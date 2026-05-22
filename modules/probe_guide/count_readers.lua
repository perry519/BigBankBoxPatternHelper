local BB = _G.BigBankDepositPatternHighlighter
local ctx = BB.shared.probe_guide

local BAG_CARRY_IDS = ctx.BAG_CARRY_IDS
local NON_PATTERN_PICKUP_INTERACTION_IDS = ctx.NON_PATTERN_PICKUP_INTERACTION_IDS
local PROBE_GUIDE_USE_GAMEINFO_LOOT_COUNT = ctx.PROBE_GUIDE_USE_GAMEINFO_LOOT_COUNT
local SMALL_LOOT_INTERACTION_IDS = ctx.SMALL_LOOT_INTERACTION_IDS

function BB:ReadProbeGuideLootCount()
	if not PROBE_GUIDE_USE_GAMEINFO_LOOT_COUNT or not managers or not managers.gameinfo or not managers.gameinfo.get_loot then
		return nil
	end

	local ok, loot = pcall(managers.gameinfo.get_loot, managers.gameinfo)

	if not ok or type(loot) ~= "table" then
		return nil
	end

	local total = 0

	for _, data in pairs(loot) do
		if data and BAG_CARRY_IDS[data.carry_id] then
			total = total + (tonumber(data.count) or 1)
		end
	end

	return total
end

function BB:ReadProbeGuideNonPatternPickupCount()
	if not PROBE_GUIDE_USE_GAMEINFO_LOOT_COUNT or not managers then
		return nil
	end

	if managers.gameinfo and managers.gameinfo.get_special_equipment then
		local ok, equipment = pcall(managers.gameinfo.get_special_equipment, managers.gameinfo)

		if ok and type(equipment) == "table" then
			local total = 0

			for _, data in pairs(equipment) do
				if data and (NON_PATTERN_PICKUP_INTERACTION_IDS[data.interact_id] or SMALL_LOOT_INTERACTION_IDS[data.interact_id]) then
					total = total + 1
				end
			end

			return total
		end
	end

	if managers.loot and managers.loot.get_real_total_small_loot_value then
		local ok, value = pcall(managers.loot.get_real_total_small_loot_value, managers.loot)

		if ok and value then
			return tonumber(value) or 0
		end
	end

	return nil
end

BB.ReadProbeGuideSmallLootCount = BB.ReadProbeGuideNonPatternPickupCount

function BB:ProbeGuideUsesLootCount()
	return self.probe_guide_loot_count_available == true
end
