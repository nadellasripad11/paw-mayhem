--!strict
-- Knockback: pure math for the defining mechanic. Kept shared so the client
-- can predict launch direction for VFX, but the SERVER is the only authority
-- that actually applies impulses.
--
-- Model: each hit adds "fluff" damage to the victim's accumulated total for the
-- current life. The impulse magnitude scales with that accumulated total, so a
-- freshly-spawned cat barely moves but a heavily-pressured cat launches far.

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local Knockback = {}

-- Compute the desired VELOCITY-CHANGE vector (studs/s) for a victim. The
-- caller converts this to a mass-correct impulse (impulse = dV * assemblyMass)
-- so knockback velocity is consistent regardless of a rig's mass, while heavier
-- rigs still receive a proportionally larger impulse.
--   direction   : unit Vector3 from shooter to victim (horizontal-ish)
--   accumulated : total fluff damage the victim has taken this life
--   weaponMult  : weapon's Knockback multiplier
--   extraMult   : power-up / status multipliers (Mega Knockback, shield, etc.)
function Knockback.ComputeDeltaV(
	direction: Vector3,
	accumulated: number,
	weaponMult: number,
	extraMult: number
): Vector3
	local cfg = GameConfig.Knockback

	-- Normalise direction on the horizontal plane, keep a little of the shot's
	-- vertical component so upward shots pop targets up.
	local horiz = Vector3.new(direction.X, 0, direction.Z)
	if horiz.Magnitude < 0.05 then
		horiz = Vector3.new(0, 0, -1)
	end
	horiz = horiz.Unit

	-- Damage scaling curve (0..1 of MaxDamageForScale).
	local dmgFrac = math.clamp(accumulated / cfg.MaxDamageForScale, 0, 1)
	local scaled = cfg.BaseImpulse * (1 + dmgFrac * cfg.DamageScale)

	local mult = math.max(0, weaponMult) * math.max(0, extraMult)
	local magnitude = scaled * mult

	-- Blend horizontal push with an upward launch bias.
	local dir = (horiz * (1 - cfg.UpwardBias) + Vector3.new(0, cfg.UpwardBias, 0)).Unit
	return dir * magnitude
end

-- Convenience: predicted launch distance for UI/feedback (very rough).
function Knockback.EstimateLaunch(accumulated: number): number
	local cfg = GameConfig.Knockback
	local dmgFrac = math.clamp(accumulated / cfg.MaxDamageForScale, 0, 1)
	return cfg.BaseImpulse * (1 + dmgFrac * cfg.DamageScale)
end

return Knockback
