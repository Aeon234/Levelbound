local LB = select(2, ...)

-- Development only: the .toc loads this file inside a do-not-package block and .pkgmeta ignores Dev.
-- `/lb demo` drives every shown bar and a sample party with simulated progress for screenshots and
-- recordings. The simulation feeds the real sources and roster, so bars, overlays, gain indicators,
-- markers, tooltips and level-up notices animate through their normal paths. The bars wear the Modern
-- look for the run, and a second experience bar above them wears the Blizzard look, fed the same progress
-- and party; each is titled. Nothing is saved, and party messages are not sent while it runs.

local DEMO_EVENT = "LEVELBOUND_DEMO"

local START_LEVEL = 42
local BASE_MAX = 85000
local MAX_GROWTH = 1.04

local KILL_EVERY = { 2, 5 }
local KILL_SHARE = { 0.02, 0.04 }
local OBJECTIVE_CHANCE = 0.3
local OBJECTIVE_SHARE = { 0.03, 0.07 }
local TURN_IN_EVERY = { 25, 45 }
local NEW_QUEST_SHARE = { 0.04, 0.09 }
local RESTED_REFILL = 0.35

local OTHER_EVERY = { 5, 14 }
local OTHER_SHARE = { 0.01, 0.04 }

local MEMBER_EVERY = { 2, 5 }
local MEMBER_KILL_SHARE = { 0.04, 0.08 }
local MEMBER_TURN_IN_CHANCE = 0.15
local MEMBER_TURN_IN_SHARE = { 0.08, 0.15 }
local MEMBER_IDLE_CHANCE = 0.05
local MEMBER_OFFLINE_CHANCE = 0.03
local MEMBER_OFFLINE_FOR = { 15, 30 }
local MEMBER_SEED_SECONDS = 900

local MEMBERS = {
	{ name = "Aerinwyn", class = "MAGE", level = 41, fraction = 0.55, rested = 0.2, rate = 52000 },
	{ name = "Brakkus", class = "WARRIOR", level = 42, fraction = 0.30, rested = 0, rate = 68000 },
	{ name = "Seraphel", class = "PRIEST", level = 42, fraction = 0.71, rested = 0.4, rate = 47000 },
	{ name = "Thornwick", class = "DRUID", level = 43, fraction = 0.08, rested = 0, rate = 61000 },
}

local OVERRIDDEN = { "Read", "OnEvent", "IsAvailable" }

local MIRROR_NAME = "LevelboundDemoMirror"
local MIRROR_GAP = 64 -- between the bars and the Blizzard look's bar: the Modern bar's text, a title and its gains
local TITLE_GAP = 2 -- a title's gap from its bar, the gain indicator's own
local TITLE_SIZE = 14
local DEMO_WIDTH = 700
local GOLD = { 1, 0.82, 0 }

---@param range number[] lower and upper bound
---@return number
local function Between(range)
	return range[1] + math.random() * (range[2] - range[1])
end

---@param level integer
---@return integer
local function XPMax(level)
	return math.floor(BASE_MAX * MAX_GROWTH ^ (level - START_LEVEL))
end

---@class LBDemoPlayer
---@field level integer
---@field cur number
---@field max number
---@field rested number
---@field quest number completed quest XP
---@field incomplete number incomplete quest XP

---@class LBDemoOther
---@field cur number
---@field max number
---@field level integer?

---@class LBDemoMember
---@field name string
---@field class string
---@field state LBPartyState
---@field gained number
---@field seed number XP counted for the seeded pace

---@class LBDemo
---@field active boolean
---@field started number
---@field timers table<string, any>
---@field saved table<LBSource, table<string, function>>
---@field savedComms table<string, function>
---@field savedReconcile function?
---@field player LBDemoPlayer
---@field others table<string, LBDemoOther>
---@field members LBDemoMember[]
---@field mirror Frame? holds the other look's experience bar
---@field mirrorBar LBBar?
---@field mirrorProfile LBProfileData? the Blizzard look's settings, read while its bar draws
---@field savedProfile LBProfileData? the player's own profile, set aside while the bars wear the Modern look
---@field titles FontString[]?
local Demo = {
	active = false,
	started = 0,
	timers = {},
	saved = {},
	savedComms = {},
	others = {},
	members = {},
}

