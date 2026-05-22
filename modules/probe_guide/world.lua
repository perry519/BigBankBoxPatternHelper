local BB = _G.BigBankDepositPatternHighlighter
local ctx = BB.shared.probe_guide

local OPENABLE_BOX_MATCH_DISTANCE_SQ = ctx.OPENABLE_BOX_MATCH_DISTANCE_SQ
local distance_sq = ctx.distance_sq
local is_alive = ctx.is_alive
local safe_call = ctx.safe_call

function BB:IsInactiveDepositBox(box)
	if not box then
		return false
	end

	if not is_alive(box.unit) then
		return true
	end

	local interaction = box.interaction
	local active = interaction and interaction.active and safe_call(interaction, "active")

	return active == false
end

function BB:NearestDepositBox(position, max_distance_sq)
	local best_key, best_box, best_distance
	local max_distance = max_distance_sq or OPENABLE_BOX_MATCH_DISTANCE_SQ

	if not position then
		return nil
	end

	for key, box in pairs(self.deposit_boxes or {}) do
		if box.position then
			local distance = distance_sq(position, box.position)

			if distance and distance <= max_distance and (not best_distance or distance < best_distance) then
				best_key = key
				best_box = box
				best_distance = distance
			end
		end
	end

	return best_key, best_box, best_distance
end

function BB:IsLiveBagBox(box)
	if not box or not is_alive(box.unit) or not box.position or not is_alive(box.carry_unit) then
		return false
	end

	local carry_position = box.carry_unit.position and box.carry_unit:position()
	local distance = distance_sq(carry_position, box.position)

	return distance and distance <= OPENABLE_BOX_MATCH_DISTANCE_SQ
end
