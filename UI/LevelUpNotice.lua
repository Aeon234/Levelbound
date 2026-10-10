local LB = select(2, ...)

local Callbacks = LB.Callbacks
local NoticeStack = LB.NoticeStack

local GAP = 4
local PREVIEW_EVERY = 1.5

local SAMPLE = {
	{ class = "MAGE", level = 41 },
	{ class = "WARRIOR", level = 42 },
	{ class = "PRIEST", level = 43 },
	{ class = "DRUID", level = 44 },
}

---@class LBLevelUpNotice
---@field stack LBNoticeStack
---@field box Frame where the notices sit when detached from the bars
---@field sampleTicker any? adds a notice to a settings preview's sample
---@field sampleIndex integer
---@field cramped boolean? a side anchor has no room before the screen's edge, so the stack sits above the bar
local Notice = {
	sampleIndex = 0,
}
LB.LevelUpNotice = Notice

---@return LBLevelUpSettings
local function Settings()
	return LB.Profile:Get("party.levelUp")
end

---@return Region? target the XP bar in independent mode, else the group; either is placed even while hidden
local function Target()
	local group = LB.BarGroup

	if LB.Layout.Independent(LB.Profile:Get("layout")) and group.bars.xp then
		return group.bars.xp
	end

	return group.frame
end

---@param settings LBLevelUpSettings
---@return boolean sideways the lines sit side by side, sliding outward, rather than stacked
local function Sideways(settings)
	return settings.animation == "SLIDE"
end

---@param settings LBLevelUpSettings
---@return string direction the detached stack's growth: UP or DOWN, or RIGHT or LEFT side by side
local function DetachedDirection(settings)
	return Sideways(settings) and settings.across or settings.direction
end

---Places the stack at its saved anchor on a bar: 4 px from a top or bottom point along the growth direction, or
---beside the bar, clear of the border, with its first line centered on the bar's side. Beside the bar, Slide Outward
---sets the lines side by side, growing away from the bar.
---@param target Region
---@param placement LBLevelUpSettings
---@param cramped boolean? a side anchor falls back to above the bar at that side's end, growing up
---@return LBNoticeAnchor
function Notice:Attach(target, placement, cramped)
	local anchor, direction = placement.anchor, placement.direction
	local beside = anchor == "LEFT" or anchor == "RIGHT"

	if beside and cramped then
		anchor, direction, beside = "TOP" .. anchor, "UP", false
	end

	local point, sign = NoticeStack:Place(anchor, direction)
	local x, y = placement.x, placement.y + sign * GAP

	if beside then
		local gap = GAP + LB.TextSlot:BorderReach(nil)
		local right = anchor == "RIGHT"

		x = placement.x + (right and gap or -gap)

		if Sideways(placement) then
			return { point = right and "LEFT" or "RIGHT", relativeTo = target, relativePoint = anchor, x = x,
				y = placement.y, sign = right and 1 or -1, across = true }
		end

		y = placement.y - sign * placement.text.size / 2
	end

	return { point = point, relativeTo = target, relativePoint = anchor, x = x, y = y, sign = sign }
end

---@return LBNoticeAnchor?
local function Anchor()
	local placement = Settings()

	if placement.detached then
		return NoticeStack:BoxAnchor(Notice.box, DetachedDirection(placement))
	end

	local target = Target()

	if not target then
		return nil
	end

	return Notice:Attach(target, placement, Notice.cramped)
end

Notice.stack = NoticeStack:Create(Anchor)
Notice.box = NoticeStack:CreateBox("LevelboundLevelUpNotices")

---@param frame Frame
local function Build(frame)
	if frame.text then
		return
	end

	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.text:SetPoint("CENTER")
end

---@param fontString FontString
---@return number
local function LineHeight(fontString)
	return math.max(fontString:GetStringHeight(), Settings().text.size)
end

---@param frame Frame
local function Style(frame)
	LB.Media:SetFont(frame.text, Settings().text)
	LB:SetPixelSize(frame, math.max(frame.text:GetStringWidth(), 1), LineHeight(frame.text))
end

---@param entry { class: string, level: integer }
---@return string name colored by class
local function SampleName(entry)
	local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.class] or entry.class

	return LB.LevelUp:ColoredName({ key = entry.class, name = name, class = entry.class, level = entry.level })
end

---@return number width the widest sample notice in the saved font
function Notice:SampleWidth()
	local measure = self.box.measure
	local width = 1

	LB.Media:SetFont(measure, Settings().text)

	for _, entry in ipairs(SAMPLE) do
		measure:SetFormattedText(LB.L["%s reached level %d"], SampleName(entry), entry.level)
		width = math.max(width, measure:GetStringWidth())
	end

	return width
end

---@return number reach how far the notices beside the bar extend past the bar's side, before the horizontal offset
function Notice:SideReach()
	local width = self:SampleWidth()

	return GAP + LB.TextSlot:BorderReach(nil) + (Sideways(Settings()) and NoticeStack:BoxHeight(width) or width)
end

