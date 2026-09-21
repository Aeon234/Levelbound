local LB = select(2, ...)

local Callbacks = LB.Callbacks

local GAP = 2
local BASE_SIZE = 24
local PREVIEW_AMOUNT = 1234
local PREVIEW_MERGE = 0.1
local HOLD_AT = 0.25
local TRAVEL = 20

local RISE = 0.25
local RISE_ALPHA = 0.15
local HOLD = 1.5
local DRIFT = 2
local FADE = 0.5
local DURATION = HOLD + FADE

local ARROW_FROM_X = -2
local ARROW_FROM_Y = -28
local ARROW_RISE_X = 2
local ARROW_RISE_Y = 16
local TEXT_FROM_Y = -14
local TEXT_RISE_Y = 4
local DRIFT_Y = 16

local OUTLINES = {
	NONE = "",
	OUTLINE = "OUTLINE",
	THICKOUTLINE = "THICKOUTLINE",
	SLUG = "SLUG",
	SLUG_OUTLINE = "SLUG, OUTLINE",
	SLUG_THICKOUTLINE = "SLUG, THICKOUTLINE",
}

---@param frame Frame
local function Reset(_, frame)
	frame:SetScript("OnUpdate", nil)
	frame:Hide()
	frame:ClearAllPoints()
	frame:SetParent(UIParent)

	frame.bar = nil
	frame.amount = 0
	frame.elapsed = 0
	frame.scale = 1
	frame.arrowX = 0
	frame.textX = 0
	frame.textY = 0
	frame.held = nil
end

---@class LBGain
---@field pool any
---@field active table<LBBar, Frame>
---@field inCombat boolean
---@field previewing boolean? a held example is on screen
local Gain = {
	pool = CreateFramePool("Frame", UIParent, nil, Reset),
	active = {},
	inCombat = false,
}
LB.Gain = Gain

---@param progress number 0-1
---@return number eased
local function EaseOut(progress)
	local inverse = 1 - progress

	return 1 - inverse * inverse * inverse
end

---@param elapsed number seconds since the gain appeared
---@param scale number 1 at the reference 24 px arrow
---@return number arrowX
---@return number arrowY
---@return number arrowAlpha
---@return number textY
---@return number textAlpha
function Gain:Keyframe(elapsed, scale)
	local eased = EaseOut(math.min(elapsed / RISE, 1))
	local arrowX = ARROW_FROM_X + ARROW_RISE_X * eased
	local arrowY = ARROW_FROM_Y + ARROW_RISE_Y * eased
	local textY = TEXT_FROM_Y + TEXT_RISE_Y * eased
	local alpha = math.min(elapsed / RISE_ALPHA, 1)

	if elapsed > HOLD then
		local drift = math.min((elapsed - HOLD) / DRIFT, 1)

		arrowY = arrowY + DRIFT_Y * drift
		textY = textY + DRIFT_Y * drift
		alpha = 1 - math.min((elapsed - HOLD) / FADE, 1)
	end

	return arrowX * scale, arrowY * scale, alpha, textY * scale, alpha
end

---@param fraction number 0-1
---@param barWidth number
---@param width number the indicator's own width
---@param mode string "FILL_EDGE" or "RIGHT_END"
---@return number x centre of the indicator, in bar coordinates
function Gain:Offset(fraction, barWidth, width, mode)
	if width >= barWidth then
		return barWidth / 2
	end

	local x = mode == "RIGHT_END" and barWidth or fraction * barWidth

	return math.min(math.max(x, width / 2), barWidth - width / 2)
end

---@param frame Frame
local function Build(frame)
	if frame.arrow then
		return
	end

	frame.arrow = frame:CreateTexture(nil, "OVERLAY")
	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
end

---@param frame Frame
local function Finish(frame)
	local bar = frame.bar

	if bar then
		Gain.active[bar] = nil
	end

	Gain.pool:Release(frame)
end

---@param frame Frame
---@param elapsed number seconds into the animation
local function Paint(frame, elapsed)
	local arrowX, arrowY, arrowAlpha, textY, textAlpha = Gain:Keyframe(elapsed, frame.scale)

	frame.arrow:ClearAllPoints()
	frame.arrow:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", frame.arrowX + arrowX, arrowY)
	frame.arrow:SetAlpha(arrowAlpha)

	frame.text:ClearAllPoints()
	frame.text:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", frame.textX, textY + frame.textY)
	frame.text:SetAlpha(textAlpha)
end

---@param frame Frame
---@param delta number
local function OnUpdate(frame, delta)
	frame.elapsed = frame.elapsed + delta

	Paint(frame, frame.elapsed)

	if frame.elapsed >= DURATION then
		Finish(frame)
	end
end

