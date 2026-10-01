local LB = select(2, ...)

local L = LB.L

local HONOR_PANELS = { "CasualPanel", "RatedPanel", "TrainingGroundsPanel" }
local HINT_COLOR = { 0.1, 1, 0.1 }

---Controls on Blizzard's progress windows that show or hide a Levelbound bar. Each is added alongside Blizzard's
---own; no Blizzard script is replaced.
---@class LBBlizzardWatch
---@field attached boolean?
local BlizzardWatch = {}
LB.BlizzardWatch = BlizzardWatch

---@param on boolean
local function PlayToggle(on)
	PlaySound(on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
end

---Adds a "Show as Experience Bar" checkbox bound to a progress type's profile switch.
---@param parent Frame
---@param anchor Region the checkbox sits on its top-right corner
---@param x number
---@param typeId string
function BlizzardWatch:AddCheckbox(parent, anchor, x, typeId)
	local path = "types." .. typeId
	local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonArtTemplate")

	LB:SetPixelSize(button, 21, 21)
	button:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", x, 0)

	local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

	label:SetPoint("RIGHT", button, "LEFT")
	label:SetText(MAJOR_FACTION_WATCH_FACTION_BUTTON_LABEL)

	local function Sync()
		button:SetChecked(LB.Profile:Get(path) == true)
	end

	button:SetScript("OnShow", Sync)
	button:SetScript("OnClick", function(self)
		local on = self:GetChecked()

		PlayToggle(on)
		LB.Profile:Set(path, on)
	end)

	LB.Callbacks:Register("Settings", button, function()
		if button:IsVisible() then
			Sync()
		end
	end)

	Sync()
end

---Shift-click on a PvP honor level display toggles honor as an experience bar, leaving the watched faction alone.
---@param display Frame
function BlizzardWatch:HookHonor(display)
	display:HookScript("OnMouseUp", function(_, button)
		if button ~= "LeftButton" or not IsShiftKeyDown() then
			return
		end

		local on = not IsWatchingHonorAsXP()

		PlayToggle(on)
		SetWatchingHonorAsXP(on)
	end)

	display:HookScript("OnEnter", function()
		if GameTooltip:GetOwner() ~= display then
			return
		end

		local hint = IsWatchingHonorAsXP() and L["Shift-Click to Stop Showing as Experience Bar"]
			or L["Shift-Click to Show as Experience Bar"]

		GameTooltip:AddLine(" ")
		GameTooltip:AddLine(("<%s>"):format(hint), HINT_COLOR[1], HINT_COLOR[2], HINT_COLOR[3])
		GameTooltip:Show()
	end)
end

---Attaches each control once its Blizzard window's addon loads. Call after capabilities resolve.
function BlizzardWatch:Attach()
	if self.attached then
		return
	end

	self.attached = true

	local can = LB.can

	if can.travelers then
		EventUtil.ContinueOnAddOnLoaded("Blizzard_EncounterJournal", function()
			local frame = EncounterJournal and EncounterJournal.MonthlyActivitiesFrame
			local bar = frame and frame.ThresholdContainer and frame.ThresholdContainer.ThresholdBar

			if bar then
				self:AddCheckbox(frame, bar, -14, "travelers")
			end
		end)
	end

	if can.endeavor then
		EventUtil.ContinueOnAddOnLoaded("Blizzard_HousingDashboard", function()
			local content = HousingDashboardFrame and HousingDashboardFrame.HouseInfoContent
			local initiatives = content and content.ContentFrame and content.ContentFrame.InitiativesFrame
			local set = initiatives and initiatives.InitiativeSetFrame

			if set and set.ProgressBar then
				self:AddCheckbox(set, set.ProgressBar, 0, "endeavor")
			end
		end)
	end

	if can.honor and can.pvpWindow then
		EventUtil.ContinueOnAddOnLoaded("Blizzard_PVPUI", function()
			local inset = PVPQueueFrame and PVPQueueFrame.HonorInset

			for _, key in ipairs(HONOR_PANELS) do
				local panel = inset and inset[key]

				if panel and panel.HonorLevelDisplay then
					self:HookHonor(panel.HonorLevelDisplay)
				end
			end
		end)
	end
end
