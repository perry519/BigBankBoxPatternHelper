local BB = _G.BigBankDepositPatternHighlighter
local config = BB.shared.config
local util = BB.shared.util

local PATTERN_MARKER_COLORS = config.marker.PATTERN_MARKER_COLORS or {}
local PATTERNS = config.patterns.PATTERNS
local PROBE_GUIDE_INITIAL_MARKER_COLOR = config.marker.PROBE_GUIDE_INITIAL_MARKER_COLOR
local PROBE_GUIDE_MODE = config.probe_guide.PROBE_GUIDE_MODE == true
local SHOW_FULL_PATTERN = config.marker.SHOW_FULL_PATTERN == true
local is_alive = util.is_alive
local waypoint_id = util.waypoint_id

local function resolved_pattern_amount(pattern, amount)
	if not pattern then
		return 0
	end

	if SHOW_FULL_PATTERN then
		return #pattern
	end

	return math.min(math.max(tonumber(amount) or #pattern, 1), #pattern)
end

local function pattern_slot_list(order, amount)
	local pattern = PATTERNS[order]

	if not pattern then
		return "none"
	end

	amount = resolved_pattern_amount(pattern, amount)

	local slots = {}

	for index = 1, amount do
		table.insert(slots, tostring(pattern[index]))
	end

	return table.concat(slots, ",")
end

function BB:LogPatternDiscovery(wall, order, amount, setup)
	if not wall or not order or not amount then
		return
	end

	local type_text = tostring(setup or "unknown")
	local key = table.concat({
		"pattern_discovery",
		tostring(wall.key),
		type_text,
		tostring(order),
		tostring(amount),
		tostring(SHOW_FULL_PATTERN)
	}, "_")
	local message = "Pattern discovered: type=" .. type_text
		.. " source=sequence"
		.. " pattern=" .. tostring(order)
		.. " amount=" .. tostring(amount)
		.. " show_full_pattern=" .. tostring(SHOW_FULL_PATTERN)
		.. " slots=" .. pattern_slot_list(order, amount)

	if self.LogBothOnce then
		self:LogBothOnce(key, message)
	else
		self:LogOnce(key, message)
	end
end

function BB:LogProbeGuideSequenceVariables(wall)
	if not wall or not self.ReadWallPatternVariables then
		return
	end

	local order, amount, setup = self:ReadWallPatternVariables(wall)
	local key = table.concat({
		"probe_guide_sequence_variables",
		tostring(wall.key),
		tostring(setup),
		tostring(order),
		tostring(amount),
		tostring(SHOW_FULL_PATTERN)
	}, "_")
	local message = "Probe guide sequence variables: type=" .. tostring(setup)
		.. " order=" .. tostring(order)
		.. " amount=" .. tostring(amount)
		.. " show_full_pattern=" .. tostring(SHOW_FULL_PATTERN)
		.. " wall=" .. tostring(wall.key)
		.. " metadata_slots=" .. pattern_slot_list(order, amount)

	if self.LogBothOnce then
		self:LogBothOnce(key, message)
	else
		self:LogOnce(key, message)
	end
end

function BB:AddDesiredSlotMarker(desired, wall, slot, source, color)
	local box = wall and wall.box_slots and wall.box_slots[slot]
	local unit = box and is_alive(box.unit) and box.unit
	local position = unit and box.position

	if not unit or not position then
		self:LogOnce("waiting_for_box_slot_" .. tostring(wall and wall.key) .. "_" .. tostring(slot), "Waiting for mapped deposit box interaction unit for slot " .. tostring(slot))
		return false
	end

	desired[waypoint_id("slot", tostring(wall.key) .. "_" .. tostring(slot))] = {
		marker_position = position,
		position = position,
		source = source,
		color = color,
		box = box,
		unit = unit,
		slot = slot,
		wall = wall
	}

	return true
end

function BB:AddPatternMarkers(desired, wall, order, amount, source)
	local added = false
	local pattern = PATTERNS[order]
	local color = PATTERN_MARKER_COLORS[order]

	if not pattern then
		return false
	end

	amount = resolved_pattern_amount(pattern, amount)

	for index = 1, amount do
		added = self:AddDesiredSlotMarker(desired, wall, pattern[index], source or "sequence", color) or added
	end

	return added
end

function BB:AddProbeGuideMarkers(desired, wall, ignore_active_wall)
	if not ignore_active_wall and self.IsActiveProbeGuideWall and not self:IsActiveProbeGuideWall(wall) then
		return false
	end

	local state = self.ProbeGuideState and self:ProbeGuideState(wall)

	if not state then
		return false
	end

	if state.pattern then
		local pattern = PATTERNS[state.pattern]

		if not pattern then
			return false
		end

		wall.resolved_probe_pattern_order = state.pattern
		self:LogBothOnce("probe_guide_pattern_" .. tostring(wall.key) .. "_" .. tostring(state.pattern), "Probe guide resolved pattern " .. tostring(state.pattern) .. " slots=" .. pattern_slot_list(state.pattern, #pattern))

		return self:AddPatternMarkers(desired, wall, state.pattern, #pattern, "probe_guide_resolved")
	end

	if state.slots and #state.slots > 0 then
		local added = false
		local added_count = 0
		local target_count = state.display_slot_count or #state.slots

		for _, slot in ipairs(state.slots) do
			if added_count >= target_count then
				break
			end

			if self.LogProbeGuideTrace then
				self:LogProbeGuideTrace("probe_guide_next_" .. tostring(wall.key) .. "_" .. tostring(slot), "Probe guide next deposit slot " .. tostring(slot))
			else
				self:LogOnce("probe_guide_next_" .. tostring(wall.key) .. "_" .. tostring(slot), "Probe guide next deposit slot " .. tostring(slot))
			end

			if self:AddDesiredSlotMarker(desired, wall, slot, "probe_guide", PROBE_GUIDE_INITIAL_MARKER_COLOR) then
				added = true
				added_count = added_count + 1
			end
		end

		return added
	end

	if state.slot then
		if self.LogProbeGuideTrace then
			self:LogProbeGuideTrace("probe_guide_next_" .. tostring(wall.key) .. "_" .. tostring(state.slot), "Probe guide next deposit slot " .. tostring(state.slot))
		else
			self:LogOnce("probe_guide_next_" .. tostring(wall.key) .. "_" .. tostring(state.slot), "Probe guide next deposit slot " .. tostring(state.slot))
		end

		return self:AddDesiredSlotMarker(desired, wall, state.slot, "probe_guide", PROBE_GUIDE_INITIAL_MARKER_COLOR)
	end

	return false
end

function BB:DesiredMarkers()
	local desired = {}
	local found_wall = false
	local found_pattern = false

	for key, wall in pairs(self.deposit_walls) do
		if wall.is_deposit_wall and is_alive(wall.unit) then
			found_wall = true

			if PROBE_GUIDE_MODE then
				self:LogProbeGuideSequenceVariables(wall)
				wall.resolved_pattern_order = nil
				wall.resolved_pattern_amount = nil
				wall.resolved_setup = nil
				found_pattern = self:AddProbeGuideMarkers(desired, wall) or found_pattern
			else
				local order, amount, setup = self:ReadWallPattern(wall)

				if order and amount then
					found_pattern = true
					wall.resolved_pattern_order = order
					wall.resolved_pattern_amount = amount
					wall.resolved_setup = setup
					self:LogPatternDiscovery(wall, order, amount, setup)
					self:AddPatternMarkers(desired, wall, order, amount)
				else
					wall.resolved_pattern_order = nil
					wall.resolved_pattern_amount = nil
					wall.resolved_setup = nil
				end
			end
		else
			self.deposit_walls[key] = nil
		end
	end

	if PROBE_GUIDE_MODE and found_wall and not found_pattern and self.active_probe_wall_key then
		for _, wall in pairs(self.deposit_walls) do
			if wall.is_deposit_wall and is_alive(wall.unit) then
				found_pattern = self:AddProbeGuideMarkers(desired, wall, true) or found_pattern
			end
		end
	end

	if found_wall and not found_pattern then
		self:LogOnce("waiting_for_wall_pattern", "Found Big Bank deposit wall units, but pattern variables are not readable yet")
	end

	local desired_count = 0

	for _ in pairs(desired) do
		desired_count = desired_count + 1
	end

	if desired_count > 0 then
		self:LogOnce("prepared_marker_count_" .. tostring(desired_count), "Prepared " .. tostring(desired_count) .. " deposit box markers")
	end

	return desired, found_wall
end

BB.DesiredWaypoints = BB.DesiredMarkers
