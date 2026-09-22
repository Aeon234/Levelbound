local LB = select(2, ...)

local Callbacks = LB.Callbacks

local PREFIX = "LEVELBOUND_"
local OPAQUE = "ff"
local FLAT = [[Interface\Buttons\WHITE8X8]]

---@class LBSettingOption
---@field value any
---@field label string

---@class LBSettingRow
---@field type "HEADER" | "CHECK" | "SLIDER" | "DROPDOWN" | "COLOR" | "BUTTON" | "CUSTOM"
---@field template string?
---@field searchTags string[]?
---@field label string?
---@field path string?
---@field variable string?
---@field get (fun(): any)?
---@field set (fun(value: any))?
---@field options (LBSettingOption[] | fun(): LBSettingOption[])?
---@field min number?
---@field max number?
---@field step number?
---@field percent boolean?
---@field alphaOf string?
---@field tooltip (string | fun(): string)?
---@field buttonText string?
---@field onClick (fun())?
---@field full boolean?
---@field alone boolean?
---@field gate (fun(): boolean)?
---@field enabled (fun(): boolean)?

---@class LBWidgets
local Widgets = {}
LB.Widgets = Widgets

local COLUMN_GAP = 12
local PAD = 8
local VALUE_PAD = 52
local SLIDER_WIDTH = 160
local DROPDOWN_WIDTH = 150
local STEPPER_WIDTH = 54
local BUTTON_WIDTH = 140

local SWATCH_INSET = 3
local CHECKBOX_ATLAS = "checkbox-minimal"
local CHECKER_ATLAS = "colorpicker-checkerboard"
local HIGHLIGHT_ALPHA = 0.15

local swatches = {}
local rows = {}

---@param swatch any Blizzard's colour swatch button, skinned below
local function PaintSwatch(swatch)
	local row = swatch.lbRow

	if not row or not swatch.lbFill then
		return
	end

	local color = LB.Widgets:Read(row) or { 1, 1, 1, 1 }
	local alpha = color[4] or 1

	swatch.lbFill:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1, alpha)
	swatch.lbCheckers:SetShown(alpha < 1)
end

---@param texture Texture
---@param size number
local function SampleCheckers(texture, size)
	local info = C_Texture.GetAtlasInfo(CHECKER_ATLAS)

	if not info or not info.file then
		texture:SetColorTexture(0.4, 0.4, 0.4, 1)

		return
	end

	local across = math.min(size / info.width, 1)
	local down = math.min(size / info.height, 1)

	texture:SetTexture(info.file)
	texture:SetTexCoord(
		info.leftTexCoord,
		info.leftTexCoord + (info.rightTexCoord - info.leftTexCoord) * across,
		info.topTexCoord,
		info.topTexCoord + (info.bottomTexCoord - info.topTexCoord) * down
	)
end

---@param swatch any
---@param row LBSettingRow?
local function SkinSwatch(swatch, row)
	swatch.lbRow = row

	if swatch.lbFill then
		PaintSwatch(swatch)

		return
	end

	for _, key in ipairs({ "SwatchBg", "InnerBorder", "Color" }) do
		if swatch[key] then
			swatch[key]:Hide()
		end
	end

	local backdrop = swatch:CreateTexture(nil, "BACKGROUND")

	backdrop:SetAtlas(CHECKBOX_ATLAS, true)
	backdrop:SetPoint("CENTER")
	swatch:SetSize(backdrop:GetWidth(), backdrop:GetHeight())

	local checkers = swatch:CreateTexture(nil, "BORDER")
	local fill = swatch:CreateTexture(nil, "ARTWORK")
	local highlight = swatch:CreateTexture(nil, "OVERLAY")

	for _, texture in ipairs({ checkers, fill, highlight }) do
		texture:SetPoint("TOPLEFT", SWATCH_INSET, -SWATCH_INSET)
		texture:SetPoint("BOTTOMRIGHT", -SWATCH_INSET, SWATCH_INSET)
	end

	SampleCheckers(checkers, backdrop:GetWidth() - SWATCH_INSET * 2)
	fill:SetTexture(FLAT)
	highlight:SetTexture(FLAT)
	highlight:SetVertexColor(1, 1, 1, HIGHLIGHT_ALPHA)
	highlight:Hide()

	local mask = swatch.CreateMaskTexture and swatch:CreateMaskTexture()

	if mask and mask.SetAtlas then
		mask:SetAtlas(CHECKBOX_ATLAS)
		mask:SetPoint("TOPLEFT", SWATCH_INSET, -SWATCH_INSET)
		mask:SetPoint("BOTTOMRIGHT", -SWATCH_INSET, SWATCH_INSET)

		for _, texture in ipairs({ checkers, fill, highlight }) do
			texture:AddMaskTexture(mask)
		end
	end

	swatch:HookScript("OnEnter", function()
		highlight:Show()
	end)
	swatch:HookScript("OnLeave", function()
		highlight:Hide()
	end)

	swatch.lbFill = fill
	swatch.lbCheckers = checkers

	swatches[swatch] = true

	PaintSwatch(swatch)
