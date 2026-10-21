--!strict
-- QuestService: rolls a fresh set of daily quests per player once per UTC day.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local QuestService = {}

local SECONDS_PER_DAY = 86400

local function currentDay(): number
	return math.floor(os.time() / SECONDS_PER_DAY)
end

-- How many tasks a day: one more with Task Master.
local function taskCount(player: Player): number
	return Progression.DailyQuestCount + (player:GetAttribute("TaskMaster") == true and Monetization.TaskMaster.ExtraTasks or 0)
end

-- Up to `count` random tasks from the pool, skipping ids in `exclude`.
local function rollQuests(count: number, exclude: { [string]: boolean }?)
	local pool = {}
	for _, t in ipairs(Progression.QuestPool) do
		if not (exclude and exclude[t.Id]) then
			table.insert(pool, t)
		end
	end
	-- shuffle
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local chosen = {}
	for i = 1, math.min(count, #pool) do
		local t = pool[i]
		table.insert(chosen, {
			Id = t.Id,
			Text = string.format(t.Text, t.Target),
			Metric = t.Metric,
			Target = t.Target,
			Progress = 0,
			Coins = t.Coins,
			Claimed = false,
		})
	end
	return chosen
end

function QuestService.EnsureDaily(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local day = currentDay()
	if profile.Quests.Day ~= day or #profile.Quests.Active == 0 then
		profile.Quests.Day = day
		profile.Quests.Active = rollQuests(taskCount(player))
		EconomyService.Push(player)
	end
end

local function idsOf(list: { any }): { [string]: boolean }
	local ids = {}
	for _, q in ipairs(list) do
		ids[q.Id] = true
	end
	return ids
end

-- Task Master bought (or found on join): top today's tasks up to the new count.
function QuestService.TopUp(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local active = profile.Quests.Active
	local missing = taskCount(player) - #active
	if missing > 0 then
		for _, q in ipairs(rollQuests(missing, idsOf(active))) do
			table.insert(active, q)
		end
		EconomyService.Push(player)
	end
end

-- Reroll Tasks: every task not yet done is swapped for a new one (finished
-- ones stay so they can still be claimed). Returns how many were swapped.
function QuestService.Reroll(player: Player): number
	local profile = DataService.Get(player)
	if not profile then
		return 0
	end
	local keep, swap = {}, 0
	for _, q in ipairs(profile.Quests.Active) do
		if q.Claimed or q.Progress >= q.Target then
			table.insert(keep, q)
		else
			swap += 1
		end
	end
	local exclude = idsOf(profile.Quests.Active)
	for _, q in ipairs(rollQuests(swap, exclude)) do
		table.insert(keep, q)
	end
	profile.Quests.Active = keep
	EconomyService.Push(player)
	return swap
end

function QuestService.Start()
	DataService.ProfileLoaded:Connect(function(player)
		QuestService.EnsureDaily(player)
	end)
end

return QuestService
