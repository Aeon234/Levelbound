local LB = select(2, ...)

local L = LB.L
local AS = LB.AeonSettings

local FRAME_NAME = "LevelboundSettings"

-- Page ids that older callers and `/lb <page>` use.
local ALIASES = {
	types = "type.xp",
	party = "markers",
	levelup = "levelups",
	appearance = "layout",
	text = "layout",
	visibility = "layout",
}

---The settings window, built on the AeonSettings library.
---@class LBSettings
---@field window table?
local Settings = {}
LB.Settings = Settings

function Settings:Create()
	if self.window then
		return
	end

	local window = AS:CreateWindow({
		name = FRAME_NAME,
		title = LB.title,
		version = LB.version,
		onEditMode = function()
			self:OnEditMode()
		end,
		contentWidth = 900,
	})

	window:SetCategories(LB.SettingsPages:Categories())
	window:HookScript("OnShow", function()
		LB.EditMode:OnSettingsShown()

		if LB.EditMode:IsActive() then
			window:ShowStatus(L["Editing the layout. Changes are not saved yet."])
		end
	end)
	window:HookScript("OnHide", function()
		if LB.EditMode:IsActive() then
			LB.EditMode:OnSettingsHidden()
		end
	end)

	self.window = window
end

---Starts edit mode from the window; during a session, returns to it.
function Settings:OnEditMode()
	if LB.EditMode:IsActive() then
		self:Close()

		return
	end

	LB.EditMode:Enter(true)
end

---@return boolean
function Settings:IsOpen()
	return self.window ~= nil and self.window:IsShown()
end

---Rebuilds the shown page, for changes made outside the window.
function Settings:Refresh()
	if self:IsOpen() then
		self.window:RefreshPage()
	end
end

---@param page string? a page id, or an alias for one
function Settings:Open(page)
	self:Create()

	if page and not ALIASES[page] and LB.Model:Source(page) then
		page = "type." .. page
	end

	self.window:Open(page and (ALIASES[page] or page) or nil)
end

function Settings:Close()
	if self.window then
		self.window:Close()
	end
end

function Settings:Toggle()
	if self:IsOpen() then
		self:Close()

		return
	end

	self:Open()
end
