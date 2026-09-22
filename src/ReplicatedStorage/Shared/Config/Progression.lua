--!strict
-- Progression: XP curve, level rewards, daily quests, power-up defs.

local Progression = {}

-- XP required to advance FROM the given level to the next.
-- Smooth quadratic-ish curve; level 1 -> 2 costs 1000, scaling up.
function Progression.XpForLevel(level: number): number
	if level < 1 then
		return 1000
	end
	return math.floor(800 + (level * 200) + (level * level * 12))
end

-- Total XP accumulated to reach a level (for progress bars).
function Progression.TotalXpToReach(level: number): number
	local total = 0
	for l = 1, level - 1 do
		total += Progression.XpForLevel(l)
	end
	return total
end

-- Given lifetime XP, return level + progress within current level.
function Progression.Resolve(totalXp: number): (number, number, number)
	local level = 1
	local remaining = totalXp
	while remaining >= Progression.XpForLevel(level) do
		remaining -= Progression.XpForLevel(level)
		level += 1
		if level > 500 then
			break
		end
	end
	return level, remaining, Progression.XpForLevel(level)
end

-- Coins granted when hitting a level milestone.
function Progression.LevelUpCoins(level: number): number
	return 50 + level * 10
end

-- Daily quest templates. The server rolls 3 per day from this pool.
Progression.QuestPool = {
	{ Id = "elim10", Text = "Get %d Eliminations", Metric = "eliminations", Target = 10, Coins = 250 },
	{ Id = "play3", Text = "Play %d Matches", Metric = "matches", Target = 3, Coins = 150 },
	{ Id = "dmg2000", Text = "Deal %d Damage", Metric = "damage", Target = 2000, Coins = 250 },
	{ Id = "launch5", Text = "Launch %d cats off the map", Metric = "ringouts", Target = 5, Coins = 300 },
	{ Id = "win2", Text = "Win %d Matches", Metric = "wins", Target = 2, Coins = 400 },
	{ Id = "power3", Text = "Grab %d Power-ups", Metric = "powerups", Target = 3, Coins = 200 },
}

Progression.DailyQuestCount = 3

-- Power-ups (mirrors the reference sheet). Effects are applied server-side.
Progression.PowerUps = {
	{ Id = "RapidFire", Name = "Rapid Fire", Color = Color3.fromRGB(90, 180, 255), FireRateMult = 2.0 },
	{ Id = "MegaKnockback", Name = "Mega Knockback", Color = Color3.fromRGB(255, 90, 70), KnockbackMult = 2.2 },
	{ Id = "Shield", Name = "Shield", Color = Color3.fromRGB(90, 220, 130), DamageResist = 0.5, KnockbackResist = 0.6 },
	{ Id = "SpeedBoost", Name = "Speed Boost", Color = Color3.fromRGB(255, 200, 80), SpeedMult = 1.5 },
	{ Id = "MultiShot", Name = "Multi Shot", Color = Color3.fromRGB(170, 120, 255), ExtraPellets = 2, SpreadAdd = 4 },
}

Progression.PowerUpById = {}
for _, p in ipairs(Progression.PowerUps) do
	Progression.PowerUpById[p.Id] = p
end

return Progression
