local BB = _G.BigBankDepositPatternHighlighter
local config = BB.shared.config
local util = BB.shared.util

local PATTERNS = config.patterns.PATTERNS
local is_alive = util.is_alive
local safe_call = util.safe_call

function BB:GetDamageNumber(damage, name)
	if not damage then
		return nil
	end

	if damage.get_variable then
		local value = safe_call(damage, "get_variable", name)

		if tonumber(value) then
			return tonumber(value)
		end
	end

	local containers = {
		damage._variables,
		damage._vars,
		damage._unit_element_vars,
		damage._sequence_vars
	}

	for _, container in ipairs(containers) do
		if type(container) == "table" then
			local value = container[name]

			if tonumber(value) then
				return tonumber(value)
			end
		end
	end
end

function BB:ReadWallSetup(wall)
	local unit = wall and wall.unit

	if not is_alive(unit) then
		return nil
	end

	local damage = safe_call(unit, "damage")

	return self:GetDamageNumber(damage, "var_type")
end

function BB:ReadWallPatternVariables(wall)
	local unit = wall and wall.unit

	if not is_alive(unit) then
		return nil
	end

	local damage = safe_call(unit, "damage")

	return self:GetDamageNumber(damage, "var_order"),
		self:GetDamageNumber(damage, "var_amount"),
		self:GetDamageNumber(damage, "var_type")
end

function BB:ReadWallPattern(wall)
	local unit = wall and wall.unit

	if not is_alive(unit) then
		return nil
	end

	local order, amount, setup = self:ReadWallPatternVariables(wall)

	if not order or not PATTERNS[order] then
		return nil
	end

	if setup and setup ~= 1 and setup ~= 2 then
		return nil
	end

	amount = math.min(math.max(tonumber(amount) or #PATTERNS[order], 1), #PATTERNS[order])

	return order, amount, setup
end
