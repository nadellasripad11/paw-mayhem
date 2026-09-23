--!strict
-- Season: the season pass. Earn Season XP by playing; every tier has a free
-- reward and a premium reward (premium needs the Season Pass game pass).
-- Season-exclusive items carry `Season = 1` in their config and can only be
-- earned here.

local Season = {}

Season.Id = 1
Season.Name = "SEASON 1: SKY PAWS"
Season.Tiers = 30
Season.XPPerTier = 300

-- Season XP per action.
Season.XP = {
	MatchPlayed = 60,
	Win = 90,
	Elimination = 20,
	Ringout = 10,
	DailyClaim = 40,
}

-- kind: Coins | Gems | Fur | Skin | Hat | Outfit | Accessory | Emote
local function r(kind: string, value: any)
	return { Kind = kind, Amount = typeof(value) == "number" and value or nil, Id = typeof(value) == "string" and value or nil }
end

Season.Rewards = {
	[1] = { Free = r("Coins", 150), Premium = r("Gems", 30) },
	[2] = { Free = r("Coins", 150), Premium = r("Coins", 400) },
	[3] = { Free = r("Gems", 10), Premium = r("Skin", "Sakura") },
	[4] = { Free = r("Coins", 200), Premium = r("Gems", 40) },
	[5] = { Free = r("Hat", "Beanie"), Premium = r("Coins", 600) },
	[6] = { Free = r("Coins", 200), Premium = r("Gems", 40) },
	[7] = { Free = r("Gems", 15), Premium = r("Coins", 600) },
	[8] = { Free = r("Coins", 250), Premium = r("Gems", 50) },
	[9] = { Free = r("Coins", 250), Premium = r("Coins", 700) },
	[10] = { Free = r("Fur", "Sakura"), Premium = r("Fur", "Midnight") },
	[11] = { Free = r("Coins", 300), Premium = r("Gems", 50) },
	[12] = { Free = r("Gems", 20), Premium = r("Coins", 800) },
	[13] = { Free = r("Coins", 300), Premium = r("Gems", 60) },
	[14] = { Free = r("Coins", 300), Premium = r("Emote", "Celebrate") },
	[15] = { Free = r("Gems", 25), Premium = r("Skin", "Glitch") },
	[16] = { Free = r("Coins", 350), Premium = r("Gems", 60) },
	[17] = { Free = r("Coins", 350), Premium = r("Coins", 900) },
	[18] = { Free = r("Gems", 25), Premium = r("Gems", 70) },
	[19] = { Free = r("Coins", 400), Premium = r("Coins", 1000) },
	[20] = { Free = r("Skin", "Ocean"), Premium = r("Outfit", "Space") },
	[21] = { Free = r("Coins", 400), Premium = r("Gems", 80) },
	[22] = { Free = r("Gems", 30), Premium = r("Coins", 1100) },
	[23] = { Free = r("Coins", 450), Premium = r("Gems", 80) },
	[24] = { Free = r("Coins", 450), Premium = r("Coins", 1200) },
	[25] = { Free = r("Gems", 35), Premium = r("Hat", "Crown") },
	[26] = { Free = r("Coins", 500), Premium = r("Gems", 90) },
	[27] = { Free = r("Coins", 500), Premium = r("Coins", 1400) },
	[28] = { Free = r("Gems", 40), Premium = r("Gems", 100) },
	[29] = { Free = r("Coins", 600), Premium = r("Coins", 1600) },
	[30] = { Free = r("Gems", 60), Premium = r("Skin", "Starlight") },
}

function Season.TierFor(xp: number): number
	return math.clamp(math.floor(xp / Season.XPPerTier), 0, Season.Tiers)
end

return Season
