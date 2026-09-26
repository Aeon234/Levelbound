local LB = select(2, ...)

local LEVEL_FILL = 4
local LEVEL_QUEST = 3
local LEVEL_RESTED = 2
local LEVEL_BACKGROUND = 1

local FLAT = [[Interface\Buttons\WHITE8X8]]
local WHITE = { 1, 1, 1, 1 }

local SWEEP_UP = 0.25

local FILL_RATE = 0.25
local FILL_MIN = 0.5
local FILL_MAX = 1
local LEVEL_RATE = 0.5
local FADE = 0.5

local CORE_WIDTH = 2
local FLARE_WIDTH = 24
local FLARE_PEAK = 0.8
local FLARE_HOT = 1
local FLARE_REST = 0.35
local FLARE_COOL = 1

local SHIMMER = 1.4
local SHIMMER_WIDTH = 90
local SHIMMER_ALPHA = 0.55

local LEVEL_DIVIDERS = LEVEL_FILL + 2
local DIVIDERS = 9
local DIVIDER_MIN_SEGMENT = 16
local DIVIDER_EDGE_SLICE = 0.125
local NOTCH = { 0, 0, 0, 0.5 }
local DIVIDED = { xp = true, petxp = true }

---@class LBBar : Frame
---@field id string
---@field clip Frame reveals the full-width fill art; only its width changes, so the art never stretches
---@field content Frame
---@field fillTexture Texture
---@field quest StatusBar
---@field rested StatusBar
---@field background StatusBar
---@field spark Texture the flare's core line
---@field flare Texture
---@field shimmer Texture[] the two halves of the sweeping highlight
---@field border LBBorderFrame?
---@field driver Frame
---@field alphaDriver Frame
---@field level number last drawn level
---@field values number[]
---@field sweeping boolean? lvl up sweep animation running
---@field fading boolean?
---@field pending number[]? target the sweep settles on
---@field hovered boolean?
---@field sparkEnabled boolean?
---@field heat number flare brightness, hot while the fill grows and resting otherwise
---@field growing boolean? a gain or level-up is moving the fill
---@field shimmerElapsed number?
---@field effectDriver Frame
---@field textSuppressed boolean?
---@field snapshot LBSnapshot?
---@field markerPool any?
---@field markers table?
---@field markerShown table<string, Frame>?
---@field markerLayer Frame?
---@field markerAlpha number?
---@field markerFade number?
local BarMixin = {}
LB.BarMixin = BarMixin

---@param parent Frame
---@param level integer offset above the parent
---@return StatusBar
local function CreateLayer(parent, level)
	local layer = CreateFrame("StatusBar", nil, parent)

	layer:SetAllPoints(parent)
	layer:SetFrameLevel(parent:GetFrameLevel() + level)
	layer:SetMinMaxValues(0, 1)
	layer:SetValue(0)

	return layer
end

---@param color LBColor
---@return number r
---@return number g
---@return number b
---@return number a
local function Unpack(color)
	return color[1], color[2], color[3], color[4] or 1
end

---@param statusBar StatusBar
---@param color LBColor
local function SetFlat(statusBar, color)
	statusBar:SetStatusBarTexture(FLAT)
	statusBar:GetStatusBarTexture():SetVertexColor(Unpack(color))
end

---@class LBBarFactory
local Bar = {}
LB.Bar = Bar

