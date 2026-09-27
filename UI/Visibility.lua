local LB = select(2, ...)

local Callbacks = LB.Callbacks
local Events = LB.Events

local FADE = 0.15
local EPSILON = 0.01

---@class LBVisibilityState
---@field inCombat boolean
---@field hasTarget boolean
---@field blocked boolean pet battle/vehiclke
---@field hovered string? id of the bar under the cursor
---@field editing boolean?

---@class LBVisibility
---@field state LBVisibilityState
local Visibility = {
	state = {
		inCombat = false,
		hasTarget = false,
		blocked = false,
		hovered = nil,
	},
}
LB.Visibility = Visibility

---@param value any
---@return boolean
local function Truthy(value)
	if issecretvalue(value) then
		return false
	end

	return value == true
end

---@param settings LBVisibilitySettings
---@param state LBVisibilityState
---@return boolean hidden
function Visibility:Hidden(settings, state)
	if state.blocked then
		return true
	end

	return settings.hideInCombat and state.inCombat
end

---@param settings LBVisibilitySettings | LBMarkerOpacitySettings
---@param state LBVisibilityState
---@param hovered boolean
---@param editing boolean?
---@return boolean faded
local function Faded(settings, state, hovered, editing)
	if not settings.fadeUntilHovered or hovered or editing then
		return false
	end

	return not ((settings.fullInCombat and state.inCombat) or (settings.fullWithTarget and state.hasTarget))
end

---@param settings LBVisibilitySettings
---@param state LBVisibilityState
---@param id string the bar being resolved
---@return boolean
local function Dimmed(settings, state, id)
	return settings.focus.enabled and state.hovered ~= nil and state.hovered ~= id
end

---@param settings LBVisibilitySettings
---@param state LBVisibilityState
---@param id string the bar being resolved
---@return number alpha
---@return boolean dimmed the bar is one focus mode is dimming, so it shows no text
function Visibility:Resolve(settings, state, id)
	local alpha = Faded(settings, state, state.hovered == id, state.editing) and settings.fadedAlpha or 1
	local dimmed = Dimmed(settings, state, id)

	if dimmed then
		alpha = math.min(alpha, settings.focus.alpha)
	end

	return alpha, dimmed
end

---@param opacity LBMarkerOpacitySettings
---@param settings LBVisibilitySettings
---@param state LBVisibilityState
---@param id string the bar the markers sit on
---@param previewing boolean?
---@return number alpha
function Visibility:ResolveMarkers(opacity, settings, state, id, previewing)
	local editing = state.editing and not previewing
	local alpha = Faded(opacity, state, state.hovered == id, editing) and opacity.fadedAlpha or opacity.alpha

	if Dimmed(settings, state, id) then
		alpha = math.min(alpha, settings.focus.alpha)
	end

	return alpha
end

---@param region Frame
---@param driver Frame runs the fade, so it must stay shown while it does
---@param alpha number
---@param animated boolean?
function Visibility:SetAlpha(region, driver, alpha, animated)
	local from = region:GetAlpha()

	if math.abs(from - alpha) < EPSILON then
		return
	end

	LB:StopTween(driver)

	if not animated then
		region:SetAlpha(alpha)

		return
	end

	LB:Tween(driver, FADE, function(eased)
		region:SetAlpha(from + (alpha - from) * eased)
	end)
end

---@param animated boolean?
function Visibility:Apply(animated)
	local group = LB.BarGroup
	local frame = group.frame

	if not frame then
		return
	end

	local settings = LB.Profile:Get("visibility")
	local hidden = self:Hidden(settings, self.state)

	frame:SetShown(group.hasBars == true and not hidden)

	if hidden then
		return
	end

	local brightest = 0

	for id, bar in pairs(group.bars) do
		if bar:IsShown() and not bar.fading then
			local alpha, dimmed = self:Resolve(settings, self.state, id)

			bar.textSuppressed = dimmed
			LB.TextSlot:SetHovered(bar, bar.hovered == true)
			self:SetAlpha(bar, bar.alphaDriver, alpha, animated)
			brightest = math.max(brightest, alpha)
		end
	end

	if group.border then
		self:SetAlpha(group.border, group.border, brightest, animated)
	end

	LB.Marker:ApplyOpacity(animated)
end

---@param id string? the bar under the cursor, or nil when the cursor left one
function Visibility:SetHovered(id)
	if self.state.hovered == id then
		return
	end

	self.state.hovered = id

	self:Apply(true)
end

function Visibility:ReadState()
	local state = self.state

	state.inCombat = InCombatLockdown() == true
	state.hasTarget = Truthy(UnitExists("target"))
	state.blocked = Truthy(UnitInVehicle("player"))
		or Truthy(UnitHasVehicleUI("player"))
		or (C_PetBattles ~= nil and C_PetBattles.IsInBattle ~= nil and Truthy(C_PetBattles.IsInBattle()))
end

---@param animated boolean?
function Visibility:Refresh(animated)
	self:ReadState()
	self:Apply(animated)
end

Events:Register("PLAYER_REGEN_DISABLED", Visibility, function()
	Visibility.state.inCombat = true

	Visibility:Apply(true)
end)

Events:Register("PLAYER_REGEN_ENABLED", Visibility, function()
	Visibility.state.inCombat = false

	Visibility:Apply(true)
end)

Events:Register("PLAYER_TARGET_CHANGED", Visibility, function()
	Visibility.state.hasTarget = Truthy(UnitExists("target"))

	Visibility:Apply(true)
end)

for _, event in ipairs({ "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE" }) do
	Events:Register(event, Visibility, function(_, _, unit)
		if unit ~= "player" then
			return
		end

		Visibility:Refresh(false)
	end)
end

for _, event in ipairs({ "PET_BATTLE_OPENING_START", "PET_BATTLE_CLOSE" }) do
	Events:Register(event, Visibility, function()
		Visibility:Refresh(false)
	end)
end

Callbacks:Register("Settings", Visibility, function()
	Visibility:Refresh(true)
end)

Callbacks:Register("Editing", Visibility, function()
	local editing = LB.Editing:IsEditing()

	if Visibility.state.editing == editing then
		return
	end

	Visibility.state.editing = editing

	Visibility:Apply(true)
end)
