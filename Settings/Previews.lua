local LB = select(2, ...)

local PAD = 8 -- room around the bars for borders and hit outlines
local APPEARANCE_GAP = 12
local GAIN_AMOUNT = 1234
local SLOT_ROOM = 4 -- room above and below the bar beyond the text size, for outer slots
local GLINT_EVERY = 2
local GAIN_PAUSE = 0.5 -- between one looped gain's fade and the next
local ZONE_ALPHA = 0.3

-- Preview bars take a fixed width, so a very wide or narrow setting never crowds the sample; their height is real.
local PREVIEW_WIDTH = 480
local GAIN_WIDTH = 190 -- the Gain Indicator page's bars, up to four to a row
local GAIN_HEIGHT = 12
local GAIN_COLUMNS = 4
local GAIN_COLUMN_GAP = 16

-- The largest values the settings allow, from which each page's preview takes a fixed height.
local BAR_MAX = LB.LIMITS.barHeight.max
local TEXT_MAX = LB.LIMITS.textSize.max
local BORDER_PIXELS_MAX = LB.LIMITS.borderWidth.max
local MARKER_SIZE_MAX = LB.LIMITS.markerSize.max
local MARKER_OFFSET_MAX = LB.LIMITS.markerOffset.max
local NOTICE_LINES = 3