---@param key string
---@param range number[] seconds
---@param work fun()
function Demo:Schedule(key, range, work)
	self.timers[key] = C_Timer.NewTimer(Between(range), function()
		if not self.active then
			return
		end

		work()
		self:Schedule(key, range, work)
	end)
end

---@param source LBSource
function Demo:Push(source)
	LB.Model:OnSourceEvent(source, DEMO_EVENT)
end

---@param source LBSource
---@param read fun(source: LBSource, snapshot: LBSnapshot): boolean
---@param available boolean? reported in place of the source's own availability
function Demo:Override(source, read, available)
	local saved = {}

	for _, name in ipairs(OVERRIDDEN) do
		saved[name] = source[name]
	end

	self.saved[source] = saved

	source.Read = read
	source.OnEvent = function(owner, event)
		return event == DEMO_EVENT and owner:Refresh()
	end

	if available ~= nil then
		source.IsAvailable = function()
			return available
		end
	end

	source.seeded = false
	LB.Model:SafeRead(source)
end

---@param player LBDemoPlayer
function Demo:LevelPlayer(player)
	while player.cur >= player.max do
		player.cur = player.cur - player.max
		player.level = player.level + 1
		player.max = XPMax(player.level)

		if player.rested <= 0 then
			player.rested = math.floor(player.max * RESTED_REFILL)
		end
	end
end

function Demo:StartPlayer()
	local source = LB.Model:Source("xp")

	if not source or not source:IsEnabled() then
		return
	end

	local max = XPMax(START_LEVEL)
	---@type LBDemoPlayer
	local player = {
		level = START_LEVEL,
		cur = math.floor(max * 0.62),
		max = max,
		rested = math.floor(max * RESTED_REFILL),
		quest = math.floor(max * 0.09),
		incomplete = math.floor(max * 0.18),
	}

	self.player = player
	source.atMaxLevel = false

	self:Override(source, function(owner, snapshot)
		snapshot.cur = math.floor(player.cur)
		snapshot.max = player.max
		snapshot.overlays.quest = math.floor(player.quest)
		snapshot.overlays.rested = math.floor(player.rested)
		snapshot.level = player.level
		snapshot.atCap = false
		owner.questXP = snapshot.overlays.quest
		owner.incompleteQuestXP = math.floor(player.incomplete)

		return true
	end, true)

	self:Schedule("player:kill", KILL_EVERY, function()
		local base = player.max * Between(KILL_SHARE)
		local bonus = math.min(base, player.rested)

		player.rested = player.rested - bonus
		player.cur = player.cur + base + bonus

		if player.incomplete > 0 and math.random() < OBJECTIVE_CHANCE then
			local finished = math.min(player.incomplete, player.max * Between(OBJECTIVE_SHARE))

			player.incomplete = player.incomplete - finished
			player.quest = player.quest + finished
		end

		self:LevelPlayer(player)
		self:Push(source)
	end)

	self:Schedule("player:turnIn", TURN_IN_EVERY, function()
		if player.quest <= 0 then
			return
		end

		player.cur = player.cur + player.quest
		player.quest = 0
		player.incomplete = player.incomplete + player.max * Between(NEW_QUEST_SHARE)

		self:LevelPlayer(player)
		self:Push(source)
	end)
end

function Demo:StartOthers()
	for _, id in ipairs(LB.Model:VisibleOrder()) do
		local source = LB.Model:Source(id)

		if id ~= "xp" and source then
			local snapshot = source:Snapshot()
			---@type LBDemoOther
			local other = {
				cur = math.floor(snapshot.max * (0.2 + math.random() * 0.5)),
				max = snapshot.max,
				level = snapshot.level,
			}

			self.others[id] = other

			self:Override(source, function(_, target)
				target.cur = math.floor(other.cur)
				target.max = other.max
				target.level = other.level

				return true
			end)

			self:Schedule("other:" .. id, OTHER_EVERY, function()
				other.cur = other.cur + other.max * Between(OTHER_SHARE)

				-- A type without levels restarts its bar; the negative change shows no gain indicator.
				if other.cur >= other.max then
					other.cur = other.cur - other.max

					if other.level then
						other.level = other.level + 1
					end
				end

				self:Push(source)
			end)
		end
	end
end

