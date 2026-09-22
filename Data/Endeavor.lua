local LB = select(2, ...)

local SETTLE = 1
local RETRY = 30

---@class LBEndeavorCache
---@field info table? the last loaded `NeighborhoodInitiativeInfo`
---@field asked boolean requested since the last read
---@field emptyAt number? `GetTime()` of the last read that came back unloaded
local Endeavor = {
	asked = false,
}

local function Fetch()
	if not Endeavor.asked and Endeavor.emptyAt and GetTime() - Endeavor.emptyAt < RETRY then
		return
	end

	Endeavor.asked = false

	local info = C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo()

	if info and info.isLoaded then
		Endeavor.info = info
		Endeavor.emptyAt = nil
	else
		Endeavor.emptyAt = GetTime()
	end
end

local function Request()
	if Endeavor.info or Endeavor.asked then
		return
	end

	Endeavor.asked = true
	C_NeighborhoodInitiative.RequestNeighborhoodInitiativeInfo()
end

LB.Source:New("endeavor", {
	Capability = function()
		return LB.can.endeavor == true
	end,

	IsAvailable = function()
		if not LB.can.endeavor then
			return false
		end

		local info = Endeavor.info

		return info ~= nil and info.progressRequired > 0
	end,

	Events = function()
		return { "NEIGHBORHOOD_INITIATIVE_UPDATED", "PLAYER_ENTERING_WORLD" }
	end,

	---@param event string
	OnEvent = function(self, event)
		if event == "NEIGHBORHOOD_INITIATIVE_UPDATED" then
			Fetch()

			return self:Refresh()
		end

		Endeavor.asked = false
		LB.Events:Merge("endeavor:request", SETTLE, Request)

		return false
	end,

	---@param snapshot LBSnapshot
	Read = function(_, snapshot)
		local info = Endeavor.info

		if not info then
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
