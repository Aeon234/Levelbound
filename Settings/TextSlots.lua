local LB = select(2, ...)

local L = LB.L
local AS = LB.AeonSettings

local NUDGE_LIMIT = 50
local SIZE_MIN, SIZE_MAX = 6, 32
local DEFAULT_SLOT = "INSIDE_LEFT"
local COPY_WIDTH = 170

local GROUP_LABELS = {
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

---The slots a progress type's editor offers: all nine for experience, the three inside the bar for the others.
---@param typeId string
---@return string[]
function Text:Keys(typeId)
	return typeId == "xp" and LB.TextSlotKeys or INSIDE_KEYS
end

---@param typeId string
---@return string
function Text:Chosen(typeId)
	local chosen = self.chosen[typeId]

	for _, key in ipairs(self:Keys(typeId)) do
		if key == chosen then
			return chosen
		end
	end

	return DEFAULT_SLOT
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
---@param key string
---@return LBTextStyle
local function Effective(typeId, key)
	return LB.Profile:ResolveStyle(Slot(typeId, key) or {})
end

---@param typeId string
---@return table[] choices one per slot, each naming its text
local function SlotChoices(typeId)
	local choices = {}

	for index, key in ipairs(Text:Keys(typeId)) do
		local slot = Slot(typeId, key)
		local text = slot and slot.text ~= "" and slot.text or L["(empty)"]

		choices[index] = { value = key, text = ("%s: %s"):format(L["slot." .. key], text) }
	end

	return choices
end

---What a tag shows for the settings' sample bar of a type, or nil when it renders nothing.
---@param typeId string
---@param tag string
---@return string?
local function Example(typeId, tag)
	local ok, text = pcall(LB.Tags.Render, LB.Tags, LB.Tags:Compile("[" .. tag .. "]"), LB.Preview:Snapshot(typeId),
		LB.Model:Source(typeId))

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

---Returns the byte offset after the first `characters` UTF-8 characters of `text`, clamped to its length.
---@param text string
---@param characters integer
---@return integer
local function ByteOffset(text, characters)
	local count = 0

	for index = 1, #text do
		local byte = text:byte(index)

		-- A byte that does not continue a multi-byte sequence starts a new character.
		if byte < 0x80 or byte >= 0xC0 then
			if count == characters then
				return index - 1
			end

			count = count + 1
		end
	end

	return #text
end

---Inserts a tag where the text box's cursor last was, counted in characters, or at the end.
---@param text string
---@param tag string
---@param cursor integer?
---@return string
function Text.InsertTag(text, tag, cursor)
	local position = cursor and ByteOffset(text, math.max(cursor, 0)) or #text

	return text:sub(1, position) .. "[" .. tag .. "]" .. text:sub(position + 1)
end

---@param ctx LBPageContext
---@param typeId string
---@return table[] elements
function Text:Elements(ctx, typeId)
	local Pages = LB.SettingsPages
	local Section, Row, Merge = Pages.Section, Pages.Row, Pages.Merge
	local key = self:Chosen(typeId)
	local textID = ("slotText.%s.%s"):format(typeId, key)

	ctx.paths[#ctx.paths + 1] = "text.slots." .. typeId

	local function Style(id, control, label, field, fields)
		return Merge({
			id = id,
			control = control,
			label = label,
			rebuild = true,
			description = Overridden(typeId, key, field) and L["Custom for this slot."] or nil,
			get = function()
				return Effective(typeId, key)[field]
			end,
			set = function(value)
				SetOverride(typeId, key, field, value)
			end,
		}, fields)
	end

	local useStyle = {
		id = "useTextStyle",
		control = "action",
		label = L["Use Text Style"],
		verb = L["Use Text Style"],
		blocked = function()
			local slot = Slot(typeId, key)

			if not slot or type(slot.style) ~= "table" or next(slot.style) == nil then
				return L["This slot uses the text style."]
			end
		end,
		set = function()
			EnsureSlot(typeId, key)
			LB.Profile:Set(Path(typeId, key) .. ".style", {})

			return true
		end,
	}

	local copyChoices = CopyChoices(typeId)

	local copyMenu = {
		id = "copyFrom",
		control = "dropdown",
		label = L["Copy Settings From"],
		placeholder = L["Copy Settings From"],
		verb = L["Copy"],
		width = COPY_WIDTH,
		rebuild = true,
		options = copyChoices,
		blocked = function()
			if #copyChoices == 0 then
				return L["No other bar to copy from."]
			end
		end,
		confirm = function(from)
			return L["Replace this bar's text with %s's?"]:format(LB.Model:Label(from))
		end,
		get = function()
			return nil
		end,
		set = function(from)
			LB.Profile:CopySlots(from, typeId)
		end,
	}

	return {
		Section("text", L["Text"], { tab = "text", action = useStyle, menu = copyMenu }),
		Row({
			id = "slot",
			control = "dropdown",
			label = L["Slot"],
			rebuild = true,
			searchText = SearchText(typeId),
			options = function()
				return SlotChoices(typeId)
			end,
			get = function()
				return self:Chosen(typeId)
			end,
			set = function(value)
				self:Choose(typeId, value)
			end,
		}),
		Row({
			id = textID,
			control = "text",
			label = L["Text"],
			allowEmpty = true,
			rebuild = true,
			get = function()
				local slot = Slot(typeId, key)

				return slot and slot.text or ""
			end,
			set = function(value)
				SetField(typeId, key, "text", value)
			end,
		}, {
			id = "insertTag",
			control = "dropdown",
			label = L["Insert Tag"],
			placeholder = L["Insert Tag"],
			rebuild = true,
			options = function()
				return TagChoices(typeId)
			end,
			get = function()
				return nil
			end,
			set = function(tag)
				local slot = Slot(typeId, key)
				local text = slot and slot.text or ""

				local cursor = AS:TextCursor(textID)

				SetField(typeId, key, "text", Text.InsertTag(text, tag, cursor))

				-- The next tag goes after this one.
				if cursor then
					AS:SetTextCursor(textID, cursor + strlenutf8(tag) + 2)
				end
			end,
		}),
		Row({
			id = "visibility",
			control = "dropdown",
			label = L["Visibility"],
			options = {
				{ value = "HIDDEN", text = L["Hidden"] },
				{ value = "HOVER", text = L["On Hover"] },
				{ value = "ALWAYS", text = ALWAYS },
			},
			get = function()
				local slot = Slot(typeId, key)

				return slot and slot.visibility or "ALWAYS"
			end,
			set = function(value)
				SetField(typeId, key, "visibility", value)
			end,
		}),
		Row({
			id = "nudgeX",
			control = "slider",
			label = L["Nudge X"],
			min = -NUDGE_LIMIT,
			max = NUDGE_LIMIT,
			step = 1,
			get = function()
				local slot = Slot(typeId, key)

				return slot and slot.x or 0
			end,
			set = function(value)
				SetField(typeId, key, "x", value)
			end,
		}, {
			id = "nudgeY",
			control = "slider",
			label = L["Nudge Y"],
			min = -NUDGE_LIMIT,
			max = NUDGE_LIMIT,
			step = 1,
			get = function()
				local slot = Slot(typeId, key)

				return slot and slot.y or 0
			end,
			set = function(value)
				SetField(typeId, key, "y", value)
			end,
		}),
		Row(
			Style("slotFont", "dropdown", L["Font"], "font", { picker = "font", options = {} }),
			Style("slotSize", "slider", L["Size"], "size", { min = SIZE_MIN, max = SIZE_MAX, step = 1 })
		),
		Row(
			Style("slotOutline", "dropdown", L["Outline"], "outline", {
				options = function()
					local choices = {}

					for index, option in ipairs(Pages.Outlines()) do
						choices[index] = { value = option.value, text = option.label }
					end

					return choices
				end,
			}),
			Style("slotColor", "color", COLOR, "color", {
				get = function()
					return Pages.Named(Effective(typeId, key).color)
				end,
				set = function(value)
					SetOverride(typeId, key, "color", { value.r, value.g, value.b })
				end,
			})
		),
	}
end
