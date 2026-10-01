local LB = select(2, ...)

local L = LB.L

---@return number? maxLevel nil when the faction has no level cap that matters
local function MaxLevel(factionID)
	if C_Reputation.IsFactionParagonForCurrentPlayer(factionID) then
		return nil
	end

	if C_Reputation.IsMajorFaction(factionID) then
		local levels = C_MajorFactions.GetRenownLevels(factionID)

		return levels and #levels > 0 and levels[#levels].level or nil
	end

	local info = C_GossipInfo.GetFriendshipReputation(factionID)

	if info and info.friendshipFactionID > 0 then
		local ranks = C_GossipInfo.GetFriendshipReputationRanks(factionID)

		return ranks and ranks.maxLevel or nil
	end

	return MAX_REPUTATION_REACTION
end

-- Blizzard draws renown with a blue bar atlas and defines no matching color constant.
local RENOWN_COLOR = { 0, 191 / 255, 243 / 255, 1 }

---@param reaction number
---@param renown boolean
---@return LBColor
local function StandingColor(reaction, renown)
	local override = LB.Profile:Get("appearance.standingColors")[renown and "renown" or tostring(reaction)]

	if override then
		return override
	end

	if renown then
		return RENOWN_COLOR
	end

	local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[reaction]

	if not color then
		return { 0.5, 0.5, 0.5, 1 }
	end

	return { color.r, color.g, color.b, 1 }
end

---@param factionID number
---@param reaction number
---@return string
local function StandingText(factionID, reaction)
	local info = C_GossipInfo.GetFriendshipReputation(factionID)

	if info and info.friendshipFactionID > 0 and info.reaction then
		return info.reaction
	end

	if C_Reputation.IsMajorFaction(factionID) then
		local data = C_MajorFactions.GetMajorFactionData(factionID)

		if data then
			return RENOWN_LEVEL_LABEL and RENOWN_LEVEL_LABEL:format(data.renownLevel) or tostring(data.renownLevel)
		end
	end

	return _G["FACTION_STANDING_LABEL" .. reaction] or ""
end

LB.Source:New("reputation", {
	label = REPUTATION,
	shortLabel = L["Rep"],
	Capability = function()
		return C_Reputation ~= nil and C_Reputation.GetWatchedFactionData ~= nil
	end,

	IsAvailable = function()
		local data = C_Reputation.GetWatchedFactionData()

		return data ~= nil and data.factionID ~= 0 and data.name ~= ""
	end,

	Events = function()
		return { "UPDATE_FACTION", "PLAYER_ENTERING_WORLD" }
	end,

	---@param self LBSource
	---@param snapshot LBSnapshot
	Read = function(self, snapshot)
		local data = C_Reputation.GetWatchedFactionData()

		if not data or data.factionID == 0 then
			local emptied = snapshot.max ~= 0

			snapshot.cur, snapshot.max = 0, 0
			snapshot.level, snapshot.label, snapshot.standing, snapshot.color = nil, nil, nil, nil
			snapshot.atCap = false
			snapshot.flags.paragonPending = false
			snapshot.flags.major = false

			self.factionID = nil

			return emptied
		end

		local factionID = data.factionID
		local maxLevel = MaxLevel(factionID)
		local reaction = data.reaction
		local minimum, maximum, value = data.currentReactionThreshold, data.nextReactionThreshold, data.currentStanding
		local level = reaction
		local paragonPending = false

		if C_Reputation.IsFactionParagonForCurrentPlayer(factionID) then
			local currentValue, threshold, _, hasRewardPending = C_Reputation.GetFactionParagonInfo(factionID)

			if currentValue and threshold and threshold > 0 then
				minimum, maximum = 0, threshold
				value = currentValue % threshold

				if hasRewardPending then
					value = value + threshold
					paragonPending = true
				end
			end

			level = maxLevel
		elseif C_Reputation.IsMajorFaction(factionID) then
			local major = C_MajorFactions.GetMajorFactionData(factionID)

			if major then
				minimum, maximum = 0, major.renownLevelThreshold
				level = major.renownLevel
			end
		else
			local info = C_GossipInfo.GetFriendshipReputation(factionID)

			if info and info.friendshipFactionID > 0 then
				local ranks = C_GossipInfo.GetFriendshipReputationRanks(factionID)

				level = ranks and ranks.currentLevel or level

				if info.nextThreshold then
					minimum, maximum, value = info.reactionThreshold, info.nextThreshold, info.standing
				else
					minimum, maximum, value = 0, 1, 1
				end

				reaction = 5
			end
		end

		local capped = (level and maxLevel) and level >= maxLevel or false

		maximum = maximum - minimum
		value = value - minimum

		if capped and maximum == 0 then
			maximum, value = 1, 1
		end

		local name = data.name
		local major = C_Reputation.IsMajorFaction(factionID)
		local nothingToShow = capped and not paragonPending and maximum <= 1

		local changed = snapshot.cur ~= value
			or snapshot.max ~= maximum
			or snapshot.label ~= name
			or snapshot.level ~= level
			or snapshot.flags.paragonPending ~= paragonPending

		snapshot.cur = value
		snapshot.max = nothingToShow and 0 or maximum
		snapshot.level = level
		snapshot.label = name
		snapshot.standing = StandingText(factionID, reaction)
		snapshot.color = StandingColor(reaction, major)
		snapshot.atCap = capped
		snapshot.flags.paragonPending = paragonPending
		snapshot.flags.major = major

		self.factionID = factionID

		return changed
	end,

	---@param self LBSource
	---@param tip GameTooltip
	Tooltip = function(self, tip)
		local factionID = self.factionID

		if not factionID then
			return
		end

		if self.snapshot.flags.paragonPending then
			tip:AddLine(L["A paragon reward is waiting."], 0, 1, 0)
		end

		if self.snapshot.flags.major and LB.can.renownRewards then
			local data = C_MajorFactions.GetMajorFactionData(factionID)

			if data and not C_MajorFactions.HasMaximumRenown(factionID) then
				local rewards = C_MajorFactions.GetRenownRewardsForLevel(factionID, data.renownLevel + 1)

				if rewards and #rewards > 0 then
					RenownRewardUtil.AddRenownRewardsToTooltip(tip, rewards, nop)
				end
			end
		end
	end,

	---@param self LBSource
	---@return string?
	ClickHint = function(self)
		if self.factionID and self.snapshot.flags.major and LB.can.encounterJournal then
			return L["Click to Open Journeys."]
		end

		return LB.can.characterPanel and L["Click to Open the Reputation Panel"] or nil
	end,

	---@param self LBSource
	Click = function(self)
		local factionID = self.factionID

		if factionID and self.snapshot.flags.major and LB.can.encounterJournal then
			ToggleEncounterJournal()

			return
		end

		if LB.can.characterPanel then
			ToggleCharacter("ReputationFrame")
		end
	end,
})
