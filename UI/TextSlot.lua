local LB = select(2, ...)

local PADDING = 4
local GAP = 2
local SPACING = 6
local LAYER = 7
local TICK = 1
local FADE = 0.15 -- as the bars' own hover fade

---@class LBSlotAnchor
---@field host FramePoint
---@field own FramePoint
---@field x number
---@field y number
---@field justify "LEFT" | "CENTER" | "RIGHT"
---@field below boolean? hangs one line below its point while anchored by its own bottom edge
---@field span "LEFT" | "" | "RIGHT" | nil pinned by that side to the bar's top and bottom edges

---@type table<string, LBSlotAnchor>
local ANCHORS = {
	ABOVE_LEFT = { host = "TOPLEFT", own = "BOTTOMLEFT", x = 0, y = GAP, justify = "LEFT" },
	ABOVE_CENTER = { host = "TOP", own = "BOTTOM", x = 0, y = GAP, justify = "CENTER" },
	ABOVE_RIGHT = { host = "TOPRIGHT", own = "BOTTOMRIGHT", x = 0, y = GAP, justify = "RIGHT" },
	INSIDE_LEFT = { host = "LEFT", own = "LEFT", x = PADDING, y = 0, justify = "LEFT", span = "LEFT" },
	INSIDE_CENTER = { host = "CENTER", own = "CENTER", x = 0, y = 0, justify = "CENTER", span = "" },
	INSIDE_RIGHT = { host = "RIGHT", own = "RIGHT", x = -PADDING, y = 0, justify = "RIGHT", span = "RIGHT" },
	BELOW_LEFT = { host = "BOTTOMLEFT", own = "BOTTOMLEFT", x = 0, y = -GAP, justify = "LEFT", below = true },
	BELOW_CENTER = { host = "BOTTOM", own = "BOTTOM", x = 0, y = -GAP, justify = "CENTER", below = true },
	BELOW_RIGHT = { host = "BOTTOMRIGHT", own = "BOTTOMRIGHT", x = 0, y = -GAP, justify = "RIGHT", below = true },
}

local ROWS = {
	{ "ABOVE_LEFT", "ABOVE_CENTER", "ABOVE_RIGHT" },
	{ "INSIDE_LEFT", "INSIDE_CENTER", "INSIDE_RIGHT" },
	{ "BELOW_LEFT", "BELOW_CENTER", "BELOW_RIGHT" },
}

local INSIDE = { INSIDE_LEFT = true, INSIDE_CENTER = true, INSIDE_RIGHT = true }

---@class LBSlotEntry
---@field fontString FontString
---@field slot LBTextSlot
---@field text string the template the parts were compiled from
---@field parts LBTagPart[]
---@field time boolean the template uses a time tag
---@field filled boolean the rendered line has something in it

---@class LBTextHost
---@field frame Frame the frame the slots are placed around
---@field layer Frame
---@field strings table<string, FontString>
---@field drivers table<string, Frame> run each slot's hover fade
---@field entries table<string, LBSlotEntry> the slots this host currently draws
---@field typeId string? whose layout it draws
---@field bar LBBar? the bar whose data and hover drive it

---@class LBTextSlotRenderer
---@field hosts table<Frame, LBTextHost>
---@field group LBTextHost?
---@field ticker table?
---@field warned boolean
local TextSlot = {
	hosts = {},
	warned = false,
}
LB.TextSlot = TextSlot

---@param frame Frame
---@return LBTextHost
local function HostFor(frame)
	local host = TextSlot.hosts[frame]

	if not host then
		local layer = CreateFrame("Frame", nil, frame)

		layer:SetAllPoints(frame)

		host = { frame = frame, layer = layer, strings = {}, drivers = {}, entries = {} }
		TextSlot.hosts[frame] = host
	end

	host.layer:SetFrameLevel(frame:GetFrameLevel() + LAYER)

	return host
end

---@param host LBTextHost
---@param key string
---@return FontString
local function StringFor(host, key)
	local fontString = host.strings[key]

	if not fontString then
		fontString = host.layer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		fontString:SetWordWrap(false)
		fontString:SetMaxLines(1)
		host.strings[key] = fontString
	end

	return fontString
end

