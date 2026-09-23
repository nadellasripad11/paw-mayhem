--!strict
-- Weapons: original blaster definitions for PAW MAYHEM.
-- Each weapon has a distinct gameplay identity via fire rate, knockback,
-- range, spread (accuracy) and cooldown. Knockback is expressed as a
-- multiplier applied on top of GameConfig.Knockback so weapons feel different
-- while sharing one physics model.

export type WeaponDef = {
	Id: string,
	Name: string,
	Rarity: string,
	Class: string, -- Balanced / Epic / Heavy / Fast / Ice / Legendary / Fun / Premium
	Damage: number, -- "fluff" damage that builds knockback scaling
	FireRate: number, -- shots per second
	Knockback: number, -- multiplier vs base knockback impulse
	Range: number, -- studs before the shot expires
	Spread: number, -- degrees of random cone (lower = more accurate)
	Pellets: number, -- projectiles per trigger pull (shotgun-style)
	ProjectileSpeed: number, -- studs/sec (0 = hitscan)
	MuzzleColor: Color3,
	TrailColor: Color3,
	-- UI stat bars are 0..1 normalised for the loadout screen.
	Bars: { Damage: number, FireRate: number, Knockback: number, Range: number, Accuracy: number },
	UnlockLevel: number,
	CoinCost: number,
}

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Weapons = {}

Weapons.List = {
	{
		Id = "PawBlaster", Name = "Paw Blaster", Rarity = "Common", Class = "Balanced", Icon = "Gun",
		Damage = 14, FireRate = 4.0, Knockback = 1.0, Range = 180, Spread = 2.2, Pellets = 1,
		ProjectileSpeed = 320, MuzzleColor = c(150, 220, 90), TrailColor = c(180, 120, 255),
		Bars = { Damage = 0.5, FireRate = 0.6, Knockback = 0.5, Range = 0.6, Accuracy = 0.7 },
		UnlockLevel = 0, CoinCost = 0,
	},
	{
		Id = "Starfall", Name = "Starfall", Rarity = "Epic", Class = "Epic", Icon = "GunSniper",
		Damage = 20, FireRate = 3.0, Knockback = 1.3, Range = 220, Spread = 1.4, Pellets = 1,
		ProjectileSpeed = 340, MuzzleColor = c(120, 180, 255), TrailColor = c(120, 160, 255),
		Bars = { Damage = 0.7, FireRate = 0.45, Knockback = 0.7, Range = 0.75, Accuracy = 0.85 },
		UnlockLevel = 4, CoinCost = 800, RobuxPrice = 99,
	},
	{
		Id = "BoomPaw", Name = "Boom Paw", Rarity = "Rare", Class = "Heavy", Icon = "GunHeavy",
		Damage = 34, FireRate = 1.1, Knockback = 2.2, Range = 130, Spread = 3.0, Pellets = 1,
		ProjectileSpeed = 240, MuzzleColor = c(255, 140, 40), TrailColor = c(255, 120, 40),
		Bars = { Damage = 0.95, FireRate = 0.2, Knockback = 1.0, Range = 0.45, Accuracy = 0.5 },
		UnlockLevel = 6, CoinCost = 1200, RobuxPrice = 129,
	},
	{
		Id = "RapidPaw", Name = "Rapid Paw", Rarity = "Rare", Class = "Fast", Icon = "GunFast",
		Damage = 8, FireRate = 9.0, Knockback = 0.6, Range = 150, Spread = 3.6, Pellets = 1,
		ProjectileSpeed = 360, MuzzleColor = c(255, 110, 230), TrailColor = c(230, 110, 255),
		Bars = { Damage = 0.3, FireRate = 1.0, Knockback = 0.3, Range = 0.5, Accuracy = 0.4 },
		UnlockLevel = 3, CoinCost = 700, RobuxPrice = 79,
	},
	{
		Id = "FrostBlaster", Name = "Frost Blaster", Rarity = "Rare", Class = "Ice", Icon = "GunIce",
		Damage = 12, FireRate = 3.5, Knockback = 1.1, Range = 170, Spread = 2.0, Pellets = 1,
		ProjectileSpeed = 300, MuzzleColor = c(120, 220, 255), TrailColor = c(150, 230, 255),
		-- Slows the target briefly (handled server-side as a status effect).
		SlowFactor = 0.6, SlowSeconds = 1.2,
		Bars = { Damage = 0.45, FireRate = 0.55, Knockback = 0.55, Range = 0.6, Accuracy = 0.75 },
		UnlockLevel = 8, CoinCost = 1500, RobuxPrice = 149,
	},
	{
		Id = "VoidCannon", Name = "Void Cannon", Rarity = "Legendary", Class = "Legendary", Icon = "GunCannon",
		Damage = 42, FireRate = 0.9, Knockback = 2.8, Range = 240, Spread = 1.2, Pellets = 1,
		ProjectileSpeed = 260, MuzzleColor = c(170, 90, 255), TrailColor = c(150, 70, 255),
		Bars = { Damage = 1.0, FireRate = 0.15, Knockback = 1.0, Range = 0.85, Accuracy = 0.9 },
		UnlockLevel = 12, CoinCost = 3000, RobuxPrice = 249,
	},
	{
		Id = "BubbleBlaster", Name = "Bubble Blaster", Rarity = "Uncommon", Class = "Fun", Icon = "GunBubble",
		Damage = 10, FireRate = 5.0, Knockback = 0.9, Range = 120, Spread = 6.0, Pellets = 3,
		ProjectileSpeed = 220, MuzzleColor = c(150, 230, 255), TrailColor = c(255, 180, 240),
		Bars = { Damage = 0.4, FireRate = 0.7, Knockback = 0.45, Range = 0.4, Accuracy = 0.3 },
		UnlockLevel = 2, CoinCost = 500, RobuxPrice = 49,
	},
	{
		Id = "GoldenPurr", Name = "Golden Purr", Rarity = "Mythic", Class = "Premium", Icon = "GunGolden",
		Damage = 26, FireRate = 4.5, Knockback = 1.6, Range = 200, Spread = 1.0, Pellets = 1,
		ProjectileSpeed = 360, MuzzleColor = c(255, 210, 90), TrailColor = c(255, 200, 80),
		Bars = { Damage = 0.8, FireRate = 0.7, Knockback = 0.8, Range = 0.8, Accuracy = 0.95 },
		UnlockLevel = 20, CoinCost = 6000, RobuxPrice = 399,
	},
	-- Exclusives: gems or Robux only (sidegrades, never stronger than Golden Purr).
	{
		Id = "CometClaw", Name = "Comet Claw", Rarity = "Mythic", Class = "Exclusive", Icon = "GunSniper",
		Damage = 22, FireRate = 3.2, Knockback = 1.4, Range = 230, Spread = 1.2, Pellets = 1,
		ProjectileSpeed = 380, MuzzleColor = c(140, 230, 255), TrailColor = c(120, 200, 255),
		Bars = { Damage = 0.72, FireRate = 0.5, Knockback = 0.72, Range = 0.9, Accuracy = 0.92 },
		UnlockLevel = 0, CoinCost = 0, GemCost = 450, RobuxPrice = 299, Exclusive = true,
	},
	{
		Id = "PurrfectStorm", Name = "Purrfect Storm", Rarity = "Mythic", Class = "Exclusive", Icon = "GunFast",
		Damage = 11, FireRate = 7.5, Knockback = 0.85, Range = 170, Spread = 2.6, Pellets = 1,
		ProjectileSpeed = 360, MuzzleColor = c(210, 150, 255), TrailColor = c(170, 110, 255),
		Bars = { Damage = 0.4, FireRate = 0.95, Knockback = 0.45, Range = 0.6, Accuracy = 0.55 },
		UnlockLevel = 0, CoinCost = 0, GemCost = 450, RobuxPrice = 299, Exclusive = true,
	},
}

