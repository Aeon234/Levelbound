local LB = select(2, ...)

local FLAT = [[Interface\Buttons\WHITE8X8]]
local OUTLINE = 1
-- The pip is Blizzard's 10 x 14 rested tick, drawn from the top-left of a 32 x 32 file without an outline of ours;
-- its highlight art is 12 x 14, stretched to the pip as Blizzard draws it.
local PIP_ASPECT = 10 / 14
local PIP_COORDS = { 0, 20 / 32, 0, 28 / 32 }
local PIP_HIGHLIGHT_COORDS = { 0, 24 / 32, 0, 28 / 32 }
local FADE = 0.5
local OFFLINE_ALPHA = 0.4
local NEUTRAL = { 0.7, 0.7, 0.7 }

local SAMPLE_XP_MAX = 100000

local SAMPLE = {
	{ class = "MAGE", fraction = 0.18, level = 41, quest = 12500, rested = 42000, rate = 58000 / 3600 },
	{ class = "WARRIOR", fraction = 0.46, level = 42, quest = 12500, rate = 71000 / 3600 },
	{ class = "PRIEST", fraction = 0.49, level = 42 },
	{ class = "DRUID", fraction = 0.81, level = 43, offline = true },
}

---@class LBMarkerPlacement
---@field member LBRosterMember
---@field x number center of the marker, in bar coordinates

---@class LBMarker
---@field sample LBRosterMember[]?
local Marker = {}
LB.Marker = Marker

---@return LBRosterMember[]
local function SampleMembers()
	---@type LBRosterMember[]
	local members = {}

	for index, entry in ipairs(SAMPLE) do
		---@type LBPartyState
		local state = {
			sequence = 0,
			level = entry.level,
			xp = math.floor(entry.fraction * SAMPLE_XP_MAX),
			xpMax = SAMPLE_XP_MAX,
			flags = 0,
			atMaxLevel = false,
			rested = entry.rested,
			quest = entry.quest,
			rate = entry.rate,
		}
		---@type LBRosterMember
		local member = {
			name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.class] or entry.class,
			class = entry.class,
			state = state,
			offline = entry.offline == true,
			snapshot = LB.Roster.Snapshot(state),
		}

		members[index] = member
	end

	return members
end

---Returns where a marker attaches: its own point, the bar point it sits on, and whether its shape is drawn upside
---down. The full-height tick always centers on the bar; the notch points into the bar from the edge it sits on.
---@param style string
---@param anchor string "CENTER", "TOP" or "BOTTOM"
---@return string point
---@return string relativePoint
---@return boolean flipped
function Marker.Point(style, anchor)
	if style == "TICK" or (anchor ~= "TOP" and anchor ~= "BOTTOM") then
		return "CENTER", "LEFT", false
	elseif style == "NOTCH" then
		return anchor, anchor .. "LEFT", anchor == "BOTTOM"
	end

	return "CENTER", anchor .. "LEFT", false
end

---@class LBMarkerMetrics
---@field width number
---@field height number the full-height tick's is the bar's own, filled in when drawn
---@field anchor string
---@field y number

-- Blizzard's rested tick on its experience bar: 10 x 14, centered on the bar with Forever's offset of 0. The pip
-- marker takes these settings when it and the Blizzard border are first combined.
Marker.BLIZZARD_PIP = { size = 14, anchor = "CENTER", y = 0 }
local BLIZZARD_PIP_KEYS = { "size", "anchor", "y" }

---Calls `write` once for each party setting that puts the pip at Blizzard's rested tick, in a fixed order.
---@param write fun(key: string, value: any) `key` is relative to the party settings
function Marker.WriteBlizzardPip(write)
	for _, key in ipairs(BLIZZARD_PIP_KEYS) do
		write(key, Marker.BLIZZARD_PIP[key])
	end
end

---Returns the markers' size and placement from their settings; the pip keeps its 10:14 shape, its height the size.
---@param party LBPartySettings
---@return LBMarkerMetrics
function Marker.Metrics(party)
	local width = party.style == "PIP" and party.size * PIP_ASPECT or party.size

	return { width = width, height = party.size, anchor = party.anchor, y = party.y }
