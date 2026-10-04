local LB = select(2, ...)

local L = LB.L

---@class LBSettingsPages
local Pages = {}
LB.SettingsPages = Pages

-- Values ---------------------------------------------------------------------------------------------------

---@param path string
---@return any
local function Default(path)
	local node = LB.Profile:Defaults()

	for key in path:gmatch("[^.]+") do
		if type(node) ~= "table" then
			return nil
		end

		node = node[key]
	end

	return node
end

---@param color number[]?
---@return table? color with named fields, as the color control takes it
local function Named(color)
	if not color then
		return nil
	end

	return { r = color[1], g = color[2], b = color[3], a = color[4] }
end

-- Page context ---------------------------------------------------------------------------------------------

---Collects what a page's Defaults resets while the page is built: profile paths, and functions for values kept
---outside the profile.
---@class LBPageContext
---@field paths string[]
---@field resets fun()[]

---@return LBPageContext
local function Context()
	return { paths = {}, resets = {} }
end

---@param ctx LBPageContext
---@param path string
local function Track(ctx, path)
	ctx.paths[#ctx.paths + 1] = path
end

---@param setting table
---@param fields table?
---@return table setting
local function Merge(setting, fields)
	for key, value in pairs(fields or {}) do
		setting[key] = value
	end

	return setting
end

-- Settings -------------------------------------------------------------------------------------------------

---@param ctx LBPageContext
---@param control string
---@param id string
---@param label string
---@param path string
---@param fields table?
---@return table setting
local function Setting(ctx, control, id, label, path, fields)
	Track(ctx, path)

	return Merge({
		id = id,
		control = control,
		label = label,
		get = function()
			return LB.Profile:Get(path)
		end,
		set = function(value)
			LB.Profile:Set(path, value)
		end,
	}, fields)
end

local function Check(ctx, id, label, path, fields)
	local setting = Setting(ctx, "checkbox", id, label, path, fields)
	local get = setting.get

	setting.get = function()
		return get() == true
	end

	return setting
end

local function Toggle(ctx, id, label, path, fields)
	local setting = Check(ctx, id, label, path, fields)

	setting.control = "toggle"

	return setting
end

local function Slider(ctx, id, label, path, minimum, maximum, step, fields)
	return Setting(
		ctx,
		"slider",
		id,
		label,
		path,
		Merge({
			min = minimum,
			max = maximum,
			step = step or 1,
			format = "integer",
		}, fields)
	)
end

---A 0 to 1 value shown as a percentage in steps of 5.
local function Percent(ctx, id, label, path, fields)
	return Setting(
		ctx,
		"slider",
		id,
		label,
		path,
		Merge({
			min = 0,
			max = 100,
			step = 5,
			format = "percent",
			get = function()
				return math.floor((LB.Profile:Get(path) or 0) * 100 + 0.5)
			end,
			set = function(value)
				LB.Profile:Set(path, value / 100)
			end,
		}, fields)
	)
end

---@param options { value: any, label: string }[] | fun(): { value: any, label: string }[]
---@return fun(): table[]
local function Choices(options)
	return function()
		local list = type(options) == "function" and options() or options
		local choices = {}

		for index, option in ipairs(list) do
			choices[index] = { value = option.value, text = option.label }
		end

		return choices
	end
end

local function Choice(ctx, id, label, path, options, fields)
	return Setting(ctx, "dropdown", id, label, path, Merge({ options = Choices(options) }, fields))
end

local function Font(ctx, id, label, path, fields)
	return Setting(ctx, "dropdown", id, label, path, Merge({ picker = "font", options = {} }, fields))
end

local function Texture(ctx, id, label, path, fields)
	return Setting(ctx, "dropdown", id, label, path, Merge({ picker = "texture", options = {} }, fields))
end

---A color stored as `{ r, g, b, a? }`. With `opacity`, the swatch edits the alpha too; without, a stored alpha is
---kept as it is.
local function Color(ctx, id, label, path, opacity, fields)
	return Setting(
		ctx,
		"color",
		id,
		label,
		path,
		Merge({
			hasOpacity = opacity == true,
			get = function()
				return Named(LB.Profile:Get(path))
			end,
			set = function(value)
				local old = LB.Profile:Get(path) or {}
				local alpha = opacity and (value.a or 1) or old[4]

				LB.Profile:Set(path, { value.r, value.g, value.b, alpha })
			end,
		}, fields)
	)
end

---@param id string
---@param title string
---@param fields table?
---@return table element
local function Section(id, title, fields)
	return Merge({ kind = "section", id = id, title = title }, fields)
end

---@param left table
---@param right table?
---@return table element
local function Row(left, right)
	if right then
		return { kind = "setting", settings = { left, right } }
	end

	return { kind = "setting", setting = left }
end

Pages.Setting, Pages.Check, Pages.Slider, Pages.Choice = Setting, Check, Slider, Choice
Pages.Font, Pages.Color, Pages.Section, Pages.Row, Pages.Merge = Font, Color, Section, Row, Merge
Pages.Named = Named

-- Shared choices and conditions ----------------------------------------------------------------------------

local UP_DOWN = {
	{ value = "UP", label = L["Up"] },
	{ value = "DOWN", label = L["Down"] },
}

---@return { value: string, label: string }[]
local function Outlines()
	return LB.Media.outlines
end
Pages.Outlines = Outlines

-- None and the flat lines lead; the textured styles follow in each locale's alphabetical order.
---@return { value: string, label: string }[]
local function BorderStyles()
	local textured = {
		{ value = "ROUNDED", label = L["Simple"] },
		{ value = "ROUNDED_THICK", label = L["Simple Thick"] },
		{ value = "BRONZE", label = L["Bronze"] },
		{ value = "METALLIC", label = L["Metallic"] },
	}

	table.sort(textured, function(a, b)
		return strcmputf8i(a.label, b.label) < 0
	end)

	local options = {
		{ value = "NONE", label = NONE },
		{ value = "ONE_PIXEL", label = L["1 Pixel"] },
		{ value = "TWO_PIXEL", label = L["2 Pixel"] },
	}

	for _, option in ipairs(textured) do
		options[#options + 1] = option
	end

	return options
end

---@return boolean
local function Independent()
	return LB.Layout.Independent(LB.Profile:Get("layout"))
end

---@return string?
local function NotIndependent()
	if Independent() then
		return L["Not in Independent layout."]
	end
end

---@return string?
local function OnlyIndependent()
	if not Independent() then
		return L["Only in Independent layout."]
	end
end
Pages.OnlyIndependent = OnlyIndependent

---@return string?
local function NotSegmented()
	if LB.Profile:Get("layout.mode") == "SEGMENTED" then
		return L["Only in Connected or Independent layout."]
	end
end

-- Pages ----------------------------------------------------------------------------------------------------

---@param ctx LBPageContext
---@return table[]
local function General(ctx)
	local global = LB.Profile:Global()

	local minimap = {
		id = "minimapButton",
		control = "checkbox",
		label = L["Show Minimap Button"],
		get = function()
			return LB.Profile:Global().minimapButton.hide ~= true
		end,
		set = function(value)
			LB.Profile:Global().minimapButton.hide = not value
			LB.Callbacks:Fire("Settings", "minimapButton", value)
		end,
	}

	local timePlayed = {
		id = "requestTimePlayed",
		control = "checkbox",
		label = L["Request Time Played at Login"],
		get = function()
			return LB.Profile:Global().requestTimePlayed == true
		end,
		set = function(value)
			LB.Profile:Global().requestTimePlayed = value
		end,
	}

	ctx.resets[#ctx.resets + 1] = function()
		global.minimapButton.hide = false
		global.requestTimePlayed = true
		LB.Callbacks:Fire("Settings", "minimapButton", true)
	end

	local resetSession = {
		id = "resetSession",
		control = "action",
		label = L["Reset Session"],
		description = L["This character only."],
		verb = L["Reset"],
		set = function(_, window)
			LB.Session:Reset()
			window:ShowStatus(L["Session reset."])

			return true
		end,
	}

	return {
		Section("access", L["Access"]),
		Row(minimap),
		Section("interaction", L["Bar Interaction"]),
		Row(
			Check(ctx, "tooltip", L["Show Tooltip"], "tooltip.enabled"),
			Check(ctx, "clickActions", L["Click to Open or Share"], "tooltip.clickActions")
		),
		Section("time", L["Time Tracking"]),
		Row(timePlayed),
		Row(resetSession),
	}
end

---@param ctx LBPageContext
---@return table[]
local function Layout(ctx)
	return {
		Section("placement", L["Placement"], { tab = "layout" }),
		Row(
			Choice(ctx, "mode", L["Layout Mode"], "layout.mode", LB.Layout.MODES),
			Choice(ctx, "fullscreen", L["Fullscreen Edge"], "layout.fullscreen", {
				{ value = "OFF", label = L["Off"] },
				{ value = "TOP", label = L["Top"] },
				{ value = "BOTTOM", label = L["Bottom"] },
			}, { blocked = NotIndependent })
		),
		Row(Choice(ctx, "strata", L["Frame Strata"], "layout.strata", {
			{ value = "BACKGROUND", label = BACKGROUND },
			{ value = "LOW", label = L["Low"] },
			{ value = "MEDIUM", label = L["Medium"] },
			{ value = "HIGH", label = L["High"] },
		})),
		Section("size", L["Size"], { tab = "layout" }),
		Row(
			Slider(ctx, "width", L["Width"], "layout.width", 100, 1600, 1),
			Slider(ctx, "height", L["Height"], "layout.height", 4, 64, 1)
		),
		Section("stacking", L["Stacking"], { tab = "layout" }),
		Row(
			Choice(ctx, "growth", L["Growth Direction"], "layout.growth", UP_DOWN, {
				blocked = NotSegmented,
				set = function(value)
					LB.BarGroup:SetGrowth(value)
				end,
			}),
			Slider(ctx, "gap", L["Gap Between Bars"], "layout.gap", 0, 10, 1, { blocked = NotSegmented })
		),
	}
end

---@param ctx LBPageContext
---@return table[]
local function Appearance(ctx)
	local function Textured()
		return LB.Border:IsTextured(LB.Profile:Get("appearance.border.style"))
	end

	return {
		Section("bars", L["Bars"], { tab = "appearance" }),
		Row(Texture(ctx, "texture", L["Bar Texture"], "appearance.texture")),
		Row(Color(ctx, "background", BACKGROUND, "appearance.background", true)),
		Section("border", L["Border"], { tab = "appearance" }),
		Row(Choice(ctx, "borderStyle", L["Border Style"], "appearance.border.style", BorderStyles)),
		Row(
			Check(ctx, "borderCustom", L["Custom Color"], "appearance.border.customColor", {
				blocked = function()
					if not Textured() then
						return L["Pixel borders always use Border Color."]
					end
				end,
			}),
			Color(ctx, "borderColor", L["Border Color"], "appearance.border.color", true, {
				blocked = function()
					if Textured() and LB.Profile:Get("appearance.border.customColor") ~= true then
						return L["Requires Custom Color to be enabled."]
					end
				end,
			})
		),
		Row(Check(ctx, "dividers", L["Show XP Dividers"], "appearance.dividers.enabled")),
		Row(
			Check(ctx, "dividerCustom", L["Divider Custom Color"], "appearance.dividers.customColor", {
				depends = "dividers",
			}),
			Color(ctx, "dividerColor", L["Divider Color"], "appearance.dividers.color", false, {
				depends = "dividerCustom",
			})
		),
		Section("spark", L["Spark and Shimmer"], { tab = "appearance" }),
		Row(
			Check(ctx, "spark", L["Progress Spark"], "appearance.spark.enabled"),
			Check(ctx, "shimmer", L["Gain Shimmer"], "appearance.shimmer")
		),
		Row(
			Check(ctx, "sparkCustom", L["Custom Spark Color"], "appearance.spark.customColor", {
				depends = "spark",
			}),
			Color(ctx, "sparkColor", L["Spark Color"], "appearance.spark.color", false, {
				depends = "sparkCustom",
			})
		),
	}
end

---@param ctx LBPageContext
---@return table[]
local function Text(ctx)
	return {
		Section("style", L["Text Style"], { tab = "text" }),
		Row(
			Font(ctx, "font", L["Font"], "text.style.font"),
			Slider(ctx, "size", L["Size"], "text.style.size", 6, 32, 1)
		),
		Row(
			Choice(ctx, "outline", L["Outline"], "text.style.outline", Outlines),
			Color(ctx, "color", COLOR, "text.style.color", false)
		),
		Section("numbers", L["Numbers"], { tab = "text" }),
		Row(
			Check(ctx, "compact", L["Compact Numbers"], "text.compactNumbers"),
			Check(ctx, "decimals", L["Show Decimals"], "text.decimals")
		),
	}
end

---@param ctx LBPageContext
---@return table[]
local function Visibility(ctx)
	local function NeedsFade()
		if LB.Profile:Get("visibility.fadeUntilHovered") ~= true then
			return L["Needs Fade Until Hovered."]
		end
	end

	return {
		Section("fading", L["Fading"], { tab = "visibility" }),
		Row(
			Check(ctx, "fade", L["Fade Until Hovered"], "visibility.fadeUntilHovered"),
			Percent(ctx, "fadedAlpha", L["Faded Opacity"], "visibility.fadedAlpha", { blocked = NeedsFade })
		),
		Row(
			Check(ctx, "fullInCombat", L["Fully Visible in Combat"], "visibility.fullInCombat", { blocked = NeedsFade }),
			Check(ctx, "fullWithTarget", L["Fully Visible with a Target"], "visibility.fullWithTarget", {
				blocked = NeedsFade,
			})
		),
		Section("focus", L["Focus Mode"], { tab = "visibility" }),
		Row(
			Check(ctx, "focus", L["Dim Other Bars on Hover"], "visibility.focus.enabled"),
			Percent(ctx, "focusAlpha", L["Dimmed Opacity"], "visibility.focus.alpha", { depends = "focus" })
		),
		Section("hiding", L["Hiding"], { tab = "visibility" }),
		Row(Check(ctx, "hideInCombat", L["Hide in Combat"], "visibility.hideInCombat")),
	}
end

---The Bars page: Layout, Appearance, Text and Visibility, one tab each.
---@param ctx LBPageContext
---@return table[]
local function Bars(ctx)
	local elements = {}

	for _, build in ipairs({ Layout, Appearance, Text, Visibility }) do
		for _, element in ipairs(build(ctx)) do
			elements[#elements + 1] = element
		end
	end

	return elements
end

---@param ctx LBPageContext
---@return table[]
local function Gain(ctx)
	local function Detached()
		return LB.Profile:Get("gain.detached") == true
	end

	local elements = {
		Section("behavior", L["Behavior"], { tab = "behavior" }),
		Row(Toggle(ctx, "enabled", L["Show Gain Indicator"], "gain.enabled", { pageSwitch = true })),
		Row(
			Check(ctx, "hideInCombat", L["Hide in Combat"], "gain.hideInCombat"),
			Check(ctx, "detached", L["Detach from Bar"], "gain.detached", { description = L["Place it in Edit Mode."] })
		),
		Section("placement", L["Placement"], { tab = "behavior" }),
		Row(
			Choice(ctx, "position", L["Position"], "gain.position", {
				{ value = "FILL_EDGE", label = L["Fill Edge"] },
				{ value = "RIGHT_END", label = L["Right End"] },
			}, {
				blocked = function()
					if Detached() then
						return L["Detached: placed in Edit Mode."]
					end
				end,
			}),
			Choice(ctx, "direction", L["Growth Direction"], "gain.direction", UP_DOWN, {
				blocked = function()
					if not Detached() then
						return L["Only when detached."]
					end
				end,
			})
		),
		Section("amount", L["Amount Text"], { tab = "amount" }),
		Row(Font(ctx, "font", L["Font"], "gain.text.font"), Slider(ctx, "size", L["Size"], "gain.text.size", 6, 32, 1)),
		Row(
			Choice(ctx, "outline", L["Outline"], "gain.text.outline", Outlines),
			Color(ctx, "color", COLOR, "gain.text.color", false)
		),
		Row(Choice(ctx, "side", L["Text Side"], "gain.text.side", {
			{ value = "LEFT", label = L["Left of the Arrow"] },
			{ value = "RIGHT", label = L["Right of the Arrow"] },
		})),
		Row(
			Slider(ctx, "x", L["Horizontal Offset"], "gain.text.x", -40, 40, 1),
			Slider(ctx, "y", L["Vertical Offset"], "gain.text.y", -40, 40, 1)
		),
		Section("tints", L["Arrow Tints"], { tab = "amount" }),
	}

	local tints = {}

	for _, id in ipairs(LB.Model:Order()) do
		if LB.Model:Capable(id) then
			tints[#tints + 1] = Color(ctx, "tint." .. id, LB.Model:Label(id), "gain.colors." .. id, false)
		end
	end

	for index = 1, #tints, 2 do
		elements[#elements + 1] = Row(tints[index], tints[index + 1])
	end

	return elements
end

---@param ctx LBPageContext
---@return table[]
local function Markers(ctx)
	local function Matched()
		if LB.Profile:Get("party.opacity.matchBar") == true then
			return L["Uses the bar's opacity."]
		end
	end

	local function MatchedOrNoFade()
		local matched = Matched()

		if matched then
			return matched
		end

		if LB.Profile:Get("party.opacity.fadeUntilHovered") ~= true then
			return L["Needs Fade Until Hovered."]
		end
	end

	return {
		Section("markers", L["Party Markers"], { tab = "markers" }),
		Row(Toggle(ctx, "markers", L["Show Party Markers"], "party.markers", { pageSwitch = true })),
		Row(
			Choice(ctx, "style", L["Marker Style"], "party.style", {
				{ value = "DOT", label = L["Dot"] },
				{ value = "TICK", label = L["Full-Height Tick"] },
				{ value = "NOTCH", label = L["Top-Edge Notch"] },
				{ value = "DIAMOND", label = L["Diamond"] },
			}),
			Slider(ctx, "size", L["Marker Size"], "party.size", 4, 24, 1)
		),
		Section("fading", L["Marker Fading"], { tab = "fading" }),
		Row(
			Check(ctx, "matchBar", L["Match Bar Opacity"], "party.opacity.matchBar"),
			Percent(ctx, "alpha", L["Marker Opacity"], "party.opacity.alpha", { blocked = Matched })
		),
		Row(
			Check(ctx, "fade", L["Fade Until Hovered"], "party.opacity.fadeUntilHovered", { blocked = Matched }),
			Percent(ctx, "fadedAlpha", L["Faded Opacity"], "party.opacity.fadedAlpha", { blocked = MatchedOrNoFade })
		),
		Row(
			Check(ctx, "fullInCombat", L["Fully Visible in Combat"], "party.opacity.fullInCombat", {
				blocked = MatchedOrNoFade,
			}),
			Check(ctx, "fullWithTarget", L["Fully Visible with a Target"], "party.opacity.fullWithTarget", {
				blocked = MatchedOrNoFade,
			})
		),
	}
end

---@param ctx LBPageContext
---@return table[]
local function LevelUps(ctx)
	local function Detached()
		if LB.Profile:Get("party.levelUp.detached") == true then
			return L["Detached: placed in Edit Mode."]
		end
	end

	local sound = Setting(ctx, "dropdown", "sound", SOUND, "party.levelUp.sound", {
		depends = "notices",
		picker = "sound",
		options = { { value = "None", text = NONE } },
	})

	return {
		Section("notices", L["Party Notices"], { tab = "notices" }),
		Row(Toggle(ctx, "notices", L["Show Level-Up Notices"], "party.levelUp.enabled")),
		Row(
			Check(ctx, "onScreen", L["On-Screen Notice"], "party.levelUp.onScreen", { depends = "notices" }),
			Check(ctx, "chat", L["Chat Message"], "party.levelUp.chat", { depends = "notices" })
		),
		Row(
			sound,
			Check(ctx, "hideInCombat", L["Hide in Combat"], "party.levelUp.hideInCombat", { depends = "notices" })
		),
		Section("placement", L["Placement"], { tab = "notices" }),
		Row(Check(ctx, "detached", L["Detach from Bar"], "party.levelUp.detached", {
			depends = "onScreen",
			description = L["Place it in Edit Mode."],
		})),
		Row(
			Choice(ctx, "anchor", L["Anchor"], "party.levelUp.anchor", {
				{ value = "TOPLEFT", label = L["Top Left"] },
				{ value = "TOP", label = L["Top"] },
				{ value = "TOPRIGHT", label = L["Top Right"] },
				{ value = "BOTTOMLEFT", label = L["Bottom Left"] },
				{ value = "BOTTOM", label = L["Bottom"] },
				{ value = "BOTTOMRIGHT", label = L["Bottom Right"] },
			}, { depends = "onScreen", blocked = Detached }),
			Choice(
				ctx,
				"direction",
				L["Growth Direction"],
				"party.levelUp.direction",
				UP_DOWN,
				{ depends = "onScreen" }
			)
		),
		Row(
			Slider(ctx, "x", L["Horizontal Offset"], "party.levelUp.x", -300, 300, 1, {
				depends = "onScreen",
				blocked = Detached,
			}),
			Slider(ctx, "y", L["Vertical Offset"], "party.levelUp.y", -200, 200, 1, {
				depends = "onScreen",
				blocked = Detached,
			})
		),
		Section("text", L["Notice Text"], { tab = "notices" }),
		Row(
			Font(ctx, "font", L["Font"], "party.levelUp.text.font", { depends = "onScreen" }),
			Slider(ctx, "size", L["Size"], "party.levelUp.text.size", 6, 32, 1, { depends = "onScreen" })
		),
		Row(Choice(ctx, "outline", L["Outline"], "party.levelUp.text.outline", Outlines, { depends = "onScreen" })),
		Section("announce", L["Announcements"], { tab = "announce" }),
		Row(
			Check(ctx, "levelUpParty", L["Party Level-Up Message"], "party.announce.levelUpParty"),
			Check(ctx, "levelUpGuild", L["Guild Level-Up Message"], "party.announce.levelUpGuild")
		),
		Row(
			Check(ctx, "runSummary", L["Post-Dungeon Summary"], "party.announce.runSummary"),
			Choice(ctx, "runChannel", L["Channels"], "party.announce.runChannel", {
				{ value = "SELF", label = L["Self Only"] },
				{ value = "PARTY", label = PARTY },
				{ value = "INSTANCE", label = INSTANCE_CHAT },
				{ value = "GUILD", label = GUILD },
			}, { depends = "runSummary" })
		),
	}
end

---One progress type's page: its switch, colors, own size, text slots and arrow tint.
---@param ctx LBPageContext
---@param id string
---@return table[]
local function TypePage(ctx, id)
	local label = LB.Model:Label(id)
	local switch = Toggle(ctx, "enabled", L["Show %s Bar"]:format(label), "types." .. id, { pageSwitch = true })
	local elements = {}

	local function Add(element)
		elements[#elements + 1] = element
	end

	local switched = false

	local function Open(section)
		Add(section)

		if not switched then
			Add(Row(switch))
			switched = true
		end
	end

	if id == "xp" then
		local function ClassColor()
			if LB.Profile:Get("appearance.xpUseClassColor") == true then
				return L["Uses your class color."]
			end
		end

		local function Stop(index)
			return {
				get = function()
					return Named(LB.Profile:Get("appearance.xpGradient")[index])
				end,
				set = function(value)
					local gradient = LB.Profile:Get("appearance.xpGradient")

					gradient[index] = { value.r, value.g, value.b }
					LB.Profile:Set("appearance.xpGradient", gradient)
				end,
				blocked = ClassColor,
			}
		end

		Open(Section("colors", L["Colors"], { tab = "bar" }))
		Add(Row(Check(ctx, "classColor", L["XP Uses Class Color"], "appearance.xpUseClassColor")))
		Add(
			Row(
				Color(ctx, "gradientStart", L["Gradient Start"], "appearance.xpGradient", false, Stop(1)),
				Color(ctx, "gradientEnd", L["Gradient End"], "appearance.xpGradient", false, Stop(2))
			)
		)
		Add(
			Row(
				Color(ctx, "quest", L["Completed-Quest Color"], "appearance.questColor", false),
				Color(ctx, "rested", L["Rested Color"], "appearance.restedColor", true)
			)
		)
	elseif id ~= "reputation" then
		Open(Section("colors", L["Colors"], { tab = "bar" }))
		Add(Row(Color(ctx, "color", L["Bar Color"], "appearance.typeColors." .. id, false)))
	end

	Open(Section("size", L["Size"], { tab = "bar", action = Pages:SharedSizeAction(id) }))
	Add(
		Row(
			Pages:BarSize(ctx, id, "width", L["Width"], 100, 1600, 1),
			Pages:BarSize(ctx, id, "height", L["Height"], 4, 64, 1)
		)
	)

	for _, element in ipairs(LB.SettingsText:Elements(ctx, id)) do
		Add(element)
	end

	return elements
end

---A bar's own width or height in Independent layout; the shared size until set.
---@param ctx LBPageContext
---@param id string
---@param field "width" | "height"
---@param label string
---@param minimum number
---@param maximum number
---@param step number
---@return table setting
function Pages:BarSize(ctx, id, field, label, minimum, maximum, step)
	ctx.resets[#ctx.resets + 1] = function()
		local entry = LB.Profile:Get("layout.independent")[id]

		if entry then
			entry[field] = nil
		end
	end

	return {
		id = "bar" .. field,
		control = "slider",
		label = label,
		min = minimum,
		max = maximum,
		step = step,
		format = "integer",
		blocked = OnlyIndependent,
		get = function()
			local entry = LB.Profile:Get("layout.independent")[id]

			return entry and entry[field] or LB.Profile:Get("layout." .. field)
		end,
		set = function(value)
			local independent = LB.Profile:Get("layout.independent")
			local entry = independent[id] or {}

			entry[field] = value
			independent[id] = entry
			LB.Profile:Set("layout.independent", independent)
		end,
	}
end

---The Size section's header action: clears the bar's own width and height.
---@param id string
---@return table setting
function Pages:SharedSizeAction(id)
	return {
		id = "sharedSize",
		control = "action",
		label = L["Use Shared Size"],
		verb = L["Use Shared Size"],
		blocked = OnlyIndependent,
		set = function()
			local independent = LB.Profile:Get("layout.independent")
			local entry = independent[id]

			if entry then
				entry.width, entry.height = nil, nil
				LB.Profile:Set("layout.independent", independent)
			end

			return true
		end,
	}
end

-- Page list ------------------------------------------------------------------------------------------------

---Puts each setting's description, from `LB.SettingsDescriptions`, ahead of any description it has.
---@param elements table[]
---@param key string the descriptions' page key
local function Describe(elements, key)
	local descriptions = LB.SettingsDescriptions
	local byID = descriptions[key] or {}

	local function Apply(setting)
		if not setting then
			return
		end

		local base = byID[setting.id]

		if type(base) == "function" then
			base = base()
		end

		if not base then
			for _, prefix in ipairs(descriptions.prefixes) do
				if setting.id:sub(1, #prefix[1]) == prefix[1] then
					base = prefix[2]
				end
			end
		end

		if base then
			setting.description = setting.description and (base .. " " .. setting.description) or base
		end
	end

	for _, element in ipairs(elements) do
		Apply(element.setting)
		Apply(element.action)
		Apply(element.menu)

		for _, setting in ipairs(element.settings or {}) do
			Apply(setting)
		end
	end
end

---Wraps a page builder: `Build` records what the page's Defaults resets and adds descriptions; `Reset` restores
---the page's defaults.
---@param id string
---@param title string
---@param build fun(ctx: LBPageContext): table[]
---@param descriptions string? the descriptions' page key; the page id when nil
---@param tabs { id: string, title: string }[]? the page's tabs, which its sections name
---@return table page
local function Page(id, title, build, descriptions, tabs)
	local page = { id = id, title = title, preview = LB.SettingsPreviews:For(id), tabs = tabs }

	function page.Build()
		local ctx = Context()
		local elements = build(ctx)

		page.context = ctx
		Describe(elements, descriptions or id)

		return elements
	end

	function page.Reset()
		local ctx = page.context

		if not ctx then
			return
		end

		for _, path in ipairs(ctx.paths) do
			local value = Default(path)

			if value ~= nil then
				LB.Profile:Set(path, type(value) == "table" and LB:CopyTable(value) or value)
			end
		end

		for _, reset in ipairs(ctx.resets) do
			reset()
		end

		LB.Callbacks:Fire("Settings", nil, nil)
	end

	return page
end

---@return table[] categories for `window:SetCategories`
function Pages:Categories()
	local types = {}

	for _, id in ipairs(LB.Model:Order()) do
		if LB.Model:Capable(id) then
			types[#types + 1] = Page("type." .. id, LB.Model:Label(id), function(ctx)
				return TypePage(ctx, id)
			end, "type", {
				{ id = "bar", title = L["Bar"] },
				{ id = "text", title = L["Text"] },
			})
		end
	end

	return {
		{ id = "general", title = GENERAL, pages = { Page("general", GENERAL, General) } },
		{
			id = "bars",
			title = L["Bars"],
			pages = {
				Page("layout", L["Layout"], Bars, nil, {
					{ id = "layout", title = L["Layout"] },
					{ id = "appearance", title = L["Appearance"] },
					{ id = "text", title = L["Text"] },
					{ id = "visibility", title = L["Visibility"] },
				}),
				Page("gain", L["Gain Indicator"], Gain, nil, {
					{ id = "behavior", title = L["Behavior"] },
					{ id = "amount", title = L["Amount"] },
				}),
			},
		},
		{ id = "types", title = L["Progress Types"], pages = types },
		{
			id = "party",
			title = L["Party"],
			pages = {
				Page("markers", L["Markers"], Markers, nil, {
					{ id = "markers", title = L["Markers"] },
					{ id = "fading", title = L["Fading"] },
				}),
				Page("levelups", L["Level-Ups"], LevelUps, nil, {
					{ id = "notices", title = L["Notices"] },
					{ id = "announce", title = L["Announcements"] },
				}),
			},
		},
		{ id = "profiles", title = L["Profiles"], pages = { LB.SettingsProfiles:Page() } },
	}
end
