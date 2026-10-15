local LB = select(2, ...)

local L = LB.L
local Settings = LB.Settings

---@param window table
function Settings:DeclareGeneral(window)
	local page = window:Page("general", {
		title = GENERAL,
		description = L["The minimap button, bar tooltips and clicks, and time tracking."],
	})

	local access = page:Section("access", L["Access"])

	access:Checkbox({
		id = "minimapButton",
		label = L["Show Minimap Button"],
		tooltip = self:Tooltip("general", "minimapButton"),
		default = true,
		wide = true,
		get = function()
			return LB.Profile:Global().minimapButton.hide ~= true
		end,
		set = function(value)
			LB.Profile:Global().minimapButton.hide = not value
			LB.Callbacks:Fire("Settings", "minimapButton", value)
		end,
	})

	local interaction = page:Section("interaction", L["Bar Interaction"])

	self:Checkbox(interaction, "general", "tooltip", L["Show Tooltip"], "tooltip.enabled")
	self:Checkbox(interaction, "general", "clickActions", L["Click to Open or Share"], "tooltip.clickActions")

	local time = page:Section("time", L["Time Tracking"])

	time:Checkbox({
		id = "requestTimePlayed",
		label = L["Request Time Played at Login"],
		tooltip = self:Tooltip("general", "requestTimePlayed"),
		default = true,
		get = function()
			return LB.Profile:Global().requestTimePlayed == true
		end,
		set = function(value)
			LB.Profile:Global().requestTimePlayed = value
		end,
	})
	time:Button({
		id = "resetSession",
		label = L["Reset Session"],
		tooltip = self:Tooltip("general", "resetSession", L["This character only."]),
		verb = L["Reset"],
		run = function(setting)
			LB.Session:Reset()
			setting.window:ShowStatus(L["Session reset."])
		end,
	})
end
