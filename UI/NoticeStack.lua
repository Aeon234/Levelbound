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
local CENTER_GAP = 40

---@class LBNoticeAnchor
---@field point string the line's own point
---@field relativeTo Region
---@field relativePoint string
---@field x number
---@field y number
---@field sign integer 1 when the stack grows up, -1 when it grows down; across, 1 to the right and -1 to the left
---@field across boolean? the lines stack side by side and fade without rising

---@class LBNoticeStack
---@field pool any
---@field active Frame[] newest first; the newest sits at the anchor
---@field leaving Frame[] pushed out by a newer line, fading while they slide on
---@field anchor fun(): LBNoticeAnchor?
---@field onRelease fun(frame: Frame)?
---@field still boolean? lines neither rise nor slide: each takes its slot at once and fades there
local NoticeStackMixin = {}

---@class LBNoticeStackFactory
local NoticeStack = {
	MAX = MAX,
	SPACING = SPACING,
	RISE = RISE,
	DURATION = DURATION,
	HELD = FADE_IN,
}
LB.NoticeStack = NoticeStack

---@param elapsed number seconds since the line appeared
---@return number rise distance traveled away from the anchor
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

---@param anchor string TOPLEFT, TOP, TOPRIGHT, BOTTOMLEFT, BOTTOM or BOTTOMRIGHT, the point on the bar; LEFT or
---RIGHT, the bar's side, which the line meets with its opposite edge
---@param direction string UP or DOWN, the way the stack grows
---@return string point the line's own point that attaches to the anchor
---@return integer sign 1 when growing up, -1 when growing down
function NoticeStack:Place(anchor, direction)
	local side = anchor == "LEFT" and "RIGHT" or anchor == "RIGHT" and "LEFT" or anchor:match("LEFT")
		or anchor:match("RIGHT") or ""

	if direction == "UP" then
		return "BOTTOM" .. side, 1
	end

	return "TOP" .. side, -1
end

---@param center number the box's horizontal center
---@param screenWidth number
---@return string align "LEFT", "RIGHT" or ""
function NoticeStack:Align(center, screenWidth)
	if center < screenWidth / 3 then
		return "LEFT"
	elseif center > screenWidth * 2 / 3 then
		return "RIGHT"
	elseif center < screenWidth / 2 then
		return "RIGHT"
	elseif center > screenWidth / 2 then
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
---@param position LBFramePosition? nil for the default place beside the screen's center
---@param width number
---@param height number
---@param side integer -1 to default left of the center, 1 to default right of it
function NoticeStack:PlaceBox(box, position, width, height, side)
	position = position or { point = "CENTER", x = side * (CENTER_GAP + width / 2), y = 0 }

	LB:SetPixelSize(box, width, height)
	box:ClearAllPoints()
	box:SetPoint(position.point, UIParent, position.point, position.x, position.y)
end

---@param box Frame
---@param direction string UP or DOWN, or RIGHT or LEFT for lines side by side from the box's matching edge
---@return LBNoticeAnchor
function NoticeStack:BoxAnchor(box, direction)
	if direction == "RIGHT" or direction == "LEFT" then
		local right = direction == "RIGHT"
		local point = right and "LEFT" or "RIGHT"

		return { point = point, relativeTo = box, relativePoint = point, x = 0, y = 0, sign = right and 1 or -1,
			across = true }
	end

	local left, _, width = box:GetRect()
	local align = left and self:Align(left + width / 2, UIParent:GetWidth()) or ""
	local up = direction == "UP"
	local point = (up and "BOTTOM" or "TOP") .. align

	return { point = point, relativeTo = box, relativePoint = point, x = 0, y = 0, sign = up and 1 or -1 }
end

---@param lineHeight number a line's extent along the stack
---@return number height of a full stack of such lines; its width, for lines side by side
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

---Restarts a line's time and makes it the newest: it fades in again at the anchor while the lines before it step
---outward, so the lines always end in order from the farthest in.
---@param frame Frame
function NoticeStackMixin:Restart(frame)
	if not frame.held then
		frame.elapsed = 0
	end

	if Remove(self.active, frame) then
		table.insert(self.active, 1, frame)
		frame.offset = 0
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

	if frame.held or self.still or anchor.across then
		rise = 0
	end

	if frame.evicted then
		alpha = alpha * (1 - math.min(frame.evicted / EVICT, 1))
	end

	local distance = anchor.sign * (frame.offset + rise)

	frame:ClearAllPoints()
	frame:SetPoint(
		anchor.point,
		anchor.relativeTo,
		anchor.relativePoint,
		anchor.x + (anchor.across and distance or 0),
		anchor.y + (anchor.across and 0 or distance)
	)
	frame:SetAlpha(alpha)
end

---@param frame Frame
---@param across boolean?
---@return number size the line's extent along the stack
local function Extent(frame, across)
	return across and frame:GetWidth() or frame:GetHeight()
end

function NoticeStackMixin:Layout()
	local anchor = self.anchor()
	local across = anchor and anchor.across
	local sizes = {}

	for index, frame in ipairs(self.active) do
		sizes[index] = Extent(frame, across)
	end

	local targets = NoticeStack:Slots(sizes)
	local beyond = 0

	for index, frame in ipairs(self.active) do
		frame.target = targets[index]
		beyond = targets[index] + Extent(frame, across) + SPACING

		if frame.held or self.still then
			frame.offset = frame.target
		end
	end

	for _, frame in ipairs(self.leaving) do
		frame.target = math.max(beyond, frame.target)

		if self.still then
			frame.offset = frame.target
		end
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
