local LB = select(2, ...)

local L = LB.L

local DEFAULT_PROFILE = "Default"
local FONT = LB.DEFAULT_FONT
local SCHEMA_VERSION = 1

---@alias LBColor number[]
---@alias LBAnchor
---| "INSIDE_LEFT"
---| "INSIDE_CENTER"
---| "INSIDE_RIGHT"
---| "ABOVE_LEFT"
---| "ABOVE_CENTER"
---| "ABOVE_RIGHT"
---| "BELOW_LEFT"
---| "BELOW_CENTER"
---| "BELOW_RIGHT"
---@alias LBTextVisibility "HIDDEN" | "HOVER" | "ALWAYS"

---@class LBTextStyle
---@field font string LibSharedMedia font name
---@field size number
---@field color LBColor
---@field outline "NONE" | "OUTLINE" | "THICKOUTLINE" | "SLUG" | "SLUG_OUTLINE" | "SLUG_THICKOUTLINE"

---@class LBGainTextStyle : LBTextStyle
---@field side "LEFT" | "RIGHT"
---@field x number
---@field y number

---@class LBTextElement : LBTextStyle
---@field kind string
---@field visibility LBTextVisibility
---@field anchor LBAnchor
---@field x number
---@field y number

---@class LBFramePosition
---@field point FramePoint
---@field x number
---@field y number

---@class LBProfileData
---@field general { hideBlizzardBar: boolean }
---@field layout LBLayoutSettings
---@field types table<string, boolean>
---@field appearance LBAppearanceSettings
---@field text LBTextSettings
---@field tooltip { enabled: boolean, clickActions: boolean }
---@field visibility LBVisibilitySettings
---@field gain LBGainSettings
---@field party LBPartySettings
---@field time table

---@class LBLayoutSettings
---@field mode "SEGMENTED" | "CONNECTED" | "INDEPENDENT"
---@field fullscreen "OFF" | "TOP" | "BOTTOM"
---@field width number
---@field height number
---@field position LBFramePosition
---@field growth "UP" | "DOWN"
---@field gap number
---@field strata FrameStrata
---@field independent table<string, { width: number, height: number, position: LBFramePosition }>

---@class LBAppearanceSettings
---@field texture string LibSharedMedia statusbar name
---@field xpGradient LBColor[] two stops
---@field xpUseClassColor boolean
---@field xpStoredGradient LBColor[]? the gradient in use before the class-colour toggle went on
---@field questColor LBColor
---@field restedColor LBColor
---@field background LBColor
---@field typeColors table<string, LBColor>
---@field standingColors table<string, LBColor> overrides on Blizzard's FACTION_BAR_COLORS
---@field border { style: string, color: LBColor, customColor: boolean }
---@field spark { enabled: boolean, color: LBColor }

---@class LBTextSettings
---@field compactNumbers boolean
---@field decimals boolean
---@field elements table<string, LBTextElement[]>

---@class LBVisibilitySettings
---@field hideInCombat boolean
---@field fadeUntilHovered boolean
---@field fadedAlpha number
---@field fullInCombat boolean
---@field fullWithTarget boolean
---@field focus { enabled: boolean, alpha: number }

---@class LBGainSettings
---@field enabled boolean
---@field hideInCombat boolean
---@field position "FILL_EDGE" | "RIGHT_END"
---@field colors table<string, LBColor>
---@field text LBGainTextStyle

---@class LBPartySettings
---@field markers boolean
---@field visibility "ALWAYS" | "HOVER"
---@field style "DOT" | "TICK" | "NOTCH" | "DIAMOND"
---@field size number
---@field glow boolean
---@field glowOpacity number

---@class LBDatabase
---@field version integer
---@field profiles table<string, LBProfileData>
---@field profileKeys table<string, string>
---@field global { minimapButton: { hide: boolean }, requestTimePlayed: boolean }

---@class LBCharacterDatabase
---@field optIn { endeavor: boolean, travelers: boolean }
---@field useCharacterProfile boolean