---@param member LBDemoMember
---@param changes fun(state: LBPartyState)
function Demo:UpdateMember(member, changes)
	local previous = member.state
	---@type LBPartyState
	local state = {
		sequence = previous.sequence + 1,
		level = previous.level,
		xp = previous.xp,
		xpMax = previous.xpMax,
		flags = 0,
		atMaxLevel = false,
		rested = previous.rested,
		quest = previous.quest,
	}

	changes(state)

	local leveled = false

	while state.xp >= state.xpMax do
		state.xp = state.xp - state.xpMax
		state.level = state.level + 1
		state.xpMax = XPMax(state.level)
		leveled = true
	end

	state.xp = math.floor(state.xp)
	state.rate = (member.seed + member.gained) / (MEMBER_SEED_SECONDS + GetTime() - self.started)
	member.state = state

	LB.Roster:Upsert(member.name, state)

	if leveled then
		LB.LevelUp:Notify({ key = "demo:" .. member.name, name = member.name, class = member.class, level = state.level })
	end
end

---@param member LBDemoMember
---@param offline boolean
function Demo:SetOffline(member, offline)
	local entry = LB.Roster.members[member.name]

	if not entry or entry.offline == offline then
		return
	end

	entry.offline = offline
	LB.Callbacks:Fire("Party")
end

---@param member LBDemoMember
function Demo:TickMember(member)
	local entry = LB.Roster.members[member.name]

	if not entry or entry.offline then
		return
	end

	local roll = math.random()

	if roll < MEMBER_OFFLINE_CHANCE then
		self:SetOffline(member, true)

		self.timers["offline:" .. member.name] = C_Timer.NewTimer(Between(MEMBER_OFFLINE_FOR), function()
			if self.active then
				self:SetOffline(member, false)
			end
		end)

		return
	end

	if roll < MEMBER_OFFLINE_CHANCE + MEMBER_IDLE_CHANCE then
		return
	end

	self:UpdateMember(member, function(state)
		local gain

		if roll < MEMBER_OFFLINE_CHANCE + MEMBER_IDLE_CHANCE + MEMBER_TURN_IN_CHANCE then
			gain = state.xpMax * Between(MEMBER_TURN_IN_SHARE)
		else
			local base = state.xpMax * Between(MEMBER_KILL_SHARE)
			local bonus = math.min(base, state.rested or 0)

			state.rested = math.floor((state.rested or 0) - bonus)
			gain = base + bonus
		end

		state.xp = state.xp + gain
		member.gained = member.gained + gain
	end)
end

function Demo:StartParty()
	self.savedReconcile = LB.Roster.Reconcile
	LB.Roster.Reconcile = function() end

	for index, entry in ipairs(MEMBERS) do
		local xpMax = XPMax(entry.level)
		---@type LBPartyState
		local state = {
			sequence = 1,
			level = entry.level,
			xp = math.floor(xpMax * entry.fraction),
			xpMax = xpMax,
			flags = 0,
			atMaxLevel = false,
			rested = math.floor(xpMax * entry.rested),
			quest = math.floor(xpMax * 0.05 * index),
			rate = entry.rate / 3600,
		}
		---@type LBDemoMember
		local member = {
			name = entry.name,
			class = entry.class,
			state = state,
			gained = 0,
			seed = entry.rate / 3600 * MEMBER_SEED_SECONDS,
		}

		self.members[index] = member

		LB.Roster.members[entry.name] = {
			name = entry.name,
			class = entry.class,
			state = state,
			offline = false,
			snapshot = LB.Roster.Snapshot(state),
			updated = GetTime(),
		}

		self:Schedule("member:" .. entry.name, MEMBER_EVERY, function()
			self:TickMember(member)
		end)
	end

	LB.Callbacks:Fire("Party")
end

---Runs `work` with the other look's settings read in place of the active profile.
---@param work fun()
function Demo:Mirror(work)
	if self.mirrorProfile then
		LB.Profile:Read(self.mirrorProfile, work)
	end
end

---A starting look over the player's own layout, so the bars keep their places, every bar the demo's width.
---@param layout LBLayoutSettings
---@param blizzard boolean
---@return LBProfileData
local function Look(layout, blizzard)
	local profile = LB.Profile:Defaults()

	profile.layout = LB:CopyTable(layout)

	if blizzard then
		LB.StylePicker.ApplyBlizzard(profile, UIParent:GetWidth())
	end

	profile.layout.width = DEMO_WIDTH

	for _, entry in pairs(profile.layout.independent) do
		entry.width = nil
	end

	return profile
end

