local LB = select(2, ...)

local L = LB.L

local FRAME_NAME = "LevelboundStylePicker"
local WIDTH = 560
local TOP = 34 -- below the title bar
local SIDE = 18
local CARD_GAP = 10
local CARD_PAD = 14
local TITLE_TO_TEXT = 4
local SAMPLE_GAP = 14 -- the least room above and below a sample
local CARD_EDGE = 10 -- the card art's band, from its outer edge to its inner one
local SAMPLE_WIDTH = 480
local TEXT_GAP = 2 -- an outer text slot's gap from the bar
local FOOTER = 34
local BLIZZARD_WIDTH = 1020 -- the Blizzard frame's own width
local TITLE_SIZE = 20
local CARD_SLICE = 20 -- the card art's corners, in texels, kept unstretched
local GOLD = { 1, 0.82, 0 }
local FRAME_TINT = { 132 / 255, 105 / 255, 82 / 255 } -- the card frame art's own bronze

---@alias LBStyle "BLIZZARD" | "MODERN"

---The first-run choice of starting look: two cards, each with a sample experience bar drawn in that look.
---@class LBStylePicker
---@field frame Frame?
---@field chosen boolean? a card was picked, so hiding the dialog chooses nothing more
---@field pending boolean? waiting for combat to end before showing
local StylePicker = {}
LB.StylePicker = StylePicker

---Turns a profile into the Blizzard look: the Blizzard border and fill, no text on any bar, dividers every 5 % and
---pip markers at Blizzard's rested tick size.
---@param profile LBProfileData
---@param maxWidth number the widest a bar can be on this screen
function StylePicker.ApplyBlizzard(profile, maxWidth)
	local appearance = profile.appearance

	appearance.border.style = "BLIZZARD"
	appearance.texture = "Levelbound Blizzard"
	appearance.dividers.enabled = true
	appearance.dividers.spacing = 5

	profile.layout.width = math.min(BLIZZARD_WIDTH, math.floor(maxWidth))

	profile.party.style = "PIP"
	LB.Marker.WriteBlizzardPip(function(key, value)
		profile.party[key] = value
	end)

	-- Slots keep their place with an empty template, which loading never refills from the defaults.
	for _, slots in pairs(profile.text.slots) do
		for _, slot in pairs(slots) do
			slot.text = ""
		end
	end
end

---Saves the choice and applies it to the active profile.
---@param style LBStyle
function StylePicker:Choose(style)
	self.chosen = true
	LB.Profile:Global().styleChosen = true

	if style == "BLIZZARD" then
		LB.Profile:Apply(function(profile)
			StylePicker.ApplyBlizzard(profile, UIParent:GetWidth())
		end)
	end

	if self.frame then
		self.frame:Hide()
	end
end

---Draws a sample experience bar in the look `profile` describes, with the sample party's markers, and returns how
---far its text and markers reach above and below it.
---@param parent Frame
---@param profile LBProfileData
---@return LBBar bar
---@return number above
---@return number below
local function Sample(parent, profile)
	local bar = LB.Bar:Create(parent, "xp")
	local above, below = 0, 0

	bar:EnableMouse(false)
	bar.border = LB.Border:Create(bar)

	LB.Profile:Read(profile, function()
		local layout = LB.Profile:Get("layout")
		local border = LB.Profile:Get("appearance.border")
		local height = LB.Layout.Height(layout, LB.Border:FixedHeight(border.style))

		bar:SetGeometry(SAMPLE_WIDTH, height)
		bar:ApplyAppearance()
		bar:SetSnapshot(LB.Preview:Snapshot("xp"), false, false)
		bar.border:Apply(border.style, LB.Border:Color(border.style, border), height, border.width)
		bar:SetEndMasks(LB.Border:EndMask(border.style), true, true)
		local shown = LB.TextSlot:ApplySample(bar, false)
		local party = LB.Profile:Get("party")
		local metrics = LB.Marker:Current()
		local reach = LB.TextSlot:BorderReach(nil)

		LB.Marker:Apply(bar, LB.Marker:SampleParty())
		above, below = LB.Marker.Reach(party.style, metrics.anchor, metrics.y, metrics.height, height)

		for key, fontString in pairs(shown) do
			local extent = fontString:GetStringHeight() + TEXT_GAP + reach

			if key:find("^ABOVE") then
				above = math.max(above, extent)
			elseif key:find("^BELOW") then
				below = math.max(below, extent)
			end
		end

		above, below = math.max(above, reach), math.max(below, reach)
	end)

	-- The markers are drawn once, from `profile`: a later resize would redraw them from the active profile.
	if bar.markerLayer then
		bar.markerLayer:SetScript("OnSizeChanged", nil)
	end

	-- The card takes every click and hover.
	for _, marker in pairs(bar.markerShown or {}) do
		marker:EnableMouse(false)
	end

	return bar, above, below
end

