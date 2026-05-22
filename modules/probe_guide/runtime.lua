local BB = _G.BigBankDepositPatternHighlighter
local ctx = BB.shared.probe_guide

local BAG_CARRY_IDS = ctx.BAG_CARRY_IDS
local PROBE_GUIDE_LOOT_MATCH_DISTANCE_SQ = ctx.PROBE_GUIDE_LOOT_MATCH_DISTANCE_SQ
local PROBE_GUIDE_MODE = ctx.PROBE_GUIDE_MODE
local SPAWN_LOOT_UNIT_KEYS = ctx.SPAWN_LOOT_UNIT_KEYS
local is_alive = ctx.is_alive
local safe_call = ctx.safe_call
local unit_key = ctx.unit_key

local function has_any_slot(slots)
	for _ in pairs(slots or {}) do
		return true
	end

	return false
end

function BB:RefreshProbeGuideEvidence()
	if not PROBE_GUIDE_MODE then
		return
	end

	local current_loot_count = self:ReadProbeGuideLootCount()
	local current_non_pattern_pickup_count = self:ReadProbeGuideNonPatternPickupCount()

	self.probe_guide_previous_loot_count_total = self.probe_guide_loot_count_total
	self.probe_guide_previous_non_pattern_pickup_count_total = self.probe_guide_non_pattern_pickup_count_total
	self.probe_guide_previous_small_loot_count_total = self.probe_guide_small_loot_count_total

	if current_loot_count ~= nil then
		if self.probe_guide_previous_loot_count_total == nil then
			self.probe_guide_previous_loot_count_total = current_loot_count
		end

		if self.probe_guide_previous_non_pattern_pickup_count_total == nil then
			self.probe_guide_previous_non_pattern_pickup_count_total = current_non_pattern_pickup_count
		end

		if self.probe_guide_previous_small_loot_count_total == nil then
			self.probe_guide_previous_small_loot_count_total = current_non_pattern_pickup_count
		end

		self.probe_guide_loot_count_available = true
		self.last_probe_guide_loot_count_t = self.current_t or 0
		self:LogBothOnce("probe_guide_gameinfo_loot_count", "Probe guide using GameInfo gold/money loot-count deltas")
	else
		self.probe_guide_loot_count_available = false
	end

	for _, box in pairs(self.deposit_boxes or {}) do
		if box.wall and box.slot then
			if self:IsInactiveDepositBox(box) then
				local evidence = self:UseProbeGuideEvidence(box.wall)
				local resolved_pattern = box.wall.resolved_probe_pattern_order or (evidence and evidence.resolved_pattern_order)
				local has_outcome = evidence and (has_any_slot(evidence.loot_slots) or has_any_slot(evidence.empty_slots))
				local already_opened = self:IsProbeGuideOpenedSlot(box.wall, box.slot)
				local should_record = box.was_active or self:IsProbeGuideOpenedBox(box) or not already_opened

				if has_outcome or not should_record then
					local state = self:ProbeGuideState(box.wall)
					should_record = should_record
						or (self.ProbeGuideStateIncludesSlot and self:ProbeGuideStateIncludesSlot(state, box.slot))
					resolved_pattern = resolved_pattern or (state and state.pattern)
				end

				if not resolved_pattern and should_record then
					self:RecordProbeGuideOpenedBox(box)
				end
			else
				box.was_active = true
			end
		end
	end

	self:RefreshProbeGuideLootCountOutcomes(current_loot_count, current_non_pattern_pickup_count)
	self:RefreshProbeGuidePendingOutcomes()

	if current_loot_count ~= nil then
		self.probe_guide_loot_count_total = current_loot_count
	end

	if current_non_pattern_pickup_count ~= nil then
		self.probe_guide_non_pattern_pickup_count_total = current_non_pattern_pickup_count
		self.probe_guide_small_loot_count_total = current_non_pattern_pickup_count
	end

	for key, box in pairs(self.bag_boxes or {}) do
		if not self:IsLiveBagBox(box) then
			self.bag_boxes[key] = nil
		end
	end
end

function BB:ObserveCarryUnit(unit)
	if not PROBE_GUIDE_MODE or not is_alive(unit) then
		return
	end

	if self:ProbeGuideUsesLootCount() then
		return
	end

	local carry_data = unit.carry_data and safe_call(unit, "carry_data")
	local carry_id = carry_data and safe_call(carry_data, "carry_id") or SPAWN_LOOT_UNIT_KEYS[unit_key(unit)]

	if not BAG_CARRY_IDS[carry_id] then
		return
	end

	local position = unit.position and unit:position()
	local box_key, box, distance = self:NearestDepositBox(position, PROBE_GUIDE_LOOT_MATCH_DISTANCE_SQ)

	if box_key and box and box.wall and box.slot then
		local state = self:ProbeGuideState(box.wall)
		local evidence = self:ProbeGuideEvidence(box.wall)
		local pending = evidence and evidence.pending_opened_slots and evidence.pending_opened_slots[box.slot]
		local is_current_probe = self.ProbeGuideStateIncludesSlot and self:ProbeGuideStateIncludesSlot(state, box.slot)

		if not state or state.pattern or (not is_current_probe and not pending) then
			return
		end

		local opened = self:IsProbeGuideOpenedSlot(box.wall, box.slot)

		if not opened and box.was_active and self:IsInactiveDepositBox(box) then
			opened = self:RecordProbeGuideOpenedBox(box)
		end

		if opened then
			self:RecordProbeGuideLootSlot(box.wall, box.slot, carry_id, distance)
			self.bag_boxes = self.bag_boxes or {}
			self.bag_boxes[box_key] = {
				carry_id = carry_id,
				carry_unit = unit,
				position = box.position,
				slot = box.slot,
				unit = box.unit,
				wall = box.wall
			}
		end

		return
	end
end
