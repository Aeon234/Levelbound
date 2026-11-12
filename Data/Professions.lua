local LB = select(2, ...)

local LABEL = PROFESSIONS_TRACKER_HEADER_PROFESSION or "Profession"
local FALLBACK_COLOR = { 141 / 255, 124 / 255, 105 / 255 }
local EVENTS = { "SKILL_LINES_CHANGED", "PLAYER_ENTERING_WORLD" }

---@class LBProfessions
---@field keys table<number, string>? skill line to its Enum.Profession key, built on first use
local Professions = {}
LB.Professions = Professions

---@return boolean
local function Capable()
	return LB.can.professions == true
end

---@param skillLine number
---@return string? key the profession's Enum.Profession key
function Professions:Key(skillLine)
	if not self.keys then
		self.keys = {}

		if Enum.Profession and C_TradeSkillUI and C_TradeSkillUI.GetProfessionSkillLineID then
			for key, profession in pairs(Enum.Profession) do
				local line = C_TradeSkillUI.GetProfessionSkillLineID(profession)

				if line then
					self.keys[line] = key
				end
			end
		end
	end

	return self.keys[skillLine]
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

---@param skillLine number
---@return boolean
function Professions:IsTracked(skillLine)
	local tracked = LB.Profile.char.professions

	return tracked ~= nil and tracked[skillLine] == true
end

---@param skillLine number
---@return LBColor
function Professions:Color(skillLine)
	local key = self:Key(skillLine)

	return key and LB.Profile:Get("appearance.professionColors." .. key) or FALLBACK_COLOR
end

---@param skillLine number
---@return LBSource
function Professions:Ensure(skillLine)
	local id = "profession" .. skillLine
	local existing = LB.Model:Source(id)

	if existing then
		return existing
	end

	return LB.Source:New(id, {
		label = LABEL,
		shortLabel = LABEL,
		textKey = "profession",
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

-- Creates a source for each tracked profession and orders them as the profession book does.
function Professions:Create()
	local tracked = LB.Profile.char.professions

	if not Capable() or not tracked then
		return
	end

	---@type number[]
	local lines = {}

	for skillLine, on in pairs(tracked) do
		if on then
			self:Ensure(skillLine)
			lines[#lines + 1] = skillLine
		end
	end

	local positions = {}

	for _, skillLine in ipairs(lines) do
		positions[skillLine] = select(2, self:Find(skillLine))
	end

	table.sort(lines, function(a, b)
		if positions[a] ~= positions[b] then
			return positions[a] < positions[b]
		end

		return a < b
	end)

	local ids = {}

	for index, skillLine in ipairs(lines) do
		ids[index] = "profession" .. skillLine
	end

	LB.Model:SetExtra(ids)
end
