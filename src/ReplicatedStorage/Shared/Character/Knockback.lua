--!strict
-- knockback: pure math for the defining mechanic. kept shared so the client
-- can predict launch direction for vfx, but the server is the only authority
-- that decides every launch.
--
-- model: each hit adds "fluff" damage to the victim's knockback % for the
-- current life, and the launch grows faster than the % does (a curve, not a
-- line): at 0% a hit is a nudge you walk off, around 100% it sends you
-- flying, near 200% almost anything is a finisher.
-- the angle grows with the % too: low-% hits push you mostly sideways, high-%
-- hits throw you up and away. aiming up or down tilts it a little.

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local Knockback = {}

-- how hard a hit at `accumulated` % launches (studs/s, before multipliers).
function Knockback.Strength(accumulated: number): number
	local cfg = GameConfig.Knockback
	local f = math.max(0, accumulated)
	return math.min(cfg.Base + cfg.Linear * f + cfg.Curve * f * f, cfg.MaxSpeed)
end

-- compute the desired velocity-change vector (studs/s) for a victim. the
-- caller converts this to a mass-correct impulse (impulse = dv * assemblymass).
--   direction   : unit vector3 from shooter to victim
--   accumulated : the victim's knockback % this life (after this hit)
--   weaponmult  : weapon's knockback multiplier
--   extramult   : power-up / status / mode multipliers
function Knockback.ComputeDeltaV(direction: Vector3, accumulated: number, weaponMult: number, extraMult: number): Vector3
	local cfg = GameConfig.Knockback

	local horiz = Vector3.new(direction.X, 0, direction.Z)
	if horiz.Magnitude < 0.05 then
		horiz = Vector3.new(0, 0, -1)
	end
	horiz = horiz.Unit

	-- launch angle: flatter at low %, steeper as the % climbs; aiming up or
	-- down nudges it.
	local t = math.clamp(accumulated / cfg.SteepAt, 0, 1)
	local up = cfg.UpLow + (cfg.UpHigh - cfg.UpLow) * t + math.clamp(direction.Y, -1, 1) * cfg.AimTilt
	up = math.clamp(up, 0.08, 0.85)
	local dir = (horiz * (1 - up) + Vector3.new(0, up, 0)).Unit

	local mult = math.max(0, weaponMult) * math.max(0, extraMult)
	return dir * Knockback.Strength(accumulated) * mult
end

-- how long a launch takes your controls away (bigger hits, longer stun).
function Knockback.StunSeconds(dV: Vector3): number
	local cfg = GameConfig.Knockback
	return math.clamp(cfg.StunMin + dV.Magnitude * cfg.StunPerSpeed, cfg.StunMin, cfg.StunMax)
end

-- rough launch speed for ui/feedback.
function Knockback.EstimateLaunch(accumulated: number): number
	return Knockback.Strength(accumulated)
end

return Knockback
