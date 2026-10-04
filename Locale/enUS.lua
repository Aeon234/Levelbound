local LB = select(2, ...)

---@param _ table
---@param key string
---@return string
local function FallBackToKey(_, key)
	return key
end

---@class LBLocale : table<string, string>
local L = setmetatable({}, { __index = FallBackToKey })
LB.L = L

-- Default text on the experience bar (Core/Profile.lua)
L["Leveling in:"] = "Leveling in:"
L["XP/Hr"] = "XP/Hr"
L["Completed:"] = "Completed:"
L["Rested:"] = "Rested:"

-- Chat messages (Core, Data)
L["settings were saved by a newer version of Levelbound and may not load correctly."] =
	"settings were saved by a newer version of Levelbound and may not load correctly."
L["your character name could not be read, so the account-wide profile is in use."] =
	"your character name could not be read, so the account-wide profile is in use."
L["a profile needs a name."] = "a profile needs a name."
L["a profile named %q already exists."] = "a profile named %q already exists."
L["the last profile cannot be deleted."] = "the last profile cannot be deleted."
L["the settings window is not available yet."] = "the settings window is not available yet."
L["saved settings failed to load, so the bars are off for this session."] =
	"saved settings failed to load, so the bars are off for this session."
L["the %s bar hit an error and is off for this session."] = "the %s bar hit an error and is off for this session."
L["the layout cannot be edited in combat."] = "the layout cannot be edited in combat."
L["layout editing is paused for combat."] = "layout editing is paused for combat."
L["there is no progress to share."] = "there is no progress to share."
-- party, instance, raid, guild and say are the /lb share command's words; keep them in English
L["share to party, instance, raid, guild or say."] = "share to party, instance, raid, guild or say."
L["you are not in a group or guild to share with."] = "you are not in a group or guild to share with."

-- Party level-up notices, on screen and in chat (UI/LevelUpNotice.lua, Party/LevelUp.lua)
L["%s reached level %d"] = "%s reached level %d"

