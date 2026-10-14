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

-- Edge Glow: a white trail fading in toward the fill's end, and two soft glows centered on that end that stand past
-- the bar's top and bottom by their spill, all added to what is beneath them.
local TRAIL_WIDTH = 48
local TRAIL_ALPHA = 0.45
local HALOS = { { spill = 13, alpha = 0.14 }, { spill = 10, alpha = 0.22 } }
local LEVEL_GLOW = LEVEL_FILL + 1

local SHIMMER = 1.4
local SHIMMER_WIDTH = 90
local SHIMMER_ALPHA = 0.55

local LEVEL_DIVIDERS = LEVEL_FILL + 2
local DIVIDERS_MAX = 19 -- every 5 %
local DIVIDER_MIN_SEGMENT = 16
local DIVIDER_EDGE_SLICE = 0.125
local NOTCH = { 0, 0, 0, 0.5 }
local DIVIDED = { xp = true, petxp = true, party = true }

-- End masks, each the bar's full height; past its own width each clamps to white and masks nothing. A texture takes
-- at most three masks, so one mask cuts both corners of an end.
local ENDS = {
	{ side = "LEFT", texture = "maskLeft", pill = "pillLeft", left = true },
	{ side = "RIGHT", texture = "maskRight", pill = "pillRight", left = false },
}

---@type table<Texture, table<Texture, true>> the end masks attached to each texture
local attached = setmetatable({}, { __mode = "k" })

---@class LBBar : Frame
---@field id string
---@field member LBRosterMember? the party member a standalone party bar shows
---@field clip Frame reveals the full-width fill art; only its width changes, so the art never stretches
---@field content Frame
---@field fillTexture Texture
---@field quest StatusBar
---@field rested StatusBar
---@field background StatusBar
---@field spark Texture the flare's core line
---@field flare Texture
---@field shimmer Texture[] the two halves of the sweeping highlight
---@field trail Texture
---@field glow Frame holds the halos, outside the clip so they stand past the fill's end
---@field halos Texture[]
---@field border LBBorderFrame?
---@field driver Frame
---@field alphaDriver Frame
---@field level number last drawn level
---@field values number[]
---@field sweeping boolean? level-up sweep animation is running
---@field fading boolean?
---@field pending number[]? target the sweep settles on
---@field hovered boolean?
---@field sparkEnabled boolean?
---@field heat number flare brightness; raised while the fill grows, at rest level otherwise
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
---@field masks table<Frame, { mask: Texture, left: boolean }[]>? end masks on each frame that draws the fill
---@field maskWidth number? the end masks' width; nil cuts neither end
---@field maskLeft boolean? the left end is cut
---@field maskRight boolean? the right end is cut
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
	bar.trail = bar.content:CreateTexture(nil, "ARTWORK", nil, 3)
	bar.flare = bar.content:CreateTexture(nil, "OVERLAY")
	bar.spark = bar.content:CreateTexture(nil, "OVERLAY", nil, 1)

	for _, texture in ipairs({ bar.shimmer[1], bar.shimmer[2], bar.trail, bar.flare, bar.spark }) do
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

	bar.trail:SetPoint("TOPRIGHT", bar.clip, "TOPRIGHT")
	bar.trail:SetPoint("BOTTOMRIGHT", bar.clip, "BOTTOMRIGHT")
	bar.trail:SetWidth(TRAIL_WIDTH)
	bar.trail:SetGradient("HORIZONTAL", CreateColor(1, 1, 1, 0), CreateColor(1, 1, 1, TRAIL_ALPHA))

	bar.glow = CreateFrame("Frame", nil, bar)
	bar.glow:SetAllPoints(bar)
	bar.glow:SetFrameLevel(bar:GetFrameLevel() + LEVEL_GLOW)
	bar.halos = {}

	for index in ipairs(HALOS) do
		local halo = bar.glow:CreateTexture(nil, "ARTWORK", nil, index)

		halo:SetTexture(LB.Media.textures.softShade)
		halo:SetBlendMode("ADD")
		halo:SetPoint("CENTER", bar.clip, "RIGHT")
		halo:Hide()
		bar.halos[index] = halo
	end

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
	if self.member then
		self.hovered = true
		LB.TextSlot:SetHovered(self, true)
		LB.Tooltip:ShowMember(self, self.member)

		return
	end

	self.hovered = true

	LB.Visibility:SetHovered(self.id)
	LB.TextSlot:SetHovered(self, true)

	if self.snapshot then
		LB.Tooltip:Show(self, self.snapshot)
	end
end

function BarMixin:OnLeave()
	if self.member then
		self.hovered = false
		LB.TextSlot:SetHovered(self, false)
		LB.Tooltip:Hide(self)

		return
	end

	self.hovered = false

	LB.Visibility:SetHovered(nil)
	LB.TextSlot:SetHovered(self, false)
	LB.Tooltip:Hide(self)
