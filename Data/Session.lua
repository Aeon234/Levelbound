local LB = select(2, ...)

---@class LBSession
---@field xp number gained this session, across level-ups
---@field accumulated number seconds counted while not AFK
---@field since number? when the clock last resumed; nil while paused
---@field afk boolean last known AFK state
---@field started boolean whether the first gain has happened
local Session = {
	xp = 0,
	accumulated = 0,
	afk = false,
	started = false,
}
LB.Session = Session

---@return number seconds
function Session:Elapsed()
	if not self.since then
		return self.accumulated
	end

	return self.accumulated + (GetTime() - self.since)
end

function Session:Reset()
	self.xp = 0
	self.accumulated = 0
	self.started = false
	self.since = self.afk and nil or GetTime()
end

---@param amount number
function Session:OnXPGain(amount)
	if not amount or amount <= 0 then
		return
	end

	self.xp = self.xp + amount
	self.started = true
end

---@param afk boolean
function Session:SetAFK(afk)
	if afk == self.afk then
		return
	end

	self.afk = afk

	if afk then
		self.accumulated = self:Elapsed()
		self.since = nil
	else
		self.since = GetTime()
	end
end

---@return number? xpPerSecond nil until the first gain of the session (scenario E4)
function Session:Rate()
	if not self.started then
		return nil
	end

	local elapsed = self:Elapsed()

	if elapsed <= 0 then
		return nil
	end

	return self.xp / elapsed
end

---@return number? seconds
function Session:TimeToLevel()
	return LB.Progress.TimeToLevel(LB.Model:Get("xp"), self:Rate())
end

function Session:RefreshAFK()
	local afk = UnitIsAFK("player")

	if issecretvalue(afk) then
		return
	end

	self:SetAFK(afk == true)
end

LB.Callbacks:Register("Progress", Session, function(_, id)
	if id ~= "xp" then
		return
	end

	local source = LB.Model:Source("xp")

	if source then
		Session:OnXPGain(source.delta)
	end
end)

LB.Events:Register("PLAYER_FLAGS_CHANGED", Session, function(owner, _, unit)
	if unit == "player" then
		owner:RefreshAFK()
	end
end)
