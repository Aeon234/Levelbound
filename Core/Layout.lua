local LB = select(2, ...)

local L = LB.L

---@class LBLayout
local Layout = {
	---@type { value: string, label: string }[]
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

---Returns the height bars draw at: a border style's fixed height while that border is drawn, which it is everywhere
---but along a screen edge; otherwise the bar's own height, or the shared one.
---@param layout LBLayoutSettings
---@param fixed number? the border style's fixed height
---@param own number? a bar's own height in Independent layout
---@return number
function Layout.Height(layout, fixed, own)
	if fixed and not Layout.Fullscreen(layout) then
		return fixed
	end

	return own or layout.height
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
