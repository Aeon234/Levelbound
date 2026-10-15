local LB = select(2, ...)

local L = LB.L
local LIMITS = LB.LIMITS
local Settings = LB.Settings

local KEY = "type"

---@return string?
local function OnlyIndependent()
	if not LB.Layout.Independent(LB.Profile:Get("layout")) then
		return L["Only in Independent layout."]
	end
end

---@return string?
local function HeightFixed()
	if LB.Border:HeldHeight() then
		return L["Set by the border style."]
	end
end

---@param window table
function Settings:DeclareTypes(window)
	window:Header("types", L["Progress Types"])

	for _, id in ipairs(LB.Model:Order()) do
		if LB.Model:Capable(id) then
			local label = LB.Model:Label(id)
			local page = window:Page("type." .. id, {
				title = label,
				under = "types",
				description = L["This bar's colors, its own size and its text."],
				switch = {
					path = "types." .. id,
					default = self:Default("types." .. id),
					label = L["Show %s Bar"]:format(label),
					tooltip = self:Tooltip(KEY, "enabled"),
				},
			})

			self:DeclareTypeBar(page:Tab("bar", L["Bar"]), id)
			LB.SettingsText:Declare(page:Tab("text", L["Text"]), id)
		end
	end
end

---@param tab table
---@param id string
function Settings:DeclareTypeBar(tab, id)
	if id == "xp" then
		self:DeclareExperienceColors(tab:Section("colors", L["Colors"]))
	elseif id ~= "reputation" then
		local colors = tab:Section("colors", L["Colors"])
		local get, set = self:ColorAccess("appearance.typeColors." .. id)

		self:Add(colors, "Color", KEY, { id = "color", label = L["Bar Color"], get = get, set = set })
	end

	local size = tab:Section("size", L["Size"])

	self:BarSize(size, id, "width", L["Width"], LIMITS.barWidth.min, function()
		return math.floor(UIParent:GetWidth())
	end)
	self:BarSize(size, id, "height", L["Height"], LIMITS.barHeight.min, LIMITS.barHeight.max)
end

---@param section table
function Settings:DeclareExperienceColors(section)
	---@return string?
	local function ClassColor()
		if LB.Profile:Get("appearance.xpUseClassColor") == true then
			return L["Uses your class color."]
		end
	end

	local function Stop(index)
		return function()
			local color = LB.Profile:Get("appearance.xpGradient")[index]

			return { r = color[1], g = color[2], b = color[3] }
		end, function(value)
			local gradient = LB.Profile:Get("appearance.xpGradient")

			gradient[index] = { value.r, value.g, value.b }
			LB.Profile:Set("appearance.xpGradient", gradient)
		end
	end

	self:Add(section, "Checkbox", KEY, { id = "classColor", label = L["XP Uses Class Color"],
		path = "appearance.xpUseClassColor" })
	self:Add(section, "Checkbox", KEY, { id = "gradientFollows", label = L["Gradient Follows Fill"],
		path = "appearance.xpGradientFollows", blocked = ClassColor })

	local getStart, setStart = Stop(1)
	local getEnd, setEnd = Stop(2)

	self:Add(section, "Color", KEY, { id = "gradientStart", label = L["Gradient Start"], get = getStart,
		set = setStart, blocked = ClassColor })
	self:Add(section, "Color", KEY, { id = "gradientEnd", label = L["Gradient End"], get = getEnd, set = setEnd,
		blocked = ClassColor })

	local getQuest, setQuest = self:ColorAccess("appearance.questColor")
	local getRested, setRested = self:ColorAccess("appearance.restedColor", true)

	self:Add(section, "Color", KEY, { id = "quest", label = L["Completed-Quest Color"], get = getQuest,
		set = setQuest })
	self:Add(section, "Color", KEY, { id = "rested", label = L["Rested Color"], hasOpacity = true, get = getRested,
		set = setRested })
end

---A bar's own width or height in Independent layout: the shared size until set (◆), and again after ↺.
---@param section table
---@param id string
---@param field "width" | "height"
---@param label string
---@param minimum number
---@param maximum number | fun(): number
function Settings:BarSize(section, id, field, label, minimum, maximum)
	self:Add(section, "Slider", KEY, {
		id = "bar" .. field,
		label = label,
		min = minimum,
		max = maximum,
		step = 1,
		inherits = { path = "layout." .. field, from = L["Layout"] },
		blocked = function()
			return OnlyIndependent() or (field == "height" and HeightFixed() or nil)
		end,
		get = function()
			local entry = LB.Profile:Get("layout.independent")[id]

			return entry and entry[field]
		end,
		set = function(value)
			local independent = LB.Profile:Get("layout.independent")
			local entry = independent[id]

			if value == nil and not (entry and entry[field] ~= nil) then
				return
			end

			entry = entry or {}
			entry[field] = value
			independent[id] = entry
			LB.Profile:Set("layout.independent", independent)
		end,
	})
end
