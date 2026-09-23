local LB = select(2, ...)

local L = LB.L

local FLAT = [[Interface\Buttons\WHITE8X8]]
local APPLY_DELAY = 0.3
local NUDGE_LIMIT = 50
local SIZE_MIN, SIZE_MAX = 6, 32
local TAG_ROW = 15
local TAG_GROUP = 18
local LABEL_WIDTH = 64
local ROW = 30
local GOLD = { 1, 0.82, 0 }
local DIM = { 0.35, 0.3, 0.22 }

local STYLE_FIELDS = { "font", "size", "color", "outline" }

local GROUP_LABELS = {
	PROGRESS = L["Progress"],
	BONUS = L["Rested and Quests"],
	TIME = L["Time"],
}

---@class LBTextEditor
---@field typeId string
---@field key string
---@field frame LBTextEditorFrame?
local Editor = {
	typeId = "xp",
	key = "INSIDE_LEFT",
}
LB.TextEditor = Editor

---@return string
local function Path()
	return ("text.slots.%s.%s"):format(Editor.typeId, Editor.key)
end

---@return LBTextSlot?
local function CurrentSlot()
	return LB.Profile:Get(Path())
end

---@return LBTextSlot
local function EnsureSlot()
	local slot = CurrentSlot()

	if slot then
		return slot
	end

	if not LB.Profile:Get("text.slots." .. Editor.typeId) then
		LB.Profile:Set("text.slots." .. Editor.typeId, {})
	end

	slot = { text = "", visibility = "ALWAYS", x = 0, y = 0, style = {} }
	LB.Profile:Set(Path(), slot)

	return slot
end

---@param field string
---@param value any
local function SetField(field, value)
	EnsureSlot()
	LB.Profile:Set(Path() .. "." .. field, value)
end

---@param field string
---@param value any
local function SetOverride(field, value)
	local slot = EnsureSlot()

	if type(slot.style) ~= "table" then
		LB.Profile:Set(Path() .. ".style", {})
	end

	LB.Profile:Set(Path() .. ".style." .. field, value)
end

---@param key string
---@return string
local function SlotLabel(key)
	return L["slot." .. key]
end

---@return string[] types this client has, in display order, whether or not this character shows them
local function Types()
	local ids = {}

	for _, id in ipairs(LB.Model:Order()) do
		local source = LB.Model:Source(id)
		local ok, capable = pcall(function()
			return source ~= nil and source:Capability()
		end)

		if ok and capable then
			ids[#ids + 1] = id
		end
	end

	return ids
end

---@param id string
---@return string
local function TypeLabel(id)
	return LB.Panels.typeLabels[id] or id
end

---@param parent Frame
---@param template string?
---@return FontString
local function Label(parent, template)
	return parent:CreateFontString(nil, "OVERLAY", template or "GameFontHighlight")
end

---@param frame table a BackdropTemplate frame
---@param color number[]
local function Outline(frame, color)
	frame:SetBackdropBorderColor(color[1], color[2], color[3], 1)
end

---@param parent Frame
---@param width number
---@param onEnter fun(box: EditBox)
---@return EditBox
local function Input(parent, width, onEnter)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")

	box:SetSize(width, 20)
	box:SetAutoFocus(false)
	box:SetScript("OnEnterPressed", function(self)
		onEnter(self)
		self:ClearFocus()
	end)
	box:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()

		if Editor.frame then
			Editor.frame:Refresh()
		end
	end)

	return box
end

---@param parent Frame
---@param text string
---@param width number
---@param onClick fun()
---@return Button
local function Button(parent, text, width, onClick)
	local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")

	button:SetSize(width, 20)
	button:SetText(text)
	button:SetScript("OnClick", onClick)

	return button
end

---@class LBTextEditorFrame : Frame
---@field built boolean?
---@field refreshing boolean?
---@field token integer
---@field cursor integer?
---@field barDropdown table
---@field copyDropdown table
---@field hint FontString
---@field slotButtons table<string, table>
---@field slotTitle FontString
---@field textBox EditBox
---@field visibility table
---@field nudgeX EditBox
---@field nudgeY EditBox
---@field font table
---@field size table
---@field color Button
---@field outline table
---@field states table<string, FontString>
---@field shared table<string, Button>
---@field tagPanel Frame
---@field tagRows table[]
LevelboundTextEditorMixin = {}