local GAIN_GREEN = { 0.226, 1.0, 0.006 }

---@type LBProfileData
local defaults = {
	general = {
		hideBlizzardBar = true,
	},
	layout = {
		mode = "SEGMENTED",
		fullscreen = "OFF",
		width = 560,
		height = 12,
		position = { point = "BOTTOM", x = 0, y = 200 },
		growth = "UP",
		gap = 2,
		strata = "LOW",
		independent = {},
	},
	types = {
		xp = true,
		petxp = true,
		reputation = true,
		house = true,
		honor = true,
		azerite = true,
	},
	appearance = {
		texture = "Solid",
		xpGradient = { { 0.335, 0.388, 1.0 }, { 0.773, 0.380, 1.0 } },
		xpUseClassColor = false,
		questColor = { 1.0, 0.589, 0.0 },
		restedColor = { 0.309, 0.562, 1.0, 0.5 },
		background = { 0, 0, 0, 0.5 },
		typeColors = {
			house = { 0.851, 0.710, 0.435 },
			travelers = { 0.035, 0.647, 0.733 },
			endeavor = { 0.294, 0.365, 0.106 },
		},
		standingColors = {},
		border = { style = "NONE", color = { 1, 1, 1, 1 }, customColor = false },
		spark = { enabled = false, color = { 1, 1, 1, 1 } },
	},
	text = {
		compactNumbers = true,
		decimals = true,
		elements = {},
	},
	tooltip = {
		enabled = true,
		clickActions = true,
	},
	visibility = {
		hideInCombat = false,
		fadeUntilHovered = false,
		fadedAlpha = 0.25,
		fullInCombat = false,
		fullWithTarget = false,
		focus = { enabled = false, alpha = 0.40 },
	},
	gain = {
		enabled = true,
		hideInCombat = false,
		position = "FILL_EDGE",
		colors = {
			xp = GAIN_GREEN,
			petxp = GAIN_GREEN,
			reputation = GAIN_GREEN,
			house = { 228 / 255, 138 / 255, 15 / 255 },
			endeavor = { 253 / 255, 199 / 255, 9 / 255 },
			travelers = { 1 / 255, 178 / 255, 193 / 255 },
			honor = { 184 / 255, 24 / 255, 0 },
			azerite = { 247 / 255, 237 / 255, 145 / 255 },
		},
		text = { font = FONT, size = 12, color = { 1, 1, 1, 1 }, outline = "OUTLINE", side = "RIGHT", x = 0, y = 0 },
	},
	party = {
		markers = true,
		visibility = "ALWAYS",
		style = "DOT",
		size = 8,
		glow = false,
		glowOpacity = 0.15,
	},
	time = {},
}

---@type table<string, LBTextElement[]>
local elementDefaults = {
	xp = {
		{
			kind = "LEVEL",
			visibility = "HOVER",
			anchor = "INSIDE_LEFT",
			x = 0,
			y = 0,
			font = FONT,
			size = 12,
			color = { 1, 1, 1, 1 },
			outline = "OUTLINE",
		},
		{
			kind = "PERCENT",
			visibility = "HOVER",
			anchor = "INSIDE_RIGHT",
			x = 0,
			y = 0,
			font = FONT,
			size = 12,
			color = { 1, 1, 1, 1 },
			outline = "OUTLINE",
		},
	},
	other = {
		{
			kind = "NAME",
			visibility = "HOVER",
			anchor = "INSIDE_LEFT",
			x = 0,
			y = 0,
			font = FONT,
			size = 12,
			color = { 1, 1, 1, 1 },
			outline = "OUTLINE",
		},
		{
			kind = "PERCENT",
			visibility = "HOVER",
			anchor = "INSIDE_RIGHT",
			x = 0,
			y = 0,
			font = FONT,
			size = 12,
			color = { 1, 1, 1, 1 },
			outline = "OUTLINE",
		},
	},
}

