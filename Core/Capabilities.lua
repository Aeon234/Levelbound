local LB = select(2, ...)

---@class LBCapabilities
---@field resolved boolean
local Capabilities = {
	resolved = false,
}
LB.Capabilities = Capabilities

---@class LBCapabilityFlags
---@field petXP boolean Forever's pet experience bar
---@field house boolean housing favor, on a client with the housing dashboard
---@field housingDashboard boolean the housing dashboard click action
---@field endeavor boolean neighborhood initiative, on a client with the housing dashboard
---@field travelers boolean Trading Post traveler points, on a client with the Encounter Journal that shows them
---@field honor boolean honor data and Blizzard's watch rule
---@field pvpWindow boolean the PvP window click action
---@field encounterJournal boolean the renown Journey click action
---@field characterPanel boolean the character and reputation panel click action
---@field renownRewards boolean renown reward tooltip lines
---@field compartment boolean the addon compartment entry point
---@field statusTrackingBar boolean Blizzard's status tracking bar, which the addon can hide
LB.can = {}

---@return LBCapabilityFlags
function Capabilities:Resolve()
	local can = LB.can

	can.petXP = GetPetExperience ~= nil
	can.housingDashboard = HousingFramesUtil ~= nil and HousingFramesUtil.ToggleHousingDashboard ~= nil
	can.house = can.housingDashboard and C_Housing ~= nil and C_Housing.GetTrackedHouseGuid ~= nil
	can.endeavor = can.housingDashboard
		and C_NeighborhoodInitiative ~= nil
		and C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo ~= nil
	can.travelers = ToggleEncounterJournal ~= nil
		and C_PerksActivities ~= nil
		and C_PerksActivities.GetPerksActivitiesInfo ~= nil
	can.honor = UnitHonor ~= nil and IsWatchingHonorAsXP ~= nil
	can.pvpWindow = TogglePVPUI ~= nil
	can.encounterJournal = ToggleEncounterJournal ~= nil
	can.characterPanel = ToggleCharacter ~= nil
	can.renownRewards = RenownRewardUtil ~= nil and RenownRewardUtil.AddRenownRewardsToTooltip ~= nil
	can.compartment = AddonCompartmentFrame ~= nil
	can.statusTrackingBar = StatusTrackingBarManager ~= nil

	self.resolved = true

	return can
end
