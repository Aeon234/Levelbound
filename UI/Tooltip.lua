local LB = select(2, ...)

local L = LB.L

local VALUE_COLOR = { 1, 1, 1 }
local LABEL_COLOR = { 1, 0.82, 0 }
local GAP = 4

---@class LBTooltipClearance
---@field top number the highest edge to stay clear of
---@field bottom number the lowest

---@class LBTooltip
---@field driver Frame follows the cursor only while a Levelbound tooltip is up
---@field owner Frame? the region the shown tooltip belongs to
---@field clearance LBTooltipClearance?
---@field cursorX number? the cursor position the tooltip was last placed for
local Tooltip = {
	driver = CreateFrame("Frame"),
}
LB.Tooltip = Tooltip

---@param bar LBBar
---@return LBTooltipClearance? clearance the bars and their text, which the tooltip must not cover
function Tooltip:Clearance(bar)
	local group = LB.BarGroup.frame
	local frames = { bar }

	if LB.Profile:Get("layout.mode") ~= "INDEPENDENT" and group then
		frames = { group }

		for _, other in pairs(LB.BarGroup.bars) do
			if other:IsShown() then
				frames[#frames + 1] = other
			end
		end
	end

	local top, bottom

	for _, frame in ipairs(frames) do
		local scale = frame:GetEffectiveScale()
		local frameTop, frameBottom = frame:GetTop(), frame:GetBottom()
		local textTop, textBottom = LB.TextSlot:Extent(frame)

		if frameTop and frameBottom then
			top = math.max(top or frameTop * scale, frameTop * scale, textTop or 0)
			bottom = math.min(bottom or frameBottom * scale, frameBottom * scale, textBottom or math.huge)
		end
	end

	if not top or not bottom then
		return nil
	end

	return { top = top, bottom = bottom }
end

---@param force boolean? place even if the cursor has not moved
function Tooltip:Place(force)
	local tip = GameTooltip
	local clearance = self.clearance

	if not clearance or tip:GetOwner() ~= self.owner or not tip:IsShown() then
		self:Stop()

		return
	end

	local cursorX = GetCursorPosition()

	if not force and self.cursorX and math.abs(cursorX - self.cursorX) < 1 then
		return
	end

	self.cursorX = cursorX

	local scale = tip:GetEffectiveScale()
	local screenWidth = UIParent:GetWidth() * UIParent:GetEffectiveScale()
	local screenHeight = UIParent:GetHeight() * UIParent:GetEffectiveScale()
	local width, height = tip:GetWidth() * scale, tip:GetHeight() * scale
	local gap = GAP * scale
	local left = math.min(math.max(cursorX - width / 2, 0), math.max(screenWidth - width, 0))
	local roomAbove = clearance.top + gap + height <= screenHeight
	local roomBelow = clearance.bottom - gap - height >= 0
	local inTopThird = (clearance.top + clearance.bottom) / 2 > screenHeight * 2 / 3
	local below = (inTopThird and roomBelow) or not roomAbove

	tip:ClearAllPoints()

	if below and roomBelow then
		tip:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / scale, (clearance.bottom - gap) / scale)
	else
		tip:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left / scale, (clearance.top + gap) / scale)
	end
end

---@param owner Frame
---@param clearance LBTooltipClearance?
function Tooltip:Follow(owner, clearance)
	GameTooltip:Show()

	if not clearance then
		return
	end

	self.owner = owner
	self.clearance = clearance
	self.cursorX = nil

	self:Place(true)
	self.driver:SetScript("OnUpdate", function()
		Tooltip:Place()
	end)
end

function Tooltip:Stop()
	self.driver:SetScript("OnUpdate", nil)
	self.owner = nil
	self.clearance = nil
end

---@param tip GameTooltip
---@param label string
---@param value string
local function Line(tip, label, value)
	tip:AddDoubleLine(
		label,
		value,
		LABEL_COLOR[1],
		LABEL_COLOR[2],
		LABEL_COLOR[3],
		VALUE_COLOR[1],
		VALUE_COLOR[2],
		VALUE_COLOR[3]
	)
