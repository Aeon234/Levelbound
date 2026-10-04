local LB = select(2, ...)

local FLAT = [[Interface\Buttons\WHITE8X8]]
local EDGE_SIZE = 16
local LEVEL = 8

local PIXELS = {
	ONE_PIXEL = 1,
	TWO_PIXEL = 2,
}

local EDGES = {
	ROUNDED = "Levelbound Ring Medium",
	ROUNDED_THICK = "Levelbound Ring Thick",
	BRONZE = "Levelbound Bronze",
	METALLIC = "Levelbound Metallic",
}

local RING = { 102 / 255, 98 / 255, 92 / 255 }
local BLIZZARD_TINT = { 141 / 255, 124 / 255, 105 / 255 }
local NATIVE = {
	ROUNDED = RING,
	ROUNDED_THICK = RING,
	BRONZE = { 165 / 255, 130 / 255, 83 / 255 },
	METALLIC = { 195 / 255, 133 / 255, 84 / 255 },
	BLIZZARD = BLIZZARD_TINT,
}

local OUTSET = 1 / 4
local OUTSETS = {
	METALLIC = 27.5 / 64,
}

-- The Blizzard frame is drawn in three slices of a 2048 x 32 file holding the 2040 x 26 art, around a bar of fixed
-- height that it overhangs by 1 UI unit; the end caps keep their size and the middle stretches.
local STRIP = "BLIZZARD"
local STRIP_CAP = 8
local STRIP_OUTSET = 1
local STRIP_COORDS = {
	left = { 0, 16 / 2048 },
	middle = { 16 / 2048, 2024 / 2048 },
	right = { 2024 / 2048, 2040 / 2048 },
	bottom = 26 / 32,
}
local FIXED_HEIGHT = { BLIZZARD = 11 }
local MASK_WIDTH = 6.5 -- the bevel's reach in from each end of the bar

-- Styles that draw dividers from the Blizzard divider art, 3 UI units wide, instead of a slice of their edge file.
local DIVIDER_ART = {
	BLIZZARD = true,
}
local DIVIDER_TINT = { 145 / 255, 136 / 255, 116 / 255 }
local DIVIDER_WIDTH = 3
local DIVIDER_COORDS = { 0, 1, 1 / 16, 15 / 16 }

---@class LBBorderFrame : Frame, BackdropTemplate
---@field edges Texture[] top, bottom, left, right
---@field strip Texture[]? left cap, middle, right cap of the Blizzard frame
local BorderMixin = {}

---@class LBBorder
local Border = {}
LB.Border = Border

---@param style string
---@return boolean
function Border:IsTextured(style)
	return EDGES[style] ~= nil or style == STRIP
end

---@return boolean drawn the Blizzard border is the chosen style and is drawn, which it is but along a screen edge
function Border:BlizzardDrawn()
	return LB.Profile:Get("appearance.border.style") == STRIP and not LB.Layout.Fullscreen(LB.Profile:Get("layout"))
end

---@param style string
---@return number? height the bar height the style is drawn around, or nil when it fits any height
function Border:FixedHeight(style)
	return FIXED_HEIGHT[style]
end

---@param style string
---@return number? width the end masks' width that cuts the fill to the style's bevel, or nil for square ends
function Border:EndMask(style)
	return style == STRIP and MASK_WIDTH or nil
end

---@class LBDividerArt
---@field path string
---@field coords number[] left, right, top, bottom
---@field width number in UI units
---@field tint LBColor the art's own color

---@param style string
---@return LBDividerArt? art the divider texture a style draws its dividers with, or nil
function Border:DividerArt(style)
	if not DIVIDER_ART[style] then
		return nil
	end

	return {
		path = LB.Media.textures.blizzardDivider,
		coords = DIVIDER_COORDS,
		width = DIVIDER_WIDTH,
		tint = DIVIDER_TINT,
	}
end

---@param style string
---@return integer? pixels the line width of a flat style
---@return string? path the edge file of a textured style
function Border:Parts(style)
	local name = EDGES[style]

	return PIXELS[style], name and LB.Media:Fetch("border", name) or nil
end

---@param style string
---@param border { color: LBColor, customColor: boolean? }
---@return LBColor
function Border:Color(style, border)
	local native = NATIVE[style]
	local alpha = border.color[4] or 1

	if native and not border.customColor then
		return { native[1], native[2], native[3], alpha }
	end

	return border.color
end

---@param host Frame
---@return LBBorderFrame
function Border:Create(host)
	---@type LBBorderFrame
	local frame = CreateFrame("Frame", nil, host, "BackdropTemplate")

	Mixin(frame, BorderMixin)

	frame:SetFrameLevel(host:GetFrameLevel() + LEVEL)
	frame.edges = {}

	for index = 1, 4 do
		local edge = frame:CreateTexture(nil, "OVERLAY")

		edge:SetTexture(FLAT)
		frame.edges[index] = edge
	end

	frame:Hide()

	return frame
