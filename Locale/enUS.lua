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
L["that is not a Levelbound profile string, or it was cut short."] =
	"that is not a Levelbound profile string, or it was cut short."
L["that profile string was made by a newer version of Levelbound."] =
	"that profile string was made by a newer version of Levelbound."
L["that profile string has no profile in it."] = "that profile string has no profile in it."

-- Progress types (Data/House.lua, settings window)
L["Pet Experience"] = "Pet Experience"
L["Housing Exp"] = "Housing Exp"
L["Neighborhood Endeavor"] = "Neighborhood Endeavor"
L["Travel Points"] = "Travel Points"
L["Azerite"] = "Azerite"

-- Minimap button and addon compartment (Core/Broker.lua)
L["Left-click: open settings"] = "Left-click: open settings"
L["Right-click: preview all bars"] = "Right-click: preview all bars"

-- Tooltip (UI/Tooltip.lua, Data/Reputation.lua)
L["Remaining"] = "Remaining"
L["Rested"] = "Rested"
L["Quests ready"] = "Quests ready"
L["After turn-in"] = "After turn-in"
L["Quests in log"] = "Quests in log"
L["Past the level-up"] = "Past the level-up"
L["Time this level"] = "Time this level"
L["Session"] = "Session"
L["XP per hour"] = "XP per hour"
L["Time to level"] = "Time to level"
L["Standing"] = "Standing"
L["Ready to upgrade"] = "Ready to upgrade"
L["A paragon reward is waiting."] = "A paragon reward is waiting."

-- Text element contents (Core/Format.lua, looked up as "kind." .. kind)
L["kind.LEVEL"] = "Level"
L["kind.NAME"] = "Name"
L["kind.STANDING"] = "Standing"
L["kind.VALUE"] = "Current / max"
L["kind.PERCENT"] = "Percentage"
L["kind.REMAINING"] = "Remaining"
L["kind.PERCENT_WITH_QUESTS"] = "Percentage after turn-in"
L["kind.RESTED"] = "Rested"
L["kind.QUEST_XP"] = "Completed-quest XP"
L["kind.SESSION_TIME"] = "Session time"
L["kind.LEVEL_TIME"] = "Time this level"
L["kind.TOTAL_TIME"] = "Total time played"
L["kind.XP_PER_HOUR"] = "XP per hour"
L["kind.TIME_TO_LEVEL"] = "Time to level"

-- Settings window: frame (Settings/Settings.lua)
L["Preview All Bars"] = "Preview All Bars"
L["Stop Preview"] = "Stop Preview"

-- Settings window: used on more than one page
L["Size"] = "Size"
L["Outline"] = "Outline"
L["Thick Outline"] = "Thick Outline"
L["Slug"] = "Slug"
L["Slug Outline"] = "Slug Outline"
L["Slug Thick Outline"] = "Slug Thick Outline"

-- Settings window: General
L["Hide Blizzard's Status Tracking Bar"] = "Hide Blizzard's Status Tracking Bar"
L["Show Minimap Button"] = "Show Minimap Button"
L["Request Time Played at Login"] = "Request Time Played at Login"

-- Settings window: Layout
L["Layout"] = "Layout"
L["Placement"] = "Placement"
L["Layout Mode"] = "Layout Mode"
L["Segmented"] = "Segmented"
L["Connected"] = "Connected"
L["Independent"] = "Independent"
L["Fullscreen Edge"] = "Fullscreen Edge"
L["Off"] = "Off"
L["Top"] = "Top"
L["Bottom"] = "Bottom"
L["Width"] = "Width"
L["Height"] = "Height"
L["Stacking"] = "Stacking"
L["Growth Direction"] = "Growth Direction"
L["Up"] = "Up"
L["Down"] = "Down"
L["Gap Between Bars"] = "Gap Between Bars"
L["Advanced"] = "Advanced"
L["Frame Strata"] = "Frame Strata"
L["Low"] = "Low"
L["Medium"] = "Medium"
L["High"] = "High"

-- Settings window: Progress Types
L["Progress Types"] = "Progress Types"
L["This Character Only"] = "This Character Only"

