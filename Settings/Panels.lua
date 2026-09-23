local LB = select(2, ...)

local L = LB.L

---@param label string
---@param path string
---@param gate (fun(): boolean)?
---@return LBSettingRow
local function Check(label, path, gate)
	return { type = "CHECK", label = label, path = path, gate = gate }
end

---@param label string
---@param path string
---@param minimum number
---@param maximum number
---@param step number?
---@param percent boolean?
---@return LBSettingRow
local function Slider(label, path, minimum, maximum, step, percent)
	return { type = "SLIDER", label = label, path = path, min = minimum, max = maximum, step = step, percent = percent }
end

---@param label string
---@param path string
---@param options LBSettingOption[] | fun(): LBSettingOption[]
---@return LBSettingRow
local function Dropdown(label, path, options)
	return { type = "DROPDOWN", label = label, path = path, options = options }
end

---@param label string
---@param path string
---@param gate (fun(): boolean)?
---@return LBSettingRow
local function Color(label, path, gate)
	return { type = "COLOR", label = label, path = path, gate = gate }
end

---@param label string
---@param path string
---@return LBSettingRow
local function Alpha(label, path)
	return {
		type = "SLIDER",
		label = label,
		variable = path .. ".alpha",
		alphaOf = path,
		min = 0,
		max = 1,
		step = 0.05,
		percent = true,
		get = function()
			local color = LB.Profile:Get(path)

			return color and color[4] or 1
		end,
		set = function(value)
			local color = LB:CopyTable(LB.Profile:Get(path))

			color[4] = value

			LB.Profile:Set(path, color)
		end,
	}
end

---@param label string
---@return LBSettingRow
local function Header(label)
	return { type = "HEADER", label = label }
end

---@param row LBSettingRow
---@param predicate fun(): boolean
---@return LBSettingRow row
local function Enabled(row, predicate)
	row.enabled = predicate

	return row
end

---@return boolean
local function BorderTextured()
	return LB.Border:IsTextured(LB.Profile:Get("appearance.border.style"))
end

---@return boolean
local function LevelUpOn()
	return LB.Profile:Get("party.levelUp.enabled") == true
end

---@return boolean
local function LevelUpOnScreen()
	return LevelUpOn() and LB.Profile:Get("party.levelUp.onScreen") == true
end

---@param row LBSettingRow
---@param icon string
---@param tooltip string
---@param onClick fun()
---@return LBSettingRow row
local function Accessory(row, icon, tooltip, onClick)
	row.accessory = { icon = icon, tooltip = tooltip, onClick = onClick }

	return row
end

---@param row LBSettingRow
---@return LBSettingRow row
local function Full(row)
	row.full = true

	return row
end

---@param row LBSettingRow
---@return LBSettingRow row
local function Alone(row)
	row.alone = true

	return row
end

---@param label string
---@param buttonText string
---@param onClick fun()
---@return LBSettingRow
local function Button(label, buttonText, onClick)
	return { type = "BUTTON", label = label, buttonText = buttonText, onClick = onClick }
end

---@param row LBSettingRow
---@param set fun(value: any)
---@return LBSettingRow row
local function Setter(row, set)
	row.set = set

	return row
end

---@return boolean
local function NotEditing()
	return not LB.EditMode:IsActive()
end

---@return string
local function EditingNote()
	return LB.EditMode:IsActive() and L["Finish editing the layout to change profiles."] or ""
end

---@param row LBSettingRow
---@return LBSettingRow row
local function Locked(row)
	row.enabled = NotEditing
	row.tooltip = EditingNote

	return row
end

---@param mediaType string
---@return fun(): LBSettingOption[]
local function MediaOptions(mediaType)
	return function()
		local options = {}

		for index, name in ipairs(LB.Media:List(mediaType)) do
			options[index] = { value = name, label = name }
		end

		return options
	end
end

---@param index integer
---@return fun(): LBColor
---@return fun(value: LBColor)
local function GradientStop(index)
	local function Read()
		return LB.Profile:Get("appearance.xpGradient")[index]
	end

	local function Write(value)
		local gradient = LB:CopyTable(LB.Profile:Get("appearance.xpGradient"))

		gradient[index] = value

		LB.Profile:Set("appearance.xpGradient", gradient)
	end

	return Read, Write