end

---@param tip GameTooltip
---@param snapshot LBSnapshot
---@param source LBSource?
function Tooltip:XP(tip, snapshot, source)
	local Format = LB.Format

	tip:AddLine(COMBAT_XP_GAIN)
	Line(tip, LEVEL, Format:Value("LEVEL", snapshot, source))
	Line(
		tip,
		XP,
		("%s (%s)"):format(Format:Value("VALUE", snapshot, source), Format:Value("PERCENT", snapshot, source))
	)
	Line(tip, L["Remaining"], Format:Value("REMAINING", snapshot, source))

	if snapshot.overlays.rested > 0 then
		local fraction = snapshot.max > 0 and (snapshot.overlays.rested / snapshot.max) or 0

		Line(tip, L["Rested"], ("%s (%s)"):format(Format:Number(snapshot.overlays.rested), Format:Percent(fraction)))
	end

	if snapshot.overlays.quest > 0 then
		local fraction = snapshot.max > 0 and (snapshot.overlays.quest / snapshot.max) or 0

		Line(
			tip,
			L["Quests ready"],
			("%s (%s)"):format(Format:Number(snapshot.overlays.quest), Format:Percent(fraction))
		)
		Line(tip, L["After turn-in"], Format:Value("PERCENT_WITH_QUESTS", snapshot, source))
	end

	if source and source.IncompleteQuestXP then
		local incomplete = source:IncompleteQuestXP()

		if incomplete > 0 then
			Line(tip, L["Quests in log"], Format:Number(incomplete))
		end
	end

	local questOverflow, restedOverflow = LB.Model:Overflow(snapshot)

	if questOverflow + restedOverflow > 0 then
		Line(tip, L["Past the level-up"], Format:Number(questOverflow + restedOverflow))
	end

	tip:AddLine(" ")
	Line(tip, L["Time this level"], Format:Value("LEVEL_TIME", snapshot, source))
	Line(tip, L["Session"], Format:Value("SESSION_TIME", snapshot, source))
	Line(tip, L["XP per hour"], Format:Value("XP_PER_HOUR", snapshot, source))
	Line(tip, L["Time to level"], Format:Value("TIME_TO_LEVEL", snapshot, source))
end

---@param tip GameTooltip
---@param snapshot LBSnapshot
---@param source LBSource?
function Tooltip:Generic(tip, snapshot, source)
	local Format = LB.Format

	tip:AddLine(Format:Value("NAME", snapshot, source))

	if snapshot.standing and snapshot.standing ~= "" and snapshot.standing ~= snapshot.label then
		Line(tip, L["Standing"], snapshot.standing)
	end

	Line(
		tip,
		XP,
		("%s (%s)"):format(Format:Value("VALUE", snapshot, source), Format:Value("PERCENT", snapshot, source))
	)
	Line(tip, L["Remaining"], Format:Value("REMAINING", snapshot, source))

	if snapshot.flags.readyToUpgrade then
		tip:AddLine(L["Ready to upgrade"], 0, 1, 0)
	end

	if source and source.Tooltip then
		source:Tooltip(tip)
	end
end

---@param bar LBBar
---@param snapshot LBSnapshot
function Tooltip:Show(bar, snapshot)
	if not LB.Profile:Get("tooltip.enabled") then
		return
	end

	local source = LB.Model:Source(bar.id)

	GameTooltip:SetOwner(bar, "ANCHOR_NONE")
	GameTooltip:ClearLines()

	if bar.id == "xp" then
		self:XP(GameTooltip, snapshot, source)
	else
		self:Generic(GameTooltip, snapshot, source)
	end

	self:Follow(bar, self:Clearance(bar))
end

---@param owner Frame? hides only a tooltip this region owns; nil hides whatever is up
function Tooltip:Hide(owner)
	self:Stop()

	if not owner or GameTooltip:GetOwner() == owner then
		GameTooltip:Hide()
	end
end
