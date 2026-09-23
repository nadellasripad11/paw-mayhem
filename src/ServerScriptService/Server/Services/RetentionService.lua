--!strict
-- RetentionService: daily login rewards, Roblox badges and the first-time
-- tutorial flag.
--   * ClaimDaily: once per UTC day; the streak grows when you come back the
--     next day and resets if you skip one. Day 7 is a big chest, then it loops.
--   * Badges: after every profile push each milestone in Config.Badges is
--     checked and awarded once (skipped while its Id is still 0).
--   * TutorialDone: the client reports when the tutorial is finished/skipped.

local BadgeService = game:GetService("BadgeService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local DailyRewards = require(Shared.Config.DailyRewards)
local Badges = require(Shared.Config.Badges)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local SeasonService = require(script.Parent.SeasonService)

local RetentionService = {}

local checking: { [Player]: boolean } = {}

local function checkBadges(player: Player, profile: any, level: number)
	if checking[player] or player.UserId <= 0 then
		return
	end
	checking[player] = true
	profile.Badges = profile.Badges or {}
	for _, b in ipairs(Badges.List) do
		if b.Id ~= 0 and not profile.Badges[b.Key] then
			local ok, earned = pcall(b.Check, profile, level)
			if ok and earned then
				local awarded = pcall(function()
					BadgeService:AwardBadge(player.UserId, b.Id)
				end)
				if awarded then
					profile.Badges[b.Key] = true
				end
			end
		end
	end
	checking[player] = nil
end

local function claimDaily(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false }
	end
	local today = DailyRewards.Today()
	local status = DailyRewards.Status(profile.Daily, today)
	if not status.CanClaim then
		return { ok = false, reason = "claimed" }
	end
	local streak = status.Streak + 1
	local reward = DailyRewards.Days[((streak - 1) % #DailyRewards.Days) + 1]
	profile.Daily = { LastDay = today, Streak = streak }
	if reward.Coins then
		EconomyService.AddCoins(player, reward.Coins, true)
	end
	if reward.Gems then
		EconomyService.AddGems(player, reward.Gems)
	end
	SeasonService.AddXP(player, "DailyClaim")
	EconomyService.Push(player)
	return { ok = true, streak = streak, coins = reward.Coins, gems = reward.Gems }
end

function RetentionService.Start()
	EconomyService.OnPushed = checkBadges
	Remotes.Get("ClaimDaily").OnServerInvoke = claimDaily
	Remotes.Get("TutorialDone").OnServerEvent:Connect(function(player)
		local profile = DataService.Get(player)
		if profile and not profile.TutorialDone then
			profile.TutorialDone = true
			EconomyService.Push(player)
		end
	end)
end

return RetentionService
