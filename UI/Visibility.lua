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

---@param settings LBVisibilitySettings
---@param state LBVisibilityState
---@param id string the bar being resolved
---@return number alpha
---@return boolean dimmed the bar is one focus mode is dimming, so it shows no text
function Visibility:Resolve(settings, state, id)
	local hovered = state.hovered == id
	local alpha = 1

	if settings.fadeUntilHovered and not hovered and not state.editing then
		local full = (settings.fullInCombat and state.inCombat) or (settings.fullWithTarget and state.hasTarget)

		if not full then
			alpha = settings.fadedAlpha
		end
	end

	local focus = settings.focus
	local dimmed = focus.enabled and state.hovered ~= nil and not hovered

	if dimmed then
		alpha = math.min(alpha, focus.alpha)
	end

	return alpha, dimmed
end

---@param region Frame
---@param driver Frame
---@param alpha number
---@param animated boolean?
local function SetAlpha(region, driver, alpha, animated)
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
			LB.TextElement:SetHovered(bar, bar.hovered == true)
			SetAlpha(bar, bar.alphaDriver, alpha, animated)
			brightest = math.max(brightest, alpha)
		end
	end

	if group.border then
		SetAlpha(group.border, group.border, brightest, animated)
	end
end

---@param editing boolean
function Visibility:SetEditing(editing)
	self.state.editing = editing

	self:Apply(true)
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