---Names a look above its bar's top-left corner, on the line its gain indicators start from.
---@param anchor Region
---@param text string
---@param index integer
---@param reach number how far the bar's border stands out past its top
function Demo:Title(anchor, text, index, reach)
	local titles = self.titles or {}
	local title = titles[index]

	self.titles = titles

	if not title then
		title = self.mirror:CreateFontString(nil, "OVERLAY")
		LibStub("LibAeonSettings-1.0"):SetFont(title, "header", TITLE_SIZE)
		title:SetTextColor(unpack(GOLD))
		title:SetShadowOffset(1, -1)
		titles[index] = title
	end

	title:ClearAllPoints()
	title:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, TITLE_GAP + reach)
	title:SetText(text)
	title:Show()
end

function Demo:StartMirror()
	local source = LB.Model:Source("xp")
	local group = LB.BarGroup.frame

	if not source or not source:IsEnabled() or not group then
		return
	end

	local frame = self.mirror or CreateFrame("Frame", MIRROR_NAME, UIParent)
	local bar = self.mirrorBar or LB.Bar:Create(frame, "xp")

	self.mirror, self.mirrorBar = frame, bar
	bar.border = bar.border or LB.Border:Create(bar)

	self:Mirror(function()
		local layout = LB.Profile:Get("layout")
		local border = LB.Profile:Get("appearance.border")
		local height = LB.Layout.Height(layout, LB.Border:FixedHeight(border.style))

		frame:SetFrameStrata(layout.strata)
		frame:ClearAllPoints()

		-- Toward the middle of the screen, so neither bar nor title leaves it.
		local top = group:GetTop()

		if top and top > UIParent:GetHeight() / 2 then
			frame:SetPoint("TOP", group, "BOTTOM", 0, -MIRROR_GAP)
		else
			frame:SetPoint("BOTTOM", group, "TOP", 0, MIRROR_GAP)
		end
		LB:SetPixelSize(frame, layout.width, height)

		bar:ClearAllPoints()
		bar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT")
		bar:SetGeometry(layout.width, height)
		bar:ApplyAppearance()
		bar.border:Apply(border.style, LB.Border:Color(border.style, border), height, border.width)
		bar:SetEndMasks(LB.Border:EndMask(border.style), true, true)
		bar:SetSnapshot(LB.Model:Get("xp"), false, false)
		LB.TextSlot:ApplySample(bar, false)
		LB.Marker:Apply(bar)
	end)

	-- Markers redraw on a resize from the active profile; this bar's are redrawn only through `Mirror`.
	if bar.markerLayer then
		bar.markerLayer:SetScript("OnSizeChanged", nil)
	end

	frame:Show()
	bar:Show()
	local blizzardReach = 0

	self:Mirror(function()
		blizzardReach = LB.TextSlot:BorderReach(bar)
	end)

	self:Title(group, "Modern Style", 1, LB.TextSlot:BorderReach(nil))
	self:Title(frame, "Blizzard Style", 2, blizzardReach)

	LB.Callbacks:Register("Progress", self, function(_, id)
		if id == "xp" then
			self:Mirror(function()
				bar:SetSnapshot(LB.Model:Get("xp"), true, true)
				LB.Gain:OnProgress(bar)
			end)
		end
	end)
	LB.Callbacks:Register("Party", self, function()
		self:Mirror(function()
			LB.Marker:Apply(bar)
		end)
	end)
end

function Demo:StopMirror()
	LB.Callbacks:Unregister("Progress", self)
	LB.Callbacks:Unregister("Party", self)

	for _, title in ipairs(self.titles or {}) do
		title:Hide()
	end

	if self.mirrorBar then
		LB.Gain:Release(self.mirrorBar)
		LB.Marker:Release(self.mirrorBar)
	end

	if self.mirror then
		self.mirror:Hide()
	end

	self.mirrorProfile = nil
end

function Demo:Start()
	if LB.failed then
		LB:Print("demo unavailable: Levelbound failed to load.")

		return
	end

	self.active = true
	self.started = GetTime()

	-- The bars wear the Modern look for the run; the player's profile comes back on stop.
	local layout = LB.Profile.active.layout

	self.savedProfile = LB.Profile.active
	self.mirrorProfile = Look(layout, true)
	LB.Profile.active = Look(layout, false)
	LB.Callbacks:Fire("Settings", nil, nil)

	local comms = LB.Comms

	self.savedComms.Send = comms.Send
	self.savedComms.SendRequest = comms.SendRequest
	comms.Send = function() end
	comms.SendRequest = function() end

	LB.Session:Reset()

	self:StartOthers()
	self:StartPlayer()
	self:StartParty()

	LB.Model:Sync()
	self:StartMirror()

	for source in pairs(self.saved) do
		LB.Callbacks:Fire("Progress", source.id)
	end

	LB:Print("demo on. /lb demo again or /reload to stop.")
