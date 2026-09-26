local LB = select(2, ...)

local L = LB.L

local SETTLE = 0.5
local RATE_AFTER = 60
local RUN_TYPES = { party = true, scenario = true }

---@class LBRun
---@field instance number
---@field xp number session XP when the run began
---@field started number

---@class LBAnnounce
---@field held table<string, string> the latest message per chat type, waiting out a chat lockdown
---@field run LBRun? the dungeon or delve under way
local Announce = {
	held = {},
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

	return ("%s %s"):format(LB.Share.PREFIX, text)
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
---@param levelMax number XP needed for the current level
---@return string
function Announce:RunText(gained, seconds, levelMax)
	local Format = LB.Format
	local share = levelMax > 0 and gained / levelMax or 0
	local parts = {
		L["This run: +%s XP (%s of a level) in %s"]:format(
			AbbreviateNumbers(gained),
			Format:Percent(share),
			Format:Short(seconds) or L["%ds"]:format(0)
		),
	}

	if seconds >= RATE_AFTER then
		parts[#parts + 1] = L["%s XP/hr"]:format(AbbreviateNumbers(math.floor(gained / seconds * 3600)))
	end

	return ("%s %s"):format(LB.Share.PREFIX, table.concat(parts, LB.Share.SEPARATOR))
end

function Announce:TrackRun()
	local inInstance, instanceType = IsInInstance()

	if not inInstance or not RUN_TYPES[instanceType] or not LB.Session then
		self.run = nil

		return
	end

	local instance = select(8, GetInstanceInfo())

	if self.run and self.run.instance == instance then
		return
	end

	self.run = { instance = instance, xp = LB.Session.xp or 0, started = GetTime() }
end

function Announce:OnRunComplete()
	local run = self.run

	self.run = nil

	if not run or not Settings().announce.runParty or not LB.Session then
		return
	end

	local gained = (LB.Session.xp or 0) - run.xp
	local snapshot = LB.Model:Get("xp")
	local channel = LB.Comms:Channel()

	if gained <= 0 or not snapshot or not channel then
		return
	end

	self:Send(self:RunText(gained, GetTime() - run.started, snapshot.max), channel)
end

LB.Events:Register("PLAYER_ENTERING_WORLD", Announce, function(owner)
	owner:TrackRun()
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
