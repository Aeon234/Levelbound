local LB = select(2, ...)

local L = LB.L

local VALUE_COLOR = { 1, 1, 1 }
local TITLE_COLOR = { 1, 0.82, 0 }
local LABEL_COLOR = { 1, 1, 1 }
local SECTION_COLOR = { 0.8, 0.72, 0.58 }
local DIM_COLOR = { 0.6, 0.6, 0.6 }
local HINT_COLOR = { 0.1, 1, 0.1 }
local AHEAD_COLOR = { 0.1, 1, 0.1 }
local BEHIND_COLOR = { 1, 0.3, 0.3 }
local GAP = 4
local DIVIDER = "Interface\\Common\\UI-TooltipDivider-Transparent"
local DIVIDER_HEIGHT = 10
local ICON_SIZE = 0 -- inline icons take the line's text height

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

	if not LB.Layout.Independent(LB.Profile:Get("layout")) and group then
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

---@class LBTooltipIcons
---@field line boolean icons beside the Rested and completed-quest rows
---@field section boolean icons beside section headers
---@field member boolean the class icon before a party member's name
---@field share boolean the icon before the share hint
Tooltip.icons = {
	line = true,
	section = true,
	member = true,
	share = true,
}

---@param color number[]
---@param text string
---@return string
local function Paint(color, text)
	return CreateColor(color[1], color[2], color[3]):WrapTextInColorCode(text)
end

---@param kind string a key of `Tooltip.icons`
---@param texture string? a `Media.textures` key
---@param text string
---@return string text with the icon before it, while that kind of icon is on
local function WithIcon(kind, texture, text)
	local path = texture and LB.Media.textures[texture]

	if not path or not Tooltip.icons[kind] then
		return text
	end

	return ("|T%s:%d|t %s"):format(path, ICON_SIZE, text)
end

---@param text string
---@return string text in capitals when it is plain ASCII; other scripts and accented letters stay as written
function Tooltip.Header(text)
	if text:find("[\128-\255]") then
		return text
	end

	return text:upper()
end

---@param value string
---@param fraction number
---@return string value followed by its share, dimmed so the number reads first
local function WithShare(value, fraction)
	return ("%s  %s"):format(value, Paint(DIM_COLOR, ("(%s)"):format(LB.Format:Percent(fraction))))
end

---A full-width rule on its own line, as Blizzard's social tooltips draw one.
---@param tip GameTooltip
local function Divider(tip)
	tip:AddLine(" ", 0, 0, 0, true)

	if tip.AddTexture and Enum.TooltipTextureAnchor and Enum.TooltipTextureAnchor.All then
		tip:AddTexture(DIVIDER, {
			height = DIVIDER_HEIGHT,
			anchor = Enum.TooltipTextureAnchor.All,
			margin = { left = 0, right = 0, top = -2, bottom = -2 },
		})
	end
end

---@class LBTooltipSection
---@field label string?
---@field icon string? a `Media.textures` key drawn beside the label
---@field lines { [1]: string, [2]: string, [3]: string? }[]

---@param label string?
---@param icon string?
---@return LBTooltipSection
local function Section(label, icon)
	return { label = label, icon = icon, lines = {} }
end

