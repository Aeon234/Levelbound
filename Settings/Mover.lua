local LB = select(2, ...)

local FLAT = [[Interface\Buttons\WHITE8X8]]
local MIN_HEIGHT = 20
local LABEL_INSET = 4
local LEVEL = 10
local LEVEL_SELECTED = 20

local ACCENT = { 122 / 255, 99 / 255, 1 }
local FILL = { 0.04, 0.04, 0.05, 0.95 }
local BORDER_ALPHA = 0.6
local BORDER_HOVER_ALPHA = 0.9
local BORDER_SELECTED_ALPHA = 1
local WASH_ALPHA = 0.1
local LABEL_ALPHA = 0.75

---@return number x
---@return number y
local function Cursor()
	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()

	return x / scale, y / scale
end

---@class LBMoverDrag
---@field x number cursor position when the drag began
---@field y number
---@field left number target position when the drag began
---@field bottom number
---@field moved boolean?

---@class LBMover : Button
---@field key string "group" for the whole group, otherwise a progress type id
---@field fill Texture
---@field wash Texture lightens the fill while selected
---@field edges Texture[]
---@field label FontString
---@field target Frame?
---@field outline Frame? border
---@field fixed boolean? pinned to a screen edge, so it cannot be dragged
---@field drag LBMoverDrag?
---@field selected boolean?
---@field hovered boolean?
local MoverMixin = {}
LB.MoverMixin = MoverMixin

---@param target Frame
---@param fixed boolean
---@param outline Frame? border
function MoverMixin:Attach(target, fixed, outline)
	self.target = target
	self.fixed = fixed
	self.outline = outline
end

---@return number left how far the shown border reaches past each side of the target
---@return number bottom
---@return number right
---@return number top
function MoverMixin:Padding()
	local target, outline = self.target, self.outline

	if not target or not outline or not outline:IsShown() then
		return 0, 0, 0, 0
	end

	local left, bottom, width, height = target:GetRect()
	local outerLeft, outerBottom, outerWidth, outerHeight = outline:GetRect()

	if not left or not outerLeft then
		return 0, 0, 0, 0
	end

	return math.max(left - outerLeft, 0),
		math.max(bottom - outerBottom, 0),
		math.max(outerLeft + outerWidth - left - width, 0),
		math.max(outerBottom + outerHeight - bottom - height, 0)
end

---@param left number the mover's left edge, border included
---@param bottom number
---@return number left where the target's own edge goes
---@return number bottom
function MoverMixin:TargetPoint(left, bottom)
	local padLeft, padBottom = self:Padding()

	return left + padLeft, bottom + padBottom
end

---@param pixel number the size of one physical pixel in UI units
function MoverMixin:Sync(pixel)
	if not self.target then
		return
	end

	local left, bottom, width, height = self:Rect()
	local pad = math.max((MIN_HEIGHT - height) / 2, 0)
	local screenHeight = UIParent:GetHeight()
	local x1 = LB.Placement:ToPixel(left, pixel)
	local x2 = LB.Placement:ToPixel(left + width, pixel)
	local y1 = LB.Placement:ToPixel(math.max(bottom - pad, 0), pixel)
	local y2 = LB.Placement:ToPixel(math.min(bottom + height + pad, screenHeight), pixel)
	local edges = self.edges

	self:ClearAllPoints()
	self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x1, y1)
	self:SetSize(math.max(x2 - x1, pixel), math.max(y2 - y1, pixel))

	edges[1]:SetHeight(pixel)
	edges[2]:SetHeight(pixel)
	edges[3]:SetWidth(pixel)
	edges[4]:SetWidth(pixel)

	self.label:SetWidth(math.max(x2 - x1 - LABEL_INSET * 2, 0))
end

---@param text string
function MoverMixin:SetLabel(text)
	self.label:SetText(text)
end

function MoverMixin:Paint()
	local r, g, b, a = ACCENT[1], ACCENT[2], ACCENT[3], self.hovered and BORDER_HOVER_ALPHA or BORDER_ALPHA

	if self.selected then
		r, g, b = LB.BRAND[1], LB.BRAND[2], LB.BRAND[3]
		a = BORDER_SELECTED_ALPHA
	end

	for _, edge in ipairs(self.edges) do
		edge:SetVertexColor(r, g, b, a)
	end

	self.wash:SetShown(self.selected == true)
end

