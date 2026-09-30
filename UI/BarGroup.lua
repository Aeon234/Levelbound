local LB = select(2, ...)

local Callbacks = LB.Callbacks
local L = LB.L

local SEPARATOR = 2
local REFLOW = 0.25

local FLAT = [[Interface\Buttons\WHITE8X8]]

---@class LBBarRect
---@field width number
---@field height number
---@field x number
---@field y number
---@field point FramePoint?

---@class LBBarGroup
---@field frame Frame?
---@field driver Frame?
---@field bars table<string, LBBar>
---@field separators Texture[]
---@field border LBBorderFrame?
---@field rects table<string, LBBarRect>
---@field hasBars boolean?
---@field settling boolean?
local BarGroup = {
	bars = {},
	separators = {},
	rects = {},
}
LB.BarGroup = BarGroup

---@return string[]
local function VisibleIds()
	if LB.Editing:PreviewAll() then
		return LB.Preview:Ids()
	end

	return LB.Model:VisibleOrder()
end

---@param id string
---@return LBSnapshot?
local function SnapshotFor(id)
	if LB.Preview:Covers(id) then
		return LB.Preview:Snapshot(id)
	end

	return LB.Model:Get(id)
end

---@param total number
---@param count integer
---@param separator number
---@return number[] widths
---@return number[] offsets left edge of each segment
function BarGroup:SegmentWidths(total, count, separator)
	local widths, offsets = {}, {}

	if count <= 0 then
		return widths, offsets
	end

	local usable = math.max(total - separator * (count - 1), 0)
	local base = math.floor(usable / count)
	local remainder = usable - base * count
	local x = 0

	for index = 1, count do
		local width = base + (index <= remainder and 1 or 0)

		widths[index] = width
		offsets[index] = x
		x = x + width + separator
	end

	return widths, offsets
end

---@param ids string[]
---@param screenWidth number
---@return table<string, LBBarRect> rects
---@return number groupWidth
---@return number groupHeight
function BarGroup:ComputeLayout(ids, screenWidth)
	local layout = LB.Profile:Get("layout")
	local count = #ids
	local rects = {}
	local width = LB.Layout.Fullscreen(layout) and screenWidth or layout.width

	if count == 0 then
		return rects, width, layout.height
	end

	if layout.mode == "SEGMENTED" then
		local widths, offsets = self:SegmentWidths(width, count, SEPARATOR)

		for index, id in ipairs(ids) do
			rects[id] = { width = widths[index], height = layout.height, x = offsets[index], y = 0 }
		end

		return rects, width, layout.height
	end

	-- Stacked bars each carry a border; the gap is measured between the borders' outer edges.
	local spacing = layout.gap

	if not LB.Layout.Fullscreen(layout) then
		spacing = spacing + 2 * LB.Border:Outset(LB.Profile:Get("appearance.border.style"), layout.height)
	end

	if layout.mode == "CONNECTED" then
		local step = layout.height + spacing
		local total = layout.height * count + spacing * (count - 1)

		local growth = LB.Layout.Growth(layout)

		for index, id in ipairs(ids) do
			local y = growth == "UP" and (total - layout.height - (index - 1) * step) or ((index - 1) * step)

			rects[id] = { width = width, height = layout.height, x = 0, y = y }
		end

		return rects, width, total
	end

	local independent = layout.independent

	for index, id in ipairs(ids) do
		local stored = independent[id]
		local position = stored and stored.position or layout.positions.INDEPENDENT

		rects[id] = {
			width = stored and stored.width or layout.width,
			height = stored and stored.height or layout.height,
			point = position.point,
			x = position.x,
			y = (stored and stored.position) and position.y
				or (position.y - (index - 1) * (layout.height + spacing)),
		}
	end

	return rects, layout.width, layout.height
end

function BarGroup:Create()
	if self.frame then
		return
	end

	local frame = CreateFrame("Frame", "LevelboundBarGroup", UIParent)

	frame:SetFrameStrata(LB.Profile:Get("layout.strata"))
	frame:Hide()

	self.frame = frame
	self.driver = CreateFrame("Frame", nil, frame)

	for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
		LB.Events:Register(event, self, function()
			self:ApplyLayout(false)
		end)
	end

	self:ApplyLayout(false)
end

---@param parent Frame
---@param id string
---@return LBBar
function BarGroup:Bar(parent, id)
	local bar = self.bars[id]

	if not bar then
		bar = LB.Bar:Create(parent, id)
		self.bars[id] = bar
	end

	return bar
end

---@param parent Frame
---@param index integer
---@return Texture
function BarGroup:Separator(parent, index)
	local separator = self.separators[index]

	if not separator then
		separator = parent:CreateTexture(nil, "OVERLAY")
		separator:SetTexture(FLAT)
		self.separators[index] = separator
	end

	return separator
end

