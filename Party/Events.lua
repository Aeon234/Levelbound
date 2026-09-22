local LB = select(2, ...)

local Comms = LB.Comms
local Roster = LB.Roster

LB.Events:Register("CHAT_MSG_ADDON", Comms, function(owner, _, prefix, text, channel, sender)
	owner:OnMessage(prefix, text, channel, sender)
end)

LB.Events:Register("GROUP_ROSTER_UPDATE", Roster, function(owner)
	local inGroup = owner:InUsableGroup()

	owner:Reconcile()

	if inGroup and not owner.wasGrouped then
		Comms:SendRequest()
		Comms:Send(true)
	end

	owner.wasGrouped = inGroup
end)

LB.Events:Register("PLAYER_ENTERING_WORLD", Comms, function(owner, _, isInitialLogin, isReloadingUi)
	if isInitialLogin or isReloadingUi then
		return
	end

	LB.Events:Merge("party:zoned", 3, function()
		owner:SendRequest()
		owner:Send(true)
	end)
end)

LB.Events:Register("UNIT_CONNECTION", Roster, function(owner)
	owner:Reconcile()
end)

LB.Events:Register("ADDON_RESTRICTION_STATE_CHANGED", Comms, function(owner, _, restrictionType, active)
	if restrictionType == Enum.AddOnRestrictionType.Chat then
		owner:OnRestrictionChanged(active == true)
	end
end)

LB.Callbacks:Register("Progress", Comms, function(owner, id)
	if id == "xp" then
		owner:Send()
	end
end)