---Resolves a side anchor against the screen as the gain indicator does: beside the bar while a notice fits between
---the bar and the screen's edge, otherwise above the bar at that side's end.
---@return boolean? cramped true when a side anchor has no room beside the bar
function Notice:Cramped()
	local anchor = Settings().anchor
	local target = Target()
	local left, right = target and target:GetLeft(), target and target:GetRight()

	if (anchor ~= "LEFT" and anchor ~= "RIGHT") or not left or not right then
		return nil
	end

	local gap = GAP + LB.TextSlot:BorderReach(nil)

	return LB.Gain:Placement("OUTSIDE_" .. anchor, left, right, UIParent:GetWidth(), self:SampleWidth(), gap) == nil
end

---@return number width
---@return number height the detached box: a full stack, its lines stacked or side by side
function Notice:Footprint()
	local width = self:SampleWidth()
	local line = LineHeight(self.box.measure)

	if Sideways(Settings()) then
		return NoticeStack:BoxHeight(width), line
	end

	return width, NoticeStack:BoxHeight(line)
end

function Notice:PlaceBox()
	local width, height = self:Footprint()

	NoticeStack:PlaceBox(self.box, Settings().screen, width, height, -1)
end

---@param name string the member's name, already class-colored
---@param level integer
function Notice:Show(name, level)
	local frame = self.stack:Acquire()

	Build(frame)

	frame.text:SetTextColor(1, 1, 1, 1)
	frame.text:SetFormattedText(LB.L["%s reached level %d"], name, level)
	frame:SetFrameStrata(LB.Profile:Get("layout.strata"))
	Style(frame)

	if Settings().detached then
		self:PlaceBox()
	else
		self.cramped = self:Cramped()
	end

	self.stack:Push(frame)
end

function Notice:ReleaseAll()
	self.stack:ReleaseAll()
end

-- A settings preview's own stack, placed around its sample bar the way the real stack is placed around the bars.
local sampleTarget

---@return LBNoticeAnchor?
local function SampleAnchor()
	if not sampleTarget then
		return nil
	end

	local placement = Settings()

	if not placement.detached then
		return Notice:Attach(sampleTarget, placement)
	end

	-- Detached, the lines grow from the target's own edge, inside it.
	local direction = DetachedDirection(placement)

	if direction == "RIGHT" or direction == "LEFT" then
		return NoticeStack:BoxAnchor(sampleTarget, direction)
	end

	local point, sign = NoticeStack:Place("TOP", direction)

	return { point = point, relativeTo = sampleTarget, relativePoint = point, x = 0, y = sign * GAP, sign = sign }
end

Notice.sampleStack = NoticeStack:Create(SampleAnchor)

---Shows sample notices around a preview's bar: three held lines, or with `playing` a new line every 1.5 s until
---`StopPreviewSample`. No chat and no sound.
---@param target Frame
---@param playing boolean
---@return Frame[] lines the stack's current lines
function Notice:ShowPreviewSample(target, playing)
	self:StopPreviewSample()
	sampleTarget = target

	local function Push(held)
		self.sampleIndex = self.sampleIndex % #SAMPLE + 1

		local entry = SAMPLE[self.sampleIndex]
		local frame = self.sampleStack:Acquire()

		Build(frame)
		frame:SetParent(target)
		frame:SetFrameLevel(target:GetFrameLevel() + 20)
		frame.text:SetTextColor(1, 1, 1, 1)
		frame.text:SetFormattedText(LB.L["%s reached level %d"], SampleName(entry), entry.level)
		Style(frame)
		self.sampleStack:Push(frame, held)
	end

	if playing then
		Push(false)
		self.sampleTicker = C_Timer.NewTicker(PREVIEW_EVERY, function()
			Push(false)
		end)
	else
		for _ = 1, 3 do
			Push(true)
		end
	end

	return self.sampleStack.active
end

function Notice:StopPreviewSample()
	if self.sampleTicker then
		self.sampleTicker:Cancel()
		self.sampleTicker = nil
	end

	self.sampleStack:ReleaseAll()
	sampleTarget = nil
end

---@return boolean
local function Shown()
	local settings = Settings()

	return settings ~= nil and settings.enabled == true and settings.onScreen == true
end

---@return Frame? box the detached stack's box, placed, or nil while the notices sit on the bars
local function DetachedBox()
	if not Shown() or not Settings().detached then
		return nil
	end

	Notice:PlaceBox()

	return Notice.box
end

---@return LBEditTarget[] targets the detached box, when there is one
function Notice:EditTargets()
	local box = DetachedBox()

	if not box then
		return {}
	end

	return {
		{
			key = "levelUp",
			label = LB.L["Level-Up Notices"],
			frame = box,
			fixed = false,
			save = function(left, bottom, width, height)
				local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()

				LB.Profile:Set(
					"party.levelUp.screen",
					LB.Placement:Anchor(left, bottom, width, height, screenWidth, screenHeight)
				)
			end,
		},
	}
end

Callbacks:Register("Settings", Notice, function(_, path)
	if type(path) == "string" and not path:find("^party") then
		return
	end

	if not Shown() then
		Notice:ReleaseAll()

		return
	end

	if path == nil or path:find("^party%.levelUp%.text") then
		for _, frame in ipairs(Notice.stack.active) do
			Style(frame)
		end

		for _, frame in ipairs(Notice.stack.leaving) do
			Style(frame)
		end
	end

	if Settings().detached then
		Notice:PlaceBox()
	else
		Notice.cramped = Notice:Cramped()
	end

	Notice.stack:Layout()
end)

