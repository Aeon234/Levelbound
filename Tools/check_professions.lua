-- Checks Data/Professions.lua outside the game: skill lines matched to their colors, the profession book's order,
-- tracking on and off, the rank read and its gains, and the settings sample.
-- Run from any directory with Lua 5.1: lua Tools/check_professions.lua
-- Loads the real Sources and Professions files against a fake profession book. Exits non-zero on the first failed
-- check.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

function issecretvalue()
	return false
end

function CreateFromMixins(...)
	local object = {}

	for index = 1, select("#", ...) do
		for key, value in pairs((select(index, ...))) do
			object[key] = value
		end
	end

	return object
end

Enum = { Profession = { FirstAid = 0, Blacksmithing = 1, Cooking = 5, Mining = 6, Fishing = 10, Unmapped = 99 } }

local SKILL_LINES = { [0] = 129, [1] = 164, [5] = 185, [6] = 186, [10] = 356, [99] = 0 }
local NAMES = { [129] = "First Aid", [164] = "Blacksmithing", [185] = "Cooking", [186] = "Mining", [356] = "Fishing" }

C_TradeSkillUI = {
	GetProfessionSkillLineID = function(profession)
		return SKILL_LINES[profession]
	end,
	GetTradeSkillDisplayName = function(skillLine)
		return NAMES[skillLine] or ""
	end,
}

-- The profession book: slot indices for prof1, prof2, first aid, fishing and cooking, and each index's skill.
local book = { slots = {}, skills = {} }

function GetProfessions()
	local slots = book.slots

	return slots.prof1, slots.prof2, slots.firstAid, slots.fishing, slots.cooking
end

function GetProfessionInfo(index)
	local skill = book.skills[index]

	return NAMES[skill.line], 0, skill.rank, skill.max, 0, 0, skill.line, 0
end

local registered = {}
local fired = {}

