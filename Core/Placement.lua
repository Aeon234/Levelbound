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
---@return number
function Placement:Round(value)
	return math.floor(value + 0.5)
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
	local centreX = left + width / 2
	local centreY = bottom + height / 2
	local horizontal, vertical, x, y

	if centreX < screenWidth / 3 then
		horizontal, x = "LEFT", left
	elseif centreX > screenWidth * 2 / 3 then
		horizontal, x = "RIGHT", left + width - screenWidth
	else
		horizontal, x = "", centreX - screenWidth / 2
	end

	if not lock then
		if centreY < screenHeight / 3 then
			lock = "BOTTOM"
		elseif centreY > screenHeight * 2 / 3 then
			lock = "TOP"
		end
	end

	if lock == "BOTTOM" then
		vertical, y = "BOTTOM", bottom
	elseif lock == "TOP" then
		vertical, y = "TOP", bottom + height - screenHeight
	else
		vertical, y = "", centreY - screenHeight / 2
	end

	return { point = Join(horizontal, vertical), x = Trim(x), y = Trim(y) }
end

---@param left number
---@param bottom number
---@param width number
---@param height number
---@param screenWidth number
---@param screenHeight number
---@return number x offset of the rectangle's center from the screen's center
---@return number y
function Placement:Centre(left, bottom, width, height, screenWidth, screenHeight)
	return self:Round(left + width / 2 - screenWidth / 2), self:Round(bottom + height / 2 - screenHeight / 2)
end

---@param x number offset of the center from the screen's center
---@param y number
---@param width number
---@param height number
---@param screenWidth number
---@param screenHeight number
---@return number left
---@return number bottom
function Placement:FromCentre(x, y, width, height, screenWidth, screenHeight)
	return screenWidth / 2 + x - width / 2, screenHeight / 2 + y - height / 2
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

---@param left number
---@param bottom number
---@param width number
---@param height number
---@param otherLeft number
---@param otherBottom number
---@param otherWidth number
---@param otherHeight number
---@return boolean overlaps the two rectangles share some area; touching edges do not count
function Placement:Overlaps(left, bottom, width, height, otherLeft, otherBottom, otherWidth, otherHeight)
	return left < otherLeft + otherWidth
		and otherLeft < left + width
		and bottom < otherBottom + otherHeight
		and otherBottom < bottom + height
end

---@class LBSnapLines
---@field x number[]
---@field y number[]

---@param start number
---@param size number
---@param lines number[]
---@param threshold number
---@return number shift
---@return number? line the line snapped to, or nil when none was close enough
local function Nearest(start, size, lines, threshold)
	local best, bestLine = nil, nil

	for _, line in ipairs(lines) do
		for _, edge in ipairs({ start, start + size / 2, start + size }) do
			local shift = line - edge

			if math.abs(shift) <= threshold and (not best or math.abs(shift) < math.abs(best)) then
				best, bestLine = shift, line
			end
		end
	end

	return best or 0, bestLine
end

---Moves a rectangle so its nearest edge or center meets a line within `threshold` on each axis.
---@param left number
---@param bottom number
---@param width number
---@param height number
---@param lines LBSnapLines
---@param threshold number
---@return number left
---@return number bottom
---@return number? guideX
---@return number? guideY
function Placement:Snap(left, bottom, width, height, lines, threshold)
	local shiftX, guideX = Nearest(left, width, lines.x, threshold)
	local shiftY, guideY = Nearest(bottom, height, lines.y, threshold)

	return left + shiftX, bottom + shiftY, guideX, guideY
end
