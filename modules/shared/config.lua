local BB = _G.BigBankDepositPatternHighlighter
local root = (BB and BB.ModPath or "mods/Big Bank Deposit Pattern Highlighter/") .. "modules/config/"

local function load_config_part(name)
	local result = dofile(root .. name .. ".lua")

	return result or BB.shared.config_parts[name]
end

BB.shared = BB.shared or {}
BB.shared.config_parts = BB.shared.config_parts or {}

local config = {
	game_ids = load_config_part("game_ids"),
	log_level = "warn",
	marker = load_config_part("marker"),
	patterns = load_config_part("patterns"),
	probe_guide = load_config_part("probe_guide"),
	runtime = {
		SCAN_INTERVAL = 20,
		SCREEN_MARKER_UPDATE_INTERVAL = 0.5,
		UPDATE_INTERVAL = 0.75
	}
}

BB.shared.config = config

return config
