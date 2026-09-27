local LB = select(2, ...)

local L = LB.L

local PREFIX = "[Levelbound]"
local SEPARATOR = " \194\183 "

local CHANNELS = {
	party = "PARTY",
	instance = "INSTANCE_CHAT",
	raid = "RAID",
	guild = "GUILD",
	say = "SAY",
}

---@class LBShare
---@field PREFIX string starts every message others see
---@field SEPARATOR string between a message's parts
local Share = {
	PREFIX = PREFIX,
	SEPARATOR = SEPARATOR,
}
LB.Share = Share

---@param id string a progress type
---@param snapshot LBSnapshot
---@param source LBSource?
---@return string
function Share:Text(id, snapshot, source)
	local Format = LB.Format
	local parts = { PREFIX }
	local share = LB.Progress.Fraction(snapshot) or 0

	if id == "xp" then
		parts[#parts + 1] = UNIT_LEVEL_TEMPLATE:format(snapshot.level or 0)
	else
		parts[#parts + 1] = Format:Value("NAME", snapshot, source)

		if snapshot.standing and snapshot.standing ~= "" and snapshot.standing ~= snapshot.label then
			parts[#parts + 1] = snapshot.standing
		end
	end

	parts[#parts + 1] = Format:Percent(share)

	if snapshot.max > 0 then
		parts[#parts + 1] = L["%s xp to go"]:format(AbbreviateNumbers(LB.Progress.Remaining(snapshot)))
	end

	local rate = id == "xp" and LB.Session and LB.Session:Rate()
	local left = rate and Format:Short(LB.Session:TimeToLevel())

	if rate and left then
		parts[#parts + 1] = L["~%s at %s XP/hr"]:format(left, AbbreviateNumbers(LB.Progress.PerHour(rate)))
	end

	return table.concat(parts, SEPARATOR)
end

---@param id string
---@return string? text nil when that type has nothing to share
function Share:TextFor(id)
	local snapshot = LB.Model:Get(id)

	if not snapshot then
		return nil
	end

	return self:Text(id, snapshot, LB.Model:Source(id))
end

---@param id string
function Share:Insert(id)
	local text = self:TextFor(id)

	if text and not ChatFrameUtil.InsertLink(text) then
		ChatFrameUtil.OpenChat(text)
	end
end

---@return string? id the XP bar while it is shown, else the first bar shown
local function DefaultType()
	local order = LB.Model:VisibleOrder()

	for _, id in ipairs(order) do
		if id == "xp" then
			return id
		end
	end

	return order[1]
end

---@param channel string? party, instance, raid, guild or say; nil opens the chat box instead
function Share:Command(channel)
	local id = DefaultType()

	if not id then
		LB:Print(L["there is no progress to share."])

		return
	end

	if not channel or channel == "" then
		self:Insert(id)

		return
	end

	local chatType = CHANNELS[channel]

	if not chatType then
		LB:Print(L["share to party, instance, raid, guild or say."])

		return
	end

	if (chatType == "GUILD" and not IsInGuild()) or (chatType ~= "GUILD" and chatType ~= "SAY" and not IsInGroup()) then
		LB:Print(L["you are not in a group or guild to share with."])

		return
	end

	C_ChatInfo.SendChatMessage(self:TextFor(id), chatType)
end
