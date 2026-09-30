local LB = select(2, ...)

local SAMPLE_MAX = 10000
local SAMPLE_CUR = 6200
local SAMPLE_QUEST = 1600
local SAMPLE_RESTED = 1400

local Editing = LB.Editing

---@class LBPreview
---@field previewAll boolean
---@field xpSample boolean
---@field snapshots table<string, LBSnapshot>
local Preview = {
	previewAll = false,
	xpSample = false,
	snapshots = {},
}
LB.Preview = Preview

local FRIENDLY = 5
local FRIENDLY_FALLBACK = { 0, 0.6, 0.1, 1 }

---@return LBColor the Friendly standing's color, which a sample reputation bar shows
local function ReputationColor()
	local color = FACTION_BAR_COLORS and FACTION_BAR_COLORS[FRIENDLY]

	return color and { color.r, color.g, color.b, 1 } or FRIENDLY_FALLBACK
end

---@param id string
---@return LBSnapshot
local function Sample(id)
	return {
		color = id == "reputation" and ReputationColor() or nil,
		cur = SAMPLE_CUR,
		max = SAMPLE_MAX,
		overlays = {
			quest = id == "xp" and SAMPLE_QUEST or 0,
			rested = id == "xp" and SAMPLE_RESTED or 0,
		},
		level = 42,
		atCap = false,
		flags = {},
	}
end

---@return string[] ids every enabled type, in the fixed display order
function Preview:Ids()
	local ids = {}

	for _, id in ipairs(LB.Model:Order()) do
		local source = LB.Model:Source(id)

		if source and source:IsEnabled() then
			ids[#ids + 1] = id
		end
	end

	return ids
end

---@param id string
---@return LBSnapshot
function Preview:Snapshot(id)
	local snapshot = self.snapshots[id]

	if not snapshot then
		snapshot = Sample(id)
		self.snapshots[id] = snapshot
	end

	return snapshot
end

---@param id string
---@return boolean
function Preview:Covers(id)
	return Editing:PreviewAll() or (Editing:XPSample() and id == "xp")
end

LB.Callbacks:Register("Editing", Preview, function()
	local previewAll, xpSample = Editing:PreviewAll(), Editing:XPSample()

	if previewAll == Preview.previewAll and xpSample == Preview.xpSample then
		return
	end

	Preview.previewAll = previewAll
	Preview.xpSample = xpSample

	LB.Callbacks:Fire("Layout")
end)
