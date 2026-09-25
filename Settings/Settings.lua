local LB = select(2, ...)

local L = LB.L

local WIDTH = 1100
local HEIGHT = 724
local CATEGORY_WIDTH = 199
local CATEGORY_HEIGHT = 20
local BUTTON_TEMPLATE = "MainMenuFrameButtonTemplate"
local BUTTON_HEIGHT = 32
local CLOSE_WIDTH = 120
local PREVIEW_WIDTH = 190
local EDIT_WIDTH = 150

---@class LBSettingPage
---@field category table
---@field layout table
---@field headers table<table, true>
---@field spans table<table, true>
---@field rows table[]?
---@field customs table<table, true>

---@class LBSettings
---@field frame Frame?
---@field list any?
---@field search EditBox?
---@field previewButton Button?
---@field editButton Button?
---@field returnButton Button?
---@field fade Frame? drives the window's fade back in after an edit session
---@field sessionLabel FontString?
---@field pages table<string, LBSettingPage>
---@field buttons table<string, Button>
---@field active string?
local Panel = {
	pages = {},
	buttons = {},
}
LB.Settings = Panel

---@param dialog Frame
---@return string text
local function EditBoxText(dialog)
	local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox

	if not box then
		return ""
	end

	return box:GetText() or ""
end

StaticPopupDialogs.LEVELBOUND_NEW_PROFILE = {
	text = L["Name the new profile"],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 32,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function(dialog)
		LB.Profile:New(EditBoxText(dialog))
		LB.Settings:Refresh()
	end,
}

StaticPopupDialogs.LEVELBOUND_RENAME_PROFILE = {
	text = L['Rename the profile "%s"'],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 32,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function(dialog)
		LB.Profile:Rename(LB.Profile.activeName, EditBoxText(dialog))
		LB.Settings:Refresh()
	end,
}

StaticPopupDialogs.LEVELBOUND_COPY_PROFILE = {
	text = L["Name the copy"],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 32,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function(dialog)
		LB.Profile:Copy(LB.Profile.activeName, EditBoxText(dialog))
		LB.Settings:Refresh()
	end,
}

StaticPopupDialogs.LEVELBOUND_EXPORT_PROFILE = {
	text = L['Copy this string to share the profile "%s".'],
	button1 = CLOSE,
	hasEditBox = 1,
	maxLetters = 0,
	editBoxWidth = 350,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function(dialog, encoded)
		local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox

		if box then
			box:SetText(encoded or "")
			box:HighlightText()
			box:SetFocus()
		end
	end,
}

StaticPopupDialogs.LEVELBOUND_IMPORT_PROFILE = {
	text = L["Paste a Levelbound profile string."],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 0,
	editBoxWidth = 350,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function(dialog)
		local payload = LB.Profile:Decode(EditBoxText(dialog))

		if payload then
			StaticPopup_Show("LEVELBOUND_NAME_IMPORT", nil, nil, payload)
		end
	end,
}

StaticPopupDialogs.LEVELBOUND_NAME_IMPORT = {
	text = L["Name the imported profile"],
	button1 = ACCEPT,
	button2 = CANCEL,
	hasEditBox = 1,
	maxLetters = 32,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnShow = function(dialog, payload)
		local box = dialog.GetEditBox and dialog:GetEditBox() or dialog.editBox

		if box and payload then
			box:SetText(LB.Profile:FreeName(payload.name))
			box:HighlightText()
		end
	end,
	OnAccept = function(dialog, payload)
		if payload then
			LB.Profile:Import(payload, EditBoxText(dialog))
			LB.Settings:Refresh()
		end
	end,
}

StaticPopupDialogs.LEVELBOUND_DELETE_PROFILE = {
	text = L['Delete the profile "%s"? This cannot be undone.'],
	button1 = ACCEPT,
	button2 = CANCEL,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function()
		LB.Profile:Delete(LB.Profile.activeName)
		LB.Settings:Refresh()
	end,
}

StaticPopupDialogs.LEVELBOUND_RESET_PROFILE = {
	text = L['Reset every setting in the profile "%s"?'],
	button1 = ACCEPT,
	button2 = CANCEL,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function()
		LB.Profile:Reset()
		LB.Settings:Refresh()
	end,
}

local INNER_ATLAS = "Options_InnerFrame"
local INNER_EDGE = 0.45

