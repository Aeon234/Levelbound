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
---@field previewing boolean?
---@field ticker any?
---@field sampleIndex integer
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

---@return LBNoticeAnchor?
local function Anchor()
	local placement = Settings()

	if placement.detached then
		return NoticeStack:BoxAnchor(Notice.box, placement.direction)
	end

	local target = Target()

	if not target then
		return nil
	end

	local point, sign = NoticeStack:Place(placement.anchor, placement.direction)

	return {
		point = point,
		relativeTo = target,
		relativePoint = placement.anchor,
		x = placement.x,
		y = placement.y + sign * GAP,
		sign = sign,
	}
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
---@return string name coloured by class
local function SampleName(entry)
	local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.class] or entry.class

	return LB.LevelUp:ColoredName({ key = entry.class, name = name, class = entry.class, level = entry.level })
end

function Notice:PlaceBox()
	local settings = Settings()
	local measure = self.box.measure
	local width = 1

	LB.Media:SetFont(measure, Settings().text)

	for _, entry in ipairs(SAMPLE) do
		measure:SetFormattedText(LB.L["%s reached level %d"], SampleName(entry), entry.level)
		width = math.max(width, measure:GetStringWidth())
	end

	NoticeStack:PlaceBox(self.box, settings.screen, width, NoticeStack:BoxHeight(LineHeight(measure)), -1)
end

---@param name string the member's name, already class-coloured
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
	end

	self.stack:Push(frame)
end

function Notice:ReleaseAll()
	self.stack:ReleaseAll()
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

function Notice:ShowSample()
	if LB.Editing:Demo() ~= "party" then
		self:ClearPreview()

		return
	end

	if not Shown() then
		self:ReleaseAll()

		return
	end

	self.sampleIndex = self.sampleIndex % #SAMPLE + 1

	local entry = SAMPLE[self.sampleIndex]

	self:Show(SampleName(entry), entry.level)
end

function Notice:Preview()
	self.previewing = true

	if not self.ticker then
		self.ticker = C_Timer.NewTicker(PREVIEW_EVERY, function()
			Notice:ShowSample()
		end)
	end

	self:ShowSample()
end

function Notice:ClearPreview()
	if not self.previewing then
		return
	end

	self.previewing = false

	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end

	self:ReleaseAll()
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
	end

	Notice.stack:Layout()
end)

Callbacks:Register("Editing", Notice, function()
	if LB.Editing:Demo() ~= "party" then
		Notice:ClearPreview()
	elseif not Notice.previewing then
		Notice:Preview()
	end
end)