---@param parent Frame
---@param id string
---@return LBBar
function Bar:Create(parent, id)
	---@type LBBar
	local bar = CreateFrame("Frame", nil, parent)

	Mixin(bar, BarMixin)

	bar.id = id
	bar.level = 0
	bar.values = { 0, 0, 0 }
	bar.driver = CreateFrame("Frame", nil, bar)
	bar.alphaDriver = CreateFrame("Frame", nil, bar)
	bar.effectDriver = CreateFrame("Frame", nil, bar)
	bar.heat = FLARE_REST

	bar.background = CreateLayer(bar, LEVEL_BACKGROUND)
	bar.rested = CreateLayer(bar, LEVEL_RESTED)
	bar.quest = CreateLayer(bar, LEVEL_QUEST)

	bar.background:SetValue(1)

	bar.clip = CreateFrame("Frame", nil, bar)
	bar.clip:SetPoint("TOPLEFT")
	bar.clip:SetPoint("BOTTOMLEFT")
	bar.clip:SetFrameLevel(bar:GetFrameLevel() + LEVEL_FILL)
	bar.clip:SetClipsChildren(true)

	bar.content = CreateFrame("Frame", nil, bar.clip)
	bar.content:SetAllPoints(bar)

	bar.fillTexture = bar.content:CreateTexture(nil, "ARTWORK")
	bar.fillTexture:SetAllPoints()

	bar.shimmer = {
		bar.content:CreateTexture(nil, "ARTWORK", nil, 2),
		bar.content:CreateTexture(nil, "ARTWORK", nil, 2),
	}
	bar.flare = bar.content:CreateTexture(nil, "OVERLAY")
	bar.spark = bar.content:CreateTexture(nil, "OVERLAY", nil, 1)

	for _, texture in ipairs({ bar.shimmer[1], bar.shimmer[2], bar.flare, bar.spark }) do
		texture:SetTexture(FLAT)
		texture:SetBlendMode("ADD")
		texture:Hide()
	end

	bar.shimmer[1]:SetWidth(SHIMMER_WIDTH / 2)
	bar.shimmer[2]:SetWidth(SHIMMER_WIDTH / 2)
	bar.shimmer[2]:SetPoint("TOPLEFT", bar.shimmer[1], "TOPRIGHT")
	bar.shimmer[2]:SetPoint("BOTTOMLEFT", bar.shimmer[1], "BOTTOMRIGHT")

	bar.flare:SetPoint("TOPRIGHT", bar.clip, "TOPRIGHT")
	bar.flare:SetPoint("BOTTOMRIGHT", bar.clip, "BOTTOMRIGHT")
	bar.flare:SetWidth(FLARE_WIDTH)

	bar.spark:SetPoint("TOPRIGHT", bar.clip, "TOPRIGHT")
	bar.spark:SetPoint("BOTTOMRIGHT", bar.clip, "BOTTOMRIGHT")

	bar:EnableMouse(true)
	bar:SetScript("OnEnter", bar.OnEnter)
	bar:SetScript("OnLeave", bar.OnLeave)
	bar:SetScript("OnMouseUp", bar.OnMouseUp)

	bar:ApplyAppearance()

	return bar
end

function BarMixin:OnEnter()
	self.hovered = true

	LB.Visibility:SetHovered(self.id)
	LB.TextSlot:SetHovered(self, true)

	if self.snapshot then
		LB.Tooltip:Show(self, self.snapshot)
	end
end

function BarMixin:OnLeave()
	self.hovered = false

	LB.Visibility:SetHovered(nil)
	LB.TextSlot:SetHovered(self, false)
	LB.Tooltip:Hide(self)
end

---@param button string
function BarMixin:OnMouseUp(button)
	if button ~= "LeftButton" or not LB.Profile:Get("tooltip.clickActions") then
		return
	end

	local source = LB.Model:Source(self.id)

	if source and source.Click then
		source:Click()
	end
end

---@param width number
---@param height number
function BarMixin:SetGeometry(width, height)
	LB:SetPixelSize(self, width, height)
	self:PaintFill()
	self:PlaceDividers()
end

function BarMixin:PaintFill()
	local fill = self.values[1]

	self.clip:SetShown(fill > 0)
	self.clip:SetWidth(math.max(fill * self:GetWidth(), 0.001))
end

---@return LBColor?
local function ClassColor()
	local class = LB:Readable(select(2, UnitClass("player")), nil)

	if not class then
		return nil
	end

	local color = C_ClassColor.GetClassColor(class)

	if not color then
		return nil
	end

	return { color.r, color.g, color.b, 1 }
end

