local LB = select(2, ...)

LB.Source:New("petxp", {
	label = LB.L["Pet Experience"],
	shortLabel = LB.L["Pet Exp"],
	Capability = function()
		return LB.can.petXP == true
	end,

	IsAvailable = function()
		return LB.can.petXP == true and UnitExists("pet")
	end,

	Events = function()
		return { "UNIT_PET_EXPERIENCE", "UNIT_PET", "PLAYER_ENTERING_WORLD" }
	end,

	---@param snapshot LBSnapshot
	Read = function(_, snapshot)
		if not GetPetExperience then
			return false
		end

		local cur, max = GetPetExperience()

		cur = LB:Readable(cur, nil)
		max = LB:Readable(max, nil)

		if not cur or not max then
			return false
		end

		local level = LB:Readable(UnitLevel("pet"), nil) or 0
		local changed = snapshot.cur ~= cur or snapshot.max ~= max or snapshot.level ~= level

		snapshot.cur = cur
		snapshot.max = max
		snapshot.level = level
		snapshot.label = LB:Readable(UnitName("pet"), nil)

		return changed
	end,
})