function LevelboundTextEditorMixin:OnLoad()
	self.token = 0
	self.slotButtons = {}
	self.states = {}
	self.shared = {}
	self.tagRows = {}
end

function LevelboundTextEditorMixin:Build()
	if self.built then
		return
	end

	self.built = true
	Editor.frame = self

	local barLabel = Label(self, "GameFontNormal")

	barLabel:SetPoint("TOPLEFT", 0, -8)
	barLabel:SetText(L["Bar"])

	self.barDropdown = CreateFrame("DropdownButton", nil, self, "WowStyle1DropdownTemplate")
	self.barDropdown:SetPoint("LEFT", barLabel, "LEFT", LABEL_WIDTH, 0)
	self.barDropdown:SetWidth(180)
	self.barDropdown:SetupMenu(function(_, root)
		for _, id in ipairs(Types()) do
			root:CreateRadio(TypeLabel(id), function()
				return Editor.typeId == id
			end, function()
				Editor.typeId = id
				self:Refresh()
			end)
		end
	end)

	self.copyDropdown = CreateFrame("DropdownButton", nil, self, "WowStyle1DropdownTemplate")
	self.copyDropdown:SetPoint("LEFT", self.barDropdown, "RIGHT", 12, 0)
	self.copyDropdown:SetWidth(170)
	self.copyDropdown:SetDefaultText(L["Copy From"])
	self.copyDropdown:SetupMenu(function(_, root)
		for _, id in ipairs(Types()) do
			if id ~= Editor.typeId then
				root:CreateButton(TypeLabel(id), function()
					StaticPopup_Show("LEVELBOUND_COPY_TEXT", TypeLabel(Editor.typeId), TypeLabel(id), id)
				end)
			end
		end
	end)

	self.hint = Label(self, "GameFontDisableSmall")
	self.hint:SetPoint("TOPLEFT", 0, -34)
	self.hint:SetText(L["This bar is not on screen. Use Preview All Bars to see it."])

	self:BuildDiagram()
	self:BuildSlotControls()
	self:BuildTagPanel()
end

---@return number width of the editing area, left of the tag panel
function LevelboundTextEditorMixin:LeftWidth()
	return math.floor((self:GetWidth() > 0 and self:GetWidth() or 800) * 0.64)
end

function LevelboundTextEditorMixin:BuildDiagram()
	local left = self:LeftWidth()
	local width = math.floor((left - 8) / 3)
	local rows = { -56, -80, -106 }
	local heights = { 20, 22, 20 }

	local bar = self:CreateTexture(nil, "BACKGROUND")

	bar:SetTexture(FLAT)
	bar:SetGradient("HORIZONTAL", CreateColor(0.45, 0.25, 0.9, 1), CreateColor(0.25, 0.45, 0.95, 1))
	bar:SetPoint("TOPLEFT", 0, rows[2])
	bar:SetSize(left, heights[2])

	for index, key in ipairs(LB.TextSlotKeys) do
		local row = math.floor((index - 1) / 3) + 1
		local column = (index - 1) % 3
		local button = CreateFrame("Button", nil, self, "BackdropTemplate")

		button:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
		button:SetBackdropColor(0, 0, 0, row == 2 and 0.25 or 0.5)
		button:SetPoint("TOPLEFT", column * (width + 4), rows[row])
		button:SetSize(width, heights[row])

		button.label = Label(button, "GameFontHighlightSmall")
		button.label:SetPoint("LEFT", 4, 0)
		button.label:SetPoint("RIGHT", -4, 0)
		button.label:SetJustifyH(column == 0 and "LEFT" or (column == 1 and "CENTER" or "RIGHT"))
		button.label:SetWordWrap(false)

		button:SetScript("OnClick", function()
			Editor.key = key
			self:Refresh()
		end)

		self.slotButtons[key] = button
	end
end

---@param y number
---@param text string
---@return FontString
function LevelboundTextEditorMixin:RowLabel(y, text)
	local label = Label(self, "GameFontHighlight")

	label:SetPoint("TOPLEFT", 0, y)
	label:SetText(text)

	return label
end