---@return LBColor first
---@return LBColor? second nil when the fill is a flat colour rather than a gradient
function BarMixin:FillColors()
	local appearance = LB.Profile:Get("appearance")

	if self.id == "xp" then
		if appearance.xpUseClassColor then
			local class = ClassColor()

			if class then
				return class, nil
			end
		end

		return appearance.xpGradient[1] or WHITE, appearance.xpGradient[2]
	end

	if self.id == "petxp" then
		return appearance.xpGradient[1] or WHITE, appearance.xpGradient[2]
	end

	local snapshot = self.snapshot

	if snapshot and snapshot.color then
		return snapshot.color, nil
	end

	return appearance.typeColors[self.id] or appearance.xpGradient[1] or WHITE, nil
end

function BarMixin:ApplyAppearance()
	local appearance = LB.Profile:Get("appearance")
	local texture = LB.Media:FetchOrDefault("statusbar", appearance.texture) or FLAT
	local first, second = self:FillColors()
	local fillTexture = self.fillTexture

	fillTexture:SetTexture(texture)

	if second then
		fillTexture:SetVertexColor(1, 1, 1, 1)
		fillTexture:SetGradient("HORIZONTAL", CreateColor(Unpack(first)), CreateColor(Unpack(second)))
	else
		fillTexture:SetVertexColor(Unpack(first))
	end

	self.quest:SetStatusBarTexture(texture)
	self.quest:GetStatusBarTexture():SetVertexColor(Unpack(appearance.questColor))

	SetFlat(self.rested, appearance.restedColor)
	SetFlat(self.background, appearance.background)

	self.background:SetValue(1)

	local tip = second or first
	local light = { (tip[1] + 1) / 2, (tip[2] + 1) / 2, (tip[3] + 1) / 2 }

	self.shimmer[1]:SetGradient(
		"HORIZONTAL",
		CreateColor(light[1], light[2], light[3], 0),
		CreateColor(light[1], light[2], light[3], SHIMMER_ALPHA)
	)
	self.shimmer[2]:SetGradient(
		"HORIZONTAL",
		CreateColor(light[1], light[2], light[3], SHIMMER_ALPHA),
		CreateColor(light[1], light[2], light[3], 0)
	)

	self:ApplySpark(appearance.spark)
	self:ApplyDividers()
	LB.TextSlot:ApplyBar(self)
end

function BarMixin:ApplyDividers()
	if not DIVIDED[self.id] then
		if self.dividers then
			self.dividers:Hide()
		end

		return
	end

	local appearance = LB.Profile:Get("appearance")
	local settings = appearance.dividers
	local border = appearance.border
	local pixels, path = LB.Border:Parts(border.style)
	local color = LB.Border:Color(border.style, border)

	if settings.customColor then
		color = settings.color
	elseif not pixels and not path then
		color = NOTCH
	end

	if not self.dividers then
		self.dividers = CreateFrame("Frame", nil, self)
		self.dividers:SetAllPoints(self)
		self.dividers.lines = {}

		for index = 1, DIVIDERS do
			self.dividers.lines[index] = self.dividers:CreateTexture(nil, "OVERLAY")
		end
	end

	self.dividers:SetFrameLevel(self:GetFrameLevel() + LEVEL_DIVIDERS)
	self.dividers.enabled = settings.enabled
	self.dividers.pixels = pixels or 1
	self.dividers.textured = path ~= nil

	for _, line in ipairs(self.dividers.lines) do
		if path then
			line:SetTexture(path)
			line:SetTexCoord(0, DIVIDER_EDGE_SLICE, 0, 1)
		else
			line:SetTexture(FLAT)
			line:SetTexCoord(0, 1, 0, 1)
		end

		line:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	end

	self:PlaceDividers()
end

function BarMixin:PlaceDividers()
	local dividers = self.dividers

	if not dividers then
		return
	end

	local width, height = self:GetSize()
	local shown = dividers.enabled and width / (DIVIDERS + 1) >= DIVIDER_MIN_SEGMENT

	dividers:SetShown(shown)

	if not shown then
		return
	end

	local pixel = LB:Pixel(self)
	local lineWidth = dividers.pixels * pixel

	if dividers.textured then
		lineWidth = LB.Placement:ToPixel(LB.Border:EdgeMetrics(height), pixel)
	end

	for index, line in ipairs(dividers.lines) do
		local x = LB.Placement:ToPixel(width * index / (DIVIDERS + 1) - lineWidth / 2, pixel)

		line:ClearAllPoints()
		line:SetPoint("TOPLEFT", self, "TOPLEFT", x, 0)
		line:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, 0)
		line:SetWidth(math.max(lineWidth, pixel))
	end
