--!strict
-- gameconfig: top-level match & gameplay tuning for paw mayhem.
-- all numbers here are server-authoritative defaults. client reads them for
-- prediction/ui only; the server never trusts client-sent values.

local GameConfig = {}

GameConfig.GameName = "PAW MAYHEM"

-- match flow -----------------------------------------------------------------
GameConfig.Match = {
	MinPlayersToStart = 1, -- allow solo testing in studio
	IntermissionSeconds = 20,
	CountdownSeconds = 3,
	MatchSeconds = 180, -- 3:00 like the reference hud
	ResultsSeconds = 15, -- (the final score + winner reveal take ~7s)
	ScoreToWin = 40, -- team score that ends the match early
	Teams = {
		{ Id = "Blue", Name = "Blue Paws", Color = Color3.fromRGB(64, 132, 255) },
		{ Id = "Red", Name = "Red Claws", Color = Color3.fromRGB(255, 82, 82) },
	},
}

-- scoring --------------------------------------------------------------------
GameConfig.Scoring = {
	EliminationTeamPoints = 1,
	EliminationXP = 100,
	EliminationCoins = 15,
	AssistXP = 35,
	MatchPlayedXP = 40,
	WinBonusXP = 120,
	WinBonusCoins = 60,
	CaptureXP = 150, -- capture the flag: bringing the flag home
	CaptureCoins = 40,
	-- each win in a row after the first adds this much to the win coins, up to
	-- winstreakmaxsteps times (+50%).
	WinStreakBonus = 0.1,
	WinStreakMaxSteps = 5,
}

-- character / movement -------------------------------------------------------
GameConfig.Character = {
	WalkSpeed = 18,
	SprintSpeed = 28,
	JumpPower = 55,
	Health = 100,
	RespawnDelay = 1.5, -- fast, chaotic respawns
	-- a player is "eliminated" when they fall below this y in the arena.
	KillFloorY = -120,
	-- hits mostly build knockback %; only this fraction of a blaster's damage
	-- comes off hp, so most knockouts are cats sent flying off the map.
	HealthDamageScale = 0.35,
}

-- knockback model (the defining mechanic) ------------------------------------
-- effective knockback scales with accumulated "fluff" damage a target has
-- taken this life, similar to a certain party fighter: the more they've been
-- hit, the further they fly. this rewards sustained pressure + a finisher.
GameConfig.Knockback = {
	-- launch speed (studs/s) for a 1x weapon at knockback % f:
	--   base + linear * f + curve * f^2   (0% ~34, 50% ~68, 100% ~109,
	--   150% ~158, 200% ~214), never more than maxspeed.
	Base = 34,
	Linear = 0.6,
	Curve = 0.0015,
	MaxSpeed = 300,
	-- launch angle (share of the push that goes upward): uplow at 0%,
	-- rising to uphigh by steepat %. aimtilt: how much aiming up/down tilts it.
	UpLow = 0.18,
	UpHigh = 0.55,
	SteepAt = 120,
	AimTilt = 0.15,
	-- hitstun: stunmin seconds plus a bit per studs/s of launch, capped.
	StunMin = 0.12,
	StunPerSpeed = 0.0022,
	StunMax = 0.6,
	-- back-to-back hits stack: this much of your current flight is kept when
	-- the next hit lands (rapid-fire pushes you along instead of juggling you).
	Stack = 0.45,
	MassReference = 14, -- a standard cat's mass, if a rig has no root yet
	DecayPerSecond = 0, -- knockback % does not decay mid-life
}

GameConfig.Camera = {
	ThirdPersonDistance = 12,
	MinDistance = 8,
	MaxDistance = 16,
	FieldOfView = 74,
	Sensitivity = 0.35,
	ShoulderOffset = Vector3.new(2.2, 1.2, 0),
}

-- power-ups ------------------------------------------------------------------
GameConfig.PowerUps = {
	SpawnInterval = 12,
	Duration = 10,
	RespawnAfterPickup = 22,
}

-- sky supply drops + fish snacks (dropservice) --------------------------------
GameConfig.Drops = {
	FirstDelay = 20, -- seconds into a match before the first crate
	Interval = 24,
	IntervalJitter = 6,
	MayhemInterval = 8, -- crates rain down in the final mayhem mode
	FallTime = 7, -- seconds from appearing in the sky to landing
	DropHeight = 140,
	Lifetime = 45, -- an untouched crate vanishes after this
	GrabRadius = 5,
	LegendaryWeapons = { "VoidCannon", "GoldenPurr", "Starfall", "BoomPaw" },
	-- roll weights for what a crate gives.
	Rewards = { Weapon = 30, Overdrive = 30, Heal = 25, Coins = 15 },
	CoinsMin = 60,
	CoinsMax = 150,
	OverdriveSeconds = 15,
	ShieldSeconds = 12,
}

GameConfig.Snacks = {
	Interval = 16,
	MaxActive = 4,
	Heal = 40,
	FluffCut = 30, -- knockback damage removed by eating one
	GrabRadius = 4,
}

-- health slowly returns once you've stopped taking hits.
GameConfig.Regen = {
	Delay = 5,
	PerSecond = 6,
}

-- dash + double jump (client-driven movement) -------------------------------
GameConfig.Movement = {
	DashSpeed = 78,
	DashTime = 0.18,
	DashCooldown = 2.5,
	DoubleJumpSpeed = 50,
	WallJumpUp = 52, -- kick off a wall: up speed ...
	WallJumpOut = 40, -- ... and speed away from the wall
	PounceUp = 38, -- pounce: a low forward leap
	PounceSpeed = 58,
	PounceCooldown = 3,
	-- airborne momentum after a hit's burst / an air dash: how much of the
	-- velocity carries on, and how fast it eases off (per second).
	KnockbackCarry = 0.75,
	DashCarry = 0.5,
	AirDrag = 1.4,
}

-- kill streaks + bounties -----------------------------------------------------
GameConfig.Streaks = {
	OnFire = 3, -- eliminations in a row to go "on fire" (and carry a bounty)
	BountyCoinsPerKill = 25, -- per streak kill beyond the threshold, paid to whoever ends it
	BountyXP = 60,
}

-- map events (eruption / wind / stampede) ------------------------------------
GameConfig.Events = {
	FirstDelay = 50,
	Interval = 60,
}

-- final-seconds mayhem mode ----------------------------------------------------
GameConfig.Mayhem = {
	Seconds = 30,
	KnockbackMult = 2,
}


GameConfig.DataStore = {
	Name = "PawMayhem_Player_v1",
	AutoSaveSeconds = 120,
	MaxRetries = 5,
}

return GameConfig
