local LB = select(2, ...)

local FLAT = [[Interface\Buttons\WHITE8X8]]
local GLOW_SCALE = 2.3
local OUTLINE = 1
local FADE = 0.5
local OFFLINE_ALPHA = 0.4
local NEUTRAL = { 0.7, 0.7, 0.7 }

---@class LBMarkerPlacement
---@field member LBRosterMember
---@field x number centre of the marker, in bar coordinates

---@class LBMarker
local Marker = {}
LB.Marker = Marker

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
	if not member.unit then
		return NEUTRAL
	end

	local _, class = UnitClass(member.unit)

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
	frame.placements = nil
end

---@param bar LBBar
---@return any pool
---@return table<string, Frame> shown the marker drawn for each member name
local function PoolFor(bar)
	---@type table<string, Frame>
	local shown = bar.markerShown or {}

	if not bar.markerPool then
		bar.markerPool = CreateFramePool("Frame", bar, nil, Reset)
	end

	bar.markerShown = shown

	return bar.markerPool, shown
end

---@param frame Frame
local function Build(frame)
	if frame.shape then
		return
	end

	frame.glow = frame:CreateTexture(nil, "BACKGROUND")
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

	GameTooltip:SetOwner(frame, "ANCHOR_CURSOR")
	GameTooltip:ClearLines()

	for _, placement in ipairs(placements) do
		if math.abs(placement.x - anchor) < size then
			local other = placement.member

			GameTooltip:AddDoubleLine(other.name, ("%s %d"):format(LEVEL, other.state.level), 1, 1, 1, 1, 0.82, 0)
		end
	end

	GameTooltip:Show()
end

local function OnLeave()
	GameTooltip:Hide()
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
	frame.placements = placements

	local tall = style == "TICK"
	local markerHeight = tall and height or size

	PixelUtil.SetSize(frame, size, markerHeight)

	frame:SetFrameLevel(bar:GetFrameLevel() + 10)
	frame:ClearAllPoints()

	if style == "NOTCH" then
		frame:SetPoint("TOP", bar, "TOPLEFT", placement.x, 0)
	else
		frame:SetPoint("CENTER", bar, "LEFT", placement.x, 0)
	end

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

	if party.glow then
		frame.glow:ClearAllPoints()
		frame.glow:SetTexture(texture or FLAT)
		frame.glow:SetVertexColor(color[1], color[2], color[3], party.glowOpacity)
		PixelUtil.SetSize(frame.glow, size * GLOW_SCALE, markerHeight * (tall and 1 or GLOW_SCALE))

		-- The triangle's visual centre is its centroid, not the middle of its box.
		if style == "NOTCH" then
			frame.glow:SetPoint("TOP", frame, "TOP", 0, 0)
		else
			frame.glow:SetPoint("CENTER", frame, "CENTER", 0, 0)
		end

		frame.glow:Show()
	else
		frame.glow:Hide()
	end

	frame:SetAlpha(member.offline and OFFLINE_ALPHA or 1)

	frame:EnableMouse(true)
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

	local pool, shown = PoolFor(bar)
	local party = LB.Profile:Get("party")

	if not party.markers then
		pool:ReleaseAll()
		wipe(shown)

		return
	end

	local members = LB.Roster:Visible()
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

	self:SetHovered(bar, bar.hovered == true)
end

---@param bar LBBar
---@param hovered boolean
function Marker:SetHovered(bar, hovered)
	local shown = bar.markerShown

	if not shown then
		return
	end

	local visible = LB.Profile:Get("party.visibility") == "ALWAYS" or hovered

	for _, frame in pairs(shown) do
		frame:SetShown(visible)
	end
end

---@param bar LBBar
function Marker:Release(bar)
	if not bar.markerPool or not bar.markerShown then
		return
	end

	bar.markerPool:ReleaseAll()
	wipe(bar.markerShown)
end
