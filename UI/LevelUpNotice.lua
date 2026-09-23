local LB = select(2, ...)

local Callbacks = LB.Callbacks

local MAX = 3
local GAP = 4
local SPACING = 2
local RISE = 12
local FADE_IN = 0.2
local HOLD = 2.5
local FADE = 0.5
local DURATION = HOLD + FADE
local EVICT = 0.3
local SLIDE_RATE = 12
local SETTLE = 0.05
local PREVIEW_EVERY = 1.5

local SAMPLE = {
	{ class = "MAGE", level = 41 },
	{ class = "WARRIOR", level = 42 },
	{ class = "PRIEST", level = 43 },
	{ class = "DRUID", level = 44 },
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

	frame.elapsed = 0
	frame.offset = 0
	frame.target = 0
	frame.evicted = nil
end

---@class LBLevelUpNotice
---@field pool any
---@field active Frame[] newest first; the newest sits at the anchor
---@field leaving Frame[] pushed out by a newer notice, fading while they slide on
---@field target Region? what the notices attach to
---@field placement LBLevelUpSettings? read at each layout
---@field previewing boolean?
---@field ticker any?
---@field sampleIndex integer
local Notice = {
	pool = CreateFramePool("Frame", UIParent, nil, Reset),
	active = {},
	leaving = {},
	sampleIndex = 0,
}
LB.LevelUpNotice = Notice

---@param elapsed number seconds since the notice appeared
---@return number rise distance travelled away from the bar
---@return number alpha
function Notice:Keyframe(elapsed)
	local progress = math.min(elapsed / DURATION, 1)
	local inverse = 1 - progress
	local rise = RISE * (1 - inverse * inverse * inverse)
	local alpha = math.min(elapsed / FADE_IN, 1)

	if elapsed > HOLD then
		alpha = 1 - math.min((elapsed - HOLD) / FADE, 1)
	end

	return rise, alpha
end

---@param current number
---@param target number
---@param delta number seconds since the last step
---@return number next eased toward the target, landing on it once close
function Notice:Ease(current, target, delta)
	local step = current + (target - current) * (1 - math.exp(-SLIDE_RATE * delta))

	if math.abs(target - step) < SETTLE then
		return target
	end

	return step
end

---@param heights number[] notice heights, newest first
---@return number[] targets each notice's distance from the anchor
function Notice:Slots(heights)
	local targets = {}
	local distance = 0

	for index, height in ipairs(heights) do
		targets[index] = distance
		distance = distance + height + SPACING
	end

	return targets
end

---@param anchor string TOPLEFT, TOP, TOPRIGHT, BOTTOMLEFT, BOTTOM or BOTTOMRIGHT, the point on the bar
---@param direction string UP or DOWN, the way the stack grows
---@return string point the notice's own point that attaches to the anchor
---@return integer sign 1 when growing up, -1 when growing down
function Notice:Place(anchor, direction)
	local side = anchor:match("LEFT") or anchor:match("RIGHT") or ""

	if direction == "UP" then
		return "BOTTOM" .. side, 1
	end

	return "TOP" .. side, -1
end

---@return Region? target the XP bar in independent mode, else the group; either is placed even while hidden
local function Target()
	local group = LB.BarGroup

	if LB.Profile:Get("layout.mode") == "INDEPENDENT" and group.bars.xp then
		return group.bars.xp
	end

	return group.frame
end

---@param frame Frame
local function Build(frame)
	if frame.text then
		return
	end

	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	frame.text:SetPoint("CENTER")
end

---@param frame Frame
local function Style(frame)
	local style = LB.Profile:Get("party.levelUp.text")
	local path = LB.Media:FetchOrDefault("font", style.font)

	if path then
		frame.text:SetFont(path, style.size, OUTLINES[style.outline] or "")
	end

	PixelUtil.SetSize(frame, math.max(frame.text:GetStringWidth(), 1), style.size)
end

---@param frame Frame
local function Paint(frame)
	local target = Notice.target
	local placement = Notice.placement

	if not target or not placement then
		return
	end

	local point, sign = Notice:Place(placement.anchor, placement.direction)
	local rise, alpha = Notice:Keyframe(frame.elapsed)

	if frame.evicted then
		alpha = alpha * (1 - math.min(frame.evicted / EVICT, 1))
	end

	frame:ClearAllPoints()
	frame:SetPoint(point, target, placement.anchor, placement.x, placement.y + sign * (GAP + frame.offset + rise))
	frame:SetAlpha(alpha)
end

function Notice:Layout()
	local heights = {}

	for index, frame in ipairs(self.active) do
		heights[index] = frame:GetHeight()
	end

	local targets = self:Slots(heights)
	local beyond = 0

	for index, frame in ipairs(self.active) do
		frame.target = targets[index]
		beyond = targets[index] + frame:GetHeight() + SPACING
	end

	for _, frame in ipairs(self.leaving) do
		frame.target = math.max(beyond, frame.target)
	end

	self.target = Target()
	self.placement = LB.Profile:Get("party.levelUp")

	for _, frame in ipairs(self.active) do
		Paint(frame)
	end

	for _, frame in ipairs(self.leaving) do
		Paint(frame)
	end
end

---@param list Frame[]
---@param frame Frame
---@return boolean removed
local function Remove(list, frame)
	for index, entry in ipairs(list) do
		if entry == frame then
			table.remove(list, index)

			return true
		end
	end

	return false
end

---@param frame Frame
local function Finish(frame)
	Remove(Notice.active, frame)
	Remove(Notice.leaving, frame)
	Notice.pool:Release(frame)
	Notice:Layout()
end

---@param frame Frame
---@param delta number
local function OnUpdate(frame, delta)
	frame.elapsed = frame.elapsed + delta
	frame.offset = Notice:Ease(frame.offset, frame.target, delta)

	if frame.evicted then
		frame.evicted = frame.evicted + delta
	end

	if frame.elapsed >= DURATION or (frame.evicted and frame.evicted >= EVICT) then
		Finish(frame)

		return
	end

	Paint(frame)
end

---@param name string the member's name, already class-coloured
---@param level integer
function Notice:Show(name, level)
	if #self.active >= MAX then
		local oldest = table.remove(self.active)

		oldest.evicted = 0
		self.leaving[#self.leaving + 1] = oldest
	end

	local frame = self.pool:Acquire()

	Build(frame)

	frame.text:SetTextColor(1, 1, 1, 1)
	frame.text:SetFormattedText(LB.L["%s reached level %d"], name, level)
	frame:SetFrameStrata(LB.Profile:Get("layout.strata") or "LOW")
	Style(frame)

	frame.elapsed = 0
	frame.offset = 0
	frame.target = 0
	table.insert(self.active, 1, frame)

	frame:SetScript("OnUpdate", OnUpdate)
	frame:Show()

	self:Layout()
end

function Notice:ReleaseAll()
	self.pool:ReleaseAll()
	wipe(self.active)
	wipe(self.leaving)
end

---@return boolean
local function Shown()
	local settings = LB.Profile:Get("party.levelUp")

	return settings ~= nil and settings.enabled == true and settings.onScreen == true
end

function Notice:ShowSample()
	if not LB.Settings:IsOpen() then
		self:ClearPreview()

		return
	end

	if not Shown() then
		self:ReleaseAll()

		return
	end

	self.sampleIndex = self.sampleIndex % #SAMPLE + 1

	local entry = SAMPLE[self.sampleIndex]
	local name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.class] or entry.class

	self:Show(
		LB.LevelUp:ColoredName({ key = entry.class, name = name, class = entry.class, level = entry.level }),
		entry.level
	)
end

function Notice:Preview()
	if not LB.Settings:IsOpen() then
		self:ClearPreview()

		return
	end

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
	if type(path) ~= "string" or not path:find("^party") then
		return
	end

	if not Shown() then
		Notice:ReleaseAll()

		return
	end

	if path:find("^party%.levelUp%.text") then
		for _, frame in ipairs(Notice.active) do
			Style(frame)
		end

		for _, frame in ipairs(Notice.leaving) do
			Style(frame)
		end
	end

	Notice:Layout()
end)
