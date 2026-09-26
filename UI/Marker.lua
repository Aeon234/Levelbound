local LB = select(2, ...)

local FLAT = [[Interface\Buttons\WHITE8X8]]
local OUTLINE = 1
local FADE = 0.5
local OFFLINE_ALPHA = 0.4
local NEUTRAL = { 0.7, 0.7, 0.7 }

local SAMPLE_XP_MAX = 100000

local SAMPLE = {
	{ class = "MAGE", fraction = 0.18, level = 41, quest = 12500, rested = 42000, rate = 58000 },
	{ class = "WARRIOR", fraction = 0.46, level = 42, quest = 12500, rate = 71000 },
	{ class = "PRIEST", fraction = 0.49, level = 42 },
	{ class = "DRUID", fraction = 0.81, level = 43, offline = true },
}

---@class LBMarkerPlacement
---@field member LBRosterMember
---@field x number centre of the marker, in bar coordinates

---@class LBMarker
---@field previewing boolean?
---@field sample LBRosterMember[]?
local Marker = {}
LB.Marker = Marker

---@return LBRosterMember[]
local function SampleMembers()
	---@type LBRosterMember[]
	local members = {}

	for index, entry in ipairs(SAMPLE) do
		---@type LBRosterMember
		local member = {
			name = LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[entry.class] or entry.class,
			class = entry.class,
			state = {
				sequence = 0,
				level = entry.level,
				xp = math.floor(entry.fraction * SAMPLE_XP_MAX),
				xpMax = SAMPLE_XP_MAX,
				flags = 0,
				atMaxLevel = false,
				rested = entry.rested,
				quest = entry.quest,
				rate = entry.rate,
			},
			offline = entry.offline == true,
			fraction = entry.fraction,
		}

		members[index] = member
	end

	return members
end

---@param members LBRosterMember[] in a stable order
---@param width number
---@param size number
---@return LBMarkerPlacement[] placements sorted left to right
function Marker:Positions(members, width, size)
	local placed = {}

	for index, member in ipairs(members) do
		placed[index] = { member = member, x = member.fraction * width }
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
end

---@param frame Frame
local function OnEnter(frame)
	local placements = frame.placements
	local member = frame.member

	if not placements or not member then
		return
	end

	local size = LB.Profile:Get("party.size")
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

	if frame.style == "NOTCH" then
		frame:SetPoint("TOP", bar, "TOPLEFT", x, 0)
	else
		frame:SetPoint("CENTER", bar, "LEFT", x, 0)
	end

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
	local member = placement.member
	local size = party.size
	local height = bar:GetHeight()
	local color = ClassColor(member)
	local style = party.style

	Build(frame)

	frame.member = member
	frame.bar = bar
	frame.placements = placements

	local tall = style == "TICK"
	local markerHeight = tall and height or size

	LB:SetPixelSize(frame, size, markerHeight)

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
function Marker:Apply(bar)
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

	local members = self.previewing and self.sample or LB.Roster:Visible()
	local placements = self:Positions(members, bar:GetWidth(), party.size)
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
			visibility:ResolveMarkers(opacity, LB.Profile:Get("visibility"), visibility.state, bar.id, self.previewing)
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

function Marker:Preview()
	if not LB.Settings:IsOpen() then
		self:ClearPreview()

		return
	end

	self.previewing = true
	self.sample = self.sample or SampleMembers()

	self:Refresh()
	self:ApplyOpacity(true)
end

function Marker:ClearPreview()
	if not self.previewing then
		return
	end

	self.previewing = false

	self:Refresh()
	self:ApplyOpacity(true)
end

---@param bar LBBar
function Marker:Release(bar)
	if not bar.markerPool or not bar.markerShown then
		return
	end

	bar.markerPool:ReleaseAll()
	wipe(bar.markerShown)
end