---@type LBDatabase
local globalDefaults = {
	version = SCHEMA_VERSION,
	profiles = {},
	profileKeys = {},
	global = {
		minimapButton = { hide = false },
		requestTimePlayed = true,
	},
}

---@type LBCharacterDatabase
local characterDefaults = {
	optIn = { endeavor = false, travelers = false },
	useCharacterProfile = false,
}

---@class LBProfile
---@field active LBProfileData
---@field activeName string
---@field db LBDatabase
---@field char LBCharacterDatabase
local Profile = {}
LB.Profile = Profile

---@param profile LBProfileData
local function SeedLists(profile)
	for key, elements in pairs(elementDefaults) do
		if profile.text.elements[key] == nil then
			profile.text.elements[key] = LB:CopyTable(elements)
		end
	end
end

---@type string?
local characterKey = nil

---@return string
local function RealmKey()
	local realm = GetNormalizedRealmName() or GetRealmName()

	if realm and realm ~= "" then
		return (realm:gsub("[%s'%-]", ""))
	end

	local mode = C_GameRules and C_GameRules.GetActiveGameMode and C_GameRules.GetActiveGameMode()

	if mode then
		return "Mode" .. tostring(mode)
	end

	return UNKNOWN
end

---@return string
function Profile:CharacterKey()
	if characterKey then
		return characterKey
	end

	local name = LB:Readable(UnitName("player"), nil)

	if not name then
		LB:Warn(L["your character name could not be read, so the account-wide profile is in use."])

		return DEFAULT_PROFILE
	end

	characterKey = name .. "-" .. RealmKey()

	return characterKey
end

---@param name string
---@return LBProfileData
function Profile:Ensure(name)
	local profile = self.db.profiles[name]

	if not profile then
		profile = LB:CopyTable(defaults)
		self.db.profiles[name] = profile
	else
		LB:MergeDefaults(profile, defaults)
	end

	SeedLists(profile)

	return profile
end

---@return string name of the profile this character should use
function Profile:ResolveName()
	local key = self:CharacterKey()
	local assigned = self.db.profileKeys[key]

	if assigned then
		return assigned
	end

	if self.char.useCharacterProfile then
		return key
	end

	return DEFAULT_PROFILE
end

---@type table<integer, fun(db: LBDatabase)>
local migrations = {}

---@param db LBDatabase
---@return integer from
---@return integer to
function Profile:Migrate(db)
	local from = db.version or SCHEMA_VERSION

	if from > SCHEMA_VERSION then
		LB:Warn(L["settings were saved by a newer version of Levelbound and may not load correctly."])

		return from, from
	end

	for version = from + 1, SCHEMA_VERSION do
		local step = migrations[version]

		if step then
			step(db)
		end

		db.version = version
	end

	db.version = SCHEMA_VERSION

	return from, SCHEMA_VERSION
end

function Profile:Initialize()
	local db = LevelboundDB or {}
	local char = LevelboundDBChar or {}
	---@cast db LBDatabase
	---@cast char LBCharacterDatabase

	LevelboundDB = db
	LevelboundDBChar = char

	self:Migrate(db)

	LB:MergeDefaults(db, globalDefaults)
	LB:MergeDefaults(char, characterDefaults)

	self.db = db
	self.char = char

	self.activeName = self:ResolveName()
	self.active = self:Ensure(self.activeName)
end

---@param path string
---@return any
function Profile:Get(path)
	local node = self.active

	for key in path:gmatch("[^.]+") do
		if type(node) ~= "table" then
			return nil
		end

		node = node[key]
	end

	return node
end

---@param path string
---@param value any
---@return boolean written
function Profile:Set(path, value)
	local node = self.active
	local last = nil

	for key in path:gmatch("[^.]+") do
		if last then
			if type(node[last]) ~= "table" then
				return false
			end

			node = node[last]
		end

		last = key
	end

	if not last or node[last] == value then
		return false
	end

	node[last] = value

	LB.Callbacks:Fire("Settings", path, value)

	return true
