local BB = _G.BigBankDepositPatternHighlighter
local util = BB.shared.util

local is_alive = util.is_alive

function BB:ScanWorld()
	if not self:IsBigBank() or not World or not World.find_units_quick or not World.make_slot_mask then
		return
	end

	local mask = World:make_slot_mask(
		0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
		10, 11, 12, 13, 14, 15, 16, 17, 18, 19,
		20, 21, 22, 23, 24, 25, 26, 27, 28, 29,
		30, 31, 32, 33, 34, 35, 36, 37, 38, 39
	)
	local units = World:find_units_quick("all", mask)

	for _, unit in ipairs(units or {}) do
		self:RegisterPotentialDepositWall(unit)
	end

	for _, unit in ipairs(units or {}) do
		local interaction = is_alive(unit) and unit.interaction and unit:interaction()

		if self:IsDepositInteraction(unit, interaction) then
			self:RegisterDepositBox(unit, interaction)
		end
	end

	if self.ObserveCarryUnit then
		for _, unit in ipairs(units or {}) do
			self:ObserveCarryUnit(unit)
		end
	end

	self.last_world_scan_t = self.current_t or 0
end
