local LB = select(2, ...)

local L = LB.L

---Each setting's tooltip description, by page id and setting id; progress type pages share `type`. A setting's
---own description (a scope note, a per-slot note) follows this one.
-- Blizzard's default chat colors, used when the client has not set its own yet.
local CHAT_COLORS = {
	PARTY = { 0.667, 0.667, 1 },
	INSTANCE_CHAT = { 1, 0.498, 0.039 },
	GUILD = { 0.251, 1, 0.251 },
}

---@param chatType string
---@param text string
---@return string text in that chat type's color
local function ChatColored(chatType, text)
	local info = ChatTypeInfo and ChatTypeInfo[chatType]
	local color = info and info.r and { info.r, info.g, info.b } or CHAT_COLORS[chatType]

	return ("|cff%02x%02x%02x%s|r"):format(color[1] * 255, color[2] * 255, color[3] * 255, text)
end

---The Channels tooltip: one line per choice, each chat named in its own chat color.
---@return string
local function ChannelDescription()
	return table.concat({
		L["Where the summary goes:"],
		L["%s: printed in your own chat window, starting with [Levelbound]. Nobody else sees it."]:format(L["Self Only"]),
		L["%s, %s or %s: posted to that chat."]:format(
			ChatColored("PARTY", PARTY),
			ChatColored("INSTANCE_CHAT", INSTANCE_CHAT),
			ChatColored("GUILD", GUILD)
		),
		L["When you are not in that group or guild, it is printed for you alone."],
	}, "\n")
end

