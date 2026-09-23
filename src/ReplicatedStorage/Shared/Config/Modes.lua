--!strict
-- Modes: the game modes players can vote for in the map picker.
--   TDM      Team Deathmatch: eliminations score for your team.
--   FFA      Free For All: everyone is an enemy; first cat to the target wins.
--   KOTH     King of the Hill: stand in the glowing hill to score each second.
--   Ringout  Blasters do no damage, only knockback: knock cats off the map.

local Modes = {}

Modes.List = {
	{ Id = "TDM", Name = "Team Deathmatch", Short = "TEAM DEATHMATCH", Rules = "FIRST TO 40", ScoreToWin = 40, KillPoints = 1, Color = Color3.fromRGB(80, 170, 255) },
	{ Id = "FFA", Name = "Free For All", Short = "FREE FOR ALL", Rules = "FIRST TO 15 KOs", ScoreToWin = 15, KillPoints = 1, Color = Color3.fromRGB(255, 120, 90) },
	{ Id = "KOTH", Name = "King of the Hill", Short = "KING OF THE HILL", Rules = "HOLD THE HILL • 100 PTS", ScoreToWin = 100, KillPoints = 0, Color = Color3.fromRGB(255, 205, 70) },
	{ Id = "Ringout", Name = "Ringout", Short = "RINGOUT", Rules = "KNOCKBACK ONLY • FIRST TO 30", ScoreToWin = 30, KillPoints = 1, Color = Color3.fromRGB(190, 120, 255) },
}

Modes.ById = {}
for _, m in ipairs(Modes.List) do
	Modes.ById[m.Id] = m
end

Modes.Default = "TDM"

function Modes.Get(id: string?): any
	return Modes.ById[id or ""] or Modes.ById[Modes.Default]
end

return Modes
