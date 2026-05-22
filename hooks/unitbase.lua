local function load_core()
	if not _G.BigBankDepositPatternHighlighter or not _G.BigBankDepositPatternHighlighter.ready then
		local path = ModPath or "mods/Big Bank Deposit Pattern Highlighter/"
		local ok, err = pcall(dofile, path .. "core.lua")

		if not ok and path ~= "mods/Big Bank Deposit Pattern Highlighter/" then
			_G.BigBankDepositPatternHighlighter = nil

			local previous_mod_path = ModPath
			ModPath = "mods/Big Bank Deposit Pattern Highlighter/"

			local fallback_ok, fallback_err = pcall(dofile, "mods/Big Bank Deposit Pattern Highlighter/core.lua")
			ModPath = previous_mod_path

			if not fallback_ok and log then
				log("[Big Bank Deposit Pattern Highlighter] Failed to load core.lua: " .. tostring(err) .. " | fallback: " .. tostring(fallback_err))
			end
		elseif not ok and log then
			log("[Big Bank Deposit Pattern Highlighter] Failed to load core.lua: " .. tostring(err))
		end
	end

	local mod = _G.BigBankDepositPatternHighlighter

	if mod and mod.ready then
		return mod
	end

	_G.BigBankDepositPatternHighlighter = nil
end

local BigBankDepositPatternHighlighter = load_core()

if BigBankDepositPatternHighlighter and BigBankDepositPatternHighlighter.RegisterPotentialDepositWall and Hooks and UnitBase then
	Hooks:PostHook(UnitBase, "init", "BigBankDepositPatternHighlighter_UnitBase_init", function(_, unit)
		if BigBankDepositPatternHighlighter.ready and BigBankDepositPatternHighlighter.RegisterPotentialDepositWall then
			BigBankDepositPatternHighlighter:RegisterPotentialDepositWall(unit)
		end

		if BigBankDepositPatternHighlighter.ready and BigBankDepositPatternHighlighter.RegisterDepositBox then
			local interaction

			if unit and unit.interaction then
				local ok, result = pcall(unit.interaction, unit)

				if ok then
					interaction = result
				end
			end

			BigBankDepositPatternHighlighter:RegisterDepositBox(unit, interaction)
		end

		if BigBankDepositPatternHighlighter.ready and BigBankDepositPatternHighlighter.ObserveCarryUnit then
			BigBankDepositPatternHighlighter:ObserveCarryUnit(unit)
		end
	end)
end
