local BB = _G.BigBankDepositPatternHighlighter
local ctx = BB.shared.probe_guide

local PROBE_GUIDE_MODE = ctx.PROBE_GUIDE_MODE
local PROBE_GUIDE_CONSOLE_EVIDENCE_LOGS = ctx.PROBE_GUIDE_CONSOLE_EVIDENCE_LOGS

local function new_probe_guide_evidence()
	return {
		empty_slots = {},
		loot_baseline_by_slot = {},
		loot_carry_ids = {},
		loot_count_accounted_by_slot = {},
		loot_slots = {},
		non_pattern_pickup_baseline_by_slot = {},
		opened_at_by_slot = {},
		opened_slots = {},
		outcome_source_by_slot = {},
		pending_opened_slots = {},
		small_loot_baseline_by_slot = {}
	}
end

local function earlier_time(current, candidate)
	if not current or candidate < current then
		return candidate
	end

	return current
end

function BB:LogProbeGuideTrace(key, message)
	if PROBE_GUIDE_CONSOLE_EVIDENCE_LOGS and self.LogBothOnce then
		self:LogBothOnce(key, message)
	elseif self.LogOnce then
		self:LogOnce(key, message)
	end
end

function BB:ProbeGuideEvidence(wall_or_key)
	if not PROBE_GUIDE_MODE then
		return nil
	end

	local key = type(wall_or_key) == "table" and wall_or_key.key or wall_or_key

	if not key then
		return nil
	end

	key = tostring(key)
	self.probe_guide_by_wall = self.probe_guide_by_wall or {}
	self.probe_guide_by_wall[key] = self.probe_guide_by_wall[key] or new_probe_guide_evidence()

	return self.probe_guide_by_wall[key]
end

function BB:UseProbeGuideEvidence(wall)
	local evidence = self:ProbeGuideEvidence(wall)

	if not wall or not evidence then
		return nil
	end

	evidence.empty_slots = evidence.empty_slots or {}
	evidence.loot_baseline_by_slot = evidence.loot_baseline_by_slot or {}
	evidence.loot_carry_ids = evidence.loot_carry_ids or {}
	evidence.loot_count_accounted_by_slot = evidence.loot_count_accounted_by_slot or {}
	evidence.loot_slots = evidence.loot_slots or {}
	evidence.non_pattern_pickup_baseline_by_slot = evidence.non_pattern_pickup_baseline_by_slot
		or evidence.small_loot_baseline_by_slot
		or {}
	evidence.opened_at_by_slot = evidence.opened_at_by_slot or {}
	evidence.opened_slots = evidence.opened_slots or {}
	evidence.outcome_source_by_slot = evidence.outcome_source_by_slot or {}
	evidence.pending_opened_slots = evidence.pending_opened_slots or {}
	evidence.small_loot_baseline_by_slot = evidence.small_loot_baseline_by_slot or {}

	wall.probe_guide_empty_slots = evidence.empty_slots
	wall.probe_guide_loot_baseline_by_slot = evidence.loot_baseline_by_slot
	wall.probe_guide_loot_carry_ids = evidence.loot_carry_ids
	wall.probe_guide_loot_count_accounted_by_slot = evidence.loot_count_accounted_by_slot
	wall.probe_guide_loot_slots = evidence.loot_slots
	wall.probe_guide_non_pattern_pickup_baseline_by_slot = evidence.non_pattern_pickup_baseline_by_slot
	wall.probe_guide_opened_at_by_slot = evidence.opened_at_by_slot
	wall.probe_guide_opened_slots = evidence.opened_slots
	wall.probe_guide_outcome_source_by_slot = evidence.outcome_source_by_slot
	wall.probe_guide_pending_opened_slots = evidence.pending_opened_slots
	wall.probe_guide_small_loot_baseline_by_slot = evidence.small_loot_baseline_by_slot

	return evidence
end

function BB:ScheduleProbeGuideScan(delay)
	local t = (self.current_t or 0) + (delay or 0)
	local current = self.state and self.state.timers and self.state.timers.next_scan_t or self.next_scan_t
	local next_scan_t = earlier_time(current, t)

	if self.SetTimer then
		self:SetTimer("next_scan_t", next_scan_t)
	else
		self.next_scan_t = next_scan_t
	end
end

function BB:SetActiveProbeGuideWall(wall)
	if wall and wall.key then
		self.active_probe_wall_key = tostring(wall.key)
	end
end

function BB:MarkProbeGuideOutcomeSource(wall, slot, source)
	local evidence = self:UseProbeGuideEvidence(wall)

	if evidence and slot then
		evidence.outcome_source_by_slot[slot] = source
	end
end

function BB:ProbeGuideWallHasEvidence(wall)
	local evidence = self:ProbeGuideEvidence(wall)

	if not evidence then
		return false
	end

	for _ in pairs(evidence.opened_slots or {}) do
		return true
	end

	for _ in pairs(evidence.empty_slots or {}) do
		return true
	end

	for _ in pairs(evidence.loot_slots or {}) do
		return true
	end

	return false
end

function BB:ProbeGuideWallByKey(key)
	for _, wall in pairs(self.deposit_walls or {}) do
		if tostring(wall.key) == tostring(key) then
			return wall
		end
	end
end

function BB:IsActiveProbeGuideWall(wall)
	if not wall or not wall.key then
		return false
	end

	if not self.active_probe_wall_key then
		return true
	end

	if tostring(wall.key) == tostring(self.active_probe_wall_key) then
		return true
	end

	if not self:ProbeGuideWallHasEvidence(wall) then
		return true
	end

	local active_wall = self:ProbeGuideWallByKey(self.active_probe_wall_key)

	if not active_wall then
		self.active_probe_wall_key = nil
		return true
	end

	local active_state = self.ProbeGuideState and self:ProbeGuideState(active_wall)

	if active_state and active_state.pattern then
		return true
	end

	return false
end
