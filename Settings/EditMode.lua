local LB = select(2, ...)

local L = LB.L

local FLAT = [[Interface\Buttons\WHITE8X8]]
local SNAP_DISTANCE = 8
local FADE_IN = 0.2
local SETTLE = 0.3
local TOOLBAR_HEIGHT = 42
local BUTTON_TEMPLATE = "MainMenuFrameButtonTemplate"
local BUTTON_WIDTH = 100
local BUTTON_HEIGHT = 32
local BUTTON_RATIO = 3
local DROPDOWN_WIDTH = 150
local GAP = 8
local GROUP_GAP = 24
local PAD = 16
local TOGGLE_ON = 0.6
local TOGGLE_OFF = 0.3
local TOGGLE_HOVER = 1
local SURFACE = { 0.06, 0.06, 0.07, 0.94 }
local OUTLINE = { 0.32, 0.32, 0.34, 1 }
local GUIDE = { 1, 0.82, 0, 0.9 }
local ACCENT = LB.Mover.accent

local GRID_SPACING = 32
local GRID_DIMMED, GRID_CENTRE_DIMMED = 0.15, 0.25
local GRID_BRIGHT, GRID_CENTRE_BRIGHT = 0.3, 0.5
local GRID_NEXT = { DIMMED = "BRIGHT", BRIGHT = "OFF", OFF = "DIMMED" }

local HOVER_FADE = 0.5

local TOOLBAR_INSET = 6
local SLOT_MARGIN = 4
local BOTTOM_RAISE = 200
local SCAN_STEP = 16
local SLOT_OFFSETS = { TOP = -TOOLBAR_INSET, BOTTOM = BOTTOM_RAISE, CENTER = 0 }
local HOVER_LEVEL = 100

local EXIT_POPUP = "LEVELBOUND_EDIT_EXIT"

StaticPopupDialogs[EXIT_POPUP] = {
	text = L["Save your layout changes?"],
	button1 = SAVE,
	button2 = CONTINUE,
	button3 = L["Discard"],
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	OnAccept = function()
		LB.EditMode:Save()
	end,
	OnAlt = function()
		LB.EditMode:Discard()
	end,
}

