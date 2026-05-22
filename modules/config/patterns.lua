local BB = _G.BigBankDepositPatternHighlighter

local PATTERNS = {
	[1] = {4, 14, 20, 33, 6},
	[2] = {32, 8, 40, 13, 21},
	[3] = {19, 33, 38, 5, 17},
	[4] = {7, 14, 21, 31, 37},
	[5] = {6, 24, 36, 10, 3},
	[6] = {10, 20, 35, 9, 22}
}

local ALL_PATTERN_SLOTS = {}
local seen_pattern_slot = {}

for _, pattern in pairs(PATTERNS) do
	for _, slot in ipairs(pattern) do
		if not seen_pattern_slot[slot] then
			table.insert(ALL_PATTERN_SLOTS, slot)
			seen_pattern_slot[slot] = true
		end
	end
end

table.sort(ALL_PATTERN_SLOTS)

local ALL_DEPOSIT_SLOTS = {}

for slot = 1, 40 do
	table.insert(ALL_DEPOSIT_SLOTS, slot)
end

local config = {
	ALL_DEPOSIT_SLOTS = ALL_DEPOSIT_SLOTS,
	ALL_PATTERN_SLOTS = ALL_PATTERN_SLOTS,
	PATTERNS = PATTERNS
}

if BB then
	BB.shared = BB.shared or {}
	BB.shared.config_parts = BB.shared.config_parts or {}
	BB.shared.config_parts.patterns = config
end

return config
