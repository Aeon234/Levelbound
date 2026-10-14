local LB = select(2, ...)

local L = LB.L

local OFFLINE_ALPHA = 0.4
local DEFAULT_Y = -150 -- the stack's top below the screen's center, until it is placed in edit mode

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

---@return LBRosterMember[] members the party's, or while editing with nobody to show, the online sample members
local function Members()
	local members = LB.Roster:Visible()

	if #members == 0 and LB.Editing:IsEditing() then
		for _, member in ipairs(LB.Marker:SampleParty()) do
			if not member.offline then
				members[#members + 1] = member
			end
		end
	end

	return PartyBars.Order(members)
end

---Places the stack at its saved position, or at the default until it has one.
---@param frame Frame
---@param position LBFramePosition?
---@param growth "UP" | "DOWN"
local function Place(frame, position, growth)
	frame:ClearAllPoints()

	if position then
		frame:SetPoint(position.point, UIParent, position.point, position.x, position.y)
	elseif growth == "UP" then
		frame:SetPoint("BOTTOM", UIParent, "CENTER", 0, DEFAULT_Y - frame:GetHeight())
	else
		frame:SetPoint("TOP", UIParent, "CENTER", 0, DEFAULT_Y)
	end
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
	local members = Members()
	local height = LB.Border:FixedHeight(border.style) or settings.height
	-- Above-the-bar text stands between one bar and the next.
	local spacing = settings.gap + 2 * LB.Border:Outset(border.style, height, border.width)
		+ LB.TextSlot:AboveRoom("party")
	local tops, total = LB.Layout.Stack(#members, height, spacing, settings.growth)
	local color = LB.Border:Color(border.style, border)
	local mask = LB.Border:EndMask(border.style)
	-- The frame holds the first bar's above-the-bar text too, so its mover covers everything the stack draws.
	local top = #members > 0 and LB.TextSlot:AboveRoom("party") or 0

	frame:SetFrameStrata(LB.Profile:Get("layout.strata"))
	LB:SetPixelSize(frame, settings.width, math.max(top + total, 1))
	Place(frame, settings.screen, settings.growth)

	for index, member in ipairs(members) do
		local bar = self:Bar(index)

		bar:ClearAllPoints()
		bar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -LB.Placement:ToPixel(top + tops[index], LB:Pixel()))
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

---Saves where the stack is now, anchored at the end it grows from, so its first bar stays put as members come
---and go.
---@param left number
---@param bottom number
---@param width number
---@param height number
---@param growth "UP" | "DOWN"
local function Save(left, bottom, width, height, growth)
	local lock = LB.Placement:StackLock(growth)
	local position = LB.Placement:Anchor(left, bottom, width, height, UIParent:GetWidth(), UIParent:GetHeight(), lock)

	LB.Profile:Set("party.bars.screen", position)
end

---@return LBEditTarget[] targets the stack, while the party bars are on
function PartyBars:EditTargets()
	if not self:Enabled() then
		return {}
	end

	self:Refresh()

	if not self.frame or not self.frame:IsShown() then
		return {}
	end

	return {
		{
			key = "partyBars",
			label = L["Party Bars"],
			frame = self.frame,
			fixed = false,
			save = function(left, bottom, width, height)
				Save(left, bottom, width, height, LB.Profile:Get("party.bars.growth"))
			end,
		},
	}
end

LB.Callbacks:Register("Party", PartyBars, function()
	PartyBars:Refresh()
end)

LB.Callbacks:Register("Editing", PartyBars, function()
	PartyBars:Refresh()
end)

LB.Callbacks:Register("Settings", PartyBars, function(_, path)
	local frame = PartyBars.frame

	-- A placed stack keeps its first bar where it is when the growth direction flips.
	if path == "party.bars.growth" and frame and frame:IsShown() and LB.Profile:Get("party.bars.screen") then
		local left, bottom, width, height = frame:GetRect()

		if left then
			Save(left, bottom, width, height, LB.Profile:Get("party.bars.growth"))

			return
		end
	end

	PartyBars:Refresh()
end)