---@param frame Frame
---@param ids string[]
---@param rects table<string, LBBarRect>
function BarGroup:PlaceSeparators(frame, ids, rects)
	local layout = LB.Profile:Get("layout")
	local shown = 0

	if layout.mode == "SEGMENTED" then
		local border = LB.Profile:Get("appearance.border")
		local color = LB.Border:Color(border.style, border)

		for index = 1, #ids - 1 do
			local rect = rects[ids[index]]
			local separator = self:Separator(frame, index)

			separator:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
			separator:ClearAllPoints()
			separator:SetPoint("TOPLEFT", frame, "TOPLEFT", LB.Placement:ToPixel(rect.x + rect.width, LB:Pixel()), 0)
			LB:SetPixelSize(separator, SEPARATOR, rect.height)
			separator:Show()

			shown = index
		end
	end

	for index = shown + 1, #self.separators do
		self.separators[index]:Hide()
	end
end

---@param frame Frame
---@param ids string[]
---@param rects table<string, LBBarRect>
---@param override string?
function BarGroup:ApplyBorders(frame, ids, rects, override)
	local border = LB.Profile:Get("appearance.border")
	local style = override or border.style
	local grouped = LB.Profile:Get("layout.mode") == "SEGMENTED"
	local color = LB.Border:Color(style, border)

	self.border = self.border or LB.Border:Create(frame)
	self.border:Apply(grouped and style or "NONE", color, frame:GetHeight())

	for _, id in ipairs(ids) do
		local bar = self.bars[id]
		local rect = rects[id]

		if bar and rect then
			bar.border = bar.border or LB.Border:Create(bar)
			bar.border:Apply(grouped and "NONE" or style, color, rect.height)
		end
	end
end

---@param value number
---@return number value on the nearest physical pixel boundary
local function Snap(value)
	return LB.Placement:ToPixel(value, LB:Pixel())
end

---@param region Frame
---@param position LBFramePosition
local function PlaceOnScreen(region, position)
	local width, height = region:GetSize()
	local left, bottom = LB.Placement:Resolve(position, width, height, UIParent:GetWidth(), UIParent:GetHeight())
	local x = position.x + Snap(left) - left
	local y = position.y + Snap(bottom) - bottom

	region:SetPoint(position.point, UIParent, position.point, x, y)
end

---@param bar LBBar
---@param frame Frame
---@param rect LBBarRect
local function Place(bar, frame, rect)
	bar:SetGeometry(rect.width, rect.height)
	bar:ClearAllPoints()

	if rect.point then
		PlaceOnScreen(bar, { point = rect.point, x = rect.x, y = rect.y })

		return
	end

	bar:SetPoint("TOPLEFT", frame, "TOPLEFT", Snap(rect.x), -Snap(rect.y))
end

---@param animated boolean?
function BarGroup:ApplyLayout(animated)
	local frame = self.frame
	local driver = self.driver

	if not frame or not driver then
		return
	end

	local layout = LB.Profile:Get("layout")
	local ids = VisibleIds()
	local fullscreen = LB.Layout.Fullscreen(layout)
	local rects, groupWidth, groupHeight = self:ComputeLayout(ids, UIParent:GetWidth())

	frame:SetFrameStrata(layout.strata)
	frame:ClearAllPoints()

	if fullscreen then
		local edge = fullscreen == "TOP" and "TOPLEFT" or "BOTTOMLEFT"
		local other = fullscreen == "TOP" and "TOPRIGHT" or "BOTTOMRIGHT"

		frame:SetPoint(edge, UIParent, edge, 0, 0)
		frame:SetPoint(other, UIParent, other, 0, 0)
		LB:SetPixelHeight(frame, math.max(groupHeight, 1))
	else
		local position = layout.positions[layout.mode]

		LB:SetPixelSize(frame, math.max(groupWidth, 1), math.max(groupHeight, 1))
		PlaceOnScreen(frame, position)
	end

	for _, id in ipairs(ids) do
		self:Bar(frame, id)
	end

	self:ApplyBorders(frame, ids, rects, fullscreen and "NONE" or nil)

	local leadId = ids[1]

	for _, id in ipairs(ids) do
		if id == "xp" then
			leadId = "xp"
		end
	end

	local lead = leadId and self.bars[leadId] or nil

	LB.TextSlot:ApplyGroup(frame, lead, fullscreen)

	if not animated then
		LB:StopTween(driver)

		for id, rect in pairs(rects) do
			Place(self.bars[id], frame, rect)
			self.rects[id] = rect
		end

		self:PlaceSeparators(frame, ids, rects)
		self:Settled()

		return
	end

	local from = {}

	self.settling = true

	for id, rect in pairs(rects) do
		from[id] = self.rects[id] or { width = rect.width, height = rect.height, x = rect.x, y = rect.y }
	end

	LB:Tween(driver, REFLOW, function(eased)
		local stepped = {}

		for id, rect in pairs(rects) do
			local start = from[id]

			stepped[id] = {
				width = start.width + (rect.width - start.width) * eased,
				height = start.height + (rect.height - start.height) * eased,
				x = start.x + (rect.x - start.x) * eased,
				y = start.y + (rect.y - start.y) * eased,
				point = rect.point,
			}

			Place(self.bars[id], frame, stepped[id])
		end

		self:PlaceSeparators(frame, ids, stepped)
	end, function()
		for id, rect in pairs(rects) do
			self.rects[id] = rect
		end

		self:Settled()
	end)
