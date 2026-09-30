local LB = select(2, ...)

local L = LB.L

---@alias LBTagGroup "PROGRESS" | "BONUS" | "TIME"

---@class LBTagPart
---@field literal string?
---@field tag string?
---@field color boolean?
---@field raw string?

---@class LBTagInfo
---@field tag string
---@field group LBTagGroup
---@field description string

---@class LBTags
local Tags = {}
LB.Tags = Tags

LB.TextSlotKeys = {
	"ABOVE_LEFT",
	"ABOVE_CENTER",
	"ABOVE_RIGHT",
	"INSIDE_LEFT",
	"INSIDE_CENTER",
	"INSIDE_RIGHT",
	"BELOW_LEFT",
	"BELOW_CENTER",
	"BELOW_RIGHT",
}

local TIME_TAGS = {
	session = true,
	leveltime = true,
	played = true,
	ttl = true,
}

local COLORS = {
	rested = "restedColor",
	restedpercent = "restedColor",
	quest = "questColor",
	questpercent = "questColor",
}

---@param snapshot LBSnapshot
---@param key "quest" | "rested"
---@return number
local function Overlay(snapshot, key)
	local overlays = snapshot.overlays

	return overlays and overlays[key] or 0
end

---@type table<string, fun(snapshot: LBSnapshot, source: LBSource?): string>
local resolvers = {
	level = function(snapshot, source)
		return LB.Format:Value("LEVEL", snapshot, source)
	end,
	name = function(snapshot, source)
		return LB.Format:Value("NAME", snapshot, source)
	end,
	standing = function(snapshot, source)
		return LB.Format:Value("STANDING", snapshot, source)
	end,
	cur = function(snapshot)
		return LB.Format:Number(snapshot.cur)
	end,
	max = function(snapshot)
		return LB.Format:Number(snapshot.max)
	end,
	remaining = function(snapshot, source)
		return LB.Format:Value("REMAINING", snapshot, source)
	end,
	percent = function(snapshot)
		return LB.Format:PercentNumber(LB.Progress.Fraction(snapshot))
	end,
	percentquest = function(snapshot)
		return LB.Format:PercentNumber(LB.Progress.Part(snapshot, snapshot.cur + Overlay(snapshot, "quest")))
	end,
	rested = function(snapshot)
		return LB.Format:Number(Overlay(snapshot, "rested"))
	end,
	restedpercent = function(snapshot)
		return LB.Format:PercentNumber(LB.Progress.Part(snapshot, Overlay(snapshot, "rested")))
	end,
	quest = function(snapshot)
		return LB.Format:Number(Overlay(snapshot, "quest"))
	end,
	questpercent = function(snapshot)
		return LB.Format:PercentNumber(LB.Progress.Part(snapshot, Overlay(snapshot, "quest")))
	end,
	xph = function(snapshot, source)
		return LB.Format:Value("XP_PER_HOUR", snapshot, source)
	end,
	ttl = function(snapshot, source)
		return LB.Format:Value("TIME_TO_LEVEL", snapshot, source)
	end,
	session = function(snapshot, source)
		return LB.Format:Value("SESSION_TIME", snapshot, source)
	end,
	leveltime = function(snapshot, source)
		return LB.Format:Value("LEVEL_TIME", snapshot, source)
	end,
	played = function(snapshot, source)
		return LB.Format:Value("TOTAL_TIME", snapshot, source)
	end,
}

---@param text string?
---@return LBTagPart[]
function Tags:Compile(text)
	local parts = {}
	local position = 1

	text = text or ""

	for start, body, finish in text:gmatch("()%[([^%]]*)%]()") do
		---@cast start integer
		---@cast finish integer
		if start > position then
			parts[#parts + 1] = { literal = text:sub(position, start - 1) }
		end

		local name, variant = body:match("^%s*([%w]+)%s*:?%s*(%w*)%s*$")

		parts[#parts + 1] = {
			tag = name and name:lower() or nil,
			color = variant ~= nil and variant:lower() == "color",
			raw = text:sub(start, finish - 1),
		}

		position = finish
	end

	if position <= #text then
		parts[#parts + 1] = { literal = text:sub(position) }
	end

	return parts
end

---@param color LBColor?
---@param value string
---@return string
local function Tint(color, value)
	if not color then
		return value
	end

	return ("|cff%02x%02x%02x%s|r"):format(
		math.floor((color[1] or 1) * 255 + 0.5),
		math.floor((color[2] or 1) * 255 + 0.5),
		math.floor((color[3] or 1) * 255 + 0.5),
		value
	)
end

---@param parts LBTagPart[]
---@param snapshot LBSnapshot
---@param source LBSource?
---@return string
function Tags:Render(parts, snapshot, source)
	local out = {}

	for index, part in ipairs(parts) do
		if part.literal then
			out[index] = part.literal
		else
			local resolver = part.tag and resolvers[part.tag]

			if not resolver then
				out[index] = part.raw or ""
			else
				local value = resolver(snapshot, source)
				local colorKey = part.color and part.tag and COLORS[part.tag]

				if colorKey then
					value = Tint(LB.Profile:Get("appearance." .. colorKey), value)
				end

				out[index] = value
			end
		end
	end

	return table.concat(out)
end

---@param parts LBTagPart[]
---@return boolean
function Tags:UsesTime(parts)
	for _, part in ipairs(parts) do
		if part.tag and TIME_TAGS[part.tag] and resolvers[part.tag] then
			return true
		end
	end

	return false
end

---@param tag string
---@param group LBTagGroup
---@return LBTagInfo
local function Info(tag, group)
	return { tag = tag, group = group, description = L["tag." .. tag] }
end

local XP_TAGS = {
	Info("level", "PROGRESS"),
	Info("cur", "PROGRESS"),
	Info("max", "PROGRESS"),
	Info("remaining", "PROGRESS"),
	Info("percent", "PROGRESS"),
	Info("percentquest", "PROGRESS"),
	Info("rested", "BONUS"),
	Info("rested:color", "BONUS"),
	Info("restedpercent", "BONUS"),
	Info("restedpercent:color", "BONUS"),
	Info("quest", "BONUS"),
	Info("quest:color", "BONUS"),
	Info("questpercent", "BONUS"),
	Info("questpercent:color", "BONUS"),
	Info("xph", "TIME"),
	Info("ttl", "TIME"),
	Info("session", "TIME"),
	Info("leveltime", "TIME"),
	Info("played", "TIME"),
}

local PET_TAGS = {
	Info("name", "PROGRESS"),
	Info("level", "PROGRESS"),
	Info("cur", "PROGRESS"),
	Info("max", "PROGRESS"),
	Info("remaining", "PROGRESS"),
	Info("percent", "PROGRESS"),
}

local OTHER_TAGS = {
	Info("name", "PROGRESS"),
	Info("standing", "PROGRESS"),
	Info("cur", "PROGRESS"),
	Info("max", "PROGRESS"),
	Info("remaining", "PROGRESS"),
	Info("percent", "PROGRESS"),
}

---@param typeId string
---@return LBTagInfo[]
function Tags:For(typeId)
	if typeId == "xp" then
		return XP_TAGS
	end

	if typeId == "petxp" then
		return PET_TAGS
	end

	return OTHER_TAGS
end
