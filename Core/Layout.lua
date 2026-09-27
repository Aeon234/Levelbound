local LB = select(2, ...)

local L = LB.L

---@class LBLayout
local Layout = {
	---@type LBSettingOption[]
	MODES = {
		{ value = "SEGMENTED", label = L["Segmented"] },
		{ value = "CONNECTED", label = L["Connected"] },
		{ value = "INDEPENDENT", label = L["Independent"] },
	},
}
LB.Layout = Layout

---@param layout LBLayoutSettings
---@return boolean
function Layout.Independent(layout)
	return layout.mode == "INDEPENDENT"
end

---@param layout LBLayoutSettings
---@return "TOP" | "BOTTOM" | nil edge the screen edge the bars span, nil when they do not
function Layout.Fullscreen(layout)
	if Layout.Independent(layout) or layout.fullscreen == "OFF" then
		return nil
	end

	return layout.fullscreen
end

---@param layout LBLayoutSettings
---@return "UP" | "DOWN" growth away from the screen edge in fullscreen
function Layout.Growth(layout)
	local edge = Layout.Fullscreen(layout)

	if edge then
		return edge == "TOP" and "DOWN" or "UP"
	end

	return layout.growth
end
