local LB = select(2, ...)

local L = LB.L

---The Profiles page: the settings library's profiles page over `LB.Profile`. Profile actions empty the window's
---Undo history and read every value again; the bars follow the swap through the profile's own "Settings" callback,
---and edit mode's targets are placed again.
---@class LBSettingsProfiles
local Profiles = {}
LB.SettingsProfiles = Profiles

---@param change fun(...)
---@return fun(...) change that places edit mode's targets again afterwards
local function Placed(change)
	return function(...)
		change(...)
		LB.EditTargets:Apply()
	end
end

local adapter = {
	List = function()
		return LB.Profile:List()
	end,
	Active = function()
		return LB.Profile.activeName
	end,
	Switch = Placed(function(name)
		LB.Profile:Activate(name)
	end),
	New = Placed(function(name)
		LB.Profile:New(name)
	end),
	Copy = Placed(function(name)
		LB.Profile:Copy(LB.Profile.activeName, name)
	end),
	Rename = Placed(function(name)
		LB.Profile:Rename(LB.Profile.activeName, name)
	end),
	Delete = Placed(function(name, replacement)
		LB.Profile:Delete(name, replacement)
	end),
	Reset = Placed(function()
		LB.Profile:Reset()
	end),
	Export = function()
		return LB.Profile:Export(LB.Profile.activeName) or ""
	end,
	Decode = function(text)
		local payload, reason = LB.Profile:Decode(text)

		if not payload then
			return nil, reason
		end

		payload.summary = L['Levelbound profile "%s", format %d.']:format(payload.name, payload.version)

		return payload
	end,
	Import = Placed(function(payload, name)
		LB.Profile:Import(payload, name)
	end),
	UsesCharacterProfile = function()
		return LB.Profile.char.useCharacterProfile == true
	end,
	SetUseCharacterProfile = Placed(function(on)
		LB.Profile:SetUseCharacterProfile(on)
	end),
}

---Declares the Profiles page below a divider, as the sidebar's last entry.
---@param window table
function Profiles:Declare(window)
	window:Divider()
	window:ProfilesPage("profiles", {
		title = L["Profiles"],
		icon = LB.Media.sidebar.profiles,
		adapter = adapter,
	})
end
