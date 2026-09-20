local LB = select(2, ...)

---@class LBCapabilities
---@field resolved boolean
local Capabilities = {
	resolved = false,
}
LB.Capabilities = Capabilities

---@class LBCapabilityFlags
---@field petXP boolean Forever's pet experience bar
---@field house boolean housing favor data
---@field housingDashboard boolean the housing dashboard click action
---@field endeavor boolean neighborhood initiative data
---@field travelers boolean Trading Post traveler points data
---@field azerite boolean Azerite item data
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
	can.house = C_Housing ~= nil and C_Housing.GetTrackedHouseGuid ~= nil
	can.housingDashboard = HousingFramesUtil ~= nil and HousingFramesUtil.ToggleHousingDashboard ~= nil
	can.endeavor = C_NeighborhoodInitiative ~= nil and C_NeighborhoodInitiative.GetNeighborhoodInitiativeInfo ~= nil
	can.travelers = C_PerksActivities ~= nil and C_PerksActivities.GetPerksActivitiesInfo ~= nil
	can.azerite = C_AzeriteItem ~= nil and C_AzeriteItem.FindActiveAzeriteItem ~= nil
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
