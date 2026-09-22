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
	})
end

-- Award XP (and handle level-up coin bonuses). Returns new level.
function EconomyService.AddXP(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile or amount <= 0 then
		return
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

function EconomyService.AddCoins(player: Player, amount: number)
	local profile = DataService.Get(player)
	if not profile then
		return
	end
	profile.Coins = math.max(0, profile.Coins + amount)
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

-- Purchase an item with coins. Returns {ok, reason}.
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
	local cost = item.CoinCost or 0
	if profile.Coins < cost then
		return { ok = false, reason = "not enough coins" }
	end
	profile.Coins -= cost
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
	return { ok = true }
end

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
			profile.Coins += q.Coins
			EconomyService.Push(player)
			return { ok = true, coins = q.Coins }
		end
	end
	return { ok = false, reason = "unknown quest" }
end

function EconomyService.Start()
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