end

---@param button string
function BarMixin:OnMouseUp(button)
	if self.member or button ~= "LeftButton" or not LB.Profile:Get("tooltip.clickActions") then
		return
	end

	if IsShiftKeyDown() then
		LB.Share:Insert(self.id)

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
	self:SizeHalos()

	if self.maskWidth == "PILL" then
		self:RefreshMasks()
	end
end

function BarMixin:SizeHalos()
	local height = self:GetHeight()

	for index, halo in ipairs(self.halos) do
		local size = height + HALOS[index].spill * 2

		LB:SetPixelSize(halo, size, size)
	end
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

---@param class string?
---@return LBColor?
local function ColorOf(class)
	local color = class and C_ClassColor.GetClassColor(class)

	return color and { color.r, color.g, color.b, 1 } or nil
end

---@return LBColor first
---@return LBColor? second nil when the fill is a flat color rather than a gradient
function BarMixin:FillColors()
	local appearance = LB.Profile:Get("appearance")

	if self.member then
		local class = LB.Profile:Get("party.bars.classColor") and ColorOf(LB.Roster.ClassOf(self.member))

		if class then
			return class, nil
		end

		return appearance.xpGradient[1] or WHITE, appearance.xpGradient[2]
	end

	if self.id == "xp" then
		if appearance.xpUseClassColor then
			local class = ClassColor()

			if class then
				return class, nil
			end
		end

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
	fillTexture:ClearAllPoints()

	-- Following the fill, the art spans only the revealed part, so the gradient's end color sits at the fill's end.
	if second and appearance.xpGradientFollows then
		fillTexture:SetPoint("TOPLEFT", self.content, "TOPLEFT")
		fillTexture:SetPoint("BOTTOMRIGHT", self.clip, "BOTTOMRIGHT")
	else
		fillTexture:SetAllPoints(self.content)
	end

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

	self.glowEnabled = appearance.glow
	self:SizeHalos()
	self:ApplySpark(appearance.spark, tip)
	self:ApplyDividers()
	self:RefreshMasks()
	LB.TextSlot:ApplyBar(self)
end

---Cuts the ends of the fill, its overlays, effects and background to a border's bevel, or rounds them for the Pill
---shape, at the left end, the right end or both.
---@param width number|"PILL"|nil the masks' width, from `Border:EndMask`: "PILL" rounds the ends at half the bar's
---height; nil cuts neither end
---@param left boolean
---@param right boolean
function BarMixin:SetEndMasks(width, left, right)
	self.maskWidth = width
	self.maskLeft, self.maskRight = width ~= nil and left, width ~= nil and right
	self:RefreshMasks()
end

---@param frame Frame
---@return Texture[] the textures on `frame` that the end masks cut
function BarMixin:MaskedTextures(frame)
	if frame == self.content then
		return { self.fillTexture, self.shimmer[1], self.shimmer[2], self.trail, self.flare, self.spark }
	end

	---@cast frame StatusBar
	return { frame:GetStatusBarTexture() }
end

