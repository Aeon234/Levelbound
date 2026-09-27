local LB = select(2, ...)

local ALLIANCE = { 0.0, 0.26, 0.68 }
local HORDE = { 0.77, 0.12, 0.23 }

LB.Source:New("honor", {
	label = HONOR,
	shortLabel = HONOR,
	Capability = function()
		return LB.can.honor == true
	end,

	IsAvailable = function()
		if not LB.can.honor then
			return false
		end

		return IsWatchingHonorAsXP() or C_PvP.IsActiveBattlefield() or (IsInActiveWorldPVP and IsInActiveWorldPVP())
	end,

	Events = function()
		return {
			"HONOR_XP_UPDATE",
			"HONOR_LEVEL_UPDATE",
			"ZONE_CHANGED",
			"ZONE_CHANGED_NEW_AREA",
			"PLAYER_ENTERING_WORLD",
		}
	end,

	---@param snapshot LBSnapshot
	Read = function(_, snapshot)
		local cur = LB:Readable(UnitHonor("player"), nil)
		local max = LB:Readable(UnitHonorMax("player"), nil)

		if not cur or not max then
			return false
		end

		local level = LB:Readable(UnitHonorLevel("player"), nil)
		local changed = snapshot.cur ~= cur or snapshot.max ~= max or snapshot.level ~= level

		snapshot.cur = cur
		snapshot.max = max
		snapshot.level = level
		snapshot.color = UnitFactionGroup("player") == "Horde" and HORDE or ALLIANCE

		return changed
	end,

	ClickHint = function()
		return LB.can.pvpWindow and LB.L["Click to Open the PvP Window"] or nil
	end,
	Click = function()
		if LB.can.pvpWindow then
			TogglePVPUI()
		end
	end,
})
