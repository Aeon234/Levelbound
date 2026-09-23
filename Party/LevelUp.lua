local LB = select(2, ...)

local MAX_PARTY = 4
local SOUND_GAP = 2

---@class LBLevelUpMember
---@field key string GUID, or the name when the GUID cannot be read
---@field name string
---@field class string?
---@field level integer

---@class LBLevelUp
---@field known table<string, integer> last level seen per member
---@field held table<string, LBLevelUpMember> notices waiting for combat to end, one per member
---@field inCombat boolean
---@field soundAt number? `GetTime()` of the last sound played
local LevelUp = {
	known = {},
	held = {},
	inCombat = false,
}
LB.LevelUp = LevelUp

---@param key string
---@param level integer
---@return boolean rose true only when a member already known has a higher level
function LevelUp:Observe(key, level)
	local previous = self.known[key]

	self.known[key] = level

	return previous ~= nil and level > previous
end

---@param present table<string, true>
function LevelUp:Forget(present)
	for key in pairs(self.known) do
		if not present[key] then
			self.known[key] = nil
		end
	end
end

---@param member LBLevelUpMember
function LevelUp:Hold(member)
	local waiting = self.held[member.key]

	if not waiting or member.level > waiting.level then
		self.held[member.key] = member
	end
end

---@return LBLevelUpMember[] held sorted by name; the hold is left empty
function LevelUp:TakeHeld()
	local list = {}

	for _, member in pairs(self.held) do
		list[#list + 1] = member
	end

	wipe(self.held)
	table.sort(list, function(a, b)
		return a.name < b.name
	end)

	return list
end

---@param now number
---@return boolean play false within SOUND_GAP seconds of the last sound played
function LevelUp:ClaimSound(now)
	if self.soundAt and now - self.soundAt < SOUND_GAP then
		return false
	end

	self.soundAt = now

	return true
end

---@param unit string
---@return LBLevelUpMember? member nil when the unit is absent or cannot be read
local function Read(unit)
	if not UnitExists(unit) then
		return nil
	end

	local name = LB:Readable(UnitName(unit), nil)
	local level = LB:Readable(UnitLevel(unit), nil)

	if type(name) ~= "string" or name == "" or name == UNKNOWNOBJECT or type(level) ~= "number" or level < 1 then
		return nil
	end

	local guid = LB:Readable(UnitGUID(unit), nil)
	local _, class = UnitClass(unit)

	return {
		key = type(guid) == "string" and guid or name,
		name = name,
		class = LB:Readable(class, nil),
		level = level,
	}
end

---@param member LBLevelUpMember
---@return string name the name in class colour when the class is known
function LevelUp:ColoredName(member)
	local color = member.class and C_ClassColor.GetClassColor(member.class)

	return color and color:WrapTextInColorCode(member.name) or member.name
end

---@param member LBLevelUpMember
---@param settings LBLevelUpSettings
function LevelUp:Deliver(member, settings)
	local name = self:ColoredName(member)

	if settings.onScreen then
		LB.LevelUpNotice:Show(name, member.level)
	end

	if settings.chat then
		LB:Print(LB.L["%s reached level %d"], name, member.level)
	end

	if settings.sound and self:ClaimSound(GetTime()) then
		self:PlaySound()
	end
end

function LevelUp:PlaySound()
	if PlaySoundFile then
		PlaySoundFile(LB.Media.sounds.levelUp, "SFX")
	end
end

---@param member LBLevelUpMember
function LevelUp:Notify(member)
	local settings = LB.Profile:Get("party.levelUp")

	if not settings or not settings.enabled then
		return
	end

	if settings.hideInCombat and (self.inCombat or InCombatLockdown()) then
		self:Hold(member)

		return
	end

	self:Deliver(member, settings)
end

---@param unit string
---@return LBLevelUpMember? member
function LevelUp:Check(unit)
	local member = Read(unit)

	if member and self:Observe(member.key, member.level) then
		self:Notify(member)
	end

	return member
end

function LevelUp:Scan()
	if not LB.Roster:InUsableGroup() then
		wipe(self.known)

		return
	end

	local present = {}
	local unresolved = false

	for index = 1, MAX_PARTY do
		local unit = "party" .. index
		local member = self:Check(unit)

		if member then
			present[member.key] = true
		elseif UnitExists(unit) then
			unresolved = true
		end
	end

	if not unresolved then
		self:Forget(present)
	end
end

---@param unit string
function LevelUp:OnUnitLevel(unit)
	if type(unit) ~= "string" or not unit:find("^party%d$") or not LB.Roster:InUsableGroup() then
		return
	end

	self:Check(unit)
end

---@param inCombat boolean
function LevelUp:SetCombat(inCombat)
	self.inCombat = inCombat

	if inCombat or not next(self.held) then
		return
	end

	local settings = LB.Profile:Get("party.levelUp")
	local held = self:TakeHeld()

	if not settings or not settings.enabled then
		return
	end

	for _, member in ipairs(held) do
		self:Deliver(member, settings)
	end
end

function LevelUp:Sample()
	local _, class = UnitClass("player")

	self:Notify({
		key = "sample",
		name = LB:Readable(UnitName("player"), nil) or UNKNOWNOBJECT,
		class = LB:Readable(class, nil),
		level = (LB:Readable(UnitLevel("player"), nil) or 0) + 1,
	})
end
