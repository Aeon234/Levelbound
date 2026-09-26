local LB = select(2, ...)

local MAX = 3
local SPACING = 2
local RISE = 12
local FADE_IN = 0.2
local HOLD = 2.5
local FADE = 0.5
local DURATION = HOLD + FADE
local EVICT = 0.3
local SLIDE_RATE = 12
local SETTLE = 0.05
local CENTRE_GAP = 40

---@class LBNoticeAnchor
---@field point string the line's own point
---@field relativeTo Region
---@field relativePoint string
---@field x number
---@field y number
---@field sign integer 1 when the stack grows up, -1 when it grows down

---@class LBNoticeStack
---@field pool any
---@field active Frame[] newest first; the newest sits at the anchor
---@field leaving Frame[] pushed out by a newer line, fading while they slide on
---@field anchor fun(): LBNoticeAnchor?
---@field onRelease fun(frame: Frame)?
local NoticeStackMixin = {}

---@class LBNoticeStackFactory
local NoticeStack = {
	MAX = MAX,
	SPACING = SPACING,
	DURATION = DURATION,
	HELD = FADE_IN,
}
LB.NoticeStack = NoticeStack

---@param elapsed number seconds since the line appeared
---@return number rise distance travelled away from the anchor
---@return number alpha
function NoticeStack:Keyframe(elapsed)
	local progress = math.min(elapsed / DURATION, 1)
	local inverse = 1 - progress
	local rise = RISE * (1 - inverse * inverse * inverse)
	local alpha = math.min(elapsed / FADE_IN, 1)

	if elapsed > HOLD then
		alpha = 1 - math.min((elapsed - HOLD) / FADE, 1)
	end

	return rise, alpha
end

---@param current number
---@param target number
---@param delta number seconds since the last step
---@return number next eased toward the target, landing on it once close
function NoticeStack:Ease(current, target, delta)
	local step = current + (target - current) * (1 - math.exp(-SLIDE_RATE * delta))

	if math.abs(target - step) < SETTLE then
		return target
	end

	return step
end

---@param heights number[] line heights, newest first
---@return number[] targets each line's distance from the anchor
function NoticeStack:Slots(heights)
	local targets = {}
	local distance = 0

	for index, height in ipairs(heights) do
		targets[index] = distance
		distance = distance + height + SPACING
	end

	return targets
end

---@param anchor string TOPLEFT, TOP, TOPRIGHT, BOTTOMLEFT, BOTTOM or BOTTOMRIGHT, the point on the bar
---@param direction string UP or DOWN, the way the stack grows
---@return string point the line's own point that attaches to the anchor
---@return integer sign 1 when growing up, -1 when growing down
function NoticeStack:Place(anchor, direction)
	local side = anchor:match("LEFT") or anchor:match("RIGHT") or ""

	if direction == "UP" then
		return "BOTTOM" .. side, 1
	end

	return "TOP" .. side, -1
end

---@param centre number the box's horizontal centre
---@param screenWidth number
---@return string align "LEFT", "RIGHT" or ""
function NoticeStack:Align(centre, screenWidth)
	if centre < screenWidth / 3 then
		return "LEFT"
	elseif centre > screenWidth * 2 / 3 then
		return "RIGHT"
	elseif centre < screenWidth / 2 then
		return "RIGHT"
	elseif centre > screenWidth / 2 then
		return "LEFT"
	end

	return ""
end

---@param name string
---@return Frame box the detached stack's place on screen, which edit mode moves
function NoticeStack:CreateBox(name)
	local box = CreateFrame("Frame", name, UIParent)

	box.measure = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	box.measure:Hide()
	box:SetSize(1, 1)

	return box
end

---@param box Frame
---@param position LBFramePosition? nil for the default place beside the screen's centre
---@param width number
---@param height number
---@param side integer -1 to default left of the centre, 1 to default right of it
function NoticeStack:PlaceBox(box, position, width, height, side)
	position = position or { point = "CENTER", x = side * (CENTRE_GAP + width / 2), y = 0 }

	LB:SetPixelSize(box, width, height)
	box:ClearAllPoints()
	box:SetPoint(position.point, UIParent, position.point, position.x, position.y)
end

---@param box Frame
---@param direction string UP or DOWN
---@return LBNoticeAnchor
function NoticeStack:BoxAnchor(box, direction)
	local left, _, width = box:GetRect()
	local align = left and self:Align(left + width / 2, UIParent:GetWidth()) or ""
	local up = direction == "UP"
	local point = (up and "BOTTOM" or "TOP") .. align

	return { point = point, relativeTo = box, relativePoint = point, x = 0, y = 0, sign = up and 1 or -1 }
end

