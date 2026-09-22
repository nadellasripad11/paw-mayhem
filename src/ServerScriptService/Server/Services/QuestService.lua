--!strict
-- QuestService: rolls a fresh set of daily quests per player once per UTC day.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local QuestService = {}

local SECONDS_PER_DAY = 86400

local function currentDay(): number
	return math.floor(os.time() / SECONDS_PER_DAY)
end

local function rollQuests()
	local pool = table.clone(Progression.QuestPool)
	-- shuffle
	for i = #pool, 2, -1 do
		local j = math.random(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local chosen = {}
	for i = 1, math.min(Progression.DailyQuestCount, #pool) do
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
		profile.Quests.Active = rollQuests()
		EconomyService.Push(player)
	end
end

function QuestService.Start()
	DataService.ProfileLoaded:Connect(function(player)
		QuestService.EnsureDaily(player)
	end)
end

return QuestService
