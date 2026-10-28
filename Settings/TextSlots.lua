local LB = select(2, ...)

local L = LB.L

local NUDGE_LIMIT = 50
local SIZE_MIN, SIZE_MAX = LB.LIMITS.textSize.min, LB.LIMITS.textSize.max
local DEFAULT_SLOT = "INSIDE_LEFT"
local COPY_WIDTH = 170

local GROUP_LABELS = {
	CHARACTER = CHARACTER,
	PROGRESS = L["Progress"],
	BONUS = L["Rested and Quests"],
	TIME = L["Time"],
}

---The Text section of each progress type's page: one slot at a time, chosen in the Slot dropdown or by clicking
---it in the preview.
---@class LBSettingsText
---@field chosen table<string, string> slot key per progress type, for the session
local Text = {
	chosen = {},
}
LB.SettingsText = Text

local INSIDE_KEYS = { "INSIDE_LEFT", "INSIDE_CENTER", "INSIDE_RIGHT" }
local PARTY_KEYS = { "ABOVE_LEFT", "ABOVE_CENTER", "ABOVE_RIGHT", "INSIDE_LEFT", "INSIDE_CENTER", "INSIDE_RIGHT" }

---The slots a progress type's editor offers: all nine for experience, above and inside the bar for party bars,
---the three inside the bar for the others.
---@param typeId string
---@return string[]
function Text:Keys(typeId)
	if typeId == "party" then
		return PARTY_KEYS
	end

	return typeId == "xp" and LB.TextSlotKeys or INSIDE_KEYS
end

---@param typeId string
---@param key string
---@return string? reason the slot cannot be edited now, or nil
local function Unavailable(typeId, key)
	if LB.TextSlot:IsInside(key) and LB.TextSlot:InsideHidden() then
		return L["The Blizzard border leaves no room for text inside the bar."]
	end

	if typeId == "party" and not LB.TextSlot:IsInside(key) and LB.Profile:Get("party.bars.compact") then
		return L["Compact shows the text inside the bars only."]
	end
end

