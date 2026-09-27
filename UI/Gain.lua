local LB = select(2, ...)

local Callbacks = LB.Callbacks
local NoticeStack = LB.NoticeStack
local L = LB.L

local GAP = 2
local PREVIEW_AMOUNT = 1234
local PREVIEW_MERGE = 0.1
local PREVIEW_EVERY = 1.5
local TRAVEL = 20

local SAMPLE_TYPES = { "xp", "reputation", "honor" }

local LABELS = {
	xp = L["Exp"],
	petxp = L["Pet Exp"],
	reputation = L["Rep"],
	honor = HONOR,
	house = L["House Exp"],
	endeavor = L["Endeavor"],
	travelers = MONTHLY_ACTIVITIES_POINTS,
}

local OUTLINES = {
	NONE = "",
	OUTLINE = "OUTLINE",
	THICKOUTLINE = "THICKOUTLINE",
	SLUG = "SLUG",
	SLUG_OUTLINE = "SLUG, OUTLINE",
	SLUG_THICKOUTLINE = "SLUG, THICKOUTLINE",
}

---@param frame Frame
local function Reset(_, frame)
	frame:SetScript("OnUpdate", nil)
	frame:Hide()
	frame:ClearAllPoints()
	frame:SetParent(UIParent)

	frame.bar = nil
	frame.id = nil
	frame.amount = 0
	frame.elapsed = 0
	frame.held = nil
end

---@class LBGain
---@field pool any the indicators drawn on the bars
---@field active table<LBBar, Frame>
---@field stack LBNoticeStack the grouped indicators when detached
---@field lines table<string, Frame> the detached line showing each progress type
---@field box Frame where the detached indicators sit
---@field moverKey string
---@field inCombat boolean
---@field previewing boolean?
---@field ticker any? adds a detached sample every PREVIEW_EVERY seconds while the Gain page is open
---@field sampleIndex integer
---@field editing boolean?
local Gain = {
	pool = CreateFramePool("Frame", UIParent, nil, Reset),
	active = {},
	lines = {},
	moverKey = "gain",
	inCombat = false,
	sampleIndex = 0,
	editing = false,
}
LB.Gain = Gain

---@return LBGainSettings
local function Settings()
	return LB.Profile:Get("gain")
end

---@return LBNoticeAnchor
local function StackAnchor()
	return NoticeStack:BoxAnchor(Gain.box, Settings().direction)
end

Gain.stack = NoticeStack:Create(StackAnchor, function(frame)
	frame.id = nil
	frame.amount = 0
end, function(frame)
	if frame.id and Gain.lines[frame.id] == frame then
		Gain.lines[frame.id] = nil
	end
end)
Gain.box = NoticeStack:CreateBox("LevelboundGainIndicators")

---@param fraction number 0-1
---@param barWidth number
---@param width number the indicator's own width
---@param mode string "FILL_EDGE" or "RIGHT_END"
---@return number x centre of the indicator, in bar coordinates
function Gain:Offset(fraction, barWidth, width, mode)
	if width >= barWidth then
		return barWidth / 2
	end

	local x = mode == "RIGHT_END" and barWidth or fraction * barWidth

	return math.min(math.max(x, width / 2), barWidth - width / 2)
end

---@param id string a progress type
---@return string label the short name a detached line shows
function Gain:Label(id)
	return LABELS[id] or id
end

---@param frame Frame
local function Build(frame)
	if frame.arrow then
		return
	end

	frame.content = CreateFrame("Frame", nil, frame)
	frame.arrow = frame.content:CreateTexture(nil, "OVERLAY")
	frame.text = frame.content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
end

---@param id string
---@return LBColor
local function TypeColor(id)
	local colors = Settings().colors

	return colors[id] or colors.xp
end

---@param fontString FontString
local function Font(fontString)
	local style = Settings().text
	local path = LB.Media:FetchOrDefault("font", style.font)

	if path then
		fontString:SetFont(path, style.size, OUTLINES[style.outline] or "")
	end
end

---@param id string
---@param amount number
---@param labelled boolean detached lines name their type, in its colour
---@return string
local function Text(id, amount, labelled)
	local text = ("+%s"):format(LB.Format:Number(amount))

	if not labelled then
		return text
	end

	local color = TypeColor(id)

	return ("%s %s"):format(text, CreateColor(color[1], color[2], color[3]):WrapTextInColorCode(Gain:Label(id)))
end

