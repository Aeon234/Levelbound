-- Checks UI/Gain.lua's placement outside the game: the position resolver, the end offsets and the motion; where
-- the segmented row's stack sits; and which way Show sends a gain (beside the bar, above it, or into the stack).
-- Run from any directory with Lua 5.1: lua Tools/check_gain.lua
-- Loads the real files against minimal fake frames that record their points. Exits non-zero on the first failed
-- check. It proves the placement's math and routing, not how it looks on screen.

local root = (arg and arg[0] or ""):match("^(.-)[^/\\]*$") .. "../"

-- Environment ---------------------------------------------------------------------------------------------

UNKNOWN = "Unknown"
SlashCmdList = {}
C_AddOns = {
	GetAddOnMetadata = function() end,
}

function issecretvalue()
	return false
end

function wipe(list)
	for key in pairs(list) do
		list[key] = nil
	end

	return list
end

function Mixin(object, ...)
	for index = 1, select("#", ...) do
		for key, value in pairs((select(index, ...))) do
			object[key] = value
		end
	end

	return object
end

function CreateColor()
	return {
		WrapTextInColorCode = function(_, text)
			return text
		end,
	}
end

PixelUtil = {
	GetNearestPixelSize = function(size)
		return size
	end,
}

local TEXT_WIDTH = 60

-- A fake frame, texture or font string: records its points, parent and scripts. Methods it lacks raise.
local FrameMethods = {}
local FrameMeta = { __index = FrameMethods }

local function NewFrame(name)
	return setmetatable({ name = name, points = {}, alpha = 1, shown = false, width = 1, height = 1, scripts = {},
		level = 1 }, FrameMeta)
end

function FrameMethods:SetScript(kind, fn)
	self.scripts[kind] = fn
end
function FrameMethods:Show()
	self.shown = true
end
function FrameMethods:Hide()
	self.shown = false
end
function FrameMethods:ClearAllPoints()
	self.points = {}
