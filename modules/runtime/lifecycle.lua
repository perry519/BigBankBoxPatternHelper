local BB = _G.BigBankDepositPatternHighlighter
local util = BB.shared.util

local current_level_id = util.current_level_id

function BB:IsBigBank()
	return current_level_id() == "big"
end

function BB:ResetDiscoveryState()
	self:SetStateTable("deposit_walls", {})
	self:SetStateTable("deposit_boxes", {})
	self:SetStateTable("bag_boxes", {})
	self:SetStateTable("opened_box_keys", {})
	self:SetStateTable("probe_guide_by_wall", {})
	self:SetStateTable("logged", {})

	self.active_probe_wall_key = nil
	self.probe_guide_loot_count_available = nil
	self.probe_guide_loot_count_total = nil
	self.probe_guide_non_pattern_pickup_count_total = nil
	self.probe_guide_small_loot_count_total = nil
	self.last_probe_guide_loot_count_t = nil
	self.last_world_scan_t = nil

	self:SetTimer("next_scan_t", 0)
	self:SetTimer("next_update_t", 0)
	self:SetTimer("next_screen_marker_update_t", 0)

	self:ClearAllMarkers()
end

function BB:Install()
	if self.installed or not Hooks then
		return
	end

	self.installed = true

	Hooks:Add("GameSetupUpdate", "BigBankDepositPatternHighlighter_GameSetupUpdate", function(t)
		BB:Update(t or 0)
	end)
end
