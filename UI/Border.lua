local LB = select(2, ...)

local FLAT = [[Interface\Buttons\WHITE8X8]]
local EDGE_SIZE = 16
local LEVEL = 8

local PIXELS = {
	ONE_PIXEL = 1,
	TWO_PIXEL = 2,
}

local EDGES = {
	THICK = "Levelbound Thick",
	ROUNDED = "Levelbound Ring Medium",
	ROUNDED_THICK = "Levelbound Ring Thick",
}

local RING = { 102 / 255, 98 / 255, 92 / 255 }
local NATIVE = {
	THICK = { 165 / 255, 165 / 255, 165 / 255 },
	ROUNDED = RING,
	ROUNDED_THICK = RING,
}

---@class LBBorderFrame : Frame, BackdropTemplate
---@field edges Texture[] top, bottom, left, right
local BorderMixin = {}

---@class LBBorder
local Border = {}
LB.Border = Border

---@param style string
---@return boolean
function Border:IsTextured(style)
	return EDGES[style] ~= nil
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
---@return number edge
---@return number outset
function Border:EdgeMetrics(height)
	local edge = math.max(math.min(EDGE_SIZE, math.floor(height * 2 / 3)), 2)

	return edge, edge / 4
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

---@param style string
---@param color LBColor
---@param height number the host's height once its layout settles
function BorderMixin:Apply(style, color, height)
	local host = self:GetParent()
	local pixels = PIXELS[style]
	local name = EDGES[style]
	local path = name and LB.Media:Fetch("border", name)

	if not host or (not pixels and not path) then
		self:Hide()

		return
	end

	local r, g, b, a = color[1], color[2], color[3], color[4] or 1

	self:ClearAllPoints()

	if pixels then
		local outset = pixels * PixelUtil.GetPixelToUIUnitFactor() / self:GetEffectiveScale()

		self:ClearBackdrop()
		self:SetPoint("TOPLEFT", host, "TOPLEFT", -outset, outset)
		self:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", outset, -outset)
		self:PlaceEdges(pixels, r, g, b, a)
	else
		local edge, outset = Border:EdgeMetrics(height)

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