---@param frame Frame
---@param style LBStyle
---@param title string
---@param text string
---@param profile LBProfileData
---@return Button card its `needed` field is the height its content takes, for sizing both cards alike
function StylePicker:Card(frame, style, title, text, profile)
	local AS = LB.AeonSettings
	local card = CreateFrame("Button", nil, frame)

	---@param layer DrawLayer
	---@param path string
	---@return Texture
	local function Sliced(layer, path)
		local texture = card:CreateTexture(nil, layer)

		texture:SetTexture(path)
		texture:SetTextureSliceMargins(CARD_SLICE, CARD_SLICE, CARD_SLICE, CARD_SLICE)
		texture:SetTextureSliceMode(Enum.UITextureSliceMode.Stretched)
		texture:SetAllPoints()

		return texture
	end

	card.fill = Sliced("BACKGROUND", LB.Media.textures.styleCardFill)
	card.frame = Sliced("BORDER", LB.Media.textures.styleCardFrame)
	card.frame:SetVertexColor(unpack(FRAME_TINT))

	card.title = card:CreateFontString(nil, "ARTWORK")
	AS:SetFont(card.title, "header", TITLE_SIZE)
	card.title:SetTextColor(unpack(GOLD))
	card.title:SetPoint("TOP", 0, -CARD_PAD)
	card.title:SetText(title)

	card.text = card:CreateFontString(nil, "ARTWORK")
	AS:SetFont(card.text, "body")
	card.text:SetTextColor(1, 1, 1, 1)
	card.text:SetPoint("TOP", card.title, "BOTTOM", 0, -TITLE_TO_TEXT)
	card.text:SetPoint("LEFT", CARD_PAD, 0)
	card.text:SetPoint("RIGHT", -CARD_PAD, 0)
	card.text:SetJustifyH("CENTER")
	card.text:SetText(text)

	local room = CreateFrame("Frame", nil, card)

	-- The room spans from the description to the band's inner edge; the sample, its text and markers included, sits
	-- in its middle, so the space above and below it matches.
	room:SetPoint("TOP", card.text, "BOTTOM")
	room:SetPoint("LEFT", CARD_PAD, 0)
	room:SetPoint("RIGHT", -CARD_PAD, 0)
	room:SetPoint("BOTTOM", card, "BOTTOM", 0, CARD_EDGE)

	local bar, above, below = Sample(room, profile)
	local sample = above + bar:GetHeight() + below

	bar:SetPoint("CENTER", room, "CENTER", 0, (below - above) / 2)

	card.needed = CARD_PAD + card.title:GetStringHeight() + TITLE_TO_TEXT + card.text:GetStringHeight()
		+ SAMPLE_GAP * 2 + sample + CARD_EDGE
	card:SetScript("OnEnter", function()
		card.frame:SetVertexColor(unpack(GOLD))
	end)
	card:SetScript("OnLeave", function()
		card.frame:SetVertexColor(unpack(FRAME_TINT))
	end)
	card:SetScript("OnClick", function()
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
		self:Choose(style)
	end)

	return card
end

---@return Frame
function StylePicker:Create()
	if self.frame then
		return self.frame
	end

	local AS = LB.AeonSettings
	local tokens = AS.tokens
	local frame = CreateFrame("Frame", FRAME_NAME, UIParent, "SettingsFrameTemplate")

	frame:SetFrameStrata("DIALOG")
	frame:SetToplevel(true)
	frame:SetClampedToScreen(true)
	frame:SetMovable(true)
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
	frame:SetPoint("CENTER", UIParent, "CENTER", 0, 80)
	frame.NineSlice.Text:SetText(L["Choose Your Style"])
	tinsert(UISpecialFrames, FRAME_NAME)

	local blizzard = LB:CopyTable(LB.Profile.active)

	StylePicker.ApplyBlizzard(blizzard, UIParent:GetWidth())

	local first = self:Card(frame, "BLIZZARD", L["Blizzard"],
		L["The classic experience bar: Blizzard's frame and fill, no text."], blizzard)
	local second = self:Card(frame, "MODERN", L["Modern"], L["Levelbound's clean look, with text on hover."],
		LB.Profile:Defaults())

	-- Both cards take the taller one's height.
	local height = math.max(first.needed, second.needed)

	first:SetHeight(height)
	second:SetHeight(height)
	first:SetPoint("TOPLEFT", SIDE, -TOP)
	first:SetPoint("RIGHT", -SIDE, 0)
	second:SetPoint("TOPLEFT", first, "BOTTOMLEFT", 0, -CARD_GAP)
	second:SetPoint("RIGHT", -SIDE, 0)

	local footer = frame:CreateFontString(nil, "ARTWORK")

	AS:SetFont(footer, "body", tokens.font.hintSize + 1)
	footer:SetTextColor(1, 1, 1, tokens.alpha.description)
	footer:SetPoint("TOP", second, "BOTTOM", 0, -CARD_GAP)
	footer:SetText(L["You can change everything later with /lb."])

	frame:SetSize(WIDTH, TOP + first:GetHeight() + CARD_GAP + second:GetHeight() + FOOTER)

	-- Closing without a pick keeps the current look, which is Modern on a fresh install.
	frame:SetScript("OnHide", function()
		if not self.chosen then
			self:Choose("MODERN")
		end
	end)

	self.frame = frame

	return frame
end

---Shows the choice once, on an account that has not made it, never during combat.
function StylePicker:Offer()
	if LB.Profile:Global().styleChosen or self.chosen then
		return
	end

	if InCombatLockdown() then
		if not self.pending then
			self.pending = true
			LB.Events:Register("PLAYER_REGEN_ENABLED", self, function()
				LB.Events:Unregister("PLAYER_REGEN_ENABLED", self)
				self.pending = false
				self:Offer()
			end)
		end

		return
	end

	self:Create():Show()
end