local LB = {
	L = setmetatable({}, { __index = function(_, key)
		return key
	end }),
	TYPE_ORDER = { "xp" },
	can = { professions = true },
	Readable = function(_, value, fallback)
		if value == nil then
			return fallback
		end

		return value
	end,
	Warn = function() end,
	Callbacks = {
		Register = function() end,
		Fire = function(_, event, ...)
			fired[#fired + 1] = { event, ... }
		end,
	},
	Events = {
		Register = function(_, event, owner)
			registered[owner] = registered[owner] or {}
			registered[owner][event] = true
		end,
		UnregisterAll = function(_, owner)
			registered[owner] = nil
		end,
		Coalesce = function(_, _, work)
			work()
		end,
	},
}

local colors = {
	Blacksmithing = { 1, 0, 0 },
	Mining = { 0, 1, 0 },
}

LB.Profile = {
	char = { professions = {} },
	Get = function(_, path)
		local key = path:match("^appearance%.professionColors%.(.+)$")

		return key and colors[key]
	end,
}

assert(loadfile(root .. "Data/Sources.lua"))("Levelbound", LB)
assert(loadfile(root .. "Data/Professions.lua"))("Levelbound", LB)

local Professions, Model = LB.Professions, LB.Model

-- Harness -------------------------------------------------------------------------------------------------

local count = 0

local function Equal(name, actual, expected)
	count = count + 1

	if actual ~= expected then
		print(("FAIL %s: expected %s, got %s"):format(name, tostring(expected), tostring(actual)))
		os.exit(1)
	end
end

local function Joined(list)
	return table.concat(list, ",")
end

-- Index 1 Mining, 2 Blacksmithing, 3 Cooking, 4 Fishing; no First Aid.
book.slots = { prof1 = 2, prof2 = 1, cooking = 3, fishing = 4 }
book.skills = {
	{ line = 186, rank = 75, max = 150 },
	{ line = 164, rank = 33, max = 75 },
	{ line = 185, rank = 50, max = 150 },
	{ line = 356, rank = 118, max = 150 },
}

-- Skill lines and colors --------------------------------------------------------------------------------

Equal("mining key", Professions:Key(186), "Mining")
Equal("first aid key", Professions:Key(129), "FirstAid")
Equal("unmapped profession left out", Professions:Key(0), nil)
Equal("every mapped line listed", #Professions:All(), 5)
Equal("lines sorted by name", Joined(Professions:All()), "164,185,129,356,186")
Equal("saved color", Professions:Color(164), colors.Blacksmithing)
Equal("palette entry missing from the profile falls back", Professions:Color(185)[1], 141 / 255)
Equal("unknown line falls back", Professions:Color(12345)[1], 141 / 255)
Equal("name from the client", Professions:Name(129), "First Aid")

-- The profession book's order ---------------------------------------------------------------------------

Equal("book order indices", Joined(Professions:Indices()), "2,1,3,4")
Equal("learned profession found", Professions:Find(185), 3)
Equal("learned profession position", select(2, Professions:Find(185)), 3)
Equal("unlearned profession not found", Professions:Find(129), nil)

-- Sample -------------------------------------------------------------------------------------------------

Equal("sample without tracking is the first learned", Professions:Sample(), 164)

-- Opt-in ---------------------------------------------------------------------------------------------------

Professions:Create()
Model:Sync()

Equal("nothing tracked by default", next(LB.Profile.char.professions), nil)
Equal("no profession bars by default", Joined(Model:Ids()), "xp")
Equal("no profession source by default", Model:Source("profession186"), nil)
Equal("nothing registered by default", next(registered), nil)

-- Tracking ---------------------------------------------------------------------------------------------

Professions:SetTracked(356, true)
Professions:SetTracked(186, true)

Equal("tracked bars in book order", Joined(Model:Ids()), "xp,profession186,profession356")
Equal("tracked bars visible", Joined(Model:VisibleOrder()), "profession186,profession356")
Equal("tracked bar listens", registered[Model:Source("profession186")].SKILL_LINES_CHANGED, true)
Equal("untracked profession has no source", Model:Source("profession164"), nil)
Equal("sample prefers a tracked profession", Professions:Sample(), 186)
Equal("saved per character", LB.Profile.char.professions[186], true)

local mining = Model:Source("profession186")

Equal("bar label", mining.label, "Mining")
Equal("bar rank", mining.snapshot.cur, 75)
Equal("bar maximum", mining.snapshot.max, 150)
Equal("bar color", mining:Color(), colors.Mining)
Equal("shares the profession settings", Model:SettingsKey("profession186"), "profession")
Equal("fixed type keeps its own settings", Model:SettingsKey("xp"), "xp")

-- Gains --------------------------------------------------------------------------------------------------

book.skills[1].rank = 76
Model:OnSourceEvent(mining, "SKILL_LINES_CHANGED")

local last = fired[#fired]

Equal("skill-up fires progress", last[1] == "Progress" and last[2], "profession186")
Equal("skill-up delta reset after firing", mining.delta, 0)

book.skills[1].max = 225
fired = {}
mining:Refresh()

Equal("training raises the maximum", mining.snapshot.max, 225)
Equal("training is not a gain", mining.delta, 0)

book.skills[1].rank = 77
mining:Refresh()

Equal("next skill-up is one", mining.delta, 1)

-- Untracking and unlearning -----------------------------------------------------------------------------

Professions:SetTracked(186, false)

Equal("untracked bar stays in the order", Joined(Model:Ids()), "xp,profession186,profession356")
Equal("untracked bar hidden", Joined(Model:VisibleOrder()), "profession356")
Equal("untracked bar stops listening", registered[mining], nil)
Equal("untracked removed from saved data", LB.Profile.char.professions[186], nil)

book.slots.fishing = nil
Model:Sync()

Equal("unlearned bar hidden", #Model:VisibleOrder(), 0)

print(("check_professions: %d checks passed"):format(count))