LB.SettingsDescriptions = {
	general = {
		minimapButton = L["Shows Levelbound's button on the minimap."],
		tooltip = L["Shows a bar's details when you hover over it."],
		clickActions = L["Click a bar to open its window, such as Reputation or the Traveler's Log.\nShift-click a bar to post its progress in chat."],
		requestTimePlayed = L["Asks the server for your time played when you log in, for the time tags and the time-to-level estimate."],
		resetSession = L["Starts the session's time and gains from zero."],
	},
	layout = {
		mode = L["How the bars are arranged:\nSegmented: one bar shared by every progress type.\nConnected: a bar for each type, stacked.\nIndependent: a bar for each type, each placed in Edit Mode."],
		fullscreen = L["Stretches the bars along the whole top or bottom edge of the screen."],
		width = L["The bars' width. In Independent layout a progress type's page can give its bar its own."],
		height = L["The bars' height. In Independent layout a progress type's page can give its bar its own."],
		growth = L["Which way a stack grows from its first bar."],
		gap = L["The space between stacked bars."],
		strata = L["The interface layer the bars draw on. Raise it if other frames cover them."],

		-- Appearance tab
		texture = L["The texture of every bar's fill."],
		background = L["The color behind each bar's fill."],
		borderStyle = L["The border drawn around the bars."],
		borderWidth = L["The Pixel border's thickness, in screen pixels."],
		borderCustom = L["Tints a textured border with Border Color instead of its own colors."],
		borderColor = L["The border's color. The XP dividers use it too unless they have their own."],
		dividers = L["Marks the experience and pet experience bars at even steps through the level."],
		dividerSpacing = L["How far apart the dividers are, as a share of the level."],
		dividerCustom = L["Gives the dividers their own color instead of the border's."],
		dividerColor = L["The dividers' own color."],
		spark = L["A bright line at the end of each bar's fill."],
		sparkCustom = L["Gives the spark its own color instead of its bar's."],
		sparkColor = L["The spark's own color."],
		shimmer = L["A shine that sweeps across the fill when a bar gains progress."],

		-- Text tab
		font = L["The font of every bar's text, unless a text slot sets its own."],
		size = L["The size of every bar's text, unless a text slot sets its own."],
		outline = L["The outline of every bar's text, unless a text slot sets its own."],
		color = L["The color of every bar's text, unless a text slot sets its own."],
		compact = L["Shortens large numbers, such as 12.4K for 12,400."],
		decimals = L["Shows one decimal place on percentages."],

		-- Visibility tab
		fade = L["Fades the bars until you move the mouse over them."],
		fadedAlpha = L["How visible the bars are while faded."],
		fullInCombat = L["Shows faded bars fully while you are in combat."],
		fullWithTarget = L["Shows faded bars fully while you have a target."],
		focus = L["While you hover one bar, the others dim and hide their text."],
		focusAlpha = L["How visible the other bars are while dimmed."],
		hideInCombat = L["Hides the bars completely while you are in combat."],
	},
	gain = {
		enabled = L["Shows how much a bar gained, with an arrow, each time it moves forward."],
		hideInCombat = L["Hides the gain indicator while you are in combat."],
		detached = L["Gathers every bar's gains in one stack away from the bars."],
		position = L["Where the indicator sits on its bar: at the end of the fill, or at the bar's right end."],
		direction = L["Which way the detached stack grows as new gains arrive."],
		font = L["The font of the gained amount."],
		size = L["The size of the gained amount."],
		outline = L["The outline of the gained amount."],
		color = L["The color of the gained amount. The arrow takes its bar's arrow tint."],
		side = L["Which side of the arrow the amount sits on."],
		x = L["Moves the amount sideways from the arrow."],
		y = L["Moves the amount up or down from the arrow."],
	},
	markers = {
		markers = L["Shows where each party member is on your experience bar."],
		style = L["The markers' shape."],
		size = L["The markers' size."],
		anchor = L["The line of the bar the markers sit on: its middle, its top edge or its bottom edge."],
		y = L["Moves the markers up or down from their anchor."],
		matchBar = L["The markers fade with the experience bar. Turn off to give them their own opacity."],
		alpha = L["How visible the markers are."],
		fade = L["Fades the markers until you hover the experience bar."],
		fadedAlpha = L["How visible the markers are while faded."],
		fullInCombat = L["Shows faded markers fully while you are in combat."],
		fullWithTarget = L["Shows faded markers fully while you have a target."],
	},
	levelups = {
		notices = L["Tells you when a party member reaches a new level."],
		onScreen = L["Shows the notice beside the bars."],
		chat = L["Prints the notice in chat."],
		sound = L["The sound played with the notice, or None. The speaker plays it now."],
		hideInCombat = L["Holds notices until combat ends."],
		detached = L["Shows the notices in their own stack away from the bars."],
		anchor = L["Where the notices appear around the bars."],
		direction = L["Which way the notices stack as new ones arrive."],
		x = L["Moves the notices sideways."],
		y = L["Moves the notices up or down."],
		font = L["The notices' font."],
		size = L["The notices' text size."],
		outline = L["The notices' text outline."],
		levelUpParty = L["Posts your own level-ups to your party."],
		levelUpGuild = L["Posts your own level-ups to your guild."],
		runSummary = L["When a dungeon or scenario ends, sums up the experience it gave and how long it took."],
		runChannel = ChannelDescription,
	},
	type = {
		enabled = L["Shows this progress type's bar."],
		classColor = L["Colors the experience bar in your class color instead of the gradient."],
		gradientStart = L["The experience bar's fill blends from Gradient Start to Gradient End."],
		gradientEnd = L["The experience bar's fill blends from Gradient Start to Gradient End."],
		quest = L["The part of the bar your completed quests will fill."],
		rested = L["The part of the bar your rested experience covers."],
		color = L["The bar's fill color."],
		barwidth = L["This bar's own width in Independent layout."],
		barheight = L["This bar's own height in Independent layout."],
		slot = L["Which of the bar's text places to edit. You can also click one in the preview."],
		visibility = L["When the slot's text shows."],
		insertTag = L["Adds a tag where you were typing."],
		nudgeX = L["Moves the slot's text sideways."],
		nudgeY = L["Moves the slot's text up or down."],
		slotFont = L["The slot's font. Changing it overrides the text style for this slot."],
		slotSize = L["The slot's text size. Changing it overrides the text style for this slot."],
		slotOutline = L["The slot's outline. Changing it overrides the text style for this slot."],
		slotColor = L["The slot's text color. Changing it overrides the text style for this slot."],
		copyFrom = L["Replaces this bar's text slots with a copy of the chosen bar's, after asking."],
	},
	-- Setting ids that carry a type or slot suffix.
	prefixes = {
		{ "slotText.", L["What the slot shows. Tags in brackets, such as [percent], show live values."] },
		{ "tint.", L["The arrow's color for this bar's gains."] },
	},
}