-- Settings window: Appearance
L["Appearance"] = "Appearance"
L["Bars"] = "Bars"
L["Bar Texture"] = "Bar Texture"
L["Experience Bar Uses Class Color"] = "Experience Bar Uses Class Color"
L["Experience Gradient Start"] = "Experience Gradient Start"
L["Experience Gradient End"] = "Experience Gradient End"
L["Completed-Quest Color"] = "Completed-Quest Color"
L["Rested Color"] = "Rested Color"
L["Rested Opacity"] = "Rested Opacity"
L["Background Opacity"] = "Background Opacity"
L["Type Colors"] = "Type Colors"
L["Border"] = "Border"
L["Border Style"] = "Border Style"
L["1 px"] = "1 px"
L["2 px"] = "2 px"
L["Thick"] = "Thick"
L["Rounded"] = "Rounded"
L["Rounded Thick"] = "Rounded Thick"
L["Custom Color"] = "Custom Color"
L["Border Color"] = "Border Color"
L["Border Opacity"] = "Border Opacity"
L["Spark"] = "Spark"
L["Progress Spark"] = "Progress Spark"
L["Spark Color"] = "Spark Color"
L["Reset Colors"] = "Reset Colors"

-- Settings window: Text and Tooltip
L["Text and Tooltip"] = "Text and Tooltip"
L["Numbers"] = "Numbers"
L["Compact Numbers"] = "Compact Numbers"
L["Show Decimals"] = "Show Decimals"
L["Tooltip"] = "Tooltip"
L["Show Tooltip"] = "Show Tooltip"
L["Click Actions"] = "Click Actions"

-- Settings window: Visibility
L["Visibility"] = "Visibility"
L["Fading"] = "Fading"
L["Fade Until Hovered"] = "Fade Until Hovered"
L["Faded Opacity"] = "Faded Opacity"
L["Stay Fully Visible"] = "Stay Fully Visible"
L["In Combat"] = "In Combat"
L["With a Target"] = "With a Target"
L["Focus Mode"] = "Focus Mode"
L["Dim the Other Bars on Hover"] = "Dim the Other Bars on Hover"
L["Dimmed Opacity"] = "Dimmed Opacity"
L["Hiding"] = "Hiding"
L["Hide the Bars in Combat"] = "Hide the Bars in Combat"

-- Settings window: Gain Indicator
L["Gain Indicator"] = "Gain Indicator"
L["Show Gain Indicator"] = "Show Gain Indicator"
L["Hide in Combat"] = "Hide in Combat"
L["Position"] = "Position"
L["Fill Edge"] = "Fill Edge"
L["Right End"] = "Right End"
L["Amount Text"] = "Amount Text"
L["Font"] = "Font"
L["Text Side"] = "Text Side"
L["Left of the Arrow"] = "Left of the Arrow"
L["Right of the Arrow"] = "Right of the Arrow"
L["Horizontal Offset"] = "Horizontal Offset"
L["Vertical Offset"] = "Vertical Offset"
L["Arrow Tint"] = "Arrow Tint"

-- Settings window: Party
L["Party"] = "Party"
L["Party Markers"] = "Party Markers"
L["Show Party Markers"] = "Show Party Markers"
L["Marker Visibility"] = "Marker Visibility"
L["On Hover"] = "On Hover"
L["Marker Style"] = "Marker Style"
L["Dot"] = "Dot"
L["Full-Height Tick"] = "Full-Height Tick"
L["Top-Edge Notch"] = "Top-Edge Notch"
L["Diamond"] = "Diamond"
L["Marker Size"] = "Marker Size"
L["Glow"] = "Glow"
L["Marker Glow"] = "Marker Glow"
L["Glow Opacity"] = "Glow Opacity"

-- Settings window: Profiles, and its popups (Settings/Settings.lua)
L["Profiles"] = "Profiles"
L["Active Profile"] = "Active Profile"
L["Use a Profile for This Character"] = "Use a Profile for This Character"
L["Manage"] = "Manage"
L["New Profile"] = "New Profile"
L["Copy Current Profile"] = "Copy Current Profile"
L["Copy"] = "Copy"
L["Export Profile"] = "Export Profile"
L["Export"] = "Export"
L["Import Profile"] = "Import Profile"
L["Import"] = "Import"
L["Delete Current Profile"] = "Delete Current Profile"
L["Reset This Profile"] = "Reset This Profile"
L["Name the new profile"] = "Name the new profile"
L["Name the copy"] = "Name the copy"
L["Copy this string to share the profile %q."] = "Copy this string to share the profile %q."
L["Paste a Levelbound profile string."] = "Paste a Levelbound profile string."
L["Name the imported profile"] = "Name the imported profile"
L["Delete the profile %q? This cannot be undone."] = "Delete the profile %q? This cannot be undone."
L["Reset every setting in the profile %q?"] = "Reset every setting in the profile %q?"
