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
			local color = LB.Profile:Get(path)

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
local function Grouped()
	return not LB.Layout.Independent(LB.Profile:Get("layout"))
end

---@return boolean
local function DividersOn()
	return LB.Profile:Get("appearance.dividers.enabled") == true
end

---@return boolean
local function BorderTextured()
	return LB.Border:IsTextured(LB.Profile:Get("appearance.border.style"))
end

---@return boolean
local function MarkersSeparate()
	return LB.Profile:Get("party.opacity.matchBar") ~= true
end

---@return boolean
local function LevelUpOn()
	return LB.Profile:Get("party.levelUp.enabled") == true
end

---@return boolean
local function LevelUpOnScreen()
	return LevelUpOn() and LB.Profile:Get("party.levelUp.onScreen") == true
end

---@return boolean
local function LevelUpOnBar()
	return LevelUpOnScreen() and LB.Profile:Get("party.levelUp.detached") ~= true
end

---@return boolean
local function GainDetached()
	return LB.Profile:Get("gain.detached") == true
end

---@return boolean
local function GainOnBar()
	return not GainDetached()
end

---@param row LBSettingRow
---@return LBSettingRow row
local function Detach(row)
	row.tooltip = L["Drag it into place in Edit Mode."]

	return row
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
		local gradient = LB.Profile:Get("appearance.xpGradient")

		gradient[index] = value

		LB.Profile:Set("appearance.xpGradient", gradient)
	end

	return Read, Write
end

local OUTLINES = LB.Media.outlines

---@param id string
---@return fun(): boolean gate shows a row only on a client that has the type
local function Capable(id)
	return function()
		return LB.Model:Capable(id)
	end
end