---@param frame Frame
---@param labelled boolean
local function Style(frame, labelled)
	local style = Settings().text
	local size = style.size * 2
	local color = TypeColor(frame.id)

	frame.arrow:SetTexture(LB.Media.textures.gainArrow)
	frame.arrow:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	LB:SetPixelSize(frame.arrow, size, size)

	Font(frame.text)
	frame.text:SetTextColor(style.color[1], style.color[2], style.color[3], style.color[4] or 1)
	frame.text:SetText(Text(frame.id, frame.amount, labelled))

	local textWidth = frame.text:GetStringWidth()
	local onLeft = style.side == "LEFT"
	local arrowX = onLeft and (textWidth + GAP) or 0
	local textX = (onLeft and 0 or (size + GAP)) + (style.x or 0)

	frame.arrow:ClearAllPoints()
	frame.arrow:SetPoint("BOTTOMLEFT", frame.content, "BOTTOMLEFT", arrowX, 0)
	frame.text:ClearAllPoints()
	frame.text:SetPoint("LEFT", frame.content, "BOTTOMLEFT", textX, size / 2 + (style.y or 0))

	LB:SetPixelSize(frame, math.max(size + GAP + textWidth, 1), size)
	frame.content:SetAllPoints(frame)
end

---@param frame Frame
local function Finish(frame)
	local bar = frame.bar

	if bar then
		Gain.active[bar] = nil
	end

	Gain.pool:Release(frame)
end

---@param frame Frame
---@param elapsed number seconds into the animation
local function Paint(frame, elapsed)
	local rise, alpha = NoticeStack:Keyframe(elapsed)

	frame.content:ClearAllPoints()
	frame.content:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, rise)
	frame.content:SetSize(frame:GetSize())
	frame:SetAlpha(alpha)
end

---@param frame Frame
---@param delta number
local function OnUpdate(frame, delta)
	frame.elapsed = frame.elapsed + delta

	Paint(frame, frame.elapsed)

	if frame.elapsed >= NoticeStack.DURATION then
		Finish(frame)
	end
end

---@param frame Frame
---@param bar LBBar
---@param height number the indicator's own height
local function Anchor(frame, bar, x, height)
	local top = bar:GetTop()
	local screen = UIParent:GetTop()

	frame:ClearAllPoints()

	if top and screen and top + height + TRAVEL > screen then
		frame:SetPoint("BOTTOM", bar, "BOTTOMLEFT", x, -(height + GAP))

		return
	end

	frame:SetPoint("BOTTOM", bar, "TOPLEFT", x, GAP)
end

---@return boolean
local function Blocked()
	local settings = Settings()

	return not settings.enabled or (settings.hideInCombat and (Gain.inCombat or InCombatLockdown()))
end

function Gain:PlaceBox()
	local settings = Settings()
	local size = settings.text.size * 2
	local measure = self.box.measure
	local width = 1

	Font(measure)

	for id in pairs(LABELS) do
		measure:SetText(Text(id, PREVIEW_AMOUNT, true))
		width = math.max(width, measure:GetStringWidth())
	end

	NoticeStack:PlaceBox(self.box, settings.screen, size + GAP + width, NoticeStack:BoxHeight(size), 1)
end

---@param id string
---@param amount number
---@param held boolean?
function Gain:ShowDetached(id, amount, held)
	local frame = self.lines[id]

	if frame and not frame.evicted then
		frame.amount = frame.amount + amount
		Style(frame, true)
		self.stack:Restart(frame)

		return
	end

	frame = self.stack:Acquire()
	frame.id = id
	frame.amount = amount
	self.lines[id] = frame

	Build(frame)
	frame:SetFrameStrata(LB.Profile:Get("layout.strata"))
	Style(frame, true)
	self:PlaceBox()
	self.stack:Push(frame, held)
end

---@param bar LBBar
---@param amount number
---@param held boolean? stop at full strength and stay there, for editing the settings
function Gain:Show(bar, amount, held)
	if amount <= 0 or Blocked() then
		return
	end

	local settings = Settings()

	if settings.detached then
		self:ShowDetached(bar.id, amount, held)

		return
	end

	local frame = self.active[bar]

	if not frame then
		frame = self.pool:Acquire()
		frame.amount = 0
		self.active[bar] = frame
	end

	Build(frame)

	frame.bar = bar
	frame.id = bar.id
	frame.amount = frame.amount + amount
	frame.elapsed = held and NoticeStack.HELD or 0
	frame.held = held == true

	frame:SetParent(bar)
	frame:SetFrameLevel(bar:GetFrameLevel() + 20)
	Style(frame, false)

	local snapshot = bar.snapshot or LB.Model:Get(bar.id)
	local fraction = snapshot and LB.Progress.Fraction(snapshot) or 0
	local width, height = frame:GetSize()

	Anchor(frame, bar, self:Offset(fraction, bar:GetWidth(), width, settings.position), height)

	frame:SetScript("OnUpdate", not frame.held and OnUpdate or nil)
	frame:Show()

	Paint(frame, frame.elapsed)
