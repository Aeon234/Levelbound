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
---@field Editing LBEditing
---@field Progress LBProgress
---@field Layout LBLayout
---@field Media LBMedia
---@field Model LBModel
---@field Source LBSourceFactory
---@field Preview LBPreview
---@field Placement LBPlacement
---@field EditMode LBEditMode
---@field EditPanel LBEditPanel
---@field Mover LBMoverFactory
---@field MoverMixin LBMover
---@field Broker LBBroker
---@field BarGroup LBBarGroup
---@field BlizzardBar LBBlizzardBar
---@field BlizzardWatch LBBlizzardWatch
---@field Bar LBBarFactory
---@field TextSlot LBTextSlotRenderer
---@field Tags LBTags
---@field Marker LBMarker
---@field Gain LBGain
---@field LevelUpNotice LBLevelUpNotice
---@field Visibility LBVisibility
---@field Tooltip LBTooltip
---@field Format LBFormat
---@field Comms LBComms
---@field Roster LBRoster
---@field LevelUp LBLevelUp
---@field Session LBSession
---@field TimePlayed LBTimePlayed
---@field failed boolean?
---@field Settings LBSettings
---@field SettingsPages LBSettingsPages
---@field SettingsText LBSettingsText
---@field SettingsProfiles LBSettingsProfiles
local LB = select(2, ...)

LB.name = addonName
LB.title = C_AddOns.GetAddOnMetadata(addonName, "Title") or addonName
LB.version = C_AddOns.GetAddOnMetadata(addonName, "Version") or UNKNOWN

if LB.version:find("@", 1, true) then
	LB.version = "dev"
end

LB.MESSAGE_PREFIX = "Levelbound"

LB.TYPE_ORDER = { "xp", "petxp", "reputation", "house", "endeavor", "travelers", "honor" }

---@class LBLimit
---@field min number
---@field max number? nil when the maximum is read at run time

-- The ranges the settings offer, shared by their sliders, the code that clamps them and the previews sized to fit
-- their largest values.
---@type table<string, LBLimit>
LB.LIMITS = {
	barWidth = { min = 100 }, -- up to the screen's width
	barHeight = { min = 4, max = 64 },
	borderWidth = { min = 1, max = 10 },
	markerSize = { min = 4, max = 24 },
	markerOffset = { min = -32, max = 32 },
	textSize = { min = 6, max = 32 },
}

-- The LibSharedMedia name of Levelbound's own level-up sound, the level-up notices' default.
LB.SOUND_LEVEL_UP = "LevelBound LvlUp"

LB.DEFAULT_FONT = "Gilroy Bold"

-- Logo gold, brightened for legibility as small text on dark chat backgrounds.
LB.BRAND = { 232 / 255, 182 / 255, 74 / 255 }

local PREFIX = "|cffe8b64aLevelbound|r: "
local WARN_PREFIX = "|cffe8b64aLevelbound|r |cffff4d4dWarning|r: "

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

---Returns `value` unless it is a secret value, in which case returns `fallback`.
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
---@param ease (fun(progress: number): number)?
function LB:Tween(frame, duration, apply, onFinished, ease)
	local elapsed = 0

	frame:SetScript("OnUpdate", function(_, delta)
		elapsed = elapsed + delta

		local progress = duration > 0 and (elapsed / duration) or 1
		local done = progress >= 1

		if done then
			progress = 1
			frame:SetScript("OnUpdate", nil)
		end

		if ease then
			apply(ease(progress))
		else
			local inverse = 1 - progress

			apply(1 - inverse * inverse * inverse)
		end

		if done and onFinished then
			onFinished()
		end
	end)
end

---@param frame Frame
function LB:StopTween(frame)
	frame:SetScript("OnUpdate", nil)
end

---@param region Region? defaults to UIParent
---@return number pixel the size of one physical pixel in the region's units
function LB:Pixel(region)
	return PixelUtil.GetPixelToUIUnitFactor() / (region or UIParent):GetEffectiveScale()
end

---@param region Region
---@param width number
function LB:SetPixelWidth(region, width)
	region:SetWidth(PixelUtil.GetNearestPixelSize(width, region:GetEffectiveScale()))
end

---@param region Region
---@param height number
function LB:SetPixelHeight(region, height)
	region:SetHeight(PixelUtil.GetNearestPixelSize(height, region:GetEffectiveScale()))
end

---@param region Region
---@param width number
---@param height number
function LB:SetPixelSize(region, width, height)
	self:SetPixelWidth(region, width)
	self:SetPixelHeight(region, height)
end

---@param section string? section to open at
function LB:OpenSettings(section)
	if self.Settings then
		self.Settings:Open(section)

		return
	end

	self:Warn(self.L["the settings window is not available yet."])
end

function LB:PrintDiagnostics()
	self:Print("v%s  profile %q", self.version, self.Profile.activeName or "?")

	local capabilities = {}

	for name, present in pairs(self.can) do
		if present then
			capabilities[#capabilities + 1] = name
		end
	end

	table.sort(capabilities)
	self:Print("capabilities: %s", table.concat(capabilities, ", "))

	local layout = self.Profile:Get("layout")

	if not layout then
		self:Warn(
			"no active profile: saved data did not initialize. LevelboundDB=%s active=%s",
			tostring(LevelboundDB ~= nil),
			tostring(self.Profile.active ~= nil)
		)

		return
	end

	self:Print(
		"layout %s  %dx%d  fullscreen %s  strata %s",
		layout.mode,
		layout.width,
		layout.height,
		layout.fullscreen,
		layout.strata
	)

	for _, id in ipairs(self.Model:Order()) do
		local source = self.Model:Source(id)

		if source then
			local snapshot = source.snapshot
			local state = source.visible and "shown" or (source.available and "available" or "absent")

			self:Print(
				"  %-10s %-9s %s / %s  quest %s  rested %s",
				id,
				state,
				tostring(snapshot.cur),
				tostring(snapshot.max),
				tostring(snapshot.overlays.quest),
				tostring(snapshot.overlays.rested)
			)
		end
	end

	self:Print(
		"session %s elapsed, %s gained, rate %s, to level %s",
		tostring(math.floor(self.Session:Elapsed())),
		tostring(self.Session.xp),
		tostring(self.Session:Rate()),
		tostring(self.Session:TimeToLevel())
	)
	self:Print(
		"time played: level %s, total %s, requested %s",
		tostring(self.TimePlayed:LevelTime()),
		tostring(self.TimePlayed:TotalTime()),
		tostring(self.TimePlayed.requested)
	)

	local inputs = self.Editing.inputs

	self:Print(
		"editing %s, preview all %s (edit mode %s, independent %s, empty %s)",
		tostring(self.Editing:IsEditing()),
		tostring(self.Editing:PreviewAll()),
		tostring(inputs.editMode),
		tostring(inputs.independent),
		tostring(inputs.empty)
	)
end

SLASH_LEVELBOUND1 = "/levelbound"
SLASH_LEVELBOUND2 = "/lb"

SlashCmdList.LEVELBOUND = function(message)
	local command, argument = (message or ""):lower():match("^%s*(%S*)%s*(%S*)")

	if command == "debug" then
		if argument == "levelup" then
			LB.LevelUp:Sample()

			return
		end

		LB:PrintDiagnostics()

		return
	end

	if command == "edit" then
		LB.EditMode:Toggle()

		return
	end

	if command == "share" then
		LB.Share:Command(argument)

		return
	end

	LB:OpenSettings(command ~= "" and command or nil)
end
