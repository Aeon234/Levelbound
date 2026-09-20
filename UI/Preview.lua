local LB = select(2, ...)

local SAMPLE_MAX = 10000
local SAMPLE_CUR = 6200
local SAMPLE_QUEST = 1600
local SAMPLE_RESTED = 1400

---@class LBPreview
---@field active boolean
---@field snapshots table<string, LBSnapshot>
local Preview = {
	active = false,
	snapshots = {},
}
LB.Preview = Preview

---@param id string
---@return LBSnapshot
local function Sample(id)
	return {
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

---@return boolean
function Preview:IsActive()
	return self.active
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

function Preview:Enter()
	if self.active then
		return
	end

	self.active = true

	LB.Callbacks:Fire("Layout")
end

function Preview:Exit()
	if not self.active then
		return
	end

	self.active = false

	LB.Callbacks:Fire("Layout")
end
