local BB = _G.BigBankDepositPatternHighlighter

local M = {}

function M.is_alive(unit)
	return unit and (not alive or alive(unit))
end

function M.safe_call(object, method, ...)
	if not object or not object[method] then
		return nil
	end

	local ok, result = pcall(object[method], object, ...)

	if ok then
		return result
	end
end

function M.unit_key(unit)
	local name = M.safe_call(unit, "name")
	return name and name.key and name:key()
end

function M.current_level_id()
	if not managers or not managers.job or not managers.job.current_level_id then
		return nil
	end

	return managers.job:current_level_id()
end

function M.waypoint_id(wall_key, slot)
	return "bbdph_" .. tostring(wall_key) .. "_" .. tostring(slot)
end

function M.distance_sq(a, b)
	if not a or not b or not mvector3 then
		return nil
	end

	if mvector3.distance_sq then
		return mvector3.distance_sq(a, b)
	end

	if mvector3.distance then
		local distance = mvector3.distance(a, b)
		return distance and distance * distance
	end
end

function M.normalized_copy(vector)
	if not vector or not mvector3 then
		return nil
	end

	local copy = Vector3()

	mvector3.set(copy, vector)

	if mvector3.length_sq and mvector3.length_sq(copy) <= 0.000001 then
		return nil
	end

	mvector3.normalize(copy)

	return copy
end

if BB then
	BB.shared = BB.shared or {}
	BB.shared.util = M
end

return M
