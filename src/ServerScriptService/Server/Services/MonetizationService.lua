--!strict
-- MonetizationService: Game Passes and Developer Products.
--   * Game Passes are checked on join (and when bought in-game) and published
--     as player attributes (VIP, DoubleCoins, EmotePack, TrailPack) that the
--     rest of the game reads. Pass rewards (VIP skin + fur, pass emotes) are
--     added to the player's unlocks.
--   * ProcessReceipt grants Developer Products exactly once: each purchase id
--     is recorded in the profile and saved before Roblox is told it's granted.

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Monetization = require(Shared.Config.Monetization)
local Weapons = require(Shared.Config.Weapons)
local Cats = require(Shared.Config.Cats)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local SeasonService = require(script.Parent.SeasonService)

local MonetizationService = {}

local MAX_RECEIPTS = 200

local function announce(title: string, sub: string?, color: Color3?)
	Remotes.Get("Announce"):FireAllClients({ title = title, sub = sub, color = color })
end

-- Every catalog item locked behind `passKey`.
local function passItems(passKey: string): { { kind: string, id: string } }
	local out = {}
	for _, s in ipairs(Weapons.Skins) do
		if (s :: any).PassOnly == passKey then
			table.insert(out, { kind = "Skin", id = s.Id })
		end
	end
	for kind, list in pairs({ Fur = Cats.Fur, Hat = Cats.Hats, Outfit = Cats.Outfits, Accessory = Cats.Accessories, Emote = Cats.Emotes }) do
		for _, item in ipairs(list) do
			if item.PassOnly == passKey then
				table.insert(out, { kind = kind, id = item.Id })
			end
		end
	end
	if passKey == "EmotePack" then
		for _, e in ipairs(Cats.Emotes) do
			table.insert(out, { kind = "Emote", id = e.Id })
		end
	end
	return out
end

local function applyPass(player: Player, passKey: string)
	player:SetAttribute(passKey, true)
	for _, it in ipairs(passItems(passKey)) do
		EconomyService.Grant(player, it.kind, it.id)
	end
	EconomyService.Push(player)
end

local function checkPasses(player: Player)
	for key, pass in pairs(Monetization.Passes) do
		if pass.Id ~= 0 and not player:GetAttribute(key) then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.Id)
			if ok and owns then
				applyPass(player, key)
			end
		end
	end
end

-- ── products ─────────────────────────────────────────────────────────────────
local function coinRain(buyer: Player, amount: number)
	for _, p in ipairs(Players:GetPlayers()) do
		EconomyService.AddCoins(p, p == buyer and amount * 2 or amount, true)
		EconomyService.Push(p)
	end
	announce(buyer.DisplayName .. " made it rain!", string.format("Everyone gets %d coins", amount), Color3.fromRGB(255, 214, 70))
	Remotes.Get("PlayEffect"):FireAllClients({ kind = "CoinRain" })
end

local function grantProduct(player: Player, key: string): boolean
	local product = Monetization.Products[key]
	local profile = DataService.Get(player)
	if not product or not profile then
		return false
	end
	if product.Kind == "Gems" then
		EconomyService.AddGems(player, product.Amount or 0)
		Remotes.Get("Notify"):FireClient(player, { text = string.format("+%d gems!", product.Amount or 0), kind = "success" })
	elseif product.Kind == "CoinRain" then
		coinRain(player, product.Amount or 150)
	elseif product.Kind == "StarterPack" then
		local pack = Monetization.StarterPack
		EconomyService.AddCoins(player, pack.Coins, true)
		EconomyService.AddGems(player, pack.Gems)
		EconomyService.Grant(player, "Skin", pack.Skin)
		profile.StarterPackBought = true
		Remotes.Get("Notify"):FireClient(player, { text = "Starter Pack unlocked!", kind = "success" })
	elseif product.Kind == "SeasonTiers" then
		SeasonService.SkipTiers(player, product.Amount or 5)
		Remotes.Get("Notify"):FireClient(player, { text = string.format("+%d season tiers!", product.Amount or 5), kind = "success" })
	elseif product.Kind == "Unlock" and product.ItemKind and product.ItemId then
		EconomyService.Grant(player, product.ItemKind, product.ItemId)
		EconomyService.Equip(player, product.ItemKind, product.ItemId)
		Remotes.Get("Notify"):FireClient(player, { text = product.Name .. "!", kind = "success" })
	else
		return false
	end
	EconomyService.Push(player)
	return true
end

local function processReceipt(info): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and DataService.Get(player)
	if not player or not profile then
		-- They left or haven't loaded; Roblox retries later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local receiptId = tostring(info.PurchaseId)
	profile.Receipts = profile.Receipts or {}
	if profile.Receipts[receiptId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local key = Monetization.ProductKeyById(info.ProductId)
	if not key or not grantProduct(player, key) then
		warn("[PAW MAYHEM] Unknown or failed product " .. tostring(info.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	profile.Receipts[receiptId] = os.time()
	-- Keep the receipt log bounded: drop the oldest entries.
	local ids = {}
	for id, t in pairs(profile.Receipts) do
		table.insert(ids, { id = id, t = t })
	end
	if #ids > MAX_RECEIPTS then
		table.sort(ids, function(a, b)
			return a.t < b.t
		end)
		for i = 1, #ids - MAX_RECEIPTS do
			profile.Receipts[ids[i].id] = nil
		end
	end
	DataService.Save(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService.Start()
	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		for key, pass in pairs(Monetization.Passes) do
			if pass.Id == passId then
				applyPass(player, key)
				announce(player.DisplayName .. " got " .. pass.Name .. "!", nil, Color3.fromRGB(255, 206, 60))
			end
		end
	end)

	DataService.ProfileLoaded:Connect(function(player)
		task.spawn(checkPasses, player)
	end)
end

return MonetizationService