end

function Demo:Stop()
	self.active = false
	self:StopMirror()

	for _, timer in pairs(self.timers) do
		timer:Cancel()
	end

	wipe(self.timers)

	for _, member in ipairs(self.members) do
		LB.Roster.members[member.name] = nil
	end

	wipe(self.members)
	LB.Roster.Reconcile = self.savedReconcile
	self.savedReconcile = nil
	LB.Callbacks:Fire("Party")
	LB.Roster:Reconcile()

	for source, saved in pairs(self.saved) do
		for name, original in pairs(saved) do
			source[name] = original
		end

		source.seeded = false

		if source.id == "xp" then
			LB.Model:OnSourceEvent(source, "LEVELBOUND_QUEST_SCAN")
		else
			LB.Model:SafeRead(source)
		end
	end

	local stopped = self.saved

	self.saved = {}
	wipe(self.others)
	self.player = nil

	LB.Comms.Send = self.savedComms.Send
	LB.Comms.SendRequest = self.savedComms.SendRequest
	wipe(self.savedComms)

	if self.savedProfile then
		LB.Profile.active = self.savedProfile
		self.savedProfile = nil
		LB.Callbacks:Fire("Settings", nil, nil)
	end

	LB.Session:Reset()
	LB.Model:Sync()

	for source in pairs(stopped) do
		LB.Callbacks:Fire("Progress", source.id)
	end

	LB:Print("demo off.")
end

function Demo:Toggle()
	if self.active then
		self:Stop()
	else
		self:Start()
	end
end

-- `/lb demo gains` hides the real bars and shows a gallery from the top of the screen: an experience bar for each
-- gain indicator placement and motion, then a segmented row with its stack beside it and a detached stack, gaining
-- on a loop through Gain:Show. Every bar draws with its own copy of the active profile that differs only in its
-- gain and layout settings, so the indicators look as they would on the real bars. Each loop sends a second gain a
-- second after the first, showing how a repeat gain adds to the running total. There is one gain stack, so the
-- segmented and detached stacks take turns: each rising, side by side with Slide Outward, and still. Real gains show
-- nothing while it runs.

local GALLERY_NAME = "LevelboundDemoGains"
local GALLERY_TOP = 32 -- from the screen's top
local GALLERY_WIDTH = 300 -- each sample bar, and the segmented row
local GALLERY_SIDE = 120 -- room beside a bar for an indicator beside it
local GALLERY_ABOVE = 44 -- room above a bar for an indicator above it, rising
local GALLERY_ROW = 100
local GALLERY_COLUMNS = 2
local GALLERY_SHARE = 0.06 -- of the level, each gain
local GALLERY_REPEAT = 1 -- seconds from a gain to its repeat
local GALLERY_PAUSE = 0.5 -- between a loop's last fade and the next loop

local STACK_ROOM = 170 -- the stacks' band: a full stack growing either way from the row's center
local STACK_INSET = 20 -- the segmented row's left edge, leaving room for its stack on the right
local STACK_ROW_WIDTH = 210 -- narrow enough that its stack, side by side, stays clear of the detached one
local STACK_SEGMENTS = 3
local STACK_EVERY = 0.3 -- between the segments' gains in a stack's turn

local VARIANTS = {
	{ title = "Fill Edge, Rise", position = "FILL_EDGE" },
	{ title = "Right End, Rise", position = "RIGHT_END" },
	{ title = "Right of Bar, Rise", position = "OUTSIDE_RIGHT" },
	{ title = "Right of Bar, Slide Outward", position = "OUTSIDE_RIGHT", animation = "SLIDE" },
	{ title = "Left of Bar, Rise", position = "OUTSIDE_LEFT" },
	{ title = "Left of Bar, Slide Outward", position = "OUTSIDE_LEFT", animation = "SLIDE" },
	{ title = "Fill Edge, Animate Off", position = "FILL_EDGE", animate = false },
	{ title = "Right of Bar, Animate Off", position = "OUTSIDE_RIGHT", animate = false },
}

