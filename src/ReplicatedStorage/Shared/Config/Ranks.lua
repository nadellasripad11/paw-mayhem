--!strict
-- Ranks: trophy ranking. Every match moves your trophies (win or lose, plus a
-- little for each knockout) and your tier shows in the menu, on the results
-- screen and on the TROPHIES leaderboard.

local Ranks = {}

Ranks.Tiers = {
	{ Name = "Kitten", Min = 0, Color = Color3.fromRGB(200, 200, 210) },
	{ Name = "Bronze", Min = 100, Color = Color3.fromRGB(214, 140, 90) },
	{ Name = "Silver", Min = 300, Color = Color3.fromRGB(200, 214, 230) },
	{ Name = "Gold", Min = 600, Color = Color3.fromRGB(255, 206, 80) },
	{ Name = "Platinum", Min = 1000, Color = Color3.fromRGB(120, 230, 220) },
	{ Name = "Diamond", Min = 1500, Color = Color3.fromRGB(130, 180, 255) },
	{ Name = "Legend", Min = 2200, Color = Color3.fromRGB(255, 120, 200) },
}

Ranks.Win = 20 -- trophies for winning a match
Ranks.Loss = -8 -- trophies for losing one (never below 0)
Ranks.PerKnockout = 2
Ranks.MaxKnockoutBonus = 10

-- Trophies earned in one match.
function Ranks.Delta(won: boolean, knockouts: number): number
	return (won and Ranks.Win or Ranks.Loss) + math.min(knockouts * Ranks.PerKnockout, Ranks.MaxKnockoutBonus)
end

-- The tier for a trophy count.
function Ranks.For(trophies: number): any
	local tier = Ranks.Tiers[1]
	for _, t in ipairs(Ranks.Tiers) do
		if trophies >= t.Min then
			tier = t
		end
	end
	return tier
end

return Ranks