---@return LBSettingRow[]
local function TypeRows()
	local rows = {}

	for _, id in ipairs(LB.Model:Order()) do
		rows[#rows + 1] = Check(LB.Model:Label(id), "types." .. id, Capable(id))
	end

	return rows
end

---@return LBSettingRow[]
local function GainColorRows()
	local rows = {}

	for _, id in ipairs(LB.Model:Order()) do
		rows[#rows + 1] = Color(LB.Model:Label(id), "gain.colors." .. id)
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
---@field demo LBEditingDemo? what the page shows samples of while it is open

---@class LBPanels
---@field sections LBSettingSection[]
local Panels = {}
LB.Panels = Panels


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
	Color(LB.Model:Label("house"), "appearance.typeColors.house", Capable("house")),
	Color(LB.Model:Label("travelers"), "appearance.typeColors.travelers", Capable("travelers")),
	Color(LB.Model:Label("endeavor"), "appearance.typeColors.endeavor", Capable("endeavor")),
	Header(L["Border"]),
	Dropdown(L["Border Style"], "appearance.border.style", {
		{ value = "NONE", label = NONE },
		{ value = "ONE_PIXEL", label = L["1 px"] },
		{ value = "TWO_PIXEL", label = L["2 px"] },
		{ value = "THICK", label = L["Thick"] },
		{ value = "ROUNDED", label = L["Rounded"] },
		{ value = "ROUNDED_THICK", label = L["Rounded Thick"] },
		{ value = "FOREVER", label = L["Forever"] },
		{ value = "METALLIC", label = L["Metallic"] },
	}),
	Enabled(Check(L["Custom Color"], "appearance.border.customColor"), BorderTextured),
	Enabled(Color(L["Border Color"], "appearance.border.color"), function()
		return not BorderTextured() or LB.Profile:Get("appearance.border.customColor") == true
	end),
	Alpha(L["Border Opacity"], "appearance.border.color"),
	Header(L["XP Dividers"]),
	Check(L["Show XP Dividers"], "appearance.dividers.enabled"),
	Enabled(Check(L["Custom Color"], "appearance.dividers.customColor"), DividersOn),
	Enabled(Color(L["Divider Color"], "appearance.dividers.color"), function()
		return DividersOn() and LB.Profile:Get("appearance.dividers.customColor") == true
	end),
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
	Detach(Check(L["Detach from Bar"], "gain.detached")),
	Enabled(
		Dropdown(L["Position"], "gain.position", {
			{ value = "FILL_EDGE", label = L["Fill Edge"] },
			{ value = "RIGHT_END", label = L["Right End"] },
		}),
		GainOnBar
	),
	Enabled(
		Dropdown(L["Growth Direction"], "gain.direction", {
			{ value = "UP", label = L["Up"] },
			{ value = "DOWN", label = L["Down"] },
		}),
		GainDetached
	),
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
			Dropdown(L["Layout Mode"], "layout.mode", LB.Layout.MODES),
			Enabled(
				Dropdown(L["Fullscreen Edge"], "layout.fullscreen", {
					{ value = "OFF", label = L["Off"] },
					{ value = "TOP", label = L["Top"] },
					{ value = "BOTTOM", label = L["Bottom"] },
				}),
				Grouped
			),
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
					LB.BarGroup:SetGrowth(value)
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
		rows = TypeRows(),
	},
	{
		id = "appearance",
		title = L["Appearance"],
		rows = appearance,
	},
	{
		id = "text",
		title = L["Text and Tooltip"],
		demo = "text",
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
		demo = "gain",
	},
	{
		id = "party",
		demo = "party",
		title = L["Party"],
		rows = {
			Header(L["Party Markers"]),
			Check(L["Show Party Markers"], "party.markers"),
			Dropdown(L["Marker Style"], "party.style", {
				{ value = "DOT", label = L["Dot"] },
				{ value = "TICK", label = L["Full-Height Tick"] },
				{ value = "NOTCH", label = L["Top-Edge Notch"] },
				{ value = "DIAMOND", label = L["Diamond"] },
			}),
			Slider(L["Marker Size"], "party.size", 4, 24, 1),
			Header(L["Marker Fading"]),
			Check(L["Match Bar Opacity"], "party.opacity.matchBar"),
			Enabled(Slider(L["Marker Opacity"], "party.opacity.alpha", 0, 1, 0.05, true), MarkersSeparate),
			Enabled(Check(L["Fade Until Hovered"], "party.opacity.fadeUntilHovered"), MarkersSeparate),
			Enabled(Slider(L["Faded Opacity"], "party.opacity.fadedAlpha", 0, 1, 0.05, true), MarkersSeparate),
			Enabled(Check(L["Stay Fully Visible in Combat"], "party.opacity.fullInCombat"), MarkersSeparate),
			Enabled(Check(L["Stay Fully Visible with a Target"], "party.opacity.fullWithTarget"), MarkersSeparate),
			Header(L["Level-Up Notices"]),
			Check(L["Show Level-Up Notices"], "party.levelUp.enabled"),
			Enabled(Check(L["On-Screen Notice"], "party.levelUp.onScreen"), LevelUpOn),
			Enabled(Check(L["Chat Message"], "party.levelUp.chat"), LevelUpOn),
			Enabled(
				Accessory(Check(SOUND, "party.levelUp.sound"), LB.Media.icons.speaker, L["Preview Sound"], function()
					LB.LevelUp:PlaySound()
				end),
				LevelUpOn
			),
			Enabled(Check(L["Hide in Combat"], "party.levelUp.hideInCombat"), LevelUpOn),
			Enabled(Detach(Check(L["Detach from Bar"], "party.levelUp.detached")), LevelUpOnScreen),
			Enabled(
				Dropdown(L["Anchor"], "party.levelUp.anchor", {
					{ value = "TOPLEFT", label = L["Top Left"] },
					{ value = "TOP", label = L["Top"] },
					{ value = "TOPRIGHT", label = L["Top Right"] },
					{ value = "BOTTOMLEFT", label = L["Bottom Left"] },
					{ value = "BOTTOM", label = L["Bottom"] },
					{ value = "BOTTOMRIGHT", label = L["Bottom Right"] },
				}),
				LevelUpOnBar
			),
			Enabled(
				Dropdown(L["Growth Direction"], "party.levelUp.direction", {
					{ value = "UP", label = L["Up"] },
					{ value = "DOWN", label = L["Down"] },
				}),
				LevelUpOnScreen
			),
			Enabled(Slider(L["Horizontal Offset"], "party.levelUp.x", -300, 300, 1), LevelUpOnBar),
			Enabled(Slider(L["Vertical Offset"], "party.levelUp.y", -200, 200, 1), LevelUpOnBar),
			Enabled(Dropdown(L["Font"], "party.levelUp.text.font", MediaOptions("font")), LevelUpOnScreen),
			Enabled(Slider(L["Size"], "party.levelUp.text.size", 6, 32, 1), LevelUpOnScreen),
			Enabled(Dropdown(L["Outline"], "party.levelUp.text.outline", OUTLINES), LevelUpOnScreen),
			Header(L["Announcements"]),
			Check(L["Announce My Level-Ups to Party"], "party.announce.levelUpParty"),
			Check(L["Announce My Level-Ups to Guild"], "party.announce.levelUpGuild"),
			Check(L["Announce Run Summaries to Party"], "party.announce.runParty"),
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
