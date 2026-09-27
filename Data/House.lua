local LB = select(2, ...)

---@class LBHouseFavor
---@field favor table? the last `HouseLevelFavor` for the tracked house
---@field asked string? the house asked about since the last loading screen
local House = {}

---@return string? guid the tracked house, or nil when there is none or it cannot be read
local function TrackedGuid()
	return LB:Readable(C_Housing.GetTrackedHouseGuid(), nil)
end

---@param guid string?
local function Ask(guid)
	if not guid or House.asked == guid then
		return
	end

	House.asked = guid
	C_Housing.GetCurrentHouseLevelFavor(guid)
end

LB.Source:New("house", {
	label = LB.L["Housing Exp"],
	shortLabel = LB.L["House Exp"],
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

	---@param event string
	OnEvent = function(self, event, ...)
		if event == "HOUSE_LEVEL_FAVOR_UPDATED" then
			local favor = ...

			if favor and LB:Readable(favor.houseGUID, nil) == TrackedGuid() then
				House.favor = favor
			end
		else
			if event == "PLAYER_ENTERING_WORLD" or event == "TRACKED_HOUSE_CHANGED" then
				House.asked = nil
			end

			if event == "TRACKED_HOUSE_CHANGED" then
				House.favor = nil
			end
		end

		return self:Refresh()
	end,

	---@param snapshot LBSnapshot
	Read = function(_, snapshot)
		local guid = TrackedGuid()
		local favor = House.favor

		if not guid then
			return false
		end

		if not favor or LB:Readable(favor.houseGUID, nil) ~= guid then
			Ask(guid)

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
		snapshot.label = LB.L["Housing Exp"]
		snapshot.flags.readyToUpgrade = ready
		snapshot.atCap = ready

		return changed
	end,

	ClickHint = function()
		return LB.can.housingDashboard and LB.L["Click to Open the Housing Dashboard"] or nil
	end,
	Click = function()
		if LB.can.housingDashboard then
			HousingFramesUtil.ToggleHousingDashboard()
		end
	end,
})
