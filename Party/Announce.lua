local LB = select(2, ...)

local L = LB.L

local SETTLE = 0.5
local RATE_AFTER = 60
local RESUME = 900 -- seconds logged out after which a saved run is dropped
local RUN_TYPES = { party = true, scenario = true }
local LEVEL_UP_ICON = "{rt1}" -- the star raid target icon, which chat draws for every reader

---@class LBRun
---@field instance number
---@field started number time() when the run began, moved later by any time logged out
---@field gained number XP gained before `base` was taken
---@field base number session XP when the run began or was restored
---@field seen number? time() at logout or reload

---@class LBAnnounce
---@field held table<string, string> the latest message per chat type, waiting out a chat lockdown
---@field loaded boolean the first loading screen since login or reload has been seen
local Announce = {
	held = {},
	loaded = false,
}
LB.Announce = Announce

---@return LBPartySettings
local function Settings()
	return LB.Profile:Get("party")
end

---@param level integer
---@param seconds number? how long the level took; nil when time played is unknown
---@return string
function Announce:LevelUpText(level, seconds)
	local took = LB.Format:Short(seconds)
	local text = took and L["Reached level %d in %s"]:format(level, took) or L["Reached level %d"]:format(level)

	return ("%s %s %s"):format(LEVEL_UP_ICON, LB.Share.PREFIX, text)
end

function Announce:Flush()
	if LB.Comms:IsRestricted() then
		return
	end

	for chatType, text in pairs(self.held) do
		self.held[chatType] = nil

		C_ChatInfo.SendChatMessage(text, chatType)
	end
end

---@param text string
---@param chatType string
function Announce:Send(text, chatType)
	self.held[chatType] = text

	self:Flush()
end

---@param level integer
function Announce:OnLevelUp(level)
	local settings = Settings().announce
	local text = self:LevelUpText(level, LB.TimePlayed.completed)

	-- Printed for the player alone, outside a group: an EMOTE send needs a hardware event, which a level-up lacks.
	if settings.levelUpEmote and not IsInGroup() then
		print(C_ChatInfo.ReplaceIconAndGroupExpressions(text))
	end

	if settings.levelUpParty then
		local channel = LB.Comms:Channel()

		if channel then
			self:Send(text, channel)
		end
	end

	if settings.levelUpGuild and IsInGuild() then
		self:Send(text, "GUILD")
	end
end

---@param gained number
---@param seconds number
---@param snapshot LBSnapshot the current level, which the gain is measured against
---@return string
function Announce:RunText(gained, seconds, snapshot)
	local Format = LB.Format
	local share = LB.Progress.Part(snapshot, gained) or 0
	local parts = {
		L["This run: +%s XP (%s of a level) in %s"]:format(
			AbbreviateNumbers(gained),
			Format:Percent(share),
			Format:Short(seconds) or L["%ds"]:format(0)
		),
	}

	if seconds >= RATE_AFTER then
		parts[#parts + 1] = L["%s XP/hr"]:format(AbbreviateNumbers(LB.Progress.PerHour(gained / seconds)))
	end

	local runs = LB.Progress.Runs(snapshot, gained)

	if runs then
		parts[#parts + 1] = runs == 1 and L["1 more run to level"] or L["%d more runs to level"]:format(runs)
	end

	return ("%s %s"):format(LB.Share.PREFIX, table.concat(parts, LB.Share.SEPARATOR))
end

---@param run LBRun
---@return number
local function Gained(run)
	return run.gained + (LB.Session.xp or 0) - run.base
end

---Starts, keeps or drops the saved run on each loading screen. A run survives a reload or a short logout inside the
---same instance, and the player leaving it dead or as a ghost.
function Announce:TrackRun()
	local char = LB.Profile.char

	if not char then
		return
	end

	local run = type(char.run) == "table" and char.run or nil
	local first = not self.loaded

	self.loaded = true

	if run and first then
		local away = run.seen and time() - run.seen

		run.seen = nil

		if away and away >= 0 and away <= RESUME then
			run.started = run.started + away
			run.base = LB.Session.xp or 0
		else
			run = nil
		end
	end

	local inInstance, instanceType = IsInInstance()

	if not inInstance or not RUN_TYPES[instanceType] then
		char.run = run and UnitIsDeadOrGhost("player") and run or nil

		return
	end

	local instance = select(8, GetInstanceInfo())

	if run and run.instance == instance then
		char.run = run

		return
	end

	char.run = { instance = instance, started = time(), gained = 0, base = LB.Session.xp or 0 }
end

function Announce:SaveRun()
	local run = LB.Profile.char and LB.Profile.char.run

	if type(run) ~= "table" then
		return
	end

	run.gained = Gained(run)
	run.base = 0
	run.seen = time()
end

local CHAT_TYPES = { PARTY = "PARTY", INSTANCE = "INSTANCE_CHAT", GUILD = "GUILD" }

---@param channel string a run summary channel setting
---@return boolean available the player can post to it now
local function Available(channel)
	if channel == "PARTY" then
		return IsInGroup(LE_PARTY_CATEGORY_HOME) and not IsInRaid()
	elseif channel == "INSTANCE" then
		return IsInGroup(LE_PARTY_CATEGORY_INSTANCE)
	elseif channel == "GUILD" then
		return IsInGuild()
	end

	return false
end

---Posts the finished run's summary to the chosen chat, or prints it for the player alone when that chat is
---Self Only or not available.
function Announce:OnRunComplete()
	local char = LB.Profile.char
	local run = char and char.run

	if type(run) ~= "table" then
		return
	end

	char.run = nil

	local announce = Settings().announce

	if not announce.runSummary then
		return
	end

	local gained = Gained(run)
	local snapshot = LB.Model:Get("xp")

	if gained <= 0 or not snapshot then
		return
	end

	local text = self:RunText(gained, math.max(time() - run.started, 0), snapshot)
	local channel = announce.runChannel

	if Available(channel) then
		self:Send(text, CHAT_TYPES[channel])
	else
		print(text)
	end
end

LB.Events:Register("PLAYER_ENTERING_WORLD", Announce, function(owner)
	owner:TrackRun()
end)

LB.Events:Register("PLAYER_LOGOUT", Announce, function(owner)
	owner:SaveRun()
end)

for _, event in ipairs({ "LFG_COMPLETION_REWARD", "SCENARIO_COMPLETED" }) do
	LB.Events:Register(event, Announce, function(owner)
		owner:OnRunComplete()
	end)
end

LB.Events:Register("PLAYER_LEVEL_UP", Announce, function(owner, _, level)
	level = LB:Readable(level, nil) or UnitLevel("player")

	C_Timer.After(SETTLE, function()
		owner:OnLevelUp(level)
	end)
end)

LB.Events:Register("ADDON_RESTRICTION_STATE_CHANGED", Announce, function(owner, _, restrictionType, active)
	if restrictionType == Enum.AddOnRestrictionType.Chat and not active then
		owner:Flush()
	end
end)
