local LB = select(2, ...)

local L = LB.L
local Settings = LB.Settings

---@param window table
function Settings:DeclareGeneral(window)
	local page = window:Page("general", {
		title = GENERAL,
		icon = LB.Media.sidebar.general,
		iconTint = true,
	})

	local minimap = page:Section("minimap", MINIMAP_LABEL)

	minimap:Checkbox({
		id = "minimapButton",
		label = L["Show Minimap Button"],
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

	self:Add(interaction, "Checkbox", "general", { id = "tooltip", label = L["Show Tooltip"], path = "tooltip.enabled" })
	self:Add(interaction, "Checkbox", "general", {
		id = "clickActions",
		label = L["Click to Open or Share"],
		path = "tooltip.clickActions",
	})

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
