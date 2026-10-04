local LB = select(2, ...)

local L = LB.L

local DEFAULT_PROFILE = "Default"
local FONT = LB.DEFAULT_FONT
local SCHEMA_VERSION = 2
local EXPORT_FORMAT = 1
local EXPORT_PREFIX = "LB!" .. EXPORT_FORMAT .. "!"

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

---@class LBFontStyle
---@field font string LibSharedMedia font name
---@field size number
---@field outline "NONE" | "OUTLINE" | "THICKOUTLINE" | "SLUG" | "SLUG_OUTLINE" | "SLUG_THICKOUTLINE"

---@class LBTextStyle : LBFontStyle
---@field color LBColor

---@class LBLevelUpTextStyle : LBFontStyle

---@class LBGainTextStyle : LBTextStyle
---@field side "LEFT" | "RIGHT"
---@field x number
---@field y number

---@class LBTextSlot
---@field text string
---@field visibility LBTextVisibility
---@field x number
---@field y number
---@field style table overridden settings

---@class LBFramePosition
---@field point FramePoint
---@field x number
---@field y number

---@class LBProfileData
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
---@field positions table<string, LBFramePosition> keyed by layout mode, so each mode keeps its own place
---@field growth "UP" | "DOWN"
---@field gap number
---@field strata FrameStrata
---@field independent table<string, { width: number, height: number, position: LBFramePosition }>

---@class LBAppearanceSettings
---@field texture string LibSharedMedia statusbar name
---@field xpGradient LBColor[] two stops
---@field xpUseClassColor boolean
---@field xpStoredGradient LBColor[]? the gradient in use before the class-color toggle went on
---@field questColor LBColor
---@field restedColor LBColor
---@field background LBColor
---@field typeColors table<string, LBColor>
---@field standingColors table<string, LBColor> overrides on Blizzard's FACTION_BAR_COLORS
---@field border { style: string, color: LBColor, customColor: boolean }
---@field spark { enabled: boolean, customColor: boolean, color: LBColor } the bar's own color unless customColor
---@field dividers { enabled: boolean, spacing: 5|10, customColor: boolean, color: LBColor } marks on the XP and pet XP
---bars every `spacing` percent of a level
---@field shimmer boolean sweep a highlight across the fill on each gain

---@class LBTextSettings
---@field compactNumbers boolean
---@field decimals boolean
---@field style LBTextStyle
---@field slots table<string, table<LBAnchor, LBTextSlot>>

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
---@field detached boolean
---@field direction "UP" | "DOWN"
---@field screen LBFramePosition? the detached stack's place; nil sits it right of the screen's center
---@field colors table<string, LBColor>
---@field text LBGainTextStyle

---@class LBLevelUpSettings
---@field enabled boolean
---@field onScreen boolean
---@field chat boolean
---@field sound string a LibSharedMedia sound name, or "None"
---@field hideInCombat boolean
---@field anchor "TOPLEFT" | "TOP" | "TOPRIGHT" | "BOTTOMLEFT" | "BOTTOM" | "BOTTOMRIGHT" the point on the bar
---@field direction "UP" | "DOWN" the way the stack grows
---@field x number
---@field y number
---@field detached boolean
---@field screen LBFramePosition? the detached stack's place; nil sits it left of the screen's center
---@field text LBLevelUpTextStyle

---@class LBMarkerOpacitySettings
---@field matchBar boolean
---@field alpha number
---@field fadeUntilHovered boolean
---@field fadedAlpha number
---@field fullInCombat boolean
---@field fullWithTarget boolean

---@class LBPartySettings
---@field markers boolean
---@field opacity LBMarkerOpacitySettings
---@field style "DOT" | "TICK" | "NOTCH" | "DIAMOND"
---@field size number
---@field anchor "CENTER" | "TOP" | "BOTTOM" the bar line the markers sit on; the full-height tick ignores it
---@field y number the markers' vertical offset from their anchor, up positive; the full-height tick ignores it
---@field levelUp LBLevelUpSettings
---@field announce { levelUpParty: boolean, levelUpGuild: boolean, runSummary: boolean, runChannel: "SELF"|"PARTY"|"INSTANCE"|"GUILD" } messages sent for the player

---@class LBDatabase
---@field version integer
---@field profiles table<string, LBProfileData>
---@field profileKeys table<string, string>
---@field global LBGlobalSettings

