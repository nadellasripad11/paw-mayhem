--!strict
-- runtime: shared, mutable per-player combat state for the current match.
-- kept dependency-free so any service can read/write it without circular
-- requires. reset each life / match as appropriate.

local Runtime = {}

export type PlayerState = {
	Team: string?, -- team id ("blue"/"red")
	Alive: boolean,
	Accumulated: number, -- fluff damage taken this life (drives knockback)
	LastAttacker: Player?, -- for ringout kill credit
	LastBot: any?, -- {name, team} of the bot that hit this player last
	LastBotAt: number?,
	LastAttackAt: number, -- os.clock() of last hit taken
	SlowUntil: number, -- status: slowed movement until this os.clock()
	StunUntil: number, -- launch stun window end
	PowerUp: { Id: string, Expires: number }?, -- active power-up
	MatchElims: number, -- eliminations this match (for scoreboard)
	MatchScore: number, -- points this match
	SpawnProtectUntil: number, -- brief invuln after spawn
	Streak: number, -- eliminations since last death (kill streak)
	WeaponOverride: string?, -- supply-drop weapon held for the rest of this life
	LifeWeapon: string?, -- the loadout blaster this life spawned with
	SpawnedAt: number?, -- os.clock() of the last spawn (loadout changes apply at once shortly after)
	Context: string?, -- where the cat is: "lobby" | "match" | "duel"
	DuelId: number?, -- which duel (context "duel")
	DuelTeam: string?, -- side in that duel
}

Runtime.States = {} :: { [Player]: PlayerState }

-- true during the final-seconds mayhem mode (double knockback, drop rain).
Runtime.Mayhem = false

function Runtime.Ensure(player: Player): PlayerState
	local s = Runtime.States[player]
	if not s then
		s = {
			Team = nil,
			Alive = false,
			Accumulated = 0,
			LastAttacker = nil,
			LastAttackAt = 0,
			SlowUntil = 0,
			StunUntil = 0,
			PowerUp = nil,
			MatchElims = 0,
			MatchScore = 0,
			SpawnProtectUntil = 0,
			Streak = 0,
			WeaponOverride = nil,
			Context = nil,
			DuelId = nil,
			DuelTeam = nil,
		}
		Runtime.States[player] = s
	end
	return s
end

function Runtime.Get(player: Player): PlayerState?
	-- current game mode ("tdm" | "ffa" | "koth" | "ringout") and the king of the
-- hill centre, read by combat + bots.
Runtime.Mode = "TDM"
Runtime.HillPos = nil :: Vector3?

-- the most recent knockout in the match (matchservice turns it into the
-- final knockout moment when it ends the match).
Runtime.LastKO = nil :: { t: number, position: Vector3 }?

return Runtime.States[player]
end

-- where a player is now (mirrored as the player's "context" attribute so the
-- client can switch between lobby and match screens).
function Runtime.SetContext(player: Player, context: string?, duelId: number?, duelTeam: string?)
	local s = Runtime.Ensure(player)
	s.Context = context
	s.DuelId = duelId
	s.DuelTeam = duelTeam
	player:SetAttribute("Context", context)
end

-- same place and able to hurt each other: same match, or opposite sides of
-- the same duel. nobody gets hurt in the lobby.
function Runtime.CanHit(a: Player, b: Player): boolean
	local sa, sb = Runtime.Get(a), Runtime.Get(b)
	if not sa or not sb or sa.Context ~= sb.Context then
		return false
	end
	if sa.Context == "Duel" then
		return sa.DuelId == sb.DuelId and sa.DuelTeam ~= sb.DuelTeam
	end
	return sa.Context == "Match"
end

function Runtime.Remove(player: Player)
	Runtime.States[player] = nil
end

-- reset per-life fields (called on spawn).
function Runtime.ResetLife(player: Player)
	local s = Runtime.Ensure(player)
	s.Accumulated = 0
	s.LastAttacker = nil
	s.LastAttackAt = 0
	s.SlowUntil = 0
	s.StunUntil = 0
	s.Streak = 0
	s.WeaponOverride = nil
end

-- reset per-match fields.
function Runtime.ResetMatch(player: Player)
	local s = Runtime.Ensure(player)
	s.MatchElims = 0
	s.MatchScore = 0
	Runtime.ResetLife(player)
end

return Runtime
