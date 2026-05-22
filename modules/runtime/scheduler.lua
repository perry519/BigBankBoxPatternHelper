local BB = _G.BigBankDepositPatternHighlighter

local runtime_config = BB.shared.config.runtime
local SCAN_INTERVAL = runtime_config.SCAN_INTERVAL
local SCREEN_MARKER_UPDATE_INTERVAL = runtime_config.SCREEN_MARKER_UPDATE_INTERVAL
local UPDATE_INTERVAL = runtime_config.UPDATE_INTERVAL

function BB:TickProbeGuide()
	if self.RefreshProbeGuideEvidence then
		self:RefreshProbeGuideEvidence()
	end
end

function BB:TickScreenMarkers(t)
	local timers = self.state.timers

	if t >= (timers.next_screen_marker_update_t or 0) then
		self:SetTimer("next_screen_marker_update_t", t + SCREEN_MARKER_UPDATE_INTERVAL)
		self:UpdateScreenMarkers()
	end
end

function BB:TickDiscovery(t)
	local timers = self.state.timers

	if t >= (timers.next_scan_t or 0) then
		self:SetTimer("next_scan_t", t + SCAN_INTERVAL)
		self:ScanWorld()
	end
end

function BB:TickMarkers(t)
	local timers = self.state.timers

	if t >= (timers.next_update_t or 0) then
		self:SetTimer("next_update_t", t + UPDATE_INTERVAL)
		self:ApplyMarkers()
	end
end

function BB:Update(t)
	local level_id = self.shared.util.current_level_id()
	local timers = self.state.timers

	if timers.last_level_id ~= level_id then
		self:SetTimer("last_level_id", level_id)
		self:ResetDiscoveryState()
	elseif timers.last_update_t and t and t + 1 < timers.last_update_t then
		self:ResetDiscoveryState()
	end

	self:SetTimer("last_update_t", t)

	if not self:IsBigBank() then
		self:ResetDiscoveryState()
		return
	end

	self.current_t = t or 0

	self:TickProbeGuide()
	self:TickScreenMarkers(t)
	self:TickDiscovery(t)
	self:TickMarkers(t)
end
