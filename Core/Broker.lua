local LB = select(2, ...)

local L = LB.L

---@class LBBroker
---@field icon table?
local Broker = {}
LB.Broker = Broker

local function OnClick(_, button)
	if button == "RightButton" then
		LB.EditMode:Toggle()

		return
	end

	if LB.Settings:IsOpen() then
		LB.Settings:Close()
	else
		LB:OpenSettings()
	end
end

---@param tooltip GameTooltip
local function OnTooltipShow(tooltip)
	tooltip:AddLine(LB.title)
	tooltip:AddLine(L["Left-click: open settings"], 1, 1, 1)
	tooltip:AddLine(L["Right-click: open edit mode"], 1, 1, 1)
end

function Broker:Create()
	if self.icon then
		return
	end

	local broker = LibStub("LibDataBroker-1.1", true)
	local icon = LibStub("LibDBIcon-1.0", true)

	if not broker or not icon then
		return
	end

	local launcher = broker:NewDataObject(LB.name, {
		type = "launcher",
		icon = LB.Media.textures.logo,
		OnClick = OnClick,
		OnTooltipShow = OnTooltipShow,
	})

	if not launcher then
		return
	end

	icon:Register(LB.name, launcher, LB.Profile:Global().minimapButton)

	if LB.can.compartment then
		icon:AddButtonToCompartment(LB.name)
	end

	self.icon = icon
end

function Broker:Refresh()
	local icon = self.icon

	if not icon then
		return
	end

	if LB.Profile:Global().minimapButton.hide then
		icon:Hide(LB.name)
	else
		icon:Show(LB.name)
	end
end

LB.Callbacks:Register("Settings", Broker, function(_, path)
	if path == "minimapButton" then
		Broker:Refresh()
	end
end)
