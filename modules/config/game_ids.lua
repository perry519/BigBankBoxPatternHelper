local BB = _G.BigBankDepositPatternHighlighter

local WALL_UNIT_KEYS = {
	[Idstring("units/payday2/architecture/bnk/bnk_int_panel_wall4m_deposit_a1"):key()] = true,
	[Idstring("units/payday2/architecture/bnk/bnk_int_panel_wall4m_deposit_a2"):key()] = true,
	[Idstring("units/payday2/architecture/bnk/bnk_int_panel_wall4m_deposit_a3"):key()] = true,
	[Idstring("units/payday2/architecture/bnk/bnk_int_panel_wall4m_deposit_b1"):key()] = true
}

local BAG_CARRY_IDS = {
	gold = true,
	money = true
}

local SMALL_LOOT_INTERACTION_IDS = {
	cas_chips_pile = true,
	diamond_pickup = true,
	diamond_pickup_axis = true,
	diamond_pickup_pal = true,
	money_wrap_single_bundle = true,
	money_wrap_single_bundle_active = true,
	money_wrap_single_bundle_dyn = true,
	pickup_phone = true,
	pickup_tablet = true,
	safe_loot_pickup = true
}

local NON_PATTERN_PICKUP_INTERACTION_IDS = {}

for id in pairs(SMALL_LOOT_INTERACTION_IDS) do
	NON_PATTERN_PICKUP_INTERACTION_IDS[id] = true
end

NON_PATTERN_PICKUP_INTERACTION_IDS.press_take_folder = true
NON_PATTERN_PICKUP_INTERACTION_IDS.take_confidential_folder_icc = true

local SPAWN_LOOT_UNIT_KEYS = {
	[Idstring("units/pd2_dlc1/vehicles/str_vehicle_truck_gensec_transport/spawn_deposit/spawn_gold"):key()] = "gold",
	[Idstring("units/pd2_dlc1/vehicles/str_vehicle_truck_gensec_transport/spawn_deposit/spawn_money"):key()] = "money"
}

local config = {
	BAG_CARRY_IDS = BAG_CARRY_IDS,
	NON_PATTERN_PICKUP_INTERACTION_IDS = NON_PATTERN_PICKUP_INTERACTION_IDS,
	SMALL_LOOT_INTERACTION_IDS = SMALL_LOOT_INTERACTION_IDS,
	SPAWN_LOOT_UNIT_KEYS = SPAWN_LOOT_UNIT_KEYS,
	WALL_UNIT_KEYS = WALL_UNIT_KEYS
}

if BB then
	BB.shared = BB.shared or {}
	BB.shared.config_parts = BB.shared.config_parts or {}
	BB.shared.config_parts.game_ids = config
end

return config