-- The stacks' turns, one each loop.
local TURNS = {
	{ area = "segmented", animate = true, state = "Rise" },
	{ area = "detached", animate = true, state = "Animate On" },
	{ area = "segmented", animate = true, animation = "SLIDE", state = "Slide Outward" },
	{ area = "detached", animate = true, animation = "SLIDE", state = "Slide Outward, Right" },
	{ area = "segmented", animate = false, state = "Animate Off" },
	{ area = "detached", animate = false, state = "Animate Off" },
}

local AREA_TITLES = {
	segmented = "Segmented, Right of Bar",
	detached = "Detached",
}

---@class LBGainDemoSample
---@field bar LBBar
---@field title FontString?
---@field profile LBProfileData the profile its gains show with
---@field snapshot LBSnapshot

---@class LBGainDemo
---@field active boolean
---@field frame Frame?
---@field holder Frame? the hidden parent of the real bars while the demo runs
---@field row Frame? the segmented row
---@field area Frame? the detached stack's place, which its title sits under
---@field titles table<string, FontString> the stack areas' titles
---@field samples LBGainDemoSample[]
---@field segments LBGainDemoSample[]
---@field turn integer the stacks' next turn
---@field ticker any?
---@field savedOnProgress function?
local GainDemo = {
	active = false,
	titles = {},
	samples = {},
	segments = {},
	turn = 1,
}

---@param position string
---@param animation string?
---@param animate boolean?
---@return LBProfileData profile a copy of the active profile wearing these gain settings, on bars of their own
local function GainLook(position, animation, animate)
	local profile = LB:CopyTable(LB.Profile.active)
	local gain = profile.gain

	profile.layout.mode = "CONNECTED"
	profile.layout.fullscreen = "OFF"
	gain.enabled, gain.hideInCombat, gain.detached = true, false, false
	gain.position = position
	gain.animation = animation or "RISE"
	gain.animate = animate ~= false

	return profile
end

---@param frame Frame
---@return FontString
local function Title(frame)
	local title = frame:CreateFontString(nil, "OVERLAY")

	LibStub("LibAeonSettings-1.0"):SetFont(title, "header", TITLE_SIZE)
	title:SetTextColor(unpack(GOLD))
	title:SetShadowOffset(1, -1)

	return title
end

---@param parent Frame
---@param id string
---@return LBBar
local function SampleBar(parent, id)
	local bar = LB.Bar:Create(parent, id)

	bar:EnableMouse(false)
	bar.border = LB.Border:Create(bar)

	return bar
end

---Draws a sample bar from its sample's profile and snapshot, `width` wide, without text.
---@param sample LBGainDemoSample
---@param width number
local function Draw(sample, width)
	local bar = sample.bar

	LB.Profile:Read(sample.profile, function()
		local layout = LB.Profile:Get("layout")
		local border = LB.Profile:Get("appearance.border")
		local height = LB.Layout.Height(layout, LB.Border:FixedHeight(border.style))

		bar:SetGeometry(width, height)
		bar:ApplyAppearance()
		bar.border:Apply(border.style, LB.Border:Color(border.style, border), height, border.width)
		bar:SetEndMasks(LB.Border:EndMask(border.style), true, true)
		bar.textSuppressed = true
		bar:SetSnapshot(sample.snapshot, false, false)
		LB.TextSlot:UpdateBar(bar)
	end)

	bar:Show()
end

---Advances a sample bar by `share` of its level and shows the gain with the sample's profile.
---@param sample LBGainDemoSample
---@param share number of the level
local function SampleGain(sample, share)
	local snapshot = LB:CopyTable(sample.snapshot)
	local amount = math.floor(snapshot.max * share)

	snapshot.cur = snapshot.cur + amount

	if snapshot.cur >= snapshot.max then
		snapshot.cur = snapshot.cur - snapshot.max
	end

	sample.snapshot = snapshot

	LB.Profile:Read(sample.profile, function()
		sample.bar:SetSnapshot(snapshot, true, false)
		LB.Gain:Show(sample.bar, amount)
	end)
end