---@param section LBTooltipSection
---@param label string
---@param value string
---@param icon string? a `Media.textures` key drawn beside the label
local function Add(section, label, value, icon)
	section.lines[#section.lines + 1] = { label, value, icon }
end

---Adds a section below a divider; an empty section adds nothing.
---@param tip GameTooltip
---@param section LBTooltipSection
local function Flush(tip, section)
	if #section.lines == 0 then
		return
	end

	Divider(tip)

	if section.label then
		local header = WithIcon("section", section.icon, Tooltip.Header(section.label))

		tip:AddLine(header, SECTION_COLOR[1], SECTION_COLOR[2], SECTION_COLOR[3])
	end

	for _, line in ipairs(section.lines) do
		tip:AddDoubleLine(
			WithIcon("line", line[3], line[1]),
			line[2],
			LABEL_COLOR[1],
			LABEL_COLOR[2],
			LABEL_COLOR[3],
			VALUE_COLOR[1],
			VALUE_COLOR[2],
			VALUE_COLOR[3]
		)
	end
end

---@param tip GameTooltip
---@param left string
---@param right string?
---@param rightColor number[]?
local function Title(tip, left, right, rightColor)
	local color = rightColor or VALUE_COLOR

	tip:AddDoubleLine(left, right or "", TITLE_COLOR[1], TITLE_COLOR[2], TITLE_COLOR[3], color[1], color[2], color[3])
end

---@param snapshot LBSnapshot
---@return number
local function Share(snapshot)
	return LB.Progress.Fraction(snapshot) or 0
end

---@param snapshot LBSnapshot
---@param amount number
---@return number
local function ShareOf(snapshot, amount)
	return LB.Progress.Part(snapshot, amount) or 0
end

---Experience tooltips split Progress from Bonus XP; other types keep one Progress section with plain labels.
---@param tip GameTooltip
---@param snapshot LBSnapshot
---@param source LBSource? the player's XP source, for the quests still in the log
---@param experience boolean? the snapshot is experience, the player's or a party member's
---@param compared string? how far ahead or behind the player a party member is
local function Progress(tip, snapshot, source, experience, compared)
	local Format = LB.Format
	local appearance = LB.Profile:Get("appearance")
	local overlays = snapshot.overlays
	local share = Share(snapshot)
	local progress = Section(L["Progress"])
	local bonus = experience and Section(L["Bonus XP"]) or progress

	Add(progress, experience and L["Current XP"] or L["Current"],
		WithShare(Format:Value("VALUE", snapshot, source), share))
	Add(progress, experience and L["XP Remaining"] or L["Remaining"],
		WithShare(Format:Value("REMAINING", snapshot, source), 1 - share))

	if overlays.rested > 0 then
		local rested = Paint(appearance.restedColor, Format:Number(overlays.rested))

		Add(bonus, L["Rested XP"], WithShare(rested, ShareOf(snapshot, overlays.rested)), "tooltipRested")
	end

	if overlays.quest > 0 then
		local completed = Paint(appearance.questColor, Format:Number(overlays.quest))

		Add(bonus, L["Ready to Turn In"], WithShare(completed, ShareOf(snapshot, overlays.quest)), "tooltipQuest")
		Add(bonus, L["After Turn-In"], Format:Value("PERCENT_WITH_QUESTS", snapshot, source))
	end

	if source and source.IncompleteQuestXP then
		local incomplete = source:IncompleteQuestXP()

		if incomplete > 0 then
			Add(bonus, L["Quests in Log"], WithShare(Format:Number(incomplete), ShareOf(snapshot, incomplete)))
		end
	end

	if compared then
		Add(progress, L["Compared with You"], compared)
	end

	Flush(tip, progress)

	if bonus ~= progress then
		Flush(tip, bonus)
	end
end

---@param pace LBTooltipSection
---@param rate number? XP per second
---@param seconds number? time to level
local function AddPace(pace, rate, seconds)
	local Format = LB.Format

	Add(pace, L["XP per Hour"], Format:Number(rate and LB.Progress.PerHour(rate)))
	Add(pace, L["Est. Time to Level"], Format:Duration(seconds))
end

---@param tip GameTooltip
---@param source LBSource?
local function ClickHint(tip, source)
	if not LB.Profile:Get("tooltip.clickActions") then
		return
	end

	local hint = source and source.ClickHint and source:ClickHint()

	Divider(tip)

	if hint then
		tip:AddLine(hint, HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
	end

	tip:AddLine(WithIcon("share", "tooltipShare", L["Shift-Click to Share"]), HINT_COLOR[1], HINT_COLOR[2],
		HINT_COLOR[3])
end

---@param tip GameTooltip
---@param snapshot LBSnapshot
---@param source LBSource?
function Tooltip:XP(tip, snapshot, source)
	local Format = LB.Format
	local rate = LB.Session:Rate()

	Title(tip, COMBAT_XP_GAIN, UNIT_LEVEL_TEMPLATE:format(snapshot.level or 0))
	Progress(tip, snapshot, source, true)

	local pace = Section(L["Pace"], "tooltipPace")

	Add(pace, L["Time This Level"], Format:Value("LEVEL_TIME", snapshot, source))
	Add(pace, L["Session Time"], Format:Value("SESSION_TIME", snapshot, source))
	AddPace(pace, rate, LB.Session:TimeToLevel())
	Flush(tip, pace)

	if not rate then
		tip:AddLine(L["Pace estimates appear after an XP gain."], DIM_COLOR[1], DIM_COLOR[2], DIM_COLOR[3], true)
	end

	ClickHint(tip, source)
end

---@param tip GameTooltip
---@param snapshot LBSnapshot
---@param source LBSource?
function Tooltip:Generic(tip, snapshot, source)
	local standing = snapshot.standing

	if not standing or standing == "" or standing == snapshot.label then
		standing = nil
	end

	Title(tip, LB.Format:Value("NAME", snapshot, source), standing, snapshot.color)
	Progress(tip, snapshot, source)

	if snapshot.flags.readyToUpgrade then
		tip:AddLine(L["Ready to Upgrade"], 0, 1, 0)
	end

	if source and source.Tooltip then
		source:Tooltip(tip)
	end

	ClickHint(tip, source)
end

---@param mine LBSnapshot?
---@param theirs LBSnapshot
---@return string? text how far ahead or behind the player the member is, colored
local function Compared(mine, theirs)
	local difference = mine and LB.Progress.Distance(mine, theirs)

	if not difference then
		return nil
	end

	local distance = math.abs(difference)

	if distance < 0.01 then
		return L["Level with you"]
	end

	local ahead = difference > 0
	local text

	if distance >= 1 then
		text = (ahead and L["%.1f levels ahead"] or L["%.1f levels behind"]):format(distance)
	else
		text = (ahead and L["%d%% of a level ahead"] or L["%d%% of a level behind"]):format(math.floor(distance * 100))
	end

	return Paint(ahead and AHEAD_COLOR or BEHIND_COLOR, text)
end

---@param member LBRosterMember
---@param nameColor number[]
---@return string name the member's name in `nameColor`, after their class icon while member icons are on
local function MemberName(member, nameColor)
	local name = Paint(nameColor, member.name)

	if not Tooltip.icons.member then
		return name
	end

	local class = member.class or (member.unit and LB:Readable(select(2, UnitClass(member.unit)), nil))
	local icon = LB.ClassIcon:Markup(class, ICON_SIZE)

	return icon ~= "" and ("%s %s"):format(icon, name) or name
end

-- One block per party member; a stack of markers lists each, a blank line apart.
---@param tip GameTooltip
---@param member LBRosterMember
---@param nameColor number[]
function Tooltip:Member(tip, member, nameColor)
	local Format = LB.Format
	local snapshot = member.snapshot
	local rate = member.state.rate

	if tip:NumLines() > 0 then
		tip:AddLine(" ")
	end

	Title(tip, MemberName(member, nameColor), UNIT_LEVEL_TEMPLATE:format(snapshot.level))
	Progress(tip, snapshot, nil, true, Compared(LB.Model:Get("xp"), snapshot))

	local pace = Section(L["Pace"], "tooltipPace")

	if rate then
		AddPace(pace, rate, LB.Progress.TimeToLevel(snapshot, rate))
	end

	Flush(tip, pace)

	if member.offline then
		tip:AddLine(FRIENDS_LIST_OFFLINE, DIM_COLOR[1], DIM_COLOR[2], DIM_COLOR[3])
	elseif member.updated then
		local ago = Format:Duration(math.max(GetTime() - member.updated, 1))

		tip:AddLine(L["Updated %s ago"]:format(ago), DIM_COLOR[1], DIM_COLOR[2], DIM_COLOR[3])
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
