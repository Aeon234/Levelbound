local LB = select(2, ...)

---@alias LBVerticalLock "TOP" | "BOTTOM"

---@class LBPlacement
local Placement = {}
LB.Placement = Placement

---@param point string
---@return string horizontal "LEFT", "RIGHT" or ""
---@return string vertical "TOP", "BOTTOM" or ""
local function Split(point)
	local vertical = point:match("^TOP") or point:match("^BOTTOM") or ""
	local horizontal = point:match("LEFT$") or point:match("RIGHT$") or ""

	return horizontal, vertical
end

---@param horizontal string
---@param vertical string
---@return FramePoint
local function Join(horizontal, vertical)
	local point = vertical .. horizontal

	if point == "" then
		return "CENTER"
	end

	return point
end

---@param value number
---@param pixel number
---@return number value moved onto the nearest physical pixel boundary
function Placement:ToPixel(value, pixel)
	if pixel <= 0 then
		return value
	end

	return math.floor(value / pixel + 0.5) * pixel
end

---@param value number
---@return number
local function Trim(value)
	return math.floor(value * 1000 + 0.5) / 1000
end

---@param position LBFramePosition
---@param width number
---@param height number
---@param screenWidth number
---@param screenHeight number
---@return number left
---@return number bottom
function Placement:Resolve(position, width, height, screenWidth, screenHeight)
	local horizontal, vertical = Split(position.point)
	local left, bottom

	if horizontal == "LEFT" then
		left = position.x
	elseif horizontal == "RIGHT" then
		left = screenWidth + position.x - width
	else
		left = screenWidth / 2 + position.x - width / 2
	end

	if vertical == "BOTTOM" then
		bottom = position.y
	elseif vertical == "TOP" then
		bottom = screenHeight + position.y - height
	else
		bottom = screenHeight / 2 + position.y - height / 2
	end

	return left, bottom
end

---@param left number
---@param bottom number
---@param width number
---@param height number
---@param screenWidth number
---@param screenHeight number
---@param lock LBVerticalLock? forces the vertical anchor, as a connected stack needs
---@return LBFramePosition
function Placement:Anchor(left, bottom, width, height, screenWidth, screenHeight, lock)
	local centerX = left + width / 2
	local centerY = bottom + height / 2
	local horizontal, vertical, x, y

	if centerX < screenWidth / 3 then
		horizontal, x = "LEFT", left
	elseif centerX > screenWidth * 2 / 3 then
		horizontal, x = "RIGHT", left + width - screenWidth
	else
		horizontal, x = "", centerX - screenWidth / 2
	end

	if not lock then
		if centerY < screenHeight / 3 then
			lock = "BOTTOM"
		elseif centerY > screenHeight * 2 / 3 then
			lock = "TOP"
		end
	end

	if lock == "BOTTOM" then
		vertical, y = "BOTTOM", bottom
	elseif lock == "TOP" then
		vertical, y = "TOP", bottom + height - screenHeight
	else
		vertical, y = "", centerY - screenHeight / 2
	end

	return { point = Join(horizontal, vertical), x = Trim(x), y = Trim(y) }
end

---@param growth "UP" | "DOWN"
---@return LBVerticalLock lock the stack's anchor sits at the end the experience bar is on
function Placement:StackLock(growth)
	return growth == "DOWN" and "TOP" or "BOTTOM"
end

---Places a connected stack so its lead bar sits at `leadBottom`, whichever way the stack grows.
---@param left number
---@param leadBottom number bottom edge of the lead bar
---@param width number
---@param barHeight number
---@param total number height of the whole stack
---@param growth "UP" | "DOWN"
---@param screenWidth number
---@param screenHeight number
---@return LBFramePosition
function Placement:Stack(left, leadBottom, width, barHeight, total, growth, screenWidth, screenHeight)
	local bottom = growth == "DOWN" and (leadBottom + barHeight - total) or leadBottom

	return self:Anchor(left, bottom, width, total, screenWidth, screenHeight, self:StackLock(growth))
end