end

---@param left number
---@param bottom number
---@param width number
---@param height number
---@param lock LBVerticalLock?
---@return LBFramePosition
local function Anchor(left, bottom, width, height, lock)
	return LB.Placement:Anchor(left, bottom, width, height, UIParent:GetWidth(), UIParent:GetHeight(), lock)
end

---@return LBEditTarget[] targets the group, or each shown bar in Independent mode
function BarGroup:EditTargets()
	local layout = LB.Profile:Get("layout")
	local frame = self.frame
	local targets = {}

	if not frame then
		return targets
	end

	if LB.Layout.Independent(layout) then
		for _, id in ipairs(LB.Preview:Ids()) do
			local bar = self.bars[id]

			if bar and bar:IsShown() then
				targets[#targets + 1] = {
					key = id,
					typeId = id,
					frame = bar,
					fixed = false,
					outline = bar.border,
					save = function(left, bottom, width, height)
						local independent = LB.Profile:Get("layout.independent")
						local entry = independent[id] or {}

						entry.position = Anchor(left, bottom, width, height)
						independent[id] = entry

						LB.Profile:Set("layout.independent", independent)
					end,
				}
			end
		end

		return targets
	end

	targets[1] = {
		key = "group",
		label = layout.mode == "CONNECTED" and L["Bar Stack"] or L["Progress Bars"],
		frame = frame,
		fixed = LB.Layout.Fullscreen(layout) ~= nil,
		outline = self.border,
		save = function(left, bottom, width, height)
			local current = LB.Profile:Get("layout")
			local lock = current.mode == "CONNECTED" and LB.Placement:StackLock(current.growth) or nil

			LB.Profile:Set("layout.positions." .. current.mode, Anchor(left, bottom, width, height, lock))
		end,
	}

	return targets
end

---Changes a connected stack's growth direction, keeping the lead bar where it is.
---@param growth "UP" | "DOWN"
function BarGroup:SetGrowth(growth)
	local layout = LB.Profile:Get("layout")
	local frame = self.frame

	if layout.growth == growth then
		return
	end

	local stacked = frame and layout.mode == "CONNECTED" and not LB.Layout.Fullscreen(layout)
	local left, bottom, _, total = nil, nil, nil, nil

	if frame and stacked then
		left, bottom, _, total = frame:GetRect()
	end

	LB.Profile:Set("layout.growth", growth)

	if left and bottom and total then
		local leadBottom = growth == "DOWN" and bottom or (bottom + total - layout.height)

		LB.Profile:Set(
			"layout.positions.CONNECTED",
			LB.Placement:Stack(
				left,
				leadBottom,
				layout.width,
				layout.height,
				total,
				growth,
				UIParent:GetWidth(),
				UIParent:GetHeight()
			)
		)
	end
end

function BarGroup:Settled()
	self.settling = false

	LB.TextSlot:Refit()
end

---@param animated boolean?
function BarGroup:Refresh(animated)
	local frame = self.frame

	if not frame then
		return
	end

	local ids = VisibleIds()
	local wanted = {}

	for _, id in ipairs(ids) do
		wanted[id] = true
	end

	for id, bar in pairs(self.bars) do
		if not wanted[id] and bar:IsShown() then
			local source = LB.Model:Source(id)

			self.rects[id] = nil
			LB.Gain:Release(bar)

			if source and source.atMaxLevel then
				bar:FadeOut()
			else
				bar:Hide()
			end
		end
	end

	self:ApplyLayout(animated)

	for _, id in ipairs(ids) do
		local snapshot = SnapshotFor(id)

		if snapshot then
			local bar = self:Bar(frame, id)
			local first = not bar:IsShown()

			bar:Appear()
			bar:ApplyAppearance()
			bar:SetSnapshot(snapshot, not first)
		end
	end

	self.hasBars = #ids > 0

	LB.Visibility:Refresh(animated)
end

---@param id string
function BarGroup:Update(id)
	local bar = self.bars[id]
	local snapshot = SnapshotFor(id)

	if bar and snapshot and bar:IsShown() then
		bar:SetSnapshot(snapshot, true, not LB.Preview:Covers(id))
		LB.Gain:OnProgress(bar)
	end
end

Callbacks:Register("Progress", BarGroup, function(_, id)
	BarGroup:Update(id)
end)

Callbacks:Register("Layout", BarGroup, function()
	BarGroup:Refresh(true)
end)

Callbacks:Register("Party", BarGroup, function()
	local bar = BarGroup.bars.xp

	if bar and bar:IsShown() then
		LB.Marker:Apply(bar)
	end
end)

Callbacks:Register("Settings", BarGroup, function(_, path, value)
	local placement = path == nil or (type(path) == "string" and path:find("^layout%.") ~= nil)

	BarGroup:Refresh(not placement)

	local spark = type(path) == "string" and path:find("^appearance%.spark") ~= nil
	local shimmer = path == "appearance.shimmer" and value == true

	if spark or shimmer then
		for _, bar in pairs(BarGroup.bars) do
			if bar:IsShown() then
				bar:Glint(shimmer)
			end
		end
	end
end)