---@class LBGlobalSettings
---@field minimapButton { hide: boolean }
---@field requestTimePlayed boolean
---@field editMode { snap: boolean, grid: "DIMMED" | "BRIGHT" | "OFF", hoverBar: boolean }

---@class LBCharacterDatabase
---@field useCharacterProfile boolean
---@field key string? this character's key in profileKeys, worked out once and kept

local GAIN_GREEN = { 0.226, 1.0, 0.006 }

---@type LBProfileData
local defaults = {
	layout = {
		mode = "SEGMENTED",
		fullscreen = "OFF",
		width = 560,
		height = 24,
		positions = {
			SEGMENTED = { point = "TOP", x = 0, y = -40 },
			CONNECTED = { point = "TOP", x = 0, y = -40 },
			INDEPENDENT = { point = "CENTER", x = 0, y = 0 },
		},
		growth = "DOWN",
		gap = 2,
		strata = "HIGH",
		independent = {},
	},
	types = {
		xp = true,
		petxp = true,
		reputation = true,
		house = true,
		endeavor = true,
		travelers = true,
		honor = true,
	},
	appearance = {
		texture = "Solid",
		xpGradient = { { 0.335, 0.388, 1.0 }, { 0.773, 0.380, 1.0 } },
		xpUseClassColor = false,
		questColor = { 1.0, 0.589, 0.0 },
		restedColor = { 0.309, 0.562, 1.0, 0.5 },
		background = { 0, 0, 0, 0.5 },
		typeColors = {
			petxp = { 1, 128 / 255, 64 / 255 },
			honor = { 0.77, 0.12, 0.23 },
			house = { 0.851, 0.710, 0.435 },
			travelers = { 0.035, 0.647, 0.733 },
			endeavor = { 0.294, 0.365, 0.106 },
		},
		standingColors = {},
		border = { style = "NONE", color = { 1, 1, 1, 1 }, customColor = false },
		spark = { enabled = true, customColor = false, color = { 1, 1, 1, 1 } },
		dividers = { enabled = false, spacing = 10, customColor = false, color = { 1, 1, 1, 1 } },
		shimmer = true,
	},
	text = {
		compactNumbers = true,
		decimals = true,
		style = { font = FONT, size = 12, color = { 1, 1, 1, 1 }, outline = "SLUG_OUTLINE" },
		slots = {},
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
		detached = false,
		direction = "UP",
		colors = {
			xp = GAIN_GREEN,
			petxp = GAIN_GREEN,
			reputation = GAIN_GREEN,
			house = { 228 / 255, 138 / 255, 15 / 255 },
			endeavor = { 253 / 255, 199 / 255, 9 / 255 },
			travelers = { 1 / 255, 178 / 255, 193 / 255 },
			honor = { 184 / 255, 24 / 255, 0 },
		},
		text = {
			font = FONT,
			size = 12,
			color = { 1, 1, 1, 1 },
			outline = "SLUG_OUTLINE",
			side = "RIGHT",
			x = 0,
			y = 0,
		},
	},
	party = {
		announce = { levelUpParty = true, levelUpGuild = false, runSummary = true, runChannel = "SELF" },
		markers = true,
		opacity = {
			matchBar = true,
			alpha = 1,
			fadeUntilHovered = false,
			fadedAlpha = 0.25,
			fullInCombat = false,
			fullWithTarget = false,
		},
		style = "DIAMOND",
		size = 14,
		anchor = "CENTER",
		y = 0,
		levelUp = {
			enabled = true,
			onScreen = true,
			chat = true,
			sound = LB.SOUND_LEVEL_UP,
			hideInCombat = false,
			anchor = "BOTTOM",
			direction = "DOWN",
			x = 0,
			y = 0,
			detached = false,
			text = { font = FONT, size = 12, outline = "SLUG_OUTLINE" },
		},
	},
	time = {},
}

---@param text string
---@return LBTextSlot
local function Slot(text)
	return { text = text, visibility = "ALWAYS", x = 0, y = 0, style = {} }
end

defaults.text.slots.xp = {
	INSIDE_LEFT = Slot((LEVEL or "Level") .. " [level]"),
	INSIDE_CENTER = Slot("[cur] / [max] ([remaining])"),
	INSIDE_RIGHT = Slot("[percent]% ([percentquest]%)"),
	BELOW_LEFT = Slot(L["Leveling in:"] .. " [ttl] ([xph] " .. L["XP/Hr"] .. ")"),
	BELOW_RIGHT = Slot(L["Completed:"] .. " [questpercent:color]% | " .. L["Rested:"] .. " [restedpercent:color]%"),
}

