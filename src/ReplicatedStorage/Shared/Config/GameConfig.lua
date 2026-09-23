--!strict
-- GameConfig: top-level match & gameplay tuning for PAW MAYHEM.
-- All numbers here are server-authoritative defaults. Client reads them for
-- prediction/UI only; the server never trusts client-sent values.

local GameConfig = {}

GameConfig.GameName = "PAW MAYHEM"

-- Match flow -----------------------------------------------------------------
GameConfig.Match = {
	MinPlayersToStart = 1, -- allow solo testing in Studio
	IntermissionSeconds = 20,
	CountdownSeconds = 3,
	MatchSeconds = 180, -- 3:00 like the reference HUD
	ResultsSeconds = 10,
	ScoreToWin = 40, -- team score that ends the match early
	Teams = {
		{ Id = "Blue", Name = "Blue Paws", Color = Color3.fromRGB(64, 132, 255) },
		{ Id = "Red", Name = "Red Claws", Color = Color3.fromRGB(255, 82, 82) },
	},
}

-- Scoring --------------------------------------------------------------------
GameConfig.Scoring = {
	EliminationTeamPoints = 1,
	EliminationXP = 100,
	EliminationCoins = 15,
	AssistXP = 35,
	MatchPlayedXP = 40,
	WinBonusXP = 120,
	WinBonusCoins = 60,
}

-- Character / movement -------------------------------------------------------
GameConfig.Character = {
	WalkSpeed = 18,
	SprintSpeed = 28,
	JumpPower = 55,
	Health = 100,
	RespawnDelay = 3.0,
	-- A player is "eliminated" when they fall below this Y in the arena.
	KillFloorY = -120,
	-- Ragdoll-ish launch: how long control is reduced after a big hit.
	LaunchStunSeconds = 0.35,
}

-- Knockback model (the defining mechanic) ------------------------------------
-- Effective knockback scales with accumulated "fluff" damage a target has
-- taken this life, similar to a certain party fighter: the more they've been
-- hit, the further they fly. This rewards sustained pressure + a finisher.
GameConfig.Knockback = {
	BaseImpulse = 45, -- flat impulse floor per hit
	DamageScale = 1.6, -- how much accumulated damage amplifies knockback
	MaxDamageForScale = 180, -- damage cap used in the scaling curve
	UpwardBias = 0.35, -- fraction of impulse redirected upward for "launch" feel
	MassReference = 14, -- normalises impulse against a standard cat mass
	DecayPerSecond = 0, -- accumulated damage does not decay mid-life
}

GameConfig.Camera = {
	ThirdPersonDistance = 12,
	MinDistance = 8,
	MaxDistance = 16,
	FieldOfView = 74,
	Sensitivity = 0.35,
	ShoulderOffset = Vector3.new(2.2, 1.2, 0),
}

-- Power-ups ------------------------------------------------------------------
GameConfig.PowerUps = {
	SpawnInterval = 18,
	Duration = 10,
	RespawnAfterPickup = 22,
}

-- Sky supply drops + fish snacks (DropService) --------------------------------
GameConfig.Drops = {
	FirstDelay = 20, -- seconds into a match before the first crate
	Interval = 32,
	IntervalJitter = 6,
	MayhemInterval = 8, -- crates rain down in the final Mayhem Mode
	FallTime = 7, -- seconds from appearing in the sky to landing
	DropHeight = 140,
	Lifetime = 45, -- an untouched crate vanishes after this
	GrabRadius = 5,
	LegendaryWeapons = { "VoidCannon", "GoldenPurr", "Starfall", "BoomPaw" },
	-- Roll weights for what a crate gives.
	Rewards = { Weapon = 30, Overdrive = 30, Heal = 25, Coins = 15 },
	CoinsMin = 60,
	CoinsMax = 150,
	OverdriveSeconds = 15,
	ShieldSeconds = 12,
}

GameConfig.Snacks = {
	Interval = 22,
	MaxActive = 3,
	Heal = 40,
	FluffCut = 30, -- knockback damage removed by eating one
	GrabRadius = 4,
}

-- Health slowly returns once you've stopped taking hits.
GameConfig.Regen = {
	Delay = 5,
	PerSecond = 6,
}

-- Dash + double jump (client-driven movement) -------------------------------
GameConfig.Movement = {
	DashSpeed = 78,
	DashTime = 0.18,
	DashCooldown = 2.5,
	DoubleJumpSpeed = 50,
}

-- Kill streaks + bounties -----------------------------------------------------
GameConfig.Streaks = {
	OnFire = 3, -- eliminations in a row to go "On Fire" (and carry a bounty)
	BountyCoinsPerKill = 25, -- per streak kill beyond the threshold, paid to whoever ends it
	BountyXP = 60,
}

-- Map events (eruption / wind / stampede) ------------------------------------
GameConfig.Events = {
	FirstDelay = 50,
	Interval = 60,
}

-- Final-seconds Mayhem Mode ----------------------------------------------------
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