local BORDER_HIT = 4 -- the least ring around a bar that finds its border setting, with or without a border
local SPARK_HIT = 12 -- the width at the fill's end that finds the spark setting

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
---@field inner Frame? the frame each preview draws into, centered in the panel's sample and scaled to fit
---@field areas table<LBBar, table<string, Frame>> click areas around each sample bar, by kind
local Previews = {
	areas = {},
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

	for _, areas in pairs(self.areas) do
		for _, area in pairs(areas) do
			area:Hide()
		end
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
	bar:SetEndMasks(LB.Border:EndMask(style), true, true)

	return bar
end

---@return number? height the border style's fixed bar height, or nil
local function FixedHeight()
	return LB.Border:FixedHeight(LB.Profile:Get("appearance.border.style"))
end

---An empty frame placed around part of a sample bar, so a click there finds that part's setting.
---@param bar LBBar
---@param kind "border" | "spark" | "gain"
---@param reach number? the border ring's width, or the gain area's height
---@return Frame area
function Previews:Area(bar, kind, reach)
	local areas = self.areas[bar] or {}
	local area = areas[kind]

	self.areas[bar] = areas

	if not area then
		area = CreateFrame("Frame", nil, self.sample)
		areas[kind] = area
	end

	if area:GetParent() ~= self.sample then
		area:SetParent(self.sample)
	end

	area:ClearAllPoints()

	if kind == "border" then
		area:SetPoint("TOPLEFT", bar, "TOPLEFT", -reach, reach)
		area:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", reach, -reach)
	elseif kind == "spark" then
		area:SetPoint("TOPLEFT", bar.clip, "TOPRIGHT", -SPARK_HIT / 2, 0)
		area:SetPoint("BOTTOMLEFT", bar.clip, "BOTTOMRIGHT", -SPARK_HIT / 2, 0)
		area:SetWidth(SPARK_HIT)
	else
		area:SetPoint("BOTTOMLEFT", bar, "TOPLEFT")
		area:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT")
		area:SetHeight(reach)
	end

	area:Show()

	return area
end

---Hides a sample bar's text, which belongs to the progress type pages.
---@param bar LBBar
function Previews:Bare(bar)
	bar.textSuppressed = true
	LB.TextSlot:UpdateBar(bar)
end

---@return number width the preview's fixed bar width
---@return number height the bars' real height
local function SharedSize()
	return PREVIEW_WIDTH, LB.Layout.Height(LB.Profile:Get("layout"), FixedHeight())
end

---@param id string
---@return number width
---@return number height
local function BarSize(id)
	local width, height = SharedSize()

	if LB.Layout.Independent(LB.Profile:Get("layout")) then
		local entry = LB.Profile:Get("layout.independent")[id]

		height = LB.Layout.Height(LB.Profile:Get("layout"), FixedHeight(), entry and entry.height)
	end

	return width, height
end

---@return number room above a bar for its gain indicator, which keeps clear of the border
local function GainRoom()
	return LB.Profile:Get("gain.text.size") * 2 + SLOT_ROOM * 2 + LB.TextSlot:BorderReach(nil)
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
			local keys = LB.SettingsText:Usable(id)
			local outer = #keys > 3
			local zone = LB.Profile:Get("text.style.size") + SLOT_ROOM
			local reach = outer and LB.TextSlot:BorderReach(nil) or 0
			local above = math.max(outer and zone + reach or 0, GainRoom())
			local below = outer and zone + reach or 0
			local bar = Previews:Bar(id, width, height)

			bar:SetPoint("TOPLEFT", sample, "TOPLEFT", PAD, -(PAD + above))

			local fill = FillSetting(id)

			if fill then
				addPart(bar, fill)
			end

			LB.Gain:Hold(bar, GAIN_AMOUNT)
			LB.TextSlot:ApplySample(bar, true)

			for _, key in ipairs(keys) do
				addPart(Previews:Zone(bar, key, zone), ("slotText.%s.%s"):format(id, key), false, key)
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
		-- Clear of the border, as the slots' text is.
		local inside = self:Zone(bar, "INSIDE_" .. column, height)
		local reach = LB.TextSlot:BorderReach(bar)

		if row == "ABOVE" then
			zone:SetPoint("BOTTOMLEFT", inside, "TOPLEFT", 0, reach)
			zone:SetPoint("BOTTOMRIGHT", inside, "TOPRIGHT", 0, reach)
		else
			zone:SetPoint("TOPLEFT", inside, "BOTTOMLEFT", 0, -reach)
			zone:SetPoint("TOPRIGHT", inside, "BOTTOMRIGHT", 0, -reach)
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

				Previews:Bare(bar)
				bars[#bars + 1] = bar

				-- Later parts win where they overlap: the ring finds the border, the fill the texture and the fill's
				-- end the spark.
				local style = Fullscreen() and "NONE" or LB.Profile:Get("appearance.border.style")
				local ring = math.max(LB.Border:Outset(style, height), BORDER_HIT)

				addPart(Previews:Area(bar, "border", ring), "borderStyle")
				addPart(bar, "texture")
				addPart(Previews:Area(bar, "spark"), "spark")
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

			-- Short bars, up to four to a row: this page is about the arrows, not the bars.
			local width, height = GAIN_WIDTH, LB.Border:HeldHeight() or GAIN_HEIGHT
			local room = GainRoom()
			local columns = math.max(math.min(#ids, GAIN_COLUMNS), 1)
			local bars = {}
			local rows = math.ceil(#ids / columns)

			for index, id in ipairs(ids) do
				local bar = Previews:Bar(id, width, height)
				local column = (index - 1) % columns
				local row = math.floor((index - 1) / columns)

				bar:SetPoint("TOPLEFT", sample, "TOPLEFT", PAD + column * (width + GAIN_COLUMN_GAP),
					-(PAD + room + row * (height + room)))
				bars[#bars + 1] = bar
				addPart(bar, "tint." .. id)
				addPart(Previews:Area(bar, "gain", room), "tint." .. id)
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

			return columns * width + (columns - 1) * GAIN_COLUMN_GAP + PAD * 2, y + PAD
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
		Previews.hover:SetScript("OnUpdate", nil)
		LB:StopTween(Previews.hover)
	end

	local bar = Previews.bars.xp

	if bar and bar.markerLayer then
		LB:StopTween(bar.markerLayer)
	end
end

---Clears the markers sample's hover and fades the markers back.
---@param hover Frame
local function Unhover(hover)
	hover:SetScript("OnUpdate", nil)
	Previews.hovered = false
	Previews:ApplyMarkerOpacity(hover.bar, true)
end

---Covers the sample bar with a mouse area that fades the markers as hovering the bar on screen does.
---@param bar LBBar
function Previews:Hover(bar)
	local hover = self.hover

	if not hover then
		hover = CreateFrame("Frame", nil, self.sample)
		hover:SetScript("OnEnter", function()
			hover:SetScript("OnUpdate", nil)
			Previews.hovered = true
			Previews:ApplyMarkerOpacity(hover.bar, true)
		end)
		hover:SetScript("OnLeave", function()
			-- A marker's hit area, drawn above this frame, takes the cursor while it is still over the bar.
			if hover:IsMouseOver() then
				-- The cursor can leave the bar from that hit area, which sends this frame no event, so watch for it
				-- until the cursor leaves the bar or comes back to this frame.
				hover:SetScript("OnUpdate", function()
					if not hover:IsMouseOver() then
						Unhover(hover)
					end
				end)

				return
			end

			Unhover(hover)
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
			local metrics = LB.Marker:Current()
			local above, below = LB.Marker.Reach(party.style, metrics.anchor, metrics.y, metrics.height, height)
			-- At least the largest marker's room, so changing the markers' size alone never rescales the bar.
			above, below = math.max(above, MARKER_SIZE_MAX), math.max(below, MARKER_SIZE_MAX)
			local bar = Previews:Bar("xp", width, height)

			Previews:Bare(bar)
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

			Previews:Bare(bar)
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

-- Fixed heights ---------------------------------------------------------------------------------------------

---@return number the farthest any border style can reach past a bar
local function ReachMax()
	local pixel = BORDER_PIXELS_MAX * LB:Pixel()

	return math.max(pixel, LB.Border:Outset("METALLIC", BAR_MAX), LB.Border:Outset("BLIZZARD", BAR_MAX))
end

---@return number room above a bar for the largest gain indicator
local function GainRoomMax()
	return TEXT_MAX * 2 + SLOT_ROOM * 2 + ReachMax()
end

-- Each page's sample height with every setting at its largest.
local FIXED = {
	type = function()
		return PAD * 2 + BAR_MAX + GainRoomMax() + TEXT_MAX + SLOT_ROOM + ReachMax()
	end,
	layout = function()
		return PAD * 2 + BAR_MAX * 2 + APPEARANCE_GAP + ReachMax() * 2
	end,
	gain = function()
		-- Rows for every type this client can track, enabled or not, so the height holds as types are switched.
		local capable = 0

		for _, id in ipairs(LB.Model:Order()) do
			if LB.Model:Capable(id) then
				capable = capable + 1
			end
		end

		local rows = math.max(math.ceil(capable / GAIN_COLUMNS), 1)

		return PAD * 2 + rows * (GAIN_HEIGHT + GainRoomMax())
	end,
	markers = function()
		local above = LB.Marker.Reach("DIAMOND", "TOP", MARKER_OFFSET_MAX, MARKER_SIZE_MAX, BAR_MAX)

		return PAD * 2 + BAR_MAX + math.max(above, MARKER_SIZE_MAX) * 2
	end,
	levelups = function()
		return PAD * 2 + BAR_MAX + NOTICE_LINES * (TEXT_MAX + 4)
	end,
}

---Holds a preview at its page's fixed height: the drawing is centered in it, and shrinks only when its settings
---carry it past that height, so the panel never changes size.
---@param preview table
---@param height fun(): number
---@return table preview
local function Framed(preview, height)
	local draw = preview.Draw

	preview.Draw = function(sample, state, addPart)
		local inner = Previews.inner

		if not inner then
			inner = CreateFrame("Frame", nil, sample)
			Previews.inner = inner
		end

		if inner:GetParent() ~= sample then
			inner:SetParent(sample)
		end

		inner:SetScale(1)
		inner:Show()

		local width, drawn = draw(inner, state, addPart)
		local fixed = height()
		local scale = drawn > fixed and fixed / drawn or 1

		inner:SetScale(scale)
		inner:SetSize(width, drawn)
		inner:ClearAllPoints()
		inner:SetPoint("CENTER", sample, "CENTER")

		return width * scale, fixed
	end

	return preview
end

---@param pageID string
---@return table? preview the page's preview, or nil for a page without one
function Previews:For(pageID)
	local typeID = pageID:match("^type%.(.+)$")

	if typeID then
		return Framed(TypePreview(typeID), FIXED.type)
	elseif pageID == "layout" then
		return Framed(AppearancePreview(), FIXED.layout)
	elseif pageID == "gain" then
		return Framed(GainPreview(), FIXED.gain)
	elseif pageID == "markers" then
		return Framed(MarkersPreview(), FIXED.markers)
	elseif pageID == "levelups" then
		return Framed(LevelUpsPreview(), FIXED.levelups)
	end
end
