local LB = select(2, ...)

local QUEST_EVENTS = {
	QUEST_LOG_UPDATE = true,
	UNIT_QUEST_LOG_CHANGED = true,
	QUEST_TURNED_IN = true,
}

---@return number completed
---@return number incomplete
local function ScanQuestXP()
	local completed, incomplete = 0, 0
	local entries = C_QuestLog.GetNumQuestLogEntries()

	for index = 1, entries do
		local questID = C_QuestLog.GetQuestIDForLogIndex(index)

		if questID then
			local reward = GetQuestLogRewardXP(questID) or 0

			if reward > 0 then
				if C_QuestLog.ReadyForTurnIn(questID) or C_QuestLog.IsComplete(questID) then
					completed = completed + reward
				else
					incomplete = incomplete + reward
				end
			end
		end
	end

	return completed, incomplete
end

---@class LBXPSource : LBSource
---@field atMaxLevel boolean
---@field questXP number
---@field incompleteQuestXP number
local XP = LB.Source:New("xp", {
	questXP = 0,
	incompleteQuestXP = 0,
	atMaxLevel = false,

	---@param self LBXPSource
	IsAvailable = function(self)
		self.atMaxLevel = GameRulesUtil.IsPlayerAtEffectiveMaxLevel()

		return GameRulesUtil.CanShowExperienceBar()
	end,

	Events = function()
		return {
			"PLAYER_XP_UPDATE",
			"PLAYER_LEVEL_UP",
			"UPDATE_EXHAUSTION",
			"PLAYER_UPDATE_RESTING",
			"DISABLE_XP_GAIN",
			"ENABLE_XP_GAIN",
			"UPDATE_EXPANSION_LEVEL",
			"QUEST_LOG_UPDATE",
			"UNIT_QUEST_LOG_CHANGED",
			"QUEST_TURNED_IN",
		}
	end,

	---@param self LBXPSource
	---@param event string
	OnEvent = function(self, event, unit)
		if event == "UNIT_QUEST_LOG_CHANGED" and unit ~= "player" then
			return false
		end

		if QUEST_EVENTS[event] then
			self.questXP, self.incompleteQuestXP = ScanQuestXP()
		end

		return self:Refresh()
	end,

	---@param self LBXPSource
	---@param snapshot LBSnapshot
	Read = function(self, snapshot)
		local cur = LB:Readable(UnitXP("player"), nil)
		local max = LB:Readable(UnitXPMax("player"), nil)

		if not cur or not max then
			return false
		end

		local rested = LB:Readable(GetXPExhaustion(), nil) or 0
		local level = LB:Readable(UnitLevel("player"), nil) or 0

		local changed = snapshot.cur ~= cur
			or snapshot.max ~= max
			or snapshot.overlays.quest ~= self.questXP
			or snapshot.overlays.rested ~= rested
			or snapshot.level ~= level

		snapshot.cur = cur
		snapshot.max = max
		snapshot.overlays.quest = self.questXP
		snapshot.overlays.rested = rested
		snapshot.level = level
		snapshot.atCap = self.atMaxLevel

		return changed
	end,
})

---@return number
function XP:IncompleteQuestXP()
	return self.incompleteQuestXP
end