end
function FrameMethods:SetPoint(...)
	self.points[#self.points + 1] = { ... }
end
function FrameMethods:SetAllPoints() end
function FrameMethods:SetAlpha(alpha)
	self.alpha = alpha
end
function FrameMethods:SetWidth(width)
	self.width = width
end
function FrameMethods:SetHeight(height)
	self.height = height
end
function FrameMethods:SetSize(width, height)
	self.width, self.height = width, height
end
function FrameMethods:GetWidth()
	return self.width
end
function FrameMethods:GetHeight()
	return self.height
end
function FrameMethods:GetSize()
	return self.width, self.height
end
function FrameMethods:GetLeft()
	return self.left
end
function FrameMethods:GetRight()
	return self.right
end
function FrameMethods:GetTop()
	return self.top
end
function FrameMethods:GetRect()
	return self.left, nil, self.width, self.height
end
function FrameMethods:GetEffectiveScale()
	return 1
end
function FrameMethods:SetParent(parent)
	self.parent = parent
end
function FrameMethods:GetParent()
	return self.parent
end
function FrameMethods:SetFrameLevel(level)
	self.level = level
end
function FrameMethods:GetFrameLevel()
	return self.level
end
function FrameMethods:CreateFontString()
	return NewFrame()
end
function FrameMethods:CreateTexture()
	return NewFrame()
end
function FrameMethods:SetFrameStrata() end
function FrameMethods:SetTexture() end
function FrameMethods:SetVertexColor() end
function FrameMethods:SetTextColor() end
function FrameMethods:SetText(text)
	self.text = text
end
function FrameMethods:GetStringWidth()
	return TEXT_WIDTH
end

UIParent = NewFrame("UIParent")
UIParent.width, UIParent.top = 1920, 1080

function CreateFrame(_, name)
	return NewFrame(name)
end

function CreateFramePool(_, _, _, resetter)
	local pool = { inactive = {}, active = {} }

	function pool:Acquire()
		local frame = table.remove(self.inactive)

		if not frame then
			frame = NewFrame()
			resetter(self, frame)
		end

		self.active[frame] = true

		return frame
	end

	function pool:Release(frame)
		assert(self.active[frame], "released a frame the pool does not hold")
		self.active[frame] = nil
		resetter(self, frame)
		self.inactive[#self.inactive + 1] = frame
	end

	function pool:ReleaseAll()
		for frame in pairs(self.active) do
			self:Release(frame)
		end
	end

	return pool
end

local LB = {}
assert(loadfile(root .. "Core/Core.lua"))("Levelbound", LB)
LB.L = setmetatable({}, { __index = function(_, key)
	return key
end })

local settings = {
	enabled = true,
	hideInCombat = false,
	animate = true,
	animation = "RISE",
	position = "FILL_EDGE",
	detached = false,
	direction = "UP",
	across = "RIGHT",
	colors = { xp = { 0, 1, 0 } },
	text = { font = "Gilroy Bold", size = 12, outline = "SLUG_OUTLINE", color = { 1, 1, 1, 1 }, side = "RIGHT",
		x = 0, y = 0 },
}
local layout = { mode = "CONNECTED", strata = "HIGH" }
LB.Profile = {
	Get = function(_, path)
		if path == "gain" then
			return settings
		elseif path:match("^gain%.") then
			return settings[path:match("^gain%.(.+)$")]
		elseif path == "layout.mode" then
			return layout.mode
		elseif path == "layout.strata" then
			return layout.strata
		end

		error("unexpected profile path " .. path)
	end,
}
LB.Callbacks = { Register = function() end }
LB.Events = { Register = function() end }
LB.Media = { SetFont = function() end, textures = { gainArrow = "arrow" } }
LB.Format = {
	Number = function(_, value)
		return tostring(value)
	end,
}
LB.Model = {
	Order = function()
		return { "xp", "reputation" }
	end,
	Label = function(_, id)
		return id
	end,
}
LB.Progress = {
	Fraction = function()
		return 0.5
	end,
}
LB.TextSlot = {
	BorderReach = function()
		return 0
	end,
}

local row = NewFrame("row")
LB.BarGroup = { frame = row }

assert(loadfile(root .. "UI/NoticeStack.lua"))("Levelbound", LB)
assert(loadfile(root .. "UI/Gain.lua"))("Levelbound", LB)

local Gain = LB.Gain

-- Harness -------------------------------------------------------------------------------------------------

local checks = 0

local function Equal(name, actual, expected)
	checks = checks + 1
	if actual ~= expected then
		error(("FAIL: %s: expected %s, got %s"):format(name, tostring(expected), tostring(actual)), 2)
	end
end

local function Check(name, condition)
	Equal(name, condition == true, true)
end

---@param left number
---@param right number
---@param id string? the progress type; experience when nil
local function Bar(left, right, id)
	local bar = NewFrame("bar")

	bar.id = id or "xp"
	bar.parent = row
	bar.snapshot = {}
	bar.left, bar.right, bar.width, bar.height, bar.top = left, right, right - left, 12, 500

	return bar
end

local function Reset()
	Gain:ReleaseAll()
	settings.position, settings.animate, settings.animation = "FILL_EDGE", true, "RISE"
	settings.detached, settings.direction = false, "UP"
	layout.mode = "CONNECTED"
	row.left, row.right = 500, 1100
end

-- An indicator is its arrow (twice the text size), the gap and its text.
local WIDTH = 12 * 2 + 2 + TEXT_WIDTH
local GAP = 2

-- Placement -----------------------------------------------------------------------------------------------

local side, mode = Gain:Placement("FILL_EDGE", 100, 500, 1920, WIDTH, GAP)
Check("fill edge sits above", side == nil and mode == "FILL_EDGE")
side, mode = Gain:Placement("RIGHT_END", 100, 500, 1920, WIDTH, GAP)
Check("right end sits above", side == nil and mode == "RIGHT_END")

side, mode = Gain:Placement("OUTSIDE_RIGHT", 100, 1000, 1920, WIDTH, GAP)
Check("right of bar with room", side == "RIGHT" and mode == "RIGHT_END")
side = Gain:Placement("OUTSIDE_RIGHT", 100, 1920 - GAP - WIDTH, 1920, WIDTH, GAP)
Equal("right of bar fits exactly", side, "RIGHT")
side, mode = Gain:Placement("OUTSIDE_RIGHT", 100, 1921 - GAP - WIDTH, 1920, WIDTH, GAP)
Check("right of bar without room falls back to the right end", side == nil and mode == "RIGHT_END")

side, mode = Gain:Placement("OUTSIDE_LEFT", 200, 1000, 1920, WIDTH, GAP)
Check("left of bar with room", side == "LEFT" and mode == "LEFT_END")
side = Gain:Placement("OUTSIDE_LEFT", GAP + WIDTH, 1000, 1920, WIDTH, GAP)
Equal("left of bar fits exactly", side, "LEFT")
side, mode = Gain:Placement("OUTSIDE_LEFT", GAP + WIDTH - 1, 1000, 1920, WIDTH, GAP)
Check("left of bar without room falls back to the left end", side == nil and mode == "LEFT_END")
side = Gain:Placement("OUTSIDE_RIGHT", 0, 1920, 1920, WIDTH, GAP)
Equal("a full-width bar has no room beside it", side, nil)

-- Offsets -------------------------------------------------------------------------------------------------

Equal("fill edge follows the fill", Gain:Offset(0.5, 400, WIDTH, "FILL_EDGE"), 200)
Equal("right end, kept on the bar", Gain:Offset(0.5, 400, WIDTH, "RIGHT_END"), 400 - WIDTH / 2)
Equal("left end, kept on the bar", Gain:Offset(0.5, 400, WIDTH, "LEFT_END"), WIDTH / 2)
Equal("wider than the bar centers", Gain:Offset(0.5, 50, WIDTH, "LEFT_END"), 25)

-- Motion --------------------------------------------------------------------------------------------------

local function Motion(animate, animation, at)
	local dx, dy = Gain:Motion({ animate = animate, animation = animation }, at)

	return dx .. "," .. dy
end

Equal("rises above the bar", Motion(true, "RISE", nil), "0,1")
Equal("rises beside the bar", Motion(true, "RISE", "RIGHT"), "0,1")
Equal("slides right, away from the bar", Motion(true, "SLIDE", "RIGHT"), "1,0")
Equal("slides left, away from the bar", Motion(true, "SLIDE", "LEFT"), "-1,0")
Equal("slide above the bar rises", Motion(true, "SLIDE", nil), "0,1")
Equal("still when animation is off", Motion(false, "SLIDE", "RIGHT"), "0,0")

-- The segmented row's stack -------------------------------------------------------------------------------

Reset()
layout.mode = "SEGMENTED"
settings.position = "OUTSIDE_RIGHT"
local anchor = Gain:GatherAnchor()
Check("right of the row", anchor and anchor.relativeTo == row and anchor.relativePoint == "RIGHT")
Equal("grows up from its first line's bottom", anchor.point, "BOTTOMLEFT")
Equal("clear of the row", anchor.x, GAP)
Equal("first line centered on the row", anchor.y, -12)
Equal("grows up", anchor.sign, 1)

settings.direction = "DOWN"
anchor = Gain:GatherAnchor()
Check("grows down from its first line's top", anchor.point == "TOPLEFT" and anchor.y == 12 and anchor.sign == -1)

settings.position = "OUTSIDE_LEFT"
anchor = Gain:GatherAnchor()
Check("left of the row", anchor.relativePoint == "LEFT" and anchor.point == "TOPRIGHT" and anchor.x == -GAP)

settings.position = "OUTSIDE_RIGHT"
local other = NewFrame("other row")
other.left, other.right = 200, 800
anchor = Gain:GatherAnchor(other)
Check("beside the row it is given", anchor and anchor.relativeTo == other)
row.right = 1900
Equal("no stack without room beside the row", Gain:GatherAnchor(), nil)
row.right = 1100
settings.detached = true
Equal("no stack while detached", Gain:GatherAnchor(), nil)
settings.detached = false
settings.position = "RIGHT_END"
Equal("no stack above the bars", Gain:GatherAnchor(), nil)
settings.position = "OUTSIDE_RIGHT"
layout.mode = "CONNECTED"
Equal("no stack outside segmented", Gain:GatherAnchor(), nil)

-- Show: where each gain goes ------------------------------------------------------------------------------

---@param frame table
---@return number x
---@return number y the content's offset within the indicator
local function Content(frame)
	local point = frame.content.points[1]

	return point[4], point[5]
end

-- Beside the bar, centered on it.
Reset()
settings.position = "OUTSIDE_RIGHT"
local bar = Bar(400, 1000)
Gain:Show(bar, 100)
local frame = Gain.active[bar]
local point = frame and frame.points[1]
Check("right of the bar", point and point[1] == "LEFT" and point[2] == bar and point[3] == "RIGHT")
Check("clear of the bar and centered", point[4] == GAP and point[5] == 0)
frame.scripts.OnUpdate(frame, 1)
local x, y = Content(frame)
Check("rises beside the bar", x == 0 and y > 0)

Reset()
settings.position, settings.animation = "OUTSIDE_RIGHT", "SLIDE"
bar = Bar(400, 1000)
Gain:Show(bar, 100)
frame = Gain.active[bar]
frame.scripts.OnUpdate(frame, 1)
x, y = Content(frame)
Check("slides away to the right", x > 0 and y == 0)

Reset()
settings.position, settings.animation = "OUTSIDE_LEFT", "SLIDE"
bar = Bar(400, 1000)
Gain:Show(bar, 100)
frame = Gain.active[bar]
point = frame.points[1]
Check("left of the bar", point[1] == "RIGHT" and point[3] == "LEFT" and point[4] == -GAP)
frame.scripts.OnUpdate(frame, 1)
x, y = Content(frame)
Check("slides away to the left", x < 0 and y == 0)

Reset()
settings.position, settings.animate = "OUTSIDE_RIGHT", false
bar = Bar(400, 1000)
Gain:Show(bar, 100)
frame = Gain.active[bar]
frame.scripts.OnUpdate(frame, 1)
x, y = Content(frame)
Check("stays in place with animation off", x == 0 and y == 0)

-- No room: above the bar's end, rising even when set to slide.
Reset()
settings.position, settings.animation = "OUTSIDE_LEFT", "SLIDE"
bar = Bar(10, 610)
Gain:Show(bar, 100)
frame = Gain.active[bar]
point = frame.points[1]
Check("above the left end", point[1] == "BOTTOM" and point[3] == "TOPLEFT" and point[4] == WIDTH / 2)
frame.scripts.OnUpdate(frame, 1)
x, y = Content(frame)
Check("the fallback rises", x == 0 and y > 0)

-- Segmented: gains gather in the stack beside the row, or fall back above each segment.
Reset()
layout.mode = "SEGMENTED"
settings.position = "OUTSIDE_RIGHT"
bar = Bar(500, 700)
Gain:Show(bar, 100)
Equal("a segment draws no indicator of its own", Gain.active[bar], nil)
local line = Gain.lines.xp
Check("the gain is a line in the stack", line ~= nil and Gain.stack.active[1] == line)
Equal("the line sits with the row", line.parent, row)
point = line.points[1]
Check("the line is beside the row", point[2] == row and point[3] == "RIGHT" and point[5] == -12)
Equal("the stack moves", Gain.stack.still, false)
layout.mode = "CONNECTED"
Gain:Show(Bar(400, 1000), 100)
Check("a bar's own indicator leaves the stack beside the row", Gain.gather and Gain.gather.relativeTo == row)

Equal("the stack is stacked by default", Gain.gather.across, nil)

-- Slide Outward: the lines sit side by side, the newest against the row, growing away from it.
local SLOT = WIDTH + 2

---Ticks every line in the stack for `seconds`.
local function Tick(seconds)
	for _ = 1, seconds * 60 do
		for _, stacked in ipairs(Gain.stack.active) do
			stacked.scripts.OnUpdate(stacked, 1 / 60)
		end
	end
end

---@param id string
---@return number x
---@return number y the line's offset from its anchor point
local function Line(id)
	local found = Gain.lines[id].points[1]

	return found[4], found[5]
end

for _, still in ipairs({ true, false }) do
	local label = still and "still: " or "moving: "

	Reset()
	layout.mode = "SEGMENTED"
	settings.position, settings.animation, settings.animate = "OUTSIDE_RIGHT", "SLIDE", not still
	Gain:Show(Bar(500, 600), 100)
	Gain:Show(Bar(600, 700, "reputation"), 100)
	Tick(1)
	point = Gain.lines.reputation.points[1]
	Check(label .. "a line's left edge against the row's right", point[1] == "LEFT" and point[3] == "RIGHT")
	x, y = Line("reputation")
	Check(label .. "the newest against the row, centered", x == GAP and y == 0)
	x, y = Line("xp")
	Check(label .. "the older pushed right, level with it", x == GAP + SLOT and y == 0)
end

Reset()
layout.mode = "SEGMENTED"
settings.position, settings.animation = "OUTSIDE_LEFT", "SLIDE"
Gain:Show(Bar(500, 600), 100)
Gain:Show(Bar(600, 700, "reputation"), 100)
Tick(1)
point = Gain.lines.reputation.points[1]
Check("left of the row, a line's right edge against it", point[1] == "RIGHT" and point[3] == "LEFT")
x = Line("reputation")
Equal("the newest against the row", x, -GAP)
x = Line("xp")
Equal("the older pushed left", x, -(GAP + SLOT))

-- Detached with Slide Outward: side by side from the box's edge, the chosen way.
for _, across in ipairs({ "RIGHT", "LEFT" }) do
	Reset()
	settings.detached, settings.animation, settings.across = true, "SLIDE", across
	Gain:Show(Bar(400, 600), 100)
	Gain:Show(Bar(600, 700, "reputation"), 100)
	Tick(1)

	local edge = across == "RIGHT" and "LEFT" or "RIGHT"
	local sign = across == "RIGHT" and 1 or -1

	point = Gain.lines.reputation.points[1]
	Check("detached " .. across .. ": from the box's " .. edge .. " edge",
		point[1] == edge and point[2] == Gain.box and point[3] == edge)
	x, y = Line("reputation")
	Check("detached " .. across .. ": the newest at the edge", x == 0 and y == 0)
	x = Line("xp")
	Equal("detached " .. across .. ": the older pushed on", x, sign * SLOT)
end
settings.across = "RIGHT"

-- The detached box is a full stack's footprint.
Reset()
settings.detached = true
local boxWidth, boxHeight = Gain:DetachedFootprint()
Check("stacked: one line wide, three tall", boxWidth == WIDTH and boxHeight == 3 * 24 + 2 * 2)
settings.animation = "SLIDE"
boxWidth, boxHeight = Gain:DetachedFootprint()
Check("side by side: three lines wide, one tall", boxWidth == 3 * WIDTH + 2 * 2 and boxHeight == 24)

Reset()
layout.mode = "SEGMENTED"
settings.position, settings.animate = "OUTSIDE_RIGHT", false
Gain:Show(Bar(500, 700), 100)
Equal("the stack is still with animation off", Gain.stack.still, true)

Reset()
layout.mode = "SEGMENTED"
settings.position = "OUTSIDE_RIGHT"
row.left, row.right = 0, 1920
bar = Bar(500, 700)
Gain:Show(bar, 100)
frame = Gain.active[bar]
Check("a full-width row falls back above each segment", frame ~= nil and Gain.lines.xp == nil)
point = frame.points[1]
Check("above the segment's right end", point[1] == "BOTTOM" and point[4] == 200 - WIDTH / 2)

-- Detached: into the box, whatever the position.
Reset()
settings.position, settings.detached = "OUTSIDE_RIGHT", true
Gain:Show(Bar(400, 1000), 100)
line = Gain.lines.xp
Check("detached goes to the box", line ~= nil and line.points[1][2] == Gain.box and line.parent == UIParent)

-- Samples sit beside their bar wherever it is, in any layout.
Reset()
layout.mode = "SEGMENTED"
settings.position = "OUTSIDE_LEFT"
bar = Bar(0, 300)
frame = Gain:Hold(bar, 100)
point = frame and frame.points[1]
Check("a sample sits beside its bar", point and point[1] == "RIGHT" and point[3] == "LEFT")

Reset()

print(("check_gain: %d checks passed"):format(checks))
