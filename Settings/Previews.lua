local LB = select(2, ...)

local PAD = 8 -- room around the bars for borders and hit outlines
local APPEARANCE_GAP = 12
local COLUMN_GAP = 24
local MARKER_ROOM = 24 -- the largest marker size
local GAIN_AMOUNT = 1234
local SLOT_ROOM = 4 -- room above and below the bar beyond the text size, for outer slots
local GLINT_EVERY = 2
local GAIN_PAUSE = 0.5 -- between one looped gain's fade and the next
local ZONE_ALPHA = 0.3

local SLOT_KEYS = {}

for _, key in ipairs(LB.TextSlotKeys) do
	SLOT_KEYS[key] = true
end

---Draws each settings page's preview: sample bars made with Levelbound's own bar code and fixed sample values,
---never the bars on screen.
---@class LBSettingsPreviews
---@field bars table<string, LBBar> sample bars by progress type
---@field used table<string, boolean> the bars the current draw placed
---@field zones table<string, Frame> text slot boxes by slot key
---@field glint any? the ticker replaying the gain effect
---@field hover Frame? the mouse area over the markers sample's bar
---@field hovered boolean? the cursor is over the markers sample's bar
local Previews = {
	bars = {},
	used = {},
	zones = {},
}
LB.SettingsPreviews = Previews

-- Sample bars ----------------------------------------------------------------------------------------------

---@param sample Frame
function Previews:Begin(sample)
	wipe(self.used)

	for _, zone in pairs(self.zones) do
		zone:Hide()
	end

	if self.box then
		self.box:Hide()
	end

	if self.hover then
		self.hover:Hide()
	end

	self.sample = sample
end

function Previews:Finish()
	for id, bar in pairs(self.bars) do
		if not self.used[id] then
			LB.Gain:Release(bar)
			LB.Marker:Release(bar)
			bar:Hide()
		end
	end
end

---@return boolean fullscreen the bars stretch along a screen edge, which draws no borders
local function Fullscreen()
	return LB.Layout.Fullscreen(LB.Profile:Get("layout")) ~= nil
end

---Returns the sample bar of a progress type, drawn from the sample snapshot at the given size.
---@param id string
---@param width number
---@param height number
---@param borderStyle string? "NONE" to draw no border; the saved style when nil
---@return LBBar
function Previews:Bar(id, width, height, borderStyle)
	local sample = self.sample
	local bar = self.bars[id]

	if not bar then
		bar = LB.Bar:Create(sample, id)
		bar:EnableMouse(false)
		bar.border = LB.Border:Create(bar)
		self.bars[id] = bar
	end

	if bar:GetParent() ~= sample then
		bar:SetParent(sample)
	end

	self.used[id] = true
	bar.hovered = false
	bar.textSuppressed = nil
	bar:SetAlpha(1)
	bar:ClearAllPoints()
	bar:Show()
	bar:SetGeometry(width, height)
	bar:ApplyAppearance()
	bar:SetSnapshot(LB.Preview:Snapshot(id), false, false)
	LB.Marker:Release(bar)
	LB.Gain:Release(bar)

	local border = LB.Profile:Get("appearance.border")
	local style = borderStyle or (Fullscreen() and "NONE" or border.style)

	bar.border:Apply(style, LB.Border:Color(style, border), height)

	return bar
end

---@return number width
---@return number height
local function SharedSize()
	local layout = LB.Profile:Get("layout")

	return layout.width, layout.height
end

---@param id string
---@return number width
---@return number height
local function BarSize(id)
	local width, height = SharedSize()

	if LB.Layout.Independent(LB.Profile:Get("layout")) then
		local entry = LB.Profile:Get("layout.independent")[id]

		width = entry and entry.width or width
		height = entry and entry.height or height
	end

	return width, height
end

---@return number room above a bar for its gain indicator
local function GainRoom()
	return LB.Profile:Get("gain.text.size") * 2 + SLOT_ROOM * 2
end