end

---@return LBMarkerMetrics
function Marker:Current()
	return Marker.Metrics(LB.Profile:Get("party"))
end

---Returns how far a marker reaches past the bar's top and bottom edges, outline included.
---@param style string
---@param anchor string
---@param y number ignored by the full-height tick
---@param size number
---@param height number the bar's height
---@return number above
---@return number below
function Marker.Reach(style, anchor, y, size, height)
	local half = size / 2
	local center

	if style == "TICK" then
		half, center = height / 2, height / 2
	else
		local point, relative = Marker.Point(style, anchor)
		local base = relative == "TOPLEFT" and height or relative == "BOTTOMLEFT" and 0 or height / 2

		center = base + y

		if point == "TOP" then
			center = center - half
		elseif point == "BOTTOM" then
			center = center + half
		end
	end

	if style ~= "PIP" then
		half = half + OUTLINE
	end

	return math.max(0, center + half - height), math.max(0, half - center)
end

---@param members LBRosterMember[] in a stable order
---@param width number
---@param size number
---@return LBMarkerPlacement[] placements sorted left to right
function Marker:Positions(members, width, size)
	local placed = {}

	for index, member in ipairs(members) do
		placed[index] = { member = member, x = (LB.Progress.Fraction(member.snapshot) or 0) * width }
	end

	table.sort(placed, function(a, b)
		if a.x == b.x then
			return a.member.name < b.member.name
		end

		return a.x < b.x
	end)

	for index = 2, #placed do
		local minimum = placed[index - 1].x + size

		if placed[index].x < minimum then
			placed[index].x = minimum
		end
	end

	local limit = width - size / 2

	for index = #placed, 1, -1 do
		if placed[index].x > limit then
			placed[index].x = limit
		end

		if index > 1 then
			local maximum = placed[index].x - size

			if placed[index - 1].x > maximum then
				placed[index - 1].x = maximum
			end
		end
	end

	for index = 1, #placed do
		placed[index].x = math.max(placed[index].x, size / 2)
	end

	return placed
end

---@param member LBRosterMember
---@return LBColor
local function ClassColor(member)
	local class = member.class

	if not class and member.unit then
		class = select(2, UnitClass(member.unit))
	end

	if issecretvalue(class) or not class then
		return NEUTRAL
	end

	local color = C_ClassColor.GetClassColor(class)

	if not color then
		return NEUTRAL
	end

	return { color.r, color.g, color.b }
end

---@param frame Frame
local function Reset(_, frame)
	frame:Hide()
	frame:ClearAllPoints()
	frame:SetAlpha(1)
	frame:SetScript("OnEnter", nil)
	frame:SetScript("OnLeave", nil)
	LB:StopTween(frame)

	frame.member = nil
	frame.bar = nil
	frame.placements = nil
	frame.x = nil
	frame.style = nil
	frame.barWidth = nil
	frame.point = nil
	frame.relativePoint = nil
	frame.offsetY = nil
end

---@param bar LBBar
---@return any pool
---@return table<string, Frame> shown the marker drawn for each member name
local function PoolFor(bar)
	---@type table<string, Frame>
	local shown = bar.markerShown or {}

	if not bar.markerPool then
		bar.markerLayer = CreateFrame("Frame", nil, bar)
		bar.markerLayer:SetAllPoints(bar)
		bar.markerLayer:SetScript("OnSizeChanged", function()
			if bar:IsShown() then
				LB.Marker:Apply(bar)
			end
		end)
		bar.markerPool = CreateFramePool("Frame", bar.markerLayer, nil, Reset)
	end

	bar.markerShown = shown

	return bar.markerPool, shown
end

