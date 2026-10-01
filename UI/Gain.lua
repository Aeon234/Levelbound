local LB = select(2, ...)

local Callbacks = LB.Callbacks
local NoticeStack = LB.NoticeStack
local L = LB.L

local GAP = 2
local PREVIEW_AMOUNT = 1234 -- the sample amount that sizes the detached box and settings samples
local PREVIEW_EVERY = 1.5 -- a settings preview adds a detached line this often
local TRAVEL = 20


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
---@field inCombat boolean
local Gain = {
	pool = CreateFramePool("Frame", UIParent, nil, Reset),
	active = {},
	lines = {},
	inCombat = false,
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
---@return number x center of the indicator, in bar coordinates
function Gain:Offset(fraction, barWidth, width, mode)
	if width >= barWidth then
		return barWidth / 2
	end

	local x = mode == "RIGHT_END" and barWidth or fraction * barWidth

	return math.min(math.max(x, width / 2), barWidth - width / 2)
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

---@param id string
---@param amount number
---@param labeled boolean detached lines name their type, in its color
---@return string
local function Text(id, amount, labeled)
	local text = ("+%s"):format(LB.Format:Number(amount))

	if not labeled then
		return text
	end

	local color = TypeColor(id)

	return ("%s %s"):format(text, CreateColor(color[1], color[2], color[3]):WrapTextInColorCode(LB.Model:Label(id, true)))
end

---@param frame Frame
---@param labeled boolean
local function Style(frame, labeled)
	local style = Settings().text
	local size = style.size * 2
	local color = TypeColor(frame.id)

	frame.arrow:SetTexture(LB.Media.textures.gainArrow)
	frame.arrow:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	LB:SetPixelSize(frame.arrow, size, size)

	LB.Media:SetFont(frame.text, Settings().text)
	frame.text:SetTextColor(style.color[1], style.color[2], style.color[3], style.color[4] or 1)
	frame.text:SetText(Text(frame.id, frame.amount, labeled))

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
---@param above boolean? always above the bar, never flipped below it near the screen's top
local function Anchor(frame, bar, x, height, above)
	local top = bar:GetTop()
	local screen = UIParent:GetTop()

	frame:ClearAllPoints()

	if not above and top and screen and top + height + TRAVEL > screen then
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

---@return number width the detached stack's widest line
---@return number height a full stack's height
function Gain:DetachedSize()
	local settings = Settings()
	local size = settings.text.size * 2
	local measure = self.box.measure
	local width = 1

	LB.Media:SetFont(measure, settings.text)

	for _, id in ipairs(LB.Model:Order()) do
		measure:SetText(Text(id, PREVIEW_AMOUNT, true))
		width = math.max(width, measure:GetStringWidth())
	end

	return size + GAP + width, NoticeStack:BoxHeight(size)
end

function Gain:PlaceBox()
	local width, height = self:DetachedSize()

	NoticeStack:PlaceBox(self.box, Settings().screen, width, height, 1)
end

-- A settings preview's own detached stack, growing from an edge of its target the saved way.
local sampleTarget

---@return LBNoticeAnchor?
local function SampleAnchor()
	if not sampleTarget then
		return nil
	end

	local up = Settings().direction == "UP"
	local point = up and "BOTTOMLEFT" or "TOPLEFT"

	return { point = point, relativeTo = sampleTarget, relativePoint = point, x = 0, y = 0, sign = up and 1 or -1 }
end

Gain.sampleStack = NoticeStack:Create(SampleAnchor, function(frame)
	frame.id = nil
	frame.amount = 0
end)

---Plays detached lines in a settings preview: a new line every 1.5 s, cycling through `ids`, until
---`StopDetachedSample`.
---@param target Frame
---@param ids string[]
function Gain:PlayDetachedSample(target, ids)
	self:StopDetachedSample()
	sampleTarget = target

	local index = 0

	local function Push()
		if #ids == 0 then
			return
		end

		index = index % #ids + 1

		local frame = self.sampleStack:Acquire()

		frame.id = ids[index]
		frame.amount = PREVIEW_AMOUNT * index
		Build(frame)
		frame:SetParent(target)
		frame:SetFrameLevel(target:GetFrameLevel() + 20)
		Style(frame, true)
		self.sampleStack:Push(frame)
	end

	Push()
	self.sampleTicker = C_Timer.NewTicker(PREVIEW_EVERY, Push)
end

function Gain:StopDetachedSample()
	if self.sampleTicker then
		self.sampleTicker:Cancel()
		self.sampleTicker = nil
	end

	self.sampleStack:ReleaseAll()
	sampleTarget = nil
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

---Draws an indicator of `amount` on a bar outside the bar group, for a settings preview, whatever the saved
---placement: held at full strength, or with `animate` playing its rise and fade once. Draws nothing while the
---indicator is off.
---@param bar LBBar
---@param amount number
---@param animate boolean?
---@return Frame? frame
function Gain:Hold(bar, amount, animate)
	if not Settings().enabled then
		self:Release(bar)

		return nil
	end

	local frame = self.active[bar]

	if not frame then
		frame = self.pool:Acquire()
		self.active[bar] = frame
	end

	Build(frame)

	frame.bar = bar
	frame.id = bar.id
	frame.amount = amount
	frame.elapsed = animate and 0 or NoticeStack.HELD
	frame.held = not animate

	frame:SetParent(bar)
	frame:SetFrameLevel(bar:GetFrameLevel() + 20)
	Style(frame, false)

	local fraction = bar.snapshot and LB.Progress.Fraction(bar.snapshot) or 0
	local width, height = frame:GetSize()

	Anchor(frame, bar, self:Offset(fraction, bar:GetWidth(), width, Settings().position), height, true)

	frame:SetScript("OnUpdate", animate and OnUpdate or nil)
	frame:Show()
	Paint(frame, frame.elapsed)

	return frame
end

---@param bar LBBar
function Gain:OnProgress(bar)
	local source = LB.Model:Source(bar.id)

	if not source or LB.Preview:Covers(bar.id) then
		return
	end

	self:Show(bar, source.delta or 0)
end

---@return Frame? box the detached stack's box, placed, or nil while the indicators sit on the bars
local function DetachedBox()
	local settings = Settings()

	if not settings.enabled or not settings.detached then
		return nil
	end

	Gain:PlaceBox()

	return Gain.box
end

---@return LBEditTarget[] targets the detached box, when there is one
function Gain:EditTargets()
	local box = DetachedBox()

	if not box then
		return {}
	end

	return {
		{
			key = "gain",
			label = L["Gain Indicator"],
			frame = box,
			fixed = false,
			save = function(left, bottom, width, height)
				local screenWidth, screenHeight = UIParent:GetWidth(), UIParent:GetHeight()

				LB.Profile:Set("gain.screen", LB.Placement:Anchor(left, bottom, width, height, screenWidth, screenHeight))
			end,
		},
	}
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
end)