---How far the drawn border stands out past a bar's top and bottom edges, which the outer slots keep clear of.
---@param bar LBBar?
---@return number reach in UI units; 0 along a screen edge, where no border is drawn
function TextSlot:BorderReach(bar)
	local layout = LB.Profile:Get("layout")

	if LB.Layout.Fullscreen(layout) then
		return 0
	end

	local style = LB.Profile:Get("appearance.border.style")
	local height = bar and bar:GetHeight() or 0

	if height <= 0 then
		height = LB.Layout.Height(layout, LB.Border:FixedHeight(style))
	end

	return LB.Border:Outset(style, height)
end

---@param host LBTextHost
---@param keys table<string, true> the slots this host owns
---@param typeId string?
local function Configure(host, keys, typeId)
	local reach = TextSlot:BorderReach(host.bar)

	local slots = typeId and LB.Profile:Get("text.slots." .. typeId) or {}

	host.typeId = typeId

	for key, fontString in pairs(host.strings) do
		fontString:Hide()
		fontString:SetAlpha(1)
		host.entries[key] = nil
	end

	for _, driver in pairs(host.drivers) do
		LB:StopTween(driver)
		driver.visible = nil
	end

	for key in pairs(keys) do
		local slot = slots[key]

		if slot and slot.text and slot.text ~= "" and slot.visibility ~= "HIDDEN" then
			local fontString = StringFor(host, key)
			local anchor = ANCHORS[key]
			local style = LB.Profile:ResolveStyle(slot)
			local parts = LB.Tags:Compile(slot.text)

			LB.Media:SetFont(fontString, style)

			local color = style.color

			fontString:SetTextColor(color[1], color[2], color[3], color[4] or 1)
			fontString:SetJustifyH(anchor.justify)
			fontString:SetJustifyV("MIDDLE")
			fontString:ClearAllPoints()
			local pixel = LB:Pixel(host.frame)
			local x = LB.Placement:ToPixel(anchor.x + (slot.x or 0), pixel)
			local y = anchor.y + (slot.y or 0)

			if anchor.below then
				y = y - style.size - reach
			elseif not anchor.span then
				y = y + reach
			end

			y = LB.Placement:ToPixel(y, pixel)

			if anchor.span then
				local top = ("TOP" .. anchor.span) --[[@as FramePoint]]
				local bottom = ("BOTTOM" .. anchor.span) --[[@as FramePoint]]
				local room = LB.Placement:ToPixel(style.size, pixel)

				fontString:SetPoint(top, host.frame, top, x, y + room)
				fontString:SetPoint(bottom, host.frame, bottom, x, y - room)
			else
				fontString:SetPoint(anchor.own, host.frame, anchor.host, x, y)
			end

			host.entries[key] = {
				fontString = fontString,
				slot = slot,
				text = slot.text,
				parts = parts,
				time = LB.Tags:UsesTime(parts),
				filled = false,
			}
		end
	end
end

---@param entry LBSlotEntry
---@param snapshot LBSnapshot
---@param source LBSource?
---@return string
local function Render(entry, snapshot, source)
	local ok, text = pcall(LB.Tags.Render, LB.Tags, entry.parts, snapshot, source)

	if ok then
		return text
	end

	if not TextSlot.warned then
		TextSlot.warned = true
		LB:Warn("a text slot failed to render: %s", tostring(text))
	end

	return entry.text
end

---@param host LBTextHost
---@param onlyTime boolean? re-render only the slots with time tags
local function Draw(host, onlyTime)
	local bar = host.bar
	local snapshot = bar and bar.snapshot

	if not snapshot then
		return
	end

	local source = LB.Model:Source(bar.id)

	for _, entry in pairs(host.entries) do
		if not onlyTime or entry.time then
			local text = Render(entry, snapshot, source)

			entry.fontString:SetText(text)
			entry.filled = text ~= ""
		end
	end
end

---@param host LBTextHost
---@param key string
---@param hovered boolean
---@return boolean
local function Showing(host, key, hovered)
	local entry = host.entries[key]

	if not entry or not entry.filled then
		return false
	end

	local visibility = entry.slot.visibility

	return visibility == "ALWAYS" or (visibility == "HOVER" and hovered)
end

