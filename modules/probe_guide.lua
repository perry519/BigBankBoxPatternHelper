local BB = _G.BigBankDepositPatternHighlighter
local config = BB.shared.config
local util = BB.shared.util

local PROBE_GUIDE_SLOT_PRIORITY = {
	[14] = 1,
	[6] = 2,
	[4] = 3,
	[10] = 4,
	[35] = 5,
	[32] = 6,
	[3] = 7,
	[21] = 8,
	[7] = 9,
	[5] = 10,
	[9] = 11,
	[20] = 12,
	[33] = 13
}

local function module_root()
	if BB.ModPath then
		return BB.ModPath .. "modules/"
	end

	local source = debug.getinfo(1, "S").source
	local path = source and source:sub(1, 1) == "@" and source:sub(2) or nil

	return path and path:match("^(.*[/\\])[^/\\]+$") or "modules/"
end

local context = {
	BAG_CARRY_IDS = config.game_ids.BAG_CARRY_IDS or {},
	NON_PATTERN_PICKUP_INTERACTION_IDS = config.game_ids.NON_PATTERN_PICKUP_INTERACTION_IDS or {},
	OPENABLE_BOX_MATCH_DISTANCE_SQ = config.marker.OPENABLE_BOX_MATCH_DISTANCE_SQ,
	PATTERNS = config.patterns.PATTERNS,
	PROBE_GUIDE_CONSOLE_EVIDENCE_LOGS = config.probe_guide.PROBE_GUIDE_CONSOLE_EVIDENCE_LOGS == true,
	PROBE_GUIDE_EMPTY_DELAY = config.probe_guide.PROBE_GUIDE_EMPTY_DELAY or 1.5,
	PROBE_GUIDE_INITIAL_SLOT_COUNT = 2,
	PROBE_GUIDE_LOOT_MATCH_DISTANCE_SQ = config.probe_guide.PROBE_GUIDE_LOOT_MATCH_DISTANCE_SQ or math.min(config.marker.OPENABLE_BOX_MATCH_DISTANCE_SQ or 10000, 10000),
	PROBE_GUIDE_MAX_BAG_SLOTS = config.probe_guide.PROBE_GUIDE_MAX_BAG_SLOTS or 5,
	PROBE_GUIDE_MIN_BAG_SLOTS = config.probe_guide.PROBE_GUIDE_MIN_BAG_SLOTS or 3,
	PROBE_GUIDE_MODE = config.probe_guide.PROBE_GUIDE_MODE == true,
	PROBE_GUIDE_NEXT_SLOT_COUNT = 1,
	PROBE_GUIDE_OPENED_ONLY_SLOT_ORDER = config.probe_guide.PROBE_GUIDE_OPENED_ONLY_SLOT_ORDER or {14, 10},
	PROBE_GUIDE_PENDING_SCAN_INTERVAL = config.probe_guide.PROBE_GUIDE_PENDING_SCAN_INTERVAL or 0.25,
	PROBE_GUIDE_SLOT_PRIORITY = PROBE_GUIDE_SLOT_PRIORITY,
	PROBE_GUIDE_USE_GAMEINFO_LOOT_COUNT = config.probe_guide.PROBE_GUIDE_USE_GAMEINFO_LOOT_COUNT == true,
	SMALL_LOOT_INTERACTION_IDS = config.game_ids.SMALL_LOOT_INTERACTION_IDS or {},
	SPAWN_LOOT_UNIT_KEYS = config.game_ids.SPAWN_LOOT_UNIT_KEYS or {},
	distance_sq = util.distance_sq,
	is_alive = util.is_alive,
	safe_call = util.safe_call,
	unit_key = util.unit_key
}

BB.shared.probe_guide = context

local root = module_root() .. "probe_guide/"

local function load_probe_guide_module(name)
	local path = root .. name .. ".lua"
	local ok, result = pcall(dofile, path)

	if not ok then
		error("[Big Bank Deposit Pattern Highlighter] Failed to load " .. path .. ": " .. tostring(result))
	end

	return result
end

load_probe_guide_module("evidence")
load_probe_guide_module("state")
load_probe_guide_module("world")
load_probe_guide_module("recording")
load_probe_guide_module("count_readers")
load_probe_guide_module("count_allocation")
load_probe_guide_module("pending_outcomes")
load_probe_guide_module("runtime")
