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
	EconomyService.Start()
	QuestService.Start()
	WeaponService.Start()
	PowerUpService.Start()
	PlayerService.Start()
	MatchService.Start()
	DropService.Start()
	EventService.Start()
	MonetizationService.Start()
	LeaderboardService.Start()
	SeasonService.Start()
	RetentionService.Start()

	-- 4. Push profile to client + ensure daily quests on load.
	DataService.ProfileLoaded:Connect(function(player)
		QuestService.EnsureDaily(player)
		EconomyService.Push(player)
	end)

	-- 5. Finally start data (fires ProfileLoaded for joiners).
	DataService.Start()

	print("[PAW MAYHEM] Server started.")
end

main()