end

local OUTLINES = {
	{ value = "NONE", label = NONE },
	{ value = "OUTLINE", label = L["Outline"] },
	{ value = "THICKOUTLINE", label = L["Thick Outline"] },
	{ value = "SLUG", label = L["Slug"] },
	{ value = "SLUG_OUTLINE", label = L["Slug Outline"] },
	{ value = "SLUG_THICKOUTLINE", label = L["Slug Thick Outline"] },
}

local TYPE_LABELS = {
	xp = COMBAT_XP_GAIN,
	petxp = L["Pet Experience"],
	reputation = REPUTATION,
	house = L["Housing Exp"],
	endeavor = L["Neighborhood Endeavor"],
	travelers = L["Travel Points"],
	honor = HONOR,
}

---@return LBSettingRow[]
local function GainColorRows()
	local rows = {}

	for _, id in ipairs(LB.Model:Order()) do
		rows[#rows + 1] = Color(TYPE_LABELS[id] or id, "gain.colors." .. id)
	end

	return rows
end

---@param rows LBSettingRow[]
---@param extra LBSettingRow[]
local function Append(rows, extra)
	for _, row in ipairs(extra) do
		rows[#rows + 1] = row
	end
end

---@class LBSettingSection
---@field id string
---@field title string
---@field rows LBSettingRow[]
---@field onSelect (fun())? run when the page is opened, for a page that demonstrates itself

---@class LBPanels
---@field sections LBSettingSection[]
---@field outlines LBSettingOption[]
---@field typeLabels table<string, string>
local Panels = {}
LB.Panels = Panels

Panels.outlines = OUTLINES
Panels.typeLabels = TYPE_LABELS

local gradientStartGet, gradientStartSet = GradientStop(1)
local gradientEndGet, gradientEndSet = GradientStop(2)

local appearance = {
	Header(L["Bars"]),
	Full(Dropdown(L["Bar Texture"], "appearance.texture", MediaOptions("statusbar"))),
	Full(Check(L["Experience Bar Uses Class Color"], "appearance.xpUseClassColor")),
	{
		type = "COLOR",
		variable = "xpGradientStart",
		label = L["Experience Gradient Start"],
		get = gradientStartGet,
		set = gradientStartSet,
	},
	{
		type = "COLOR",
		variable = "xpGradientEnd",
		label = L["Experience Gradient End"],
		get = gradientEndGet,
		set = gradientEndSet,
	},
	Full(Color(L["Completed-Quest Color"], "appearance.questColor")),
	Color(L["Rested Color"], "appearance.restedColor"),
	Alpha(L["Rested Opacity"], "appearance.restedColor"),
	Color(BACKGROUND, "appearance.background"),
	Alpha(L["Background Opacity"], "appearance.background"),
	Header(L["Type Colors"]),
	Color(TYPE_LABELS.house, "appearance.typeColors.house", function()
		return LB.can.house == true
	end),
	Color(TYPE_LABELS.travelers, "appearance.typeColors.travelers", function()
		return LB.can.travelers == true
	end),
	Color(TYPE_LABELS.endeavor, "appearance.typeColors.endeavor", function()
		return LB.can.endeavor == true
	end),
	Header(L["Border"]),
	Dropdown(L["Border Style"], "appearance.border.style", {
		{ value = "NONE", label = NONE },
		{ value = "ONE_PIXEL", label = L["1 px"] },
		{ value = "TWO_PIXEL", label = L["2 px"] },
		{ value = "THICK", label = L["Thick"] },
		{ value = "ROUNDED", label = L["Rounded"] },
		{ value = "ROUNDED_THICK", label = L["Rounded Thick"] },
	}),
	Enabled(Check(L["Custom Color"], "appearance.border.customColor"), BorderTextured),
	Enabled(Color(L["Border Color"], "appearance.border.color"), function()
		return not BorderTextured() or LB.Profile:Get("appearance.border.customColor") == true
	end),
	Alpha(L["Border Opacity"], "appearance.border.color"),
	Header(L["Spark"]),
	Check(L["Progress Spark"], "appearance.spark.enabled"),
	Color(L["Spark Color"], "appearance.spark.color"),
	Check(L["Gain Shimmer"], "appearance.shimmer"),
	Full(Button(L["Reset Colors"], RESET, function()
		LB.Profile:Reset("appearance")
		LB.Settings:Refresh()
	end)),
}

local gain = {
	Check(L["Show Gain Indicator"], "gain.enabled"),
	Check(L["Hide in Combat"], "gain.hideInCombat"),
	Full(Dropdown(L["Position"], "gain.position", {
		{ value = "FILL_EDGE", label = L["Fill Edge"] },
		{ value = "RIGHT_END", label = L["Right End"] },
	})),
	Header(L["Amount Text"]),
	Dropdown(L["Font"], "gain.text.font", MediaOptions("font")),
	Slider(L["Size"], "gain.text.size", 6, 32, 1),
	Dropdown(L["Outline"], "gain.text.outline", OUTLINES),
	Color(COLOR, "gain.text.color"),

	Alone(Dropdown(L["Text Side"], "gain.text.side", {
		{ value = "LEFT", label = L["Left of the Arrow"] },
		{ value = "RIGHT", label = L["Right of the Arrow"] },
	})),
	Slider(L["Horizontal Offset"], "gain.text.x", -40, 40, 1),
	Slider(L["Vertical Offset"], "gain.text.y", -40, 40, 1),
	Header(L["Arrow Tint"]),
}

Append(gain, GainColorRows())

Panels.sections = {
	{
		id = "general",
		title = GENERAL,
		rows = {
			{
				type = "CHECK",
				full = true,
				variable = "minimapButton",
				label = L["Show Minimap Button"],
				get = function()
					return LB.Profile:Global().minimapButton.hide ~= true
				end,
				set = function(value)
					LB.Profile:Global().minimapButton.hide = not value

					LB.Callbacks:Fire("Settings", "minimapButton", value)
				end,
			},
			{
				type = "CHECK",
				full = true,
				variable = "requestTimePlayed",
				label = L["Request Time Played at Login"],
				get = function()
					return LB.Profile:Global().requestTimePlayed == true
				end,
				set = function(value)
					LB.Profile:Global().requestTimePlayed = value
				end,
			},
		},
	},
	{
		id = "layout",
		title = L["Layout"],
		rows = {
			Header(L["Placement"]),
			Dropdown(L["Layout Mode"], "layout.mode", {
				{ value = "SEGMENTED", label = L["Segmented"] },
				{ value = "CONNECTED", label = L["Connected"] },
				{ value = "INDEPENDENT", label = L["Independent"] },
			}),
			Dropdown(L["Fullscreen Edge"], "layout.fullscreen", {
				{ value = "OFF", label = L["Off"] },
				{ value = "TOP", label = L["Top"] },
				{ value = "BOTTOM", label = L["Bottom"] },
			}),
			Header(L["Size"]),
			Slider(L["Width"], "layout.width", 100, 1600, 10),
			Slider(L["Height"], "layout.height", 4, 64, 1),
			Header(L["Stacking"]),
			Setter(
				Dropdown(L["Growth Direction"], "layout.growth", {
					{ value = "UP", label = L["Up"] },
					{ value = "DOWN", label = L["Down"] },
				}),
				function(value)
					LB.EditMode:SetGrowth(value)
				end
			),
			Slider(L["Gap Between Bars"], "layout.gap", 0, 10, 1),
			Header(L["Advanced"]),
			Dropdown(L["Frame Strata"], "layout.strata", {
				{ value = "BACKGROUND", label = BACKGROUND },
				{ value = "LOW", label = L["Low"] },
				{ value = "MEDIUM", label = L["Medium"] },
				{ value = "HIGH", label = L["High"] },
			}),
		},
	},
	{
		id = "types",
		title = L["Progress Types"],
		rows = {
			Check(TYPE_LABELS.xp, "types.xp"),
			Check(TYPE_LABELS.petxp, "types.petxp", function()
				return LB.can.petXP == true
			end),
			Check(TYPE_LABELS.reputation, "types.reputation"),
			Check(TYPE_LABELS.house, "types.house", function()
				return LB.can.house == true
			end),
			Check(TYPE_LABELS.endeavor, "types.endeavor", function()
				return LB.can.endeavor == true
			end),
			Check(TYPE_LABELS.travelers, "types.travelers", function()
				return LB.can.travelers == true
			end),
			Check(TYPE_LABELS.honor, "types.honor", function()
				return LB.can.honor == true
			end),
		},
	},
	{
		id = "appearance",
		title = L["Appearance"],
		rows = appearance,
	},
	{
		id = "text",
		title = L["Text and Tooltip"],
		onSelect = function()
			LB.TextSlot:SetEditing(true)
		end,
		rows = {
			Header(L["Bar Text"]),
			{
				type = "CUSTOM",
				template = "LevelboundTextEditorTemplate",
				label = L["Bar Text"],
				searchTags = {
					L["Tags"],
					L["slot.ABOVE_LEFT"],
					L["slot.ABOVE_CENTER"],
					L["slot.ABOVE_RIGHT"],
					L["slot.INSIDE_LEFT"],
					L["slot.INSIDE_CENTER"],
					L["slot.INSIDE_RIGHT"],
					L["slot.BELOW_LEFT"],
					L["slot.BELOW_CENTER"],
					L["slot.BELOW_RIGHT"],
				},
			},
			Header(L["Shared Text Style"]),
			Dropdown(L["Font"], "text.style.font", MediaOptions("font")),
			Slider(L["Size"], "text.style.size", 6, 32, 1),
			Dropdown(L["Outline"], "text.style.outline", OUTLINES),
			Color(COLOR, "text.style.color"),
			Header(L["Numbers"]),
			Check(L["Compact Numbers"], "text.compactNumbers"),
			Check(L["Show Decimals"], "text.decimals"),
			Header(L["Tooltip"]),
			Check(L["Show Tooltip"], "tooltip.enabled"),
			Check(L["Click Actions"], "tooltip.clickActions"),
		},
	},
	{
		id = "visibility",
		title = L["Visibility"],
		rows = {
			Header(L["Fading"]),
			Check(L["Fade Until Hovered"], "visibility.fadeUntilHovered"),
			Slider(L["Faded Opacity"], "visibility.fadedAlpha", 0, 1, 0.05, true),
			Header(L["Stay Fully Visible"]),
			Check(L["In Combat"], "visibility.fullInCombat"),
			Check(L["With a Target"], "visibility.fullWithTarget"),
			Header(L["Focus Mode"]),
			Check(L["Dim the Other Bars on Hover"], "visibility.focus.enabled"),
			Slider(L["Dimmed Opacity"], "visibility.focus.alpha", 0, 1, 0.05, true),
			Header(L["Hiding"]),
			Full(Check(L["Hide the Bars in Combat"], "visibility.hideInCombat")),
		},
	},
	{
		id = "gain",
		title = L["Gain Indicator"],
		rows = gain,
		onSelect = function()
			LB.Gain:Preview()
		end,
	},
	{
		id = "party",
		onSelect = function()
			LB.Marker:Preview()
			LB.LevelUpNotice:Preview()
		end,
		title = L["Party"],
		rows = {
			Header(L["Party Markers"]),
			Check(L["Show Party Markers"], "party.markers"),
			Dropdown(L["Marker Visibility"], "party.visibility", {
				{ value = "ALWAYS", label = ALWAYS },
				{ value = "HOVER", label = L["On Hover"] },
			}),
			Dropdown(L["Marker Style"], "party.style", {
				{ value = "DOT", label = L["Dot"] },
				{ value = "TICK", label = L["Full-Height Tick"] },
				{ value = "NOTCH", label = L["Top-Edge Notch"] },
				{ value = "DIAMOND", label = L["Diamond"] },
			}),
			Slider(L["Marker Size"], "party.size", 4, 24, 1),
			Header(L["Level-Up Notices"]),
			Check(L["Show Level-Up Notices"], "party.levelUp.enabled"),
			Enabled(Check(L["On-Screen Notice"], "party.levelUp.onScreen"), LevelUpOn),
			Enabled(Check(L["Chat Message"], "party.levelUp.chat"), LevelUpOn),
			Enabled(Accessory(Check(SOUND, "party.levelUp.sound"), LB.Media.icons.speaker, L["Preview Sound"], function()
				LB.LevelUp:PlaySound()
			end), LevelUpOn),
			Enabled(Check(L["Hide in Combat"], "party.levelUp.hideInCombat"), LevelUpOn),
			Enabled(Dropdown(L["Anchor"], "party.levelUp.anchor", {
				{ value = "TOPLEFT", label = L["Top Left"] },
				{ value = "TOP", label = L["Top"] },
				{ value = "TOPRIGHT", label = L["Top Right"] },
				{ value = "BOTTOMLEFT", label = L["Bottom Left"] },
				{ value = "BOTTOM", label = L["Bottom"] },
				{ value = "BOTTOMRIGHT", label = L["Bottom Right"] },
			}), LevelUpOnScreen),
			Enabled(Dropdown(L["Growth Direction"], "party.levelUp.direction", {
				{ value = "UP", label = L["Up"] },
				{ value = "DOWN", label = L["Down"] },
			}), LevelUpOnScreen),
			Enabled(Slider(L["Horizontal Offset"], "party.levelUp.x", -300, 300, 1), LevelUpOnScreen),
			Enabled(Slider(L["Vertical Offset"], "party.levelUp.y", -200, 200, 1), LevelUpOnScreen),
			Enabled(Dropdown(L["Font"], "party.levelUp.text.font", MediaOptions("font")), LevelUpOnScreen),
			Enabled(Slider(L["Size"], "party.levelUp.text.size", 6, 32, 1), LevelUpOnScreen),
			Enabled(Dropdown(L["Outline"], "party.levelUp.text.outline", OUTLINES), LevelUpOnScreen),
		},
	},
	{
		id = "profiles",
		title = L["Profiles"],
		rows = {
			{
				type = "DROPDOWN",
				full = true,
				variable = "activeProfile",
				label = L["Active Profile"],
				enabled = NotEditing,
				tooltip = EditingNote,
				options = function()
					local options = {}

					for index, name in ipairs(LB.Profile:List()) do
						options[index] = { value = name, label = name }
					end

					return options
				end,
				get = function()
					return LB.Profile.activeName
				end,
				set = function(value)
					LB.Profile:Activate(value)
					LB.Settings:Refresh()
				end,
			},
			{
				type = "CHECK",
				full = true,
				variable = "characterProfile",
				label = L["Use a Profile for This Character"],
				enabled = NotEditing,
				tooltip = EditingNote,
				get = function()
					return LB.Profile.char.useCharacterProfile == true
				end,
				set = function(value)
					LB.Profile:SetUseCharacterProfile(value)
					LB.Settings:Refresh()
				end,
			},
			Header(L["Manage"]),
			Locked(Button(L["New Profile"], NEW, function()
				StaticPopup_Show("LEVELBOUND_NEW_PROFILE")
			end)),
			Locked(Button(L["Rename Current Profile"], L["Rename"], function()
				StaticPopup_Show("LEVELBOUND_RENAME_PROFILE", LB.Profile.activeName)
			end)),
			Locked(Button(L["Copy Current Profile"], L["Copy"], function()
				StaticPopup_Show("LEVELBOUND_COPY_PROFILE")
			end)),
			Button(L["Export Profile"], L["Export"], function()
				local encoded = LB.Profile:Export(LB.Profile.activeName)

				if encoded then
					StaticPopup_Show("LEVELBOUND_EXPORT_PROFILE", LB.Profile.activeName, nil, encoded)
				end
			end),
			Locked(Button(L["Import Profile"], L["Import"], function()
				StaticPopup_Show("LEVELBOUND_IMPORT_PROFILE")
			end)),
			Locked(Button(L["Delete Current Profile"], DELETE, function()
				StaticPopup_Show("LEVELBOUND_DELETE_PROFILE", LB.Profile.activeName)
			end)),
			Locked(Button(L["Reset This Profile"], RESET, function()
				StaticPopup_Show("LEVELBOUND_RESET_PROFILE", LB.Profile.activeName)
			end)),
		},
	},
}