-- Center goes first, then right; the left is kept and cut off with an ellipsis if it is too wide on its own.
---@param host LBTextHost
---@param row string[]
---@param shown table<string, boolean>
local function Fit(host, row, shown)
	local inside = INSIDE[row[1]] == true
	local width = host.frame:GetWidth() - (inside and PADDING * 2 or 0)
	local left, center, right = row[1], row[2], row[3]

	---@param key string
	---@return number
	local function Measure(key)
		local entry = host.entries[key]

		if not shown[key] or not entry then
			return 0
		end

		entry.fontString:SetWidth(0)

		return entry.fontString:GetUnboundedStringWidth()
	end

	local l, c, r = Measure(left), Measure(center), Measure(right)

	if shown[center] then
		local half = (width - c) / 2

		if l + SPACING > half or r + SPACING > half then
			shown[center] = false
			c = 0
		end
	end

	if shown[left] and shown[right] and l + r + SPACING > width then
		shown[right] = false
		r = 0
	end

	for key, measured in pairs({ [left] = l, [center] = c, [right] = r }) do
		local entry = host.entries[key]

		if entry and shown[key] and measured > width then
			entry.fontString:SetWidth(math.max(width, 1))
		end
	end
end

---Shows or hides a slot's text. A hover-only slot fades when `fade` is set; otherwise, and whenever its host is not
---on screen, it snaps, unless a fade toward the same state is already running.
---@param host LBTextHost
---@param key string
---@param entry LBSlotEntry
---@param visible boolean
---@param fade boolean?
local function SetVisible(host, key, entry, visible, fade)
	local fontString = entry.fontString
	local driver = host.drivers[key]

	if not driver then
		driver = CreateFrame("Frame", nil, host.layer)
		host.drivers[key] = driver
	end

	local running = driver:GetScript("OnUpdate") ~= nil and host.layer:IsVisible()

	if running and driver.visible == visible then
		return
	end

	driver.visible = visible
	LB:StopTween(driver)

	if not fade or entry.slot.visibility ~= "HOVER" or not host.layer:IsVisible() then
		fontString:SetAlpha(1)
		fontString:SetShown(visible)

		return
	end

	if visible and not fontString:IsShown() then
		fontString:SetAlpha(0)
		fontString:Show()
	end

	local from = fontString:GetAlpha()
	local to = visible and 1 or 0

	LB:Tween(driver, FADE * math.abs(to - from), function(eased)
		fontString:SetAlpha(from + (to - from) * eased)
	end, function()
		if not visible then
			fontString:Hide()
			fontString:SetAlpha(1)
		end
	end)
end

---@param host LBTextHost
---@param hovered boolean
---@param fade boolean? hover-only slots fade rather than snap
local function Show(host, hovered, fade)
	local suppressed = host.bar and host.bar.textSuppressed and host ~= TextSlot.group

	for _, row in ipairs(ROWS) do
		local shown = {}

		for _, key in ipairs(row) do
			shown[key] = not suppressed and Showing(host, key, hovered)
		end

		Fit(host, row, shown)

		for _, key in ipairs(row) do
			local entry = host.entries[key]

			if entry then
				SetVisible(host, key, entry, shown[key] == true, fade)
			end
		end
	end
end

---@param host LBTextHost
---@return boolean
local function ShowsTime(host)
	for _, entry in pairs(host.entries) do
		if entry.time and entry.fontString:IsShown() then
			return true
		end
	end

	return false
end

function TextSlot:UpdateTicker()
	local needed = false

	for _, host in pairs(self.hosts) do
		if host.frame:IsVisible() and ShowsTime(host) then
			needed = true
		end
	end

	if needed and not self.ticker then
		self.ticker = C_Timer.NewTicker(TICK, function()
			for _, host in pairs(TextSlot.hosts) do
				if host.frame:IsVisible() and ShowsTime(host) then
					Draw(host, true)
				end
			end

			TextSlot:UpdateTicker()
		end)
	elseif not needed and self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end
end

---@return boolean
local function Independent()
	return LB.Layout.Independent(LB.Profile:Get("layout"))
end

---@return boolean hidden the bars are held too short for text inside them by their border style
function TextSlot:InsideHidden()
	return LB.Border:FixedHeight(LB.Profile:Get("appearance.border.style")) ~= nil
		and not LB.Layout.Fullscreen(LB.Profile:Get("layout"))
end

---@param key string a slot key
---@return boolean
function TextSlot:IsInside(key)
	return INSIDE[key] == true
