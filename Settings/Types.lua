local LB = select(2, ...)

local L = LB.L
local LIMITS = LB.LIMITS
local Settings = LB.Settings

local KEY = "type"

---@return boolean
local function Independent()
	return LB.Layout.Independent(LB.Profile:Get("layout")) and true or false
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
				icon = LB.Media.sidebar[id],
				iconTint = true,
				under = "types",
				switch = {
					path = "types." .. id,
					default = self:Default("types." .. id),
					label = L["Show %s Bar"]:format(label),
				},
			})

			LB.SettingsPreviews:Declare(page, "type." .. id)
			self:DeclareTypeBar(page, id)
			LB.SettingsText:Declare(page, id)
		end
	end

	if LB.can.professions then
		self:DeclareProfessions(window)
	end
end

---@param window table
function Settings:DeclareProfessions(window)
	local Professions = LB.Professions
	local page = window:Page("type.profession", { title = TRADE_SKILLS or "Professions", under = "types" })
	local bars = page:Section("bars", L["Bars"], {
		columns = 2,
		show = function()
			return #Professions:Indices() > 0
		end,
	})

	for _, line in ipairs(Professions:All()) do
		local path = Professions:ColorPath(line)

		local function Learned()
			return Professions:Find(line) ~= nil
		end

		self:Add(bars, "Checkbox", KEY, {
			id = "track" .. line,
			label = Professions:Name(line),
			tooltip = L["This character only."],
			default = false,
			show = Learned,
			get = function()
				return Professions:IsTracked(line)
			end,
			set = function(value)
				Professions:SetTracked(line, value == true)
			end,
		})

		if path then
			local get, set = self:ColorAccess(path)

			self:Add(bars, "Color", KEY, { id = "color" .. line, label = L["Bar Color"], default = self:Default(path),
				show = Learned, get = get, set = set })
		end
	end

	LB.SettingsPreviews:Declare(page, "type.profession")
	self:DeclareTypeSize(page, "profession")
	LB.SettingsText:Declare(page, "profession")

	-- While the window is open, learning or unlearning a profession redraws the page.
	local lib = LibStub("LibAeonSettings-1.0")

	lib.RegisterCallback(Professions, "OnOpen", function(_, addonName)
		if addonName == LB.name then
			LB.Events:Register("SKILL_LINES_CHANGED", Professions, function()
				self:Refresh()
			end)
		end
	end)
	lib.RegisterCallback(Professions, "OnClose", function(_, addonName)
		if addonName == LB.name then
			LB.Events:Unregister("SKILL_LINES_CHANGED", Professions)
		end
	end)
end

---@param page table
---@param id string
function Settings:DeclareTypeBar(page, id)
	if id == "xp" then
		self:DeclareExperienceColors(page:Section("colors", L["Colors"]))
	elseif id ~= "reputation" then
		local colors = page:Section("colors", L["Colors"])
		local get, set = self:ColorAccess("appearance.typeColors." .. id)

		self:Add(colors, "Color", KEY, { id = "color", label = L["Bar Color"], get = get, set = set })
	end

	self:DeclareTypeSize(page, id)
end

---@param page table
---@param id string the type id, or the settings key its bars share
function Settings:DeclareTypeSize(page, id)
	local size = page:Section("size", L["Size"], { show = Independent })

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
			return L["Set by Use Class Color."]
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

	self:Add(section, "Checkbox", KEY, { id = "classColor", label = L["Use Class Color"],
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
			return field == "height" and HeightFixed() or nil
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