---@param field string
---@param y number
function LevelboundTextEditorMixin:StyleState(field, y)
	local state = Label(self, "GameFontHighlightSmall")

	state:SetPoint("TOPLEFT", 260, y - 3)
	self.states[field] = state

	self.shared[field] = Button(self, L["Use Shared"], 100, function()
		SetOverride(field, nil)
	end)
	self.shared[field]:SetPoint("TOPLEFT", 330, y + 1)
end

function LevelboundTextEditorMixin:BuildSlotControls()
	local y = -138

	self.slotTitle = Label(self, "GameFontNormal")
	self.slotTitle:SetPoint("TOPLEFT", 0, y)

	y = y - 24
	self:RowLabel(y, L["Text"])

	self.textBox = Input(self, self:LeftWidth() - LABEL_WIDTH - 8, function(box)
		SetField("text", box:GetText())
	end)
	self.textBox:SetPoint("TOPLEFT", LABEL_WIDTH + 6, y + 3)
	self.textBox:SetScript("OnTextChanged", function(box, user)
		self.cursor = box:GetCursorPosition()

		if not user then
			return
		end

		self.token = self.token + 1

		local token = self.token

		C_Timer.After(APPLY_DELAY, function()
			if token == self.token then
				SetField("text", box:GetText())
			end
		end)
	end)
	self.textBox:SetScript("OnEditFocusLost", function(box)
		self.cursor = box:GetCursorPosition()
	end)

	y = y - ROW
	self:RowLabel(y, L["Visibility"])

	self.visibility = CreateFrame("DropdownButton", nil, self, "WowStyle1DropdownTemplate")
	self.visibility:SetPoint("TOPLEFT", LABEL_WIDTH, y + 4)
	self.visibility:SetWidth(130)
	self.visibility:SetupMenu(function(_, root)
		for _, option in ipairs({
			{ "HIDDEN", L["Hidden"] },
			{ "HOVER", L["On Hover"] },
			{ "ALWAYS", ALWAYS },
		}) do
			root:CreateRadio(option[2], function()
				local slot = CurrentSlot()

				return (slot and slot.visibility or "ALWAYS") == option[1]
			end, function()
				SetField("visibility", option[1])
			end)
		end
	end)

	local nudge = Label(self, "GameFontHighlight")

	nudge:SetPoint("TOPLEFT", 220, y)
	nudge:SetText(L["Nudge"])

	self.nudgeX = self:Nudge("x", 280, y)
	self.nudgeY = self:Nudge("y", 380, y)

	y = y - ROW
	self:RowLabel(y, L["Font"])
	self.font = CreateFrame("DropdownButton", nil, self, "WowStyle1DropdownTemplate")
	self.font:SetPoint("TOPLEFT", LABEL_WIDTH, y + 4)
	self.font:SetWidth(180)
	self.font:SetupMenu(function(_, root)
		for _, name in ipairs(LB.Media:List("font")) do
			root:CreateRadio(name, function()
				return self:Effective("font") == name
			end, function()
				SetOverride("font", name)
			end)
		end
	end)
	self:StyleState("font", y)

	y = y - ROW
	self:RowLabel(y, L["Size"])
	self.size = CreateFrame("Slider", nil, self, "MinimalSliderWithSteppersTemplate")
	self.size:SetPoint("TOPLEFT", LABEL_WIDTH, y + 2)
	self.size:SetWidth(180)
	self.size:RegisterCallback(MinimalSliderWithSteppersMixin.Event.OnValueChanged, function(_, value)
		if not self.refreshing then
			SetOverride("size", math.floor(value + 0.5))
		end
	end, self)
	self:StyleState("size", y)

	y = y - ROW
	self:RowLabel(y, COLOR)
	self.color = CreateFrame("Button", nil, self, "BackdropTemplate")
	self.color:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
	self.color:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
	self.color:SetPoint("TOPLEFT", LABEL_WIDTH + 4, y + 1)
	self.color:SetSize(18, 18)
	self.color:SetScript("OnClick", function()
		self:PickColor()
	end)
	self:StyleState("color", y)

	y = y - ROW
	self:RowLabel(y, L["Outline"])
	self.outline = CreateFrame("DropdownButton", nil, self, "WowStyle1DropdownTemplate")
	self.outline:SetPoint("TOPLEFT", LABEL_WIDTH, y + 4)
	self.outline:SetWidth(180)
	self.outline:SetupMenu(function(_, root)
		for _, option in ipairs(LB.Panels.outlines) do
			root:CreateRadio(option.label, function()
				return self:Effective("outline") == option.value
			end, function()
				SetOverride("outline", option.value)
			end)
		end
	end)
	self:StyleState("outline", y)
