local LB = select(2, ...)

local MAJOR = 1
local SEQUENCE_MAX = 65536
local MERGE = 0.2
local REPLY_DELAY = 1
local PRIORITY = "NORMAL"
local RETRY = 1
local RETRIES = 3

local FLAG_MAX_LEVEL = 1

---@class LBPartyState
---@field sequence integer
---@field level integer
---@field xp integer
---@field xpMax integer
---@field flags integer
---@field atMaxLevel boolean
---@field rested integer?
---@field quest integer?
---@field rate integer?

---@class LBComms
---@field sequence integer outgoing counter
---@field restricted boolean
---@field pending boolean
---@field owed boolean request arrived while restricted and is owed an answer
---@field asking boolean a request was refused by messaging lockdown and goes out when it lifts
---@field queued boolean
---@field stale boolean stale message still in queue
---@field retries integer refused sends of the current state
local Comms = {
	sequence = 0,
	restricted = false,
	pending = false,
	owed = false,
	asking = false,
	queued = false,
	stale = false,
	retries = 0,
}
LB.Comms = Comms

---@param incoming integer
---@param known integer
---@return boolean
function Comms:IsNewer(incoming, known)
	local difference = (incoming - known) % SEQUENCE_MAX

	return difference > 0 and difference < (SEQUENCE_MAX / 2)
end

---out of range; every rejection is silent
---@param text string
---@return LBPartyState? state nil when the message is malformed, a different major version, or
function Comms.Parse(text)
	if type(text) ~= "string" then
		return nil
	end

	local major = text:match("^(%d+):")

	if tonumber(major) ~= MAJOR then
		return nil
	end

	local sequence, level, xp, xpMax, flags = text:match("^%d+:(%d+):(%d+):(%d+):(%d+):(%d+)")

	sequence, level, xp, xpMax, flags =
		tonumber(sequence), tonumber(level), tonumber(xp), tonumber(xpMax), tonumber(flags)

	if not sequence or not level or not xp or not xpMax or not flags then
		return nil
	end

	if sequence < 0 or sequence >= SEQUENCE_MAX then
		return nil
	end

	if level < 1 or level > (GetMaxPlayerLevel() or 0) then
		return nil
	end

	if xpMax <= 0 or xp < 0 or xp > xpMax then
		return nil
	end

	local rested, quest, rate = text:match("^%d+:%d+:%d+:%d+:%d+:%d+:(%d+):(%d+):(%d+)")

	rested, quest, rate = tonumber(rested), tonumber(quest), tonumber(rate)

	return {
		sequence = sequence,
		level = level,
		xp = xp,
		xpMax = xpMax,
		flags = flags,
		atMaxLevel = bit.band(flags, FLAG_MAX_LEVEL) ~= 0,
		rested = rested,
		quest = quest,
		rate = rate and rate > 0 and rate or nil,
	}
end

---@param text string
---@return boolean
function Comms.IsRequest(text)
	return text == MAJOR .. ":R"
end

---@return string? message nil when there is nothing worth sending
function Comms:Encode()
	local snapshot = LB.Model:Get("xp")

	if not snapshot or snapshot.max <= 0 then
		return nil
	end

	self.sequence = (self.sequence + 1) % SEQUENCE_MAX

	local flags = snapshot.atCap and FLAG_MAX_LEVEL or 0
	local rate = LB.Session and LB.Session:Rate()

	return ("%d:%d:%d:%d:%d:%d:%d:%d:%d"):format(
		MAJOR,
		self.sequence,
		snapshot.level or 0,
		snapshot.cur,
		snapshot.max,
		flags,
		math.floor(snapshot.overlays.rested or 0),
		math.floor(snapshot.overlays.quest or 0),
		rate and math.floor(rate * 3600) or 0
	)
end

---@return string? channel nil when not in a party the protocol should use
function Comms:Channel()
	if IsInRaid() then
		return nil
	end

	if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) then
		return "INSTANCE_CHAT"
	end

	if IsInGroup(LE_PARTY_CATEGORY_HOME) then
		return "PARTY"
	end

	return nil
