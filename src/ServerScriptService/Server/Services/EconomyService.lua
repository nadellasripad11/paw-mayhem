--!strict
-- EconomyService: server-authoritative coins / XP / levels / unlocks /
-- purchases / quest progress. Every reward flows through here so the client can
-- never mint currency or unlock items on its own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Progression = require(Shared.Config.Progression)
local Weapons = require(Shared.Config.Weapons)
local Cats = require(Shared.Config.Cats)
local Monetization = require(Shared.Config.Monetization)
local Codes = require(Shared.Config.Codes)
local DailyRewards = require(Shared.Config.DailyRewards)

local DataService = require(script.Parent.DataService)

local EconomyService = {}

-- Catalog lookup: kind -> list + id field for cost/unlock validation.
local CATALOG = {
	Weapon = { list = Weapons.List, unlockKey = "Weapons" },
	Skin = { list = Weapons.Skins, unlockKey = "Skins" },
	Fur = { list = Cats.Fur, unlockKey = "Fur" },
	Outfit = { list = Cats.Outfits, unlockKey = "Outfits" },
	Hat = { list = Cats.Hats, unlockKey = "Hats" },
	Accessory = { list = Cats.Accessories, unlockKey = "Accessories" },
	Emote = { list = Cats.Emotes, unlockKey = "Emotes" },
}

local function findItem(kind: string, id: string)
	local cat = CATALOG[kind]
	if not cat then
		return nil, nil
	end
	for _, item in ipairs(cat.list) do
		if item.Id == id then
			return item, cat
		end
	end
	return nil, cat
end

-- Push the full profile snapshot to a player's client.
-- Set by BadgeService: runs after every profile push (milestone checks).
EconomyService.OnPushed = nil :: ((Player, any, number) -> ())?

function EconomyService.Push(player: Player)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	local level, into, need = Progression.Resolve(profile.XP)
	Remotes.Get("ProfileUpdate"):FireClient(player, {
		Coins = profile.Coins,
		Gems = profile.Gems,
		XP = profile.XP,
		Level = level,
		LevelXP = into,
		LevelNeed = need,
		Stats = profile.Stats,
		Unlocks = profile.Unlocks,
		Loadout = profile.Loadout,
		Quests = profile.Quests,
		StarterPackBought = profile.StarterPackBought,
		Settings = profile.Settings,
		Daily = DailyRewards.Status(profile.Daily),
		Season = profile.Season,
		TutorialDone = profile.TutorialDone,
	})
	if EconomyService.OnPushed then
		task.spawn(EconomyService.OnPushed, player, profile, level)
	end
end