for _, id in ipairs(LB.TYPE_ORDER) do
	if id ~= "xp" then
		defaults.text.slots[id] = {
			INSIDE_LEFT = Slot("[name]"),
			INSIDE_RIGHT = Slot("[percent]%"),
		}
	end
end

defaults.text.slots.house.INSIDE_LEFT = Slot("[standing]")
defaults.text.slots.travelers.INSIDE_RIGHT = Slot("[cur] / [max]")

---@type LBDatabase
local globalDefaults = {
	version = SCHEMA_VERSION,
	profiles = {},
	profileKeys = {},
	global = {
		minimapButton = { hide = false },
		requestTimePlayed = true,
		editMode = { snap = true, grid = "BRIGHT", hoverBar = false },
	},
}

---@type LBCharacterDatabase
local characterDefaults = {
	useCharacterProfile = false,
}

---@class LBProfile
---@field active LBProfileData
---@field activeName string
---@field db LBDatabase
---@field char LBCharacterDatabase
local Profile = {}
LB.Profile = Profile

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

---The character's key in `profileKeys`. It is worked out from the name once and kept in the character's own saved
---variables, because the name a client reports can change between sessions: on Forever `UnitName` returns the
---surname as its second value, and its first can carry the first name alone or joined to the surname.
---@return string
function Profile:CharacterKey()
	if characterKey then
		return characterKey
	end

	local stored = self.char and self.char.key

	if type(stored) == "string" and stored ~= "" then
		characterKey = stored

		return characterKey
	end

	local name, surname = UnitName("player")

	name = LB:Readable(name, nil)

	if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT then
		LB:Warn(L["your character name could not be read, so the account-wide profile is in use."])

		return DEFAULT_PROFILE
	end

	surname = LB:Readable(surname, nil)

	if type(surname) == "string" and surname ~= "" and not name:find(surname, 1, true) then
		name = name .. " " .. surname
	end

	characterKey = name .. "-" .. RealmKey()

	if self.char then
		self.char.key = characterKey
	end

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
local migrations = {
	-- The notch hung from the bar's top edge before markers had an anchor.
	[2] = function(db)
		for _, profile in pairs(type(db.profiles) == "table" and db.profiles or {}) do
			local party = type(profile) == "table" and profile.party

			if type(party) == "table" and party.style == "NOTCH" and party.anchor == nil then
				party.anchor = "TOP"
			end
		end
	end,
}

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

	if not last or (type(value) ~= "table" and node[last] == value) then
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
---@return string? existing the saved name that matches `name` ignoring case
function Profile:Find(name)
	local lower = name:lower()

	for existing in pairs(self.db.profiles) do
		if existing:lower() == lower then
			return existing
		end
	end
end

---@param name string
---@return boolean valid
local function ValidateNewName(name)
	if not name or name:trim() == "" then
		LB:Warn(L["a profile needs a name."])

		return false
	end

	if LB.Profile:Find(name) then
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

---@class LBExportPayload
---@field addon string
---@field version integer the schema version the profile was saved under
---@field name string the name it was exported under
---@field profile LBProfileData

---@param target table
---@param template table
local function Sanitize(target, template)
	for key, value in pairs(template) do
		local current = target[key]

		if current ~= nil and type(current) ~= type(value) then
			target[key] = LB:CopyTable(value)
		elseif type(current) == "table" then
			Sanitize(current, value)
		end
	end
end

---@param name string
---@return string? encoded nil when the profile is missing or encoding failed
function Profile:Export(name)
	local profile = self.db.profiles[name]

	if not profile then
		return nil
	end

	---@type LBExportPayload
	local payload = {
		addon = LB.name,
		version = SCHEMA_VERSION,
		name = name,
		profile = profile,
	}

	local ok, encoded = pcall(function()
		return C_EncodingUtil.EncodeBase64(C_EncodingUtil.CompressString(C_EncodingUtil.SerializeCBOR(payload)))
	end)

	if not ok or type(encoded) ~= "string" then
		return nil
	end

	return EXPORT_PREFIX .. encoded
end

