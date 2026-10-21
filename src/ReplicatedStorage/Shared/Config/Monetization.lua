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
	VIP = { Id = 2047568433, Price = 199, Name = "VIP", Desc = "Gold VIP tag, +25% coins forever, VIP Gold blaster skin and Royal Gold fur." },
	DoubleCoins = { Id = 2046117070, Price = 249, Name = "2x Coins", Desc = "Double every coin reward. Stacks with VIP." },
	EmotePack = { Id = 2045331039, Price = 99, Name = "Emote Pack", Desc = "Unlocks every emote plus the exclusive Dance, Flex and Box Sit." },
	SeasonPass = { Id = 2045649065, Price = 299, Name = "Season Pass", Desc = "Unlocks every premium reward in the current season pass." },
	TrailPack = { Id = 2047946341, Price = 149, Name = "Trail Pack", Desc = "Rainbow dash trail and confetti bursts on every elimination." },
	DoubleXP = { Id = 2045001108, Price = 149, Name = "2x XP", Desc = "Double XP from everything: level up and climb the season pass twice as fast." },
	LuckyGift = { Id = 2047952362, Price = 99, Name = "Lucky Gift", Desc = "Double coins and gems from the free daily gift, every day." },
	TaskMaster = { Id = 2045613029, Price = 129, Name = "Task Master", Desc = "A 4th daily task every day and +50% coins from every task." },
} :: { [string]: Pass }

-- Coin reward multipliers granted by passes (they stack).
-- Coin multipliers by player attribute (GroupMember: Config.Community).
Monetization.CoinMult = { VIP = 1.25, DoubleCoins = 2, GroupMember = 1.1 }
-- XP multipliers granted by passes (levels and the season pass).
Monetization.XPMult = { DoubleXP = 2 }
-- Task Master: one extra daily task and this much more coin per task.
Monetization.TaskMaster = { ExtraTasks = 1, CoinMult = 1.5 }
-- Lucky Gift: the daily gift's coins and gems are multiplied by this.
Monetization.LuckyGiftMult = 2
-- Streak Saver: a lost win streak of at least MinStreak can be bought back
-- for Window seconds. Bought with nothing to save, it gives FallbackGems.
Monetization.StreakSaver = { MinStreak = 3, Window = 300, FallbackGems = 100 }

-- Developer Products (can be bought again and again).
Monetization.Products = {
	Gems100 = { Id = 3720863139, Price = 49, Name = "100 Gems", Desc = "A pouch of gems.", Kind = "Gems", Amount = 100 },
	Gems350 = { Id = 3720863518, Price = 149, Name = "350 Gems", Desc = "A bag of gems.", Kind = "Gems", Amount = 350 },
	Gems1000 = { Id = 3720863661, Price = 399, Name = "1,000 Gems", Desc = "A chest of gems.", Kind = "Gems", Amount = 1000 },
	Gems2800 = { Id = 3720863979, Price = 999, Name = "2,800 Gems", Desc = "A vault of gems. Best value!", Kind = "Gems", Amount = 2800 },
	CoinRain = { Id = 3720864126, Price = 99, Name = "Coin Rain", Desc = "Make it rain! Everyone in the server gets 150 coins (you get 300).", Kind = "CoinRain", Amount = 150 },
	SeasonTiers = { Id = 3720864273, Price = 99, Name = "+5 Season Tiers", Desc = "Jump 5 tiers ahead in the season pass.", Kind = "SeasonTiers", Amount = 5 },
	StarterPack = { Id = 3720864467, Price = 79, Name = "Starter Pack", Desc = "1,500 coins, 150 gems and the Aurora blaster skin. Once per player.", Kind = "StarterPack" },
	RerollTasks = { Id = 3720866163, Price = 25, Name = "Reroll Tasks", Desc = "Swap your unfinished daily tasks for new ones.", Kind = "RerollTasks" },
	StreakSaver = { Id = 3720866349, Price = 49, Name = "Streak Saver", Desc = "Get back the win streak you just lost.", Kind = "StreakSaver" },
} :: { [string]: Product }

Monetization.StarterPack = { Coins = 1500, Gems = 150, Skin = "Aurora" }

-- "Buy with R$": one product per weapon that has a RobuxPrice. Fill the ids in
-- after creating them (named "Unlock <weapon name>").
Monetization.WeaponProductIds = {
	Starfall = 3720864947,
	BoomPaw = 3720865093,
	RapidPaw = 3720864796,
	FrostBlaster = 3720865268,
	VoidCannon = 3720865394,
	BubbleBlaster = 3720864623,
	GoldenPurr = 3720865963,
	CometClaw = 3720865580,
	PurrfectStorm = 3720865744,
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