end

---@param frame any
---@return any? control
---@return string? kind
local function Control(frame)
	if frame.SliderWithSteppers then
		return frame.SliderWithSteppers, "SLIDER"
	end

	if frame.Control then
		return frame.Control, "DROPDOWN"
	end

	if frame.Button then
		return frame.Button, "BUTTON"
	end

	if frame.ColorSwatch then
		return frame.ColorSwatch, "SWATCH"
	end

	if frame.Checkbox then
		return frame.Checkbox, "CHECKBOX"
	end

	return nil
end

---@param row Frame
---@param frame any
---@param full boolean?
local function Fit(row, frame, full)
	local control, kind = Control(frame)

	if not control then
		return
	end

	local anchor, relative, offset = frame, "RIGHT", -PAD

	if full then
		anchor, relative, offset = row, "CENTER", -(COLUMN_GAP / 2 + PAD)
	end

	control:ClearAllPoints()

	if kind == "SWATCH" then
		SkinSwatch(control, frame.initializer and frame.initializer.lbRow)
	end

	if kind == "SLIDER" then
		control:SetWidth(SLIDER_WIDTH)
		control:SetPoint("RIGHT", anchor, relative, offset - VALUE_PAD, 3)
	elseif kind == "DROPDOWN" then
		control.Dropdown:SetWidth(DROPDOWN_WIDTH)
		control:SetWidth(DROPDOWN_WIDTH + STEPPER_WIDTH)
		control:SetPoint("RIGHT", anchor, relative, offset, 3)
	elseif kind == "BUTTON" then
		control:SetWidth(BUTTON_WIDTH)
		control:SetPoint("RIGHT", anchor, relative, offset, 0)
	else
		control:SetPoint("RIGHT", anchor, relative, offset, 0)
	end

	frame.Text:ClearAllPoints()
	frame.Text:SetPoint("LEFT", frame, "LEFT", PAD, 0)
	frame.Text:SetPoint("RIGHT", control, "LEFT", -PAD, 0)

	frame.Tooltip:ClearAllPoints()
	frame.Tooltip:SetPoint("TOPLEFT")
	frame.Tooltip:SetPoint("BOTTOMRIGHT", control, "BOTTOMLEFT", -2, 0)
end

LevelboundSettingsRowMixin = {}

---@param frame any
local function Evaluate(frame)
	if frame.EvaluateState then
		frame:EvaluateState()
	end

	if frame.ColorSwatch and frame.IsEnabled then
		frame.ColorSwatch:SetEnabled(frame:IsEnabled())
	end
end

function LevelboundSettingsRowMixin:OnLoad()
	self.slots = { {}, {} }
	self.shown = {}

	rows[self] = true
end

