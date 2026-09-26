local LB = select(2, ...)

local MAX_PARTY = 4

---@class LBRosterMember
---@field name string
---@field unit string?
---@field class string?
---@field state LBPartyState
---@field offline boolean
---@field fraction number progress toward that member's next level
---@field updated number? last update time

---@class LBRoster
---@field members table<string, LBRosterMember>
---@field wasGrouped boolean?
local Roster = {
	members = {},
}
LB.Roster = Roster

---@param a string
---@param b string
---@return boolean? same nil when the client will not permit the comparison
local function SameUnit(a, b)
	if C_Secrets and C_Secrets.CanCompareUnitTokens and not C_Secrets.CanCompareUnitTokens(a, b) then
		return nil
	end

	local same = UnitIsUnit(a, b)

	if issecretvalue(same) then
		return nil
	end

	return same == true
end

---@return boolean usable a 5-player group the protocol should talk on (never a raid)
function Roster:InUsableGroup()
	return IsInGroup() and not IsInRaid()
end

---@param name string
---@return string? unit the party token this name resolves to, if any
function Roster:UnitFor(name)
	if type(name) ~= "string" or name == "" then
		return nil
	end

	for index = 1, MAX_PARTY do
		local unit = "party" .. index

		if UnitExists(unit) and SameUnit(name, unit) then
			return unit
		end
	end

	return nil
end

---@param name string
---@return boolean
function Roster:IsMember(name)
	if not self:InUsableGroup() then
		return false
	end

	if SameUnit(name, "player") ~= false then
		return false
	end

	return self:UnitFor(name) ~= nil
end

---@param name string
---@param state LBPartyState
function Roster:Upsert(name, state)
	local member = self.members[name]

	if member and not LB.Comms:IsNewer(state.sequence, member.state.sequence) then
		return
	end

	local fraction = state.xpMax > 0 and math.min(state.xp / state.xpMax, 1) or 0

	if member then
		member.state = state
		member.fraction = fraction
		member.updated = GetTime()
	else
		self.members[name] = {
			name = name,
			unit = self:UnitFor(name),
			state = state,
			offline = false,
			fraction = fraction,
			updated = GetTime(),
		}
	end

	LB.Callbacks:Fire("Party")
end

function Roster:Clear()
	if not next(self.members) then
		return
	end

	wipe(self.members)

	LB.Callbacks:Fire("Party")
end

function Roster:Reconcile()
	if not self:InUsableGroup() then
		self:Clear()

		return
	end

	local changed = false

	for name, member in pairs(self.members) do
		local unit = self:UnitFor(name)

		if not unit then
			self.members[name] = nil
			changed = true
		else
			local offline = not UnitIsConnected(unit)

			if member.offline ~= offline or member.unit ~= unit then
				member.offline = offline
				member.unit = unit
				changed = true
			end
		end
	end

	if changed then
		LB.Callbacks:Fire("Party")
	end
end

---@return LBRosterMember[] members with a marker to draw, in a stable order
function Roster:Visible()
	local list = {}

	for _, member in pairs(self.members) do
		if not member.state.atMaxLevel then
			list[#list + 1] = member
		end
	end

	table.sort(list, function(a, b)
		return a.name < b.name
	end)

	return list
end
