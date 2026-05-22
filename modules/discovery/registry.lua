local BB = _G.BigBankDepositPatternHighlighter
local config = BB.shared.config
local util = BB.shared.util

local ALL_DEPOSIT_SLOTS = config.patterns.ALL_DEPOSIT_SLOTS
local ALL_PATTERN_SLOTS = config.patterns.ALL_PATTERN_SLOTS
local OPENABLE_BOX_MATCH_DISTANCE_SQ = config.marker.OPENABLE_BOX_MATCH_DISTANCE_SQ
local WALL_UNIT_KEYS = config.game_ids.WALL_UNIT_KEYS
local distance_sq = util.distance_sq
local is_alive = util.is_alive
local safe_call = util.safe_call
local unit_key = util.unit_key

local PATTERN_SLOT_SET = {}

for _, slot in ipairs(ALL_PATTERN_SLOTS) do
	PATTERN_SLOT_SET[slot] = true
end

local function has_stale_deposit_walls(self)
	for _, wall in pairs(self.deposit_walls or {}) do
		if wall.is_deposit_wall and not is_alive(wall.unit) then
			return true
		end
	end

	return false
end

function BB:IsDepositWallUnit(unit)
	if not is_alive(unit) then
		return false
	end

	local key = unit_key(unit)

	return key and WALL_UNIT_KEYS[key] == true
end

function BB:RegisterPotentialDepositWall(unit)
	if not self:IsBigBank() or not self:IsDepositWallUnit(unit) then
		return
	end

	local key = safe_call(unit, "key") or tostring(unit)

	if not self.deposit_walls[key] and has_stale_deposit_walls(self) and self.ResetDiscoveryState then
		self:ResetDiscoveryState()
	end

	if self.deposit_walls[key] then
		self.deposit_walls[key].unit = unit
		return
	end

	self.deposit_walls[key] = {
		unit = unit,
		key = key,
		is_deposit_wall = true,
		box_slots = {}
	}

	self:LogOnce("wall_" .. tostring(key), "Registered Big Bank deposit wall " .. tostring(key))
end

function BB:GetSnapPosition(unit, slot)
	if not is_alive(unit) or not unit.get_object then
		return nil
	end

	local names = {
		string.format("snap_%02d", slot),
		"snap_" .. tostring(slot),
		string.format("a_snap_%02d", slot),
		string.format("g_snap_%02d", slot)
	}

	for _, name in ipairs(names) do
		local ok, object = pcall(unit.get_object, unit, Idstring(name))

		if ok and object and object.position then
			return object:position()
		end
	end
end

function BB:GetSlotPosition(wall, slot)
	return wall and self:GetSnapPosition(wall.unit, slot)
end

function BB:IsDepositInteraction(unit, interaction)
	if not interaction then
		return false
	end

	local tweak_id = interaction.tweak_data

	if tweak_id == "pick_lock_deposit_transport" or tweak_id == "safety_deposit" then
		return true
	end

	if tweak_id == "open_door_with_keys" and self:IsDepositWallUnit(unit) then
		return true
	end

	local data = interaction._tweak_data

	return data and data.is_lockpicking and self:IsDepositWallUnit(unit)
end

function BB:NearestSlot(wall, position, slots, max_distance_sq)
	local best_slot, best_distance

	if not wall or not is_alive(wall.unit) or not position then
		return nil
	end

	for _, slot in ipairs(slots or ALL_DEPOSIT_SLOTS) do
		local slot_position = self:GetSlotPosition(wall, slot)

		if slot_position then
			local distance = distance_sq(position, slot_position)

			if distance and (not best_distance or distance < best_distance) then
				best_distance = distance
				best_slot = slot
			end
		end
	end

	if best_distance and best_distance <= (max_distance_sq or 40000) then
		return best_slot, best_distance
	end
end

function BB:NearestWallSlot(position, slots, max_distance_sq)
	local best_wall, best_slot, best_distance

	if not position then
		return nil
	end

	for _, wall in pairs(self.deposit_walls or {}) do
		if wall.is_deposit_wall and is_alive(wall.unit) then
			local slot, distance = self:NearestSlot(wall, position, slots, max_distance_sq)

			if distance and (not best_distance or distance < best_distance) then
				best_wall = wall
				best_slot = slot
				best_distance = distance
			end
		end
	end

	if best_distance then
		return best_wall, best_slot, best_distance
	end
end

function BB:NearestWallDepositSlot(position)
	return self:NearestWallSlot(position, ALL_DEPOSIT_SLOTS, OPENABLE_BOX_MATCH_DISTANCE_SQ)
end

function BB:RegisterDepositBox(unit, interaction)
	if not self:IsBigBank() or not is_alive(unit) or not self:IsDepositInteraction(unit, interaction) then
		return
	end

	local key = safe_call(unit, "key") or tostring(unit)
	local previous = self.deposit_boxes[key]
	local position = interaction.interact_position and interaction:interact_position()
		or unit.position and unit:position()

	if not position then
		return
	end

	local box = {
		unit = unit,
		key = key,
		position = position,
		interaction = interaction,
		opened = previous and previous.opened,
		was_active = previous and previous.was_active
	}

	local active = interaction.active and safe_call(interaction, "active")

	if active ~= false then
		box.was_active = true
	end

	self.deposit_boxes[key] = box

	local wall, slot = self:NearestWallDepositSlot(position)

	if wall and slot then
		box.wall = wall
		box.slot = slot

		if PATTERN_SLOT_SET[slot] then
			wall.box_slots = wall.box_slots or {}
			wall.box_slots[slot] = box
		end

		if not previous or previous.wall ~= wall or previous.slot ~= slot then
			self:SetTimer("next_update_t", 0)
		end

		if PATTERN_SLOT_SET[slot] then
			self:LogOnce("box_slot_" .. tostring(wall.key) .. "_" .. tostring(slot), "Mapped live deposit box " .. tostring(key) .. " to pattern slot " .. tostring(slot))
		end
	elseif previous then
		self:SetTimer("next_update_t", 0)
	end
end
