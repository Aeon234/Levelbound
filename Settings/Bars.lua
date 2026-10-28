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

-- Descriptions for the four bar pages are kept under the former Layout page's key.
local KEY = "layout"

---@return { value: string, label: string }[]
local function Outlines()
	return LB.Media.outlines
end

-- None and the flat lines lead; the textured styles follow in each locale's alphabetical order.
---@return { value: string, label: string }[]
local function BorderStyles()
	local textured = {
		{ value = "ROUNDED", label = L["Simple"] },
		{ value = "ROUNDED_THICK", label = L["Simple Thick"] },
		{ value = "BRONZE", label = L["Bronze"] },
		{ value = "METALLIC", label = L["Metallic"] },
		{ value = "BLIZZARD", label = L["Blizzard"] },
	}

	table.sort(textured, function(a, b)
		return strcmputf8i(a.label, b.label) < 0
	end)

	local options = {
		{ value = "NONE", label = NONE },
		{ value = "PIXEL", label = L["Pixel"] },
		{ value = "PILL", label = L["Pill"] },
	}

	for _, option in ipairs(textured) do
		options[#options + 1] = option
	end

	return options
end

---Saves a border style or marker style. Choosing Pill starts its outline at 0; choosing Pixel after it raises a 0
---width to Pixel's least; putting the Pip marker on the Blizzard border starts the pip at Blizzard's rested tick's
---size and place.
---@param path "appearance.border.style" | "party.style"
---@param value string
function Settings:SetStyle(path, value)
	local function Paired()
		return LB.Profile:Get("party.style") == "PIP" and LB.Profile:Get("appearance.border.style") == "BLIZZARD"
	end

	local wasPaired = Paired()

	LB.Profile:Set(path, value)

	if path == "appearance.border.style" and value == "PILL" then
		LB.Profile:Set("appearance.border.width", 0)
	elseif path == "appearance.border.style" and value == "PIXEL" then
		local width = LB.Profile:Get("appearance.border.width")

		LB.Profile:Set("appearance.border.width", math.max(width, LIMITS.borderWidth.min))
	end

	if not wasPaired and Paired() then
		LB.Marker.WriteBlizzardPip(function(key, pip)
			LB.Profile:Set("party." .. key, pip)
		end)
	end
end

---@return integer the widest a bar can be set: the screen's width in UI units
local function MaxWidth()
	return math.floor(UIParent:GetWidth())
end

---@return string?
local function NotIndependent()
	if LB.Layout.Independent(LB.Profile:Get("layout")) then
		return L["Requires Segmented or Connected layout."]
	end
end

---@return string?
local function HeightFixed()
	if LB.Border:HeldHeight() then
		return L["Set by the border style."]
	end
end

---@return boolean
local function Connected()
	return LB.Profile:Get("layout.mode") == "CONNECTED"
end

---@param window table
function Settings:DeclareBars(window)
	window:Header("bars", L["Bars"])
	self:DeclareLayout(window:Page("layout", { title = L["Layout"], under = "bars",
		icon = LB.Media.sidebar.layout }))
	self:DeclareAppearance(window:Page("appearance", {
		title = L["Appearance"],
		icon = LB.Media.sidebar.appearance,
		under = "bars",
	}))
	self:DeclareText(window:Page("text", {
		title = L["Text"],
		icon = LB.Media.sidebar.text,
		under = "bars",
	}))
	self:DeclareVisibility(window:Page("visibility", {
		title = L["Visibility"],
		icon = LB.Media.sidebar.visibility,
		under = "bars",
	}))
	self:DeclareGain(window:Page("gain", {
		title = L["Gain Indicator"],
		icon = LB.Media.sidebar.gain,
		under = "bars",
		description = L["The arrow and amount shown each time a bar gains progress."],
		switch = {
			path = "gain.enabled",
			default = self:Default("gain.enabled"),
			label = L["Show Gain Indicator"],
		},
	}))
end

---@param page table
function Settings:DeclareLayout(page)
	local placement = page:Section("placement", L["Placement"])

	self:Add(placement, "Dropdown", KEY, {
		id = "mode",
		label = L["Layout Mode"],
		path = "layout.mode",
		options = self:Choices(LB.Layout.MODES),
	})
	self:Add(placement, "Dropdown", KEY, {
		id = "fullscreen",
		label = L["Fullscreen Edge"],
		path = "layout.fullscreen",
		options = self:Choices({
			{ value = "OFF", label = L["Off"] },
			{ value = "TOP", label = L["Top"] },
			{ value = "BOTTOM", label = L["Bottom"] },
		}),
		blocked = NotIndependent,
	})

	local size = page:Section("size", L["Size"])

	self:Add(size, "Slider", KEY, {
		id = "width",
		label = L["Width"],
		path = "layout.width",
		min = LIMITS.barWidth.min,
		max = MaxWidth,
		step = 1,
	})
	self:Add(size, "Slider", KEY, {
		id = "height",
		label = L["Height"],
		path = "layout.height",
		min = LIMITS.barHeight.min,
		max = LIMITS.barHeight.max,
		step = 1,
		blocked = HeightFixed,
	})

	local stacking = page:Section("stacking", L["Stacking"], { show = Connected })

	self:Add(stacking, "Dropdown", KEY, {
		id = "growth",
		label = L["Growth Direction"],
		default = self:Default("layout.growth"),
		options = self:Choices(UP_DOWN),
		get = function()
			return LB.Profile:Get("layout.growth")
		end,
		set = function(value)
			LB.BarGroup:SetGrowth(value)
		end,
	})
	self:Add(stacking, "Slider", KEY, {
		id = "gap",
		label = L["Gap Between Bars"],
		path = "layout.gap",
		min = 0,
		max = 10,
		step = 1,
	})

	local advanced = page:Section("advanced", ADVANCED_LABEL)

	self:Add(advanced, "Dropdown", KEY, {
		id = "strata",
		label = L["Frame Strata"],
		path = "layout.strata",
		options = self:Choices({
			{ value = "BACKGROUND", label = BACKGROUND },
			{ value = "LOW", label = L["Low"] },
			{ value = "MEDIUM", label = L["Medium"] },
			{ value = "HIGH", label = L["High"] },
		}),
	})
end

---@param page table
function Settings:DeclareAppearance(page)
	LB.SettingsPreviews:Declare(page, "appearance")

	local function Style()
		return LB.Profile:Get("appearance.border.style")
	end

	---@return string?
	local function NoBorder()
		if Style() == "NONE" then
			return L["Requires a border style."]
		end
	end

	local fill = page:Section("fill", L["Fill"])

	self:Add(fill, "Dropdown", KEY, { id = "texture", label = L["Bar Texture"], path = "appearance.texture",
		picker = "texture" })

	local getBackground, setBackground = self:ColorAccess("appearance.background", true)

	self:Add(fill, "Color", KEY, { id = "background", label = BACKGROUND, hasOpacity = true, get = getBackground,
		set = setBackground })

	local border = page:Section("border", L["Border"])

	self:Add(border, "Dropdown", KEY, {
		id = "borderStyle",
		label = L["Border Style"],
		default = self:Default("appearance.border.style"),
		options = self:Choices(BorderStyles),
		redraws = true,
		get = Style,
		set = function(value)
			self:SetStyle("appearance.border.style", value)
		end,
	})
	self:Add(border, "Slider", KEY, {
		id = "borderWidth",
		label = L["Border Width"],
		path = "appearance.border.width",
		min = function()
			return Style() == "PILL" and 0 or LIMITS.borderWidth.min
		end,
		max = LIMITS.borderWidth.max,
		step = 1,
		show = function()
			return Style() == "PIXEL" or Style() == "PILL"
		end,
	})
	self:Add(border, "Checkbox", KEY, {
		id = "borderCustom",
		label = L["Custom Color"],
		path = "appearance.border.customColor",
		blocked = function()
			if NoBorder() then
				return NoBorder()
			elseif not LB.Border:IsTextured(Style()) then
				return L["Requires a textured border style."]
			end
		end,
	})

	local getBorder, setBorder = self:ColorAccess("appearance.border.color", true)

	self:Add(border, "Color", KEY, {
		id = "borderColor",
		label = L["Border Color"],
		hasOpacity = true,
		get = getBorder,
		set = setBorder,
		blocked = function()
			-- Segmented layout's separators take Border Color even with no border.
			if NoBorder() and LB.Profile:Get("layout.mode") ~= "SEGMENTED" then
				return NoBorder()
			elseif LB.Border:IsTextured(Style()) and LB.Profile:Get("appearance.border.customColor") ~= true then
				return L["Requires Custom Color."]
			end
		end,
	})
	local dividers = page:Section("dividers", L["XP Dividers"])

	self:Add(dividers, "Checkbox", KEY, { id = "dividers", label = L["Show Dividers"],
		path = "appearance.dividers.enabled" })
	self:Add(dividers, "Dropdown", KEY, {
		id = "dividerSpacing",
		label = L["Spacing"],
		path = "appearance.dividers.spacing",
		options = self:Choices({
			{ value = 10, label = L["Every 10%"] },
			{ value = 5, label = L["Every 5%"] },
		}),
		depends = "dividers",
	})
	self:Add(dividers, "Checkbox", KEY, { id = "dividerCustom", label = L["Custom Color"],
		path = "appearance.dividers.customColor", depends = "dividers" })

	local getDivider, setDivider = self:ColorAccess("appearance.dividers.color")

	self:Add(dividers, "Color", KEY, { id = "dividerColor", label = L["Divider Color"], get = getDivider,
		set = setDivider, depends = "dividerCustom" })

	local spark = page:Section("spark", L["Spark and Shimmer"])

	self:Add(spark, "Checkbox", KEY, { id = "spark", label = L["Progress Spark"], path = "appearance.spark.enabled" })
	self:Add(spark, "Checkbox", KEY, { id = "sparkCustom", label = L["Custom Color"],
		path = "appearance.spark.customColor", depends = "spark" })

	local getSpark, setSpark = self:ColorAccess("appearance.spark.color")

	self:Add(spark, "Color", KEY, { id = "sparkColor", label = L["Spark Color"], get = getSpark, set = setSpark,
		depends = "sparkCustom" })
	self:Add(spark, "Checkbox", KEY, { id = "glow", label = L["Edge Glow"], path = "appearance.glow" })
	self:Add(spark, "Checkbox", KEY, { id = "shimmer", label = L["Gain Shimmer"], path = "appearance.shimmer" })
end

---@param page table
function Settings:DeclareText(page)
	local style = page:Section("style", L["Text Style"])

	self:Add(style, "Dropdown", KEY, { id = "font", label = L["Font"], path = "text.style.font", picker = "font" })
	self:Add(style, "Slider", KEY, {
		id = "size",
		label = L["Size"],
		path = "text.style.size",
		min = LIMITS.textSize.min,
		max = LIMITS.textSize.max,
		step = 1,
	})
	self:Add(style, "Dropdown", KEY, { id = "outline", label = L["Outline"], path = "text.style.outline",
		options = self:Choices(Outlines) })

	local getColor, setColor = self:ColorAccess("text.style.color")

	self:Add(style, "Color", KEY, { id = "color", label = COLOR, get = getColor, set = setColor })

	local numbers = page:Section("numbers", L["Numbers"])

	self:Add(numbers, "Checkbox", KEY, { id = "compact", label = L["Compact Numbers"], path = "text.compactNumbers" })
	self:Add(numbers, "Checkbox", KEY, { id = "decimals", label = L["Show Decimals"], path = "text.decimals" })
end

---@param page table
function Settings:DeclareVisibility(page)
	local fading = page:Section("fading", L["Fading"])

	self:Add(fading, "Checkbox", KEY, { id = "fade", label = L["Fade Until Hovered"],
		path = "visibility.fadeUntilHovered" })

	local getFaded, setFaded = self:Percent("visibility.fadedAlpha")

	self:Add(fading, "Slider", KEY, { id = "fadedAlpha", label = L["Faded Opacity"], min = 0, max = 100, step = 5,
		format = "percent", get = getFaded, set = setFaded, depends = "fade" })
	self:Add(fading, "Checkbox", KEY, { id = "fullInCombat", label = L["Fully Visible in Combat"],
		path = "visibility.fullInCombat", depends = "fade", blocked = function()
			if LB.Profile:Get("visibility.hideInCombat") == true then
				return L["Set by Hide in Combat."]
			end
		end })
	self:Add(fading, "Checkbox", KEY, { id = "fullWithTarget", label = L["Fully Visible with a Target"],
		path = "visibility.fullWithTarget", depends = "fade" })

	local focus = page:Section("focus", L["Focus Mode"])

	self:Add(focus, "Checkbox", KEY, { id = "focus", label = L["Dim Other Bars on Hover"],
		path = "visibility.focus.enabled" })

	local getDimmed, setDimmed = self:Percent("visibility.focus.alpha")

	self:Add(focus, "Slider", KEY, { id = "focusAlpha", label = L["Dimmed Opacity"], min = 0, max = 100, step = 5,
		format = "percent", get = getDimmed, set = setDimmed, depends = "focus" })

	local hiding = page:Section("hiding", L["Hiding"])

	self:Add(hiding, "Checkbox", KEY, { id = "hideInCombat", label = L["Hide in Combat"],
		path = "visibility.hideInCombat" })
end

---@param page table
function Settings:DeclareGain(page)
	LB.SettingsPreviews:Declare(page, "gain")

	local function Detached()
		return LB.Profile:Get("gain.detached") == true
	end

	local function Beside()
		local position = LB.Profile:Get("gain.position")

		return not Detached() and (position == "OUTSIDE_RIGHT" or position == "OUTSIDE_LEFT")
	end

	-- With Slide Outward, the detached stack's lines sit side by side, growing left or right.
	local function DirectionPath()
		return Detached() and LB.Profile:Get("gain.animation") == "SLIDE" and "gain.across" or "gain.direction"
	end

	local behavior = page:Section("behavior", L["Behavior"])

	self:Add(behavior, "Toggle", "gain", { id = "animate", label = L["Animate"], path = "gain.animate" })
	self:Add(behavior, "Dropdown", "gain", {
		id = "animation",
		label = L["Animation Style"],
		path = "gain.animation",
		options = self:Choices({
			{ value = "RISE", label = L["Rise"] },
			{ value = "SLIDE", label = L["Slide Outward"] },
		}),
		depends = "animate",
		blocked = function()
			if not Beside() and not Detached() then
				return L["Requires Right or Left of Bar, or Detach from Bar."]
			end
		end,
	})
	self:Add(behavior, "Checkbox", "gain", { id = "hideInCombat", label = L["Hide in Combat"],
		path = "gain.hideInCombat" })
	self:Add(behavior, "Checkbox", "gain", { id = "detached", label = L["Detach from Bar"], path = "gain.detached" },
		L["Place it in Edit Mode."])

	local placement = page:Section("placement", L["Placement"])

	self:Add(placement, "Dropdown", "gain", {
		id = "position",
		label = L["Position"],
		path = "gain.position",
		options = self:Choices({
			{ value = "FILL_EDGE", label = L["Fill Edge"] },
			{ value = "RIGHT_END", label = L["Right End"] },
			{ value = "OUTSIDE_RIGHT", label = L["Right of Bar"] },
			{ value = "OUTSIDE_LEFT", label = L["Left of Bar"] },
		}),
		blocked = function()
			if Detached() then
				return L["Set in Edit Mode."]
			end
		end,
	})
	self:Add(placement, "Dropdown", "gain", {
		id = "direction",
		label = L["Growth Direction"],
		options = self:Choices(function()
			return DirectionPath() == "gain.across" and LEFT_RIGHT or UP_DOWN
		end),
		get = function()
			return LB.Profile:Get(DirectionPath())
		end,
		set = function(value)
			LB.Profile:Set(DirectionPath(), value)
		end,
		blocked = function()
			if Detached() then
				return nil
			elseif not (Beside() and LB.Profile:Get("layout.mode") == "SEGMENTED") then
				return L["Requires Detach from Bar, or Right or Left of Bar in Segmented layout."]
			elseif LB.Profile:Get("gain.animation") == "SLIDE" then
				return L["Set by Slide Outward."]
			end
		end,
	})
	local amount = page:Section("amount", L["Amount Text"])

	self:Add(amount, "Dropdown", "gain", { id = "font", label = L["Font"], path = "gain.text.font", picker = "font" })
	self:Add(amount, "Slider", "gain", {
		id = "size",
		label = L["Size"],
		path = "gain.text.size",
		min = LIMITS.textSize.min,
		max = LIMITS.textSize.max,
		step = 1,
	})
	self:Add(amount, "Dropdown", "gain", { id = "outline", label = L["Outline"], path = "gain.text.outline",
		options = self:Choices(Outlines) })

	local getColor, setColor = self:ColorAccess("gain.text.color")

	self:Add(amount, "Color", "gain", { id = "color", label = COLOR, get = getColor, set = setColor })
	self:Add(amount, "Dropdown", "gain", {
		id = "side",
		label = L["Text Side"],
		path = "gain.text.side",
		options = self:Choices({
			{ value = "LEFT", label = L["Left of the Arrow"] },
			{ value = "RIGHT", label = L["Right of the Arrow"] },
		}),
	})
	self:Add(amount, "Slider", "gain", { id = "x", label = L["Horizontal Offset"], path = "gain.text.x", min = -40,
		max = 40, step = 1 })
	self:Add(amount, "Slider", "gain", { id = "y", label = L["Vertical Offset"], path = "gain.text.y", min = -40,
		max = 40, step = 1 })

	local tints = page:Section("tints", L["Arrow Tints"])

	for _, id in ipairs(LB.Model:Order()) do
		if LB.Model:Capable(id) then
			local getTint, setTint = self:ColorAccess("gain.colors." .. id)

			self:Add(tints, "Color", "gain", { id = "tint." .. id, label = LB.Model:Label(id), get = getTint,
				set = setTint })
		end
	end
end