-- Progress type names (Data/*, shown in the settings window and edit mode)
L["Pet Experience"] = "Pet Experience"
L["Housing Exp"] = "Housing Exp"
L["Neighborhood Endeavor"] = "Neighborhood Endeavor"
L["Travel Points"] = "Travel Points"

-- Minimap button and addon compartment (Core/Broker.lua)
L["Left-click: open settings"] = "Left-click: open settings"
L["Right-click: open edit mode"] = "Right-click: open edit mode"

-- Tooltip (UI/Tooltip.lua, Data/Reputation.lua)
L["Progress"] = "Progress"
L["Current"] = "Current"
L["Remaining"] = "Remaining"
L["Rested"] = "Rested"
L["Completed"] = "Completed"
L["After Turn-In"] = "After Turn-In"
L["Quests in Log"] = "Quests in Log"
L["Pace"] = "Pace"
L["Time This Level"] = "Time This Level"
L["Session"] = "Session"
L["XP per Hour"] = "XP per Hour"
L["Time to Level"] = "Time to Level"
L["Ready to Upgrade"] = "Ready to Upgrade"
L["A paragon reward is waiting."] = "A paragon reward is waiting."
L["Compared with You"] = "Compared with You"
L["Level with you"] = "Level with you"
L["%.1f levels ahead"] = "%.1f levels ahead"
L["%.1f levels behind"] = "%.1f levels behind"
L["%d%% of a level ahead"] = "%d%% of a level ahead"
L["%d%% of a level behind"] = "%d%% of a level behind"
L["Updated %s ago"] = "Updated %s ago"
L["Click to Open the Housing Dashboard"] = "Click to Open the Housing Dashboard"
L["Click to Open the PvP Window"] = "Click to Open the PvP Window"
L["Click to Open the Traveler's Log"] = "Click to Open the Traveler's Log"
L["Click to Open Journeys."] = "Click to Open Journeys."
L["Click to Open the Reputation Panel"] = "Click to Open the Reputation Panel"
L["Shift-Click to Share"] = "Shift-Click to Share"

-- Honor level display hint in the PvP window (UI/BlizzardWatch.lua)
L["Shift-Click to Show as Experience Bar"] = "Shift-Click to Show as Experience Bar"
L["Shift-Click to Stop Showing as Experience Bar"] = "Shift-Click to Stop Showing as Experience Bar"

-- Sharing to chat (Core/Share.lua, Core/Format.lua); the "[Levelbound]" prefix itself is never translated
L["%s xp to go"] = "%s xp to go"
L["~%s at %s XP/hr"] = "~%s at %s XP/hr"
L["%dh %dm"] = "%dh %dm"
L["%dm"] = "%dm"
L["%ds"] = "%ds"
L["Reached level %d in %s"] = "Reached level %d in %s"
L["Reached level %d"] = "Reached level %d"
L["This run: +%s XP (%s of a level) in %s"] = "This run: +%s XP (%s of a level) in %s"
L["%s XP/hr"] = "%s XP/hr"

-- Bar text tags (Core/Tags.lua, looked up as "tag." .. tag), shown in the settings' Insert Tag list
L["tag.level"] = "Level"
L["tag.name"] = "Name"
L["tag.standing"] = "Standing"
L["tag.cur"] = "Current progress"
L["tag.max"] = "Progress needed"
L["tag.remaining"] = "Progress remaining"
L["tag.percent"] = "Progress, as a number"
L["tag.percentquest"] = "Progress After Turn-In"
L["tag.rested"] = "Rested XP"
L["tag.rested:color"] = "Rested XP, in the rested color"
L["tag.restedpercent"] = "Rested XP, as a share of the level"
L["tag.restedpercent:color"] = "Rested share, in the rested color"
L["tag.quest"] = "Completed-quest XP"
L["tag.quest:color"] = "Completed-quest XP, in its color"
L["tag.questpercent"] = "Completed quests, as a share of the level"
L["tag.questpercent:color"] = "Completed-quest share, in its color"
L["tag.xph"] = "XP per hour"
L["tag.ttl"] = "Time to level"
L["tag.session"] = "Session time"
L["tag.leveltime"] = "Time this level"
L["tag.played"] = "Total time played"

-- Settings window: frame (Settings/Settings.lua); "Edit Mode" is also the edit mode toolbar's title
L["Edit Mode"] = "Edit Mode"
L["Editing the layout. Changes are not saved yet."] = "Editing the layout. Changes are not saved yet."

-- Settings window: used on more than one page
L["Font"] = "Font"
L["Size"] = "Size"
L["Outline"] = "Outline"
L["Thick Outline"] = "Thick Outline"
L["Slug"] = "Slug"
L["Slug Outline"] = "Slug Outline"
L["Slug Thick Outline"] = "Slug Thick Outline"
L["Hide in Combat"] = "Hide in Combat"
L["Top"] = "Top"
L["Bottom"] = "Bottom"
L["Growth Direction"] = "Growth Direction"
L["Up"] = "Up"
L["Down"] = "Down"
L["Horizontal Offset"] = "Horizontal Offset"
L["Vertical Offset"] = "Vertical Offset"
L["Placement"] = "Placement"
L["Width"] = "Width"
L["Height"] = "Height"
L["Text"] = "Text"
L["Reset"] = "Reset"
L["Detach from Bar"] = "Detach from Bar"
L["Place it in Edit Mode."] = "Place it in Edit Mode."
L["Detached: placed in Edit Mode."] = "Detached: placed in Edit Mode."
L["Fade Until Hovered"] = "Fade Until Hovered"
L["Faded Opacity"] = "Faded Opacity"
L["Needs Fade Until Hovered."] = "Needs Fade Until Hovered."
L["Fully Visible in Combat"] = "Fully Visible in Combat"
L["Fully Visible with a Target"] = "Fully Visible with a Target"
L["Only in Independent layout."] = "Only in Independent layout."
L["Level-Up Notices"] = "Level-Up Notices"

-- Settings window: General
L["Access"] = "Access"
L["Show Minimap Button"] = "Show Minimap Button"
L["Bar Interaction"] = "Bar Interaction"
L["Show Tooltip"] = "Show Tooltip"
L["Click to Open or Share"] = "Click to Open or Share"
L["Time Tracking"] = "Time Tracking"
L["Request Time Played at Login"] = "Request Time Played at Login"
L["Reset Session"] = "Reset Session"
L["This character only."] = "This character only."
L["Session reset."] = "Session reset."

-- Settings window: Layout; mode names (Core/Layout.lua), sizes and "Off" are also used by edit mode
L["Layout"] = "Layout"
L["Layout Mode"] = "Layout Mode"
L["Segmented"] = "Segmented"
L["Connected"] = "Connected"
L["Independent"] = "Independent"
L["Fullscreen Edge"] = "Fullscreen Edge"
L["Off"] = "Off"
L["Not in Independent layout."] = "Not in Independent layout."
L["Stacking"] = "Stacking"
L["Gap Between Bars"] = "Gap Between Bars"
L["Only in Connected layout."] = "Only in Connected layout."
L["Frame Strata"] = "Frame Strata"
L["Low"] = "Low"
L["Medium"] = "Medium"
L["High"] = "High"

-- Settings window: Appearance
L["Appearance"] = "Appearance"
L["Bars"] = "Bars"
L["Bar Texture"] = "Bar Texture"
L["Border"] = "Border"
L["Border Style"] = "Border Style"
L["Pixel"] = "Pixel"
L["Border Width"] = "Border Width"
L["Simple"] = "Simple"
L["Simple Thick"] = "Simple Thick"
L["Bronze"] = "Bronze"
L["Metallic"] = "Metallic"
L["Blizzard"] = "Blizzard"
L["Set by the border style."] = "Set by the border style."
L["Custom Color"] = "Custom Color"
L["Pixel borders always use Border Color."] = "Pixel borders always use Border Color."
L["Requires a border style."] = "Requires a border style."
L["Border Color"] = "Border Color"
L["Requires Custom Color to be enabled."] = "Requires Custom Color to be enabled."
L["Show XP Dividers"] = "Show XP Dividers"
L["Divider Spacing"] = "Divider Spacing"
L["Every 10%"] = "Every 10%"
L["Every 5%"] = "Every 5%"
L["Divider Custom Color"] = "Divider Custom Color"
L["Divider Color"] = "Divider Color"
L["Spark and Shimmer"] = "Spark and Shimmer"
L["Progress Spark"] = "Progress Spark"
L["Custom Spark Color"] = "Custom Spark Color"
L["Spark Color"] = "Spark Color"
L["Gain Shimmer"] = "Gain Shimmer"

-- Settings window: Text
L["Text Style"] = "Text Style"
L["Numbers"] = "Numbers"
L["Compact Numbers"] = "Compact Numbers"
L["Show Decimals"] = "Show Decimals"

-- Settings window: Visibility
L["Visibility"] = "Visibility"
L["Fading"] = "Fading"
L["Focus Mode"] = "Focus Mode"
L["Dim Other Bars on Hover"] = "Dim Other Bars on Hover"
L["Dimmed Opacity"] = "Dimmed Opacity"
L["Hiding"] = "Hiding"

-- Short progress type names, for the detached gain indicator (Data/*)
L["Exp"] = "Exp"
L["Pet Exp"] = "Pet Exp"
L["Rep"] = "Rep"
L["House Exp"] = "House Exp"
L["Endeavor"] = "Endeavor"

-- Settings window: Gain Indicator
L["Gain Indicator"] = "Gain Indicator"
L["Show Gain Indicator"] = "Show Gain Indicator"
L["Behavior"] = "Behavior"
L["Amount"] = "Amount"
L["Position"] = "Position"
L["Fill Edge"] = "Fill Edge"
L["Right End"] = "Right End"
L["Only when detached."] = "Only when detached."
L["Amount Text"] = "Amount Text"
L["Text Side"] = "Text Side"
L["Left of the Arrow"] = "Left of the Arrow"
L["Right of the Arrow"] = "Right of the Arrow"
L["Arrow Tints"] = "Arrow Tints"

-- Settings window: Progress Types, one page per type
L["Progress Types"] = "Progress Types"
L["Bar"] = "Bar"
L["Show %s Bar"] = "Show %s Bar"
L["Colors"] = "Colors"
L["XP Uses Class Color"] = "XP Uses Class Color"
L["Uses your class color."] = "Uses your class color."
L["Gradient Start"] = "Gradient Start"
L["Gradient End"] = "Gradient End"
L["Completed-Quest Color"] = "Completed-Quest Color"
L["Rested Color"] = "Rested Color"
L["Bar Color"] = "Bar Color"

-- Settings window: a progress type's text slots (Settings/TextSlots.lua)
L["Slot"] = "Slot"
L["(empty)"] = "(empty)"
L["slot.ABOVE_LEFT"] = "Above Left"
L["slot.ABOVE_CENTER"] = "Above Center"
L["slot.ABOVE_RIGHT"] = "Above Right"
L["slot.INSIDE_LEFT"] = "Inside Left"
L["slot.INSIDE_CENTER"] = "Inside Center"
L["slot.INSIDE_RIGHT"] = "Inside Right"
L["slot.BELOW_LEFT"] = "Below Left"
L["slot.BELOW_CENTER"] = "Below Center"
L["slot.BELOW_RIGHT"] = "Below Right"
L["Insert Tag"] = "Insert Tag"
L["Tags"] = "Tags"
L["Rested and Quests"] = "Rested and Quests"
L["Time"] = "Time"
L["Hidden"] = "Hidden"
L["On Hover"] = "On Hover"
L["Nudge X"] = "Nudge X"
L["Nudge Y"] = "Nudge Y"
L["Copy"] = "Copy"
L["Replace this bar's text with %s's?"] = "Replace this bar's text with %s's?"
L["Copy Settings From"] = "Copy Settings From"
L["The Blizzard border leaves no room for text inside the bar."] =
	"The Blizzard border leaves no room for text inside the bar."
L["Example: %s"] = "Example: %s"
L["No other bar to copy from."] = "No other bar to copy from."

-- Settings window: Party
L["Party"] = "Party"
L["Markers"] = "Markers"
L["Notices"] = "Notices"
L["Party Markers"] = "Party Markers"
L["Show Party Markers"] = "Show Party Markers"
L["Marker Style"] = "Marker Style"
L["Dot"] = "Dot"
L["Full-Height Tick"] = "Full-Height Tick"
L["Notch"] = "Notch"
L["Diamond"] = "Diamond"
L["Pip"] = "Pip"
L["Marker Size"] = "Marker Size"
L["Center"] = "Center"
L["The full-height tick always spans the bar."] = "The full-height tick always spans the bar."
L["Marker Fading"] = "Marker Fading"
L["Match Bar Opacity"] = "Match Bar Opacity"
L["Marker Opacity"] = "Marker Opacity"
L["Uses the bar's opacity."] = "Uses the bar's opacity."
L["Level-Ups"] = "Level-Ups"
L["Party Notices"] = "Party Notices"
L["Show Level-Up Notices"] = "Show Level-Up Notices"
L["On-Screen Notice"] = "On-Screen Notice"
L["Chat Message"] = "Chat Message"
L["Anchor"] = "Anchor"
L["Top Left"] = "Top Left"
L["Top Right"] = "Top Right"
L["Bottom Left"] = "Bottom Left"
L["Bottom Right"] = "Bottom Right"
L["Notice Text"] = "Notice Text"
L["Announcements"] = "Announcements"
L["Party Level-Up Message"] = "Party Level-Up Message"
L["Guild Level-Up Message"] = "Guild Level-Up Message"
L["Channels"] = "Channels"
L["Post-Dungeon Summary"] = "Post-Dungeon Summary"
L["Self Only"] = "Self Only"

-- Settings window: Profiles; the page and its dialogs are the settings library's (Settings/Profiles.lua, Core/Profile.lua)
L["Profiles"] = "Profiles"
L['Levelbound profile "%s", format %d.'] = 'Levelbound profile "%s", format %d.'
L["This is not a Levelbound profile string, or it was cut short."] =
	"This is not a Levelbound profile string, or it was cut short."
L["This profile string was made by a newer version of Levelbound."] =
	"This profile string was made by a newer version of Levelbound."
L["This profile string has no profile in it."] = "This profile string has no profile in it."

-- Settings window: page descriptions, under each page's title (Settings/Pages.lua, Settings/Profiles.lua)
L["The minimap button, bar tooltips and clicks, and time tracking."] =
	"The minimap button, bar tooltips and clicks, and time tracking."
L["How every bar is arranged, sized, drawn and shown."] = "How every bar is arranged, sized, drawn and shown."
L["The arrow and amount shown each time a bar gains progress."] =
	"The arrow and amount shown each time a bar gains progress."
L["This bar's colors, its own size and its text."] = "This bar's colors, its own size and its text."
L["Where party members running Levelbound are on your experience bar."] =
	"Where party members running Levelbound are on your experience bar."
L["Party level-up notices, and messages about your own level-ups and runs."] =
	"Party level-up notices, and messages about your own level-ups and runs."
L["Per-character or shared settings, with copy, export and import."] =
	"Per-character or shared settings, with copy, export and import."

-- Settings window: setting descriptions, shown in their tooltips (Settings/Descriptions.lua)
L["Shows Levelbound's button on the minimap."] = "Shows Levelbound's button on the minimap."
L["Shows a bar's details when you hover over it."] = "Shows a bar's details when you hover over it."
L["Asks the server for your time played when you log in, for the time tags and the time-to-level estimate."] =
	"Asks the server for your time played when you log in, for the time tags and the time-to-level estimate."
L["Starts the session's time and gains from zero."] = "Starts the session's time and gains from zero."
L["Stretches the bars along the whole top or bottom edge of the screen."] =
	"Stretches the bars along the whole top or bottom edge of the screen."
L["The bars' width. In Independent layout a progress type's page can give its bar its own."] =
	"The bars' width. In Independent layout a progress type's page can give its bar its own."
L["The bars' height. In Independent layout a progress type's page can give its bar its own."] =
	"The bars' height. In Independent layout a progress type's page can give its bar its own."
L["Which way a stack grows from its first bar."] = "Which way a stack grows from its first bar."
L["The space between stacked bars."] = "The space between stacked bars."
L["The interface layer the bars draw on. Raise it if other frames cover them."] =
	"The interface layer the bars draw on. Raise it if other frames cover them."
L["The texture of every bar's fill."] = "The texture of every bar's fill."
L["The color behind each bar's fill."] = "The color behind each bar's fill."
L["The border drawn around the bars."] = "The border drawn around the bars."
L["The Pixel border's thickness, in screen pixels."] = "The Pixel border's thickness, in screen pixels."
L["Tints a textured border with Border Color instead of its own colors."] =
	"Tints a textured border with Border Color instead of its own colors."
L["The border's color. The XP dividers use it too unless they have their own."] =
	"The border's color. The XP dividers use it too unless they have their own."
L["Marks the experience and pet experience bars at even steps through the level."] =
	"Marks the experience and pet experience bars at even steps through the level."
L["How far apart the dividers are, as a share of the level."] =
	"How far apart the dividers are, as a share of the level."
L["Gives the dividers their own color instead of the border's."] =
	"Gives the dividers their own color instead of the border's."
L["The dividers' own color."] = "The dividers' own color."
L["A bright line at the end of each bar's fill."] = "A bright line at the end of each bar's fill."
L["Gives the spark its own color instead of its bar's."] = "Gives the spark its own color instead of its bar's."
L["The spark's own color."] = "The spark's own color."
L["A shine that sweeps across the fill when a bar gains progress."] =
	"A shine that sweeps across the fill when a bar gains progress."
L["The font of every bar's text, unless a text slot sets its own."] =
	"The font of every bar's text, unless a text slot sets its own."
L["The size of every bar's text, unless a text slot sets its own."] =
	"The size of every bar's text, unless a text slot sets its own."
L["The outline of every bar's text, unless a text slot sets its own."] =
	"The outline of every bar's text, unless a text slot sets its own."
L["The color of every bar's text, unless a text slot sets its own."] =
	"The color of every bar's text, unless a text slot sets its own."
L["Shortens large numbers, such as 12.4K for 12,400."] = "Shortens large numbers, such as 12.4K for 12,400."
L["Shows one decimal place on percentages."] = "Shows one decimal place on percentages."
L["Fades the bars until you move the mouse over them."] = "Fades the bars until you move the mouse over them."
L["How visible the bars are while faded."] = "How visible the bars are while faded."
L["Shows faded bars fully while you are in combat."] = "Shows faded bars fully while you are in combat."
L["Shows faded bars fully while you have a target."] = "Shows faded bars fully while you have a target."
L["While you hover one bar, the others dim and hide their text."] =
	"While you hover one bar, the others dim and hide their text."
L["How visible the other bars are while dimmed."] = "How visible the other bars are while dimmed."
L["Hides the bars completely while you are in combat."] = "Hides the bars completely while you are in combat."
L["Shows how much a bar gained, with an arrow, each time it moves forward."] =
	"Shows how much a bar gained, with an arrow, each time it moves forward."
L["Hides the gain indicator while you are in combat."] = "Hides the gain indicator while you are in combat."
L["Gathers every bar's gains in one stack away from the bars."] =
	"Gathers every bar's gains in one stack away from the bars."
L["Where the indicator sits on its bar: at the end of the fill, or at the bar's right end."] =
	"Where the indicator sits on its bar: at the end of the fill, or at the bar's right end."
L["Which way the detached stack grows as new gains arrive."] = "Which way the detached stack grows as new gains arrive."
L["The font of the gained amount."] = "The font of the gained amount."
L["The size of the gained amount."] = "The size of the gained amount."
L["The outline of the gained amount."] = "The outline of the gained amount."
L["The color of the gained amount. The arrow takes its bar's arrow tint."] =
	"The color of the gained amount. The arrow takes its bar's arrow tint."
L["Which side of the arrow the amount sits on."] = "Which side of the arrow the amount sits on."
L["Moves the amount sideways from the arrow."] = "Moves the amount sideways from the arrow."
L["Moves the amount up or down from the arrow."] = "Moves the amount up or down from the arrow."
L["Shows where each party member is on your experience bar."] =
	"Shows where each party member is on your experience bar."
L["The markers' shape."] = "The markers' shape."
L["The markers' size."] = "The markers' size."
L["The line of the bar the markers sit on: its middle, its top edge or its bottom edge."] =
	"The line of the bar the markers sit on: its middle, its top edge or its bottom edge."
L["Moves the markers up or down from their anchor."] = "Moves the markers up or down from their anchor."
L["The markers fade with the experience bar. Turn off to give them their own opacity."] =
	"The markers fade with the experience bar. Turn off to give them their own opacity."
L["How visible the markers are."] = "How visible the markers are."
L["Fades the markers until you hover the experience bar."] = "Fades the markers until you hover the experience bar."
L["How visible the markers are while faded."] = "How visible the markers are while faded."
L["Shows faded markers fully while you are in combat."] = "Shows faded markers fully while you are in combat."
L["Shows faded markers fully while you have a target."] = "Shows faded markers fully while you have a target."
L["Tells you when a party member reaches a new level."] = "Tells you when a party member reaches a new level."
L["Shows the notice beside the bars."] = "Shows the notice beside the bars."
L["Prints the notice in chat."] = "Prints the notice in chat."
L["Holds notices until combat ends."] = "Holds notices until combat ends."
L["Shows the notices in their own stack away from the bars."] =
	"Shows the notices in their own stack away from the bars."
L["Where the notices appear around the bars."] = "Where the notices appear around the bars."
L["Which way the notices stack as new ones arrive."] = "Which way the notices stack as new ones arrive."
L["Moves the notices sideways."] = "Moves the notices sideways."
L["Moves the notices up or down."] = "Moves the notices up or down."
L["The notices' font."] = "The notices' font."
L["The notices' text size."] = "The notices' text size."
L["The notices' text outline."] = "The notices' text outline."
L["Posts your own level-ups to your party."] = "Posts your own level-ups to your party."
L["Posts your own level-ups to your guild."] = "Posts your own level-ups to your guild."
L["Shows this progress type's bar."] = "Shows this progress type's bar."
L["Colors the experience bar in your class color instead of the gradient."] =
	"Colors the experience bar in your class color instead of the gradient."
L["The experience bar's fill blends from Gradient Start to Gradient End."] =
	"The experience bar's fill blends from Gradient Start to Gradient End."
L["The part of the bar your completed quests will fill."] = "The part of the bar your completed quests will fill."
L["The part of the bar your rested experience covers."] = "The part of the bar your rested experience covers."
L["The bar's fill color."] = "The bar's fill color."
L["This bar's own width in Independent layout."] = "This bar's own width in Independent layout."
L["This bar's own height in Independent layout."] = "This bar's own height in Independent layout."
L["When the slot's text shows."] = "When the slot's text shows."
L["Adds a tag where you were typing."] = "Adds a tag where you were typing."
L["Moves the slot's text sideways."] = "Moves the slot's text sideways."
L["Moves the slot's text up or down."] = "Moves the slot's text up or down."
L["The slot's font. Changing it overrides the text style for this slot."] =
	"The slot's font. Changing it overrides the text style for this slot."
L["The slot's text size. Changing it overrides the text style for this slot."] =
	"The slot's text size. Changing it overrides the text style for this slot."
L["The slot's outline. Changing it overrides the text style for this slot."] =
	"The slot's outline. Changing it overrides the text style for this slot."
L["The slot's text color. Changing it overrides the text style for this slot."] =
	"The slot's text color. Changing it overrides the text style for this slot."
L["What the slot shows. Tags in brackets, such as [percent], show live values."] =
	"What the slot shows. Tags in brackets, such as [percent], show live values."
L["The arrow's color for this bar's gains."] = "The arrow's color for this bar's gains."
L["The sound played with the notice, or None. The speaker plays it now."] = "The sound played with the notice, or None. The speaker plays it now."
L["Which of the bar's text places to edit. You can also click one in the preview."] =
	"Which of the bar's text places to edit. You can also click one in the preview."
L["When a dungeon or scenario ends, sums up the experience it gave and how long it took."] =
	"When a dungeon or scenario ends, sums up the experience it gave and how long it took."
L["Replaces this bar's text slots with a copy of the chosen bar's, after asking."] =
	"Replaces this bar's text slots with a copy of the chosen bar's, after asking."
L["%s: printed in your own chat window, starting with [Levelbound]. Nobody else sees it."] =
	"%s: printed in your own chat window, starting with [Levelbound]. Nobody else sees it."
L["Click a bar to open its window, such as Reputation or the Traveler's Log.\nShift-click a bar to post its progress in chat."] =
	"Click a bar to open its window, such as Reputation or the Traveler's Log.\nShift-click a bar to post its progress in chat."
L["Where the summary goes:"] = "Where the summary goes:"
L["When you are not in that group or guild, it is printed for you alone."] = "When you are not in that group or guild, it is printed for you alone."
L["%s, %s or %s: posted to that chat."] = "%s, %s or %s: posted to that chat."
L["How the bars are arranged:\nSegmented: one bar shared by every progress type.\nConnected: a bar for each type, stacked.\nIndependent: a bar for each type, each placed in Edit Mode."] =
	"How the bars are arranged:\nSegmented: one bar shared by every progress type.\nConnected: a bar for each type, stacked.\nIndependent: a bar for each type, each placed in Edit Mode."

-- Edit mode: toolbar, mover panel, popups and the bars' mover labels (Settings/EditMode.lua, Settings/EditPanel.lua, UI/BarGroup.lua)
L["Exit"] = "Exit"
L["Snap"] = "Snap"
L["Enabled"] = "Enabled"
L["Disabled"] = "Disabled"
L["Grid Lines"] = "Grid Lines"
L["Dimmed"] = "Dimmed"
L["Bright"] = "Bright"
L["Hover Top Bar"] = "Hover Top Bar"
L["Resume Editing"] = "Resume Editing"
L["Paused"] = "Paused"
L["Paused for combat"] = "Paused for combat"
L["Progress Bars"] = "Progress Bars"
L["Bar Stack"] = "Bar Stack"
L["X"] = "X"
L["Y"] = "Y"
L["Pinned to Top Edge"] = "Pinned to Top Edge"
L["Pinned to Bottom Edge"] = "Pinned to Bottom Edge"
L["Save your layout changes?"] = "Save your layout changes?"
L["Discard"] = "Discard"
