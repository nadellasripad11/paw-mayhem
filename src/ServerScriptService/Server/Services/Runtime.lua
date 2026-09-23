--!strict
-- Runtime: shared, mutable per-player combat state for the current match.
-- Kept dependency-free so any service can read/write it without circular
-- requires. Reset each life / match as appropriate.

local Runtime = {}

export type PlayerState = {
	Team: string?, -- team id ("Blue"/"Red")
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
}

Runtime.States = {} :: { [Player]: PlayerState }

-- True during the final-seconds Mayhem Mode (double knockback, drop rain).
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
		}
		Runtime.States[player] = s
	end
	return s
end

function Runtime.Get(player: Player): PlayerState?
	-- Current game mode ("TDM" | "FFA" | "KOTH" | "Ringout") and the King of the
-- Hill centre, read by combat + bots.
Runtime.Mode = "TDM"
Runtime.HillPos = nil :: Vector3?

return Runtime.States[player]
end

function Runtime.Remove(player: Player)
	Runtime.States[player] = nil
end

-- Reset per-life fields (called on spawn).
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

-- Reset per-match fields.
function Runtime.ResetMatch(player: Player)
	local s = Runtime.Ensure(player)
	s.MatchElims = 0
	s.MatchScore = 0
	Runtime.ResetLife(player)
end

return Runtime
