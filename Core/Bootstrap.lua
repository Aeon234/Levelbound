local LB = select(2, ...)

-- Seconds after entering the world before asking the server for anything.
local SETTLE = 1

local frame = CreateFrame("Frame")

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")

frame:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		local addon = ...

		if addon ~= LB.name then
			return
		end

		self:UnregisterEvent(event)

		local ok, err = pcall(LB.Profile.Initialize, LB.Profile)

		if not ok then
			LB.failed = true

			LB:Warn(LB.L["saved settings failed to load, so the bars are off for this session."])
			LB:Warn(tostring(err))

			return
		end

		C_ChatInfo.RegisterAddonMessagePrefix(LB.MESSAGE_PREFIX)
	elseif event == "PLAYER_LOGIN" and not LB.failed then
		self:UnregisterEvent(event)

		LB.Capabilities:Resolve()
		LB.Media:Register()
		LB.BarGroup:Create()
		LB.BlizzardBar:Hide()
		LB.BlizzardWatch:Attach()
		LB.Broker:Create()
		LB.Session:Reset()
		LB.Session:RefreshAFK()
		LB.Roster:Reconcile()
	elseif event == "PLAYER_ENTERING_WORLD" and not LB.failed then
		local isInitialLogin, isReloadingUi = ...

		LB.Model:Seed()
		LB.Roster:Reconcile()
		LB.Visibility:Refresh(false)

		if isInitialLogin or isReloadingUi then
			C_Timer.After(SETTLE, function()
				LB.TimePlayed:RequestOnce()
				LB.Comms:SendRequest()
				LB.StylePicker:Offer()
			end)
		end
	end
end)
