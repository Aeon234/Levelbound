local LB = select(2, ...)

local lib = LibStub("LibAeonSettings-1.0")

local ADDON_NAME = ...
local FRAME_NAME = "LevelboundSettings"

-- Page ids that older callers and `/lb <page>` use.
local ALIASES = {
	types = "type.xp",
	party = "markers",
	levelup = "levelups",
}

---The settings window, built on LibAeonSettings. Pages are declared the first time the window is asked for, once
---capabilities and saved data are ready.
---@class LBSettings
---@field window table?
local Settings = {}
LB.Settings = Settings

---@return table window the library's settings window, registered and declared on first use
function Settings:Window()
	if self.window then
		return self.window
	end

	local window = lib:Settings(ADDON_NAME, {
		title = LB.title,
		version = LB.version,
		frameName = FRAME_NAME,
		store = function()
			return LB.Profile.active
		end,
		write = function(path, value)
			LB.Profile:Set(path, value)
		end,
		account = function()
			return LB.Profile:Global()
		end,
	})

	self.window = window
	self:DeclareGeneral(window)

	return window
end

---@return boolean
function Settings:IsOpen()
	return self.window ~= nil and self.window:IsShown()
end

---Redraws the shown page, for changes made outside the window.
function Settings:Refresh()
	if self:IsOpen() then
		self.window:Refresh()
	end
end

---@param page string? a page id, an alias for one or a progress type id; the last page shown when nil or unknown
function Settings:Open(page)
	local window = self:Window()

	if page and not ALIASES[page] and LB.Model:Source(page) then
		page = "type." .. page
	end

	page = page and (ALIASES[page] or page)

	if page and window.pages[page] then
		window:SelectPage(page)
	end

	window:Open()
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

-- Declaration helpers --------------------------------------------------------------------------------------------

---@param path string
---@return any value the profile default at `path`, copied when it is a table
function Settings:Default(path)
	local node = LB.Profile:Defaults()

	for key in path:gmatch("[^.]+") do
		if type(node) ~= "table" then
			return nil
		end

		node = node[key]
	end

	return type(node) == "table" and LB:CopyTable(node) or node
end

---@param key string the descriptions' page key in `LB.SettingsDescriptions`
---@param id string the setting's id
---@param note string? a scope or per-slot note that follows the description
---@return string? tooltip
function Settings:Tooltip(key, id, note)
	local descriptions = LB.SettingsDescriptions
	local base = (descriptions[key] or {})[id]

	if type(base) == "function" then
		base = base()
	end

	if not base then
		for _, prefix in ipairs(descriptions.prefixes) do
			if id:sub(1, #prefix[1]) == prefix[1] then
				base = prefix[2]
			end
		end
	end

	if base and note then
		return base .. " " .. note
	end

	return base or note
end

---Declares a checkbox bound to a profile path, with its default and tooltip.
---@param section table
---@param key string the descriptions' page key
---@param id string
---@param label string
---@param path string
---@param fields table? further setting fields, which take precedence
---@return table? setting
function Settings:Checkbox(section, key, id, label, path, fields)
	local info = { id = id, label = label, path = path, default = self:Default(path), tooltip = self:Tooltip(key, id) }

	for field, value in pairs(fields or {}) do
		info[field] = value
	end

	return section:Checkbox(info)
end
