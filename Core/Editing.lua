local LB = select(2, ...)

---@alias LBEditingDemo "text" | "gain" | "party"

---@class LBEditingInputs
---@field settings boolean
---@field demo LBEditingDemo|false
---@field editMode boolean
---@field previewAll boolean
---@field previewAllFromSettings boolean
---@field independent boolean
---@field empty boolean

---@class LBEditingOutputs
---@field editing boolean
---@field demo LBEditingDemo|false
---@field xpSample boolean
---@field previewAll boolean

---@class LBEditingChanges
---@field settings boolean?
---@field demo (LBEditingDemo|false)?
---@field editMode boolean?
---@field previewAll boolean?

---@class LBEditing
---@field inputs LBEditingInputs
---@field outputs LBEditingOutputs
local Editing = {
	inputs = {
		settings = false,
		demo = false,
		editMode = false,
		previewAll = false,
		previewAllFromSettings = false,
		independent = false,
		empty = false,
	},
	outputs = {
		editing = false,
		demo = false,
		xpSample = false,
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
		xpSample = inputs.settings,
		previewAll = inputs.previewAll or (inputs.editMode and (inputs.independent or inputs.empty)),
	}
end

---@return boolean editing the settings window or edit mode is open, so fading holds
function Editing:IsEditing()
	return self.outputs.editing
end

---@return LBEditingDemo? demo the feature the open settings page shows samples of
function Editing:Demo()
	return self.outputs.demo or nil
end

---@return boolean xpSample the XP bar shows its sample, so the settings can recolour its overlays
function Editing:XPSample()
	return self.outputs.xpSample
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
	local inputs = self.inputs

	for key, value in pairs(changes) do
		inputs[key] = value
	end

	if changes.previewAll then
		inputs.previewAllFromSettings = inputs.settings
	end

	if inputs.previewAllFromSettings and not inputs.settings and not inputs.editMode then
		inputs.previewAll = false
	end

	Update(self)
end

LB.Callbacks:Register("Settings", Editing, function()
	Update(Editing)
end)

LB.Callbacks:Register("Layout", Editing, function()
	Update(Editing)
end)
