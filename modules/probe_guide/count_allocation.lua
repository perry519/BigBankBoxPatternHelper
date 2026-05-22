local BB = _G.BigBankDepositPatternHighlighter
local ctx = BB.shared.probe_guide

local PROBE_GUIDE_SLOT_PRIORITY = ctx.PROBE_GUIDE_SLOT_PRIORITY

local function sort_direct_loot_candidates(candidates)
	table.sort(candidates, function(a, b)
		if a.opened_at ~= b.opened_at then
			return a.opened_at < b.opened_at
		end

		if a.slot_priority ~= b.slot_priority then
			return a.slot_priority < b.slot_priority
		end

		if a.slot ~= b.slot then
			return a.slot < b.slot
		end

		return tostring(a.wall_key) < tostring(b.wall_key)
	end)

	return candidates
end

function BB:ProbeGuidePendingCandidates()
	local candidates = {}

	for wall_key in pairs(self.probe_guide_by_wall or {}) do
		local wall = self:ProbeGuideWallByKey(wall_key)

		if wall then
			local evidence = self:UseProbeGuideEvidence(wall)

			for slot, pending in pairs(evidence.pending_opened_slots or {}) do
				if not evidence.loot_slots[slot] and not evidence.empty_slots[slot] then
					local state = self:ProbeGuideState(wall)
					local key = tostring(wall_key)
					local is_current_slot = self.ProbeGuideStateIncludesSlot and self:ProbeGuideStateIncludesSlot(state, slot)

					candidates[#candidates + 1] = {
						evidence = evidence,
						is_active_wall = self.active_probe_wall_key ~= nil and key == tostring(self.active_probe_wall_key),
						is_current_slot = is_current_slot == true,
						opened_at = pending.opened_at or evidence.opened_at_by_slot[slot] or 0,
						slot = slot,
						slot_priority = PROBE_GUIDE_SLOT_PRIORITY[slot] or 999,
						wall = wall,
						wall_key = key
					}
				else
					evidence.pending_opened_slots[slot] = nil
				end
			end
		end
	end

	return candidates
end

function BB:SortProbeGuideCandidates(candidates)
	table.sort(candidates, function(a, b)
		if a.is_current_slot ~= b.is_current_slot then
			return a.is_current_slot
		end

		if a.is_active_wall ~= b.is_active_wall then
			return a.is_active_wall
		end

		if a.opened_at ~= b.opened_at then
			return a.opened_at < b.opened_at
		end

		if a.slot_priority ~= b.slot_priority then
			return a.slot_priority < b.slot_priority
		end

		if a.slot ~= b.slot then
			return a.slot < b.slot
		end

		return tostring(a.wall_key) < tostring(b.wall_key)
	end)

	return candidates
end

function BB:ConsumeDirectLootCountDelta(loot_delta)
	loot_delta = math.max(0, loot_delta or 0)

	if loot_delta <= 0 then
		return 0
	end

	local candidates = {}

	for wall_key in pairs(self.probe_guide_by_wall or {}) do
		local wall = self:ProbeGuideWallByKey(wall_key)

		if wall then
			local evidence = self:UseProbeGuideEvidence(wall)

			for slot in pairs(evidence.loot_slots or {}) do
				local source = evidence.outcome_source_by_slot[slot] or "unit"

				if source == "unit" and not evidence.loot_count_accounted_by_slot[slot] then
					candidates[#candidates + 1] = {
						evidence = evidence,
						opened_at = evidence.opened_at_by_slot[slot] or 0,
						slot = slot,
						slot_priority = PROBE_GUIDE_SLOT_PRIORITY[slot] or 999,
						wall_key = tostring(wall_key)
					}
				end
			end
		end
	end

	sort_direct_loot_candidates(candidates)

	for _, candidate in ipairs(candidates) do
		if loot_delta <= 0 then
			break
		end

		candidate.evidence.loot_count_accounted_by_slot[candidate.slot] = true
		loot_delta = loot_delta - 1
		self:LogProbeGuideTrace("probe_guide_direct_loot_delta_" .. candidate.wall_key .. "_" .. tostring(candidate.slot), "Probe guide consumed GameInfo loot delta for direct loot slot " .. tostring(candidate.slot) .. " wall=" .. candidate.wall_key)
	end

	return loot_delta
end

function BB:AllocateProbeGuideCountDeltas(loot_delta, non_pattern_delta)
	loot_delta = math.max(0, loot_delta or 0)
	non_pattern_delta = math.max(0, non_pattern_delta or 0)

	if loot_delta > 0 then
		local candidates = self:SortProbeGuideCandidates(self:ProbeGuidePendingCandidates())

		for _, candidate in ipairs(candidates) do
			if loot_delta <= 0 then
				break
			end

			if candidate.evidence.pending_opened_slots[candidate.slot]
				and not candidate.evidence.loot_slots[candidate.slot]
				and not candidate.evidence.empty_slots[candidate.slot] then
				self:RecordProbeGuideLootSlot(candidate.wall, candidate.slot, "loot_count", loot_delta, "gameinfo_best_effort")
				self:LogProbeGuideTrace("probe_guide_best_effort_loot_" .. candidate.wall_key .. "_" .. tostring(candidate.slot), "Probe guide best-effort assigned GameInfo loot delta to slot " .. tostring(candidate.slot) .. " wall=" .. candidate.wall_key)
				loot_delta = loot_delta - 1
			end
		end
	end

	if non_pattern_delta > 0 then
		local candidates = self:SortProbeGuideCandidates(self:ProbeGuidePendingCandidates())

		for _, candidate in ipairs(candidates) do
			if non_pattern_delta <= 0 then
				break
			end

			if candidate.evidence.pending_opened_slots[candidate.slot]
				and not candidate.evidence.loot_slots[candidate.slot]
				and not candidate.evidence.empty_slots[candidate.slot] then
				self:RecordProbeGuideEmptySlot(candidate.wall, candidate.slot, "non_pattern_best_effort")
				self:LogProbeGuideTrace("probe_guide_best_effort_empty_" .. candidate.wall_key .. "_" .. tostring(candidate.slot), "Probe guide best-effort assigned non-pattern pickup delta to slot " .. tostring(candidate.slot) .. " wall=" .. candidate.wall_key)
				non_pattern_delta = non_pattern_delta - 1
			end
		end
	end

	return loot_delta, non_pattern_delta
end

function BB:RefreshProbeGuideLootCountOutcomes(current_total, current_non_pattern_total)
	local previous_total = self.probe_guide_previous_loot_count_total
	local previous_non_pattern_total = self.probe_guide_previous_non_pattern_pickup_count_total
	local loot_delta = 0
	local non_pattern_delta = 0

	if current_total ~= nil and previous_total ~= nil then
		loot_delta = math.max(0, current_total - previous_total)
	end

	if current_non_pattern_total ~= nil and previous_non_pattern_total ~= nil then
		non_pattern_delta = math.max(0, current_non_pattern_total - previous_non_pattern_total)
	end

	loot_delta = self:ConsumeDirectLootCountDelta(loot_delta)
	self:AllocateProbeGuideCountDeltas(loot_delta, non_pattern_delta)
end
