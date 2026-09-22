--!strict
-- Cats: base cat roster + customization catalog for PAW MAYHEM.
-- Cats are purely cosmetic (never pay-to-win). Each entry drives a procedural
-- R15-scaled cat model built at runtime by Shared/Character/CatBuilder.

local function c(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local Cats = {}

-- Fur variations (base body color + accent). Names mirror the design sheet
-- but colors/values are original tuning for this game.
Cats.Fur = {
	{ Id = "Orange", Name = "Orange", Desc = "Default", Body = c(240, 150, 70), Accent = c(255, 200, 140), UnlockLevel = 0, CoinCost = 0 },
	{ Id = "Black", Name = "Black", Desc = "Stealth", Body = c(45, 45, 55), Accent = c(90, 90, 110), UnlockLevel = 0, CoinCost = 200 },
	{ Id = "White", Name = "White", Desc = "Fluffy", Body = c(245, 245, 245), Accent = c(210, 215, 230), UnlockLevel = 0, CoinCost = 200 },
	{ Id = "Gray", Name = "Gray", Desc = "Cool", Body = c(150, 155, 165), Accent = c(110, 115, 130), UnlockLevel = 2, CoinCost = 300 },
	{ Id = "Blue", Name = "Blue", Desc = "Sporty", Body = c(120, 170, 240), Accent = c(90, 130, 210), UnlockLevel = 3, CoinCost = 400 },
	{ Id = "Purple", Name = "Purple", Desc = "Mystic", Body = c(170, 130, 230), Accent = c(140, 100, 210), UnlockLevel = 5, CoinCost = 600 },
	{ Id = "Calico", Name = "Calico", Desc = "Trendy", Body = c(235, 180, 130), Accent = c(120, 80, 60), UnlockLevel = 7, CoinCost = 800 },
	{ Id = "Tiger", Name = "Tiger", Desc = "Wild", Body = c(240, 150, 60), Accent = c(60, 45, 40), UnlockLevel = 10, CoinCost = 1200 },
}

-- Outfits (torso/limb overlay color + tag).
Cats.Outfits = {
	{ Id = "None", Name = "None", Color = c(200, 200, 200), UnlockLevel = 0, CoinCost = 0 },
	{ Id = "Hoodie", Name = "Hoodie", Color = c(60, 65, 80), UnlockLevel = 0, CoinCost = 250 },
	{ Id = "Streetwear", Name = "Streetwear", Color = c(40, 90, 120), UnlockLevel = 2, CoinCost = 400 },
	{ Id = "Robot", Name = "Robot", Color = c(150, 160, 175), UnlockLevel = 6, CoinCost = 900 },
	{ Id = "Ninja", Name = "Ninja", Color = c(30, 30, 38), UnlockLevel = 8, CoinCost = 1100 },
	{ Id = "Royal", Name = "Royal", Color = c(120, 60, 160), UnlockLevel = 12, CoinCost = 1800 },
	{ Id = "Space", Name = "Space", Color = c(220, 230, 245), UnlockLevel = 15, CoinCost = 2500 },
}

-- Hats / head accessories (procedural shapes drawn by CatBuilder).
Cats.Hats = {
	{ Id = "None", Name = "None", Shape = "None", Color = c(255, 255, 255), UnlockLevel = 0, CoinCost = 0 },
	{ Id = "Cap", Name = "Cap", Shape = "Cap", Color = c(70, 130, 220), UnlockLevel = 0, CoinCost = 150 },
	{ Id = "Beanie", Name = "Beanie", Shape = "Beanie", Color = c(210, 90, 90), UnlockLevel = 1, CoinCost = 250 },
	{ Id = "Crown", Name = "Crown", Shape = "Crown", Color = c(255, 205, 90), UnlockLevel = 12, CoinCost = 2000 },
	{ Id = "Space", Name = "Space Helmet", Shape = "Helmet", Color = c(200, 230, 255), UnlockLevel = 15, CoinCost = 2500 },
}

-- Accessories (face/back items).
Cats.Accessories = {
	{ Id = "None", Name = "None", Shape = "None", Color = c(255, 255, 255), UnlockLevel = 0, CoinCost = 0 },
	{ Id = "Sunglasses", Name = "Sunglasses", Shape = "Glasses", Color = c(30, 30, 35), UnlockLevel = 0, CoinCost = 200 },
	{ Id = "Backpack", Name = "Backpack", Shape = "Backpack", Color = c(120, 90, 60), UnlockLevel = 4, CoinCost = 500 },
	{ Id = "Jetpack", Name = "Jetpack", Shape = "Jetpack", Color = c(150, 160, 180), UnlockLevel = 9, CoinCost = 1400 },
}

-- Emotes (client-side anim triggers; ids referenced by the emote wheel).
Cats.Emotes = {
	{ Id = "Happy", Name = "Happy", UnlockLevel = 0, CoinCost = 0 },
	{ Id = "Sit", Name = "Sit", UnlockLevel = 0, CoinCost = 0 },
	{ Id = "Wave", Name = "Wave", UnlockLevel = 0, CoinCost = 100 },
	{ Id = "Laugh", Name = "Laugh", UnlockLevel = 2, CoinCost = 200 },
	{ Id = "Celebrate", Name = "Celebrate", UnlockLevel = 3, CoinCost = 200 },
	{ Id = "Sleep", Name = "Sleep", UnlockLevel = 4, CoinCost = 300 },
	{ Id = "Spin", Name = "Spin", UnlockLevel = 5, CoinCost = 300 },
	{ Id = "Fall", Name = "Fall", UnlockLevel = 6, CoinCost = 300 },
}

Cats.Default = {
	Fur = "Orange",
	Outfit = "Hoodie",
	Hat = "None",
	Accessory = "None",
	Emote = "Happy",
}

-- Lookup helpers -------------------------------------------------------------
local function indexBy(list)
	local t = {}
	for _, v in ipairs(list) do
		t[v.Id] = v
	end
	return t
end

Cats.FurById = indexBy(Cats.Fur)
Cats.OutfitById = indexBy(Cats.Outfits)
Cats.HatById = indexBy(Cats.Hats)
Cats.AccessoryById = indexBy(Cats.Accessories)
Cats.EmoteById = indexBy(Cats.Emotes)

return Cats