---@param encoded string
---@return LBExportPayload? payload
---@return string? reason why the string was refused, when it was
function Profile:Decode(encoded)
	local text = (encoded or ""):trim()
	local format = text:match("^LB!(%d+)!")

	if not format then
		return nil, L["This is not a Levelbound profile string, or it was cut short."]
	end

	if tonumber(format) ~= EXPORT_FORMAT then
		return nil, L["This profile string was made by a newer version of Levelbound."]
	end

	local ok, decoded = pcall(C_EncodingUtil.DecodeBase64, text:sub(#EXPORT_PREFIX + 1))
	local decompressed, payload

	if ok and type(decoded) == "string" then
		ok, decompressed = pcall(C_EncodingUtil.DecompressString, decoded)
	end

	if ok and type(decompressed) == "string" then
		ok, payload = pcall(C_EncodingUtil.DeserializeCBOR, decompressed)
	end

	if not ok or type(payload) ~= "table" or payload.addon ~= LB.name then
		return nil, L["This is not a Levelbound profile string, or it was cut short."]
	end

	if type(payload.version) ~= "number" or payload.version > SCHEMA_VERSION then
		return nil, L["This profile string was made by a newer version of Levelbound."]
	end

	if type(payload.profile) ~= "table" or type(payload.name) ~= "string" then
		return nil, L["This profile string has no profile in it."]
	end

	return payload
end

---@param name string the name an import would like
---@return string name free of every existing profile
function Profile:FreeName(name)
	local base = (name or ""):trim()

	if base == "" then
		base = DEFAULT_PROFILE
	end

	if not self:Exists(base) then
		return base
	end

	local index = 2

	while self:Exists(("%s (%d)"):format(base, index)) do
		index = index + 1
	end

	return ("%s (%d)"):format(base, index)
end

---@param payload LBExportPayload from Profile:Decode
---@param name string
---@return boolean imported
function Profile:Import(payload, name)
	if not ValidateNewName(name) then
		return false
	end

	local profile = LB:CopyTable(payload.profile)
	local staging = { version = payload.version, profiles = { [name] = profile }, profileKeys = {}, global = {} }

	---@cast staging LBDatabase
	self:Migrate(staging)

	Sanitize(profile, defaults)

	self.db.profiles[name] = profile
	self:Activate(name)

	return true
end

---@param slot LBTextSlot
---@return LBTextStyle style the shared style with this slot's overrides applied
function Profile:ResolveStyle(slot)
	local style = LB:CopyTable(self.active.text.style)

	for key, value in pairs(slot.style or {}) do
		style[key] = LB:CopyTable(value)
	end

	return style
end

---@param from string progress type to copy
---@param to string progress type to replace
function Profile:CopySlots(from, to)
	local slots = self.active.text.slots

	if from == to or not slots[from] then
		return
	end

	slots[to] = LB:CopyTable(slots[from])

	LB.Callbacks:Fire("Settings", "text.slots", nil)
end

---@param from string
---@param to string
---@return boolean renamed
function Profile:Rename(from, to)
	if from == to then
		return self:Exists(from)
	end

	local existing = self:Find(to)

	if not self:Exists(from) or (existing ~= from and not ValidateNewName(to)) then
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
		self:Activate(to)
	end

	return true
end

---@param name string
---@param replacement string? the profile to activate when `name` is active; the first remaining when nil
---@return boolean deleted
function Profile:Delete(name, replacement)
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
		self:Activate(replacement and self:Exists(replacement) and replacement or self:List()[1])
	end

	return true
end

---@param enabled boolean
function Profile:SetUseCharacterProfile(enabled)
	self.char.useCharacterProfile = enabled
	self.db.profileKeys[self:CharacterKey()] = nil

	self:Activate(self:ResolveName())
end

---@return LBGlobalSettings
function Profile:Global()
	return self.db.global
end

---@return LBProfileData copy of the active profile, for an editing session to fall back to
function Profile:Snapshot()
	return LB:CopyTable(self.active)
end

---@param data LBProfileData a copy taken by Snapshot while this profile was active
function Profile:Restore(data)
	LB:MergeDefaults(data, defaults)

	self.db.profiles[self.activeName] = data
	self.active = data

	LB.Callbacks:Fire("Settings", nil, nil)
end

---@return LBProfileData defaults a fresh copy, for comparison and reset controls
function Profile:Defaults()
	return LB:CopyTable(defaults)
end
