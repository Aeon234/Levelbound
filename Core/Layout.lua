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

---Returns a border style's fixed height while that border is drawn, which it is everywhere but along a screen edge.
---@param layout LBLayoutSettings
---@param fixed number? the border style's fixed height
---@return number? height nil when the bars take their own height
function Layout.HeldHeight(layout, fixed)
	if fixed and not Layout.Fullscreen(layout) then
		return fixed
	end

	return nil
end

---Returns the height bars draw at: the border's held height, otherwise the bar's own height, or the shared one.
---@param layout LBLayoutSettings
---@param fixed number? the border style's fixed height
---@param own number? a bar's own height in Independent layout
---@return number
function Layout.Height(layout, fixed, own)
	return Layout.HeldHeight(layout, fixed) or own or layout.height
end

---Stacks `count` bars of one height, `spacing` apart, the first at the top when growing down and at the bottom when
---growing up.
---@param count integer
---@param height number
---@param spacing number between one bar's bottom and the next one's top
---@param growth "UP" | "DOWN"
---@return number[] tops each bar's top, down from the stack's top
---@return number total the stack's height
function Layout.Stack(count, height, spacing, growth)
	local step = height + spacing
	local total = count > 0 and height * count + spacing * (count - 1) or 0
	local tops = {}

	for index = 1, count do
		tops[index] = growth == "UP" and (total - height - (index - 1) * step) or ((index - 1) * step)
	end

	return tops, total
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
