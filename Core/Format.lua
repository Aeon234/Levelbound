local LB = select(2, ...)

local L = LB.L

local DASH = "—"

local PERCENT_WHOLE = PERCENTAGE_STRING
local PERCENT_DECIMAL = PERCENTAGE_STRING:gsub("%%d", "%%.1f")

---@class LBFormat
local Format = {}
LB.Format = Format

---@return string
function Format:Dash()
	return DASH
end

---@param value number?
---@return string
function Format:Number(value)
	if not value then
		return DASH
	end

	if LB.Profile:Get("text.compactNumbers") then
		return AbbreviateNumbers(value)
	end

	return BreakUpLargeNumbers(value)
end

---@param fraction number? 0-1
---@return string
function Format:Percent(fraction)
	if not fraction then
		return DASH
	end

	if LB.Profile:Get("text.decimals") then
		return PERCENT_DECIMAL:format(fraction * 100)
	end

	return PERCENT_WHOLE:format(Round(fraction * 100))
end

---@param cur number?
---@param max number?
---@return string
function Format:Fraction(cur, max)
	if not cur or not max then
		return DASH
	end

	return ("%s / %s"):format(self:Number(cur), self:Number(max))
end

---@param seconds number?
---@return string
function Format:Duration(seconds)
	if not seconds or seconds <= 0 then
		return DASH
	end

	return SecondsToTime(seconds)
end

---@param snapshot LBSnapshot
---@return number fraction
local function SafeFraction(snapshot)
	if snapshot.max <= 0 then
		return 0
	end

	return math.min(snapshot.cur / snapshot.max, 1)
end

---@type table<string, fun(snapshot: LBSnapshot, source: LBSource?): string>
local resolvers = {
	LEVEL = function(snapshot)
		return snapshot.level and tostring(snapshot.level) or DASH
	end,

	NAME = function(snapshot)
		return snapshot.standing or snapshot.label or DASH
	end,

	VALUE = function(snapshot)
		return Format:Fraction(snapshot.cur, snapshot.max)
	end,

	PERCENT = function(snapshot)
		return Format:Percent(SafeFraction(snapshot))
	end,

	REMAINING = function(snapshot)
		return Format:Number(math.max(snapshot.max - snapshot.cur, 0))
	end,

	PERCENT_WITH_QUESTS = function(snapshot)
		if snapshot.max <= 0 then
			return DASH
		end

		return Format:Percent(math.min((snapshot.cur + snapshot.overlays.quest) / snapshot.max, 1))
	end,

	RESTED = function(snapshot)
		return Format:Number(snapshot.overlays.rested)
	end,

	QUEST_XP = function(snapshot)
		return Format:Number(snapshot.overlays.quest)
	end,

	SESSION_TIME = function()
		return LB.Session and Format:Duration(LB.Session:Elapsed()) or DASH
	end,

	LEVEL_TIME = function()
		return LB.TimePlayed and Format:Duration(LB.TimePlayed:LevelTime()) or DASH
	end,

	TOTAL_TIME = function()
		return LB.TimePlayed and Format:Duration(LB.TimePlayed:TotalTime()) or DASH
	end,

	XP_PER_HOUR = function()
		if not LB.Session then
			return DASH
		end

		local rate = LB.Session:Rate()

		return rate and Format:Number(math.floor(rate * 3600)) or DASH
	end,

	TIME_TO_LEVEL = function()
		return LB.Session and Format:Duration(LB.Session:TimeToLevel()) or DASH
	end,
}

---@param kind string
---@param snapshot LBSnapshot
---@param source LBSource?
---@return string
function Format:Value(kind, snapshot, source)
	local resolver = resolvers[kind]

	if not resolver then
		return DASH
	end

	return resolver(snapshot, source)
end

---@param kind string
---@return string label for a tooltip line or a settings list
function Format:Label(kind)
	return L["kind." .. kind]
end

---@return string[] kinds offered for the XP bar, in inventory order
function Format:XPKinds()
	return {
		"LEVEL",
		"VALUE",
		"PERCENT",
		"REMAINING",
		"PERCENT_WITH_QUESTS",
		"SESSION_TIME",
		"LEVEL_TIME",
		"TOTAL_TIME",
		"XP_PER_HOUR",
		"TIME_TO_LEVEL",
	}
end

---@return string[] kinds offered for every other progress type
function Format:OtherKinds()
	return { "NAME", "VALUE", "PERCENT", "REMAINING" }
end