---The slots of a type's editor that can be edited now.
---@param typeId string
---@return string[]
function Text:Usable(typeId)
	local keys = {}

	for _, key in ipairs(self:Keys(typeId)) do
		if not Unavailable(typeId, key) then
			keys[#keys + 1] = key
		end
	end

	return keys
end

---@param typeId string
---@return string
function Text:Chosen(typeId)
	local chosen = self.chosen[typeId]
	local usable = self:Usable(typeId)

	for _, key in ipairs(usable) do
		if key == chosen then
			return chosen
		end
	end

	return usable[1] or DEFAULT_SLOT
end

---@param typeId string
---@param key string
function Text:Choose(typeId, key)
	self.chosen[typeId] = key
end

---@param typeId string
---@param key string
---@return string
local function Path(typeId, key)
	return ("text.slots.%s.%s"):format(typeId, key)
end

---@param typeId string
---@param key string
---@return LBTextSlot?
local function Slot(typeId, key)
	return LB.Profile:Get(Path(typeId, key))
end

---@param typeId string
---@param key string
---@return LBTextSlot
local function EnsureSlot(typeId, key)
	local slot = Slot(typeId, key)

	if slot then
		return slot
	end

	if not LB.Profile:Get("text.slots." .. typeId) then
		LB.Profile:Set("text.slots." .. typeId, {})
	end

	slot = { text = "", visibility = "ALWAYS", x = 0, y = 0, style = {} }
	LB.Profile:Set(Path(typeId, key), slot)

	return slot
end

---@param typeId string
---@param key string
---@param field string
---@param value any
local function SetField(typeId, key, field, value)
	EnsureSlot(typeId, key)
	LB.Profile:Set(Path(typeId, key) .. "." .. field, value)
end

---@param typeId string
---@param key string
---@param field string
---@param value any
local function SetOverride(typeId, key, field, value)
	local slot = EnsureSlot(typeId, key)

	if type(slot.style) ~= "table" then
		LB.Profile:Set(Path(typeId, key) .. ".style", {})
	end

	LB.Profile:Set(Path(typeId, key) .. ".style." .. field, value)
end

---@param typeId string
---@param key string
---@param field string
---@return boolean
local function Overridden(typeId, key, field)
	local slot = Slot(typeId, key)

	return slot ~= nil and type(slot.style) == "table" and slot.style[field] ~= nil
end

---@param typeId string
---@return table[] choices one per slot, each naming its text
local function SlotChoices(typeId)
	local choices = {}

	for index, key in ipairs(Text:Keys(typeId)) do
		local slot = Slot(typeId, key)
		local text = slot and slot.text ~= "" and slot.text or L["(empty)"]

		choices[index] = {
			value = key,
			text = ("%s: %s"):format(L["slot." .. key], text),
			blocked = Unavailable(typeId, key),
		}
	end

	return choices
end

---What a tag shows for the settings' sample bar of a type, or nil when it renders nothing.
---@param typeId string
---@param tag string
---@return string?
local function Example(typeId, tag)
	local snapshot, source = nil, nil

	if typeId == "party" then
		local member = LB.Marker:SampleParty()[1]

		snapshot, source = member.snapshot, LB.Tags.MemberSource(member)
	else
		snapshot, source = LB.Preview:Snapshot(typeId), LB.Model:Source(typeId)
	end

	local ok, text = pcall(LB.Tags.Render, LB.Tags, LB.Tags:Compile("[" .. tag .. "]"), snapshot, source)

	if ok and type(text) == "string" and text ~= "" then
		return text
	end
end

---@param typeId string
---@return table[] choices: a title per tag group, then its tags with their descriptions and examples
local function TagChoices(typeId)
	local choices = {}
	local group

	for _, info in ipairs(LB.Tags:For(typeId)) do
		if info.group ~= group then
			group = info.group
			choices[#choices + 1] = { title = true, text = GROUP_LABELS[group] or group }
		end

		local example = Example(typeId, info.tag)

		choices[#choices + 1] = {
			value = info.tag,
			text = example and ("[%s]  |cff9d9d9d%s|r"):format(info.tag, example) or "[" .. info.tag .. "]",
			tooltip = example and ("%s\n%s"):format(info.description, L["Example: %s"]:format(example))
				or info.description,
		}
	end

	return choices
end

---@param typeId string
---@return string search text: every tag name and slot name
local function SearchText(typeId)
	local words = { L["Tags"] }

	for _, info in ipairs(LB.Tags:For(typeId)) do
		words[#words + 1] = info.tag
	end

	for _, key in ipairs(Text:Keys(typeId)) do
		words[#words + 1] = L["slot." .. key]
	end

	return table.concat(words, " ")
end

---@param typeId string
---@return table[] choices: every other progress type this client has
local function CopyChoices(typeId)
	local choices = {}

	for _, id in ipairs(LB.Model:Order()) do
		if id ~= typeId and LB.Model:Capable(id) then
			choices[#choices + 1] = { value = id, text = LB.Model:Label(id) }
		end
	end

	return choices
end

---Declares the slot editor: one set of rows that edits whichever slot is chosen, in a Text
---section of `container` (a page or a tab) with Copy Text From on its title line.
---@param container table a page or a tab
---@param typeId string
---@param show (fun(): boolean)? hides the whole section while it returns false
---@return table section
function Text:Declare(container, typeId, show)
	local Settings = LB.Settings
	local KEY = typeId == "party" and "markers" or "type"

	local function Chosen()
		return self:Chosen(typeId)
	end

	-- With no slot left to edit, every row says why.
	local function Blocked()
		return Unavailable(typeId, Chosen())
	end

	local function Field(field, fallback)
		return function()
			local slot = Slot(typeId, Chosen())

			if slot and slot[field] ~= nil then
				return slot[field]
			end

			return fallback
		end
	end

	local function Setter(field)
		return function(value)
			SetField(typeId, Chosen(), field, value)
		end
	end

	-- A style row shows the slot's own value while it has one, and the text style's otherwise (◆ and ↺).
	local function Override(field)
		return function()
			if Overridden(typeId, Chosen(), field) then
				return Slot(typeId, Chosen()).style[field]
			end
		end, function(value)
			if value == nil then
				if Overridden(typeId, Chosen(), field) then
					LB.Profile:Set(Path(typeId, Chosen()) .. ".style." .. field, nil)
				end

				return
			end

			SetOverride(typeId, Chosen(), field, value)
		end
	end

	local section = container:Section("text", L["Text"], show and { show = show } or nil)
	local copyChoices = CopyChoices(typeId)

	section:Menu({
		id = "copyFrom",
		label = L["Copy Text From"],
		tooltip = Settings:Tooltip(KEY, "copyFrom"),
		placeholder = L["Copy Text From"],
		titleCase = false,
		action = true,
		verb = L["Copy"],
		width = COPY_WIDTH,
		options = copyChoices,
		blocked = function()
			if #copyChoices == 0 then
				return L["No other bar to copy from."]
			end
		end,
		confirm = function(from)
			return L["Replace this bar's text with %s's?"]:format(LB.Model:Label(from))
		end,
		set = function(from, setting)
			LB.Profile:CopySlots(from, typeId)
			setting.window:Refresh()
		end,
	})

	local textInput

	Settings:Add(section, "Dropdown", KEY, {
		id = "slot",
		label = L["Slot"],
		keywords = SearchText(typeId),
		redraws = true,
		options = function()
			return SlotChoices(typeId)
		end,
		get = Chosen,
		set = function(value)
			self:Choose(typeId, value)

			if textInput then
				textInput:SetTextCursor(nil)
			end
		end,
	})
	section:Skip()

	textInput = Settings:Add(section, "TextInput", KEY, {
		id = "slotText." .. typeId,
		label = L["Text"],
		allowEmpty = true,
		blocked = Blocked,
		get = Field("text", ""),
		set = Setter("text"),
	})
	Settings:Add(section, "Dropdown", KEY, {
		id = "insertTag",
		label = L["Insert Tag"],
		placeholder = L["Insert Tag"],
		action = true,
		blocked = Blocked,
		options = function()
			return TagChoices(typeId)
		end,
		set = function(tag)
			textInput:InsertText("[" .. tag .. "]")
		end,
	})
	Settings:Add(section, "Dropdown", KEY, {
		id = "visibility",
		label = L["Visibility"],
		blocked = Blocked,
		options = {
			{ value = "HIDDEN", text = L["Hidden"] },
			{ value = "HOVER", text = L["On Hover"] },
			{ value = "ALWAYS", text = ALWAYS },
		},
		get = Field("visibility", "ALWAYS"),
		set = Setter("visibility"),
	})
	section:Skip()
	Settings:Add(section, "Slider", KEY, {
		id = "nudgeX",
		label = L["Horizontal Offset"],
		min = -NUDGE_LIMIT,
		max = NUDGE_LIMIT,
		step = 1,
		blocked = Blocked,
		get = Field("x", 0),
		set = Setter("x"),
	})
	Settings:Add(section, "Slider", KEY, {
		id = "nudgeY",
		label = L["Vertical Offset"],
		min = -NUDGE_LIMIT,
		max = NUDGE_LIMIT,
		step = 1,
		blocked = Blocked,
		get = Field("y", 0),
		set = Setter("y"),
	})

	local getFont, setFont = Override("font")

	Settings:Add(section, "Dropdown", KEY, {
		id = "slotFont",
		label = L["Font"],
		picker = "font",
		inherits = { path = "text.style.font", from = L["Text Style"] },
		blocked = Blocked,
		get = getFont,
		set = setFont,
	})

	local getSize, setSize = Override("size")

	Settings:Add(section, "Slider", KEY, {
		id = "slotSize",
		label = L["Size"],
		min = SIZE_MIN,
		max = SIZE_MAX,
		step = 1,
		inherits = { path = "text.style.size", from = L["Text Style"] },
		blocked = Blocked,
		get = getSize,
		set = setSize,
	})

	local getOutline, setOutline = Override("outline")

	Settings:Add(section, "Dropdown", KEY, {
		id = "slotOutline",
		label = L["Outline"],
		options = Settings:Choices(LB.Media.outlines),
		inherits = { path = "text.style.outline", from = L["Text Style"] },
		blocked = Blocked,
		get = getOutline,
		set = setOutline,
	})

	local getColor, setColor = Override("color")

	Settings:Add(section, "Color", KEY, {
		id = "slotColor",
		label = COLOR,
		inherits = {
			from = L["Text Style"],
			get = function()
				local color = LB.Profile:Get("text.style.color")

				return { r = color[1], g = color[2], b = color[3] }
			end,
		},
		blocked = Blocked,
		get = function()
			local color = getColor()

			return color and { r = color[1], g = color[2], b = color[3] }
		end,
		set = function(value)
			setColor(value and { value.r, value.g, value.b })
		end,
	})

	return section
end