end

---@param bar LBBar
function TextSlot:ApplyBar(bar)
	local host = HostFor(bar)
	local inside = not self:InsideHidden()
	local keys = {}

	for _, key in ipairs(LB.TextSlotKeys) do
		if INSIDE[key] then
			keys[key] = inside or nil
		elseif Independent() then
			keys[key] = true
		end
	end

	host.bar = bar
	Configure(host, keys, bar.id)
	Draw(host)
	Show(host, bar.hovered == true)
	self:UpdateTicker()
end

---Draws a bar's slots around it, whatever the layout mode, for a settings preview: all nine, or the six outside it
---while the bars are too short for text inside.
---@param bar LBBar a bar outside the bar group
---@param hovered boolean
---@return table<string, FontString> strings the shown slots' font strings, by slot key
function TextSlot:ApplySample(bar, hovered)
	local host = HostFor(bar)
	local inside = not self:InsideHidden()
	local keys = {}
	local shown = {}

	for _, key in ipairs(LB.TextSlotKeys) do
		keys[key] = inside or not INSIDE[key] or nil
	end

	bar.hovered = hovered
	host.bar = bar
	Configure(host, keys, bar.id)
	Draw(host)
	Show(host, hovered)

	for key, entry in pairs(host.entries) do
		if entry.fontString:IsShown() then
			shown[key] = entry.fontString
		end
	end

	return shown
end

---@param key string a slot key
---@return LBSlotAnchor
function TextSlot:Anchor(key)
	return ANCHORS[key]
end

-- In segmented and connected modes the six outer slots span the whole group and draw the lead type's layout.
---@param frame Frame
---@param lead LBBar? the bar whose layout and data the outer slots use; nil when the bars stand alone
---@param edge string? "TOP" or "BOTTOM" in fullscreen, whose side's slots would fall off the screen
function TextSlot:ApplyGroup(frame, lead, edge)
	local host = HostFor(frame)
	local keys = {}

	if lead and not Independent() then
		for _, key in ipairs(LB.TextSlotKeys) do
			local above = key:find("^ABOVE") ~= nil
			local below = key:find("^BELOW") ~= nil

			if (above and edge ~= "TOP") or (below and edge ~= "BOTTOM") then
				keys[key] = true
			end
		end
	end

	host.bar = lead
	self.group = host

	Configure(host, keys, lead and lead.id or nil)
	Draw(host)
	Show(host, LB.Visibility.state.hovered ~= nil)
	self:UpdateTicker()
end

---@param bar LBBar
function TextSlot:UpdateBar(bar)
	local host = self.hosts[bar]

	if host then
		Draw(host)
		Show(host, bar.hovered == true)
	end

	local group = self.group

	if group and group.bar == bar then
		Draw(group)
		Show(group, LB.Visibility.state.hovered ~= nil)
	end

	self:UpdateTicker()
end

---@param bar LBBar
---@param hovered boolean
function TextSlot:SetHovered(bar, hovered)
	local host = self.hosts[bar]

	if host then
		Show(host, hovered, true)
	end

	if self.group then
		Show(self.group, LB.Visibility.state.hovered ~= nil, true)
	end

	self:UpdateTicker()
end

---@param frame Frame a bar or the group
---@return number? top the highest shown text of that frame's slots, in screen pixels
---@return number? bottom the lowest
function TextSlot:Extent(frame)
	local host = self.hosts[frame]
	local top, bottom

	if not host then
		return nil, nil
	end

	for _, entry in pairs(host.entries) do
		local fontString = entry.fontString

		if fontString:IsVisible() then
			local scale = fontString:GetEffectiveScale()
			local stringTop, stringBottom = fontString:GetTop(), fontString:GetBottom()

			if stringTop and stringBottom then
				top = math.max(top or stringTop * scale, stringTop * scale)
				bottom = math.min(bottom or stringBottom * scale, stringBottom * scale)
			end
		end
	end

	return top, bottom
end

function TextSlot:Refit()
	for _, host in pairs(self.hosts) do
		if host == self.group then
			Show(host, LB.Visibility.state.hovered ~= nil)
		else
			Show(host, host.bar ~= nil and host.bar.hovered == true)
		end
	end

	self:UpdateTicker()
end

