local LB = select(2, ...)

---@alias LBEditingDemo "text" | "gain" | "party"

---@class LBEditingInputs
---@field settings boolean
---@field demo LBEditingDemo|false
---@field editMode boolean
---@field movers boolean
---@field previewAll boolean
---@field independent boolean

---@class LBEditingOutputs
---@field editing boolean
---@field demo LBEditingDemo|false
---@field movers boolean
---@field previewAll boolean

---@class LBEditingChanges
---@field settings boolean?
---@field demo (LBEditingDemo|false)?
---@field editMode boolean?
---@field movers boolean?
---@field previewAll boolean?

---@class LBEditing
---@field inputs LBEditingInputs
---@field outputs LBEditingOutputs
local Editing = {
	inputs = {
		settings = false,
		demo = false,
		editMode = false,
		movers = false,
		previewAll = false,
		independent = false,
	},
	outputs = {
		editing = false,
		demo = false,
		movers = false,
		previewAll = false,
	},
}
LB.Editing = Editing

---@param inputs LBEditingInputs
---@return LBEditingOutputs
function Editing.Resolve(inputs)
	return {
		editing = inputs.settings or inputs.editMode,
		demo = inputs.settings and inputs.demo,
		movers = inputs.movers,
		previewAll = inputs.previewAll or (inputs.editMode and inputs.independent),
	}
end

---@return boolean editing the settings window or edit mode is open, so the XP bar shows its sample and fading holds
function Editing:IsEditing()
	return self.outputs.editing
end

---@return LBEditingDemo? demo the feature the open settings page shows samples of
function Editing:Demo()
	return self.outputs.demo or nil
end

---@return boolean showing edit mode's movers are on screen
function Editing:MoversShowing()
	return self.outputs.movers
end

---@return boolean previewAll every enabled type shows a sample bar
function Editing:PreviewAll()
	return self.outputs.previewAll
end

---@param self LBEditing
local function Update(self)
	local inputs = self.inputs

	inputs.independent = LB.Profile:Get("layout.mode") == "INDEPENDENT"

	local outputs = Editing.Resolve(inputs)
	local changed = false

	for key, value in pairs(outputs) do
		if self.outputs[key] ~= value then
			changed = true
		end
	end

	if not changed then
		return
	end

	self.outputs = outputs

	LB.Callbacks:Fire("Editing")
end

---@param changes LBEditingChanges
function Editing:Set(changes)
	for key, value in pairs(changes) do
		self.inputs[key] = value
	end

	Update(self)
end

LB.Callbacks:Register("Settings", Editing, function()
	Update(Editing)
end)
