local LB = select(2, ...)

---@class LBEditingInputs
---@field editMode boolean
---@field independent boolean
---@field empty boolean

---@class LBEditingOutputs
---@field editing boolean
---@field previewAll boolean

---@class LBEditingChanges
---@field editMode boolean?

---Whether edit mode is open, and whether it shows every enabled type as a sample bar: in Independent layout,
---where each bar is placed on its own, and when there is no bar to show.
---@class LBEditing
---@field inputs LBEditingInputs
---@field outputs LBEditingOutputs
local Editing = {
	inputs = {
		editMode = false,
		independent = false,
		empty = false,
	},
	outputs = {
		editing = false,
		previewAll = false,
	},
}
LB.Editing = Editing

---@param inputs LBEditingInputs
---@return LBEditingOutputs
function Editing.Resolve(inputs)
	return {
		editing = inputs.editMode,
		previewAll = inputs.editMode and (inputs.independent or inputs.empty),
	}
end

---@return boolean editing edit mode is open, so fading holds
function Editing:IsEditing()
	return self.outputs.editing
end

---@return boolean previewAll every enabled type shows a sample bar
function Editing:PreviewAll()
	return self.outputs.previewAll
end

---@param self LBEditing
local function Update(self)
	local inputs = self.inputs

	inputs.independent = LB.Layout.Independent(LB.Profile:Get("layout"))
	inputs.empty = #LB.Model:VisibleOrder() == 0

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

LB.Callbacks:Register("Layout", Editing, function()
	Update(Editing)
end)
