local LB = select(2, ...)

local L = LB.L

---@alias LBTagGroup "CHARACTER" | "PROGRESS" | "BONUS" | "TIME"

---@class LBTagPart
---@field literal string?
---@field tag string?
---@field color boolean?
---@field variant string? the lowercased text after the colon, if any
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

---@param name string the first name, or the first name and surname joined by `separator`
---@param surname string?
---@param separator string? what joins a first name and surname
---@param variant string? "first" for the first name, "short" for it and the surname's initial, else the full name
---@return string
function Tags.StyleName(name, surname, separator, variant)
	separator = separator or " "

	if not surname or surname == "" then
		local at = separator ~= "" and name:find(separator, 1, true)

		if at then
			name, surname = name:sub(1, at - 1), name:sub(at + #separator)
		end
	end

	if not surname or surname == "" or variant == "first" then
		return name
	end

	if variant == "short" then
		return ("%s %s."):format(name, surname:match("^[%z\1-\127\194-\244][\128-\191]*") or surname:sub(1, 1))
	end

	return name .. separator .. surname
end

---@return string? separator what joins a first name and surname, on Forever only
function Tags.Separator()
	if WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then
		return Constants and Constants.CharacterNameSeparatorConsts
			and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR
	end
end

---The source a standalone party bar renders its text with: tags that would read the player read this member.
---@class LBMemberSource
---@field id "party"
---@field member LBRosterMember

---@param member LBRosterMember
---@return LBMemberSource
function Tags.MemberSource(member)
	return { id = "party", member = member }
end

---@param variant string?
---@return string name the player's name in the variant's style, or "" while it is secret
local function PlayerName(variant)
	local name, second = UnitName("player")

	name = LB:Readable(name, nil)

	if type(name) ~= "string" or name == "" then
		return ""
	end

	-- Only Forever's second return is a surname; Retail's is the realm.
	local surname, separator

	if WOW_PROJECT_ID == WOW_PROJECT_CAMELOT then
		surname = LB:Readable(second, nil)
		separator = Tags.Separator()
	end

	return Tags.StyleName(name, type(surname) == "string" and surname or nil, separator, variant)
end

---@type table<string, fun(snapshot: LBSnapshot, source: LBSource?, variant: string?): string>
local resolvers = {
	level = function(snapshot, source)
		return LB.Format:Value("LEVEL", snapshot, source)
	end,
	name = function(snapshot, source, variant)
		if source and source.member then
			return Tags.StyleName(source.member.name, nil, Tags.Separator(), variant)
		end

		if source and source.id == "xp" then
			return PlayerName(variant)
		end

		return LB.Format:Value("NAME", snapshot, source)
	end,
	classicon = function(_, source)
		if source and source.member then
			return LB.ClassIcon:Markup(LB.Roster.ClassOf(source.member))
		end

		return LB.ClassIcon:Markup(LB.ClassIcon:PlayerClass())
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
		if source and source.member then
			local rate = source.member.state.rate

			return LB.Format:Number(rate and LB.Progress.PerHour(rate))
		end

		return LB.Format:Value("XP_PER_HOUR", snapshot, source)
	end,
	ttl = function(snapshot, source)
		if source and source.member then
			local rate = source.member.state.rate

			return LB.Format:Duration(rate and LB.Progress.TimeToLevel(snapshot, rate))
		end

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

		variant = variant and variant ~= "" and variant:lower() or nil

		parts[#parts + 1] = {
			tag = name and name:lower() or nil,
			color = variant == "color",
			variant = variant,
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
				local value = resolver(snapshot, source, part.variant)
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
	Info("name", "CHARACTER"),
	Info("name:first", "CHARACTER"),
	Info("name:short", "CHARACTER"),
	Info("classicon", "CHARACTER"),
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

local PARTY_TAGS = {
	Info("name", "CHARACTER"),
	Info("name:first", "CHARACTER"),
	Info("name:short", "CHARACTER"),
	Info("classicon", "CHARACTER"),
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
}

local HOUSE_TAGS = {
	Info("name", "PROGRESS"),
	Info("level", "PROGRESS"),
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

	if typeId == "party" then
		return PARTY_TAGS
	end

	if typeId == "house" then
		return HOUSE_TAGS
	end

	return OTHER_TAGS
end
