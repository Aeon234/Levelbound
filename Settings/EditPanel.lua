local LB = select(2, ...)

local L = LB.L

local PAD = 10
local ROW = 28
local LABEL_WIDTH = 14
local LABEL_GAP = 6
local BOX_WIDTH = 64
local BOX_HEIGHT = 20
local ARROW = 24
local CLUSTER_GAP = 16
local PINNED_HEIGHT = 32
local OFFSET = 10

local WIDTH = PAD + LABEL_WIDTH + LABEL_GAP + BOX_WIDTH + CLUSTER_GAP + ARROW * 3 + PAD
local HEIGHT = PAD * 2 + ARROW * 3

---@class LBNudgeArrow
---@field dx number
---@field dy number
---@field family "up" | "down"
---@field rotation number turns the up arrow sideways

---@type LBNudgeArrow[]
local ARROWS = {
	{ dx = 0, dy = 1, family = "up", rotation = 0 },
	{ dx = -1, dy = 0, family = "up", rotation = math.pi / 2 },
	{ dx = 1, dy = 0, family = "up", rotation = -math.pi / 2 },
	{ dx = 0, dy = -1, family = "down", rotation = 0 },
}

---@class LBEditBox : EditBox
---@field label FontString

---@class LBEditPanelFrame : Frame
---@field pinned FontString
---@field x LBEditBox
---@field y LBEditBox
---@field arrows Button[]
---@field key string? the mover the panel shows

---@class LBEditPanel
---@field frame LBEditPanelFrame?
local EditPanel = {}
LB.EditPanel = EditPanel

---@param parent LBEditPanelFrame
---@param label string
---@param apply fun(key: string, value: number)
---@return LBEditBox
local function NumberBox(parent, label, apply)
	---@type LBEditBox
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")

	box:SetSize(BOX_WIDTH, BOX_HEIGHT)
	box:SetAutoFocus(false)
	box:SetScript("OnEnterPressed", function(self)
		local value = tonumber(self:GetText())
		local key = parent.key

		self:ClearFocus()

		if value and key then
			apply(key, value)
		end
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
	end)
	box:HookScript("OnEditFocusLost", function()
		EditPanel:Refresh()
	end)

	box.label = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	box.label:SetWidth(LABEL_WIDTH)
	box.label:SetJustifyH("RIGHT")
	box.label:SetPoint("RIGHT", box, "LEFT", -LABEL_GAP, 0)
	box.label:SetText(label)

	return box
end

---@param box LBEditBox
---@param value number
local function Fill(box, value)
	if not box:HasFocus() then
		box:SetText(tostring(value))
	end
end

---@param button Button
---@param rotation number
local function Rotate(button, rotation)
	for _, texture in ipairs({
		button:GetNormalTexture(),
		button:GetPushedTexture(),
		button:GetDisabledTexture(),
		button:GetHighlightTexture(),
	}) do
		if texture then
			texture:SetRotation(rotation)
		end
	end
end

---@param parent Frame
---@param dx number
---@param dy number
---@param family "up" | "down"
---@param rotation number
---@return Button
local function Arrow(parent, dx, dy, family, rotation)
	local button = CreateFrame("Button", nil, parent)

	button:SetSize(ARROW, ARROW)
	button:SetNormalAtlas("common-button-collapseexpand-" .. family)
	button:SetPushedAtlas("common-button-collapseExpand-" .. family .. "-pressed")
	button:SetDisabledAtlas("common-button-collapseExpand-" .. family .. "-disabled")
	button:SetHighlightAtlas("common-button-collapseExpand-hover")

	Rotate(button, rotation)

	button:SetScript("OnClick", function()
		local step = IsShiftKeyDown() and 10 or 1

		LB.EditMode:Nudge(dx * step, dy * step)
	end)

	return button
end

function EditPanel:Build()
	if self.frame then
		return
	end

	---@type LBEditPanelFrame
	local frame = CreateFrame("Frame", "LevelboundEditPanel", UIParent)

	frame:SetSize(WIDTH, HEIGHT)
	frame:SetFrameStrata("FULLSCREEN_DIALOG")
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:Hide()

	LB.EditMode:Skin(frame)

	local column = PAD + LABEL_WIDTH + LABEL_GAP
	local rows = (HEIGHT - ROW - BOX_HEIGHT) / 2

	frame.x = NumberBox(frame, L["X"], function(key, value)
		local _, y = LB.EditMode:Position(key)

		LB.EditMode:SetPosition(key, value, y)
	end)
	frame.y = NumberBox(frame, L["Y"], function(key, value)
		local x = LB.EditMode:Position(key)

		LB.EditMode:SetPosition(key, x, value)
	end)

	frame.x:SetPoint("TOPLEFT", column, -rows)
	frame.y:SetPoint("TOPLEFT", column, -rows - ROW)

	frame.pinned = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	frame.pinned:SetPoint("CENTER")

	local centre = WIDTH - PAD - ARROW * 1.5
	local places = {
		{ centre, -PAD },
		{ centre - ARROW, -PAD - ARROW },
		{ centre + ARROW, -PAD - ARROW },
		{ centre, -PAD - ARROW * 2 },
	}

	frame.arrows = {}

	for index, arrow in ipairs(ARROWS) do
		local button = Arrow(frame, arrow.dx, arrow.dy, arrow.family, arrow.rotation)
		local place = places[index]

		button:SetPoint("TOP", frame, "TOPLEFT", place[1], place[2])
		frame.arrows[index] = button
	end

	self.frame = frame
end

---@param mover LBMover
function EditPanel:Place(mover)
	local frame = self.frame

	if not frame then
		return
	end

	local _, bottom = mover:Rect()

	frame:ClearAllPoints()

	if bottom - frame:GetHeight() - OFFSET > 0 then
		frame:SetPoint("TOP", mover, "BOTTOM", 0, -OFFSET)
	else
		frame:SetPoint("BOTTOM", mover, "TOP", 0, OFFSET)
	end
end

function EditPanel:Refresh()
	local mover = LB.EditMode:Showing() and LB.EditMode:Selected() or nil

	if not mover then
		self:Hide()

		return
	end

	self:Build()

	local frame = self.frame

	if not frame then
		return
	end

	local fixed = mover.fixed == true

	frame.key = mover.key

	for _, region in ipairs({ frame.x, frame.x.label, frame.y, frame.y.label }) do
		region:SetShown(not fixed)
	end

	for _, arrow in ipairs(frame.arrows) do
		arrow:SetShown(not fixed)
	end

	frame.pinned:SetShown(fixed)

	if fixed then
		local edge = LB.Profile:Get("layout.fullscreen")

		frame.pinned:SetText(edge == "TOP" and L["Pinned to Top Edge"] or L["Pinned to Bottom Edge"])
		frame:SetSize(frame.pinned:GetStringWidth() + PAD * 2, PINNED_HEIGHT)
	else
		local x, y = LB.EditMode:Position(mover.key)

		frame:SetSize(WIDTH, HEIGHT)
		Fill(frame.x, x)
		Fill(frame.y, y)
	end

	self:Place(mover)
	frame:Show()
end

function EditPanel:Hide()
	local frame = self.frame

	if not frame then
		return
	end

	frame.x:ClearFocus()
	frame.y:ClearFocus()
	frame:Hide()
end