---@param a any
---@param b any
---@return boolean
local function Same(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return a == b
	end

	for key, value in pairs(a) do
		if not Same(value, b[key]) then
			return false
		end
	end

	for key in pairs(b) do
		if a[key] == nil then
			return false
		end
	end

	return true
end

---@param value number
---@param minimum number
---@param maximum number
---@return number
local function Clamp(value, minimum, maximum)
	return math.min(math.max(value, minimum), math.max(maximum, minimum))
end

---@return number width
---@return number height
local function Screen()
	return UIParent:GetWidth(), UIParent:GetHeight()
end

---@return number pixel the size of one physical pixel in UIParent's units
local function Pixel()
	return LB:Pixel()
end

---@param id string
---@return string
local function TypeLabel(id)
	return LB.Panels.typeLabels[id] or id
end

---@param mode string
---@return number line
---@return number centre
local function GridAlpha(mode)
	if mode == "BRIGHT" then
		return GRID_BRIGHT, GRID_CENTRE_BRIGHT
	end

	return GRID_DIMMED, GRID_CENTRE_DIMMED
end

---@return string label
---@return boolean on
local function GridState()
	local mode = LB.Profile:Global().editMode.grid

	if mode == "BRIGHT" then
		return L["Bright"], true
	elseif mode == "OFF" then
		return L["Off"], false
	end

	return L["Dimmed"], true
end

---@class LBEditTarget
---@field key string
---@field label string
---@field target Frame
---@field fixed boolean

---@class LBEditToolbar : Frame
---@field title FontString
---@field exit Button
---@field save Button
---@field mode table
---@field toggles LBEditToggle[]
---@field resume Button
---@field controls table[] disabled while combat pauses the session

---@class LBEditGrid : Frame
---@field lines Texture[]

---@class LBEditMode
---@field active boolean
---@field paused boolean combat interrupted the session
---@field inCombat boolean
---@field hidden boolean the settings window is in front of the layout
---@field closing boolean? the layout is fading out after Save or Exit
---@field dragging boolean? a mover is being dragged, so the toolbar stands aside
---@field toolbarSlot string? where the toolbar sits, as point and offsets, away from the movers
---@field fromSettings boolean? the session began from the settings window, so it ends there too
---@field previewAll boolean? Preview All Bars on for Independent mode
---@field snapshot LBProfileData? the profile as it was when the session began
---@field selected string?
---@field movers table<string, LBMover>
---@field toolbar LBEditToolbar?
---@field keyboard Frame?
---@field guides { x: Texture, y: Texture }?
---@field grid LBEditGrid?
---@field hoverZone Frame? notices the cursor over the hidden toolbar's place without taking its clicks
---@field hoverFade Frame? drives the toolbar's fade
---@field hoverWatch Frame? follows the cursor only while a concealable toolbar is showing
---@field driver Frame?
local EditMode = {
	active = false,
	paused = false,
	inCombat = false,
	hidden = false,
	movers = {},
}
LB.EditMode = EditMode

---@return boolean
function EditMode:IsActive()
	return self.active
end

---@return boolean showing movers are on screen and can be worked
function EditMode:Showing()
	return self.active and not self.paused and not self.hidden and not self.closing
end

function EditMode:Toggle()
	if self.active then
		self:RequestExit()

		return
	end

	self:Enter()
end

---@param fromSettings boolean? entered from the settings window, which Save and Exit then return to
function EditMode:Enter(fromSettings)
	if self.active or LB.failed or not LB.BarGroup.frame then
		return
	end

	if InCombatLockdown() then
		LB:Print(L["the layout cannot be edited in combat."])

		return
	end

	self:Build()

	self.active = true
	self.paused = false
	self.inCombat = false
	self.hidden = false
	self.snapshot = LB.Profile:Snapshot()
	self.selected = nil
	self.closing = false
	self.fromSettings = fromSettings == true
	self.dragging = false

	LB.Events:Register("PLAYER_REGEN_DISABLED", self, function()
		self:Pause()
	end)
	LB.Events:Register("PLAYER_REGEN_ENABLED", self, function()
		self.inCombat = false
		self:PaintToolbar()
	end)
	LB.Events:Register("PLAYER_LOGOUT", self, function()
		self:Discard()
	end)

	LB.Events:Register("GLOBAL_MOUSE_DOWN", self, function()
		if self:Showing() and not self:IsMouseOverLayout() then
			self:Deselect()
		end
	end)

	for _, event in ipairs({ "UI_SCALE_CHANGED", "DISPLAY_SIZE_CHANGED" }) do
		LB.Events:Register(event, self, function()
			LB.Events:Coalesce("editModeScale", function()
				if self:Showing() then
					self:RefreshMovers()
					self:RefreshGrid()
				end
			end)
		end)
	end

	LB.Visibility:SetEditing(true)
	LB.Preview:SetEditing(true)
	self:SyncPreview()

	if LB.Settings:IsOpen() then
		LB.Settings:Close()
	end

	self:ShowLayout()
	self:FadeIn()
end

---@return boolean
function EditMode:IsDirty()
	return self.snapshot ~= nil and not Same(self.snapshot, LB.Profile.active)
end

function EditMode:RequestExit()
	if not self.active then
		return
	end

	if self:IsDirty() then
		StaticPopup_Show(EXIT_POPUP)

		return
	end

	self:Exit()
end

function EditMode:Save()
	self.snapshot = nil

	self:Exit()
end

function EditMode:Discard()
	local snapshot = self.snapshot

	self.snapshot = nil

	if snapshot then
		LB.Profile:Restore(snapshot)
	end

	self:Exit()
end

---Fades the layout out the way it came in, then ends the session; one begun from settings returns there.
function EditMode:Exit()
	if not self.active or self.closing then
		return
	end

	local reopen = self.fromSettings == true and not self.hidden and not LB.Settings:IsOpen()
	local toolbar, driver = self.toolbar, self.driver

	LB.Events:UnregisterAll(self)
	StaticPopup_Hide(EXIT_POPUP)

	if self.hidden or not toolbar or not driver then
		self:Finish(reopen)

		return
	end

	self.closing = true

	LB.EditPanel:Hide()
	self:HideGuides()
	self:StopHover()

	if self.keyboard then
		self.keyboard:Hide()
	end

	local toolbarFrom = toolbar:IsShown() and toolbar:GetAlpha() or 0

	LB:Tween(driver, FADE_IN, function(eased)
		local alpha = 1 - eased

		toolbar:SetAlpha(toolbarFrom * alpha)

		if self.grid then
			self.grid:SetAlpha(alpha)
		end

		for _, mover in pairs(self.movers) do
			mover:SetAlpha(alpha)
		end
	end, function()
		self:Finish(reopen)
	end)
end

---@param reopen boolean
function EditMode:Finish(reopen)
	self.active = false
	self.paused = false
	self.hidden = false
	self.closing = false
	self.snapshot = nil
	self.fromSettings = nil

	if self.driver then
		LB:StopTween(self.driver)
	end

	self:HideLayout(false)

	local settingsOpen = LB.Settings:IsOpen() or reopen

	if not settingsOpen or self.previewAll then
		LB.Preview:Exit()
	end

	if not settingsOpen then
		LB.Gain:ClearPreview()
		LB.Marker:ClearPreview()
		LB.LevelUpNotice:ClearPreview()
	end

	self.previewAll = false

	LB.Preview:SetEditing(settingsOpen)
	LB.Visibility:SetEditing(settingsOpen)
	LB.Settings:PaintSession()
	LB.Settings:Refresh()

	if reopen then
		LB.Settings:Reveal(FADE_IN)
	end
end

function EditMode:Pause()
	self.inCombat = true

	if not self.active or self.paused then
		self:PaintToolbar()

		return
	end

	self.paused = true

	self:HideLayout(true)
	self:ApplyHover()
	self:PaintToolbar()

	LB:Print(L["layout editing is paused for combat."])
end

function EditMode:Resume()
	if not self.paused or self.inCombat or InCombatLockdown() then
		return
	end

	self.paused = false

	if not self.hidden then
		self:ShowLayout()
	end
end

---@param section string?
function EditMode:OpenSettings(section)
	LB.Settings:Open(section)
end

function EditMode:OnSettingsShown()
	if not self.active then
		return
	end

	self.hidden = true

	self:HideLayout(false)
end

function EditMode:OnSettingsHidden()
	if not self.active then
		return
	end

	self.hidden = false

	LB.Visibility:SetEditing(true)

	self:ShowLayout()
end

function EditMode:ShowLayout()
	local toolbar = self.toolbar

	if not toolbar then
		return
	end

	toolbar:Show()
	self:PaintToolbar()

	if self.paused then
		return
	end

	if self.keyboard then
		self.keyboard:Show()
	end

	self:RefreshMovers()
	self:RefreshGrid()
	self:ApplyHover()
end

---@param keepToolbar boolean
function EditMode:HideLayout(keepToolbar)
	for _, mover in pairs(self.movers) do
		mover:Hide()
	end

	LB.LevelUpNotice:SetEditing(false)
	LB.Gain:SetEditing(false)
	LB.EditPanel:Hide()

	if self.keyboard then
		self.keyboard:Hide()
	end

	self:HideGuides()

	if self.grid then
		self.grid:Hide()
	end

	self:StopHover()

	if self.toolbar and not keepToolbar then
		self.toolbar:Hide()
	end
end

function EditMode:FadeIn()
	local toolbar = self.toolbar
	local driver = self.driver

	if not toolbar or not driver then
		return
	end

	local fadeToolbar = not LB.Profile:Global().editMode.hoverBar

	LB:Tween(driver, FADE_IN, function(eased)
		if fadeToolbar then
			toolbar:SetAlpha(eased)
		end

		if self.grid then
			self.grid:SetAlpha(eased)
		end

		for _, mover in pairs(self.movers) do
			mover:SetAlpha(eased)
		end
	end)
end

---@return LBEditTarget[]
---@return table[] targets the bars' movers
local function BarTargets()
	local layout = LB.Profile:Get("layout")
	local group = LB.BarGroup.frame
	local targets = {}

	if not group then
		return targets
	end

	if layout.mode == "INDEPENDENT" then
		for _, id in ipairs(LB.Preview:Ids()) do
			local bar = LB.BarGroup.bars[id]

			if bar and bar:IsShown() then
				targets[#targets + 1] =
					{ key = id, label = TypeLabel(id), target = bar, fixed = false, outline = bar.border }
			end
		end

		return targets
	end

	targets[1] = {
		key = "group",
		label = layout.mode == "CONNECTED" and L["Bar Stack"] or L["Progress Bars"],
		target = group,
		fixed = layout.fullscreen ~= "OFF",
		outline = LB.BarGroup.border,
	}

	return targets
end

-- Notices detached from the bars, each one stack in its own box.
local NOTICES = {
	{ owner = "LevelUpNotice", label = L["Level-Up Notices"] },
	{ owner = "Gain", label = L["Gain Indicator"] },
}

---@param key string
---@return (LBLevelUpNotice | LBGain)? owner the notice a mover key belongs to
local function NoticeFor(key)
	for _, notice in ipairs(NOTICES) do
		local owner = LB[notice.owner]

		if owner.moverKey == key then
			return owner
		end
	end

	return nil
end

function EditMode:Targets()
	local targets = BarTargets()

	for _, notice in ipairs(NOTICES) do
		local owner = LB[notice.owner]
		local box = owner:DetachedBox()

		if box then
			targets[#targets + 1] = { key = owner.moverKey, label = notice.label, target = box, fixed = false }
		end
	end

	return targets
end

function EditMode:RefreshMovers()
	if not self:Showing() then
		return
	end

	local seen = {}

	LB.LevelUpNotice:SetEditing(true)
	LB.Gain:SetEditing(true)

	for _, target in ipairs(self:Targets()) do
		local mover = self.movers[target.key]

		if not mover then
			mover = LB.Mover:Create(target.key)
			self.movers[target.key] = mover
		end

		mover:Attach(target.target, target.fixed, target.outline)
		mover:Sync(Pixel())
		mover:SetLabel(target.label)
		mover:Show()

		seen[target.key] = true
	end

	for key, mover in pairs(self.movers) do
		if not seen[key] then
			mover:Hide()
		end
	end

	if self.selected and not seen[self.selected] then
		self.selected = nil
	end

	self:PaintSelection()
	self:PlaceToolbar()

	LB.Events:Merge("editPanel", SETTLE, function()
		if self:Showing() then
			self:SyncMovers()
			self:PlaceToolbar()
			LB.EditPanel:Refresh()
		end
	end)
end

---@param left number
---@param bottom number
---@param width number
---@param height number
---@return boolean taken a shown mover would sit under a toolbar placed here
function EditMode:SlotTaken(left, bottom, width, height)
	for _, mover in pairs(self.movers) do
		if mover:IsShown() then
			local moverLeft, moverBottom, moverWidth, moverHeight = mover:GetRect()

			if
				moverLeft
				and LB.Placement:Overlaps(
					left - SLOT_MARGIN,
					bottom - SLOT_MARGIN,
					width + SLOT_MARGIN * 2,
					height + SLOT_MARGIN * 2,
					moverLeft,
					moverBottom,
					moverWidth,
					moverHeight
				)
			then
				return true
			end
		end
	end

	return false
end

---@param width number
---@param height number
---@return number? left a spot no mover covers, scanning down the centre, then the left and right edges
---@return number? bottom
function EditMode:FreeSpot(width, height)
	local screenWidth, screenHeight = Screen()
	local pixel = Pixel()
	local columns = { (screenWidth - width) / 2, TOOLBAR_INSET, screenWidth - width - TOOLBAR_INSET }

	for _, left in ipairs(columns) do
		local bottom = screenHeight - TOOLBAR_INSET - height

		while bottom >= TOOLBAR_INSET do
			if not self:SlotTaken(left, bottom, width, height) then
				return LB.Placement:ToPixel(left, pixel), LB.Placement:ToPixel(bottom, pixel)
			end

			bottom = bottom - SCAN_STEP
		end
	end

	return nil, nil
end

---Keeps the toolbar off the movers: at the top, the screen's centre or raised off the bottom, whichever is free
---first, else the first free spot anywhere; a screen with none left keeps it raised off the bottom.
function EditMode:PlaceToolbar()
	local toolbar = self.toolbar

	if not toolbar or not self:Showing() or self.dragging then
		return
	end

	local screenWidth, screenHeight = Screen()
	local width, height = toolbar:GetWidth(), toolbar:GetHeight()
	local centred = (screenWidth - width) / 2
	local slots = {
		{ point = "TOP", bottom = screenHeight - TOOLBAR_INSET - height },
		{ point = "CENTER", bottom = (screenHeight - height) / 2 },
		{ point = "BOTTOM", bottom = BOTTOM_RAISE },
	}
	local point, x, y, bottom = "BOTTOM", 0, SLOT_OFFSETS.BOTTOM, BOTTOM_RAISE

	for _, slot in ipairs(slots) do
		if not self:SlotTaken(centred, slot.bottom, width, height) then
			point, x, y, bottom = slot.point, 0, SLOT_OFFSETS[slot.point], slot.bottom

			break
		end
	end

	if point == "BOTTOM" and self:SlotTaken(centred, BOTTOM_RAISE, width, height) then
		local left, free = self:FreeSpot(width, height)

		if left and free then
			point, x, y, bottom = "BOTTOMLEFT", left, free, free
		end
	end

	local placed = ("%s:%s:%s"):format(point, x, y)

	if placed == self.toolbarSlot then
		return
	end

	self.toolbarSlot = placed

	toolbar:ClearAllPoints()
	toolbar:SetPoint(point, UIParent, point, x, y)

	toolbar.resume:ClearAllPoints()

	if bottom < screenHeight / 2 then
		toolbar.resume:SetPoint("BOTTOM", toolbar, "TOP", 0, GAP)
	else
		toolbar.resume:SetPoint("TOP", toolbar, "BOTTOM", 0, -GAP)
	end
end

---The toolbar fades out of the way while a bar is dragged, so a bar can be taken right up to the screen edge.
function EditMode:BeginDrag()
	self.dragging = true

	self:StopHover()
	self:FadeToolbar(false)
end

function EditMode:EndDrag()
	self.dragging = false

	if not self:Showing() then
		return
	end

	self:PlaceToolbar()

	if LB.Profile:Global().editMode.hoverBar then
		self:ApplyHover()
	else
		self:FadeToolbar(true)
	end
end

function EditMode:SyncMovers()
	local pixel = Pixel()

	for _, mover in pairs(self.movers) do
		if mover:IsShown() then
			mover:Sync(pixel)
		end
	end
end

function EditMode:PaintSelection()
	for key, mover in pairs(self.movers) do
		mover:SetSelected(key == self.selected)
	end

	LB.EditPanel:Refresh()
end

---@param key string
function EditMode:Select(key)
	if not self.movers[key] then
		return
	end

	self.selected = key

	self:PaintSelection()
end

function EditMode:Deselect()
	if not self.selected then
		return
	end

	self.selected = nil

	self:PaintSelection()
end

---@return boolean over the cursor is on a mover or on the edit mode's own controls
function EditMode:IsMouseOverLayout()
	for _, mover in pairs(self.movers) do
		if mover:IsShown() and mover:IsMouseOver() then
			return true
		end
	end

	local panel = LB.EditPanel.frame
	local toolbar = self.toolbar

	return (panel ~= nil and panel:IsShown() and panel:IsMouseOver())
		or (toolbar ~= nil and toolbar:IsShown() and toolbar:IsMouseOver())
end

---@return LBMover?
function EditMode:Selected()
	local mover = self.selected and self.movers[self.selected]

	if mover and mover:IsShown() then
		return mover
	end

	return nil
end

---@param key string
---@return number x offset of the centre from the screen's centre
---@return number y
function EditMode:Position(key)
	local mover = self.movers[key]

	if not mover then
		return 0, 0
	end

	local left, bottom, width, height = mover:Rect()
	local screenWidth, screenHeight = Screen()

	return LB.Placement:Centre(left, bottom, width, height, screenWidth, screenHeight)
end

---@param mover LBMover
---@return LBSnapLines
function EditMode:SnapLines(mover)
	local screenWidth, screenHeight = Screen()
	local lines = { x = { 0, screenWidth / 2, screenWidth }, y = { 0, screenHeight / 2, screenHeight } }

	for _, other in pairs(self.movers) do
		if other ~= mover and other:IsShown() then
			local left, bottom, width, height = other:Rect()

			tinsert(lines.x, left)
			tinsert(lines.x, left + width / 2)
			tinsert(lines.x, left + width)
			tinsert(lines.y, bottom)
			tinsert(lines.y, bottom + height / 2)
			tinsert(lines.y, bottom + height)
		end
	end

	return lines
end

---@param mover LBMover
---@param left number
---@param bottom number
function EditMode:DragTo(mover, left, bottom)
	local _, _, width, height = mover:Rect()
	local screenWidth, screenHeight = Screen()
	local guideX, guideY = nil, nil

	if LB.Profile:Global().editMode.snap and not IsAltKeyDown() then
		left, bottom, guideX, guideY =
			LB.Placement:Snap(left, bottom, width, height, self:SnapLines(mover), SNAP_DISTANCE)
	end

	local pixel = Pixel()

	left = LB.Placement:ToPixel(Clamp(left, 0, screenWidth - width), pixel)
	bottom = LB.Placement:ToPixel(Clamp(bottom, 0, screenHeight - height), pixel)

	self:ShowGuides(guideX, guideY)
	self:MoveTarget(mover, left, bottom)
	LB.EditPanel:Refresh()
end

---@param mover LBMover
---@param left number
---@param bottom number
function EditMode:MoveTarget(mover, left, bottom)
	local target = mover.target

	if not target or mover.fixed then
		return
	end

	left, bottom = mover:TargetPoint(left, bottom)

	target:ClearAllPoints()
	target:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
	mover:Sync(Pixel())
end

---Stores where a mover's target now sits, anchored to the nearest screen point.
---@param key string
---@param left number
---@param bottom number
function EditMode:Commit(key, left, bottom)
	local mover = self.movers[key]

	if not mover or mover.fixed then
		return
	end

	local _, _, width, height = mover:Rect()
	local screenWidth, screenHeight = Screen()
	local layout = LB.Profile:Get("layout")

	local pixel = Pixel()

	left = LB.Placement:ToPixel(Clamp(left, 0, screenWidth - width), pixel)
	bottom = LB.Placement:ToPixel(Clamp(bottom, 0, screenHeight - height), pixel)

	self:MoveTarget(mover, left, bottom)

	left, bottom = mover:TargetPoint(left, bottom)
	width, height = mover.target:GetSize()

	local notice = NoticeFor(key)

	if notice then
		notice:SavePosition(LB.Placement:Anchor(left, bottom, width, height, screenWidth, screenHeight))
	elseif key == "group" then
		local lock = layout.mode == "CONNECTED" and LB.Placement:StackLock(layout.growth) or nil
		local position = LB.Placement:Anchor(left, bottom, width, height, screenWidth, screenHeight, lock)

		LB.Profile:Set("layout.positions." .. layout.mode, position)
	else
		local position = LB.Placement:Anchor(left, bottom, width, height, screenWidth, screenHeight)
		local independent = LB:CopyTable(layout.independent)
		local entry = independent[key] or {}

		entry.position = position
		independent[key] = entry

		LB.Profile:Set("layout.independent", independent)
	end

	LB.EditPanel:Refresh()
end

---@param dx number
---@param dy number
---@return boolean moved
function EditMode:Nudge(dx, dy)
	local mover = self:Selected()

	if not mover or mover.fixed then
		return false
	end

	local left, bottom = mover:Rect()
	local pixel = Pixel()

	local function Step(delta)
		if delta == 0 then
			return 0
		end

		local pixels = math.max(LB.Placement:Round(math.abs(delta) / pixel), 1)

		return (delta < 0 and -pixels or pixels) * pixel
	end

	self:Commit(mover.key, left + Step(dx), bottom + Step(dy))

	return true
end

---@param key string
---@param x number offset of the centre from the screen's centre
---@param y number
function EditMode:SetPosition(key, x, y)
	local mover = self.movers[key]

	if not mover then
		return
	end

	local _, _, width, height = mover:Rect()
	local screenWidth, screenHeight = Screen()
	local left, bottom = LB.Placement:FromCentre(x, y, width, height, screenWidth, screenHeight)

	self:Commit(key, left, bottom)
end

---Changes a connected stack's growth direction, keeping the lead bar where it is.
---@param growth "UP" | "DOWN"
function EditMode:SetGrowth(growth)
	local layout = LB.Profile:Get("layout")
	local frame = LB.BarGroup.frame

	if layout.growth == growth then
		return
	end

	local stacked = frame and layout.mode == "CONNECTED" and layout.fullscreen == "OFF"
	local left, bottom, _, total = nil, nil, nil, nil

	if frame and stacked then
		left, bottom, _, total = frame:GetRect()
	end

	LB.Profile:Set("layout.growth", growth)

	if left and bottom and total then
		local screenWidth, screenHeight = Screen()
		local leadBottom = growth == "DOWN" and bottom or (bottom + total - layout.height)

		LB.Profile:Set(
			"layout.positions.CONNECTED",
			LB.Placement:Stack(left, leadBottom, layout.width, layout.height, total, growth, screenWidth, screenHeight)
		)
	end
end

---@param key string
---@return boolean handled
function EditMode:OnKey(key)
	if key == "ESCAPE" then
		if Menu.GetManager():IsAnyMenuOpen() or StaticPopup_Visible(EXIT_POPUP) then
			return false
		end

		self:RequestExit()

		return true
	end

	local step = IsShiftKeyDown() and 10 or 1

	if key == "LEFT" then
		return self:Nudge(-step, 0)
	elseif key == "RIGHT" then
		return self:Nudge(step, 0)
	elseif key == "UP" then
		return self:Nudge(0, step)
	elseif key == "DOWN" then
		return self:Nudge(0, -step)
	end

	return false
end

---@param x number?
---@param y number?
function EditMode:ShowGuides(x, y)
	local guides = self.guides

	if not guides then
		return
	end

	local pixel = Pixel()

	if x then
		x = LB.Placement:ToPixel(x, pixel)

		guides.x:ClearAllPoints()
		guides.x:SetPoint("TOPLEFT", UIParent, "TOPLEFT", x, 0)
		guides.x:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, 0)
		guides.x:SetWidth(pixel)
		guides.x:Show()
	else
		guides.x:Hide()
	end

	if y then
		y = LB.Placement:ToPixel(y, pixel)

		guides.y:ClearAllPoints()
		guides.y:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, y)
		guides.y:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", 0, y)
		guides.y:SetHeight(pixel)
		guides.y:Show()
	else
		guides.y:Hide()
	end
end

function EditMode:HideGuides()
	self:ShowGuides(nil, nil)
end

---@param frame Frame
---@param from FramePoint
---@param to FramePoint
---@param horizontal boolean
local function Edge(frame, from, to, horizontal)
	local line = frame:CreateTexture(nil, "BORDER")

	line:SetTexture(FLAT)
	line:SetVertexColor(OUTLINE[1], OUTLINE[2], OUTLINE[3], OUTLINE[4])
	line:SetPoint(from)
	line:SetPoint(to)
	line:SetSnapToPixelGrid(false)
	line:SetTexelSnappingBias(0)

	if horizontal then
		line:SetHeight(Pixel())
	else
		line:SetWidth(Pixel())
	end
end

---@param frame Frame
function EditMode:Skin(frame)
	local background = frame:CreateTexture(nil, "BACKGROUND")

	background:SetTexture(FLAT)
	background:SetVertexColor(SURFACE[1], SURFACE[2], SURFACE[3], SURFACE[4])
	background:SetAllPoints()

	Edge(frame, "TOPLEFT", "TOPRIGHT", true)
	Edge(frame, "BOTTOMLEFT", "BOTTOMRIGHT", true)
	Edge(frame, "TOPLEFT", "BOTTOMLEFT", false)
	Edge(frame, "TOPRIGHT", "BOTTOMRIGHT", false)
end

---@param parent Frame
---@param text string
---@param onClick fun()
---@return Button
local function ToolbarButton(parent, text, onClick)
	local button = CreateFrame("Button", nil, parent, BUTTON_TEMPLATE)

	button:SetText(text)
	button:SetSize(math.max(button:GetTextWidth() + 40, BUTTON_WIDTH), BUTTON_HEIGHT)
	button:SetScript("OnClick", onClick)

	return button
end

---@class LBEditToggle : Button
---@field label FontString
---@field name string
---@field state fun(): string, boolean the state's name, and whether it counts as on
---@field hovered boolean?

---An EllesmereUI-style toolbar toggle: its name above its state, brighter while on or hovered.
---@param parent Frame
---@param name string
---@param state fun(): string, boolean
---@param onClick fun()
---@return LBEditToggle
local function Toggle(parent, name, state, onClick)
	---@type LBEditToggle
	local toggle = CreateFrame("Button", nil, parent)

	toggle.name = name
	toggle.state = state
	toggle.label = toggle:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	toggle.label:SetPoint("LEFT")
	toggle.label:SetJustifyH("LEFT")

	toggle:SetScript("OnClick", function()
		onClick()
		LB.EditMode:PaintToolbar()
	end)
	toggle:SetScript("OnEnter", function(self)
		self.hovered = true
		LB.EditMode:PaintToolbar()
	end)
	toggle:SetScript("OnLeave", function(self)
		self.hovered = false
		LB.EditMode:PaintToolbar()
	end)

	return toggle
end

---@param toggle LBEditToggle
local function PaintToggle(toggle)
	local text, on = toggle.state()
	local alpha = (toggle.hovered and toggle:IsEnabled()) and TOGGLE_HOVER or (on and TOGGLE_ON or TOGGLE_OFF)

	toggle.label:SetText(toggle.name .. "\n" .. text)
	toggle.label:SetTextColor(1, 1, 1, alpha)
	toggle:SetSize(toggle.label:GetStringWidth(), BUTTON_HEIGHT)
end

---@return LBEditToolbar
function EditMode:BuildToolbar()
	---@type LBEditToolbar
	local toolbar = CreateFrame("Frame", "LevelboundEditToolbar", UIParent)

	toolbar:SetFrameStrata("FULLSCREEN_DIALOG")
	toolbar:SetHeight(TOOLBAR_HEIGHT)
	toolbar:SetPoint("TOP", UIParent, "TOP", 0, -TOOLBAR_INSET)
	toolbar:EnableMouse(true)
	toolbar:Hide()

	local background = toolbar:CreateTexture(nil, "BACKGROUND")

	background:SetTexture(FLAT)
	background:SetVertexColor(SURFACE[1], SURFACE[2], SURFACE[3], SURFACE[4])
	background:SetAllPoints()

	local edge = LB.Border:Create(toolbar)

	edge:Apply("ROUNDED", LB.Border:Color("ROUNDED", { color = { 1, 1, 1, 1 } }), TOOLBAR_HEIGHT)

	toolbar.title = toolbar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	toolbar.title:SetPoint("CENTER")
	toolbar.title:SetJustifyH("CENTER")

	toolbar.exit = ToolbarButton(toolbar, L["Exit"], function()
		self:Discard()
	end)
	toolbar.save = ToolbarButton(toolbar, SAVE, function()
		self:Save()
	end)

	toolbar.mode = CreateFrame("DropdownButton", nil, toolbar, "WowStyle1DropdownTemplate")
	toolbar.mode:SetWidth(DROPDOWN_WIDTH)
	toolbar.mode:SetupMenu(function(_, root)
		for _, option in ipairs({
			{ "SEGMENTED", L["Segmented"] },
			{ "CONNECTED", L["Connected"] },
			{ "INDEPENDENT", L["Independent"] },
		}) do
			root:CreateRadio(option[2], function()
				return LB.Profile:Get("layout.mode") == option[1]
			end, function()
				LB.Profile:Set("layout.mode", option[1])
			end)
		end
	end)

	toolbar.toggles = {
		Toggle(toolbar, L["Snap"], function()
			local on = LB.Profile:Global().editMode.snap == true

			return on and L["Enabled"] or L["Disabled"], on
		end, function()
			local settings = LB.Profile:Global().editMode

			settings.snap = not settings.snap
		end),
		Toggle(toolbar, L["Grid Lines"], GridState, function()
			self:CycleGrid()
		end),
		Toggle(toolbar, L["Hover Top Bar"], function()
			local on = LB.Profile:Global().editMode.hoverBar == true

			return on and L["Enabled"] or L["Disabled"], on
		end, function()
			local settings = LB.Profile:Global().editMode

			settings.hoverBar = not settings.hoverBar

			self:ApplyHover()
		end),
	}

	toolbar.resume = ToolbarButton(toolbar, L["Resume Editing"], function()
		self:Resume()
	end)
	toolbar.resume:SetPoint("TOP", toolbar, "BOTTOM", 0, -GAP)
	toolbar.resume:Hide()

	toolbar.controls = { toolbar.exit, toolbar.save, toolbar.mode }

	for _, toggle in ipairs(toolbar.toggles) do
		toolbar.controls[#toolbar.controls + 1] = toggle
	end

	return toolbar
end

---Exit and the mode dropdown sit left of the centred title, the toggles and Save to its right, and the bar
---is as wide as its busier side needs so the title stays in the middle.
function EditMode:LayoutToolbar()
	local toolbar = self.toolbar

	if not toolbar then
		return
	end

	local toggles = 0

	for index, toggle in ipairs(toolbar.toggles) do
		PaintToggle(toggle)
		toggle:ClearAllPoints()

		if index == 1 then
			toggle:SetPoint("LEFT", toolbar.title, "RIGHT", GROUP_GAP, 0)
		else
			toggle:SetPoint("LEFT", toolbar.toggles[index - 1], "RIGHT", GAP * 2, 0)
		end

		toggles = toggles + toggle:GetWidth() + (index > 1 and GAP * 2 or 0)
	end

	local height = toolbar.mode:GetHeight()

	for _, button in ipairs({ toolbar.exit, toolbar.save }) do
		button:SetSize(math.max(button:GetTextWidth() + height, LB.Placement:Round(height * BUTTON_RATIO)), height)
	end

	toolbar.exit:ClearAllPoints()
	toolbar.exit:SetPoint("LEFT", PAD, 0)
	toolbar.save:ClearAllPoints()
	toolbar.save:SetPoint("RIGHT", -PAD, 0)

	local titleWidth = toolbar.title:GetStringWidth()
	local left = PAD + toolbar.exit:GetWidth() + GROUP_GAP + toolbar.mode:GetWidth() + GROUP_GAP
	local right = GROUP_GAP + toggles + GROUP_GAP + toolbar.save:GetWidth() + PAD
	local width = math.max(left, right) * 2 + titleWidth

	toolbar:SetWidth(width)

	local exitRight = PAD + toolbar.exit:GetWidth()
	local titleLeft = (width - titleWidth) / 2

	toolbar.mode:ClearAllPoints()
	toolbar.mode:SetPoint("CENTER", toolbar, "LEFT", (exitRight + titleLeft) / 2, 0)
end

function EditMode:PaintToolbar()
	local toolbar = self.toolbar

	if not toolbar then
		return
	end

	local locked = self.paused and self.inCombat
	local second = L["Edit Mode"]

	if self.paused then
		second = RED_FONT_COLOR:WrapTextInColorCode(self.inCombat and L["Paused for combat"] or L["Paused"])
	end

	toolbar.title:SetText(LB.title .. "\n" .. second)
	toolbar.resume:SetShown(self.paused and not self.inCombat)

	for _, control in ipairs(toolbar.controls) do
		control:SetEnabled(not locked)
	end

	toolbar.mode:GenerateMenu()

	self:LayoutToolbar()
end

---@return Frame
function EditMode:BuildKeyboard()
	local keyboard = CreateFrame("Frame", nil, UIParent)

	keyboard:SetSize(1, 1)
	keyboard:SetPoint("CENTER")
	keyboard:EnableKeyboard(true)
	keyboard:SetPropagateKeyboardInput(true)
	keyboard:SetScript("OnKeyDown", function(frame, key)
		if InCombatLockdown() then
			return
		end

		frame:SetPropagateKeyboardInput(not self:OnKey(key))
	end)
	keyboard:Hide()

	return keyboard
end

---@param parent Frame
---@return Texture
local function Guide(parent)
	local line = parent:CreateTexture(nil, "OVERLAY")

	line:SetTexture(FLAT)
	line:SetVertexColor(GUIDE[1], GUIDE[2], GUIDE[3], GUIDE[4])
	line:SetSnapToPixelGrid(false)
	line:SetTexelSnappingBias(0)
	line:Hide()

	return line
end

---@param grid LBEditGrid
---@param index integer
---@return Texture
local function GridLine(grid, index)
	local line = grid.lines[index]

	if not line then
		line = grid:CreateTexture(nil, "BACKGROUND")
		line:SetTexture(FLAT)
		line:SetSnapToPixelGrid(false)
		line:SetTexelSnappingBias(0)
		grid.lines[index] = line
	end

	return line
end

---Lines one physical pixel wide, GRID_SPACING pixels apart, counted out from a brighter centre cross.
function EditMode:RefreshGrid()
	local grid = self.grid

	if not grid then
		return
	end

	local mode = LB.Profile:Global().editMode.grid

	if not self:Showing() or mode == "OFF" then
		grid:Hide()

		return
	end

	local pixel = Pixel()
	local spacing = GRID_SPACING * pixel
	local width, height = Screen()
	local centreX = LB.Placement:ToPixel(width / 2, pixel)
	local centreY = LB.Placement:ToPixel(height / 2, pixel)
	local alpha, centreAlpha = GridAlpha(mode)
	local count = 0

	---@param vertical boolean
	---@param at number
	---@param a number
	local function Line(vertical, at, a)
		count = count + 1

		local line = GridLine(grid, count)

		line:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], a)
		line:ClearAllPoints()

		if vertical then
			line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", at, 0)
			line:SetSize(pixel, height)
		else
			line:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 0, at)
			line:SetSize(width, pixel)
		end

		line:Show()
	end

	for offset = spacing, math.max(width, height), spacing do
		if centreX - offset > 0 then
			Line(true, LB.Placement:ToPixel(centreX - offset, pixel), alpha)
		end

		if centreX + offset < width then
			Line(true, LB.Placement:ToPixel(centreX + offset, pixel), alpha)
		end

		if centreY - offset > 0 then
			Line(false, LB.Placement:ToPixel(centreY - offset, pixel), alpha)
		end

		if centreY + offset < height then
			Line(false, LB.Placement:ToPixel(centreY + offset, pixel), alpha)
		end
	end

	Line(true, centreX, centreAlpha)
	Line(false, centreY, centreAlpha)

	for index = count + 1, #grid.lines do
		grid.lines[index]:Hide()
	end

	grid:Show()
