local LB = select(2, ...)

local L = LB.L

local VALUE_COLOR = { 1, 1, 1 }
local LABEL_COLOR = { 1, 0.82, 0 }

---@class LBTooltip
local Tooltip = {}
LB.Tooltip = Tooltip

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
	Line(
		tip,
		XP,
		("%s (%s)"):format(Format:Value("VALUE", snapshot, source), Format:Value("PERCENT", snapshot, source))
	)
	Line(tip, L["Remaining"], Format:Value("REMAINING", snapshot, source))
end

---@param bar LBBar
---@param snapshot LBSnapshot
function Tooltip:Show(bar, snapshot)
	if not LB.Profile:Get("tooltip.enabled") then
		return
	end

	local source = LB.Model:Source(bar.id)

	GameTooltip:SetOwner(bar, "ANCHOR_CURSOR")
	GameTooltip:ClearLines()

	if bar.id == "xp" then
		self:XP(GameTooltip, snapshot, source)
	else
		self:Generic(GameTooltip, snapshot, source)
	end

	GameTooltip:Show()
end

function Tooltip:Hide()
	GameTooltip:Hide()
end
