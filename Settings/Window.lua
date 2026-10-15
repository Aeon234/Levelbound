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
	self:DeclareBars(window)
	self:DeclareTypes(window)
	self:DeclareParty(window)

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
---@return (string | fun(): string)? tooltip
function Settings:Tooltip(key, id, note)
	local descriptions = LB.SettingsDescriptions
	local base = (descriptions[key] or {})[id]

	-- A description built on each hover stays a function, which the library calls then.
	if type(base) == "function" then
		if not note then
			return base
		end

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

---Declares a setting of a library control kind (`"Checkbox"`, `"Slider"`, `"Dropdown"` ...). A setting bound by
---`path` gets the profile default; the tooltip is the description under `key`, followed by `note`. Dropdown
---choices are already localized and keep their case.
---@param section table
---@param kind string
---@param key string the descriptions' page key
---@param info table the setting's fields
---@param note string?
---@return table? setting
function Settings:Add(section, kind, key, info, note)
	if info.path and info.default == nil then
		info.default = self:Default(info.path)
	end

	if info.tooltip == nil then
		info.tooltip = self:Tooltip(key, info.id, note)
	end

	if kind == "Dropdown" and info.titleCase == nil then
		info.titleCase = false
	end

	return section[kind](section, info)
end

---@param options { value: any, label: string }[] | fun(): { value: any, label: string }[]
---@return fun(): { value: any, text: string }[] choices a dropdown's `options`
function Settings:Choices(options)
	return function()
		local list = type(options) == "function" and options() or options
		local choices = {}

		for index, option in ipairs(list) do
			choices[index] = { value = option.value, text = option.label }
		end

		return choices
	end
end

---A 0 to 1 profile value shown as a percentage, for a slider's `get` and `set`.
---@param path string
---@return fun(): number get
---@return fun(value: number) set
function Settings:Percent(path)
	return function()
		return math.floor((LB.Profile:Get(path) or 0) * 100 + 0.5)
	end, function(value)
		LB.Profile:Set(path, value / 100)
	end
end

---A profile color stored as `{ r, g, b, a? }`, for a swatch's `get` and `set`. With `opacity`, the swatch edits
---the alpha too; without, a stored alpha is kept.
---@param path string
---@param opacity boolean?
---@return fun(): table? get
---@return fun(value: table) set
function Settings:ColorAccess(path, opacity)
	return function()
		local color = LB.Profile:Get(path)

		return color and { r = color[1], g = color[2], b = color[3], a = color[4] }
	end, function(value)
		local old = LB.Profile:Get(path) or {}

		LB.Profile:Set(path, { value.r, value.g, value.b, opacity and (value.a or 1) or old[4] })
	end
end