---@param frame Frame
local function Build(frame)
	if frame.shape then
		return
	end

	frame.outline = frame:CreateTexture(nil, "BORDER")
	frame.shape = frame:CreateTexture(nil, "ARTWORK")
	frame.highlight = frame:CreateTexture(nil, "HIGHLIGHT")
	frame.highlight:SetTexture(LB.Media.textures.markerPipHighlight)
	frame.highlight:SetTexCoord(unpack(PIP_HIGHLIGHT_COORDS))
	frame.highlight:SetBlendMode("ADD")
	frame.highlight:SetAllPoints(frame)
end

---@param frame Frame
local function OnEnter(frame)
	local placements = frame.placements
	local member = frame.member

	if not placements or not member then
		return
	end

	local size = Marker:Current().width
	local anchor = nil

	for _, placement in ipairs(placements) do
		if placement.member == member then
			anchor = placement.x
		end
	end

	if not anchor then
		return
	end

	GameTooltip:SetOwner(frame, "ANCHOR_NONE")
	GameTooltip:ClearLines()

	for _, placement in ipairs(placements) do
		if math.abs(placement.x - anchor) < size then
			local other = placement.member

			LB.Tooltip:Member(GameTooltip, other, ClassColor(other))
		end
	end

	LB.Tooltip:Follow(frame, frame.bar and LB.Tooltip:Clearance(frame.bar))
end

---@param frame Frame
local function OnLeave(frame)
	LB.Tooltip:Hide(frame)
end

---@param frame Frame
---@param bar LBBar
---@param x number
local function Anchor(frame, bar, x)
	frame:ClearAllPoints()
	frame:SetPoint(frame.point, bar, frame.relativePoint, x, frame.offsetY)
	frame.x = x
end

---@param frame Frame
---@param bar LBBar
---@param x number
---@param style string
local function Place(frame, bar, x, style)
	local width = bar:GetWidth()
	local from = frame.x
	local glide = from ~= nil
		and from ~= x
		and width > 0
		and frame.style == style
		and frame.barWidth == width
		and frame:IsVisible()

	frame.style = style
	frame.barWidth = width

	LB:StopTween(frame)

	if not glide then
		Anchor(frame, bar, x)

		return
	end

	LB:Tween(frame, LB.Bar:FillDuration((x - from) / width), function(eased)
		Anchor(frame, bar, from + (x - from) * eased)
	end)
end

---@param frame Frame
---@param bar LBBar
---@param placement LBMarkerPlacement
---@param placements LBMarkerPlacement[]
local function Draw(frame, bar, placement, placements)
	local party = LB.Profile:Get("party")
	local metrics = Marker:Current()
	local member = placement.member
	local height = bar:GetHeight()
	local color = ClassColor(member)
	local style = party.style

	Build(frame)

	frame.member = member
	frame.bar = bar
	frame.placements = placements

	local tall = style == "TICK"
	local pip = style == "PIP"
	local markerHeight = tall and height or metrics.height

	LB:SetPixelSize(frame, metrics.width, markerHeight)

	local point, relativePoint, flipped = Marker.Point(style, metrics.anchor)

	frame.point, frame.relativePoint = point, relativePoint
	frame.offsetY = tall and 0 or metrics.y
	frame:SetFrameLevel(bar:GetFrameLevel() + 10)
	Place(frame, bar, placement.x, style)

	local texture = LB.Media.markerShapes[style]

	frame.shape:ClearAllPoints()
	frame.shape:SetAllPoints(frame)
	frame.outline:ClearAllPoints()
	frame.outline:SetPoint("TOPLEFT", frame, "TOPLEFT", -OUTLINE, OUTLINE)
	frame.outline:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", OUTLINE, -OUTLINE)

	if texture then
		frame.shape:SetTexture(texture)
		frame.outline:SetTexture(texture)
	else
		frame.shape:SetTexture(FLAT)
		frame.outline:SetTexture(FLAT)
	end

	local top, bottom = flipped and 1 or 0, flipped and 0 or 1

	if pip then
		frame.shape:SetTexCoord(unpack(PIP_COORDS))
	else
		frame.shape:SetTexCoord(0, 1, top, bottom)
	end

	frame.outline:SetTexCoord(0, 1, top, bottom)
	frame.outline:SetShown(not pip)
	frame.highlight:SetShown(pip)
	frame.shape:SetVertexColor(color[1], color[2], color[3], 1)
	frame.outline:SetVertexColor(0, 0, 0, 1)

	frame:SetAlpha(member.offline and OFFLINE_ALPHA or 1)

	frame:EnableMouse(bar.markerLayer.interactive ~= false)
	frame:SetScript("OnEnter", OnEnter)
	frame:SetScript("OnLeave", OnLeave)
	frame:Show()
