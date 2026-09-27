local LB = select(2, ...)

local DASH = "—"

local PERCENT_WHOLE = PERCENTAGE_STRING
local PERCENT_DECIMAL = PERCENTAGE_STRING:gsub("%%d", "%%.1f")

---@class LBFormatOptions
---@field compact boolean
---@field decimals boolean

---@class LBFormat
---@field options LBFormatOptions? read from the profile on first use and dropped on every settings change
local Format = {}
LB.Format = Format

---@return LBFormatOptions
local function Options()
	local options = Format.options

	if not options then
		options = {
			compact = LB.Profile:Get("text.compactNumbers") == true,
			decimals = LB.Profile:Get("text.decimals") == true,
		}
		Format.options = options
	end

	return options
end

---@param value number?
---@return string
function Format:Number(value)
	if not value then
		return DASH
	end

	if Options().compact then
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

	if Options().decimals then
		return PERCENT_DECIMAL:format(fraction * 100)
	end

	return PERCENT_WHOLE:format(Round(fraction * 100))
end

---@param fraction number? 0-1
---@return string
function Format:PercentNumber(fraction)
	if not fraction then
		return DASH
	end

	if Options().decimals then
		return ("%.1f"):format(fraction * 100)
	end

	return tostring(Round(fraction * 100))
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

-- Compact, for chat: "1h 24m", "18m", "45s".
---@param seconds number?
---@return string?
function Format:Short(seconds)
	if not seconds or seconds <= 0 then
		return nil
	end

	local hours = math.floor(seconds / 3600)
	local minutes = math.floor(seconds % 3600 / 60)

	if hours > 0 then
		return LB.L["%dh %dm"]:format(hours, minutes)
	elseif minutes > 0 then
		return LB.L["%dm"]:format(minutes)
	end

	return LB.L["%ds"]:format(math.floor(seconds))
end

---@type table<string, fun(snapshot: LBSnapshot, source: LBSource?): string>
local resolvers = {
	LEVEL = function(snapshot)
		return snapshot.level and tostring(snapshot.level) or DASH
	end,

	NAME = function(snapshot)
		return snapshot.label or DASH
	end,

	STANDING = function(snapshot)
		return snapshot.standing or DASH
	end,

	VALUE = function(snapshot)
		return Format:Fraction(snapshot.cur, snapshot.max)
	end,

	PERCENT = function(snapshot)
		return Format:Percent(LB.Progress.Fraction(snapshot) or 0)
	end,

	REMAINING = function(snapshot)
		return Format:Number(LB.Progress.Remaining(snapshot))
	end,

	PERCENT_WITH_QUESTS = function(snapshot)
		local _, quest = LB.Progress.Fills(snapshot)

		return quest and Format:Percent(quest) or DASH
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

		return rate and Format:Number(LB.Progress.PerHour(rate)) or DASH
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

LB.Callbacks:Register("Settings", Format, function()
	Format.options = nil
end)
