local LB = select(2, ...)

local LABEL = PROFESSIONS_TRACKER_HEADER_PROFESSION or "Profession"
local FALLBACK_COLOR = { 141 / 255, 124 / 255, 105 / 255 }
local EVENTS = { "SKILL_LINES_CHANGED", "PLAYER_ENTERING_WORLD" }

---@class LBProfessions
---@field keys table<number, string>? skill line to its Enum.Profession key, built on first use
---@field lines number[]? every Enum.Profession skill line, built on first use
local Professions = {}
LB.Professions = Professions

---@return boolean
local function Capable()
	return LB.can.professions == true
end

---@param skillLine number
---@return string id the bar's type id
local function Id(skillLine)
	return "profession" .. skillLine
end

function Professions:Build()
	if self.keys then
		return
	end

	self.keys, self.lines = {}, {}

	if not (Enum.Profession and C_TradeSkillUI and C_TradeSkillUI.GetProfessionSkillLineID) then
		return
	end

	for key, profession in pairs(Enum.Profession) do
		local line = C_TradeSkillUI.GetProfessionSkillLineID(profession)

		if line and line > 0 then
			self.keys[line] = key
			self.lines[#self.lines + 1] = line
		end
	end
end

---@param skillLine number
---@return string? key the profession's Enum.Profession key
function Professions:Key(skillLine)
	self:Build()

	return self.keys and self.keys[skillLine]
end

---@return number[] lines every profession's skill line, sorted by name
function Professions:All()
	self:Build()

	local lines = {}

	for index, line in ipairs(self.lines or {}) do
		lines[index] = line
	end

	table.sort(lines, function(a, b)
		return self:Name(a) < self:Name(b)
	end)

	return lines
end

---@param skillLine number
---@return string name the profession's name, whether or not it is learned
function Professions:Name(skillLine)
	local name = C_TradeSkillUI and C_TradeSkillUI.GetTradeSkillDisplayName
		and C_TradeSkillUI.GetTradeSkillDisplayName(skillLine)

	if type(name) == "string" and name ~= "" then
		return name
	end

	return self:Key(skillLine) or LABEL
end

---@return number[] indices the learned professions' indices, in the profession book's order
function Professions:Indices()
	local prof1, prof2, firstAid, fishing, cooking = GetProfessions()
	local indices = {}

	for _, index in ipairs({ prof1 or false, prof2 or false, cooking or false, fishing or false, firstAid or false }) do
		if index then
			indices[#indices + 1] = index
		end
	end

	return indices
end

---@param skillLine number
---@return number? index the profession's index for GetProfessionInfo, nil when it is not learned
---@return number position its place in the profession book's order
function Professions:Find(skillLine)
	local indices = self:Indices()

	for position, index in ipairs(indices) do
		if select(7, GetProfessionInfo(index)) == skillLine then
			return index, position
		end
	end

	return nil, #indices + 1
end

---@return number? skillLine the profession a settings sample shows: the first tracked one learned, else the first
---learned
function Professions:Sample()
	local first

	for _, index in ipairs(self:Indices()) do
		local line = select(7, GetProfessionInfo(index))

		if line and self:IsTracked(line) then
			return line
		end

		first = first or line
	end

	return first
end

---@param skillLine number
---@return boolean
function Professions:IsTracked(skillLine)
	local tracked = LB.Profile.char.professions

	return tracked ~= nil and tracked[skillLine] == true
end

---@param skillLine number
---@param on boolean
function Professions:SetTracked(skillLine, on)
	LB.Profile.char.professions[skillLine] = on or nil

	self:Create()
	LB.Model:Sync()
end

---@param skillLine number
---@return string? path the profile path of the profession's color, nil when it has no saved color
function Professions:ColorPath(skillLine)
	local key = self:Key(skillLine)

	return key and "appearance.professionColors." .. key
end

---@param skillLine number
---@return LBColor
function Professions:Color(skillLine)
	local path = self:ColorPath(skillLine)

	return path and LB.Profile:Get(path) or FALLBACK_COLOR
end

---@param skillLine number
---@return LBSource
function Professions:Ensure(skillLine)
	local existing = LB.Model:Source(Id(skillLine))

	if existing then
		return existing
	end

	return LB.Source:New(Id(skillLine), {
		label = LABEL,
		shortLabel = LABEL,
		settingsKey = "profession",
		skillLine = skillLine,
		Capability = Capable,

		IsAvailable = function()
			return Capable() and Professions:Find(skillLine) ~= nil
		end,

		IsEnabled = function()
			return Professions:IsTracked(skillLine)
		end,

		Events = function()
			return EVENTS
		end,

		Color = function()
			return Professions:Color(skillLine)
		end,

		---@param source LBSource
		---@param snapshot LBSnapshot
		Read = function(source, snapshot)
			local index = Professions:Find(skillLine)

			if not index then
				return false
			end

			local name, _, rank, maxRank = GetProfessionInfo(index)

			rank = LB:Readable(rank, nil)
			maxRank = LB:Readable(maxRank, nil)

			if not rank or not maxRank then
				return false
			end

			local changed = snapshot.cur ~= rank or snapshot.max ~= maxRank

			snapshot.cur = rank
			snapshot.max = maxRank
			snapshot.label = name
			source.label = name or LABEL
			source.shortLabel = source.label

			return changed
		end,
	})
end

-- Creates a source for each tracked profession and orders every profession source as the profession book does;
-- untracked ones stay in the order so the model can unsubscribe them.
function Professions:Create()
	local tracked = LB.Profile.char.professions

	if not Capable() or not tracked then
		return
	end

	for skillLine, on in pairs(tracked) do
		if on then
			self:Ensure(skillLine)
		end
	end

	---@type number[]
	local lines = {}
	local positions = {}

	for id, source in pairs(LB.Model.sources) do
		local line = source.skillLine

		if line and id == Id(line) then
			lines[#lines + 1] = line
			positions[line] = select(2, self:Find(line))
		end
	end

	table.sort(lines, function(a, b)
		if positions[a] ~= positions[b] then
			return positions[a] < positions[b]
		end

		return a < b
	end)

	local ids = {}

	for index, skillLine in ipairs(lines) do
		ids[index] = Id(skillLine)
	end

	LB.Model:SetExtra(ids)
end
