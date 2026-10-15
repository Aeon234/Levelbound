local LB = select(2, ...)

local L = LB.L
local AS = LB.AeonSettings

---The Profiles page: the settings library's profiles page over `LB.Profile`.
---@class LBSettingsProfiles
---@field page table?
local Profiles = {}
LB.SettingsProfiles = Profiles

local adapter = {
	builtin = "Default",
	List = function()
		return LB.Profile:List()
	end,
	Active = function()
		return LB.Profile.activeName
	end,
	Switch = function(name)
		LB.Profile:Activate(name)
	end,
	New = function(name)
		LB.Profile:New(name)
	end,
	Copy = function(name)
		LB.Profile:Copy(LB.Profile.activeName, name)
	end,
	Rename = function(name)
		LB.Profile:Rename(LB.Profile.activeName, name)
	end,
	Delete = function(name, replacement)
		LB.Profile:Delete(name, replacement)
	end,
	Reset = function()
		LB.Profile:Reset()
	end,
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
	Import = function(payload, name)
		LB.Profile:Import(payload, name)
	end,
	IsEditing = function()
		return LB.EditMode:IsActive()
	end,
	UsesCharacterProfile = function()
		return LB.Profile.char.useCharacterProfile == true
	end,
	SetUseCharacterProfile = function(on)
		LB.Profile:SetUseCharacterProfile(on)
	end,
}

---@return table page
function Profiles:Page()
	if not self.page then
		self.page = AS:CreateProfilesPage({ id = "profiles", title = L["Profiles"], adapter = adapter })
		self.page.description = L["Per-character or shared settings, with copy, export and import."]
	end

	return self.page
end

---The Profiles page on LibAeonSettings, over the same adapter. Profile actions empty the window's Undo history and
---read every value again; the bars follow the swap through the profile's own "Settings" callback, and edit mode's
---targets are placed again.
---@param window table
function Profiles:Declare(window)
	-- Edit mode's own state locks the page, and every action that changes the profile places the frames again.
	local SKIP = { builtin = true, IsEditing = true }
	local REPLACES = { Switch = true, New = true, Copy = true, Rename = true, Delete = true, Reset = true,
		Import = true, SetUseCharacterProfile = true }
	local shared = {}

	for name, fn in pairs(adapter) do
		if REPLACES[name] then
			shared[name] = function(...)
				fn(...)
				LB.EditTargets:Apply()
			end
		elseif not SKIP[name] then
			shared[name] = fn
		end
	end

	window:ProfilesPage("profiles", {
		title = L["Profiles"],
		description = L["Per-character or shared settings, with copy, export and import."],
		adapter = shared,
	})
end
