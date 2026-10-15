local LB = select(2, ...)

local L = LB.L
local LIMITS = LB.LIMITS
local Settings = LB.Settings

local UP_DOWN = {
	{ value = "UP", label = L["Up"] },
	{ value = "DOWN", label = L["Down"] },
}

local LEFT_RIGHT = {
	{ value = "LEFT", label = L["Left"] },
	{ value = "RIGHT", label = L["Right"] },
}

---@return boolean
local function ShowsBars()
	return LB.Profile:Get("party.display") == "BARS"
end

---@return boolean
local function ShowsMarkers()
	return not ShowsBars()
end

---@param window table
function Settings:DeclareParty(window)
	window:Header("party", L["Party"])
	self:DeclarePartyProgress(window:Page("markers", {
		title = L["Party Progress"],
		under = "party",
		description = L["Party members running Levelbound, as markers on your experience bar or as bars of their own."],
		switch = {
			path = "party.markers",
			default = self:Default("party.markers"),
			label = L["Show Party Progress"],
			tooltip = self:Tooltip("markers", "markers"),
		},
	}))
	self:DeclareLevelUps(window:Page("levelups", {
		title = L["Level-Ups"],
		under = "party",
		description = L["Party level-up notices, and messages about your own level-ups and runs."],
	}))
end

---The Display choice, at the top of whichever set of sections it shows.
---@param section table
---@param id string
function Settings:DeclareDisplay(section, id)
	self:Add(section, "Dropdown", "markers", {
		id = id,
		label = L["Display"],
		path = "party.display",
		tooltip = self:Tooltip("markers", "display"),
		options = self:Choices({
			{ value = "MARKERS", label = L["Markers on Your Bar"] },
			{ value = "BARS", label = L["Standalone Bars"] },
		}),
	})
	section:Skip()
end

---@param page table
function Settings:DeclarePartyProgress(page)
	LB.SettingsPreviews:Declare(page, "markers")
	self:DeclareMarkers(page)
	self:DeclarePartyBars(page)
end

---@param page table
function Settings:DeclareMarkers(page)
	local KEY = "markers"

	---@return string?
	local function Matched()
		if LB.Profile:Get("party.opacity.matchBar") == true then
			return L["Uses the bar's opacity."]
		end
	end

	---@return string?
	local function MatchedOrNoFade()
		local matched = Matched()

		if matched then
			return matched
		end

		if LB.Profile:Get("party.opacity.fadeUntilHovered") ~= true then
			return L["Needs Fade Until Hovered."]
		end
	end

	---@return string?
	local function Tick()
		if LB.Profile:Get("party.style") == "TICK" then
			return L["The full-height tick always spans the bar."]
		end
	end

	local markers = page:Section("markers", L["Party Markers"], { show = ShowsMarkers })

	self:DeclareDisplay(markers, "display")
	self:Add(markers, "Dropdown", KEY, {
		id = "style",
		label = L["Marker Style"],
		default = self:Default("party.style"),
		redraws = true,
		options = self:Choices({
			{ value = "DOT", label = L["Dot"] },
			{ value = "TICK", label = L["Full-Height Tick"] },
			{ value = "NOTCH", label = L["Notch"] },
			{ value = "DIAMOND", label = L["Diamond"] },
			{ value = "PIP", label = L["Pip"] },
			{ value = "ICON_CIRCLE", label = L["Class Icon (Circle)"] },
			{ value = "ICON_DIAMOND", label = L["Class Icon (Diamond)"] },
			{ value = "ICON_RING", label = L["Class Icon (Ring)"] },
		}),
		get = function()
			return LB.Profile:Get("party.style")
		end,
		set = function(value)
			self:SetStyle("party.style", value)
		end,
	})
	self:Add(markers, "Slider", KEY, { id = "size", label = L["Marker Size"], path = "party.size",
		min = LIMITS.markerSize.min, max = LIMITS.markerSize.max, step = 1 })
	self:Add(markers, "Dropdown", KEY, {
		id = "anchor",
		label = L["Anchor"],
		path = "party.anchor",
		options = self:Choices({
			{ value = "CENTER", label = L["Center"] },
			{ value = "TOP", label = L["Top"] },
			{ value = "BOTTOM", label = L["Bottom"] },
		}),
		blocked = Tick,
	})
	self:Add(markers, "Slider", KEY, { id = "y", label = L["Vertical Offset"], path = "party.y",
		min = LIMITS.markerOffset.min, max = LIMITS.markerOffset.max, step = 1, blocked = Tick })

	local fading = page:Section("fading", L["Marker Fading"], { show = ShowsMarkers })

	self:Add(fading, "Checkbox", KEY, { id = "matchBar", label = L["Match Bar Opacity"],
		path = "party.opacity.matchBar" })

	local getAlpha, setAlpha = self:Percent("party.opacity.alpha")

	self:Add(fading, "Slider", KEY, { id = "alpha", label = L["Marker Opacity"], min = 0, max = 100, step = 5,
		format = "percent", get = getAlpha, set = setAlpha, blocked = Matched })
	self:Add(fading, "Checkbox", KEY, { id = "fade", label = L["Fade Until Hovered"],
		path = "party.opacity.fadeUntilHovered", blocked = Matched })

	local getFaded, setFaded = self:Percent("party.opacity.fadedAlpha")

	self:Add(fading, "Slider", KEY, { id = "fadedAlpha", label = L["Faded Opacity"], min = 0, max = 100, step = 5,
		format = "percent", get = getFaded, set = setFaded, blocked = MatchedOrNoFade })
	self:Add(fading, "Checkbox", KEY, { id = "fullInCombat", label = L["Fully Visible in Combat"],
		path = "party.opacity.fullInCombat", blocked = MatchedOrNoFade })
	self:Add(fading, "Checkbox", KEY, { id = "fullWithTarget", label = L["Fully Visible with a Target"],
		path = "party.opacity.fullWithTarget", blocked = MatchedOrNoFade })
