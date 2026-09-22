--!strict
-- DataService: persistent player profiles backed by DataStoreService.
-- Lightweight session handling: load-on-join, autosave, save-on-leave, with
-- retry + BindToClose. Falls back to an in-memory profile if DataStores are
-- unavailable (e.g. Studio without API access) so the game stays playable.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)
local Cats = require(game:GetService("ReplicatedStorage").Shared.Config.Cats)
local Weapons = require(game:GetService("ReplicatedStorage").Shared.Config.Weapons)
local Signal = require(game:GetService("ReplicatedStorage").Shared.Util.Signal)

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- fires (player, profile)

local store: DataStore? = nil
local ok = pcall(function()
	store = DataStoreService:GetDataStore(GameConfig.DataStore.Name)
end)
if not ok then
	store = nil
end

local profiles: { [Player]: any } = {}

-- Default profile shape ------------------------------------------------------
local function defaultProfile()
	return {
		Version = 1,
		Coins = 250,
		Gems = 25,
		XP = 0, -- lifetime XP
		Stats = {
			Eliminations = 0,
			Deaths = 0,
			Matches = 0,
			Wins = 0,
			Ringouts = 0,
			DamageDealt = 0,
			PowerupsGrabbed = 0,
		},
		Unlocks = {
			Weapons = { [Weapons.DefaultLoadout] = true, BubbleBlaster = true },
			Skins = { Default = true },
			Fur = { Orange = true, Black = true, White = true },
			Outfits = { None = true, Hoodie = true },
			Hats = { None = true, Cap = true },
			Accessories = { None = true, Sunglasses = true },
			Emotes = { Happy = true, Sit = true },
		},
		Loadout = {
			Weapon = Weapons.DefaultLoadout,
			Skin = "Default",
			Cat = {
				Fur = Cats.Default.Fur,
				Outfit = Cats.Default.Outfit,
				Hat = Cats.Default.Hat,
				Accessory = Cats.Default.Accessory,
				Emote = Cats.Default.Emote,
			},
		},
		Quests = {
			Day = 0, -- os.time() day-number the quests were rolled for
			Active = {}, -- { {Id, Metric, Target, Progress, Claimed} }
		},
	}
end

-- Merge saved data over defaults so new fields appear for old profiles.
local function reconcile(saved: any)
	local base = defaultProfile()
	local function deepMerge(dst, src)
		if type(src) ~= "table" then
			return
		end
		for k, v in pairs(src) do
			if type(v) == "table" and type(dst[k]) == "table" then
				deepMerge(dst[k], v)
			else
				dst[k] = v
			end
		end
	end
	deepMerge(base, saved)
	return base
end

local function key(player: Player): string
	return "u_" .. tostring(player.UserId)
end

local function loadProfile(player: Player)
	local data = nil
	if store then
		local attempts = 0
		repeat
			attempts += 1
			local success, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if success then
				data = result
				break
			else
				task.wait(1.5)
			end
		until attempts >= GameConfig.DataStore.MaxRetries
	end

	local profile = reconcile(data or {})
	profiles[player] = profile
	DataService.ProfileLoaded:Fire(player, profile)
	return profile
end

local function saveProfile(player: Player)
	local profile = profiles[player]
	if not profile or not store then
		return
	end
	pcall(function()
		store:UpdateAsync(key(player), function(_old)
			return profile
		end)
	end)
end

function DataService.Get(player: Player): any?
	return profiles[player]
end

function DataService.Save(player: Player)
	saveProfile(player)
end

function DataService.Start()
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadProfile, player)
	end)
	-- Handle players already present (Studio play solo hot-reload edge case)
	for _, p in ipairs(Players:GetPlayers()) do
		if not profiles[p] then
			task.spawn(loadProfile, p)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player)
		profiles[player] = nil
	end)

	-- Autosave loop
	task.spawn(function()
		while true do
			task.wait(GameConfig.DataStore.AutoSaveSeconds)
			for _, p in ipairs(Players:GetPlayers()) do
				saveProfile(p)
			end
		end
	end)

	game:BindToClose(function()
		if RunService:IsStudio() then
			return
		end
		for _, p in ipairs(Players:GetPlayers()) do
			saveProfile(p)
		end
		task.wait(2)
	end)
end

return DataService
