local LB = select(2, ...)

LB.Source:New("endeavor", {
	perCharacter = true,

	Capability = function()
		return LB.can.endeavor == true
	end,

	IsAvailable = function()
		if not LB.can.endeavor then
			return false
		end

		local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()

		return info ~= nil and info.isLoaded and info.progressRequired > 0
	end,

	Events = function()
		return { "NEIGHBORHOOD_INITIATIVE_UPDATED", "PLAYER_ENTERING_WORLD" }
	end,

	---@param snapshot LBSnapshot
	Read = function(_, snapshot)
		local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()

		if not info or not info.isLoaded then
			return false
		end

		local cur = info.currentProgress or 0
		local max = info.progressRequired or 0
		local complete = max > 0 and cur >= max

		-- A completed endeavor leaves and the rest reflow (Monobrow follow-up, decision 5).
		local changed = snapshot.cur ~= cur or snapshot.max ~= max or snapshot.label ~= info.title

		snapshot.cur = cur
		snapshot.max = complete and 0 or max
		snapshot.label = info.title ~= "" and info.title or HOUSING_DASHBOARD_INITIATIVES
		snapshot.atCap = complete

		return changed
	end,

	Click = function()
		if LB.can.housingDashboard then
			HousingFramesUtil.ToggleHousingDashboard()
		end
	end,
})
