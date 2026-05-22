local BB = _G.BigBankDepositPatternHighlighter
local marker_config = BB.shared.config.marker
local util = BB.shared.util

local is_alive = util.is_alive
local WORLD_MARKER_COLOR = marker_config.WORLD_MARKER_COLOR
local WORLD_MARKER_PIXEL_HEIGHT = marker_config.WORLD_MARKER_PIXEL_HEIGHT
local WORLD_MARKER_PIXEL_WIDTH = marker_config.WORLD_MARKER_PIXEL_WIDTH
local WORLD_MARKER_STROKE = marker_config.WORLD_MARKER_STROKE
local WORLD_MARKER_VERSION = marker_config.WORLD_MARKER_VERSION

local function vector_signature(vector)
	if not vector then
		return "nil"
	end

	return string.format("%.1f,%.1f,%.1f", vector.x or 0, vector.y or 0, vector.z or 0)
end

function BB:BuildScreenMarkerPlane(data)
	local object, origin, x_axis, y_axis, marker_width, marker_height = self:MarkerPlane(data)

	if not object then
		return nil
	end

	return {
		object = object,
		origin = origin,
		x_axis = x_axis,
		y_axis = y_axis,
		marker_height = marker_height,
		marker_width = marker_width,
		signature = table.concat({
			vector_signature(origin),
			vector_signature(x_axis),
			vector_signature(y_axis),
			string.format("%.1f", marker_width or 0),
			string.format("%.1f", marker_height or 0)
		}, "|")
	}
end

function BB:ShouldCreateScreenMarker(data)
	local marker_position = self:MarkerPosition(data)

	return marker_position and self:IsCloseMarker(marker_position)
end

function BB:AddWorldMarkerRect(panel, name, data)
	panel:rect({
		name = name,
		x = data.x,
		y = data.y,
		w = data.w,
		h = data.h,
		layer = data.layer or 2,
		color = data.color or WORLD_MARKER_COLOR,
		blend_mode = "add"
	})
end

function BB:DrawWorldMarker(panel, color)
	local w = WORLD_MARKER_PIXEL_WIDTH
	local h = WORLD_MARKER_PIXEL_HEIGHT
	local t = WORLD_MARKER_STROKE
	local marker_color = color or WORLD_MARKER_COLOR

	self:AddWorldMarkerRect(panel, "fill", {
		x = 0,
		y = 0,
		w = w,
		h = h,
		layer = 1,
		color = marker_color
	})

	self:AddWorldMarkerRect(panel, "top", { x = 0, y = 0, w = w, h = t, color = marker_color })
	self:AddWorldMarkerRect(panel, "bottom", { x = 0, y = h - t, w = w, h = t, color = marker_color })
	self:AddWorldMarkerRect(panel, "left", { x = 0, y = 0, w = t, h = h, color = marker_color })
	self:AddWorldMarkerRect(panel, "right", { x = w - t, y = 0, w = t, h = h, color = marker_color })
end

function BB:CreateScreenMarker(id, data, plane)
	if not World or not World.newgui then
		return nil
	end

	plane = plane or self:BuildScreenMarkerPlane(data)

	if not plane then
		return nil
	end

	local gui = World:newgui()
	local ok, ws = pcall(gui.create_linked_workspace, gui, WORLD_MARKER_PIXEL_WIDTH, WORLD_MARKER_PIXEL_HEIGHT, plane.object, plane.origin, plane.x_axis, plane.y_axis)

	if not ok or not ws then
		return nil
	end

	self:DrawWorldMarker(ws:panel(), data and data.color)

	return {
		color = data and data.color,
		gui = gui,
		ws = ws,
		marker_height = plane.marker_height,
		marker_width = plane.marker_width,
		signature = plane.signature,
		slot = data and data.slot,
		unit = data and data.unit,
		version = WORLD_MARKER_VERSION
	}
end

function BB:ApplyScreenMarkers(desired)
	local wanted = {}
	local active_count = 0
	local desired_count = 0

	self.screen_marker_data = desired or {}
	self.world_marker_brush = nil

	for id, data in pairs(desired or {}) do
		desired_count = desired_count + 1

		if not self:ShouldCreateScreenMarker(data) then
			if self.screen_markers[id] then
				self:DestroyScreenMarker(self.screen_markers[id])
				self.screen_markers[id] = nil
			end
		else
			wanted[id] = true
			active_count = active_count + 1

			local plane = self:BuildScreenMarkerPlane(data)
			local marker = self.screen_markers[id]

			if not plane then
				self:DestroyScreenMarker(marker)
				self.screen_markers[id] = nil
			elseif not marker or not marker.ws or marker.unit ~= data.unit or marker.color ~= data.color or marker.version ~= WORLD_MARKER_VERSION or marker.signature ~= plane.signature then
				self:DestroyScreenMarker(marker)
				self.screen_markers[id] = self:CreateScreenMarker(id, data, plane)
			end
		end
	end

	for id, marker in pairs(self.screen_markers) do
		if not wanted[id] then
			self:DestroyScreenMarker(marker)
			self.screen_markers[id] = nil
		end
	end

	if desired_count > 0 then
		self:LogOnce("screen_marker_workspace_count_" .. tostring(active_count) .. "_of_" .. tostring(desired_count), "Active deposit marker workspaces " .. tostring(active_count) .. "/" .. tostring(desired_count))
	end

	self:UpdateScreenMarkers()
end

function BB:DestroyScreenMarker(marker)
	if marker and marker.ws then
		local gui = marker.gui or marker.ws.gui and marker.ws:gui()

		if gui and gui.destroy_workspace then
			pcall(gui.destroy_workspace, gui, marker.ws)
		end
	end

	if marker and marker.panel and marker.panel.parent then
		local parent = marker.panel:parent()

		if parent then
			pcall(parent.remove, parent, marker.panel)
		end
	end
end

function BB:UpdateScreenMarker(marker, data)
	local marker_position = self:MarkerPosition(data)
	local visible = marker and marker.ws and is_alive(marker.unit) and marker_position and self:IsCloseMarker(marker_position)

	if visible then
		if marker.ws.show then
			pcall(marker.ws.show, marker.ws)
		end
	else
		if marker and marker.ws and marker.ws.hide then
			pcall(marker.ws.hide, marker.ws)
		end
	end

	return visible
end

function BB:UpdateScreenMarkers()
	for id, marker in pairs(self.screen_markers) do
		local data = self.screen_marker_data and self.screen_marker_data[id]

		self:UpdateScreenMarker(marker, data)
	end
end

function BB:ClearScreenMarkers()
	for id, marker in pairs(self.screen_markers) do
		self:DestroyScreenMarker(marker)
		self.screen_markers[id] = nil
	end

	self.screen_marker_data = {}
	self.world_marker_brush = nil
end
