local LB = select(2, ...)

local Callbacks = LB.Callbacks

---@class LBBarGroup
---@field frame Frame?
---@field bars table<string, LBBar>
---@field built boolean
local BarGroup = {
	bars = {},
	built = false,
}
LB.BarGroup = BarGroup

function BarGroup:Create()
	if self.frame then
		return
	end

	local layout = LB.Profile:Get("layout")
	local frame = CreateFrame("Frame", "LevelboundBarGroup", UIParent)

	frame:SetFrameStrata(layout.strata)
	frame:Hide()

	self.frame = frame

	self:ApplyLayout()
end

---@param parent Frame
---@param id string
---@return LBBar
function BarGroup:Bar(parent, id)
	local bar = self.bars[id]

	if not bar then
		bar = LB.Bar:Create(parent, id)
		self.bars[id] = bar
	end

	return bar
end

function BarGroup:ApplyLayout()
	local frame = self.frame

	if not frame then
		return
	end

	local layout = LB.Profile:Get("layout")
	local position = layout.position
	local visible = LB.Model:VisibleOrder()

	PixelUtil.SetSize(frame, layout.width, math.max(layout.height * math.max(#visible, 1), 1))
	frame:ClearAllPoints()
	frame:SetPoint(position.point, UIParent, position.point, position.x, position.y)
	frame:SetFrameStrata(layout.strata)

	local offset = 0

	for _, id in ipairs(visible) do
		local bar = self:Bar(frame, id)

		bar:SetGeometry(layout.width, layout.height)
		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -offset)

		offset = offset + layout.height
	end
end

function BarGroup:Refresh()
	local frame = self.frame

	if not frame then
		return
	end

	local wanted = {}

	for _, id in ipairs(LB.Model:VisibleOrder()) do
		wanted[id] = true
	end

	for id, bar in pairs(self.bars) do
		if not wanted[id] and bar:IsShown() then
			local source = LB.Model:Source(id)

			if source and source.atMaxLevel then
				bar:FadeOut(function()
					self:ApplyLayout()
				end)
			else
				bar:Hide()
			end
		end
	end

	self:ApplyLayout()

	for id in pairs(wanted) do
		local snapshot = LB.Model:Get(id)

		if snapshot then
			local bar = self:Bar(frame, id)
			local first = not bar:IsShown()

			bar:Appear()
			bar:ApplyAppearance()
			bar:SetSnapshot(snapshot, not first)
		end
	end

	frame:SetShown(next(wanted) ~= nil)
end

---@param id string
function BarGroup:Update(id)
	local bar = self.bars[id]
	local snapshot = LB.Model:Get(id)

	if bar and snapshot and bar:IsShown() then
		bar:SetSnapshot(snapshot, true)
	end
end

Callbacks:Register("Progress", BarGroup, function(_, id)
	BarGroup:Update(id)
end)

Callbacks:Register("Layout", BarGroup, function()
	BarGroup:Refresh()
end)

Callbacks:Register("Settings", BarGroup, function()
	BarGroup:ApplyLayout()

	for _, bar in pairs(BarGroup.bars) do
		bar:ApplyAppearance()
	end
end)