end

---@param spark { enabled: boolean, color: LBColor }
function BarMixin:ApplySpark(spark)
	local r, g, b, a = Unpack(spark.color)

	self.sparkEnabled = spark.enabled

	LB:SetPixelWidth(self.spark, CORE_WIDTH)
	self.spark:SetVertexColor(r, g, b, a)
	self.flare:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, a * FLARE_PEAK))

	self:PaintEffects()
end

---@param heat number
---@param growing boolean
---@param delta number seconds since the last step
---@return number heat hot while the fill grows, then cooling to rest over FLARE_COOL seconds
function Bar:FlareHeat(heat, growing, delta)
	if growing then
		return FLARE_HOT
	end

	return math.max(FLARE_REST, heat - (FLARE_HOT - FLARE_REST) * delta / FLARE_COOL)
end

---@param elapsed number seconds into the sweep
---@param fillWidth number
---@return number x left edge of the highlight, from the bar's left edge
---@return number alpha
---@return boolean done
function Bar:ShimmerKeyframe(elapsed, fillWidth)
	local progress = math.min(math.max(elapsed, 0) / SHIMMER, 1)
	local eased = progress < 0.5 and 2 * progress * progress or 1 - (-2 * progress + 2) ^ 2 / 2

	return -SHIMMER_WIDTH + (fillWidth + SHIMMER_WIDTH) * eased, math.sin(math.pi * progress), progress >= 1
end

function BarMixin:PaintEffects()
	local fill = self.values[1]
	local edge = self.sparkEnabled and fill > 0 and fill < 1 or false

	self.spark:SetShown(edge)
	self.flare:SetShown(edge)
	self.spark:SetAlpha(self.heat)
	self.flare:SetAlpha(self.heat)

	local elapsed = self.shimmerElapsed
	local shown = elapsed ~= nil and fill > 0

	self.shimmer[1]:SetShown(shown)
	self.shimmer[2]:SetShown(shown)

	if not elapsed or not shown then
		return
	end

	local x, alpha = Bar:ShimmerKeyframe(elapsed, fill * self:GetWidth())
	local left = self.shimmer[1]

	left:ClearAllPoints()
	left:SetPoint("TOPLEFT", self.content, "TOPLEFT", x, 0)
	left:SetPoint("BOTTOMLEFT", self.content, "BOTTOMLEFT", x, 0)
	left:SetAlpha(alpha)
	self.shimmer[2]:SetAlpha(alpha)
end

---@param driver Frame
---@param delta number
local function EffectsOnUpdate(driver, delta)
	local bar = driver:GetParent() --[[@as LBBar]]

	bar.heat = Bar:FlareHeat(bar.heat, bar.growing == true, delta)

	if bar.shimmerElapsed then
		bar.shimmerElapsed = bar.shimmerElapsed + delta

		if bar.shimmerElapsed >= SHIMMER then
			bar.shimmerElapsed = nil
		end
	end

	bar:PaintEffects()

	if not bar.growing and not bar.shimmerElapsed and bar.heat <= FLARE_REST then
		driver:SetScript("OnUpdate", nil)
	end
end

---@param shimmer boolean sweep the highlight too, when the profile allows it
function BarMixin:Glint(shimmer)
	if shimmer and LB.Profile:Get("appearance.shimmer") then
		self.shimmerElapsed = 0
	end

	self.heat = FLARE_HOT
	self:PaintEffects()
	self.effectDriver:SetScript("OnUpdate", EffectsOnUpdate)
end

---@param fill number
---@param quest number
---@param rested number
function BarMixin:SetValues(fill, quest, rested)
	self.values[1], self.values[2], self.values[3] = fill, quest, rested

	self:PaintFill()
	self.quest:SetValue(quest)
	self.rested:SetValue(rested)
	self:PaintEffects()
end

