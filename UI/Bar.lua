local LB = select(2, ...)

local LEVEL_FILL = 4
local LEVEL_QUEST = 3
local LEVEL_RESTED = 2
local LEVEL_BACKGROUND = 1

local FLAT = [[Interface\Buttons\WHITE8X8]]
local WHITE = { 1, 1, 1, 1 }

local SWEEP_UP = 0.25
local SWEEP_DOWN = 0.35
local FADE = 0.5

---@class LBBar : Frame
---@field id string
---@field fill StatusBar
---@field quest StatusBar
---@field rested StatusBar
---@field background StatusBar
---@field driver Frame
---@field level number last drawn level
---@field values number[]
---@field sweeping boolean? lvl up sweep animation running
---@field pending number[]? target the sweep settles on
---@field hovered boolean?
---@field snapshot LBSnapshot?
---@field textPool any?
---@field texts LBTextEntry[]?
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

	bar.background = CreateLayer(bar, LEVEL_BACKGROUND)
	bar.rested = CreateLayer(bar, LEVEL_RESTED)
	bar.quest = CreateLayer(bar, LEVEL_QUEST)
	bar.fill = CreateLayer(bar, LEVEL_FILL)

	bar.background:SetValue(1)

	bar:EnableMouse(true)
	bar:SetScript("OnEnter", bar.OnEnter)
	bar:SetScript("OnLeave", bar.OnLeave)
	bar:SetScript("OnMouseUp", bar.OnMouseUp)

	bar:ApplyAppearance()

	return bar
end

function BarMixin:OnEnter()
	self.hovered = true

	LB.TextElement:SetHovered(self, true)

	if self.snapshot then
		LB.Tooltip:Show(self, self.snapshot)
	end
end

function BarMixin:OnLeave()
	self.hovered = false

	LB.TextElement:SetHovered(self, false)
	LB.Tooltip:Hide()
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
	PixelUtil.SetSize(self, width, height)
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

	self.fill:SetStatusBarTexture(texture)

	local fillTexture = self.fill:GetStatusBarTexture()

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

	LB.TextElement:Apply(self)
end

---@param fill number
---@param quest number
---@param rested number
function BarMixin:SetValues(fill, quest, rested)
	self.values[1], self.values[2], self.values[3] = fill, quest, rested

	self.fill:SetValue(fill)
	self.quest:SetValue(quest)
	self.rested:SetValue(rested)
end

---@param fill number
---@param quest number
---@param rested number
---@param duration number
---@param onFinished fun()?
function BarMixin:TweenValues(fill, quest, rested, duration, onFinished)
	local from = { self.values[1], self.values[2], self.values[3] }
	local to = { fill, quest, rested }

	LB:Tween(self.driver, duration, function(eased)
		self:SetValues(
			from[1] + (to[1] - from[1]) * eased,
			from[2] + (to[2] - from[2]) * eased,
			from[3] + (to[3] - from[3]) * eased
		)
	end, onFinished)
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

	self:TweenValues(1, 1, 1, SWEEP_UP, function()
		self:SetValues(0, 0, 0)

		local target = self.pending
		self.pending = nil

		if not target then
			self.sweeping = false

			return
		end

		self:TweenValues(target[1], target[2], target[3], SWEEP_DOWN, function()
			self.sweeping = false
		end)
	end)
end

---@param snapshot LBSnapshot
---@param animate boolean?
function BarMixin:SetSnapshot(snapshot, animate)
	local recolour = self.snapshot == nil or self.snapshot.color ~= snapshot.color

	self.snapshot = snapshot

	if recolour then
		self:ApplyAppearance()
	end

	LB.TextElement:Update(self, snapshot)

	local fill, quest, rested = LB.Model:Fractions(snapshot)
	local level = snapshot.level or 0
	local levelled = self.level > 0 and level > self.level

	self.level = level

	if not animate then
		LB:StopTween(self.driver)
		self.sweeping = false
		self.pending = nil
		self:SetValues(fill, quest, rested)

		return
	end

	if levelled then
		self:LevelUp(fill, quest, rested)

		return
	end

	if self.sweeping then
		self.pending = { fill, quest, rested }

		return
	end

	self:TweenValues(fill, quest, rested, SWEEP_UP)
end

---@param onFinished fun()?
function BarMixin:FadeOut(onFinished)
	local from = self:GetAlpha()

	LB:Tween(self, FADE, function(eased)
		self:SetAlpha(from * (1 - eased))
	end, function()
		self:Hide()
		self:SetAlpha(1)

		if onFinished then
			onFinished()
		end
	end)
end

function BarMixin:Appear()
	LB:StopTween(self)
	self:SetAlpha(1)
	self:Show()
end