---Places bars in a column from `top` down, `gap` apart, and returns the column's width and bottom.
---@param bars LBBar[]
---@param top number
---@param gap number
---@return number width
---@return number bottom
local function Column(bars, top, gap)
	local width, y = 0, top

	for index, bar in ipairs(bars) do
		if index > 1 then
			y = y + gap
		end

		bar:SetPoint("TOPLEFT", Previews.sample, "TOPLEFT", PAD, -y)
		width = math.max(width, bar:GetWidth())
		y = y + bar:GetHeight()
	end

	return width, y
end

---@return string[] the enabled progress types this client has
local function Types()
	local ids = {}

	for _, id in ipairs(LB.Preview:Ids()) do
		if LB.Model:Capable(id) then
			ids[#ids + 1] = id
		end
	end

	return ids
end

---@return string[] up to two types to show together: experience and one other
local function Pair()
	local ids = { "xp" }

	for _, id in ipairs(Types()) do
		if id ~= "xp" then
			ids[2] = id

			break
		end
	end

	return ids
end

---@param id string
---@return string? the setting a click on the bar's fill finds on its type page
local function FillSetting(id)
	if id == "xp" then
		return "gradientStart"
	elseif id ~= "reputation" then
		return "color"
	end
end

-- Page previews --------------------------------------------------------------------------------------------

---A progress type's bar with every text slot, its empty slots marked, and the gain indicator attached.
---@param id string
---@return table preview
local function TypePreview(id)
	return {
		Pick = function(key)
			if SLOT_KEYS[key] and LB.Settings.window then
				LB.SettingsText:Choose(id, key)
				LB.Settings.window:SetPreviewChosen(key)
				LB.Settings.window:RefreshPage()
			end
		end,
		Draw = function(sample, _, addPart)
			Previews:Begin(sample)

			local width, height = BarSize(id)
			local keys = LB.SettingsText:Keys(id)
			local outer = #keys > 3
			local zone = LB.Profile:Get("text.style.size") + SLOT_ROOM
			local above = math.max(outer and zone or 0, GainRoom())
			local below = outer and zone or 0
			local bar = Previews:Bar(id, width, height)

			bar:SetPoint("TOPLEFT", sample, "TOPLEFT", PAD, -(PAD + above))

			local fill = FillSetting(id)

			if fill then
				addPart(bar, fill)
			end

			LB.Gain:Hold(bar, GAIN_AMOUNT)
			LB.TextSlot:ApplySample(bar, true)

			for _, key in ipairs(keys) do
				addPart(Previews:Zone(bar, key, zone), "slot", false, key)
			end

			if LB.Settings.window then
				LB.Settings.window:SetPreviewChosen(LB.SettingsText:Chosen(id))
			end

			Previews:Finish()

			return width + PAD * 2, height + above + below + PAD * 2
		end,
	}
end

local ZONE_COLUMNS = { LEFT = 0, CENTER = 1, RIGHT = 2 }

---An outlined box showing the room a text slot has: a third of the bar's width, on the bar for the inside
---slots and above or below it for the others.
---@param bar LBBar
---@param key string
---@param height number the outer slots' box height
---@return Frame zone
function Previews:Zone(bar, key, height)
	local zone = self.zones[key]

	if not zone then
		zone = CreateFrame("Frame", nil, self.sample)
		zone.edges = {}

		for index = 1, 4 do
			local edge = zone:CreateTexture(nil, "OVERLAY")

			edge:SetColorTexture(1, 1, 1, ZONE_ALPHA)
			zone.edges[index] = edge
		end

		self.zones[key] = zone
	end

	if zone:GetParent() ~= self.sample then
		zone:SetParent(self.sample)
	end

	local row, column = key:match("^(%u+)_(%u+)$")
	local width = bar:GetWidth() / 3
	local x = ZONE_COLUMNS[column] * width
	local thickness = LB:Pixel(zone)
	local top, bottom, left, right = zone.edges[1], zone.edges[2], zone.edges[3], zone.edges[4]

	zone:ClearAllPoints()

	if row == "INSIDE" then
		zone:SetPoint("TOPLEFT", bar, "TOPLEFT", x, 0)
		zone:SetSize(width, bar:GetHeight())
	else
		-- Above and below boxes take their column's inside box's exact width.
		local inside = self:Zone(bar, "INSIDE_" .. column, height)

		if row == "ABOVE" then
			zone:SetPoint("BOTTOMLEFT", inside, "TOPLEFT")
			zone:SetPoint("BOTTOMRIGHT", inside, "TOPRIGHT")
		else
			zone:SetPoint("TOPLEFT", inside, "BOTTOMLEFT")
			zone:SetPoint("TOPRIGHT", inside, "BOTTOMRIGHT")
		end

		zone:SetHeight(height)
	end

	top:ClearAllPoints()
	top:SetPoint("TOPLEFT")
	top:SetPoint("TOPRIGHT")
	top:SetHeight(thickness)
	bottom:ClearAllPoints()
	bottom:SetPoint("BOTTOMLEFT")
	bottom:SetPoint("BOTTOMRIGHT")
	bottom:SetHeight(thickness)
	left:ClearAllPoints()
	left:SetPoint("TOPLEFT")
	left:SetPoint("BOTTOMLEFT")
	left:SetWidth(thickness)
	right:ClearAllPoints()
	right:SetPoint("TOPRIGHT")
	right:SetPoint("BOTTOMRIGHT")
	right:SetWidth(thickness)

	zone:SetFrameLevel(bar:GetFrameLevel() + 15)
	zone:Show()

	return zone
end

---Experience and one other bar, with the border, spark and background; the gain effect replays on a loop while
---the gain shimmer is on.
---@return table preview
local function AppearancePreview()
	local function StopGlint()
		if Previews.glint then
			Previews.glint:Cancel()
			Previews.glint = nil
		end
	end

	return {
		Stop = StopGlint,
		Draw = function(sample, _, addPart)
			StopGlint()
			Previews:Begin(sample)

			local width, height = SharedSize()
			local bars = {}

			for _, id in ipairs(Pair()) do
				local bar = Previews:Bar(id, width, height)

				bars[#bars + 1] = bar
				addPart(bar, "texture")
				addPart(bar.border, "borderStyle")
			end

			-- Apart by their borders' reach and a clear gap, so each bar reads on its own.
			local style = Fullscreen() and "NONE" or LB.Profile:Get("appearance.border.style")
			local gap = APPEARANCE_GAP + 2 * LB.Border:Outset(style, height)
			local columnWidth, bottom = Column(bars, PAD, gap)

			if LB.Profile:Get("appearance.shimmer") then
				local function Glint()
					for _, bar in ipairs(bars) do
						bar:Glint(true)
					end
				end

				Glint()
				Previews.glint = C_Timer.NewTicker(GLINT_EVERY, Glint)
			end

			Previews:Finish()

			return columnWidth + PAD * 2, bottom + PAD
		end,
	}
end

---A frame in the sample that detached notices and gain lines grow inside; the panel centers the sample.
---@param width number
---@param height number
---@return Frame box
function Previews:Box(width, height)
	local box = self.box

	if not box then
		box = CreateFrame("Frame", nil, self.sample)
		self.box = box
	end

	if box:GetParent() ~= self.sample then
		box:SetParent(self.sample)
	end

	box:ClearAllPoints()
	box:SetPoint("TOPLEFT", self.sample, "TOPLEFT", PAD, -PAD)
	box:SetSize(width, height)
	box:Show()

	return box
end

---Stops the looping gain samples, attached and detached.
local function StopGains()
	if Previews.gainLoop then
		Previews.gainLoop:Cancel()
		Previews.gainLoop = nil
	end

	LB.Gain:StopDetachedSample()
end

---Every enabled type's bar with its gain indicator playing on a loop, each arrow in its own tint; when
---detached, the detached stack playing instead, without the bars.
---@return table preview
local function GainPreview()
	return {
		Stop = StopGains,
		Draw = function(sample, _, addPart)
			StopGains()
			Previews:Begin(sample)

			local ids = Types()

			if LB.Profile:Get("gain.detached") and LB.Profile:Get("gain.enabled") then
				local width, height = LB.Gain:DetachedSize()

				LB.Gain:PlayDetachedSample(Previews:Box(width, height), ids)
				addPart(Previews.box, "direction")
				Previews:Finish()

				return width + PAD * 2, height + PAD * 2
			end

			local width, height = SharedSize()
			local room = GainRoom()
			local columns = #ids > 2 and 2 or 1
			local bars = {}
			local rows = math.ceil(#ids / columns)

			-- Two columns once there are more than two bars, filled row by row.
			for index, id in ipairs(ids) do
				local bar = Previews:Bar(id, width, height)
				local column = (index - 1) % columns
				local row = math.floor((index - 1) / columns)

				bar:SetPoint("TOPLEFT", sample, "TOPLEFT", PAD + column * (width + COLUMN_GAP),
					-(PAD + room + row * (height + room)))
				bars[#bars + 1] = bar
				addPart(bar, "tint." .. id)
			end

			local y = PAD + rows * (height + room)

			local function Play()
				for index, bar in ipairs(bars) do
					LB.Gain:Hold(bar, GAIN_AMOUNT * index, true)
				end
			end

			Play()
			Previews.gainLoop = C_Timer.NewTicker(LB.NoticeStack.DURATION + GAIN_PAUSE, Play)
			Previews:Finish()

			return columns * width + (columns - 1) * COLUMN_GAP + PAD * 2, y + PAD
		end,
	}
end

---Sets the sample markers' and bar's opacity as the experience bar on screen has them, hovered or not.
---@param bar LBBar
---@param animated boolean?
function Previews:ApplyMarkerOpacity(bar, animated)
	local layer = bar.markerLayer

	if not layer then
		return
	end

	local opacity = LB.Profile:Get("party.opacity")
	local settings = LB.Profile:Get("visibility")
	local visibility = {
		inCombat = false,
		hasTarget = false,
		blocked = false,
		hovered = self.hovered and "xp" or nil,
		editing = false,
	}
	local alpha = LB.Visibility:ResolveMarkers(opacity, settings, visibility, "xp", true)
	local barAlpha = opacity.matchBar and LB.Visibility:Resolve(settings, visibility, "xp") or 1

	layer:SetIgnoreParentAlpha(false)
	LB.Visibility:SetAlpha(layer, layer, opacity.matchBar and 1 or alpha, animated)
	LB.Visibility:SetAlpha(bar, self.hover, barAlpha, animated)
end

---Stops the markers sample's fades and forgets its hover.
local function StopMarkers()
	Previews.hovered = false

	if Previews.hover then
		LB:StopTween(Previews.hover)
	end

	local bar = Previews.bars.xp

	if bar and bar.markerLayer then
		LB:StopTween(bar.markerLayer)
	end
end

---Covers the sample bar with a mouse area that fades the markers as hovering the bar on screen does.
---@param bar LBBar
function Previews:Hover(bar)
	local hover = self.hover

	if not hover then
		hover = CreateFrame("Frame", nil, self.sample)
		hover:SetScript("OnEnter", function()
			Previews.hovered = true
			Previews:ApplyMarkerOpacity(hover.bar, true)
		end)
		hover:SetScript("OnLeave", function()
			-- A marker's hit area, drawn above this frame, takes the cursor while it is still over the bar.
			if hover:IsMouseOver() then
				return
			end

			Previews.hovered = false
			Previews:ApplyMarkerOpacity(hover.bar, true)
		end)
		self.hover = hover
	end

	if hover:GetParent() ~= self.sample then
		hover:SetParent(self.sample)
	end

	hover.bar = bar
	hover:ClearAllPoints()
	hover:SetAllPoints(bar)
	hover:SetFrameLevel(bar:GetFrameLevel() + 20)
	hover:EnableMouse(true)
	hover:Show()
end

---The experience bar with a sample party's markers, at the markers' opacity; hovering the bar fades them as on
---screen.
---@return table preview
local function MarkersPreview()
	return {
		Stop = StopMarkers,
		Draw = function(sample, _, addPart)
			Previews:Begin(sample)

			local width, height = SharedSize()
			local party = LB.Profile:Get("party")
			local above, below = LB.Marker.Reach(party.style, party.anchor, party.y, party.size, height)
			-- At least the largest marker's room, so changing the markers' size alone never rescales the bar.
			above, below = math.max(above, MARKER_ROOM), math.max(below, MARKER_ROOM)
			local bar = Previews:Bar("xp", width, height)

			bar:SetPoint("TOPLEFT", sample, "TOPLEFT", PAD, -(PAD + above))
			LB.Marker:Apply(bar, LB.Marker:SampleParty())
			Previews:Hover(bar)
			StopMarkers()
			Previews.hovered = Previews.hover:IsMouseOver()
			Previews:ApplyMarkerOpacity(bar, false)

			for _, marker in pairs(bar.markerShown or {}) do
				addPart(marker, "style")
			end

			Previews:Finish()

			return width + PAD * 2, height + above + below + PAD * 2
		end,
	}
end

---How far the notices reach above and below the bar, from where they attach and which way they stack.
---@param settings LBLevelUpSettings
---@param stack number a full stack's height
---@param height number the bar's height
---@return number above
---@return number below
local function NoticeRoom(settings, stack, height)
	local reach = stack + math.abs(settings.y)
	local top = settings.anchor:find("^TOP") ~= nil
	local up = settings.direction == "UP"

	if top and up then
		return reach, 0
	elseif not top and not up then
		return 0, reach
	elseif top then
		return 0, math.max(0, reach - height)
	end

	return math.max(0, reach - height), 0
end

---The experience bar with sample level-up notices arriving on a loop, placed as set; when detached, the
---notices alone in the middle of the preview.
---@return table preview
local function LevelUpsPreview()
	return {
		Stop = function()
			LB.LevelUpNotice:StopPreviewSample()
		end,
		Draw = function(sample, _, addPart)
			LB.LevelUpNotice:StopPreviewSample()
			Previews:Begin(sample)

			local settings = LB.Profile:Get("party.levelUp")
			local shown = settings.enabled and settings.onScreen
			local line = settings.text.size + 4
			local stack = line * 3

			if settings.detached then
				local width = SharedSize()
				local box = Previews:Box(width, stack)

				if shown then
					LB.LevelUpNotice:ShowPreviewSample(box, true)
					addPart(box, "font")
				end

				Previews:Finish()

				return width + PAD * 2, stack + PAD * 2
			end

			local width, height = SharedSize()
			local above, below = NoticeRoom(settings, stack, height)
			local bar = Previews:Bar("xp", width, height)

			bar:SetPoint("TOPLEFT", sample, "TOPLEFT", PAD + math.max(0, -settings.x), -(PAD + above))
			addPart(bar, "anchor")

			if shown then
				LB.LevelUpNotice:ShowPreviewSample(bar, true)
			end

			Previews:Finish()

			return width + math.abs(settings.x) + PAD * 2, above + height + below + PAD * 2
		end,
	}
end

---@param pageID string
---@return table? preview the page's preview, or nil for a page without one
function Previews:For(pageID)
	local typeID = pageID:match("^type%.(.+)$")

	if typeID then
		return TypePreview(typeID)
	elseif pageID == "layout" then
		return AppearancePreview()
	elseif pageID == "gain" then
		return GainPreview()
	elseif pageID == "markers" then
		return MarkersPreview()
	elseif pageID == "levelups" then
		return LevelUpsPreview()
	end
end
