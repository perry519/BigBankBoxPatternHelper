local BB = _G.BigBankDepositPatternHighlighter

function BB:ClearAllMarkers()
	self:ClearScreenMarkers()
end

function BB:ApplyMarkers()
	if not self:IsBigBank() then
		self:ClearAllMarkers()
		self:SetStateTable("deposit_walls", {})
		self:SetStateTable("deposit_boxes", {})
		return
	end

	local desired = self:DesiredMarkers()
	self:ApplyScreenMarkers(desired)
end
