local LB = select(2, ...)

---@param _ table
---@param key string
---@return string
local function FallBackToKey(_, key)
	return key
end

-- enUS is the base locale and always loads first, so it owns the table. Later locale files
-- overwrite the keys they translate; anything untranslated falls back to the key itself,
-- which is written as the English sentence.
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
