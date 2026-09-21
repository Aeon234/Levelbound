local LB = select(2, ...)

---@return LBColor
local function ArtifactColor()
	local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[Enum.ItemQuality.Artifact]

	if not color then
		return { 0.9, 0.8, 0.5, 1 }
	end

	return { color.r, color.g, color.b, 1 }
end

LB.Source:New("azerite", {
	Capability = function()
		return LB.can.azerite == true
	end,

	IsAvailable = function()
		if not LB.can.azerite then
			return false
		end

		local location = C_AzeriteItem.FindActiveAzeriteItem()

		if not location or C_AzeriteItem.IsAzeriteItemAtMaxLevel() then
			return false
		end

		return location:IsEquipmentSlot() and C_AzeriteItem.IsAzeriteItemEnabled(location)
	end,

	Events = function()
		return {
			"AZERITE_ITEM_EXPERIENCE_CHANGED",
			"AZERITE_ITEM_ENABLED_STATE_CHANGED",
			"PLAYER_EQUIPMENT_CHANGED",
			"PLAYER_ENTERING_WORLD",
		}
	end,

	---@param snapshot LBSnapshot
	Read = function(_, snapshot)
		local location = C_AzeriteItem.FindActiveAzeriteItem()

		if not location then
			return false
		end

		local cur, max = C_AzeriteItem.GetAzeriteItemXPInfo(location)

		cur = LB:Readable(cur, nil)
		max = LB:Readable(max, nil)

		if not cur or not max then
			return false
		end

		local level = LB:Readable(C_AzeriteItem.GetPowerLevel(location), nil)
		local changed = snapshot.cur ~= cur or snapshot.max ~= max or snapshot.level ~= level

		snapshot.cur = cur
		snapshot.max = max
		snapshot.level = level
		snapshot.label = ARTIFACT_POWER
		snapshot.color = ArtifactColor()

		return changed
	end,
})
