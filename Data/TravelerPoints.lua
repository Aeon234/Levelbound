local LB = select(2, ...)

---@return number earned
---@return number maximum
local function Progress()
	local info = C_PerksActivities.GetPerksActivitiesInfo()

	if not info then
		return 0, 0
	end

	local maximum = 0

	for _, threshold in pairs(info.thresholds) do
		if threshold.requiredContributionAmount > maximum then
			maximum = threshold.requiredContributionAmount
		end
	end

	if maximum == 0 then
		return 0, 0
	end

	local earned = 0

	for _, activity in pairs(info.activities) do
		if activity.completed then
			earned = earned + (activity.thresholdContributionAmount or 0)
		end
	end

	return math.min(earned, maximum), maximum
end

LB.Source:New("travelers", {
	perCharacter = true,

	IsAvailable = function()
		if not LB.can.travelers then
			return false
		end

		local _, maximum = Progress()

		return maximum > 0
	end,

	Events = function()
		return { "PERKS_ACTIVITIES_UPDATED", "PLAYER_ENTERING_WORLD" }
	end,

	---@param snapshot LBSnapshot
	Read = function(_, snapshot)
		local cur, max = Progress()
		local complete = max > 0 and cur >= max

		local changed = snapshot.cur ~= cur or snapshot.max ~= max

		snapshot.cur = cur
		snapshot.max = complete and 0 or max
		snapshot.label = MONTHLY_ACTIVITIES_POINTS
		snapshot.atCap = complete

		return changed
	end,

	Click = function()
		if LB.can.encounterJournal then
			ToggleEncounterJournal()
		end
	end,
})