end

---@param field "x" | "y"
---@param x number
---@param y number
---@return EditBox
function LevelboundTextEditorMixin:Nudge(field, x, y)
	local function Apply(value)
		value = tonumber(value)

		if value then
			SetField(field, math.max(-NUDGE_LIMIT, math.min(NUDGE_LIMIT, math.floor(value + 0.5))))
		end

		self:Refresh()
	end

	local minus = Button(self, "-", 22, function()
		local slot = CurrentSlot()

		Apply((slot and slot[field] or 0) - 1)
	end)

	minus:SetPoint("TOPLEFT", x, y + 1)

	local box = Input(self, 34, function(input)
		Apply(input:GetText())
	end)

	box:SetPoint("LEFT", minus, "RIGHT", 6, 0)
	box:SetNumeric(false)
	box:SetJustifyH("CENTER")

	local plus = Button(self, "+", 22, function()
		local slot = CurrentSlot()

		Apply((slot and slot[field] or 0) + 1)
	end)

	plus:SetPoint("LEFT", box, "RIGHT", 2, 0)

	return box
end

---@param field string
---@return any
function LevelboundTextEditorMixin:Effective(field)
	local slot = CurrentSlot()
	local style = slot and LB.Profile:ResolveStyle(slot) or LB.Profile:Get("text.style")

	return style[field]
end

function LevelboundTextEditorMixin:PickColor()
	local slot = CurrentSlot()
	local previous = slot and slot.style and slot.style.color
	local color = self:Effective("color") or { 1, 1, 1, 1 }

	ColorPickerFrame:SetupColorPickerAndShow({
		r = color[1],
		g = color[2],
		b = color[3],
		hasOpacity = false,
		swatchFunc = function()
			local r, g, b = ColorPickerFrame:GetColorRGB()

			SetOverride("color", { r, g, b, 1 })
		end,
		cancelFunc = function()
			SetOverride("color", previous and LB:CopyTable(previous) or nil)
		end,
	})
end

function LevelboundTextEditorMixin:BuildTagPanel()
	local left = self:LeftWidth()

	self.tagPanel = CreateFrame("Frame", nil, self, "BackdropTemplate")
	self.tagPanel:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, edgeSize = 1 })
	self.tagPanel:SetBackdropColor(0, 0, 0, 0.35)
	self.tagPanel:SetBackdropBorderColor(DIM[1], DIM[2], DIM[3], 1)
	self.tagPanel:SetPoint("TOPLEFT", left + 16, -4)
	self.tagPanel:SetPoint("BOTTOMRIGHT", -4, 4)

	local title = Label(self.tagPanel, "GameFontNormal")

	title:SetPoint("TOPLEFT", 8, -6)
	title:SetText(L["Tags"])

	local help = Label(self.tagPanel, "GameFontDisableSmall")

	help:SetPoint("LEFT", title, "RIGHT", 6, 0)
	help:SetText(L["Click a tag to insert it."])
end

---@param index integer
---@return table row
function LevelboundTextEditorMixin:TagRow(index)
	local row = self.tagRows[index]

	if row then
		return row
	end

	row = CreateFrame("Button", nil, self.tagPanel)
	row:SetHeight(TAG_ROW)
	row:SetPoint("LEFT", 8, 0)
	row:SetPoint("RIGHT", -8, 0)

	row.tag = Label(row, "GameFontHighlightSmall")
	row.tag:SetPoint("LEFT")
	row.tag:SetTextColor(0.6, 1, 0.95)

	row.description = Label(row, "GameFontHighlightSmall")
	row.description:SetPoint("RIGHT")
	row.description:SetJustifyH("RIGHT")

	row:SetHighlightTexture(FLAT)
	row:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.08)
	row:SetScript("OnClick", function(button)
		if button.insert then
			self:Insert(button.insert)
		end
	end)

	self.tagRows[index] = row

	return row
end

