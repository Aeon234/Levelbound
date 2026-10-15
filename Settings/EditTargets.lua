local LB = select(2, ...)

local lib = LibStub("LibAeonSettings-1.0")

local ADDON_NAME = ...

-- Each owner describes what edit mode moves and where it is saved: `:EditTargets()` entries with `read`, `write`,
-- `place`, `default` and the mover's options.
local OWNERS = { LB.BarGroup, LB.LevelUpNotice, LB.Gain, LB.PartyBars }

---Levelbound's frames in LibAeonSettings' edit mode: the owners' targets, positions read and written through them,
---and the sample bars shown while a session is open.
---@class LBEditTargets
---@field registration table?
---@field entries table<string, LBEditTarget> the owners' entries by key, as last read
local EditTargets = {
	entries = {},
}
LB.EditTargets = EditTargets

---@param shown boolean
local function Sample(shown)
	LB.Editing:Set({ editMode = shown })
end

---@return table[] targets in the library's form
function EditTargets:Targets()
	if LB.failed then
		return {}
	end

	-- Edit mode reads the targets as it opens: the sample bars are shown first, and the targets are read again
	-- once the bars have settled.
	if lib:IsEditing() then
		Sample(true)
		LB.Settings:Window()
	end

	local targets = {}

	wipe(self.entries)

	for _, owner in ipairs(OWNERS) do
		for _, entry in ipairs(owner:EditTargets()) do
			local typeId = entry.typeId

			self.entries[entry.key] = entry
			targets[#targets + 1] = {
				key = entry.key,
				label = entry.label or LB.Model:Label(typeId or entry.key),
				frame = entry.frame,
				default = entry.default,
				fixedEdge = entry.fixedEdge,
				pinned = entry.pinned,
				outline = entry.outline,
				settings = entry.settings,
				place = entry.place,
				sample = Sample,
			}
		end
	end

	return targets
end

function EditTargets:Register()
	self.registration = lib:Placement(ADDON_NAME, {
		title = LB.title,
		account = function()
			return LB.Profile:Global()
		end,
		targets = function()
			return EditTargets:Targets()
		end,
		get = function(key)
			local entry = EditTargets.entries[key]

			return entry and entry.read()
		end,
		set = function(key, position)
			local entry = EditTargets.entries[key]

			if entry then
				entry.write(position)
			end
		end,
	})
end

---Places every target at its position again, as after a profile change.
function EditTargets:Apply()
	if self.registration then
		self.registration:Apply()
	end
end

---@return boolean
function EditTargets:IsActive()
	return lib:IsEditing()
end

function EditTargets:Toggle()
	if lib:IsEditing() then
		lib:RequestClose(false)

		return
	end

	lib:OpenEditMode(ADDON_NAME)
end

-- While a session is open, a relayout can add or remove frames (sample bars arriving, a group settling): read the
-- targets again and redraw the movers, once per frame.
local function Refresh()
	if not lib:IsEditing() or not EditTargets.registration then
		return
	end

	LB.Events:Coalesce("editTargets", function()
		if lib:IsEditing() then
			EditTargets.registration:RefreshTargets()
			lib:RefreshMovers()
		end
	end)
end

LB.Callbacks:Register("Layout", EditTargets, Refresh)
LB.Callbacks:Register("Editing", EditTargets, Refresh)
LB.Callbacks:Register("Party", EditTargets, Refresh)

EditTargets:Register()
