local LB = select(2, ...)

---@class LBProgress
local Progress = {}
LB.Progress = Progress

---@param snapshot LBSnapshot
---@param key "quest" | "rested"
---@return number
local function Overlay(snapshot, key)
	local overlays = snapshot.overlays

	return overlays and overlays[key] or 0
end

---@param value number
---@return number
local function Clamp(value)
	return math.min(math.max(value, 0), 1)
end

---@param snapshot LBSnapshot
---@return boolean
local function Measurable(snapshot)
	return snapshot.max ~= nil and snapshot.max > 0
end

---@param snapshot LBSnapshot
---@return number? fraction 0-1, nil when there is no level to measure against
function Progress.Fraction(snapshot)
	if not Measurable(snapshot) then
		return nil
	end

	return Clamp(snapshot.cur / snapshot.max)
end

---@param snapshot LBSnapshot
---@param amount number
---@return number? part of the level, unclamped, so rested XP can pass a whole level
function Progress.Part(snapshot, amount)
	if not Measurable(snapshot) then
		return nil
	end

	return amount / snapshot.max
end

---@param snapshot LBSnapshot
---@return number? fill
---@return number? quest the fill with quests ready to turn in
---@return number? rested the fill with those quests and rested XP
function Progress.Fills(snapshot)
	if not Measurable(snapshot) then
		return nil
	end

	local max = snapshot.max
	local quest = snapshot.cur + Overlay(snapshot, "quest")

	return Clamp(snapshot.cur / max), Clamp(quest / max), Clamp((quest + Overlay(snapshot, "rested")) / max)
end

---@param snapshot LBSnapshot
---@return number
function Progress.Remaining(snapshot)
	return math.max(snapshot.max - snapshot.cur, 0)
end

---@param snapshot LBSnapshot
---@return number quest quest XP past the level-up
---@return number rested rested XP past the level-up
function Progress.Overflow(snapshot)
	local remaining = Progress.Remaining(snapshot)
	local questXP = Overlay(snapshot, "quest")
	local quest = math.max(questXP - remaining, 0)
	local rested = math.max(questXP + Overlay(snapshot, "rested") - remaining - quest, 0)

	return quest, rested
end

---@param rate number XP per second
---@return number perHour whole XP per hour, rounded so a rate read back from the party message's per-hour figure returns it exactly
function Progress.PerHour(rate)
	return math.floor(rate * 3600 + 0.5)
end

---@param snapshot LBSnapshot?
---@param rate number? XP per second
---@return number? seconds
function Progress.TimeToLevel(snapshot, rate)
	if not snapshot or not rate or rate <= 0 or not Measurable(snapshot) then
		return nil
	end

	local remaining = snapshot.max - snapshot.cur

	if remaining <= 0 then
		return nil
	end

	return remaining / rate
end

---@param from LBSnapshot
---@param to LBSnapshot
---@return number? levels how far `to` is ahead of `from`, negative when behind
function Progress.Distance(from, to)
	local mine, theirs = Progress.Fraction(from), Progress.Fraction(to)

	if not mine or not theirs or not from.level or not to.level then
		return nil
	end

	return (to.level + theirs) - (from.level + mine)
end
