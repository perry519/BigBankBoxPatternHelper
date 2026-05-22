local BB = _G.BigBankDepositPatternHighlighter

local config = {
	PROBE_GUIDE_CONSOLE_EVIDENCE_LOGS = false,
	PROBE_GUIDE_EMPTY_DELAY = 1.5,
	PROBE_GUIDE_LOOT_MATCH_DISTANCE_SQ = 10000,
	PROBE_GUIDE_MODE = true,
	PROBE_GUIDE_PENDING_SCAN_INTERVAL = 0.25,
	PROBE_GUIDE_USE_GAMEINFO_LOOT_COUNT = true
}

if BB then
	BB.shared = BB.shared or {}
	BB.shared.config_parts = BB.shared.config_parts or {}
	BB.shared.config_parts.probe_guide = config
end

return config