---@param parent Frame
---@return Frame? frame nil when the client has no such atlas, which leaves the panel plain, not broken
local function InnerFrame(parent)
	local info = C_Texture.GetAtlasInfo(INNER_ATLAS)

	if not info or not info.file then
		return nil
	end

	local frame = CreateFrame("Frame", nil, parent)
	local span = info.rightTexCoord - info.leftTexCoord
	local edge = math.floor(info.width * INNER_EDGE)
	local innerLeft = info.leftTexCoord + span * INNER_EDGE
	local innerRight = info.rightTexCoord - span * INNER_EDGE

	frame:SetHeight(info.height)

	local left = frame:CreateTexture(nil, "OVERLAY", nil, 2)
	local middle = frame:CreateTexture(nil, "OVERLAY", nil, 2)
	local right = frame:CreateTexture(nil, "OVERLAY", nil, 2)

	for _, texture in ipairs({ left, middle, right }) do
		texture:SetTexture(info.file)
	end

	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(edge)
	left:SetTexCoord(info.leftTexCoord, innerLeft, info.topTexCoord, info.bottomTexCoord)

	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(edge)
	right:SetTexCoord(innerRight, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord)

	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	middle:SetTexCoord(innerLeft, innerRight, info.topTexCoord, info.bottomTexCoord)

	return frame
end

---@param button Button
---@param selected boolean
local function PaintCategory(button, selected)
	if selected then
		button.Label:SetFontObject("GameFontHighlight")
		button.Texture:SetAtlas("Options_List_Active", TextureKitConstants.UseAtlasSize)
		button.Texture:Show()

		return
	end

	button.Label:SetFontObject("GameFontNormal")

	if button.over then
		button.Texture:SetAtlas("Options_List_Hover", TextureKitConstants.UseAtlasSize)
		button.Texture:Show()

		return
	end

	button.Texture:Hide()
end

---@param parent Frame
---@param section LBSettingSection
---@param index integer
---@return Button
local function CategoryButton(parent, section, index)
	local button = CreateFrame("Button", nil, parent)

	button:SetSize(CATEGORY_WIDTH, CATEGORY_HEIGHT)
	button:SetPoint("TOPLEFT", 0, -(index - 1) * CATEGORY_HEIGHT)

	local texture = button:CreateTexture(nil, "BACKGROUND")

	texture:SetPoint("CENTER")
	texture:Hide()

	local label = button:CreateFontString(nil, "ARTWORK", "GameFontNormal")

	label:SetJustifyH("LEFT")
	label:SetPoint("TOPLEFT", 16, 1)
	label:SetPoint("BOTTOMRIGHT", 0, 1)
	label:SetText(section.title)

	button.Texture = texture
	button.Label = label

	button:SetScript("OnEnter", function(self)
		self.over = true

		PaintCategory(self, LB.Settings.active == section.id)
	end)
	button:SetScript("OnLeave", function(self)
		self.over = false

		PaintCategory(self, LB.Settings.active == section.id)
	end)
	button:SetScript("OnClick", function()
		LB.Settings:Select(section.id)
	end)

	return button
end

