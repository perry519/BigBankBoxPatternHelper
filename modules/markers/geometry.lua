local BB = _G.BigBankDepositPatternHighlighter
local marker_config = BB.shared.config.marker
local util = BB.shared.util

local is_alive = util.is_alive
local safe_call = util.safe_call
local distance_sq = util.distance_sq
local normalized_copy = util.normalized_copy
local MARKER_DISPLAY_DISTANCE_SQ = marker_config.MARKER_DISPLAY_DISTANCE_SQ
local WORLD_MARKER_FACE_OFFSET = marker_config.WORLD_MARKER_FACE_OFFSET
local WORLD_MARKER_HEIGHT = marker_config.WORLD_MARKER_HEIGHT
local WORLD_MARKER_HEIGHT_INSET = marker_config.WORLD_MARKER_HEIGHT_INSET
local WORLD_MARKER_LOCK_TO_CENTER_Y = marker_config.WORLD_MARKER_LOCK_TO_CENTER_Y
local WORLD_MARKER_WIDTH = marker_config.WORLD_MARKER_WIDTH
local WORLD_MARKER_WIDTH_INSET = marker_config.WORLD_MARKER_WIDTH_INSET

function BB:HudPanel()
	if not managers or not managers.hud or not managers.hud.script or not PlayerBase then
		return nil
	end

	local hud = managers.hud:script(PlayerBase.PLAYER_INFO_HUD_PD2)

	return hud and hud.panel
end

function BB:ScreenPosition(position)
	if not position or not managers or not managers.viewport or not managers.hud or not managers.hud._saferect then
		return nil
	end

	local camera = managers.viewport:get_current_camera()

	if not camera then
		return nil
	end

	return managers.hud._saferect:world_to_screen(camera, position)
end

function BB:PlayerPosition()
	if not managers or not managers.player or not managers.player.player_unit then
		return nil
	end

	local unit = managers.player:player_unit()

	return is_alive(unit) and unit.position and unit:position()
end

function BB:MarkerPosition(data)
	return data and (data.marker_position or data.position)
end

function BB:GetInteraction(unit)
	if not is_alive(unit) or not unit.interaction then
		return nil
	end

	return safe_call(unit, "interaction")
end

function BB:InteractionAxis(unit)
	local interaction = self:GetInteraction(unit)
	local axis = interaction and interaction.interact_axis and safe_call(interaction, "interact_axis")

	return normalized_copy(axis)
end

function BB:FaceNormal(anchor, rotation)
	local normal = rotation and normalized_copy(rotation:y())

	if not normal or not mvector3 then
		return normal
	end

	local viewer_position = self:PlayerPosition()

	if not viewer_position and managers and managers.viewport and managers.viewport.get_current_camera_position then
		viewer_position = managers.viewport:get_current_camera_position()
	end

	if viewer_position and anchor then
		local viewer_direction = Vector3()

		mvector3.set(viewer_direction, viewer_position)
		mvector3.subtract(viewer_direction, anchor)

		if mvector3.dot(normal, viewer_direction) < 0 then
			normal = normal * -1
		end
	end

	return normal
end

function BB:NearestDepositBoxSpacing(center, axis, other_axis)
	if not center or not axis or not other_axis or not mvector3 then
		return nil
	end

	local best

	for _, box in pairs(self.deposit_boxes or {}) do
		local position = box and box.position

		if position then
			local offset = Vector3()

			mvector3.set(offset, position)
			mvector3.subtract(offset, center)

			local primary = math.abs(mvector3.dot(offset, axis))
			local secondary = math.abs(mvector3.dot(offset, other_axis))

			if primary > 5 and secondary <= primary * 0.45 and (not best or primary < best) then
				best = primary
			end
		end
	end

	return best
end

function BB:RuntimeMarkerSize(data, center, right, up)
	if center and right and up then
		local width = self:NearestDepositBoxSpacing(center, right, up)
		local height = self:NearestDepositBoxSpacing(center, up, right)

		if width and height then
			return width * WORLD_MARKER_WIDTH_INSET, height * WORLD_MARKER_HEIGHT_INSET
		end
	end

	return WORLD_MARKER_WIDTH, WORLD_MARKER_HEIGHT
end

function BB:MarkerCenter(data, anchor, right, up)
	if not anchor then
		return nil
	end

	if data and up and right then
		local row_spacing

		if data.box then
			row_spacing = self:NearestDepositBoxSpacing(anchor, up, right)
		end

		if row_spacing then
			return anchor + up * (row_spacing * WORLD_MARKER_LOCK_TO_CENTER_Y)
		end
	end

	return anchor
end

function BB:MarkerPlane(data)
	local unit = data and data.unit
	local anchor = self:MarkerPosition(data)

	if not anchor or not is_alive(unit) then
		return nil
	end

	local rotation = is_alive(unit) and unit.rotation and safe_call(unit, "rotation")
	local object = unit.orientation_object and safe_call(unit, "orientation_object")

	if not rotation or not object then
		return nil
	end

	local right = rotation:x()
	local up = rotation:z()
	local normal = self:InteractionAxis(unit) or self:FaceNormal(anchor, rotation)

	if not normal then
		return nil
	end

	local face_distance = WORLD_MARKER_FACE_OFFSET

	if normal and mvector3 then
		local face_right = Vector3()

		mvector3.cross(face_right, normal, math.UP or Vector3(0, 0, 1))

		local normalized_right = normalized_copy(face_right)

		if normalized_right then
			right = normalized_right
		end
	end

	local center = self:MarkerCenter(data, anchor, right, up)

	if not center then
		return nil
	end

	local marker_width, marker_height = self:RuntimeMarkerSize(data, anchor, right, up)

	local x_axis = right * marker_width
	local y_axis = up * -marker_height
	local origin = center + normal * face_distance - right * (marker_width / 2) + up * (marker_height / 2)

	return object, origin, x_axis, y_axis, marker_width, marker_height
end

function BB:IsCloseMarker(position)
	local player_position = self:PlayerPosition()
	local distance = player_position and position and distance_sq(player_position, position)

	return distance and distance <= MARKER_DISPLAY_DISTANCE_SQ
end

function BB:IsInFrontOfCamera(position)
	if not position or not managers or not managers.viewport or not mrotation or not mvector3 then
		return true
	end

	local camera_position = managers.viewport:get_current_camera_position()
	local camera_rotation = managers.viewport:get_current_camera_rotation()

	if not camera_position or not camera_rotation then
		return true
	end

	local forward = Vector3()
	local direction = Vector3()

	mrotation.y(camera_rotation, forward)
	mvector3.set(direction, position)
	mvector3.subtract(direction, camera_position)
	mvector3.normalize(direction)

	return mvector3.dot(forward, direction) > 0
end
