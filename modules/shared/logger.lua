local BB = _G.BigBankDepositPatternHighlighter
local config = BB.shared and BB.shared.config or {}

local LOG_PREFIX = "[Big Bank Deposit Pattern Highlighter] "
local CONSOLE_PREFIX = "[BBDPH] "

local LOG_LEVELS = {
	off = 0,
	error = 1,
	warn = 2,
	info = 3,
	debug = 4
}

local LOG_LABELS = {
	[LOG_LEVELS.error] = "ERROR",
	[LOG_LEVELS.warn] = "WARN",
	[LOG_LEVELS.info] = "INFO",
	[LOG_LEVELS.debug] = "DEBUG"
}

local DEFAULT_LOG_LEVEL = LOG_LEVELS.warn

local function log_level_value(level)
	if type(level) == "string" then
		level = LOG_LEVELS[level]
	end

	return tonumber(level) or DEFAULT_LOG_LEVEL
end

BB.log_level = log_level_value(config.log_level)

function BB:SetLogLevel(level)
	self.log_level = log_level_value(level)
end

function BB:IsLogLevelEnabled(level)
	return (self.log_level or DEFAULT_LOG_LEVEL) >= log_level_value(level)
end

function BB:FormatLogMessage(message, level)
	level = log_level_value(level)
	local label = LOG_LABELS[level]

	return LOG_PREFIX .. (label and (label .. ": ") or "") .. tostring(message)
end

function BB:LogFile(message, level)
	level = level or "debug"

	if log and self:IsLogLevelEnabled(level) then
		log(self:FormatLogMessage(message, level))
	end
end

function BB:LogConsole(message, level)
	level = level or "debug"

	if not self:IsLogLevelEnabled(level) then
		return
	end

	local text = CONSOLE_PREFIX .. tostring(message)
	local wrote = false

	if Console then
		local console_log = Console.Log or Console.log

		if console_log then
			local ok = pcall(console_log, Console, text)
			wrote = ok or wrote
		end
	end

	if not wrote and Application and Application.debug then
		local ok = pcall(Application.debug, Application, text)
		wrote = ok or wrote
	end

	if not wrote and managers and managers.chat and managers.chat._receive_message then
		local channel = ChatManager and ChatManager.GAME or 1
		local color = tweak_data and tweak_data.system_chat_color
		pcall(managers.chat._receive_message, managers.chat, channel, CONSOLE_PREFIX, tostring(message), color)
	end
end

function BB:LogOnce(key, message, level)
	level = level or "debug"

	if self.logged[key] or not self:IsLogLevelEnabled(level) then
		return
	end

	self.logged[key] = true
	self:LogFile(message, level)
end

function BB:LogBothOnce(key, message, level)
	level = level or "debug"

	if self.logged[key] or not self:IsLogLevelEnabled(level) then
		return
	end

	self.logged[key] = true
	self:LogFile(message, level)
	self:LogConsole(message, level)
end