---@param lineHeight number
---@return number height of a full stack of such lines
function NoticeStack:BoxHeight(lineHeight)
	return MAX * lineHeight + (MAX - 1) * SPACING
end

---@param anchor fun(): LBNoticeAnchor?
---@param onReset fun(frame: Frame)? clears the owner's own fields when a line returns to the pool
---@param onRelease fun(frame: Frame)? told when a line leaves the stack
---@return LBNoticeStack
function NoticeStack:Create(anchor, onReset, onRelease)
	local stack = Mixin({ active = {}, leaving = {}, anchor = anchor, onRelease = onRelease }, NoticeStackMixin)

	stack.pool = CreateFramePool("Frame", UIParent, nil, function(_, frame)
		frame:SetScript("OnUpdate", nil)
		frame:Hide()
		frame:ClearAllPoints()

		frame.stack = nil
		frame.elapsed = 0
		frame.offset = 0
		frame.target = 0
		frame.evicted = nil
		frame.held = nil

		if onReset then
			onReset(frame)
		end
	end)

	return stack
end

---@param list Frame[]
---@param frame Frame
---@return boolean removed
local function Remove(list, frame)
	for index, entry in ipairs(list) do
		if entry == frame then
			table.remove(list, index)

			return true
		end
	end

	return false
end

---@param frame Frame
---@param delta number
local function OnUpdate(frame, delta)
	local stack = frame.stack

	frame.elapsed = frame.elapsed + delta
	frame.offset = NoticeStack:Ease(frame.offset, frame.target, delta)

	if frame.evicted then
		frame.evicted = frame.evicted + delta
	end

	if frame.elapsed >= DURATION or (frame.evicted and frame.evicted >= EVICT) then
		stack:Finish(frame)

		return
	end

	stack:Paint(frame)
end

---@return Frame
function NoticeStackMixin:Acquire()
	local frame = self.pool:Acquire()

	frame.stack = self

	return frame
end

---@param frame Frame built and sized by the owner
---@param held boolean? stays at full strength without timing out, for previews and edit mode
function NoticeStackMixin:Push(frame, held)
	if #self.active >= MAX then
		local oldest = table.remove(self.active)

		oldest.evicted = 0
		oldest:SetScript("OnUpdate", OnUpdate)
		self.leaving[#self.leaving + 1] = oldest
	end

	frame.elapsed = held and FADE_IN or 0
	frame.offset = 0
	frame.target = 0
	frame.held = held == true
	table.insert(self.active, 1, frame)

	frame:SetScript("OnUpdate", not frame.held and OnUpdate or nil)
	frame:Show()

	self:Layout()
end

---@param frame Frame
function NoticeStackMixin:Restart(frame)
	if not frame.held then
		frame.elapsed = 0
	end

	self:Layout()
end

---@param frame Frame
function NoticeStackMixin:Paint(frame)
	local anchor = self.anchor()

	if not anchor then
		return
	end

	local rise, alpha = NoticeStack:Keyframe(frame.elapsed)

	if frame.held then
		rise = 0
	end

	if frame.evicted then
		alpha = alpha * (1 - math.min(frame.evicted / EVICT, 1))
	end

	frame:ClearAllPoints()
	frame:SetPoint(
		anchor.point,
		anchor.relativeTo,
		anchor.relativePoint,
		anchor.x,
		anchor.y + anchor.sign * (frame.offset + rise)
	)
	frame:SetAlpha(alpha)
end

function NoticeStackMixin:Layout()
	local heights = {}

	for index, frame in ipairs(self.active) do
		heights[index] = frame:GetHeight()
	end

	local targets = NoticeStack:Slots(heights)
	local beyond = 0

	for index, frame in ipairs(self.active) do
		frame.target = targets[index]
		beyond = targets[index] + frame:GetHeight() + SPACING

		if frame.held then
			frame.offset = frame.target
		end
	end

	for _, frame in ipairs(self.leaving) do
		frame.target = math.max(beyond, frame.target)
	end

	for _, frame in ipairs(self.active) do
		self:Paint(frame)
	end

	for _, frame in ipairs(self.leaving) do
		self:Paint(frame)
	end
end

---@param frame Frame
function NoticeStackMixin:Finish(frame)
	Remove(self.active, frame)
	Remove(self.leaving, frame)

	if self.onRelease then
		self.onRelease(frame)
	end

	self.pool:Release(frame)
	self:Layout()
end

function NoticeStackMixin:ReleaseAll()
	if self.onRelease then
		for _, frame in ipairs(self.active) do
			self.onRelease(frame)
		end

		for _, frame in ipairs(self.leaving) do
			self.onRelease(frame)
		end
	end

	self.pool:ReleaseAll()
	wipe(self.active)
	wipe(self.leaving)
end
