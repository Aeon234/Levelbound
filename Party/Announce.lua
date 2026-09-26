local LB = select(2, ...)

local L = LB.L

local SETTLE = 0.5

---@class LBAnnounce
---@field held table<string, string> the latest message per chat type, waiting out a chat lockdown
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
