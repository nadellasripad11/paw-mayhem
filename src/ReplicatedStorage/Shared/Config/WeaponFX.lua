--!strict
-- WeaponFX: how each blaster class looks and sounds when it fires, so every
-- weapon has its own identity (a thick booming bolt, a thin rapid zip, a
-- bubble stream...). Purely cosmetic; gameplay numbers live in Weapons.

local Weapons = require(script.Parent.Weapons)

export type Style = {
	core: number, -- bright centre thickness (studs)
	glow: number, -- soft outer glow thickness
	life: number, -- seconds the bolt stays on screen
	sparks: number, -- impact sparks
	ring: number?, -- impact shock ring size (heavy hitters)
	bubbles: boolean?, -- drawn as a stream of bubbles instead of a beam
	shards: boolean?, -- ice shards at the impact
	pitch: number, -- shot sound pitch
	volume: number?, -- shot sound volume multiplier
}

local STYLES: { [string]: Style } = {
	Balanced = { core = 0.22, glow = 0.72, life = 0.12, sparks = 5, pitch = 1.25 },
	Epic = { core = 0.16, glow = 0.55, life = 0.2, sparks = 6, pitch = 1.05 },
	Exclusive = { core = 0.17, glow = 0.6, life = 0.18, sparks = 6, pitch = 1.1 },
	Heavy = { core = 0.45, glow = 1.3, life = 0.16, sparks = 8, ring = 6, pitch = 0.72, volume = 1.3 },
	Fast = { core = 0.13, glow = 0.4, life = 0.07, sparks = 2, pitch = 1.6, volume = 0.75 },
	Ice = { core = 0.2, glow = 0.85, life = 0.14, sparks = 4, shards = true, pitch = 1.45 },
	Legendary = { core = 0.5, glow = 1.6, life = 0.22, sparks = 10, ring = 9, pitch = 0.58, volume = 1.4 },
	Fun = { core = 0.3, glow = 0, life = 0.5, sparks = 0, bubbles = true, pitch = 1.85 },
	Premium = { core = 0.24, glow = 0.8, life = 0.14, sparks = 8, pitch = 1.15 },
}

local WeaponFX = {}

function WeaponFX.Style(weaponId: string?): Style
	local w = weaponId and Weapons.Get(weaponId)
	return (w and STYLES[w.Class]) or STYLES.Balanced
end

return WeaponFX
