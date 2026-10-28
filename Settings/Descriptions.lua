local LB = select(2, ...)

local L = LB.L

---Tooltip descriptions, by page id and setting id; a setting with none has no tooltip. Progress type pages share
---`type`. A setting's
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
		clickActions = L["Click a bar to open its window, such as Reputation or the Traveler's Log.\nShift-click a bar to post its progress in chat."],
		requestTimePlayed = L["Asks the server for your time played when you log in, for the time tags and the time-to-level estimate."],
		resetSession = L["Starts the session's time and gains from zero."],
	},
	layout = {
		mode = L["How the bars are arranged:\nSegmented: one bar shared by every progress type.\nConnected: a bar for each type, stacked.\nIndependent: a bar for each type, each placed in Edit Mode."],
		fullscreen = L["Stretches the bars along the whole top or bottom edge of the screen."],
		width = L["The bars' width. In Independent layout a progress type's page can give its bar its own."],
		height = L["The bars' height. In Independent layout a progress type's page can give its bar its own."],
		strata = L["The interface layer the bars draw on. Raise it if other frames cover them."],

		-- Appearance tab
		borderWidth = L["The Pixel or Pill border's thickness, in screen pixels. A Pill at 0 has no outline."],
		borderCustom = L["Tints a textured border with Border Color instead of its own colors."],
		borderColor = L["Also colors the XP dividers, unless they have their own."],
		dividers = L["Marks the experience and pet experience bars at even steps through the level."],
		dividerCustom = L["Gives the dividers their own color instead of the border's."],
		spark = L["A bright line at the end of each bar's fill."],
		sparkCustom = L["Gives the spark its own color instead of its bar's."],
		shimmer = L["A shine that sweeps across the fill when a bar gains progress."],
		glow = L["A soft glow and trail at the end of each bar's fill, in the spark's color."],

		-- Text tab
		font = L["The font of every bar's text, unless a text slot sets its own."],
		size = L["The size of every bar's text, unless a text slot sets its own."],
		outline = L["The outline of every bar's text, unless a text slot sets its own."],
		color = L["The color of every bar's text, unless a text slot sets its own."],
		compact = L["Shortens large numbers, such as 12.4K for 12,400."],
		decimals = L["Shows one decimal place on percentages."],

		-- Visibility tab
		focus = L["While you hover one bar, the others dim and hide their text."],
	},
	gain = {
		animate = L["Moves each indicator as it fades. When off, it appears in place and fades."],
		detached = L["Gathers every bar's gains in one stack away from the bars."],
		position = L["Beside segmented bars, every gain stacks next to the row."],
		animation = L["With Slide Outward, a stack's gains sit side by side."],
		color = L["The arrow takes its color from Arrow Tints."],
		x = L["Moves the amount sideways from the arrow."],
		y = L["Moves the amount up or down from the arrow."],
	},
	markers = {
		matchBar = L["The markers fade with the experience bar. Turn off to give them their own opacity."],
		fade = L["Fades the markers until you hover the experience bar."],
		classColor = L["Fills each party bar in its member's class color instead of the experience gradient."],
		compact = L["Stacks the party bars 1 pixel apart and shows only the text inside them."],
		barsMatch = L["The party bars hide and fade with your bars. Turn off to give them their own visibility."],
		barsFade = L["Fades the party bars until you hover one of them."],
	},
	levelups = {
		notices = L["Tells you when a party member reaches a new level."],
		onScreen = L["Shows the notice beside the bars."],
		sound = L["Click the speaker to hear it."],
		detached = L["Shows the notices in their own stack away from the bars."],
		animation = L["With Slide Outward, the notices sit side by side."],
		runSummary = L["When a dungeon or scenario ends, sums up the experience it gave and how long it took."],
		runChannel = ChannelDescription,
	},
	type = {
		gradientFollows = L["Stretches the gradient across the fill, so Gradient End is always at its end."],
		quest = L["The part of the bar your completed quests will fill."],
		rested = L["The part of the bar your rested experience covers."],
		slot = L["Which of the bar's text places to edit. You can also click one in the preview."],
		insertTag = L["Adds a tag where you were typing."],
		slotFont = L["Changing it overrides the text style for this slot."],
		slotSize = L["Changing it overrides the text style for this slot."],
		slotOutline = L["Changing it overrides the text style for this slot."],
		slotColor = L["Changing it overrides the text style for this slot."],
		copyFrom = L["Replaces this bar's text slots with a copy of the chosen bar's."],
	},
	-- Setting ids that carry a type or slot suffix.
	prefixes = {
		{ "slotText.", L["What the slot shows. Tags in brackets, such as [percent], show live values."] },
	},
}

-- The Party Progress page carries the same text editor as the progress type pages.
local EDITOR = {
	"slot", "visibility", "insertTag", "nudgeX", "nudgeY", "slotFont", "slotSize", "slotOutline", "slotColor", "copyFrom",
}

for _, id in ipairs(EDITOR) do
	LB.SettingsDescriptions.markers[id] = LB.SettingsDescriptions.type[id]
end