---@param frame Frame
---@param bar LBBar
---@param height number the indicator's own height
local function Anchor(frame, bar, x, height)
	local top = bar:GetTop()
	local screen = UIParent:GetTop()

	frame:ClearAllPoints()

	if top and screen and top + height + TRAVEL > screen then
		frame:SetPoint("BOTTOM", bar, "BOTTOMLEFT", x, -(height + GAP))

		return
	end

	frame:SetPoint("BOTTOM", bar, "TOPLEFT", x, GAP)
end

---@param bar LBBar
---@param amount number
---@param held boolean? stop at the top of the rise and stay there, for editing the settings
function Gain:Show(bar, amount, held)
	local settings = LB.Profile:Get("gain")

	if not settings.enabled or amount <= 0 then
		return
	end

	if settings.hideInCombat and (self.inCombat or InCombatLockdown()) then
		return
	end

	local frame = self.active[bar]

	if not frame then
		frame = self.pool:Acquire()
		frame.amount = 0
		self.active[bar] = frame
	end

	Build(frame)

	local style = settings.text
	local size = style.size * 2
	local scale = size / BASE_SIZE
	local color = settings.colors[bar.id] or settings.colors.xp
	local path = LB.Media:FetchOrDefault("font", style.font)

	frame.bar = bar
	frame.amount = frame.amount + amount
	frame.elapsed = 0
	frame.scale = scale
	frame.textY = style.y or 0

	frame:SetParent(bar)
	frame:SetFrameLevel(bar:GetFrameLevel() + 20)

	frame.arrow:SetTexture(LB.Media.textures.gainArrow)
	frame.arrow:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
	PixelUtil.SetSize(frame.arrow, size, size)

	if path then
		frame.text:SetFont(path, style.size, OUTLINES[style.outline] or "")
	end

	frame.text:SetTextColor(style.color[1], style.color[2], style.color[3], style.color[4] or 1)
	frame.text:SetText(("+%s"):format(LB.Format:Number(frame.amount)))

	local textWidth = frame.text:GetStringWidth()
	local width = size + GAP + textWidth
	local onLeft = style.side == "LEFT"

	frame.arrowX = onLeft and (textWidth + GAP) or 0
	frame.textX = (onLeft and 0 or (size + GAP)) + (style.x or 0)

	PixelUtil.SetSize(frame, math.max(width, 1), size)

	local snapshot = bar.snapshot or LB.Model:Get(bar.id)
	local fraction = snapshot and LB.Model:Fractions(snapshot) or 0

	Anchor(frame, bar, self:Offset(fraction, bar:GetWidth(), width, settings.position), size)

	frame.held = held == true

	frame:SetScript("OnUpdate", not frame.held and OnUpdate or nil)
	frame:Show()

	Paint(frame, frame.held and HOLD_AT or 0)
end

---@param bar LBBar
function Gain:OnProgress(bar)
	local source = LB.Model:Source(bar.id)

	if not source or LB.Preview:IsActive() then
		return
	end

	self:ClearPreview()
	self:Show(bar, source.delta or 0)
end

function Gain:Preview()
	local group = LB.BarGroup
	local frame = group.frame

	if not frame or not frame:IsShown() then
		return
	end

	self:ReleaseAll()

	self.previewing = true

	if group.settling then
		return
	end

	for _, bar in pairs(group.bars) do
		if bar:IsShown() then
			self:Show(bar, PREVIEW_AMOUNT, true)
		end
	end
end

function Gain:OnLayoutSettled()
	if self.previewing then
		self:Preview()
	end
end

function Gain:ClearPreview()
	if not self.previewing then
		return
	end

	self.previewing = false

	self:ReleaseAll()
end

---@param bar LBBar
function Gain:Release(bar)
	local frame = self.active[bar]

	if not frame then
		return
	end

	self.active[bar] = nil
	self.pool:Release(frame)
end

function Gain:ReleaseAll()
	self.pool:ReleaseAll()
	wipe(self.active)
end

---@param inCombat boolean
function Gain:SetCombat(inCombat)
	self.inCombat = inCombat

	if inCombat and LB.Profile:Get("gain.hideInCombat") then
		self:ReleaseAll()
	end
end

LB.Events:Register("PLAYER_REGEN_DISABLED", Gain, function()
	Gain:SetCombat(true)
end)

LB.Events:Register("PLAYER_REGEN_ENABLED", Gain, function()
	Gain:SetCombat(false)
end)

Callbacks:Register("Settings", Gain, function(_, path)
	if not LB.Profile:Get("gain.enabled") then
		Gain:ReleaseAll()

		return
	end

	if LB.Settings:IsOpen() and type(path) == "string" and path:find("^gain") then
		LB.Events:Merge("gain:preview", PREVIEW_MERGE, function()
			Gain:Preview()
		end)
	end
end)