---@param side 1 | 2
---@param initializer table?
---@param full boolean?
function LevelboundSettingsRowMixin:Attach(side, initializer, full)
	local previous = self.shown[side]

	if previous then
		if previous.Release then
			previous:Release()
		end

		previous:Hide()
		self.shown[side] = nil
	end

	if not initializer then
		return
	end

	local template = initializer:GetTemplate()
	local cache = self.slots[side]

	---@type any Blizzard's control templates carry their own mixin, which the checker cannot see
	local frame = cache[template]

	if not frame then
		frame = CreateFrame("Frame", nil, self, template) --[[@as any]]

		frame.GetElementData = function()
			return frame.initializer
		end

		cache[template] = frame
	end

	frame.initializer = initializer
	frame:ClearAllPoints()

	if full then
		frame:SetPoint("TOPLEFT")
		frame:SetPoint("BOTTOMRIGHT")
	elseif side == 1 then
		frame:SetPoint("TOPLEFT")
		frame:SetPoint("BOTTOMRIGHT", self, "BOTTOM", -COLUMN_GAP / 2, 0)
	else
		frame:SetPoint("TOPRIGHT")
		frame:SetPoint("BOTTOMLEFT", self, "BOTTOM", COLUMN_GAP / 2, 0)
	end

	frame:Show()
	frame:Init(initializer)
	Evaluate(frame)
	Fit(self, frame, full)

	self.shown[side] = frame
end

---@param initializer table
function LevelboundSettingsRowMixin:Init(initializer)
	local data = initializer:GetData()

	self:Attach(1, data.left, data.full)
	self:Attach(2, data.right)
end

function LevelboundSettingsRowMixin:Release()
	self:Attach(1, nil)
	self:Attach(2, nil)
end

---@param left table
---@param right table?
---@param full boolean?
---@return table
function Widgets:Row(left, right, full)
	local data = { left = left, right = right, full = full }

	return Settings.CreateElementInitializer("LevelboundSettingsRowTemplate", data)
end

---@param row LBSettingRow
---@return any
function Widgets:Read(row)
	if row.get then
		return row.get()
	end

	if not row.path then
		return nil
	end

	return LB.Profile:Get(row.path)
end

---@param row LBSettingRow
---@param value any
function Widgets:Write(row, value)
	if row.set then
		row.set(value)

		return
	end

	if not row.path then
		return
	end

	LB.Profile:Set(row.path, value)
end

local used = {}

---@param row LBSettingRow
---@param index integer
---@param section string
---@return string
local function Variable(row, index, section)
	local base = row.variable or row.path or tostring(index)
	local variable = PREFIX .. ((section .. "_" .. base):upper():gsub("[^%u%d]", "_"))

	if used[variable] then
		variable = ("%s_%d"):format(variable, index)
	end

	used[variable] = true

	return variable
end

---@param path string?
---@return any
local function DefaultFor(path)
	if not path then
		return nil
	end

	local node = LB.Profile:Defaults()

	for key in path:gmatch("[^.]+") do
		if type(node) ~= "table" then
			return nil
		end

		node = node[key]
	end

	return node
end

---@param color LBColor?
---@return string
local function ToHex(color)
	if not color then
		return OPAQUE .. "ffffff"
	end

	return CreateColor(color[1] or 1, color[2] or 1, color[3] or 1):GenerateHexColor()
end

---@param hex string
---@param previous LBColor?
---@return LBColor
local function FromHex(hex, previous)
	local color = CreateColorFromHexString(hex)

	if not color then
		return previous or { 1, 1, 1 }
	end

	local red, green, blue = color:GetRGB()

	return { red, green, blue, previous and previous[4] or nil }
end

---@param row LBSettingRow
---@return fun(value: number): string
local function Formatter(row)
	return function(value)
		if row.percent then
			return ("%d%%"):format(math.floor(value * 100 + 0.5))
		end

		return tostring(math.floor(value + 0.5))
	end
end

---@param row LBSettingRow
---@return LBSettingOption[]
local function Options(row)
	local options = row.options

	if type(options) == "function" then
		return options()
	end

	return options or {}
end

---@param row LBSettingRow
---@param variable string
---@param category table
---@param value any the default the setting reports
---@param get fun(): any
---@param set fun(value: any)
---@param variableType string
---@return table? setting nil when the registry refused it
local function Proxy(category, variable, row, variableType, value, get, set)
	local setting =
		Settings.RegisterProxySetting(category, variable, variableType, row.label or variable, value, get, set)

	if type(setting) ~= "table" or type(setting.GetVariableType) ~= "function" then
		LB:Warn("the %q setting could not be registered.", tostring(row.label or variable))

		return nil
	end

	return setting