---@param tag string
function LevelboundTextEditorMixin:Insert(tag)
	local box = self.textBox
	local text = box:GetText() or ""
	local cursor = math.min(self.cursor or #text, #text)
	local insert = "[" .. tag .. "]"

	box:SetText(text:sub(1, cursor) .. insert .. text:sub(cursor + 1))
	box:SetCursorPosition(cursor + #insert)
	self.cursor = cursor + #insert

	SetField("text", box:GetText())
end

function LevelboundTextEditorMixin:RefreshTags()
	local y = -26
	local index = 0
	local group = nil

	for _, info in ipairs(LB.Tags:For(Editor.typeId)) do
		if info.group ~= group then
			group = info.group
			index = index + 1

			local heading = self:TagRow(index)

			heading:SetPoint("TOP", 0, y - 2)
			heading.tag:SetText(GROUP_LABELS[group])
			heading.tag:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
			heading.description:SetText("")
			heading.insert = nil
			heading:EnableMouse(false)
			heading:Show()

			y = y - TAG_GROUP
		end

		index = index + 1

		local row = self:TagRow(index)

		row:SetPoint("TOP", 0, y)
		row.tag:SetText("[" .. info.tag .. "]")
		row.tag:SetTextColor(0.6, 1, 0.95)
		row.description:SetText(info.description)
		row.insert = info.tag
		row:EnableMouse(true)
		row:Show()

		y = y - TAG_ROW
	end

	for extra = index + 1, #self.tagRows do
		self.tagRows[extra]:Hide()
	end
end

---@param field string
---@param slot LBTextSlot?
function LevelboundTextEditorMixin:PaintState(field, slot)
	local custom = slot ~= nil and type(slot.style) == "table" and slot.style[field] ~= nil
	local state = self.states[field]

	if custom then
		state:SetText(L["Custom"])
		state:SetTextColor(1, 0.8, 0.4)
	else
		state:SetText(L["Shared"])
		state:SetTextColor(0.4, 0.8, 0.4)
	end

	self.shared[field]:SetEnabled(custom)
end

function LevelboundTextEditorMixin:Refresh()
	if not self.built then
		return
	end

	self.refreshing = true

	local slots = LB.Profile:Get("text.slots." .. Editor.typeId) or {}
	local slot = slots[Editor.key]
	local bar = LB.BarGroup.bars[Editor.typeId]

	self.barDropdown:SetDefaultText(TypeLabel(Editor.typeId))
	self.barDropdown:GenerateMenu()
	self.hint:SetShown(not (bar and bar:IsShown()))

	for key, button in pairs(self.slotButtons) do
		local text = slots[key] and slots[key].text or ""

		if text == "" then
			button.label:SetText("+")
			button.label:SetTextColor(0.5, 0.5, 0.5)
		else
			button.label:SetText(text)
			button.label:SetTextColor(1, 1, 1)
		end

		Outline(button, key == Editor.key and GOLD or DIM)
	end

	self.slotTitle:SetText(SlotLabel(Editor.key))

	if not self.textBox:HasFocus() then
		self.textBox:SetText(slot and slot.text or "")
	end

	self.visibility:GenerateMenu()
	self.nudgeX:SetText(tostring(slot and slot.x or 0))
	self.nudgeY:SetText(tostring(slot and slot.y or 0))

	self.font:GenerateMenu()
	self.outline:GenerateMenu()

	local size = self:Effective("size") or 12

	self.size:Init(size, SIZE_MIN, SIZE_MAX, SIZE_MAX - SIZE_MIN, {
		[MinimalSliderWithSteppersMixin.Label.Right] = function(value)
			return tostring(math.floor(value + 0.5))
		end,
	})

	local color = self:Effective("color") or { 1, 1, 1, 1 }

	self.color:SetBackdropColor(color[1], color[2], color[3], 1)

	for _, field in ipairs(STYLE_FIELDS) do
		self:PaintState(field, slot)
	end

	self:RefreshTags()

	self.refreshing = false
end

---@param initializer table
function LevelboundTextEditorMixin:Init(initializer)
	self:Build()
	self:Refresh()
end

StaticPopupDialogs.LEVELBOUND_COPY_TEXT = {
	text = L["Replace the %s text layout with a copy of %s's?"],
	button1 = ACCEPT,
	button2 = CANCEL,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function(_, from)
		LB.Profile:CopySlots(from, Editor.typeId)
	end,
}

LB.Callbacks:Register("Settings", Editor, function()
	local frame = Editor.frame

	if frame and frame:IsVisible() then
		frame:Refresh()
	end
end)
