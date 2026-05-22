local BB = _G.BigBankDepositPatternHighlighter

function BB:RecordProbeGuideLootSlot(wall, slot, carry_id, distance, source)
	local evidence = self:UseProbeGuideEvidence(wall)

	if not evidence or not slot then
		return false
	end

	source = source or "unit"

	local is_new = not evidence.loot_slots[slot]
	local changed = is_new or evidence.empty_slots[slot] ~= nil or evidence.loot_carry_ids[slot] ~= (carry_id or true)
	evidence.loot_slots[slot] = true
	evidence.loot_carry_ids[slot] = carry_id or true
	evidence.opened_slots[slot] = true
	evidence.empty_slots[slot] = nil
	evidence.pending_opened_slots[slot] = nil
	evidence.opened_at_by_slot[slot] = evidence.opened_at_by_slot[slot] or self.current_t or 0
	self:MarkProbeGuideOutcomeSource(wall, slot, source)

	if source ~= "unit" then
		evidence.loot_count_accounted_by_slot[slot] = true
	end

	self:SetActiveProbeGuideWall(wall)

	if changed then
		if self.SetTimer then
			self:SetTimer("next_update_t", 0)
		else
			self.next_update_t = 0
		end
	end

	if is_new then
		self:LogProbeGuideTrace("probe_guide_loot_" .. tostring(wall.key) .. "_" .. tostring(slot), "Probe guide observed loot in deposit slot " .. tostring(slot) .. " carry=" .. tostring(carry_id) .. " wall=" .. tostring(wall.key) .. " source=" .. tostring(source) .. " distance=" .. tostring(distance))
	end

	return true
end

function BB:RecordProbeGuideOpenedSlot(wall, slot)
	local evidence = self:UseProbeGuideEvidence(wall)

	if not evidence or not slot then
		return false
	end

	local is_new = not evidence.opened_slots[slot]
	local changed = is_new or not evidence.opened_at_by_slot[slot]
	evidence.opened_slots[slot] = true
	evidence.opened_at_by_slot[slot] = evidence.opened_at_by_slot[slot] or self.current_t or 0
	evidence.loot_baseline_by_slot[slot] = evidence.loot_baseline_by_slot[slot]
		or self.probe_guide_previous_loot_count_total
		or self.probe_guide_loot_count_total
	evidence.non_pattern_pickup_baseline_by_slot[slot] = evidence.non_pattern_pickup_baseline_by_slot[slot]
		or self.probe_guide_previous_non_pattern_pickup_count_total
		or self.probe_guide_non_pattern_pickup_count_total
	evidence.small_loot_baseline_by_slot[slot] = evidence.small_loot_baseline_by_slot[slot]
		or self.probe_guide_previous_small_loot_count_total
		or self.probe_guide_small_loot_count_total

	if evidence.loot_slots[slot] or evidence.empty_slots[slot] then
		evidence.pending_opened_slots[slot] = nil
	else
		local pending = evidence.pending_opened_slots[slot] or {}
		pending.opened_at = pending.opened_at or evidence.opened_at_by_slot[slot]
		pending.loot_baseline = pending.loot_baseline or evidence.loot_baseline_by_slot[slot]
		pending.non_pattern_baseline = pending.non_pattern_baseline or evidence.non_pattern_pickup_baseline_by_slot[slot]
		pending.small_loot_baseline = pending.small_loot_baseline or evidence.small_loot_baseline_by_slot[slot]
		evidence.pending_opened_slots[slot] = pending
	end

	self:SetActiveProbeGuideWall(wall)

	if changed then
		if not self:ProbeGuideUsesLootCount() then
			self:ScheduleProbeGuideScan(0)
		end

		if self.SetTimer then
			self:SetTimer("next_update_t", 0)
		else
			self.next_update_t = 0
		end
	end

	if is_new then
		self:LogProbeGuideTrace("probe_guide_opened_" .. tostring(wall.key) .. "_" .. tostring(slot), "Probe guide observed opened deposit slot " .. tostring(slot) .. " wall=" .. tostring(wall.key))
	end

	return true
end

function BB:RecordProbeGuideEmptySlot(wall, slot, source)
	local evidence = self:UseProbeGuideEvidence(wall)

	if not evidence or not slot or evidence.loot_slots[slot] then
		return false
	end

	source = source or "pending_timeout"

	local is_new = not evidence.empty_slots[slot]
	evidence.opened_slots[slot] = true
	evidence.opened_at_by_slot[slot] = evidence.opened_at_by_slot[slot] or self.current_t or 0
	evidence.empty_slots[slot] = true
	evidence.pending_opened_slots[slot] = nil
	self:MarkProbeGuideOutcomeSource(wall, slot, source)

	if is_new then
		if self.SetTimer then
			self:SetTimer("next_update_t", 0)
		else
			self.next_update_t = 0
		end
		self:LogProbeGuideTrace("probe_guide_empty_" .. tostring(wall.key) .. "_" .. tostring(slot), "Probe guide confirmed empty deposit slot " .. tostring(slot) .. " wall=" .. tostring(wall.key) .. " source=" .. tostring(source))
	end

	return true
end

function BB:IsProbeGuideOpenedSlot(wall, slot)
	local evidence = self:ProbeGuideEvidence(wall)

	return evidence and slot and (
		evidence.opened_slots[slot]
		or evidence.empty_slots[slot]
		or evidence.loot_slots[slot]
	)
end

function BB:IsProbeGuideOpenedBox(box)
	return box and box.key and self.opened_box_keys and self.opened_box_keys[box.key]
end

function BB:RecordProbeGuideOpenedBox(box)
	if not box or not box.key then
		return false
	end

	self.opened_box_keys = self.opened_box_keys or {}
	self.opened_box_keys[box.key] = true
	box.opened = true

	if box.wall and box.slot then
		return self:RecordProbeGuideOpenedSlot(box.wall, box.slot)
	end

	return true
end
