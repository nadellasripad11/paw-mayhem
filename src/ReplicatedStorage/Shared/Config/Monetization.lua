--!strict
-- Monetization: every Game Pass and Developer Product the game sells.
-- `Id` is the asset id from the Creator Dashboard (create.roblox.com >
-- Monetization). While an Id is 0 the item shows as "coming soon" and can't be
-- bought. Prices here are for display; Roblox charges what the dashboard says.

local Weapons = require(script.Parent.Weapons)

local Monetization = {}

export type Pass = { Id: number, Price: number, Name: string, Desc: string }
export type Product = { Id: number, Price: number, Name: string, Desc: string, Kind: string, Amount: number?, ItemKind: string?, ItemId: string? }

-- Game Passes (bought once, owned forever).
Monetization.Passes = {
	VIP = { Id = 1991786724, Price = 199, Name = "VIP", Desc = "Gold VIP tag, +25% coins forever, VIP Gold blaster skin and Royal Gold fur." },
	DoubleCoins = { Id = 1993418269, Price = 249, Name = "2x Coins", Desc = "Double every coin reward. Stacks with VIP." },
	EmotePack = { Id = 1993058474, Price = 99, Name = "Emote Pack", Desc = "Unlocks every emote plus the exclusive Dance and Flex." },
	TrailPack = { Id = 1988444705, Price = 149, Name = "Trail Pack", Desc = "Rainbow dash trail and confetti bursts on every elimination." },
} :: { [string]: Pass }

-- Coin reward multipliers granted by passes (they stack).
Monetization.CoinMult = { VIP = 1.25, DoubleCoins = 2 }

-- Developer Products (can be bought again and again).
Monetization.Products = {
	Gems100 = { Id = 3714380523, Price = 49, Name = "100 Gems", Desc = "A pouch of gems.", Kind = "Gems", Amount = 100 },
	Gems350 = { Id = 3714380605, Price = 149, Name = "350 Gems", Desc = "A bag of gems.", Kind = "Gems", Amount = 350 },
	Gems1000 = { Id = 3714380695, Price = 399, Name = "1,000 Gems", Desc = "A chest of gems.", Kind = "Gems", Amount = 1000 },
	Gems2800 = { Id = 3714380755, Price = 999, Name = "2,800 Gems", Desc = "A vault of gems. Best value!", Kind = "Gems", Amount = 2800 },
	CoinRain = { Id = 3714380823, Price = 99, Name = "Coin Rain", Desc = "Make it rain! Everyone in the server gets 150 coins (you get 300).", Kind = "CoinRain", Amount = 150 },
	StarterPack = { Id = 3714380879, Price = 79, Name = "Starter Pack", Desc = "1,500 coins, 150 gems and the Aurora blaster skin. Once per player.", Kind = "StarterPack" },
} :: { [string]: Product }

Monetization.StarterPack = { Coins = 1500, Gems = 150, Skin = "Aurora" }

-- "Buy with R$": one product per weapon that has a RobuxPrice. Fill the ids in
-- after creating them (named "Unlock <weapon name>").
Monetization.WeaponProductIds = {
	Starfall = 3714381074,
	BoomPaw = 3714381168,
	RapidPaw = 3714381009,
	FrostBlaster = 3714381249,
	VoidCannon = 3714381344,
	BubbleBlaster = 3714380957,
	GoldenPurr = 3714381604,
	CometClaw = 3714381449,
	PurrfectStorm = 3714381513,
} :: { [string]: number }

for _, w in ipairs(Weapons.List) do
	local id = Monetization.WeaponProductIds[w.Id]
	if id ~= nil and (w :: any).RobuxPrice then
		Monetization.Products["Weapon_" .. w.Id] = {
			Id = id, Price = (w :: any).RobuxPrice, Name = "Unlock " .. w.Name, Desc = "Unlock the " .. w.Name .. " blaster.",
			Kind = "Unlock", ItemKind = "Weapon", ItemId = w.Id,
		}
	end
end

-- Lookup: product asset id -> product key.
function Monetization.ProductKeyById(assetId: number): string?
	for key, p in pairs(Monetization.Products) do
		if p.Id ~= 0 and p.Id == assetId then
			return key
		end
	end
	return nil
end

return Monetization