---@param selected boolean
function MoverMixin:SetSelected(selected)
	self.selected = selected

	self:SetFrameLevel(selected and LEVEL_SELECTED or LEVEL)
	self:Paint()
end

function MoverMixin:OnEnter()
	self.hovered = true

	self:Paint()
end

function MoverMixin:OnLeave()
	self.hovered = false

	self:Paint()
end

---@return number left
---@return number bottom
---@return number width
---@return number height
function MoverMixin:Rect()
	local target = self.target

	if not target then
		return 0, 0, 0, 0
	end

	local left, bottom, width, height = target:GetRect()
	local padLeft, padBottom, padRight, padTop = self:Padding()

	return (left or 0) - padLeft,
		(bottom or 0) - padBottom,
		(width or 0) + padLeft + padRight,
		(height or 0) + padBottom + padTop
end

---@param button string
function MoverMixin:OnMouseDown(button)
	if button ~= "LeftButton" or not LB.EditMode:Showing() then
		return
	end

	LB.EditMode:Select(self.key)

	if self.fixed or not self.target then
		return
	end

	local x, y = Cursor()
	local left, bottom = self:Rect()

	self.drag = { x = x, y = y, left = left, bottom = bottom }
	self:SetScript("OnUpdate", self.OnDragUpdate)
end

function MoverMixin:OnDragUpdate()
	local drag = self.drag

	if not drag then
		return
	end

	local x, y = Cursor()

	if not drag.moved and (x ~= drag.x or y ~= drag.y) then
		drag.moved = true

		LB.EditMode:BeginDrag()
	end

	LB.EditMode:DragTo(self, drag.left + x - drag.x, drag.bottom + y - drag.y)
end

---@param button string
function MoverMixin:OnMouseUp(button)
	if button == "RightButton" then
		LB.EditMode:Select(self.key)
		LB.EditMode:OpenSettings("layout")

		return
	end

	self:StopDrag(true)
end

---@param commit boolean keep where the drag left the target, rather than dropping it
function MoverMixin:StopDrag(commit)
	local drag = self.drag

	if not drag then
		return
	end

	self.drag = nil
	self:SetScript("OnUpdate", nil)

	LB.EditMode:HideGuides()

	if commit and drag.moved then
		local left, bottom = self:Rect()

		LB.EditMode:Commit(self.key, left, bottom)
	end

	if drag.moved then
		LB.EditMode:EndDrag()
	end
end

---@class LBMoverFactory
---@field accent number[] shared with the rest of edit mode
local Mover = {
	accent = ACCENT,
}
LB.Mover = Mover

---@param key string
---@return LBMover
function Mover:Create(key)
	---@type LBMover
	local mover = CreateFrame("Button", nil, UIParent)

	Mixin(mover, MoverMixin)

	mover.key = key
	mover:SetFrameStrata("DIALOG")
	mover:SetScript("OnMouseDown", mover.OnMouseDown)
	mover:SetScript("OnMouseUp", mover.OnMouseUp)
	mover:SetScript("OnEnter", mover.OnEnter)
	mover:SetScript("OnLeave", mover.OnLeave)
	mover:SetScript("OnHide", function(frame)
		frame:StopDrag(false)
		frame.hovered = false
	end)

	mover.fill = mover:CreateTexture(nil, "BACKGROUND")
	mover.fill:SetTexture(FLAT)
	mover.fill:SetVertexColor(FILL[1], FILL[2], FILL[3], FILL[4])
	mover.fill:SetAllPoints()

	mover.wash = mover:CreateTexture(nil, "BACKGROUND", nil, 1)
	mover.wash:SetTexture(FLAT)
	mover.wash:SetVertexColor(1, 1, 1, WASH_ALPHA)
	mover.wash:SetAllPoints()

	local top = mover:CreateTexture(nil, "BORDER")
	local bottom = mover:CreateTexture(nil, "BORDER")
	local left = mover:CreateTexture(nil, "BORDER")
	local right = mover:CreateTexture(nil, "BORDER")

	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")

	mover.edges = { top, bottom, left, right }

	for _, edge in ipairs(mover.edges) do
		edge:SetTexture(FLAT)
		edge:SetSnapToPixelGrid(false)
		edge:SetTexelSnappingBias(0)
	end

	mover.label = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	mover.label:SetPoint("CENTER")
	mover.label:SetTextColor(1, 1, 1, LABEL_ALPHA)
	mover.label:SetWordWrap(false)

	mover:SetSelected(false)
	mover:Hide()

	return mover
end
