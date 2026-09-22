local LB = select(2, ...)

---@class LBBlizzardBar
---@field hidden boolean?
local BlizzardBar = {}
LB.BlizzardBar = BlizzardBar

function BlizzardBar:Hide()
	if self.hidden or not LB.can.statusTrackingBar then
		return
	end

	local holder = CreateFrame("Frame")

	holder:Hide()
	StatusTrackingBarManager:SetParent(holder)

	for _, frame in ipairs({
		StatusTrackingBarManager,
		StatusTrackingBarManager.MainStatusTrackingBarContainer,
		StatusTrackingBarManager.SecondaryStatusTrackingBarContainer,
	}) do
		if frame then
			frame:UnregisterAllEvents()
		end
	end

	self.hidden = true
end
