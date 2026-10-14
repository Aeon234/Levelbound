local LB = select(2, ...)

local OFFLINE_ALPHA = 0.4
local DEFAULT_Y = -150 -- below the screen's center, until the stack is placed in edit mode

---Standalone party bars: one experience bar per party member, stacked in a frame of their own.
---@class LBPartyBars
---@field frame Frame?
---@field bars LBBar[] by place in the stack
local PartyBars = {
	bars = {},
}
LB.PartyBars = PartyBars

---@param member LBRosterMember
---@return integer place the member's party slot, party1 first; members without one sort last
local function Slot(member)
	local index = type(member.unit) == "string" and member.unit:match("^party(%d)$")

	return tonumber(index) or math.huge
end

---Orders members by party slot, then by name.
---@param members LBRosterMember[]
---@return LBRosterMember[] ordered a new list
function PartyBars.Order(members)
	local ordered = {}

	for index, member in ipairs(members) do
		ordered[index] = member
	end

	table.sort(ordered, function(a, b)
		local left, right = Slot(a), Slot(b)

		if left ~= right then
			return left < right
		end

		return a.name < b.name
	end)

	return ordered
end

---@return boolean
function PartyBars:Enabled()
	local party = LB.Profile:Get("party")

	return party.markers == true and party.display == "BARS"
end

function PartyBars:Create()
	if self.frame then
		return
	end

	local frame = CreateFrame("Frame", "LevelboundPartyBars", UIParent)

	frame:Hide()
	self.frame = frame
end

---@param index integer
---@return LBBar
function PartyBars:Bar(index)
	local bar = self.bars[index]

	if not bar then
		bar = LB.Bar:Create(self.frame, "party")
		bar.border = LB.Border:Create(bar)
		self.bars[index] = bar
	end

	return bar
end

---@param bar LBBar
---@param member LBRosterMember
local function Show(bar, member)
	local same = bar.member ~= nil and bar.member.name == member.name
	local changed = bar.snapshot ~= member.snapshot

	bar.member = member

	if not same then
		bar.snapshot = nil
		bar.level = 0
	end

	if changed or not same then
		bar:SetSnapshot(member.snapshot, same, same)
	end

	bar:SetAlpha(member.offline and OFFLINE_ALPHA or 1)
	bar:Show()
end

---Draws a bar for each visible member, or hides the stack when the bars are off or nobody has one.
function PartyBars:Refresh()
	if not self:Enabled() then
		if self.frame then
			self.frame:Hide()
		end

		return
	end

	self:Create()

	local frame = self.frame
	local settings = LB.Profile:Get("party.bars")
	local border = LB.Profile:Get("appearance.border")
	local members = self.Order(LB.Roster:Visible())
	local height = LB.Border:FixedHeight(border.style) or settings.height
	-- Above-the-bar text stands between one bar and the next.
	local spacing = settings.gap + 2 * LB.Border:Outset(border.style, height, border.width)
		+ LB.TextSlot:AboveRoom("party")
	local tops, total = LB.Layout.Stack(#members, height, spacing, settings.growth)
	local color = LB.Border:Color(border.style, border)
	local mask = LB.Border:EndMask(border.style)
	local point = settings.growth == "UP" and "BOTTOM" or "TOP"

	frame:SetFrameStrata(LB.Profile:Get("layout.strata"))
	frame:ClearAllPoints()
	frame:SetPoint(point, UIParent, "CENTER", 0, DEFAULT_Y)
	LB:SetPixelSize(frame, settings.width, math.max(total, 1))

	for index, member in ipairs(members) do
		local bar = self:Bar(index)

		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -LB.Placement:ToPixel(tops[index], LB:Pixel()))
		bar:SetGeometry(settings.width, height)
		bar.border:Apply(border.style, color, height, border.width)
		bar:SetEndMasks(mask, true, true)
		Show(bar, member)
		bar:ApplyAppearance()
	end

	for index = #members + 1, #self.bars do
		local bar = self.bars[index]

		bar.member = nil
		bar.snapshot = nil
		bar:Hide()
	end

	frame:SetShown(#members > 0)
end

LB.Callbacks:Register("Party", PartyBars, function()
	PartyBars:Refresh()
end)

LB.Callbacks:Register("Settings", PartyBars, function()
	PartyBars:Refresh()
end)