-- Award XP (and handle level-up coin bonuses). Returns new level.
function EconomyService.AddXP(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
	end
	for pass, mult in pairs(Monetization.XPMult) do
		if player:GetAttribute(pass) == true then
			amount = math.floor(amount * mult + 0.5)
		end
	end
	local beforeLevel = Progression.Resolve(profile.XP)
	profile.XP += amount
	local afterLevel = Progression.Resolve(profile.XP)
	if afterLevel > beforeLevel then
		for l = beforeLevel, afterLevel - 1 do
			profile.Coins += Progression.LevelUpCoins(l + 1)
		end
		Remotes.Get("Notify"):FireClient(player, { text = "Level Up! Now level " .. afterLevel, kind = "level" })
	end
end

-- Coin rewards are multiplied by owned passes (VIP, 2x Coins); purchases and
-- refunds pass `raw = true` so they're never multiplied.
function EconomyService.AddCoins(player: Player, amount: number, raw: boolean?)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	if amount > 0 and not raw then
		for pass, mult in pairs(Monetization.CoinMult) do
			if player:GetAttribute(pass) == true then
				amount *= mult
			end
		end
		-- Weekend Mayhem bonus (CommunityService).
		local boost = workspace:GetAttribute("CoinBoost")
		if typeof(boost) == "number" then
			amount *= boost
		end
		amount = math.floor(amount + 0.5)
	end
	profile.Coins = math.max(0, profile.Coins + amount)
end

function EconomyService.AddGems(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.Gems = math.max(0, (profile.Gems or 0) + amount)
end

-- A win streak ended: reset it, and if it was worth saving (3+), remember it
-- for a few minutes and offer the Streak Saver.
function EconomyService.EndStreak(player: Player)
	local profile = DataService.Get(player)
	local stats = profile and profile.Stats
	if not stats then
		return
	end
	local n = stats.WinStreak or 0
	stats.WinStreak = 0
	if n >= Monetization.StreakSaver.MinStreak then
		profile.LostStreak = { N = n, At = os.time() }
		Remotes.Get("StreakLost"):FireClient(player, { streak = n })
	end
end

-- Give an item outright (Robux unlocks, pass rewards). Returns true if new.
function EconomyService.Grant(player: Player, kind: string, id: string): boolean
	local profile = DataService.Get(player)
	local item, cat = findItem(kind, id)
	if not profile or not item or not cat then
		return false
	end
	local unlocks = profile.Unlocks[cat.unlockKey]
	if unlocks[id] then
		return false
	end
	unlocks[id] = true
	return true
end

-- Track a stat and advance any matching quest metrics.
function EconomyService.AddStat(player: Player, statName: string, amount: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	amount = amount or 1
	if profile.Stats[statName] ~= nil then
		profile.Stats[statName] += amount
	end
	-- Map stat -> quest metric names.
	local metricMap = {
		Eliminations = "eliminations",
		Matches = "matches",
		Wins = "wins",
		Ringouts = "ringouts",
		DamageDealt = "damage",
		PowerupsGrabbed = "powerups",
	}
	local metric = metricMap[statName]
	if metric then
		EconomyService.AdvanceQuests(player, metric, amount)
	end
end

function EconomyService.AdvanceQuests(player: Player, metric: string, amount: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	for _, q in ipairs(profile.Quests.Active) do
		if q.Metric == metric and not q.Claimed then
			q.Progress = math.min(q.Target, q.Progress + amount)
		end
	end
end

-- Purchase an item with coins, or gems for gem-priced items. Pass-only items
-- come from their Game Pass. Returns {ok, reason}.
function EconomyService.Purchase(player: Player, kind: string, id: string)
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false, reason = "no profile" }
	end
	local item, cat = findItem(kind, id)
	if not item or not cat then
		return { ok = false, reason = "unknown item" }
	end
	local unlocks = profile.Unlocks[cat.unlockKey]
	if unlocks[id] then
		return { ok = false, reason = "already owned" }
	end
	if item.PassOnly then
		return { ok = false, reason = "pass only" }
	end
	if item.Season then
		return { ok = false, reason = "season only" }
	end
	if item.GemCost then
		if (profile.Gems or 0) < item.GemCost then
			return { ok = false, reason = "not enough gems" }
		end
		profile.Gems -= item.GemCost
	else
		local cost = item.CoinCost or 0
		if profile.Coins < cost then
			return { ok = false, reason = "not enough coins" }
		end
		profile.Coins -= cost
	end
	unlocks[id] = true
	EconomyService.Push(player)
	return { ok = true }
end

-- Validate a player owns an item id of a kind.
function EconomyService.Owns(player: Player, kind: string, id: string): boolean
	local profile = DataService.Get(player)
	if not profile then
		return false
	end
	local cat = CATALOG[kind]
	if not cat then
		return false
	end
	return profile.Unlocks[cat.unlockKey][id] == true
end

-- Equip an item into the loadout (validates ownership).
function EconomyService.Equip(player: Player, kind: string, id: string)
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false }
	end
	if not EconomyService.Owns(player, kind, id) then
		return { ok = false, reason = "not owned" }
	end
	if kind == "Weapon" then
		profile.Loadout.Weapon = id
	elseif kind == "Skin" then
		profile.Loadout.Skin = id
	elseif kind == "Fur" or kind == "Outfit" or kind == "Hat" or kind == "Accessory" or kind == "Emote" then
		profile.Loadout.Cat[kind] = id
	else
		return { ok = false }
	end
	EconomyService.Push(player)
	if EconomyService.OnEquipped then
		EconomyService.OnEquipped(player, kind)
	end
	return { ok = true }
end

-- Set by PlayerService: put a loadout change on the player's cat.
EconomyService.OnEquipped = nil :: ((player: Player, kind: string) -> ())?

function EconomyService.ClaimQuest(player: Player, questId: string)
	local profile = DataService.Get(player)
	if not profile then
		return { ok = false }
	end
	for _, q in ipairs(profile.Quests.Active) do
		if q.Id == questId then
			if q.Claimed then
				return { ok = false, reason = "claimed" }
			end
			if q.Progress < q.Target then
				return { ok = false, reason = "incomplete" }
			end
			q.Claimed = true
			local coins = q.Coins
			if player:GetAttribute("TaskMaster") == true then
				coins = math.floor(coins * Monetization.TaskMaster.CoinMult + 0.5)
			end
			profile.Coins += coins
			EconomyService.Push(player)
			return { ok = true, coins = coins }
		end
	end
	return { ok = false, reason = "unknown quest" }
end

-- Client settings the profile may store, with how to validate each.
local SETTING_RULES: { [string]: any } = {
	CameraShake = "boolean", ShowDamage = "boolean", InvertY = "boolean", AutoSprint = "boolean", AutoFire = "boolean", ShowFPS = "boolean", FirstPerson = "boolean",
	MobileSensitivity = { 0, 1 }, MusicVolume = { 0, 1 }, SFXVolume = { 0, 1 }, MouseSensitivity = { 0, 1 }, FieldOfView = { 60, 95 },
	GraphicsQuality = { Low = true, Medium = true, High = true },
	Crosshair = { White = true, Green = true, Cyan = true, Pink = true, Yellow = true },
}

-- Reward codes (Config.Codes): once per player, case-insensitive.
local function redeemCode(player: Player, code: any)
	local profile = DataService.Get(player)
	if not profile or type(code) ~= "string" then
		return { ok = false, text = "Try again in a moment" }
	end
	local key = string.upper((string.gsub(code, "%s", "")))
	local reward = Codes[key]
	if not reward then
		return { ok = false, text = "That code doesn't exist" }
	end
	profile.RedeemedCodes = profile.RedeemedCodes or {}
	if profile.RedeemedCodes[key] then
		return { ok = false, text = "You already used that code" }
	end
	profile.RedeemedCodes[key] = true
	local parts = {}
	if reward.Coins then
		EconomyService.AddCoins(player, reward.Coins, true)
		table.insert(parts, "+" .. reward.Coins .. " coins")
	end
	if reward.Gems then
		EconomyService.AddGems(player, reward.Gems)
		table.insert(parts, "+" .. reward.Gems .. " gems")
	end
	EconomyService.Push(player)
	return { ok = true, text = "Redeemed! " .. table.concat(parts, ", ") }
end

local lastEmote: { [Player]: number } = {}

-- Emotes: if the player owns it, stamp it on their character so every client
-- poses it (Emote / EmoteAt attributes, read by CatBuilder.Pose).
local function useEmote(player: Player, id: any)
	if type(id) ~= "string" or os.clock() - (lastEmote[player] or 0) < 1 then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 or not EconomyService.Owns(player, "Emote", id) then
		return
	end
	lastEmote[player] = os.clock()
	char:SetAttribute("Emote", id)
	char:SetAttribute("EmoteAt", workspace:GetServerTimeNow())
end

-- Move animations (the double-jump flip, a dash...) are passed on to everyone
-- else so they see them too. Animation only: nothing here changes the game.
local MOVE_FX = { Flip = true, Dash = true, Pounce = true, WallKick = true, Swing = true, SwingEnd = true }
local lastMoveFx: { [Player]: number } = {}
local function relayMoveFx(player: Player, kind: any)
	if type(kind) ~= "string" or not MOVE_FX[kind] or not player.Character then
		return
	end
	local now = os.clock()
	if now - (lastMoveFx[player] or 0) < 0.08 then
		return
	end
	lastMoveFx[player] = now
	for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
		if p ~= player then
			Remotes.Get("MoveFx"):FireClient(p, { char = player.Character, kind = kind })
		end
	end
end

function EconomyService.Start()
	Remotes.Get("RedeemCode").OnServerInvoke = redeemCode
	Remotes.Get("UseEmote").OnServerEvent:Connect(useEmote)
	Remotes.Get("MoveFx").OnServerEvent:Connect(relayMoveFx)
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		lastEmote[p] = nil
		lastMoveFx[p] = nil
	end)
	Remotes.Get("SaveSettings").OnServerEvent:Connect(function(player, patch)
		local profile = DataService.Get(player)
		if not profile or typeof(patch) ~= "table" then
			return
		end
		profile.Settings = profile.Settings or {}
		for k, v in pairs(patch) do
			local rule = SETTING_RULES[k]
			if rule == "boolean" and typeof(v) == "boolean" then
				profile.Settings[k] = v
			elseif typeof(rule) == "table" and rule[1] and typeof(v) == "number" then
				profile.Settings[k] = math.clamp(v, rule[1], rule[2])
			elseif typeof(rule) == "table" and typeof(v) == "string" and rule[v] then
				profile.Settings[k] = v
			end
		end
	end)

	-- Purchase / equip / claim remote handlers.
	Remotes.Get("PurchaseItem").OnServerInvoke = function(player, payload)
		if type(payload) ~= "table" then
			return { ok = false }
		end
		return EconomyService.Purchase(player, tostring(payload.kind), tostring(payload.id))
	end
	Remotes.Get("EquipItem").OnServerInvoke = function(player, payload)
		if type(payload) ~= "table" then
			return { ok = false }
		end
		return EconomyService.Equip(player, tostring(payload.kind), tostring(payload.id))
	end
	Remotes.Get("ClaimQuest").OnServerInvoke = function(player, questId)
		return EconomyService.ClaimQuest(player, tostring(questId))
	end
end

return EconomyService