-- Cosmetic skins (recolor/aura only — never affect stats). Applied by id.
Weapons.Skins = {
	{ Id = "Default", Name = "Default", Tint = c(235, 235, 245), CoinCost = 0 },
	{ Id = "Ocean", Name = "Ocean", Tint = c(90, 170, 255), CoinCost = 300 },
	{ Id = "Inferno", Name = "Inferno", Tint = c(255, 90, 60), CoinCost = 300 },
	{ Id = "Golden", Name = "Golden", Tint = c(255, 205, 90), CoinCost = 1000 },
	{ Id = "Galaxy", Name = "Galaxy", Tint = c(150, 90, 255), CoinCost = 800 },
	{ Id = "Neon", Name = "Neon", Tint = c(120, 255, 200), CoinCost = 800 },
	{ Id = "Candy", Name = "Candy", Tint = c(255, 150, 220), CoinCost = 500 },
	{ Id = "Void", Name = "Void", Tint = c(120, 70, 200), CoinCost = 1200 },
	-- Gem-only and pass-only skins.
	{ Id = "Aurora", Name = "Aurora", Tint = c(90, 230, 200), CoinCost = 0, GemCost = 120 },
	{ Id = "Molten", Name = "Molten", Tint = c(255, 110, 40), CoinCost = 0, GemCost = 120 },
	{ Id = "VIPGold", Name = "VIP Gold", Tint = c(255, 206, 60), CoinCost = 0, PassOnly = "VIP" },
}

local byId: { [string]: WeaponDef } = {}
for _, w in ipairs(Weapons.List) do
	byId[w.Id] = w :: any
end

function Weapons.Get(id: string): WeaponDef?
	return byId[id]
end

function Weapons.GetSkin(id: string)
	for _, s in ipairs(Weapons.Skins) do
		if s.Id == id then
			return s
		end
	end
	return Weapons.Skins[1]
end

Weapons.DefaultLoadout = "PawBlaster"

return Weapons