end

---@param bar LBBar
function Gain:OnProgress(bar)
	local source = LB.Model:Source(bar.id)

	if not source or LB.Preview:Covers(bar.id) then
		return
	end

	self:ClearPreview()
	self:Show(bar, source.delta or 0)
end

function Gain:StopTicker()
	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

---@return string[] ids the types this client can track, so a preview never shows one it cannot
local function SampleTypes()
	local ids = {}

	for _, id in ipairs(LB.Model:Order()) do
		local source = LB.Model:Source(id)
		local ok, capable = false, false

		if source then
			ok, capable = pcall(source.Capability, source)
		end

		if ok and capable then
			ids[#ids + 1] = id
		end
	end

	return ids
end

function Gain:ShowSample()
	local ids = SampleTypes()

	if LB.Editing:Demo() ~= "gain" or not Settings().detached or #ids == 0 then
		self:ClearPreview()

		return
	end

	self.sampleIndex = self.sampleIndex % #ids + 1
	self:ShowDetached(ids[self.sampleIndex], PREVIEW_AMOUNT)
end

function Gain:Preview()
	local group = LB.BarGroup
	local frame = group.frame

	if not frame or not frame:IsShown() or LB.Editing:Demo() ~= "gain" then
		self:ClearPreview()

		return
	end

	self.previewing = true

	if Settings().detached then
		self.pool:ReleaseAll()
		wipe(self.active)

		if not self.ticker then
			self.ticker = C_Timer.NewTicker(PREVIEW_EVERY, function()
				Gain:ShowSample()
			end)

			self:ShowSample()
		end

		return
	end

	self:StopTicker()
	self:ReleaseAll()

	if group.settling then
		return
	end

	for _, bar in pairs(group.bars) do
		if bar:IsShown() then
			self:Show(bar, PREVIEW_AMOUNT, true)
		end
	end
end

function Gain:OnLayoutSettled()
	if not self.previewing then
		return
	end

	if LB.Editing:Demo() == "gain" then
		self:Preview()
	else
		self:ClearPreview()
	end
end

function Gain:ClearPreview()
	if not self.previewing then
		return
	end

	self.previewing = false

	self:StopTicker()
	self:ReleaseAll()
end

---@return Frame? box the detached stack's box, placed, or nil while the indicators sit on the bars
function Gain:DetachedBox()
	local settings = Settings()

	if not settings.enabled or not settings.detached then
		return nil
	end

	self:PlaceBox()

	return self.box
end

---@param position LBFramePosition
function Gain:SavePosition(position)
	LB.Profile:Set("gain.screen", position)
end

---@param editing boolean
function Gain:SetEditing(editing)
	if self.editing == editing then
		return
	end

	self.editing = editing

	self:ReleaseAll()

	if not editing or not self:DetachedBox() then
		return
	end

	for index = #SAMPLE_TYPES, 1, -1 do
		self:ShowDetached(SAMPLE_TYPES[index], PREVIEW_AMOUNT, true)
	end
end

---@param bar LBBar
function Gain:Release(bar)
	local frame = self.active[bar]

	if not frame then
		return
	end

	self.active[bar] = nil
	self.pool:Release(frame)
end

function Gain:ReleaseAll()
	self.pool:ReleaseAll()
	wipe(self.active)
	self.stack:ReleaseAll()
	wipe(self.lines)
end

---@param inCombat boolean
function Gain:SetCombat(inCombat)
	self.inCombat = inCombat

	if inCombat and LB.Profile:Get("gain.hideInCombat") then
		self:ReleaseAll()
	end
end

LB.Events:Register("PLAYER_REGEN_DISABLED", Gain, function()
	Gain:SetCombat(true)
end)

LB.Events:Register("PLAYER_REGEN_ENABLED", Gain, function()
	Gain:SetCombat(false)
end)

Callbacks:Register("Settings", Gain, function(_, path)
	if not LB.Profile:Get("gain.enabled") then
		Gain:ReleaseAll()

		return
	end

	if path ~= nil and (type(path) ~= "string" or not path:find("^gain")) then
		return
	end

	if Settings().detached then
		for _, frame in ipairs(Gain.stack.active) do
			Style(frame, true)
		end

		Gain:PlaceBox()
		Gain.stack:Layout()
	end

	if LB.Editing:Demo() == "gain" then
		LB.Events:Merge("gain:preview", PREVIEW_MERGE, function()
			Gain:Preview()
		end)
	end
end)

Callbacks:Register("Editing", Gain, function()
	Gain:SetEditing(LB.Editing:MoversShowing())

	if LB.Editing:Demo() ~= "gain" then
		Gain:ClearPreview()
	elseif not Gain.previewing then
		Gain:Preview()
	end
end)