---@return string[] ids the first types this client can track, for the segments
local function SegmentIds()
	local ids = {}

	for _, id in ipairs(LB.Model:Order()) do
		if #ids < STACK_SEGMENTS and LB.Model:Capable(id) then
			ids[#ids + 1] = id
		end
	end

	return ids
end

---Builds the gallery's frame, the variants' bars and the segmented row, and the detached stack's place.
---@return Frame frame the gallery, not yet shown
function GainDemo:Build()
	local frame = self.frame or CreateFrame("Frame", GALLERY_NAME, UIParent)
	local cell = GALLERY_SIDE * 2 + GALLERY_WIDTH
	local width = cell * GALLERY_COLUMNS
	local top = math.ceil(#VARIANTS / GALLERY_COLUMNS) * GALLERY_ROW

	self.frame = frame
	frame:SetFrameStrata(LB.Profile:Get("layout.strata"))
	frame:ClearAllPoints()
	frame:SetPoint("TOP", UIParent, "TOP", 0, -GALLERY_TOP)
	LB:SetPixelSize(frame, width, top + STACK_ROOM)

	for index, variant in ipairs(VARIANTS) do
		local sample = self.samples[index]

		if not sample then
			sample = { bar = SampleBar(frame, "xp"), title = Title(frame) }
			self.samples[index] = sample
		end

		local column, row = (index - 1) % GALLERY_COLUMNS, math.floor((index - 1) / GALLERY_COLUMNS)

		sample.profile = GainLook(variant.position, variant.animation, variant.animate)
		sample.snapshot = LB:CopyTable(LB.Preview:Snapshot("xp"))
		sample.bar:ClearAllPoints()
		sample.bar:SetPoint("TOPLEFT", frame, "TOPLEFT", column * cell + GALLERY_SIDE,
			-(row * GALLERY_ROW + GALLERY_ABOVE))
		Draw(sample, GALLERY_WIDTH)

		local title = sample.title --[[@as FontString]]

		title:ClearAllPoints()
		title:SetPoint("TOP", sample.bar, "BOTTOM", 0, -(TITLE_GAP * 3))
		title:SetText(variant.title)
		title:Show()
	end

	-- The segmented row, centered in the left column's band.
	local rowFrame = self.row or CreateFrame("Frame", nil, frame)
	local segmentProfile = GainLook("OUTSIDE_RIGHT")
	local ids = SegmentIds()
	local segmentWidth = STACK_ROW_WIDTH / math.max(#ids, 1)
	local height = 1

	segmentProfile.layout.mode = "SEGMENTED"
	self.row = rowFrame

	for index, id in ipairs(ids) do
		local segment = self.segments[index]

		if not segment or segment.bar.id ~= id then
			segment = { bar = SampleBar(rowFrame, id) }
			self.segments[index] = segment
		end

		segment.profile = segmentProfile
		segment.snapshot = LB:CopyTable(LB.Preview:Snapshot(id))
		segment.bar:ClearAllPoints()
		segment.bar:SetPoint("TOPLEFT", rowFrame, "TOPLEFT", (index - 1) * segmentWidth, 0)
		Draw(segment, segmentWidth)
		height = segment.bar:GetHeight()
	end

	rowFrame:ClearAllPoints()
	rowFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", STACK_INSET, -(top + (STACK_ROOM - height) / 2))
	LB:SetPixelSize(rowFrame, STACK_ROW_WIDTH, height)
	rowFrame:Show()

	-- The detached stack's place, centered in the right column's band, its title under the stacked footprint.
	-- Each turn's box is placed from its profile, in screen coordinates, centered in the band for its footprint.
	local area = self.area or CreateFrame("Frame", nil, frame)
	local boxWidth, boxHeight = LB.Gain:DetachedSize()
	local boxLeft = cell + GALLERY_SIDE

	self.area = area
	area:ClearAllPoints()
	area:SetPoint("TOPLEFT", frame, "TOPLEFT", boxLeft, -(top + (STACK_ROOM - boxHeight) / 2))
	LB:SetPixelSize(area, boxWidth, boxHeight)
	area:Show()

	for _, turn in ipairs(TURNS) do
		local profile = turn.area == "segmented" and LB:CopyTable(segmentProfile) or GainLook("OUTSIDE_RIGHT")

		turn.profile = profile
		profile.gain.animate = turn.animate
		profile.gain.animation = turn.animation or "RISE"

		if turn.area == "detached" then
			local footprint = boxHeight

			profile.gain.detached = true
			profile.gain.across = "RIGHT"
			LB.Profile:Read(profile, function()
				local _, used = LB.Gain:DetachedFootprint()

				footprint = used
			end)
			profile.gain.screen = {
				point = "TOPLEFT",
				x = (UIParent:GetWidth() - width) / 2 + boxLeft,
				y = -(GALLERY_TOP + top + (STACK_ROOM - footprint) / 2),
			}
		end
	end

	self.titles.segmented = self.titles.segmented or Title(frame)
	self.titles.segmented:ClearAllPoints()
	self.titles.segmented:SetPoint("TOP", rowFrame, "BOTTOM", 0, -(TITLE_GAP * 3))
	self.titles.detached = self.titles.detached or Title(frame)
	self.titles.detached:ClearAllPoints()
	self.titles.detached:SetPoint("TOP", area, "BOTTOM", 0, -(TITLE_GAP * 3))

	for _, title in pairs(self.titles) do
		title:Show()
	end

	return frame
end

---Plays the stacks' next turn: each segment gains in turn, then the first again, adding to its line.
function GainDemo:PlayStack()
	local turn = TURNS[self.turn]

	self.turn = self.turn % #TURNS + 1

	for area, title in pairs(self.titles) do
		local state = area ~= turn.area and "waiting" or turn.state

		title:SetText(("%s (%s)"):format(AREA_TITLES[area], state))
	end

	for index, segment in ipairs(self.segments) do
		segment.profile = turn.profile

		C_Timer.After((index - 1) * STACK_EVERY, function()
			if self.active then
				SampleGain(segment, GALLERY_SHARE)
			end
		end)
	end

	local first = self.segments[1]

	if first then
		C_Timer.After(GALLERY_REPEAT, function()
			if self.active then
				SampleGain(first, GALLERY_SHARE / 2)
			end
		end)
	end
end

function GainDemo:Play()
	for _, sample in ipairs(self.samples) do
		SampleGain(sample, GALLERY_SHARE)
	end

	C_Timer.After(GALLERY_REPEAT, function()
		if not self.active then
			return
		end

		for _, sample in ipairs(self.samples) do
			SampleGain(sample, GALLERY_SHARE / 2)
		end
	end)

	self:PlayStack()
end

function GainDemo:Start()
	if LB.failed then
		LB:Print("gain demo unavailable: Levelbound failed to load.")

		return
	end

	self.active = true
	self.turn = 1

	-- The real bars hide under a hidden parent, and their gains show nothing, until the demo stops.
	local group = LB.BarGroup.frame

	self.holder = self.holder or CreateFrame("Frame")
	self.holder:Hide()

	if group then
		group:SetParent(self.holder)
	end

	self.savedOnProgress = LB.Gain.OnProgress
	LB.Gain.OnProgress = function() end
	LB.Gain:ReleaseAll()

	self:Build():Show()
	self:Play()
	self.ticker = C_Timer.NewTicker(GALLERY_REPEAT + LB.NoticeStack.DURATION + GALLERY_PAUSE, function()
		self:Play()
	end)

	LB:Print("gain demo on. /lb demo gains again or /reload to stop.")
end

function GainDemo:Stop()
	self.active = false

	if self.ticker then
		self.ticker:Cancel()
		self.ticker = nil
	end

	-- Lands each fill animation on its target before the bars hide.
	for _, list in ipairs({ self.samples, self.segments }) do
		for _, sample in ipairs(list) do
			LB.Profile:Read(sample.profile, function()
				sample.bar:SetSnapshot(sample.snapshot, false, false)
			end)
		end
	end

	LB.Gain:ReleaseAll()
	LB.Gain.OnProgress = self.savedOnProgress
	self.savedOnProgress = nil

	if self.frame then
		self.frame:Hide()
	end

	local group = LB.BarGroup.frame

	if group then
		group:SetParent(UIParent)
		group:SetFrameStrata(LB.Profile:Get("layout.strata"))
	end

	LB:Print("gain demo off.")
end

function GainDemo:Toggle()
	if self.active then
		self:Stop()
	else
		self:Start()
	end
end

local handler = SlashCmdList.LEVELBOUND

SlashCmdList.LEVELBOUND = function(message)
	local command = (message or ""):lower()

	if command:match("^%s*demo%s*$") then
		Demo:Toggle()

		return
	elseif command:match("^%s*demo%s+gains%s*$") then
		GainDemo:Toggle()

		return
	end

	handler(message)
end
