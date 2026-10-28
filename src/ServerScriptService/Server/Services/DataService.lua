--!strict
-- dataservice: persistent player profiles backed by datastoreservice.
-- lightweight session handling: load-on-join, autosave, save-on-leave, with
-- retry + bindtoclose. falls back to an in-memory profile if datastores are
-- unavailable (e.g. studio without api access) so the game stays playable.

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

-- default profile shape ------------------------------------------------------
local function defaultProfile()
	return {
		Version = 1,
		Coins = 250,
		Gems = 25,
		XP = 0, -- lifetime xp
		Stats = {
			Eliminations = 0,
			Deaths = 0,
			Matches = 0,
			Wins = 0,
			WinStreak = 0, -- wins in a row (pays a coin bonus)
			BestWinStreak = 0,
			Trophies = 0, -- trophy ranking (config.ranks)
			LastTrophies = 0, -- change from the last match, for the results screen
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
			-- the (up to) six emotes in the emote picker; "" = an empty slot.
			EmoteSlots = { "Happy", "Sit", "", "", "", "" },
		},
		RedeemedCodes = {}, -- reward codes already used (config.codes)
		Receipts = {}, -- robux purchase ids already granted (duplicate-safe)
		StarterPackBought = false,
		Daily = { LastDay = 0, Streak = 0 },
		Season = { Id = 1, XP = 0, Free = {}, Premium = {} },
		TutorialDone = false,
		Badges = {},
		Settings = {},
		Quests = {
			Day = 0, -- os.time() day-number the quests were rolled for
			Active = {}, -- { {id, metric, target, progress, claimed} }
		},
	}
end

-- merge saved data over defaults so new fields appear for old profiles.
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
			elseif string.find(tostring(result), "StudioAccessToApisNotAllowed") or string.find(tostring(result), "403") then
				-- saving is switched off for this place (studio without api
				-- access): retrying won't help, so play on a fresh profile now
				-- instead of keeping the player waiting with no cat.
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
	-- handle players already present (studio play solo hot-reload edge case)
	for _, p in ipairs(Players:GetPlayers()) do
		if not profiles[p] then
			task.spawn(loadProfile, p)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		saveProfile(player)
		profiles[player] = nil
	end)

	-- autosave loop
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