end

---@param bar LBBar
---@param frame Frame
local function FadeAndRelease(bar, frame)
	local pool = bar.markerPool

	if not pool then
		return
	end

	local from = frame:GetAlpha()

	LB:Tween(frame, FADE, function(eased)
		frame:SetAlpha(from * (1 - eased))
	end, function()
		pool:Release(frame)
	end)
end

---@param bar LBBar
---@param members LBRosterMember[]? the members to mark; the party when nil
function Marker:Apply(bar, members)
	if bar.id ~= "xp" then
		return
	end

	local created = bar.markerLayer == nil
	local pool, shown = PoolFor(bar)
	local party = LB.Profile:Get("party")

	if not party.markers then
		pool:ReleaseAll()
		wipe(shown)

		return
	end

	-- A preview's members stay with its bar, so a redraw after a resize keeps them.
	if members then
		bar.markerMembers = members
	end

	members = members or bar.markerMembers or LB.Roster:Visible()
	local placements = self:Positions(members, bar:GetWidth(), self:Current().width)
	local wanted = {}

	for _, placement in ipairs(placements) do
		wanted[placement.member.name] = true
	end

	for name, frame in pairs(shown) do
		if not wanted[name] then
			shown[name] = nil

			local member = LB.Roster.members[name]

			if member and member.state.atMaxLevel then
				FadeAndRelease(bar, frame)
			else
				pool:Release(frame)
			end
		end
	end

	for _, placement in ipairs(placements) do
		local name = placement.member.name
		local frame = shown[name]

		if not frame then
			frame = pool:Acquire()
			shown[name] = frame
		end

		Draw(frame, bar, placement, placements)
	end

	if created then
		self:ApplyOpacity(false)
	end
end

---@param animated boolean?
function Marker:ApplyOpacity(animated)
	local bar = LB.BarGroup.bars.xp
	local layer = bar and bar.markerLayer

	if not layer then
		return
	end

	local opacity = LB.Profile:Get("party.opacity")
	local alpha = 1
	local fade = 1

	if not opacity.matchBar then
		local visibility = LB.Visibility

		alpha =
			visibility:ResolveMarkers(opacity, LB.Profile:Get("visibility"), visibility.state, bar.id)
		fade = bar.markerFade or 1
	end

	layer:SetIgnoreParentAlpha(not opacity.matchBar)
	bar.markerAlpha = alpha

	local interactive = alpha > 0

	if layer.interactive ~= interactive then
		layer.interactive = interactive

		for _, frame in pairs(bar.markerShown) do
			frame:EnableMouse(interactive)
		end
	end

	LB.Visibility:SetAlpha(layer, layer, alpha * fade, animated)
end

---@param bar LBBar
---@param factor number
function Marker:FollowFade(bar, factor)
	local layer = bar.markerLayer

	bar.markerFade = factor

	if not layer or not layer:IsIgnoringParentAlpha() then
		return
	end

	LB:StopTween(layer)
	layer:SetAlpha((bar.markerAlpha or 1) * factor)
end

function Marker:Refresh()
	local bar = LB.BarGroup.bars.xp

	if bar and bar:IsShown() then
		self:Apply(bar)
	end
end

---@return LBRosterMember[] the sample party
function Marker:SampleParty()
	self.sample = self.sample or SampleMembers()

	return self.sample
end

---@param bar LBBar
function Marker:Release(bar)
	if not bar.markerPool or not bar.markerShown then
		return
	end

	bar.markerPool:ReleaseAll()
	wipe(bar.markerShown)
	bar.markerMembers = nil
end

