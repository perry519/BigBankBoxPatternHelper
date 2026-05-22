_G.BigBankDepositPatternHighlighter = _G.BigBankDepositPatternHighlighter or {}

local BB = _G.BigBankDepositPatternHighlighter

BB.ready = false

local source = debug.getinfo(1, "S").source
local core_path = source and source:sub(1, 1) == "@" and source:sub(2) or nil
local current_mod_path = core_path and core_path:match("^(.*[/\\])core%.lua$")

BB.ModPath = current_mod_path or BB.ModPath or ModPath or "mods/Big Bank Deposit Pattern Highlighter/"

dofile(BB.ModPath .. "modules/shared/bootstrap.lua")

BB:InstallModules()
BB:InstallRuntime()
