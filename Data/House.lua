local LB = select(2, ...)

LB.Source:New("house", {
	Capability = function()
		return LB.can.house == true
	end,

	IsAvailable = function()
		return LB.can.house == true and C_Housing.GetTrackedHouseGuid() ~= nil
	end,

	Events = function()
		return {
			"HOUSE_LEVEL_FAVOR_UPDATED",
			"PLAYER_HOUSE_LIST_UPDATED",
			"TRACKED_HOUSE_CHANGED",
			"PLAYER_ENTERING_WORLD",
		}
	end,

	---@param snapshot LBSnapshot
	Read = function(_, snapshot)
		local guid = C_Housing.GetTrackedHouseGuid()

		if not guid then
			return false
		end

		local favor = C_Housing.GetCurrentHouseLevelFavor(guid)

		if not favor then
			return false
		end

		local level = favor.houseLevel
		local minimum = C_Housing.GetHouseLevelFavorForLevel(level) or 0
		local maximum = C_Housing.GetHouseLevelFavorForLevel(level + 1) or 0
		local cur = math.max((favor.houseFavor or 0) - minimum, 0)
		local max = math.max(maximum - minimum, 0)
		local ready = max <= 0 or cur >= max

		if max <= 0 then
			cur, max = 1, 1
		end

		local changed = snapshot.cur ~= cur
			or snapshot.max ~= max
			or snapshot.level ~= level
			or snapshot.flags.readyToUpgrade ~= ready

		snapshot.cur = cur
		snapshot.max = max
		snapshot.level = level
		snapshot.label = LB.L["House favor"]
		snapshot.flags.readyToUpgrade = ready
		snapshot.atCap = ready

		return changed
	end,

	Click = function()
		if LB.can.housingDashboard then
			HousingFramesUtil.ToggleHousingDashboard()
		end
	end,
})