end

---@param category table
---@param layout table
---@param row LBSettingRow
---@param index integer
---@param section string
---@return table? initializer the element this row added to the layout
function Widgets:Add(category, layout, row, index, section)
	local initializer = self:Create(category, layout, row, index, section)

	if initializer and row.enabled then
		initializer:AddModifyPredicate(row.enabled)
	end

	return initializer
end

---@param category table
---@param layout table
---@param row LBSettingRow
---@param index integer
---@param section string
---@return table? initializer
function Widgets:Create(category, layout, row, index, section)
	if row.type == "CUSTOM" then
		local initializer = Settings.CreateElementInitializer(row.template, row)

		initializer:AddSearchTags(row.label, unpack(row.searchTags or {}))
		layout:AddInitializer(initializer)

		return initializer
	end

	if row.type == "HEADER" then
		local initializer = CreateSettingsListSectionHeaderInitializer(row.label)

		layout:AddInitializer(initializer)

		return initializer
	end

	if row.type == "BUTTON" then
		local addSearchTags = true
		local initializer = CreateSettingsButtonInitializer(
			row.label,
			row.buttonText or row.label,
			row.onClick,
			row.tooltip,
			addSearchTags
		)

		layout:AddInitializer(initializer)

		return initializer
	end

	local variable = Variable(row, index, section)

	if row.type == "CHECK" then
		local setting = Proxy(
			category,
			variable,
			row,
			Settings.VarType.Boolean,
			DefaultFor(row.path) == true,
			function()
				return Widgets:Read(row) == true
			end,
			function(value)
				Widgets:Write(row, value == true)
			end
		)

		if setting then
			return Settings.CreateCheckbox(category, setting, row.tooltip)
		end

		return
	end

	if row.type == "SLIDER" then
		local minimum, maximum, step = row.min or 0, row.max or 1, row.step or 1
		local default = DefaultFor(row.alphaOf or row.path) or minimum

		if row.alphaOf then
			default = type(default) == "table" and (default[4] or 1) or 1
		end

		local setting = Proxy(category, variable, row, Settings.VarType.Number, default, function()
			local value = Widgets:Read(row)

			return type(value) == "number" and value or minimum
		end, function(value)
			Widgets:Write(row, row.percent and (math.floor(value * 100 + 0.5) / 100) or math.floor(value + 0.5))
		end)

		if setting then
			local options = Settings.CreateSliderOptions(minimum, maximum, step)

			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right, Formatter(row))
			return Settings.CreateSlider(category, setting, options, row.tooltip)
		end

		return
	end

	if row.type == "DROPDOWN" then
		local setting = Proxy(category, variable, row, Settings.VarType.String, DefaultFor(row.path) or "", function()
			return tostring(Widgets:Read(row) or "")
		end, function(value)
			Widgets:Write(row, value)
		end)

		if setting then
			return Settings.CreateDropdown(category, setting, function()
				local container = Settings.CreateControlTextContainer()

				for _, option in ipairs(Options(row)) do
					container:Add(option.value, option.label)
				end

				return container:GetData()
			end, row.tooltip)
		end

		return
	end

	if row.type == "COLOR" then
		local setting = Proxy(category, variable, row, Settings.VarType.String, ToHex(DefaultFor(row.path)), function()
			return ToHex(Widgets:Read(row))
		end, function(value)
			Widgets:Write(row, FromHex(value, Widgets:Read(row)))
		end)

		if setting then
			local initializer = Settings.CreateColorSwatch(category, setting, row.tooltip)

			initializer.lbRow = row

			return initializer
		end
	end
end

Callbacks:Register("Settings", Widgets, function()
	for swatch in pairs(swatches) do
		if swatch:IsShown() then
			PaintSwatch(swatch)
		end
	end

	for row in pairs(rows) do
		if row:IsShown() then
			for _, frame in pairs(row.shown) do
				Evaluate(frame)
			end
		end
	end
end)