end

---@param section string?
---@return boolean reset
function Profile:Reset(section)
	if not section then
		self.db.profiles[self.activeName] = nil
		self.active = self:Ensure(self.activeName)

		LB.Callbacks:Fire("Settings", nil, nil)

		return true
	end

	if defaults[section] == nil then
		return false
	end

	self.active[section] = LB:CopyTable(defaults[section])

	if section == "text" then
		SeedLists(self.active)
	end

	LB.Callbacks:Fire("Settings", section, nil)

	return true
end

---@return string[] names sorted, so a picker is stable across sessions
function Profile:List()
	local names = {}

	for name in pairs(self.db.profiles) do
		names[#names + 1] = name
	end

	table.sort(names)

	return names
end

---@param name string
---@return boolean
function Profile:Exists(name)
	return self.db.profiles[name] ~= nil
end

---@param name string
---@return boolean valid
local function ValidateNewName(name)
	if not name or name:trim() == "" then
		LB:Warn(L["a profile needs a name."])

		return false
	end

	if LB.Profile:Exists(name) then
		LB:Warn(L["a profile named %q already exists."], name)

		return false
	end

	return true
end

---@param name string
function Profile:Activate(name)
	self.db.profileKeys[self:CharacterKey()] = name
	self.activeName = name
	self.active = self:Ensure(name)

	LB.Callbacks:Fire("Settings", nil, nil)
end

---@param name string
---@return boolean created
function Profile:New(name)
	if not ValidateNewName(name) then
		return false
	end

	self:Activate(name)

	return true
end

---@param source string
---@param name string
---@return boolean created
function Profile:Copy(source, name)
	if not self:Exists(source) or not ValidateNewName(name) then
		return false
	end

	self.db.profiles[name] = LB:CopyTable(self.db.profiles[source])
	self:Activate(name)

	return true
end

---@param from string
---@param to string
---@return boolean renamed
function Profile:Rename(from, to)
	if not self:Exists(from) or not ValidateNewName(to) then
		return false
	end

	self.db.profiles[to] = self.db.profiles[from]
	self.db.profiles[from] = nil

	for key, assigned in pairs(self.db.profileKeys) do
		if assigned == from then
			self.db.profileKeys[key] = to
		end
	end

	if self.activeName == from then
		self.activeName = to
	end

	return true
end

---@param name string
---@return boolean deleted
function Profile:Delete(name)
	if not self:Exists(name) then
		return false
	end

	if #self:List() <= 1 then
		LB:Warn(L["the last profile cannot be deleted."])

		return false
	end

	self.db.profiles[name] = nil

	for key, assigned in pairs(self.db.profileKeys) do
		if assigned == name then
			self.db.profileKeys[key] = nil
		end
	end

	if self.activeName == name then
		self:Activate(self:List()[1])
	end

	return true
end

---@param enabled boolean
function Profile:SetUseCharacterProfile(enabled)
	self.char.useCharacterProfile = enabled
	self.db.profileKeys[self:CharacterKey()] = nil

	self:Activate(self:ResolveName())
end

---@param key "endeavor" | "travelers"
---@return boolean
function Profile:OptedIn(key)
	return self.char.optIn[key] == true
end

---@param key "endeavor" | "travelers"
---@param enabled boolean
function Profile:SetOptIn(key, enabled)
	if self.char.optIn[key] == enabled then
		return
	end

	self.char.optIn[key] = enabled

	LB.Callbacks:Fire("Settings", "optIn." .. key, enabled)
end

---@return { minimapButton: { hide: boolean }, requestTimePlayed: boolean }
function Profile:Global()
	return self.db.global
end

---@return LBProfileData defaults a fresh copy, for comparison and reset controls
function Profile:Defaults()
	local copy = LB:CopyTable(defaults)

	SeedLists(copy)

	return copy
end
