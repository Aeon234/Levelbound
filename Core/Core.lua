---@type string
local addonName = ...

---@class LB
---@field name string
---@field title string
---@field version string
---@field L LBLocale
---@field can LBCapabilityFlags
---@field Capabilities LBCapabilities
---@field Callbacks LBCallbacks
---@field Events LBEvents
---@field Profile LBProfile
---@field Media LBMedia
---@field Settings table?
local LB = select(2, ...)

LB.name = addonName
LB.title = C_AddOns.GetAddOnMetadata(addonName, "Title") or addonName
LB.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or UNKNOWN

LB.MESSAGE_PREFIX = "Levelbound"

LB.DEFAULT_FONT = "Gilroy Bold"

local PREFIX = "|cff7a63ffLevelbound|r: "
local WARN_PREFIX = "|cff7a63ffLevelbound|r |cffff7f3fWarning|r: "

---@param message string
---@param ... any
function LB:Print(message, ...)
	if select("#", ...) > 0 then
		message = message:format(...)
	end

	print(PREFIX .. message)
end

---@param message string
---@param ... any
function LB:Warn(message, ...)
	if select("#", ...) > 0 then
		message = message:format(...)
	end

	print(WARN_PREFIX .. message)
end

---Is Secret Value checker.
---@generic T
---@param value T
---@param fallback T?
---@return T? value the value itself when it can be read, otherwise the fallback
function LB:Readable(value, fallback)
	if issecretvalue(value) then
		return fallback
	end

	return value
end

---@generic T
---@param source T
---@return T copy a deep copy; tables are rebuilt, everything else is returned as it is
function LB:CopyTable(source)
	if type(source) ~= "table" then
		return source
	end

	local result = {}

	for key, value in pairs(source) do
		result[key] = self:CopyTable(value)
	end

	return result
end

---@param target table?
---@param defaults table
function LB:MergeDefaults(target, defaults)
	if not target then
		return
	end

	for key, value in pairs(defaults) do
		local current = target[key]

		if type(value) == "table" then
			if type(current) ~= "table" then
				current = {}
				target[key] = current
			end

			self:MergeDefaults(current, value)
		elseif current == nil then
			target[key] = value
		end
	end
end

---@param frame Frame
---@param duration number seconds
---@param apply fun(eased: number)
---@param onFinished fun()?
function LB:Tween(frame, duration, apply, onFinished)
	local elapsed = 0

	frame:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta

		local progress = duration > 0 and (elapsed / duration) or 1
		local done = progress >= 1

		if done then
			progress = 1
			frame:SetScript("OnUpdate", nil)
		end

		local inverse = 1 - progress

		apply(1 - inverse * inverse * inverse)

		if done and onFinished then
			onFinished()
		end
	end)
end

---@param frame Frame
function LB:StopTween(frame)
	frame:SetScript("OnUpdate", nil)
end

---@param section string? section to open at
function LB:OpenSettings(section)
	if self.Settings then
		self.Settings:Open(section)

		return
	end

	self:Warn(self.L["the settings window is not available yet."])
end

SLASH_LEVELBOUND1 = "/levelbound"
SLASH_LEVELBOUND2 = "/lb"

SlashCmdList.LEVELBOUND = function()
	LB:OpenSettings()
end
