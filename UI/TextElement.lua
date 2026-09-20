local LB = select(2, ...)

local PADDING = 4
local GAP = 2

local OUTLINES = {
	NONE = "",
	OUTLINE = "OUTLINE",
	THICKOUTLINE = "THICKOUTLINE",
}

---@class LBAnchorSpec
---@field bar FramePoint
---@field own FramePoint
---@field x number
---@field y number

---@type table<string, LBAnchorSpec>
local ANCHORS = {
	INSIDE_LEFT = { bar = "LEFT", own = "LEFT", x = PADDING, y = 0 },
	INSIDE_CENTER = { bar = "CENTER", own = "CENTER", x = 0, y = 0 },
	INSIDE_RIGHT = { bar = "RIGHT", own = "RIGHT", x = -PADDING, y = 0 },
	ABOVE_LEFT = { bar = "TOPLEFT", own = "BOTTOMLEFT", x = 0, y = GAP },
	ABOVE_CENTER = { bar = "TOP", own = "BOTTOM", x = 0, y = GAP },
	ABOVE_RIGHT = { bar = "TOPRIGHT", own = "BOTTOMRIGHT", x = 0, y = GAP },
	BELOW_LEFT = { bar = "BOTTOMLEFT", own = "TOPLEFT", x = 0, y = -GAP },
	BELOW_CENTER = { bar = "BOTTOM", own = "TOP", x = 0, y = -GAP },
	BELOW_RIGHT = { bar = "BOTTOMRIGHT", own = "TOPRIGHT", x = 0, y = -GAP },
}

---@class LBTextEntry
---@field fontString FontString
---@field definition LBTextElement

---@param fontString FontString
local function Reset(_, fontString)
	fontString:Hide()
	fontString:SetText("")
	fontString:ClearAllPoints()
	fontString:SetTextColor(1, 1, 1, 1)
end

---@class LBTextElement
local TextElement = {}
LB.TextElement = TextElement

---@param bar LBBar
---@return any pool
---@return LBTextEntry[] texts
local function PoolFor(bar)
	---@type LBTextEntry[]
	local texts = bar.texts or {}

	if not bar.textPool then
		bar.textPool = CreateFontStringPool(bar, "OVERLAY", 7, nil, Reset)
	end

	bar.texts = texts

	return bar.textPool, texts
end

---@param bar LBBar
---@return LBTextElement[]
local function Definitions(bar)
	local elements = LB.Profile:Get("text.elements")

	return elements[bar.id == "xp" and "xp" or "other"] or {}
end

---@param bar LBBar
function TextElement:Apply(bar)
	local pool, texts = PoolFor(bar)

	pool:ReleaseAll()
	wipe(texts)

	for index, definition in ipairs(Definitions(bar)) do
		local fontString = pool:Acquire()
		local anchor = ANCHORS[definition.anchor] or ANCHORS.INSIDE_CENTER
		local path = LB.Media:FetchOrDefault("font", definition.font)

		if path then
			fontString:SetFont(path, definition.size, OUTLINES[definition.outline] or "")
		end

		local color = definition.color

		fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
		fontString:ClearAllPoints()
		fontString:SetPoint(anchor.own, bar, anchor.bar, anchor.x + definition.x, anchor.y + definition.y)
		fontString:Hide()

		texts[index] = { fontString = fontString, definition = definition }
	end
end

---@param bar LBBar
---@param snapshot LBSnapshot
function TextElement:Update(bar, snapshot)
	local texts = bar.texts

	if not texts then
		return
	end

	local source = LB.Model:Source(bar.id)

	for _, entry in ipairs(texts) do
		entry.fontString:SetText(LB.Format:Value(entry.definition.kind, snapshot, source))
	end

	self:SetHovered(bar, bar.hovered == true)
end

---@param bar LBBar
---@param hovered boolean
function TextElement:SetHovered(bar, hovered)
	local texts = bar.texts

	if not texts then
		return
	end

	for _, entry in ipairs(texts) do
		local visibility = entry.definition.visibility

		entry.fontString:SetShown(visibility == "ALWAYS" or (visibility == "HOVER" and hovered))
	end
end

---@param bar LBBar
function TextElement:Release(bar)
	if not bar.textPool or not bar.texts then
		return
	end

	bar.textPool:ReleaseAll()
	wipe(bar.texts)
end