---@param progress number
---@return number
local function EaseOut(progress)
	local inverse = 1 - progress

	return 1 - inverse * inverse * inverse
end

---@param progress number
---@return number
local function Linear(progress)
	return progress
end

---@param delta number fraction of the bar the fill moves
---@return number seconds
function Bar:FillDuration(delta)
	return math.min(math.max(math.abs(delta) / FILL_RATE, FILL_MIN), FILL_MAX)
end

---@param fill number
---@param quest number
---@param rested number
---@param duration number
---@param onFinished fun()?
---@param ease (fun(progress: number): number)?
function BarMixin:TweenValues(fill, quest, rested, duration, onFinished, ease)
	local from = { self.values[1], self.values[2], self.values[3] }
	local to = { fill, quest, rested }

	LB:Tween(self.driver, duration, function(eased)
		self:SetValues(
			from[1] + (to[1] - from[1]) * eased,
			from[2] + (to[2] - from[2]) * eased,
			from[3] + (to[3] - from[3]) * eased
		)
	end, onFinished, ease)
end

---@param fill number
---@param quest number
---@param rested number
---@param onFinished fun()?
function BarMixin:GainTo(fill, quest, rested, onFinished)
	self.growing = true

	self:TweenValues(fill, quest, rested, Bar:FillDuration(fill - self.values[1]), function()
		self.growing = false

		if onFinished then
			onFinished()
		end
	end, EaseOut)
end

---@param fill number
---@param quest number
---@param rested number
function BarMixin:LevelUp(fill, quest, rested)
	self.pending = { fill, quest, rested }

	if self.sweeping then
		return
	end

	self.sweeping = true
	self.growing = true

	self:TweenValues(1, 1, 1, (1 - self.values[1]) / LEVEL_RATE, function()
		self:SetValues(0, 0, 0)

		local target = self.pending
		self.pending = nil

		if not target then
			self.sweeping = false
			self.growing = false

			return
		end

		self:Glint(true)
		self:GainTo(target[1], target[2], target[3], function()
			self.sweeping = false
		end)
	end, Linear)
end

---@param snapshot LBSnapshot
---@param animate boolean?
---@param gained boolean? real progress arrived, rather than a redraw or a swap to or from sample data
function BarMixin:SetSnapshot(snapshot, animate, gained)
	local recolour = self.snapshot == nil or self.snapshot.color ~= snapshot.color

	self.snapshot = snapshot

	if recolour then
		self:ApplyAppearance()
	end

	LB.TextSlot:UpdateBar(self)
	LB.Marker:Apply(self)

	local fill, quest, rested = LB.Model:Fractions(snapshot)
	local level = snapshot.level or 0
	local levelled = gained == true and self.level > 0 and level > self.level

	self.level = level

	if not animate then
		LB:StopTween(self.driver)
		self.sweeping = false
		self.growing = false
		self.pending = nil
		self:SetValues(fill, quest, rested)

		return
	end

	if levelled then
		self:Glint(true)
		self:LevelUp(fill, quest, rested)

		return
	end

	if self.sweeping then
		self.pending = { fill, quest, rested }

		return
	end

	if not gained then
		self.growing = false
		self:TweenValues(fill, quest, rested, SWEEP_UP)

		return
	end

	if fill > self.values[1] then
		self:Glint(true)
	end

	self:GainTo(fill, quest, rested)
end

---@param onFinished fun()?
function BarMixin:FadeOut(onFinished)
	local from = self:GetAlpha()

	self.fading = true

	LB:Tween(self, FADE, function(eased)
		self:SetAlpha(from * (1 - eased))
		LB.Marker:FollowFade(self, 1 - eased)
	end, function()
		self.fading = nil

		self:Hide()
		self:SetAlpha(1)
		LB.Marker:FollowFade(self, 1)

		if onFinished then
			onFinished()
		end
	end)
end

function BarMixin:Appear()
	local returning = not self:IsShown() or self.fading

	LB:StopTween(self)

	self.fading = nil

	if returning then
		self:SetAlpha(1)
		LB.Marker:FollowFade(self, 1)
	end

	self:Show()
end