---Attaches or detaches each end mask to match `maskLeft` and `maskRight`; a status bar's texture may be replaced
---when its texture changes, so this runs again after every appearance change.
function BarMixin:RefreshMasks()
	if not self.masks then
		if not self.maskLeft and not self.maskRight then
			return
		end

		self.masks = {}

		for _, frame in ipairs({ self.background, self.rested, self.quest, self.content }) do
			local set = {}

			for _, entry in ipairs(ENDS) do
				local mask = frame:CreateMaskTexture()

				mask:SetPoint("TOP" .. entry.side, frame, "TOP" .. entry.side)
				mask:SetPoint("BOTTOM" .. entry.side, frame, "BOTTOM" .. entry.side)
				set[#set + 1] = { mask = mask, left = entry.left, texture = entry.texture, pill = entry.pill }
			end

			self.masks[frame] = set
		end
	end

	for frame, set in pairs(self.masks) do
		local textures = self:MaskedTextures(frame)

		for _, entry in ipairs(set) do
			local wanted = (entry.left and self.maskLeft) or (not entry.left and self.maskRight)

			if self.maskWidth == "PILL" then
				entry.mask:SetTexture(LB.Media.textures[entry.pill], "CLAMPTOWHITE", "CLAMPTOWHITE")
				entry.mask:SetWidth(self:GetHeight() / 2)
			elseif self.maskWidth then
				entry.mask:SetTexture(LB.Media.textures[entry.texture], "CLAMPTOWHITE", "CLAMPTOWHITE")
				entry.mask:SetWidth(self.maskWidth)
			end

			for _, texture in ipairs(textures) do
				local masks = attached[texture] or {}

				attached[texture] = masks

				if wanted and not masks[entry.mask] then
					texture:AddMaskTexture(entry.mask)
					masks[entry.mask] = true
				elseif not wanted and masks[entry.mask] then
					texture:RemoveMaskTexture(entry.mask)
					masks[entry.mask] = nil
				end
			end
		end
	end
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
	local pixels, path = LB.Border:Parts(border.style, border.width)
	local art = LB.Border:DividerArt(border.style)
	local color = LB.Border:Color(border.style, border)

	if settings.customColor then
		color = settings.color
	elseif art and not border.customColor then
		color = art.tint
	elseif (not pixels or pixels == 0) and not path and not art then
		color = NOTCH
	end

	if not self.dividers then
		self.dividers = CreateFrame("Frame", nil, self)
		self.dividers:SetAllPoints(self)
		self.dividers.lines = {}

		for index = 1, DIVIDERS_MAX do
			self.dividers.lines[index] = self.dividers:CreateTexture(nil, "OVERLAY")
		end
	end

	self.dividers:SetFrameLevel(self:GetFrameLevel() + LEVEL_DIVIDERS)
	self.dividers.enabled = settings.enabled
	self.dividers.segments = math.min(math.floor(100 / settings.spacing), DIVIDERS_MAX + 1)
	-- Pill dividers stand one pixel thicker than the outline, so they read against the rounded bar.
	self.dividers.pixels = border.style == "PILL" and math.max(pixels or 0, 1) + 1 or pixels or 1
	self.dividers.textured = path ~= nil
	self.dividers.art = art

	for _, line in ipairs(self.dividers.lines) do
		if art then
			line:SetTexture(art.path)
			line:SetTexCoord(unpack(art.coords))
		elseif path then
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
	local segments = dividers.segments
	local shown = dividers.enabled and width / segments >= DIVIDER_MIN_SEGMENT

	dividers:SetShown(shown)

	if not shown then
		return
	end

	local pixel = LB:Pixel(self)
	local lineWidth = dividers.pixels * pixel

	if dividers.art then
		lineWidth = LB.Placement:ToPixel(dividers.art.width, pixel)
	elseif dividers.textured then
		lineWidth = LB.Placement:ToPixel(LB.Border:EdgeMetrics(height), pixel)
	end

	for index, line in ipairs(dividers.lines) do
		local used = index < segments

		line:SetShown(used)

		if used then
			local x = LB.Placement:ToPixel(width * index / segments - lineWidth / 2, pixel)

			line:ClearAllPoints()
			line:SetPoint("TOPLEFT", self, "TOPLEFT", x, 0)
			line:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", x, 0)
			line:SetWidth(math.max(lineWidth, pixel))
		end
	end
end

---@param spark { enabled: boolean, customColor: boolean, color: LBColor }
---@param tip LBColor the fill's color at its end, used unless the spark has its own
function BarMixin:ApplySpark(spark, tip)
	local r, g, b = Unpack(spark.customColor and spark.color or tip)
	local a = spark.color[4] or 1

	self.sparkEnabled = spark.enabled

	LB:SetPixelWidth(self.spark, CORE_WIDTH)
	self.spark:SetVertexColor(r, g, b, a)
	self.flare:SetGradient("HORIZONTAL", CreateColor(r, g, b, 0), CreateColor(r, g, b, a * FLARE_PEAK))

	for index, halo in ipairs(self.halos) do
		halo:SetVertexColor(r, g, b, HALOS[index].alpha)
	end

	self:PaintEffects()
end

---@param heat number
---@param growing boolean
---@param delta number seconds since the last step
---@return number heat raised while the fill grows, then decaying to rest level over FLARE_COOL seconds
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

	local glow = self.glowEnabled and fill > 0 or false

	self.trail:SetShown(glow)

	for _, halo in ipairs(self.halos) do
		halo:SetShown(glow)
	end

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
	local recolor = self.snapshot == nil or self.snapshot.color ~= snapshot.color

	self.snapshot = snapshot

	if recolor then
		self:ApplyAppearance()
	end

	LB.TextSlot:UpdateBar(self)
	LB.Marker:Apply(self)

	local fill, quest, rested = LB.Progress.Fills(snapshot)

	fill, quest, rested = fill or 0, quest or 0, rested or 0
	local level = snapshot.level or 0
	local leveled = gained == true and self.level > 0 and level > self.level

	self.level = level

	if not animate then
		LB:StopTween(self.driver)
		self.sweeping = false
		self.growing = false
		self.pending = nil
		self:SetValues(fill, quest, rested)

		return
	end

	if leveled then
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
