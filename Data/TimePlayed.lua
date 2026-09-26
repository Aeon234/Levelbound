local LB = select(2, ...)

---@class LBTimePlayed
---@field total number? seconds at the last reply
---@field level number? seconds at this level at the last reply
---@field stamp number? GetTime() when the values above were taken
---@field completed number? seconds the level just finished took, kept across the reset for announcing it
---@field requested boolean
local TimePlayed = {
	requested = false,
}
LB.TimePlayed = TimePlayed

---@return number seconds since the last reply
local function SinceReply()
	if not TimePlayed.stamp then
		return 0
	end

	return GetTime() - TimePlayed.stamp
end

function TimePlayed:RequestOnce()
	if self.requested or not LB.Profile:Global().requestTimePlayed then
		return
	end

	self.requested = true

	RequestTimePlayed()
end

---@param total number
---@param level number
function TimePlayed:OnReply(total, level)
	self.total = total
	self.level = level
	self.stamp = GetTime()
end

function TimePlayed:OnLevelUp()
	self.completed = self:LevelTime()

	if not self.stamp then
		return
	end

	self.total = self:TotalTime()
	self.level = 0
	self.stamp = GetTime()
end

---@return number? seconds
function TimePlayed:LevelTime()
	if not self.level then
		return nil
	end

	return self.level + SinceReply()
end

---@return number? seconds
function TimePlayed:TotalTime()
	if not self.total then
		return nil
	end

	return self.total + SinceReply()
end

LB.Events:Register("TIME_PLAYED_MSG", TimePlayed, function(owner, _, total, level)
	owner:OnReply(total, level)
end)

LB.Events:Register("PLAYER_LEVEL_UP", TimePlayed, function(owner)
	owner:OnLevelUp()
end)
