local BB = _G.BigBankDepositPatternHighlighter
local ctx = BB.shared.probe_guide

local PROBE_GUIDE_EMPTY_DELAY = ctx.PROBE_GUIDE_EMPTY_DELAY
local PROBE_GUIDE_PENDING_SCAN_INTERVAL = ctx.PROBE_GUIDE_PENDING_SCAN_INTERVAL

function BB:RefreshProbeGuidePendingOutcomes()
	local now = self.current_t or 0

	for wall_key, evidence in pairs(self.probe_guide_by_wall or {}) do
		local wall = self:ProbeGuideWallByKey(wall_key)

		for slot, pending in pairs(evidence.pending_opened_slots or {}) do
			if not evidence.loot_slots[slot] and not evidence.empty_slots[slot] then
				local opened_t = pending.opened_at or evidence.opened_at_by_slot and evidence.opened_at_by_slot[slot] or now
				local empty_ready_t = opened_t + PROBE_GUIDE_EMPTY_DELAY
				local count_ready = pending.loot_baseline ~= nil
					and (self.last_probe_guide_loot_count_t or 0) >= empty_ready_t

				if now >= empty_ready_t and ((self.last_world_scan_t or 0) >= empty_ready_t or count_ready) then
					if wall then
						self:RecordProbeGuideEmptySlot(wall, slot, "pending_timeout")
					else
						evidence.empty_slots[slot] = true
						evidence.pending_opened_slots[slot] = nil
						evidence.outcome_source_by_slot[slot] = "pending_timeout"
					if self.SetTimer then
						self:SetTimer("next_update_t", 0)
					else
						self.next_update_t = 0
					end
					end
				elseif not self:ProbeGuideUsesLootCount() then
					local delay = math.max(0, math.min(PROBE_GUIDE_PENDING_SCAN_INTERVAL, empty_ready_t - now))
					self:ScheduleProbeGuideScan(delay)
				end
			else
				evidence.pending_opened_slots[slot] = nil
			end
		end
	end
end