end

function EditMode:CycleGrid()
	local settings = LB.Profile:Global().editMode

	settings.grid = GRID_NEXT[settings.grid] or "BRIGHT"

	self:RefreshGrid()
end

---@return boolean over the cursor is where the toolbar should stay visible
function EditMode:IsHoveringToolbar()
	local zone, toolbar = self.hoverZone, self.toolbar

	return (zone ~= nil and zone:IsMouseOver())
		or (toolbar ~= nil and toolbar:IsShown() and toolbar:IsMouseOver())
		or Menu.GetManager():IsAnyMenuOpen()
end

---@param shown boolean
function EditMode:FadeToolbar(shown)
	local toolbar, fade = self.toolbar, self.hoverFade

	if not toolbar or not fade then
		return
	end

	local from = toolbar:IsShown() and toolbar:GetAlpha() or 0
	local to = shown and 1 or 0

	if shown then
		toolbar:SetAlpha(from)
		toolbar:Show()
	end

	LB:Tween(fade, HOVER_FADE * math.abs(to - from), function(eased)
		toolbar:SetAlpha(from + (to - from) * eased)
	end, function()
		if not shown then
			toolbar:Hide()
		end
	end)
end

function EditMode:WatchHover()
	local watch = self.hoverWatch

	if not watch then
		return
	end

	watch:SetScript("OnUpdate", function()
		if not self:IsHoveringToolbar() then
			watch:SetScript("OnUpdate", nil)
			self:FadeToolbar(false)
		end
	end)
