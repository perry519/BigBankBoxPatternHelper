local BB = _G.BigBankDepositPatternHighlighter

local function load_file(path)
	local ok, result = pcall(dofile, path)

	if not ok then
		error("[Big Bank Deposit Pattern Highlighter] Failed to load " .. path .. ": " .. tostring(result))
	end

	return result
end

local function state_table(name)
	BB.state[name] = BB.state[name] or BB[name] or {}
	BB[name] = BB.state[name]
end

function BB:InstallState()
	self.state = self.state or {}

	state_table("deposit_walls")
	state_table("deposit_boxes")
	state_table("bag_boxes")
	state_table("opened_box_keys")
	state_table("probe_guide_by_wall")
	state_table("screen_markers")
	state_table("screen_marker_data")
	state_table("logged")

	self.state.timers = self.state.timers or {}
	self.state.timers.next_scan_t = self.state.timers.next_scan_t or self.next_scan_t or 0
	self.state.timers.next_update_t = self.state.timers.next_update_t or self.next_update_t or 0
	self.state.timers.next_screen_marker_update_t =
		self.state.timers.next_screen_marker_update_t or self.next_screen_marker_update_t or 0
	self.state.timers.last_update_t = self.state.timers.last_update_t or self.last_update_t
	self.state.timers.last_level_id = self.state.timers.last_level_id or self.last_level_id

	self.next_scan_t = self.state.timers.next_scan_t
	self.next_update_t = self.state.timers.next_update_t
	self.next_screen_marker_update_t = self.state.timers.next_screen_marker_update_t
	self.last_update_t = self.state.timers.last_update_t
	self.last_level_id = self.state.timers.last_level_id
end

function BB:SetStateTable(name, value)
	self.state[name] = value or {}
	self[name] = self.state[name]
end

function BB:SetTimer(name, value)
	self.state.timers[name] = value
	self[name] = value
end

function BB:LoadFile(path)
	return load_file(path)
end

function BB:LoadModule(name)
	local path = self.ModPath .. "modules/" .. name .. ".lua"

	if self.LogFile then
		self:LogFile("Loading module " .. name)
	end

	local result = load_file(path)

	if self.LogFile then
		self:LogFile("Loaded module " .. name)
	end

	return result
end

function BB:InstallModules()
	self.shared = self.shared or {}
	if not self.shared.config then
		self:LoadModule("shared/config")
	end

	if not self.shared.util then
		self:LoadModule("shared/util")
	end

	self:InstallState()
	self.shared.logger = self.shared.logger or self:LoadModule("shared/logger") or true
	self:LogFile("BBDPH shared logger installed")

	self:LoadModule("markers/geometry")
	self:LoadModule("markers/screen")
	self:LoadModule("patterns/solver")
	self:LoadModule("discovery/registry")
	self:LoadModule("discovery/world_scan")
	self:LoadModule("probe_guide")
	self:LoadModule("markers/selection")
	self:LoadModule("markers/runtime")
	self:LogFile("BBDPH modules installed")
end

function BB:InstallRuntime()
	self:LogFile("Installing BBDPH runtime")
	self:LoadModule("runtime/lifecycle")
	self:LoadModule("runtime/scheduler")

	local version = self.shared.config.marker.WORLD_MARKER_VERSION

	if self.discovery_version ~= version then
		self.discovery_version = version
		self:ResetDiscoveryState()
	end

	self.ready = true
	self:Install()
	self:LogFile("BBDPH runtime installed")
end

return {
	load_file = load_file,
	load_module = function(name)
		return BB:LoadModule(name)
	end
}
