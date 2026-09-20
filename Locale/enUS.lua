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

L["settings were saved by a newer version of Levelbound and may not load correctly."] =
	"settings were saved by a newer version of Levelbound and may not load correctly."
L["the settings window is not available yet."] = "the settings window is not available yet."
L["a profile needs a name."] = "a profile needs a name."
L["a profile named %q already exists."] = "a profile named %q already exists."
L["the last profile cannot be deleted."] = "the last profile cannot be deleted."
L["your character name could not be read, so the account-wide profile is in use."] =
	"your character name could not be read, so the account-wide profile is in use."

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

L["House favor"] = "House favor"
L["A paragon reward is waiting."] = "A paragon reward is waiting."
L["Ready to upgrade"] = "Ready to upgrade"
L["Standing"] = "Standing"

L["the %s bar hit an error and is off for this session."] = "the %s bar hit an error and is off for this session."

L["saved settings failed to load, so the bars are off for this session."] = "saved settings failed to load, so the bars are off for this session."
