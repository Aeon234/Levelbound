local LB = select(2, ...)

local L = LB.L

local HONOR_PANELS = { "CasualPanel", "RatedPanel", "TrainingGroundsPanel" }
local BOOK_CARDS = {
	"PrimaryProfession1", "PrimaryProfession2", "SecondaryProfession1", "SecondaryProfession2", "SecondaryProfession3",
}
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

---Adds an unplaced "Show as Experience Bar" checkbox.
---@param parent Frame
---@param get fun(): boolean
---@param set fun(on: boolean)
---@return CheckButton button
---@return fun() sync shows the current value
function BlizzardWatch:AddCheckbox(parent, get, set)
	local button = CreateFrame("CheckButton", nil, parent, "UICheckButtonArtTemplate")

	LB:SetPixelSize(button, 21, 21)

	local label = button:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")

	label:SetPoint("RIGHT", button, "LEFT")
	label:SetText(MAJOR_FACTION_WATCH_FACTION_BUTTON_LABEL)

	local function Sync()
		button:SetChecked(get())
	end

	button:SetScript("OnShow", Sync)
	button:SetScript("OnClick", function(self)
		local on = self:GetChecked()

		PlayToggle(on)
		set(on)
	end)

	LB.Callbacks:Register("Settings", button, function()
		if button:IsVisible() then
			Sync()
		end
	end)

	Sync()

	return button, Sync
end

---Adds a "Show as Experience Bar" checkbox bound to a progress type's profile switch.
---@param parent Frame
---@param anchor Region the checkbox sits on its top-right corner
---@param x number
---@param typeId string
function BlizzardWatch:AddTypeCheckbox(parent, anchor, x, typeId)
	local path = "types." .. typeId
	local button = self:AddCheckbox(parent, function()
		return LB.Profile:Get(path) == true
	end, function(on)
		LB.Profile:Set(path, on)
	end)

	button:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", x, 0)
end

---Adds a checkbox to each profession card of the profession book, and one beside the professions window's close
---button for the profession it shows. They track a profession for this character.
---@param frame Frame ProfessionsFrame
function BlizzardWatch:AttachProfessions(frame)
	local Professions = LB.Professions
	local content = frame.BookPage and frame.BookPage.ProfessionsContentFrame
	local syncs = {}

	for _, key in ipairs(BOOK_CARDS) do
		local card = content and content[key]
		local bar = card and card.StatusBar

		if bar then
			-- Parented to the rank bar, which the book hides on a card with no profession.
			local button, sync = self:AddCheckbox(bar, function()
				return card.skillLine ~= nil and Professions:IsTracked(card.skillLine)
			end, function(on)
				if card.skillLine then
					Professions:SetTracked(card.skillLine, on)
				end
			end)

			if card.isPrimary then
				button:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", 0, 0)
			else
				button:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -2)
			end

			syncs[#syncs + 1] = sync
		end
	end

	if #syncs > 0 and frame.BookPage.Update then
		hooksecurefunc(frame.BookPage, "Update", function()
			for _, sync in ipairs(syncs) do
				sync()
			end
		end)
	end

	local page = frame.CraftingPage

	if not (page and frame.CloseButton) then
		return
	end

	---@return number? skillLine the shown profession, when it is one of this character's
	local function Shown()
		local info = C_TradeSkillUI.GetBaseProfessionInfo()
		local line = info and info.professionID

		return line and Professions:Find(line) and line or nil
	end

	local button, sync = self:AddCheckbox(page, function()
		local line = Shown()

		return line ~= nil and Professions:IsTracked(line)
	end, function(on)
		local line = Shown()

		if line then
			Professions:SetTracked(line, on)
		end
	end)

	button:SetPoint("TOPRIGHT", frame.CloseButton, "BOTTOMRIGHT", -4, 0)
	-- The page sits below the window's border art.
	button:SetFrameLevel(frame.CloseButton:GetFrameLevel())

	local function Update()
		button:SetShown(Shown() ~= nil)
		sync()
	end

	page:HookScript("OnShow", Update)

	if frame.SetProfessionInfo then
		hooksecurefunc(frame, "SetProfessionInfo", Update)
	end
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
				self:AddTypeCheckbox(frame, bar, -14, "travelers")
			end
		end)
	end

	if can.endeavor then
		EventUtil.ContinueOnAddOnLoaded("Blizzard_HousingDashboard", function()
			local content = HousingDashboardFrame and HousingDashboardFrame.HouseInfoContent
			local initiatives = content and content.ContentFrame and content.ContentFrame.InitiativesFrame
			local set = initiatives and initiatives.InitiativeSetFrame

			if set and set.ProgressBar then
				self:AddTypeCheckbox(set, set.ProgressBar, 0, "endeavor")
			end
		end)
	end

	if can.professions then
		EventUtil.ContinueOnAddOnLoaded("Blizzard_Professions", function()
			if ProfessionsFrame then
				self:AttachProfessions(ProfessionsFrame)
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
