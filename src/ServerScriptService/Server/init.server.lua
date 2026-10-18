--!strict
-- PAW MAYHEM — server bootstrap.
-- Builds the arena and starts every service in dependency order. Services that
-- listen to DataService.ProfileLoaded are started BEFORE DataService so no
-- early join is missed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Services = script.Services
local World = script.World

local DataService = require(Services.DataService)
local EconomyService = require(Services.EconomyService)
local QuestService = require(Services.QuestService)
local WeaponService = require(Services.WeaponService)
local PowerUpService = require(Services.PowerUpService)
local PlayerService = require(Services.PlayerService)
local MatchService = require(Services.MatchService)
local DropService = require(Services.DropService)
local EventService = require(Services.EventService)
local MonetizationService = require(Services.MonetizationService)
local LeaderboardService = require(Services.LeaderboardService)
local SeasonService = require(Services.SeasonService)
local RetentionService = require(Services.RetentionService)
local CommunityService = require(Services.CommunityService)
local LobbyService = require(Services.LobbyService)
local DuelService = require(Services.DuelService)
local ArenaBuilder = require(World.ArenaBuilder)
local MapPreviews = require(World.MapPreviews)

local function main()
	-- 1. Create all remotes up front.
	Remotes.InitServer()

	-- 2. Snapshot every map for the map picker, then build the real arena so
	--    spawns/pads exist before players spawn.
	MapPreviews.Build()
	ArenaBuilder.Build()

	-- 3. Start services that must be ready before profiles load.
	-- Each one starts on its own, so a bug in one can't stop the rest (and
	-- leave players with no lobby to spawn into); the error still shows in Output.
	local function start(name: string, service: any)
		local ok, err = pcall(service.Start)
		if not ok then
			warn("[PAW MAYHEM] " .. name .. " failed to start: " .. tostring(err))
		end
	end
	start("EconomyService", EconomyService)
	start("QuestService", QuestService)
	start("WeaponService", WeaponService)
	start("PowerUpService", PowerUpService)
	start("PlayerService", PlayerService)
	start("MatchService", MatchService)
	start("DropService", DropService)
	start("EventService", EventService)
	start("MonetizationService", MonetizationService)
	start("LeaderboardService", LeaderboardService)
	start("SeasonService", SeasonService)
	start("RetentionService", RetentionService)
	start("CommunityService", CommunityService)
	start("LobbyService", LobbyService)
	start("DuelService", DuelService) -- (duel pads stand in the lobby)

	-- 4. Push profile to client + ensure daily quests on load, then put the
	--    player in the lobby (they join matches and duels from there).
	DataService.ProfileLoaded:Connect(function(player)
		QuestService.EnsureDaily(player)
		EconomyService.Push(player)
		LobbyService.Spawn(player)
	end)

	-- 5. Finally start data (fires ProfileLoaded for joiners).
	DataService.Start()

	print("[PAW MAYHEM] Server started.")
end

main()