end

---@return boolean
function Comms:IsRestricted()
	if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then
		return true
	end

	if C_RestrictedActions and C_RestrictedActions.IsAddOnRestrictionActive then
		return C_RestrictedActions.IsAddOnRestrictionActive(Enum.AddOnRestrictionType.Chat) == true
	end

	return false
end

---@param message string
---@param onSent? fun(arg: any, didSend: boolean, result: integer)
---@return boolean handed false when not in a party the protocol uses
function Comms:Transmit(message, onSent)
	local channel = self:Channel()

	if not channel then
		return false
	end

	ChatThrottleLib:SendAddonMessage(PRIORITY, LB.MESSAGE_PREFIX, message, channel, nil, nil, onSent)

	return true
end

---@param result integer
---@return boolean retry worth sending again shortly
function Comms:OnRefused(result)
	if result == Enum.SendAddonMessageResult.AddOnMessageLockdown then
		self.restricted = true

		return false
	end

	return result ~= Enum.SendAddonMessageResult.NotInGroup
		and result ~= Enum.SendAddonMessageResult.InvalidChannel
		and result ~= Enum.SendAddonMessageResult.InvalidChatType
end

---@param _ any
---@param didSend boolean
---@param result integer
local function OnStateSent(_, didSend, result)
	Comms.queued = false

	if didSend then
		Comms.retries = 0

		if Comms.stale then
			Comms:TransmitState()
		end

		return
	end

	if Comms:OnRefused(result) then
		if Comms.retries < RETRIES then
			Comms.retries = Comms.retries + 1

			LB.Events:Merge("party:retry", RETRY, function()
				Comms:TransmitState()
			end)
		end
	elseif Comms.restricted then
		Comms.pending = true
	end
end

function Comms:TransmitState()
	if self.queued then
		self.stale = true

		return
	end

	local message = self:Encode()

	if not message then
		return
	end

	self.queued = true
	self.stale = false

	if not self:Transmit(message, OnStateSent) then
		self.queued = false
	end
end

---@param immediate boolean? skip the merge window, for a login or a group join
function Comms:Send(immediate)
	if not self:Channel() then
		return
	end

	if self.restricted or self:IsRestricted() then
		self.restricted = true
		self.pending = true

		return
	end

	self.retries = 0

	if immediate then
		self:TransmitState()

		return
	end

	LB.Events:Merge("party:send", MERGE, function()
		Comms:TransmitState()
	end)
end

---@param _ any
---@param didSend boolean
---@param result integer
local function OnRequestSent(_, didSend, result)
	if not didSend and not Comms:OnRefused(result) and Comms.restricted then
		Comms.asking = true
	end
end

function Comms:SendRequest()
	if not self:Channel() then
		return
	end

	if self.restricted then
		self.asking = true

		return
	end

	self:Transmit(MAJOR .. ":R", OnRequestSent)
end

function Comms:AnswerRequest()
	if self.restricted then
		self.owed = true

		return
	end

	C_Timer.After(math.random() * REPLY_DELAY, function()
		Comms:Send(true)
	end)
end

---@param state boolean
function Comms:OnRestrictionChanged(state)
	if state then
		self.restricted = true

		return
	end

	self.restricted = false

	if self.asking then
		self.asking = false

		self:SendRequest()
	end

	if self.pending or self.owed then
		self.pending = false
		self.owed = false

		self:Send(true)
	end
end

---@param prefix string
---@param text string
---@param channel string
---@param sender string
function Comms:OnMessage(prefix, text, channel, sender)
	if prefix ~= LB.MESSAGE_PREFIX then
		return
	end

	if not LB.Roster:IsMember(sender) then
		return
	end

	if self.IsRequest(text) then
		self:AnswerRequest()

		return
	end

	local state = self.Parse(text)

	if not state then
		return
	end

	LB.Roster:Upsert(sender, state)
end
