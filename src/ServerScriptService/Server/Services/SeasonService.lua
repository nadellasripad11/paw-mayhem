--!strict
-- SeasonService: season pass progress + reward claims.
--   * Season XP comes from playing (see Config.Season.XP).
--   * Free rewards can be claimed by anyone who reaches the tier; premium
--     rewards need the "SeasonPass" game pass (player attribute).
--   * Claimed tiers are stored with string keys ("t12") so the profile saves
--     cleanly to DataStores.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Season = require(Shared.Config.Season)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)

local SeasonService = {}

local function seasonOf(profile: any): any
	local s = profile.Season
	if typeof(s) ~= "table" or s.Id ~= Season.Id then
		-- New season: progress starts over.
		s = { Id = Season.Id, XP = 0, Free = {}, Premium = {} }
		profile.Season = s
	end
	s.Free = s.Free or {}
	s.Premium = s.Premium or {}
	return s
end

-- Add Season XP for an action ("MatchPlayed", "Win", ...) or a raw amount.
function SeasonService.AddXP(player: Player, action: string | number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local amount = typeof(action) == "number" and action or (Season.XP[action] or 0)
	if amount <= 0 then
		return
	end
	local s = seasonOf(profile)
	local before = Season.TierFor(s.XP)
	s.XP = math.min(s.XP + amount, Season.Tiers * Season.XPPerTier)
	local after = Season.TierFor(s.XP)
	if after > before then
		Remotes.Get("Notify"):FireClient(player, { text = string.format("Season tier %d reached! Claim your reward.", after), kind = "success" })
	end
end

local function grant(player: Player, reward: any): boolean
	if reward.Kind == "Coins" then
		EconomyService.AddCoins(player, reward.Amount or 0, true)
		return true
	elseif reward.Kind == "Gems" then
		EconomyService.AddGems(player, reward.Amount or 0)
		return true
	elseif reward.Id then
		-- Already owning a cosmetic still counts as claimed.
		EconomyService.Grant(player, reward.Kind, reward.Id)
		return true
	end
	return false
end

local function claim(player: Player, payload: any)
	local profile = DataService.Get(player)
	if not profile or typeof(payload) ~= "table" then
		return { ok = false }
	end
	local tier = tonumber(payload.tier)
	local track = payload.track == "Premium" and "Premium" or "Free"
	local row = tier and Season.Rewards[tier]
	if not row then
		return { ok = false, reason = "unknown tier" }
	end
	local s = seasonOf(profile)
	if Season.TierFor(s.XP) < tier then
		return { ok = false, reason = "locked" }
	end
	if track == "Premium" and not player:GetAttribute("SeasonPass") then
		return { ok = false, reason = "need pass" }
	end
	local key = "t" .. tostring(tier)
	if s[track][key] then
		return { ok = false, reason = "claimed" }
	end
	if not grant(player, row[track]) then
		return { ok = false }
	end
	s[track][key] = true
	EconomyService.Push(player)
	return { ok = true }
end

-- Robux "+5 tiers" product.
function SeasonService.SkipTiers(player: Player, tiers: number)
	SeasonService.AddXP(player, tiers * Season.XPPerTier)
end

function SeasonService.Start()
	Remotes.Get("ClaimSeason").OnServerInvoke = claim
	DataService.ProfileLoaded:Connect(function(_player, profile)
		seasonOf(profile)
	end)
end

return SeasonService
