local LB = select(2, ...)

local Callbacks = LB.Callbacks
local Events = LB.Events

---@class LBOverlays
---@field quest number
---@field rested number

---@class LBSnapshot
---@field cur number
---@field max number
---@field overlays LBOverlays
---@field level number?
---@field label string?
---@field standing string?
---@field color LBColor?
---@field atCap boolean
---@field flags table<string, boolean>

---@class LBSourceFields
---@field id string
---@field snapshot LBSnapshot
---@field available boolean
---@field visible boolean
---@field subscribed boolean
---@field perCharacter boolean

---@class LBSourceSpec
---@field Read fun(self: LBSource, snapshot: LBSnapshot): boolean
---@field IsAvailable? fun(self: LBSource): boolean
---@field HasData? fun(self: LBSource): boolean
---@field Events? fun(self: LBSource): string[]
---@field OnEvent? fun(self: LBSource, event: string, ...: any): boolean
---@field Click? fun(self: LBSource)
---@field Tooltip? fun(self: LBSource, tip: GameTooltip)
---@field perCharacter? boolean

---@class LBSourceMixin : LBSourceFields, LBSourceSpec
local SourceMixin = {}

---@class LBSource : LBSourceMixin

---@return boolean
function SourceMixin:IsAvailable()
	return true
end

---@return boolean
function SourceMixin:IsEnabled()
	if self.perCharacter then
		return LB.Profile:OptedIn(self.id)
	end

	return LB.Profile:Get("types." .. self.id) == true
end

---@return boolean
function SourceMixin:HasData()
	return self.snapshot.max > 0
end

---@return boolean
function SourceMixin:IsVisible()
	return self.available and self:IsEnabled() and self:HasData()
end

---@return LBSnapshot
function SourceMixin:Snapshot()
	return self.snapshot
end

---@return string[]
function SourceMixin:Events()
	return {}
end

---@return boolean changed
function SourceMixin:Refresh()
	return self:Read(self.snapshot) == true
end

---@param event string
---@return boolean changed
function SourceMixin:OnEvent(event)
	return self:Refresh()
end

---@return number fraction 0-1
function SourceMixin:Fraction()
	local snapshot = self.snapshot

	if snapshot.max <= 0 then
		return 0
	end

	return math.min(snapshot.cur / snapshot.max, 1)
end

---@return number fill
---@return number quest
---@return number rested
function SourceMixin:OverlayFractions()
	return LB.Model:Fractions(self.snapshot)
end

---@return number questOverflow
---@return number restedOverflow
function SourceMixin:Overflow()
	return LB.Model:Overflow(self.snapshot)
end

---@class LBModel
---@field sources table<string, LBSource>
local Model = {
	sources = {},
}
LB.Model = Model

local ORDER = { "xp", "petxp", "reputation", "house", "endeavor", "travel", "honor", "azerite" }

---@class LBSourceFactory
local Source = {}
LB.Source = Source

---@param id string
---@param spec LBSourceSpec
---@return LBSource
function Source:New(id, spec)
	---@type LBSource
	local source = CreateFromMixins(SourceMixin, spec)

	source.id = id
	source.available = false
	source.visible = false
	source.snapshot = {
		cur = 0,
		max = 0,
		overlays = { quest = 0, rested = 0 },
		atCap = false,
		flags = {},
	}

	Model.sources[id] = source

	return source
end

---@param snapshot LBSnapshot
---@return number fill
---@return number quest
---@return number rested
function Model:Fractions(snapshot)
	if snapshot.max <= 0 then
		return 0, 0, 0
	end

	local overlays = snapshot.overlays
	local fill = math.min(snapshot.cur / snapshot.max, 1)
	local quest = math.min((snapshot.cur + overlays.quest) / snapshot.max, 1)
	local rested = math.min((snapshot.cur + overlays.quest + overlays.rested) / snapshot.max, 1)

	return fill, quest, rested
end

---@param snapshot LBSnapshot
---@return number questOverflow
---@return number restedOverflow
function Model:Overflow(snapshot)
	local overlays = snapshot.overlays
	local remaining = math.max(snapshot.max - snapshot.cur, 0)
	local quest = math.max(overlays.quest - remaining, 0)
	local rested = math.max(overlays.quest + overlays.rested - remaining - quest, 0)

	return quest, rested
end

---@param id string
---@return LBSnapshot?
function Model:Get(id)
	local source = self.sources[id]

	return source and source.snapshot
end

---@param id string
---@return LBSource?
function Model:Source(id)
	return self.sources[id]
end

---@return string[] ids visible now, in the fixed order
function Model:VisibleOrder()
	local visible = {}

	for _, id in ipairs(ORDER) do
		local source = self.sources[id]

		if source and source.visible then
			visible[#visible + 1] = id
		end
	end

	return visible
end

---@param source LBSource
local function Subscribe(source)
	for _, event in ipairs(source:Events()) do
		Events:Register(event, source, function(owner, eventName, ...)
			Model:OnSourceEvent(owner, eventName, ...)
		end)
	end
end

---@param source LBSource
local function Unsubscribe(source)
	Events:UnregisterAll(source)
end

---@param source LBSource
---@param event string
function Model:OnSourceEvent(source, event, ...)
	if source:OnEvent(event, ...) then
		Events:Coalesce("progress:" .. source.id, function()
			Callbacks:Fire("Progress", source.id)
		end)
	end

	if source.visible ~= source:IsVisible() then
		Events:Coalesce("layout", function()
			Model:Sync()
		end)
	end
end

function Model:Sync()
	local changed = false

	for _, id in ipairs(ORDER) do
		local source = self.sources[id]

		if source then
			source.available = source:IsAvailable()

			local wanted = source.available and source:IsEnabled()

			if wanted and not source.subscribed then
				source.subscribed = true
				Subscribe(source)
				source:Refresh()
			elseif not wanted and source.subscribed then
				source.subscribed = false
				Unsubscribe(source)
			end

			local visible = source:IsVisible()

			if visible ~= source.visible then
				source.visible = visible
				changed = true
			end
		end
	end

	if changed then
		Callbacks:Fire("Layout")
	end
end

function Model:Seed()
	for _, id in ipairs(ORDER) do
		local source = self.sources[id]

		if source then
			source.available = source:IsAvailable()

			if source.available and source:IsEnabled() then
				source:Refresh()
			end
		end
	end

	self:Sync()
end

Callbacks:Register("Settings", Model, function()
	Model:Sync()
end)