end

---@param height number the bordered frame's height
---@param style string?
---@return number edge
---@return number outset
function Border:EdgeMetrics(height, style)
	local edge = math.max(math.min(EDGE_SIZE, math.floor(height * 2 / 3)), 2)

	return edge, edge * (OUTSETS[style] or OUTSET)
end

---How far a style's border reaches outside the frame it surrounds, in UI units.
---@param style string
---@param height number the framed height
---@return number
function Border:Outset(style, height)
	local pixels = PIXELS[style]

	if pixels then
		return pixels * LB:Pixel()
	end

	if style == STRIP then
		return STRIP_OUTSET
	end

	if EDGES[style] then
		local _, outset = self:EdgeMetrics(height, style)

		return outset
	end

	return 0
end

---@param pixels number
---@param r number
---@param g number
---@param b number
---@param a number
function BorderMixin:PlaceEdges(pixels, r, g, b, a)
	local thickness = pixels * PixelUtil.GetPixelToUIUnitFactor() / self:GetEffectiveScale()
	local top, bottom, left, right = self.edges[1], self.edges[2], self.edges[3], self.edges[4]

	for _, edge in ipairs(self.edges) do
		edge:ClearAllPoints()
		edge:SetVertexColor(r, g, b, a)
		edge:Show()
	end

	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(thickness)

	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(thickness)

	left:SetPoint("TOPLEFT", 0, -thickness)
	left:SetPoint("BOTTOMLEFT", 0, thickness)
	left:SetWidth(thickness)

	right:SetPoint("TOPRIGHT", 0, -thickness)
	right:SetPoint("BOTTOMRIGHT", 0, thickness)
	right:SetWidth(thickness)
end

---Draws the Blizzard frame's three slices.
---@param r number
---@param g number
---@param b number
---@param a number
function BorderMixin:PlaceStrip(r, g, b, a)
	if not self.strip then
		self.strip = {}

		for index = 1, 3 do
			local slice = self:CreateTexture(nil, "OVERLAY")

			slice:SetTexture(LB.Media.textures.blizzardFrame)
			self.strip[index] = slice
		end
	end

	local left, middle, right = self.strip[1], self.strip[2], self.strip[3]
	local bottom = STRIP_COORDS.bottom

	left:SetTexCoord(STRIP_COORDS.left[1], STRIP_COORDS.left[2], 0, bottom)
	middle:SetTexCoord(STRIP_COORDS.middle[1], STRIP_COORDS.middle[2], 0, bottom)
	right:SetTexCoord(STRIP_COORDS.right[1], STRIP_COORDS.right[2], 0, bottom)

	for _, slice in ipairs(self.strip) do
		slice:ClearAllPoints()
		slice:SetVertexColor(r, g, b, a)
		slice:Show()
	end

	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	LB:SetPixelWidth(left, STRIP_CAP)

	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	LB:SetPixelWidth(right, STRIP_CAP)

	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
end

---@param style string
---@param color LBColor
---@param height number the host's height once its layout settles
function BorderMixin:Apply(style, color, height)
	local host = self:GetParent()
	local pixels = PIXELS[style]
	local name = EDGES[style]
	local path = name and LB.Media:Fetch("border", name)
	local strip = style == STRIP

	if self.strip and not strip then
		for _, slice in ipairs(self.strip) do
			slice:Hide()
		end
	end

	if not host or (not pixels and not path and not strip) then
		self:Hide()

		return
	end

	local r, g, b, a = color[1], color[2], color[3], color[4] or 1

	self:ClearAllPoints()

	if strip then
		for _, texture in ipairs(self.edges) do
			texture:Hide()
		end

		self:ClearBackdrop()
		self:SetPoint("TOPLEFT", host, "TOPLEFT", -STRIP_OUTSET, STRIP_OUTSET)
		self:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", STRIP_OUTSET, -STRIP_OUTSET)
		self:PlaceStrip(r, g, b, a)
	elseif pixels then
		local outset = pixels * PixelUtil.GetPixelToUIUnitFactor() / self:GetEffectiveScale()

		self:ClearBackdrop()
		self:SetPoint("TOPLEFT", host, "TOPLEFT", -outset, outset)
		self:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", outset, -outset)
		self:PlaceEdges(pixels, r, g, b, a)
	else
		local edge, outset = Border:EdgeMetrics(height, style)

		for _, texture in ipairs(self.edges) do
			texture:Hide()
		end

		self:SetPoint("TOPLEFT", host, "TOPLEFT", -outset, outset)
		self:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", outset, -outset)
		self:SetBackdrop({ edgeFile = path, edgeSize = edge })
		self:SetBackdropBorderColor(r, g, b, a)
	end

	self:Show()
end
