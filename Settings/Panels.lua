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

---@param key "endeavor" | "travelers"
---@param label string
---@param gate fun(): boolean
---@return LBSettingRow
local function OptIn(key, label, gate)
	return {
		type = "CHECK",
		variable = "optIn." .. key,
		label = label,
		gate = gate,
		get = function()
			return LB.Profile:OptedIn(key)
		end,
		set = function(value)
			LB.Profile:SetOptIn(key, value)
		end,
	}
end

local OUTLINES = {
	{ value = "NONE", label = NONE },
	{ value = "OUTLINE", label = L["Outline"] },
	{ value = "THICKOUTLINE", label = L["Thick outline"] },
	{ value = "SLUG", label = L["Slug"] },
	{ value = "SLUG_OUTLINE", label = L["Slug outline"] },
	{ value = "SLUG_THICKOUTLINE", label = L["Slug thick outline"] },
}

local TYPE_LABELS = {
	xp = COMBAT_XP_GAIN,
	petxp = L["Pet experience"],
	reputation = REPUTATION,
	house = L["House favor"],
	endeavor = L["Neighborhood endeavor"],
	travelers = L["Travel points"],
	honor = HONOR,
	azerite = L["Azerite"],
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
local Panels = {}
LB.Panels = Panels

local gradientStartGet, gradientStartSet = GradientStop(1)
local gradientEndGet, gradientEndSet = GradientStop(2)

local appearance = {
	Header(L["Bars"]),
	Full(Dropdown(L["Bar texture"], "appearance.texture", MediaOptions("statusbar"))),
	Full(Check(L["Experience bar uses class color"], "appearance.xpUseClassColor")),
	{
		type = "COLOR",
		variable = "xpGradientStart",
		label = L["Experience gradient start"],
		get = gradientStartGet,
		set = gradientStartSet,
	},
	{
		type = "COLOR",
		variable = "xpGradientEnd",
		label = L["Experience gradient end"],
		get = gradientEndGet,
		set = gradientEndSet,
	},
	Full(Color(L["Completed-quest color"], "appearance.questColor")),
	-- A colour and its opacity share a row, so the slider is read as belonging to the swatch beside it.
	Color(L["Rested color"], "appearance.restedColor"),
	Alpha(L["Rested opacity"], "appearance.restedColor"),
	Color(BACKGROUND, "appearance.background"),
	Alpha(L["Background opacity"], "appearance.background"),
	Header(L["Type colors"]),
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
	Full(Dropdown(L["Border style"], "appearance.border.style", {
		{ value = "NONE", label = NONE },
		{ value = "ONE_PIXEL", label = L["1 px"] },
		{ value = "TWO_PIXEL", label = L["2 px"] },
		{ value = "RING", label = L["Ring"] },
		{ value = "RING_MEDIUM", label = L["Ring medium"] },
		{ value = "RING_THICK", label = L["Ring thick"] },
	})),
	Color(L["Border color"], "appearance.border.color"),
	Alpha(L["Border opacity"], "appearance.border.color"),
	Header(L["Spark"]),
	Check(L["Progress spark"], "appearance.spark.enabled"),
	Color(L["Spark color"], "appearance.spark.color"),
	Full(Button(L["Reset colors"], RESET, function()
		LB.Profile:Reset("appearance")
		LB.Settings:Refresh()
	end)),
}

local gain = {
	Check(L["Show gain indicator"], "gain.enabled"),
	Check(L["Hide in combat"], "gain.hideInCombat"),
	Full(Button(L["Example gain"], PREVIEW, function()
		LB.Gain:Preview()
	end)),
	Full(Dropdown(L["Position"], "gain.position", {
		{ value = "FILL_EDGE", label = L["Fill edge"] },
		{ value = "RIGHT_END", label = L["Right end"] },
	})),
	Header(L["Amount text"]),
	Dropdown(L["Font"], "gain.text.font", MediaOptions("font")),
	Slider(L["Size"], "gain.text.size", 6, 32, 1),
	Dropdown(L["Outline"], "gain.text.outline", OUTLINES),
	Color(COLOR, "gain.text.color"),
	-- Alone, so the two offsets land on one line together rather than one of them chasing the side.
	Alone(Dropdown(L["Text side"], "gain.text.side", {
		{ value = "LEFT", label = L["Left of the arrow"] },
		{ value = "RIGHT", label = L["Right of the arrow"] },
	})),
	Slider(L["Horizontal offset"], "gain.text.x", -40, 40, 1),
	Slider(L["Vertical offset"], "gain.text.y", -40, 40, 1),
	Header(L["Arrow tint"]),
}

Append(gain, GainColorRows())

Panels.sections = {
	{
		id = "general",
		title = GENERAL,
		rows = {
			Full(Check(L["Hide Blizzard's status tracking bar"], "general.hideBlizzardBar", function()
				return LB.can.statusTrackingBar == true
			end)),
			{
				type = "CHECK",
				full = true,
				variable = "minimapButton",
				label = L["Show minimap button"],
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
				label = L["Request time played at login"],
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
			Dropdown(L["Layout mode"], "layout.mode", {
				{ value = "SEGMENTED", label = L["Segmented"] },
				{ value = "CONNECTED", label = L["Connected"] },
				{ value = "INDEPENDENT", label = L["Independent"] },
			}),
			Dropdown(L["Fullscreen edge"], "layout.fullscreen", {
				{ value = "OFF", label = L["Off"] },
				{ value = "TOP", label = L["Top"] },
				{ value = "BOTTOM", label = L["Bottom"] },
			}),
			Header(L["Size"]),
			Slider(L["Width"], "layout.width", 100, 1600, 10),
			Slider(L["Height"], "layout.height", 4, 64, 1),
			Header(L["Stacking"]),
			Dropdown(L["Growth direction"], "layout.growth", {
				{ value = "UP", label = L["Up"] },
				{ value = "DOWN", label = L["Down"] },
			}),
			Slider(L["Gap between bars"], "layout.gap", 0, 10, 1),
			Header(L["Advanced"]),
			Dropdown(L["Frame strata"], "layout.strata", {
				{ value = "BACKGROUND", label = BACKGROUND },
				{ value = "LOW", label = L["Low"] },
				{ value = "MEDIUM", label = L["Medium"] },
				{ value = "HIGH", label = L["High"] },
			}),
		},
	},
	{
		id = "types",
		title = L["Progress types"],
		rows = {
			Check(TYPE_LABELS.xp, "types.xp"),
			Check(TYPE_LABELS.petxp, "types.petxp", function()
				return LB.can.petXP == true
			end),
			Check(TYPE_LABELS.reputation, "types.reputation"),
			Check(TYPE_LABELS.house, "types.house", function()
				return LB.can.house == true
			end),
			Check(TYPE_LABELS.honor, "types.honor", function()
				return LB.can.honor == true
			end),
			Check(TYPE_LABELS.azerite, "types.azerite", function()
				return LB.can.azerite == true
			end),
			Header(L["This character only"]),
			OptIn("endeavor", TYPE_LABELS.endeavor, function()
				return LB.can.endeavor == true
			end),
			OptIn("travelers", TYPE_LABELS.travelers, function()
				return LB.can.travelers == true
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
		title = L["Text and tooltip"],
		rows = {
			Header(L["Numbers"]),
			Check(L["Compact numbers"], "text.compactNumbers"),
			Check(L["Show decimals"], "text.decimals"),
			Header(L["Tooltip"]),
			Check(L["Show tooltip"], "tooltip.enabled"),
			Check(L["Click actions"], "tooltip.clickActions"),
		},
	},
	{
		id = "visibility",
		title = L["Visibility"],
		rows = {
			Header(L["Fading"]),
			Check(L["Fade until hovered"], "visibility.fadeUntilHovered"),
			Slider(L["Faded opacity"], "visibility.fadedAlpha", 0, 1, 0.05, true),
			Header(L["Stay fully visible"]),
			Check(L["In combat"], "visibility.fullInCombat"),
			Check(L["With a target"], "visibility.fullWithTarget"),
			Header(L["Focus mode"]),
			Check(L["Dim the other bars on hover"], "visibility.focus.enabled"),
			Slider(L["Dimmed opacity"], "visibility.focus.alpha", 0, 1, 0.05, true),
			Header(L["Hiding"]),
			Full(Check(L["Hide the bars in combat"], "visibility.hideInCombat")),
		},
	},
	{
		id = "gain",
		title = L["Gain indicator"],
		rows = gain,
		onSelect = function()
			LB.Gain:Preview()
		end,
	},
	{
		id = "party",
		title = L["Party"],
		rows = {
			Header(L["Party markers"]),
			Check(L["Show party markers"], "party.markers"),
			Dropdown(L["Marker visibility"], "party.visibility", {
				{ value = "ALWAYS", label = ALWAYS },
				{ value = "HOVER", label = L["On hover"] },
			}),
			Dropdown(L["Marker style"], "party.style", {
				{ value = "DOT", label = L["Dot"] },
				{ value = "TICK", label = L["Full-height tick"] },
				{ value = "NOTCH", label = L["Top-edge notch"] },
				{ value = "DIAMOND", label = L["Diamond"] },
			}),
			Slider(L["Marker size"], "party.size", 4, 24, 1),
			Header(L["Glow"]),
			Check(L["Marker glow"], "party.glow"),
			Slider(L["Glow opacity"], "party.glowOpacity", 0, 1, 0.05, true),
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
				label = L["Active profile"],
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
				label = L["Use a profile for this character"],
				get = function()
					return LB.Profile.char.useCharacterProfile == true
				end,
				set = function(value)
					LB.Profile:SetUseCharacterProfile(value)
					LB.Settings:Refresh()
				end,
			},
			Header(L["Manage"]),
			Button(L["New profile"], NEW, function()
				StaticPopup_Show("LEVELBOUND_NEW_PROFILE")
			end),
			Button(L["Copy current profile"], L["Copy"], function()
				StaticPopup_Show("LEVELBOUND_COPY_PROFILE")
			end),
			Button(L["Delete current profile"], DELETE, function()
				StaticPopup_Show("LEVELBOUND_DELETE_PROFILE", LB.Profile.activeName)
			end),
			Button(L["Reset this profile"], RESET, function()
				StaticPopup_Show("LEVELBOUND_RESET_PROFILE", LB.Profile.activeName)
			end),
		},
	},
}