end

---@param page table
function Settings:DeclarePartyBars(page)
	local KEY = "markers"
	local VISIBILITY = "party.bars.visibility."

	---@return string?
	local function HeldHeight()
		if LB.Border:FixedHeight(LB.Profile:Get("appearance.border.style")) then
			return L["Set by the border style."]
		end
	end

	---@return string?
	local function Compact()
		if LB.Profile:Get("party.bars.compact") == true then
			return L["Compact sets the gap to 1 pixel."]
		end
	end

	---@return string?
	local function Matched()
		if LB.Profile:Get("party.bars.matchBar") == true then
			return L["Uses the bars' Visibility settings."]
		end
	end

	---@return string?
	local function MatchedOrNoFade()
		local matched = Matched()

		if matched then
			return matched
		end

		if LB.Profile:Get(VISIBILITY .. "fadeUntilHovered") ~= true then
			return L["Needs Fade Until Hovered."]
		end
	end

	local bars = page:Section("bars", L["Party Bars"], { show = ShowsBars })

	self:DeclareDisplay(bars, "barsDisplay")
	self:Add(bars, "Checkbox", KEY, { id = "classColor", label = L["Class Color Fill"],
		path = "party.bars.classColor" })
	-- Compact changes which text slots can be edited, so every row redraws.
	self:Add(bars, "Checkbox", KEY, { id = "compact", label = L["Compact"], path = "party.bars.compact",
		redraws = true })
	self:Add(bars, "Slider", KEY, {
		id = "width",
		label = L["Width"],
		path = "party.bars.width",
		min = LIMITS.barWidth.min,
		max = function()
			return math.floor(UIParent:GetWidth())
		end,
		step = 1,
	})
	self:Add(bars, "Slider", KEY, { id = "height", label = L["Height"], path = "party.bars.height",
		min = LIMITS.barHeight.min, max = LIMITS.barHeight.max, step = 1, blocked = HeldHeight })
	self:Add(bars, "Slider", KEY, { id = "gap", label = L["Gap Between Bars"], path = "party.bars.gap", min = 0,
		max = 10, step = 1, blocked = Compact })
	self:Add(bars, "Dropdown", KEY, { id = "growth", label = L["Growth Direction"], path = "party.bars.growth",
		options = self:Choices(UP_DOWN) })

	LB.SettingsText:Declare(page, "party", ShowsBars)

	local visibility = page:Section("partyVisibility", L["Visibility"], { show = ShowsBars })

	self:Add(visibility, "Checkbox", KEY, { id = "barsMatch", label = L["Match Bar Visibility"],
		path = "party.bars.matchBar" })
	visibility:Skip()
	self:Add(visibility, "Checkbox", KEY, { id = "barsHideInCombat", label = L["Hide in Combat"],
		path = VISIBILITY .. "hideInCombat", blocked = Matched })
	visibility:Skip()
	self:Add(visibility, "Checkbox", KEY, { id = "barsFade", label = L["Fade Until Hovered"],
		path = VISIBILITY .. "fadeUntilHovered", blocked = Matched })

	local getFaded, setFaded = self:Percent(VISIBILITY .. "fadedAlpha")

	self:Add(visibility, "Slider", KEY, { id = "barsFadedAlpha", label = L["Faded Opacity"], min = 0, max = 100,
		step = 5, format = "percent", get = getFaded, set = setFaded, blocked = MatchedOrNoFade })
	self:Add(visibility, "Checkbox", KEY, { id = "barsFullInCombat", label = L["Fully Visible in Combat"],
		path = VISIBILITY .. "fullInCombat", blocked = MatchedOrNoFade })
	self:Add(visibility, "Checkbox", KEY, { id = "barsFullWithTarget", label = L["Fully Visible with a Target"],
		path = VISIBILITY .. "fullWithTarget", blocked = MatchedOrNoFade })