end

function EditMode:RevealToolbar()
	self:FadeToolbar(true)
	self:WatchHover()
end

function EditMode:StopHover()
	if self.hoverWatch then
		self.hoverWatch:SetScript("OnUpdate", nil)
	end

	if self.hoverFade then
		LB:StopTween(self.hoverFade)
	end

	if self.hoverZone then
		self.hoverZone:Hide()
	end
end

---Hover Top Bar applies only while the layout is being worked; a paused session keeps its toolbar in view.
function EditMode:ApplyHover()
	local toolbar, zone = self.toolbar, self.hoverZone

	if not toolbar or not zone then
		return
	end

	if not (self:Showing() and LB.Profile:Global().editMode.hoverBar) then
		self:StopHover()

		if self.active and not self.hidden then
			toolbar:SetAlpha(1)
			toolbar:Show()
		end

		return
	end

	zone:Show()

	if self:IsHoveringToolbar() then
		self:RevealToolbar()
	else
		self:FadeToolbar(false)
	end
end

---@return Frame
function EditMode:BuildHoverZone()
	local zone = CreateFrame("Frame", nil, UIParent)

	zone:SetAllPoints(self.toolbar)
	zone:SetFrameStrata("DIALOG")
	zone:SetFrameLevel(HOVER_LEVEL)
	zone:SetMouseMotionEnabled(true)
	zone:SetMouseClickEnabled(false)
	zone:SetScript("OnEnter", function()
		if self:Showing() and LB.Profile:Global().editMode.hoverBar then
			self:RevealToolbar()
		end
	end)
	zone:Hide()

	return zone