---@param rows LBSettingRow[]
---@return LBSettingRow[] allowed the rows this client can show
local function Allowed(rows)
	local allowed = {}

	for _, row in ipairs(rows) do
		if not row.gate or row.gate() then
			allowed[#allowed + 1] = row
		end
	end

	return allowed
end

---@param section LBSettingSection
---@return LBSettingPage
function Panel:Page(section)
	local page = self.pages[section.id]

	if page then
		return page
	end

	local category, layout = _G.Settings.RegisterVerticalLayoutCategory(("Levelbound %s"):format(section.title))
	local headers, spans, alones, customs = {}, {}, {}, {}

	for index, row in ipairs(Allowed(section.rows)) do
		local initializer = LB.Widgets:Add(category, layout, row, index, section.id)

		if initializer then
			if row.type == "HEADER" then
				headers[initializer] = true
			end

			if row.type == "HEADER" or row.full then
				spans[initializer] = true
			end

			if row.alone then
				alones[initializer] = true
			end

			if row.type == "CUSTOM" then
				customs[initializer] = true
			end
		end
	end

	page = { category = category, layout = layout, headers = headers, spans = spans, customs = customs }
	page.rows = self:Pair(layout:GetInitializers(), spans, headers, alones, customs)

	self.pages[section.id] = page

	return page
end

---@param initializers table[]
---@param spans table<table, true>
---@param headers table<table, true>
---@param alones table<table, true>?
---@param customs table<table, true>?
---@return table[] rows spanning rows alone, everything else two to a row
function Panel:Pair(initializers, spans, headers, alones, customs)
	local rows = {}
	local pending = nil

	for _, initializer in ipairs(initializers) do
		if customs and customs[initializer] then
			if pending then
				rows[#rows + 1] = LB.Widgets:Row(pending)
				pending = nil
			end

			rows[#rows + 1] = initializer
		elseif alones and alones[initializer] then
			if pending then
				rows[#rows + 1] = LB.Widgets:Row(pending)
			end

			rows[#rows + 1] = LB.Widgets:Row(initializer)
			pending = nil
		elseif spans[initializer] then
			if pending then
				rows[#rows + 1] = LB.Widgets:Row(pending)
				pending = nil
			end

			if headers[initializer] then
				rows[#rows + 1] = initializer
			else
				rows[#rows + 1] = LB.Widgets:Row(initializer, nil, true)
			end
		elseif pending then
			rows[#rows + 1] = LB.Widgets:Row(pending, initializer)
			pending = nil
		else
			pending = initializer
		end
	end

	if pending then
		rows[#rows + 1] = LB.Widgets:Row(pending)
	end

	return rows
end

---@param id string
function Panel:Select(id)
	local list = self.list

	if not list then
		return
	end

	self.active = id

	LB.Gain:ClearPreview()
	LB.Marker:ClearPreview()
	LB.LevelUpNotice:ClearPreview()
	LB.TextSlot:SetEditing(false)

	for sectionId, button in pairs(self.buttons) do
		PaintCategory(button, sectionId == id)
	end

	for _, section in ipairs(LB.Panels.sections) do
		if section.id == id then
			local page = self:Page(section)

			list.Header.Title:SetText(section.title)
			list.Header.DefaultsButton:SetShown(LB.Profile:Defaults()[id] ~= nil)
			list:Display(page.rows)

			if section.onSelect then
				section.onSelect()
			end
		end
	end
end

---@return boolean
function Panel:IsOpen()
	return self.frame ~= nil and self.frame:IsShown()
end

---@param text string
function Panel:Search(text)
	local list = self.list

	if not list then
		return
	end

	local upper = text:upper()
	local words = { upper }

	for word in upper:gmatch("[^, ]+") do
		words[#words + 1] = word
	end

	local rows = {}

	for _, section in ipairs(LB.Panels.sections) do
		local page = self:Page(section)
		local matches = {}

		for _, initializer in ipairs(page.layout:GetInitializers()) do
			if not page.headers[initializer] and initializer:MatchesSearchTags(words) then
				matches[#matches + 1] = initializer
			end
		end

		if #matches > 0 then
			rows[#rows + 1] = CreateSettingsListSectionHeaderInitializer(section.title)

			for _, paired in ipairs(self:Pair(matches, {}, {}, nil, page.customs)) do
				rows[#rows + 1] = paired
			end
		end
	end

	for sectionId, button in pairs(self.buttons) do
		PaintCategory(button, sectionId == self.active)
	end

	list.Header.Title:SetText(SEARCH)
	list.Header.DefaultsButton:Hide()
	list:Display(rows)
end

---@param text string
function Panel:OnSearchChanged(text)
	if text == "" then
		if self.active then
			self:Select(self.active)
		end

		return
	end

	self:Search(text)
end

function Panel:Create()
	if self.frame then
		return
	end

	C_AddOns.LoadAddOn("Blizzard_Settings")

	local frame = CreateFrame("Frame", "LevelboundSettings", UIParent, "SettingsFrameTemplate")

	frame:SetSize(WIDTH, HEIGHT)
	frame:SetPoint("CENTER")
	frame:SetFrameStrata("HIGH")
	frame:SetToplevel(true)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetScript("OnShow", function()
		LB.Visibility:SetEditing(true)
		LB.Preview:SetEditing(true)
		LB.EditMode:OnSettingsShown()
		self:PaintPreviewButton()
		self:PaintSession()
	end)
	frame:SetScript("OnHide", function()
		if self.fade then
			LB:StopTween(self.fade)
		end

		frame:SetAlpha(1)
		LB.Gain:ClearPreview()
		LB.Marker:ClearPreview()
		LB.LevelUpNotice:ClearPreview()
		LB.TextSlot:SetEditing(false)

		if LB.EditMode:IsActive() then
			LB.EditMode:OnSettingsHidden()

			return
		end

		LB.Preview:Exit()
		LB.Preview:SetEditing(false)
		LB.Visibility:SetEditing(false)
	end)
	frame:Hide()

	if frame.NineSlice and frame.NineSlice.Text then
		frame.NineSlice.Text:SetText(("%s  |cff9d9d9d%s|r"):format(LB.title, LB.version))
	end

	if frame.ClosePanelButton then
		frame.ClosePanelButton:SetScript("OnClick", function()
			frame:Hide()
		end)
	end

	local inner = InnerFrame(frame)

	if inner then
		inner:SetPoint("TOPLEFT", 17, -64)
		inner:SetPoint("TOPRIGHT", -17, -64)
	end

	local categories = CreateFrame("Frame", nil, frame)

	categories:SetPoint("TOPLEFT", 18, -76)
	categories:SetPoint("BOTTOMLEFT", 178, 46)
	categories:SetWidth(CATEGORY_WIDTH)

	local list = CreateFrame("Frame", nil, frame, "SettingsListTemplate")

	list:SetPoint("TOPLEFT", categories, "TOPRIGHT", 16, 0)
	list:SetPoint("BOTTOMLEFT", categories, "BOTTOMRIGHT", 16, 1)
	list:SetPoint("RIGHT", -22, 0)

	list.Header.DefaultsButton:SetText(SETTINGS_DEFAULTS)
	list.Header.DefaultsButton:SetScript("OnClick", function()
		if self.active then
			LB.Profile:Reset(self.active)
			self:Refresh()
		end
	end)

	local search = CreateFrame("EditBox", "LevelboundSettingsSearchBox", frame, "SearchBoxTemplate")

	search:SetSize(350, 22)
	search:SetPoint("BOTTOMRIGHT", list, "TOPRIGHT", 4, 20)
	search:HookScript("OnTextChanged", function(box)
		LB.Settings:OnSearchChanged(box:GetText() or "")
	end)

	local close = CreateFrame("Button", nil, frame, BUTTON_TEMPLATE)

	close:SetPoint("BOTTOMRIGHT", -16, 8)
	close:SetSize(CLOSE_WIDTH, BUTTON_HEIGHT)
	close:SetText(CLOSE)
	close:SetScript("OnClick", function()
		frame:Hide()
	end)

	local preview = CreateFrame("Button", nil, frame, BUTTON_TEMPLATE)

	preview:SetPoint("TOPLEFT", 16, -28)
	preview:SetSize(PREVIEW_WIDTH, BUTTON_HEIGHT)
	preview:SetScript("OnClick", function()
		if LB.Preview:IsActive() then
			LB.Preview:Exit()
		else
			LB.Preview:Enter()
		end
	end)

	local edit = CreateFrame("Button", nil, frame, BUTTON_TEMPLATE)

	edit:SetPoint("LEFT", preview, "RIGHT", 8, 0)
	edit:SetSize(EDIT_WIDTH, BUTTON_HEIGHT)
	edit:SetText(L["Edit Mode"])
	edit:SetScript("OnClick", function()
		LB.EditMode:Enter(true)
	end)

	local back = CreateFrame("Button", nil, frame, BUTTON_TEMPLATE)

	back:SetPoint("TOPLEFT", preview, "TOPLEFT")
	back:SetSize(PREVIEW_WIDTH, BUTTON_HEIGHT)
	back:SetText(L["Return to Layout"])
	back:SetScript("OnClick", function()
		frame:Hide()
	end)

	local session = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

	session:SetPoint("LEFT", edit, "LEFT")
	session:SetText(L["Editing the layout. Changes are not saved yet."])

	self.frame = frame
	self.list = list
	self.search = search
	self.previewButton = preview
	self.editButton = edit
	self.returnButton = back
	self.sessionLabel = session

	self:PaintPreviewButton()
	self:PaintSession()

	for index, section in ipairs(LB.Panels.sections) do
		self.buttons[section.id] = CategoryButton(categories, section, index)
	end

	tinsert(UISpecialFrames, "LevelboundSettings")
end

function Panel:PaintPreviewButton()
	local button = self.previewButton

	if button then
		button:SetText(LB.Preview:IsActive() and L["Stop Preview"] or L["Preview All Bars"])
	end
end

function Panel:PaintSession()
	local editing = LB.EditMode:IsActive()

	if self.previewButton and self.editButton and self.returnButton and self.sessionLabel then
		self.previewButton:SetShown(not editing)
		self.editButton:SetShown(not editing)
		self.returnButton:SetShown(editing)
		self.sessionLabel:SetShown(editing)
	end
end

---Opens the window on the page it last showed and fades it in.
---@param duration number seconds
function Panel:Reveal(duration)
	self:Open()

	local frame = self.frame

	if not frame then
		return
	end

	self.fade = self.fade or CreateFrame("Frame")

	frame:SetAlpha(0)
	LB:Tween(self.fade, duration, function(eased)
		frame:SetAlpha(eased)
	end)
end

function Panel:Refresh()
	if self.active then
		self:Select(self.active)
	end
end

---@param section string?
function Panel:Open(section)
	self:Create()

	local frame = self.frame

	if not frame then
		return
	end

	frame:Show()
	self:Select(section or self.active or LB.Panels.sections[1].id)
end

function Panel:Close()
	if self.frame then
		self.frame:Hide()
	end
end

function Panel:Toggle()
	if self.frame and self.frame:IsShown() then
		self:Close()

		return
	end

	self:Open()
end

LB.Callbacks:Register("Layout", Panel, function()
	Panel:PaintPreviewButton()
end)
