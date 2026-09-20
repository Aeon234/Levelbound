local LB = select(2, ...)

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

		LB.Profile:Initialize()

		C_ChatInfo.RegisterAddonMessagePrefix(LB.MESSAGE_PREFIX)
	elseif event == "PLAYER_LOGIN" then
		self:UnregisterEvent(event)

		LB.Capabilities:Resolve()
		LB.Media:Register()
		LB.BarGroup:Create()
	elseif event == "PLAYER_ENTERING_WORLD" then
		LB.Model:Seed()
	end
end)