end

function EditMode:Build()
	if self.toolbar then
		return
	end

	local overlay = CreateFrame("Frame", nil, UIParent)

	overlay:SetAllPoints(UIParent)
	overlay:SetFrameStrata("FULLSCREEN")

	---@type LBEditGrid
	local grid = CreateFrame("Frame", nil, UIParent)

	grid:SetAllPoints(UIParent)
	grid:SetFrameStrata("BACKGROUND")
	grid:SetFrameLevel(1)
	grid:Hide()
	grid.lines = {}

	self.grid = grid
	self.guides = { x = Guide(overlay), y = Guide(overlay) }
	self.driver = CreateFrame("Frame")
	self.keyboard = self:BuildKeyboard()
	self.toolbar = self:BuildToolbar()
	self.hoverZone = self:BuildHoverZone()
	self.hoverFade = CreateFrame("Frame")
	self.hoverWatch = CreateFrame("Frame")
end

function EditMode:SyncPreview()
	local independent = LB.Profile:Get("layout.mode") == "INDEPENDENT"

	if independent and not LB.Preview:IsActive() then
		self.previewAll = true
		LB.Preview:Enter()
	elseif not independent and self.previewAll then
		self.previewAll = false
		LB.Preview:Exit()
	end
end

LB.Callbacks:Register("Settings", EditMode, function()
	if EditMode.active then
		EditMode:SyncPreview()
		EditMode:RefreshMovers()
		EditMode:PaintToolbar()
	end
end)

LB.Callbacks:Register("Layout", EditMode, function()
	if EditMode.active then
		EditMode:RefreshMovers()
	end
end)