end

---@param page table
function Settings:DeclareLevelUps(page)
	local KEY = "levelups"

	LB.SettingsPreviews:Declare(page, "levelups")

	local function Detached()
		if LB.Profile:Get("party.levelUp.detached") == true then
			return L["Detached: placed in Edit Mode."]
		end
	end

	local function Beside()
		local anchor = LB.Profile:Get("party.levelUp.anchor")

		return not Detached() and (anchor == "RIGHT" or anchor == "LEFT")
	end

	local function Sliding()
		return LB.Profile:Get("party.levelUp.animation") == "SLIDE"
	end

	-- With Slide Outward, the detached stack's lines sit side by side, growing left or right.
	local function DirectionPath()
		return Detached() and Sliding() and "party.levelUp.across" or "party.levelUp.direction"
	end

	local notices = page:Section("notices", L["Party Notices"])

	self:Add(notices, "Toggle", KEY, { id = "notices", label = L["Show Level-Up Notices"],
		path = "party.levelUp.enabled" })
	notices:Skip()
	self:Add(notices, "Checkbox", KEY, { id = "onScreen", label = L["On-Screen Notice"],
		path = "party.levelUp.onScreen", depends = "notices" })
	self:Add(notices, "Checkbox", KEY, { id = "chat", label = L["Chat Message"], path = "party.levelUp.chat",
		depends = "notices" })
	self:Add(notices, "Dropdown", KEY, { id = "sound", label = SOUND, path = "party.levelUp.sound", picker = "sound",
		options = { { value = "None", text = NONE } }, depends = "notices" })
	self:Add(notices, "Checkbox", KEY, { id = "hideInCombat", label = L["Hide in Combat"],
		path = "party.levelUp.hideInCombat", depends = "notices" })

	local placement = page:Section("placement", L["Placement"])

	self:Add(placement, "Checkbox", KEY, { id = "detached", label = L["Detach from Bar"],
		path = "party.levelUp.detached", depends = "onScreen" }, L["Place it in Edit Mode."])
	placement:Skip()
	self:Add(placement, "Dropdown", KEY, {
		id = "anchor",
		label = L["Anchor"],
		path = "party.levelUp.anchor",
		options = self:Choices({
			{ value = "TOPLEFT", label = L["Top Left"] },
			{ value = "TOP", label = L["Top"] },
			{ value = "TOPRIGHT", label = L["Top Right"] },
			{ value = "BOTTOMLEFT", label = L["Bottom Left"] },
			{ value = "BOTTOM", label = L["Bottom"] },
			{ value = "BOTTOMRIGHT", label = L["Bottom Right"] },
			{ value = "RIGHT", label = L["Right of Bar"] },
			{ value = "LEFT", label = L["Left of Bar"] },
		}),
		depends = "onScreen",
		blocked = Detached,
	})
	self:Add(placement, "Dropdown", KEY, {
		id = "direction",
		label = L["Growth Direction"],
		options = self:Choices(function()
			return DirectionPath() == "party.levelUp.across" and LEFT_RIGHT or UP_DOWN
		end),
		depends = "onScreen",
		get = function()
			return LB.Profile:Get(DirectionPath())
		end,
		set = function(value)
			LB.Profile:Set(DirectionPath(), value)
		end,
		blocked = function()
			if Beside() and Sliding() then
				return L["Slide Outward grows the stack away from the bars."]
			end
		end,
	})
	self:Add(placement, "Dropdown", KEY, {
		id = "animation",
		label = L["Animation Style"],
		path = "party.levelUp.animation",
		options = self:Choices({
			{ value = "RISE", label = L["Rise"] },
			{ value = "SLIDE", label = L["Slide Outward"] },
		}),
		depends = "onScreen",
		blocked = function()
			if not Beside() and not Detached() then
				return L["Only beside the bar, or detached."]
			end
		end,
	})
	placement:Skip()
	self:Add(placement, "Slider", KEY, { id = "x", label = L["Horizontal Offset"], path = "party.levelUp.x",
		min = -300, max = 300, step = 1, depends = "onScreen", blocked = Detached })
	self:Add(placement, "Slider", KEY, { id = "y", label = L["Vertical Offset"], path = "party.levelUp.y",
		min = -200, max = 200, step = 1, depends = "onScreen", blocked = Detached })

	local text = page:Section("text", L["Notice Text"])

	self:Add(text, "Dropdown", KEY, { id = "font", label = L["Font"], path = "party.levelUp.text.font",
		picker = "font", depends = "onScreen" })
	self:Add(text, "Slider", KEY, { id = "size", label = L["Size"], path = "party.levelUp.text.size",
		min = LIMITS.textSize.min, max = LIMITS.textSize.max, step = 1, depends = "onScreen" })
	self:Add(text, "Dropdown", KEY, { id = "outline", label = L["Outline"], path = "party.levelUp.text.outline",
		options = self:Choices(LB.Media.outlines), depends = "onScreen" })

	local announce = page:Section("announce", L["Level-Ups"])

	self:Add(announce, "Checkbox", KEY, { id = "levelUpEmote", label = L["Print Level-Up Message"],
		path = "party.announce.levelUpEmote" })
	announce:Skip()
	self:Add(announce, "Checkbox", KEY, { id = "levelUpParty", label = L["Party Level-Up Message"],
		path = "party.announce.levelUpParty" })
	self:Add(announce, "Checkbox", KEY, { id = "levelUpGuild", label = L["Guild Level-Up Message"],
		path = "party.announce.levelUpGuild" })

	local summary = page:Section("summary", L["Dungeon Summary"])

	self:Add(summary, "Checkbox", KEY, { id = "runSummary", label = L["Post-Dungeon Summary"],
		path = "party.announce.runSummary" })
	self:Add(summary, "Dropdown", KEY, {
		id = "runChannel",
		label = L["Channels"],
		path = "party.announce.runChannel",
		options = self:Choices({
			{ value = "SELF", label = L["Self Only"] },
			{ value = "PARTY", label = PARTY },
			{ value = "INSTANCE", label = INSTANCE_CHAT },
			{ value = "GUILD", label = GUILD },
		}),
		depends = "runSummary",
	})
end
