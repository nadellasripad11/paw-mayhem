--!strict
-- Map 2/3 — Volcano. One connected cluster of basalt platforms stepping down
-- from a craggy erupting volcano: lava rivers pour down the cone, across the
-- crater terrace and off the edges into a glowing lava sea. Paved platforms
-- with brass arena pads, scaffold watchtowers, forge huts, braziers and
-- industrial bridges. Point-symmetric so Blue and Red play the same map.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ArenaKit = require(script.Parent.Parent.ArenaKit)

local Volcano = { Id = "Volcano", Name = "Volcano" }

local PALETTE: ArenaKit.Palette = {
	Top = Color3.fromRGB(106, 94, 116), TopDark = Color3.fromRGB(76, 64, 86),
	Stone = Color3.fromRGB(88, 72, 94), StoneDark = Color3.fromRGB(46, 38, 54),
	Wood = Color3.fromRGB(112, 78, 52), WoodDark = Color3.fromRGB(66, 44, 32),
}
local LAVA = Color3.fromRGB(255, 110, 28)
local LAVA_GLOW = Color3.fromRGB(255, 190, 70)
local LAVA_DARK = Color3.fromRGB(214, 60, 18)
local BASALT = Color3.fromRGB(58, 48, 66)
local ROCK_MID = Color3.fromRGB(80, 67, 90)
local ROCK_LIGHT = Color3.fromRGB(126, 112, 134)
local FLAG = Color3.fromRGB(118, 106, 128)
local FLAG_DARK = Color3.fromRGB(88, 78, 100)
local BRASS = Color3.fromRGB(206, 160, 76)
local IRON = Color3.fromRGB(58, 54, 62)
local BRICK = Color3.fromRGB(92, 76, 98)
local CRATE = Color3.fromRGB(132, 92, 58)
local TEAM_COLOR = { Blue = Color3.fromRGB(70, 160, 255), Red = Color3.fromRGB(255, 72, 60) }
local STYLE: ArenaKit.IslandStyle = { cliffMaterial = Enum.Material.Basalt, seam = LAVA, depth = 1.1 }
local STAIRS: ArenaKit.StairStyle = { step = FLAG, stepAlt = FLAG_DARK, wall = BRICK, under = BASALT, material = Enum.Material.Basalt }

local LAVA_SEA_Y = -88

-- ── Layout (point-symmetric: Blue at -Z, Red at +Z) ─────────────────────────
local LAYOUT = {
	center = { pos = Vector3.new(0, 20, 0), r = 38 },
	cornerBL = { pos = Vector3.new(-52, 12, -52), r = 20 },
	cornerBR = { pos = Vector3.new(52, 12, -52), r = 20 },
	cornerRL = { pos = Vector3.new(-52, 12, 52), r = 20 },
	cornerRR = { pos = Vector3.new(52, 12, 52), r = 20 },
	teamB = { pos = Vector3.new(0, 5, -104), r = 28, team = "Blue" },
	teamR = { pos = Vector3.new(0, 5, 104), r = 28, team = "Red" },
	flankL = { pos = Vector3.new(-108, 6, 0), r = 22 },
	flankR = { pos = Vector3.new(108, 6, 0), r = 22 },
	padBL = { pos = Vector3.new(-58, 2, -118), r = 14 },
	padBR = { pos = Vector3.new(58, 2, -118), r = 14 },
	padRL = { pos = Vector3.new(-58, 2, 118), r = 14 },
	padRR = { pos = Vector3.new(58, 2, 118), r = 14 },
	perchL = { pos = Vector3.new(-66, 28, 0), r = 12 },
	perchR = { pos = Vector3.new(66, 28, 0), r = 12 },
}
local LINKS = {
	{ "center", "cornerBL", "bridge" }, { "center", "cornerBR", "bridge" },
	{ "center", "cornerRL", "bridge" }, { "center", "cornerRR", "bridge" },
	{ "center", "teamB", "bridge" }, { "center", "teamR", "bridge" },
	{ "center", "perchL", "stairs" }, { "center", "perchR", "stairs" },
	{ "cornerBL", "teamB", "bridge" }, { "cornerBR", "teamB", "bridge" },
	{ "cornerRL", "teamR", "bridge" }, { "cornerRR", "teamR", "bridge" },
	{ "cornerBL", "flankL", "bridge" }, { "cornerRL", "flankL", "bridge" },
	{ "cornerBR", "flankR", "bridge" }, { "cornerRR", "flankR", "bridge" },
	{ "teamB", "padBL", "bridge" }, { "teamB", "padBR", "bridge" },
	{ "teamR", "padRL", "bridge" }, { "teamR", "padRR", "bridge" },
	{ "padBL", "cornerBL", "bridge" }, { "padBR", "cornerBR", "bridge" },
	{ "padRL", "cornerRL", "bridge" }, { "padRR", "cornerRR", "bridge" },
}
local RIVERS = { math.rad(22.5), math.rad(112.5), math.rad(202.5), math.rad(292.5) }
local DECOR = {
	{ pos = Vector3.new(-150, 34, -70), r = 10, tower = true },
	{ pos = Vector3.new(150, 30, 70), r = 10, tower = true },
	{ pos = Vector3.new(-176, 6, 48), r = 13 },
	{ pos = Vector3.new(176, 10, -48), r = 13 },
	{ pos = Vector3.new(-128, 50, 118), r = 8 },
	{ pos = Vector3.new(128, 46, -118), r = 8 },
	{ pos = Vector3.new(-110, -12, -178), r = 12, tower = true },
	{ pos = Vector3.new(110, -10, 178), r = 12, tower = true },
	{ pos = Vector3.new(-206, 24, -136), r = 9 },
	{ pos = Vector3.new(206, 20, 136), r = 9 },
	{ pos = Vector3.new(0, 56, -206), r = 9, tower = true },
	{ pos = Vector3.new(0, 52, 206), r = 9, tower = true },
}

local rng = Random.new(20260923)
local NP = ArenaKit.NewPart
local DISC = ArenaKit.NewDisc
local BEAM = ArenaKit.Beam

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	return p
end

local function glowPart(p: BasePart): BasePart
	p.CanCollide = false
	p.CastShadow = false
	return p
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = parent
end

local function faceYaw(dir: Vector3): number
	return math.atan2(-dir.X, -dir.Z)
end

local function rockShade(): Color3
	return BASALT:Lerp(ROCK_MID, rng:NextNumber())
end

local function smokeEmitter(parent: BasePart, rate: number, size0: number, size1: number, life: number, speed: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(92, 72, 70), Color3.fromRGB(44, 36, 42))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size0), NumberSequenceKeypoint.new(1, size1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(life * 0.7, life)
	e.Rate = rate
	e.Speed = NumberRange.new(speed * 0.6, speed)
	e.SpreadAngle = Vector2.new(12, 12)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end

-- Glowing sparks drifting up out of the lava.
local function emberEmitter(parent: BasePart, rate: number, speed: number, spread: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 214, 110), Color3.fromRGB(255, 90, 30))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(2.5, 5)
	e.Rate = rate
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end

-- Invisible anchor for emitters / bubble vents.
local function marker(name: string, pos: Vector3, parent: Instance): BasePart
	local p = NP(name, Vector3.new(1, 1, 1), CFrame.new(pos), LAVA, Enum.Material.SmoothPlastic, parent)
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- Cooled lava crust: dark red-brown rock that the CrackedLava material laces
-- with glowing fissures.
local function crustShade(): Color3
	return Color3.fromRGB(rng:NextInteger(64, 98), rng:NextInteger(34, 48), rng:NextInteger(30, 40))
end

-- Tags the client LavaFX controller animates.
local function hot(p: BasePart): BasePart
	CollectionService:AddTag(p, "LavaHot")
	return p
end

local FALL_SPOTS: { Vector3 } = {}

-- ── Surface detail ───────────────────────────────────────────────────────────

-- Worn paving flagstones across the platform top.
local function makeFlagstones(isle: any, minR: number, count: number)
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(minR, isle.r - 2.5)
		local s = rng:NextNumber(2.6, 4.2)
		local p = ArenaKit.Polar(isle, a, d, 0.08)
		deco(NP("Flag", Vector3.new(s, 0.16, s * rng:NextNumber(0.7, 1)), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), FLAG:Lerp(FLAG_DARK, rng:NextNumber()), Enum.Material.Slate, isle.folder))
	end
end

-- Zig-zag glowing cracks running in from the edge.
local function makeLavaCracks(isle: any, count: number, minR: number)
	for _ = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = ArenaKit.Polar(isle, a, isle.r - 1, 0.1)
		local heading = a + math.pi + rng:NextNumber(-0.5, 0.5)
		for _ = 1, 3 do
			local len = rng:NextNumber(2.5, 5.5)
			local q = p + Vector3.new(math.cos(heading) * len, 0, math.sin(heading) * len)
			if Vector2.new(q.X - isle.pos.X, q.Z - isle.pos.Z).Magnitude < minR then
				break
			end
			local cf = CFrame.lookAt((p + q) / 2, q)
			deco(NP("CrackEdge", Vector3.new(1.1, 0.14, len + 0.4), cf * CFrame.new(0, -0.03, 0), BASALT, Enum.Material.Basalt, isle.folder))
			glowPart(NP("Crack", Vector3.new(0.45, 0.16, len + 0.2), cf, LAVA, Enum.Material.Neon, isle.folder))
			p = q
			heading += rng:NextNumber(-0.8, 0.8)
		end
	end
end

-- Round paved combat pad with a brass compass ring.
local function makeArenaPad(center: Vector3, R: number, parent: Instance, ring: Color3?)
	local metal = ring or BRASS
	deco(DISC("PadBase", R * 2 + 1, 0.3, center + Vector3.new(0, 0.12, 0), FLAG_DARK, Enum.Material.Slate, parent))
	deco(DISC("Pad", R * 2, 0.32, center + Vector3.new(0, 0.14, 0), ROCK_LIGHT, Enum.Material.Slate, parent))
	deco(DISC("PadRing", R * 1.25, 0.34, center + Vector3.new(0, 0.16, 0), metal, Enum.Material.Metal, parent))
	deco(DISC("PadInner", R * 1.25 - 1.2, 0.36, center + Vector3.new(0, 0.17, 0), FLAG, Enum.Material.Slate, parent))
	deco(DISC("Emblem", R * 0.45, 0.38, center + Vector3.new(0, 0.18, 0), metal, Enum.Material.Metal, parent))
	for k = 0, 3 do
		local a = k * math.pi / 2
		local p = center + Vector3.new(math.cos(a) * R * 0.42, 0.18, math.sin(a) * R * 0.42)
		deco(NP("Ray", Vector3.new(0.6, 0.38, R * 0.3), CFrame.lookAt(p, p + Vector3.new(math.cos(a), 0, math.sin(a))), metal, Enum.Material.Metal, parent))
	end
	glowPart(DISC("Core", 1.4, 0.4, center + Vector3.new(0, 0.2, 0), LAVA, Enum.Material.Neon, parent))
	local n = math.floor(R * 1.5)
	for i = 1, n do
		local a = i / n * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * (R - 0.6), 0.2, math.sin(a) * (R - 0.6))
		deco(NP("Rim", Vector3.new(1, 0.34, 2 * math.pi * R / n * 0.85), CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))), FLAG_DARK, Enum.Material.Slate, parent))
	end
end

-- ── Props ────────────────────────────────────────────────────────────────────

local function makeCrate(pos: Vector3, s: number, yaw: number, ore: boolean, parent: Instance)
	local cf = CFrame.new(pos + Vector3.new(0, 1.8 * s, 0)) * CFrame.Angles(0, yaw, 0)
	NP("Crate", Vector3.new(3.6, 3.6, 3.6) * s, cf, CRATE:Lerp(PALETTE.WoodDark, rng:NextNumber(0, 0.3)), Enum.Material.WoodPlanks, parent)
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			deco(NP("Corner", Vector3.new(0.45, 3.7, 0.45) * s, cf * CFrame.new(x * 1.62 * s, 0, z * 1.62 * s), IRON, Enum.Material.Metal, parent))
		end
	end
	for _, y in ipairs({ -1.5, 1.5 }) do
		deco(NP("Band", Vector3.new(3.72, 0.35, 3.72) * s, cf * CFrame.new(0, y * s, 0), IRON, Enum.Material.Metal, parent))
	end
	if ore then
		local g = glowPart(NP("Ore", Vector3.new(2.6, 0.55, 3.66) * s, cf * CFrame.new(0, 0.2 * s, 0), LAVA, Enum.Material.Neon, parent))
		light(g, LAVA, 9, 0.8)
	end
end

local function makeCrateStack(pos: Vector3, parent: Instance)
	local yaw = rng:NextNumber(0, 6.28)
	makeCrate(pos, 1, yaw, rng:NextNumber() < 0.35, parent)
	makeCrate(pos + Vector3.new(3.9 * math.cos(yaw), 0, 3.9 * math.sin(yaw)), 0.85, yaw + 0.25, false, parent)
	if rng:NextNumber() < 0.6 then
		makeCrate(pos + Vector3.new(0, 3.6, 0), 0.72, yaw + 0.6, rng:NextNumber() < 0.3, parent)
	end
end

local function makeBarrel(pos: Vector3, parent: Instance)
	DISC("Drum", 2.4, 3, pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(70, 64, 74), Enum.Material.Metal, parent)
	glowPart(DISC("Band", 2.5, 0.35, pos + Vector3.new(0, 1.6, 0), LAVA, Enum.Material.Neon, parent))
	for _, y in ipairs({ 0.4, 2.7 }) do
		deco(DISC("Rib", 2.55, 0.25, pos + Vector3.new(0, y, 0), IRON, Enum.Material.Metal, parent))
	end
end

local function makeBrazier(pos: Vector3, parent: Instance)
	NP("Pedestal", Vector3.new(1.6, 2.4, 1.6), CFrame.new(pos + Vector3.new(0, 1.2, 0)), BRICK, Enum.Material.Basalt, parent)
	deco(DISC("Bowl", 3.2, 0.8, pos + Vector3.new(0, 2.8, 0), IRON, Enum.Material.Metal, parent))
	local fire = glowPart(DISC("Coals", 2.6, 0.3, pos + Vector3.new(0, 3.25, 0), LAVA, Enum.Material.Neon, parent))
	local flame = glowPart(NP("Flame", Vector3.new(1.1, 1.1, 1.1), CFrame.new(pos + Vector3.new(0, 3.8, 0)), LAVA_GLOW, Enum.Material.Neon, parent))
	flame.Shape = Enum.PartType.Ball
	light(fire, LAVA_GLOW, 18, 1.3)
end

local function makeSpire(pos: Vector3, s: number, parent: Instance)
	for k = 1, rng:NextInteger(2, 3) do
		local h = rng:NextNumber(4, 9) * s
		local w = rng:NextNumber(1.4, 2.6) * s
		local off = Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2)) * s
		local cf = CFrame.new(pos + off + Vector3.new(0, h * 0.42, 0)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6.28), rng:NextNumber(-0.25, 0.25))
		deco(NP("Spire" .. k, Vector3.new(w, h, w * rng:NextNumber(0.7, 1)), cf, rockShade(), Enum.Material.Basalt, parent))
		if k == 1 then
			glowPart(NP("SpireSeam", Vector3.new(0.25, h * 0.6, 0.2), cf * CFrame.new(0, -h * 0.1, -w * 0.45), LAVA, Enum.Material.Neon, parent))
		end
	end
end

local function makeVent(pos: Vector3, parent: Instance)
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		local p = pos + Vector3.new(math.cos(a) * 1.7, 0.5, math.sin(a) * 1.7)
		deco(NP("VentRock", Vector3.new(1.4, rng:NextNumber(0.8, 1.6), 1.2), CFrame.lookAt(p, pos + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0.3, 0, 0), rockShade(), Enum.Material.Basalt, parent))
	end
	local pool = glowPart(DISC("VentLava", 2.6, 0.3, pos + Vector3.new(0, 0.3, 0), LAVA_GLOW, Enum.Material.Neon, parent))
	light(pool, LAVA, 12, 1)
	smokeEmitter(pool, 3, 1.5, 5, 5, 4)
end

local function makeBanner(pos: Vector3, color: Color3, yaw: number, parent: Instance)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	NP("BannerPole", Vector3.new(0.55, 11, 0.55), cf * CFrame.new(0, 5.5, 0), IRON, Enum.Material.Metal, parent)
	deco(NP("BannerBar", Vector3.new(4.2, 0.35, 0.35), cf * CFrame.new(0, 10.3, -0.35), IRON, Enum.Material.Metal, parent))
	deco(NP("Banner", Vector3.new(3.6, 5.4, 0.15), cf * CFrame.new(0, 7.4, -0.4), color, Enum.Material.Fabric, parent))
	glowPart(NP("BannerTrim", Vector3.new(3.6, 0.35, 0.18), cf * CFrame.new(0, 4.85, -0.42), LAVA_GLOW, Enum.Material.Neon, parent))
	local tip = glowPart(NP("BannerTip", Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(0, 11.4, 0), LAVA_GLOW, Enum.Material.Neon, parent))
	tip.Shape = Enum.PartType.Ball
end

-- Tapered timber scaffold watchtower with braces, railed deck, pitched roof,
-- lantern and ladder.
local function makeTower(pos: Vector3, height: number, s: number, facing: Vector3, parent: Instance)
	local f = Instance.new("Model")
	f.Name = "Watchtower"
	f.Parent = parent
	local rot = CFrame.new(pos) * CFrame.Angles(0, faceYaw(facing), 0)
	local hb, ht = 3.2 * s, 2.3 * s
	local corners = { { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }
	local function C(k: number, y: number): Vector3
		local c = corners[k]
		local hw = hb + (ht - hb) * (y / height)
		return rot:PointToWorldSpace(Vector3.new(c[1] * hw, y, c[2] * hw))
	end
	for k = 1, 4 do
		BEAM("Leg", C(k, 0) - Vector3.new(0, 0.6, 0), C(k, height), 0.75 * s, PALETTE.WoodDark, Enum.Material.Wood, f).CanCollide = true
		deco(NP("Foot", Vector3.new(1.4, 0.6, 1.4) * s, CFrame.new(C(k, 0) + Vector3.new(0, 0.2, 0)), IRON, Enum.Material.Metal, f))
	end
	local levels = math.max(2, math.floor(height / 5))
	for l = 1, levels do
		local y = height * l / levels
		for k = 1, 4 do
			BEAM("Ring", C(k, y), C(k % 4 + 1, y), 0.42 * s, PALETTE.Wood, Enum.Material.Wood, f)
		end
	end
	for l = 0, levels - 1 do
		local y0, y1 = height * l / levels, height * (l + 1) / levels
		for k = 1, 4 do
			if (k + l) % 2 == 0 then
				BEAM("Brace", C(k, y0), C(k % 4 + 1, y1), 0.32 * s, PALETTE.WoodDark, Enum.Material.Wood, f)
			else
				BEAM("Brace", C(k % 4 + 1, y0), C(k, y1), 0.32 * s, PALETTE.WoodDark, Enum.Material.Wood, f)
			end
		end
	end
	local dh = ht + 1.1 * s
	deco(NP("Deck", Vector3.new(dh * 2, 0.5, dh * 2), rot * CFrame.new(0, height + 0.25, 0), PALETTE.Wood, Enum.Material.WoodPlanks, f))
	local deckCorners = {}
	for k = 1, 4 do
		local c = corners[k]
		deckCorners[k] = rot:PointToWorldSpace(Vector3.new(c[1] * (dh - 0.2), height + 0.5, c[2] * (dh - 0.2)))
		deco(NP("RoofPost", Vector3.new(0.35, 4, 0.35) * s, CFrame.new(deckCorners[k] + Vector3.new(0, 2 * s, 0)), PALETTE.WoodDark, Enum.Material.Wood, f))
	end
	for k = 1, 4 do
		BEAM("Rail", deckCorners[k] + Vector3.new(0, 1.3 * s, 0), deckCorners[k % 4 + 1] + Vector3.new(0, 1.3 * s, 0), 0.26 * s, PALETTE.Wood, Enum.Material.Wood, f)
	end
	local roofBase = height + 0.5 + 4 * s
	local ridge = Vector3.new(0, roofBase + 1.9 * s, 0)
	for _, side in ipairs({ 1, -1 }) do
		local eave = Vector3.new(0, roofBase, side * (dh + 0.7))
		local dir = (eave - ridge).Unit
		local c = rot:PointToWorldSpace((ridge + eave) / 2 + Vector3.new(0, 0.2, 0))
		deco(NP("Roof", Vector3.new(dh * 2 + 1.2, 0.4, (eave - ridge).Magnitude + 0.4), CFrame.lookAt(c, c + rot:VectorToWorldSpace(dir)), Color3.fromRGB(86, 60, 50), Enum.Material.CorrodedMetal, f))
	end
	local lantern = glowPart(NP("Lantern", Vector3.new(1, 1.3, 1) * s, rot * CFrame.new(0, height + 0.5 + 2.6 * s, 0), LAVA_GLOW, Enum.Material.Neon, f))
	light(lantern, LAVA_GLOW, 24, 1.4)
	for _, x in ipairs({ -0.7, 0.7 }) do
		BEAM("LadderRail", rot:PointToWorldSpace(Vector3.new(x * s, 0, -hb - 0.25)), rot:PointToWorldSpace(Vector3.new(x * s, height, -ht - 0.25)), 0.2 * s, PALETTE.Wood, Enum.Material.Wood, f)
	end
	for y = 1.2, height - 0.4, 1.5 do
		local z = -(hb + (ht - hb) * (y / height)) - 0.25
		BEAM("Rung", rot:PointToWorldSpace(Vector3.new(-0.7 * s, y, z)), rot:PointToWorldSpace(Vector3.new(0.7 * s, y, z)), 0.16 * s, PALETTE.Wood, Enum.Material.Wood, f)
	end
end

-- Basalt forge hut with a glowing furnace mouth and smoking chimney.
local function makeForge(pos: Vector3, facing: Vector3, teamColor: Color3, parent: Instance)
	local f = Instance.new("Model")
	f.Name = "Forge"
	f.Parent = parent
	local rot = CFrame.new(pos) * CFrame.Angles(0, faceYaw(facing), 0)
	NP("Walls", Vector3.new(10, 6.5, 8), rot * CFrame.new(0, 3.25, 0), BRICK, Enum.Material.Brick, f)
	for _, x in ipairs({ -5.2, 5.2 }) do
		for _, z in ipairs({ -4.2, 4.2 }) do
			NP("Pillar", Vector3.new(1.4, 7.2, 1.4), rot * CFrame.new(x, 3.6, z), BASALT, Enum.Material.Basalt, f)
		end
	end
	NP("Roof", Vector3.new(12, 0.6, 10), rot * CFrame.new(0, 7.3, 0.3) * CFrame.Angles(math.rad(-7), 0, 0), Color3.fromRGB(86, 60, 50), Enum.Material.CorrodedMetal, f)
	NP("Chimney", Vector3.new(2.2, 7, 2.2), rot * CFrame.new(3, 9.5, 2.2), BRICK, Enum.Material.Brick, f)
	local cap = glowPart(NP("ChimneyGlow", Vector3.new(1.6, 0.3, 1.6), rot * CFrame.new(3, 13.05, 2.2), LAVA, Enum.Material.Neon, f))
	smokeEmitter(cap, 4, 2, 7, 6, 5)
	deco(NP("FurnaceFrame", Vector3.new(4.2, 3.4, 0.5), rot * CFrame.new(0, 2, -4.1), BASALT, Enum.Material.Basalt, f))
	local mouth = glowPart(NP("Furnace", Vector3.new(3.2, 2.5, 0.5), rot * CFrame.new(0, 1.9, -4.2), LAVA, Enum.Material.Neon, f))
	light(mouth, LAVA, 16, 1.5)
	for _, x in ipairs({ -3.6, 3.6 }) do
		deco(NP("TeamCloth", Vector3.new(2, 4.2, 0.15), rot * CFrame.new(x, 4, -4.1), teamColor, Enum.Material.Fabric, f))
	end
	NP("Anvil", Vector3.new(1.2, 1.2, 2.2), rot * CFrame.new(-2.5, 0.6, -6.2), IRON, Enum.Material.Metal, f)
	deco(NP("AnvilTop", Vector3.new(1.6, 0.5, 2.8), rot * CFrame.new(-2.5, 1.45, -6.2), IRON, Enum.Material.Metal, f))
end

-- ── The volcano ──────────────────────────────────────────────────────────────

local function makeMountain(c: any, parent: Instance)
	local f = Instance.new("Model")
	f.Name = "VolcanoMountain"
	f.Parent = parent
	local base = Vector3.new(c.pos.X, c.surf, c.pos.Z)
	local R0, R1, H, K = 17, 5.5, 46, 12
	local function radiusAt(y: number): number
		return R1 + (R0 - R1) * (1 - math.clamp(y / H, 0, 1)) ^ 1.6
	end
	local function nearRiver(a: number): boolean
		for _, r in ipairs(RIVERS) do
			if ArenaKit.AngDist(a, r) < 0.28 then
				return true
			end
		end
		return false
	end
	local h = H / K
	for k = 0, K - 1 do
		local y0 = k * h
		local r = radiusAt(y0 + h)
		DISC("Tier" .. k, r * 2, h + 0.2, base + Vector3.new(0, y0 + h / 2, 0), BASALT:Lerp(ROCK_MID, k / K * 0.5), Enum.Material.Basalt, f)
		local n = math.max(6, math.floor(2 * math.pi * r / 5))
		for i = 1, n do
			local a = i / n * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
			if not nearRiver(a) then
				local bh = h * rng:NextNumber(1.1, 2)
				local bw = 2 * math.pi * r / n * rng:NextNumber(0.9, 1.3)
				local bd = rng:NextNumber(2.2, 3.6)
				local out = Vector3.new(math.cos(a), 0, math.sin(a))
				local p = base + Vector3.new(0, y0 + bh * 0.42, 0) + out * (r - bd * 0.35)
				local cf = CFrame.lookAt(p, p + out) * CFrame.Angles(rng:NextNumber(0.1, 0.35), 0, rng:NextNumber(-0.15, 0.15))
				deco(NP("Crag", Vector3.new(bw, bh, bd), cf, rockShade(), Enum.Material.Basalt, f))
				if rng:NextNumber() < 0.12 then
					glowPart(NP("CragSeam", Vector3.new(0.3, bh * 0.7, 0.2), cf * CFrame.new(rng:NextNumber(-bw / 3, bw / 3), 0, -bd / 2 - 0.05), LAVA, Enum.Material.Neon, f))
				end
			end
		end
	end

	-- Secondary peaks hugging the main cone (between the rivers).
	for k = 0, 3 do
		local a = math.rad(67.5) + k * math.pi / 2
		local pc = base + Vector3.new(math.cos(a) * 11, 0, math.sin(a) * 11)
		local ph = rng:NextNumber(17, 25)
		local tiers = 5
		for t = 0, tiers - 1 do
			local rr = 7.5 - t * 1.2
			DISC("PeakTier", rr * 2, ph / tiers + 0.2, pc + Vector3.new(0, (t + 0.5) * ph / tiers, 0), rockShade(), Enum.Material.Basalt, f)
			for i = 1, 5 do
				local b = i / 5 * math.pi * 2 + rng:NextNumber(0, 1)
				local out = Vector3.new(math.cos(b), 0, math.sin(b))
				local bh = ph / tiers * rng:NextNumber(1.2, 2)
				local p = pc + Vector3.new(0, t * ph / tiers + bh * 0.4, 0) + out * (rr - 0.8)
				deco(NP("PeakCrag", Vector3.new(rng:NextNumber(2.4, 3.6), bh, 2.4), CFrame.lookAt(p, p + out) * CFrame.Angles(rng:NextNumber(0.1, 0.3), 0, 0), rockShade(), Enum.Material.Basalt, f))
			end
		end
		deco(NP("PeakTip", Vector3.new(2.6, 6, 2.2), CFrame.new(pc + Vector3.new(0, ph + 2, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2)), ROCK_MID, Enum.Material.Basalt, f))
	end

	-- Crater rim, lava pool, pulsing glow, embers and smoke plume.
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local bh = rng:NextNumber(2.5, 4.8)
		local p = base + Vector3.new(0, H + bh * 0.4, 0) + out * 5.6
		deco(NP("CraterLip", Vector3.new(3.8, bh, 2.6), CFrame.lookAt(p, p + out) * CFrame.Angles(-0.25, 0, 0), rockShade(), Enum.Material.Basalt, f))
	end
	local pool = glowPart(DISC("CraterLava", 10, 0.6, base + Vector3.new(0, H + 0.8, 0), LAVA_GLOW, Enum.Material.Neon, f))
	local poolLight = Instance.new("PointLight")
	poolLight.Color = LAVA_GLOW
	poolLight.Range = 60
	poolLight.Brightness = 4
	poolLight.Parent = pool
	local embers = Instance.new("ParticleEmitter")
	embers.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	embers.Color = ColorSequence.new(LAVA_GLOW, LAVA_DARK)
	embers.LightEmission = 1
	embers.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0.1) })
	embers.Lifetime = NumberRange.new(3, 5)
	embers.Rate = 24
	embers.Speed = NumberRange.new(12, 22)
	embers.SpreadAngle = Vector2.new(35, 35)
	embers.Acceleration = Vector3.new(0, -6, 0)
	embers.EmissionDirection = Enum.NormalId.Top
	embers.Parent = pool
	local plume = smokeEmitter(pool, 5, 6, 22, 10, 10)
	plume.Acceleration = Vector3.new(1.5, 0.5, 0)
	task.spawn(function()
		local t = 0
		while pool.Parent do
			t += 0.1
			local pulse = 0.5 + math.sin(t * 1.3) * 0.5
			pool.Color = LAVA:Lerp(LAVA_GLOW, pulse)
			poolLight.Brightness = 3 + pulse * 2
			task.wait(0.1)
		end
	end)

	-- Lava rivers down the cone, with rock fill underneath so no gaps show.
	for _, a in ipairs(RIVERS) do
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local segs = 6
		for j = 0, segs - 1 do
			local ya, yb = H * (1 - j / segs), H * (1 - (j + 1) / segs)
			local ra = j == 0 and R1 - 1 or radiusAt(ya) + 0.5
			local pa = base + out * ra + Vector3.new(0, ya + (j == 0 and 1 or 0.4), 0)
			local pb = base + out * (radiusAt(yb) + 0.5) + Vector3.new(0, yb + 0.4, 0)
			local mid = (pa + pb) / 2
			local len = (pb - pa).Magnitude
			deco(NP("RiverBed", Vector3.new(5.2, 2.6, len + 0.6), CFrame.lookAt(mid - out * 1.3, pb - out * 1.3) * CFrame.new(0, -0.8, 0), BASALT, Enum.Material.Basalt, f))
			local glow = glowPart(NP("RiverGlow", Vector3.new(5, 0.5, len + 0.8), CFrame.lookAt(mid, pb) * CFrame.new(0, -0.15, 0), LAVA_DARK, Enum.Material.Neon, f))
			glow.Transparency = 0.25
			local river = hot(glowPart(NP("River", Vector3.new(3.2, 0.7, len + 0.6), CFrame.lookAt(mid, pb), LAVA, Enum.Material.Neon, f)))
			if j % 2 == 1 then
				light(river, LAVA, 20, 1.2)
			end
		end
	end
end

-- Lava channel from `fromR` to the island edge, then a lavafall into the sea.
local function makeLavaRun(isle: any, angle: number, fromR: number, parent: Instance)
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local from = ArenaKit.Polar(isle, angle, fromR)
	local lip = ArenaKit.Polar(isle, angle, isle.r + 0.2)
	local len = (lip - from).Magnitude
	local cf = CFrame.lookAt((from + lip) / 2, lip)
	deco(NP("ChannelBank", Vector3.new(6.4, 0.26, len), cf * CFrame.new(0, 0.1, 0), crustShade(), Enum.Material.CrackedLava, parent))
	hot(glowPart(NP("Channel", Vector3.new(3.6, 0.3, len), cf * CFrame.new(0, 0.16, 0), LAVA, Enum.Material.Neon, parent)))
	for k = 1, math.floor(len / 5) do
		for _, x in ipairs({ -3.4, 3.4 }) do
			local p = (cf * CFrame.new(x + rng:NextNumber(-0.3, 0.3), 0.4, -len / 2 + k * 5)).Position
			deco(NP("BankRock", Vector3.new(1.3, rng:NextNumber(0.6, 1.2), 1.5), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.2), rockShade(), Enum.Material.Basalt, parent))
		end
	end
	-- Lavafall: molten core, jagged crusted edges, a flowing surface and a
	-- splash pool where it meets the sea.
	local height = isle.surf - LAVA_SEA_Y
	local edge = lip + out * 0.9
	local top = edge - Vector3.new(0, height / 2 - 0.3, 0)
	local fallCF = CFrame.lookAt(top, top + out)
	local sheet = hot(glowPart(NP("Lavafall", Vector3.new(3.8, height, 1.2), fallCF, LAVA, Enum.Material.Neon, parent)))
	local halo = glowPart(NP("LavafallGlow", Vector3.new(7, height, 3), fallCF * CFrame.new(0, 0, -0.6), LAVA_DARK, Enum.Material.Neon, parent))
	halo.Transparency = 0.75
	for _, x in ipairs({ -2.3, 2.3 }) do
		local y = 0
		while y < height - 0.5 do
			local seg = math.min(rng:NextNumber(7, 15), height - y)
			local chunk = deco(NP("FallCrust", Vector3.new(rng:NextNumber(0.9, 1.5), seg + 0.4, rng:NextNumber(1.5, 2.1)),
				fallCF * CFrame.new(x + rng:NextNumber(-0.25, 0.25), height / 2 - y - seg / 2, rng:NextNumber(-0.2, 0.2)) * CFrame.Angles(0, 0, rng:NextNumber(-0.05, 0.05)),
				crustShade(), Enum.Material.CrackedLava, parent))
			chunk.CastShadow = false
			y += seg
		end
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, height / 2 - 0.4, -0.75)
	a0.Parent = sheet
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -height / 2 + 1, -0.75)
	a1.Parent = sheet
	for k, spec in ipairs({ { 4.6, 1.4, 12, 0.1 }, { 3.2, 2.3, 7, 0.35 } }) do
		local flow = Instance.new("Beam")
		flow.Name = "LavaFlow" .. k
		flow.Attachment0 = a0
		flow.Attachment1 = a1
		flow.Texture = "rbxasset://textures/particles/fire_main.dds"
		flow.TextureMode = Enum.TextureMode.Wrap
		flow.TextureLength = spec[3]
		flow.TextureSpeed = spec[2]
		flow.Width0 = spec[1]
		flow.Width1 = spec[1] * 1.15
		flow.FaceCamera = true
		flow.LightEmission = 1
		flow.LightInfluence = 0
		flow.Color = ColorSequence.new(LAVA_GLOW, LAVA)
		flow.Transparency = NumberSequence.new(spec[4])
		flow.Parent = sheet
	end
	local crest = hot(glowPart(NP("LavaCrest", Vector3.new(5, 1.2, 2), CFrame.lookAt(edge + Vector3.new(0, 0.15, 0), edge + Vector3.new(0, 0.15, 0) + out), LAVA_GLOW, Enum.Material.Neon, parent)))
	light(crest, LAVA_GLOW, 22, 1.5)

	local foot = Vector3.new(edge.X, LAVA_SEA_Y + 0.25, edge.Z)
	table.insert(FALL_SPOTS, foot)
	hot(glowPart(DISC("FallPool", 18, 0.5, foot, LAVA_GLOW, Enum.Material.Neon, parent)))
	for k = 1, 7 do
		local a = k / 7 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local p = foot + Vector3.new(math.cos(a) * 10, 0.4, math.sin(a) * 10)
		deco(NP("PoolRock", Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(1, 2.2), rng:NextNumber(3, 5)), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), crustShade(), Enum.Material.CrackedLava, parent))
	end
	local splash = marker("LavaSplash", foot + Vector3.new(0, 1, 0), parent)
	smokeEmitter(splash, 3, 6, 24, 8, 9)
	emberEmitter(splash, 12, 16, 40)
	splash:SetAttribute("Radius", 7)
	splash:SetAttribute("SurfaceY", foot.Y + 0.3)
	CollectionService:AddTag(splash, "LavaVent")
end

-- ── Connections ──────────────────────────────────────────────────────────────

-- Industrial bridge: iron girders, timber planks, iron posts with chain
-- rails, string lights and lamps on the end posts.
local function makeBridge(A: any, B: any, parent: Instance)
	local f = Instance.new("Folder")
	f.Name = "Bridge"
	f.Parent = parent
	local a, b = ArenaKit.WalkwayCollision(A, B, f, 6, 1.2)
	local span = (b - a).Magnitude
	local dir = (b - a).Unit
	local right = CFrame.lookAt(a, b).RightVector
	for i = 0, math.floor(span / 1.4) do
		local p = a + dir * (i * 1.4 + 0.6) - Vector3.new(0, 0.14, 0)
		deco(NP("Plank", Vector3.new(rng:NextNumber(5.8, 6.2), 0.3, 1.1), CFrame.lookAt(p, p + dir) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), 0), PALETTE.Wood:Lerp(PALETTE.WoodDark, rng:NextNumber(0, 0.5)), Enum.Material.WoodPlanks, f))
	end
	for _, x in ipairs({ -2.4, 2.4 }) do
		BEAM("Girder", a + right * x - Vector3.new(0, 0.75, 0), b + right * x - Vector3.new(0, 0.75, 0), 0.9, IRON, Enum.Material.Metal, f)
	end
	local posts = math.max(1, math.floor(span / 6.5))
	for side = -1, 1, 2 do
		local prev: Vector3? = nil
		for k = 0, posts do
			local p = a:Lerp(b, k / posts) + right * side * 3
			local endPost = k == 0 or k == posts
			deco(NP("Post", Vector3.new(endPost and 0.7 or 0.45, 3.2, endPost and 0.7 or 0.45), CFrame.new(p + Vector3.new(0, 1.2, 0)), IRON, Enum.Material.Metal, f))
			if prev then
				BEAM("Chain", prev + Vector3.new(0, 2.5, 0), p + Vector3.new(0, 2.5, 0), 0.2, Color3.fromRGB(40, 36, 40), Enum.Material.Metal, f)
				BEAM("Chain", prev + Vector3.new(0, 1.3, 0), p + Vector3.new(0, 1.3, 0), 0.2, Color3.fromRGB(40, 36, 40), Enum.Material.Metal, f)
				local segLen = (p - prev).Magnitude
				for t = 1.6, segLen - 1, 2.6 do
					local bulb = glowPart(NP("Bulb", Vector3.new(0.35, 0.35, 0.35), CFrame.new(prev:Lerp(p, t / segLen) + Vector3.new(0, 2.3, 0)), LAVA_GLOW, Enum.Material.Neon, f))
					bulb.Shape = Enum.PartType.Ball
				end
			end
			if endPost then
				local cap = glowPart(NP("PostLamp", Vector3.new(0.9, 0.9, 0.9), CFrame.new(p + Vector3.new(0, 3.2, 0)), LAVA_GLOW, Enum.Material.Neon, f))
				if side == 1 then
					light(cap, LAVA_GLOW, 14, 0.9)
				end
			end
			prev = p
		end
	end
end

-- ── Island dressing ──────────────────────────────────────────────────────────

local function propsAt(isle: any, n: number, minD: number, maxD: number, rad: number, fn: (Vector3) -> ())
	for _ = 1, n do
		local p = ArenaKit.TryPlace(isle, rng, minD, maxD, rad, 5.5)
		if p then
			fn(p)
		end
	end
end

local function dress(isle: any, minD: number, spires: number, crates: number, barrels: number, vents: number)
	local maxD = isle.r - 3
	propsAt(isle, crates, minD, maxD, 3.4, function(p) makeCrateStack(p, isle.folder) end)
	propsAt(isle, barrels, minD, maxD, 1.6, function(p) makeBarrel(p, isle.folder) end)
	propsAt(isle, vents, minD, maxD, 2.4, function(p) makeVent(p, isle.folder) end)
	propsAt(isle, spires, isle.r * 0.72, isle.r - 1.5, 2.2, function(p) makeSpire(p, rng:NextNumber(0.8, 1.2), isle.folder) end)
end

-- One brazier beside each bridge landing, just outside the walkway.
local function bridgeBraziers(isle: any)
	for i, a in ipairs(isle.links) do
		local d = isle.r - 3.5
		local b = a + (i % 2 == 0 and 1 or -1) * math.asin(math.min(0.95, 6.4 / d))
		local p = ArenaKit.Polar(isle, b, d)
		makeBrazier(p, isle.folder)
		ArenaKit.Reserve(isle, p, 1.8)
	end
end

local function addLavaRuns(isle: any, count: number)
	for _, a in ipairs(ArenaKit.OpenAngles(isle, count)) do
		table.insert(isle.reserved, a)
		makeLavaRun(isle, a, isle.r * 0.55, isle.folder)
	end
end

-- ── Build ────────────────────────────────────────────────────────────────────

function Volcano.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, Volcano.Name)
	table.clear(FALL_SPOTS)

	local I: { [string]: any } = {}
	for key, spec in pairs(LAYOUT) do
		local folder = ArenaKit.MakeIslandBase(spec.pos, spec.r, key, PALETTE, Enum.Material.Slate, arena, STYLE)
		local isle = ArenaKit.NewIsle(spec.pos, spec.r, folder)
		isle.team = (spec :: any).team
		I[key] = isle
	end
	for _, l in ipairs(LINKS) do
		ArenaKit.Link(I[l[1]], I[l[2]])
	end
	local bridges = Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = arena
	for _, l in ipairs(LINKS) do
		if l[3] == "stairs" then
			ArenaKit.MakeStairs(I[l[1]], I[l[2]], bridges, STAIRS)
		else
			makeBridge(I[l[1]], I[l[2]], bridges)
		end
	end

	-- Crater terrace + the volcano
	do
		local c = I.center
		for _, a in ipairs(RIVERS) do
			table.insert(c.reserved, a)
			makeLavaRun(c, a, 17.5, c.folder)
		end
		makeMountain(c, c.folder)
		ArenaKit.Reserve(c, ArenaKit.Polar(c, 0, 0), 19.5)
		makeFlagstones(c, 18, 70)
		makeLavaCracks(c, 8, 19)
		bridgeBraziers(c)
		dress(c, 21, 6, 4, 4, 0)
	end

	-- Corner platforms
	for _, key in ipairs({ "cornerBL", "cornerBR", "cornerRL", "cornerRR" }) do
		local k = I[key]
		local outward = ArenaKit.AngleTo(Vector3.zero, k.pos)
		table.insert(k.reserved, outward)
		makeArenaPad(ArenaKit.Polar(k, 0, 0), 7, k.folder)
		ArenaKit.Reserve(k, ArenaKit.Polar(k, 0, 0), 7.5)
		local tp = ArenaKit.Polar(k, outward, k.r - 6)
		makeTower(tp, 14, 1, ArenaKit.Polar(k, 0, 0) - tp, k.folder)
		ArenaKit.Reserve(k, tp, 5)
		addLavaRuns(k, 1)
		makeFlagstones(k, 7.5, 26)
		makeLavaCracks(k, 5, 8)
		dress(k, 9, 3, 2, 2, 1)
		ArenaKit.AddPowerPad(k.pos, powerPads)
	end

	-- Team bases
	for _, key in ipairs({ "teamB", "teamR" }) do
		local t = I[key]
		local col = TEAM_COLOR[t.team]
		local back = ArenaKit.AngleTo(Vector3.zero, t.pos)
		local towerA = { back - 0.62, back + 0.62 }
		table.insert(t.reserved, back)
		for _, a in ipairs(towerA) do
			table.insert(t.reserved, a)
		end
		makeArenaPad(ArenaKit.Polar(t, 0, 0), 13, t.folder, col)
		ArenaKit.Reserve(t, ArenaKit.Polar(t, 0, 0), 14)
		local home = ArenaKit.Polar(t, back, 20)
		makeForge(home, ArenaKit.Polar(t, 0, 0) - home, col, t.folder)
		ArenaKit.Reserve(t, home, 7.5)
		for _, a in ipairs(towerA) do
			local p = ArenaKit.Polar(t, a, t.r - 6)
			makeTower(p, 16, 1, ArenaKit.Polar(t, 0, 0) - p, t.folder)
			ArenaKit.Reserve(t, p, 5)
		end
		addLavaRuns(t, 2)
		for _, off in ipairs({ -0.5, 0.5 }) do
			local a = back + math.pi + off
			if not ArenaKit.Blocked(t, a, 15.5, 2) then
				local p = ArenaKit.Polar(t, a, 15.5)
				makeBanner(p, col, faceYaw(ArenaKit.Polar(t, 0, 0) - p), t.folder)
				ArenaKit.Reserve(t, p, 1.5)
			end
		end
		makeFlagstones(t, 14, 45)
		makeLavaCracks(t, 6, 15)
		bridgeBraziers(t)
		dress(t, 16, 4, 3, 3, 1)
		ArenaKit.AddTeamTriangleSpawns(t.pos, t.r, t.team, spawns)
		ArenaKit.AddTeamSpawnBeacons(t.pos, t.r, t.team, t.folder)
	end

	-- Flank platforms
	for _, key in ipairs({ "flankL", "flankR" }) do
		local fl = I[key]
		local outward = ArenaKit.AngleTo(Vector3.zero, fl.pos)
		table.insert(fl.reserved, outward)
		makeArenaPad(ArenaKit.Polar(fl, 0, 0), 8, fl.folder)
		ArenaKit.Reserve(fl, ArenaKit.Polar(fl, 0, 0), 8.5)
		local tp = ArenaKit.Polar(fl, outward, fl.r - 6)
		makeTower(tp, 16, 1, ArenaKit.Polar(fl, 0, 0) - tp, fl.folder)
		ArenaKit.Reserve(fl, tp, 5)
		addLavaRuns(fl, 2)
		makeFlagstones(fl, 8.5, 30)
		makeLavaCracks(fl, 5, 9)
		dress(fl, 10, 3, 3, 2, 1)
		ArenaKit.AddPowerPad(fl.pos, powerPads)
	end

	-- Side pads next to the team bases
	for _, key in ipairs({ "padBL", "padBR", "padRL", "padRR" }) do
		local p = I[key]
		makeArenaPad(ArenaKit.Polar(p, 0, 0), 5, p.folder)
		ArenaKit.Reserve(p, ArenaKit.Polar(p, 0, 0), 5.5)
		addLavaRuns(p, 1)
		makeFlagstones(p, 5.5, 14)
		makeLavaCracks(p, 3, 6)
		dress(p, 6.5, 2, 2, 1, 0)
	end

	-- Sniper perches beside the mountain
	for _, key in ipairs({ "perchL", "perchR" }) do
		local pr = I[key]
		local outward = ArenaKit.AngleTo(Vector3.zero, pr.pos)
		table.insert(pr.reserved, outward)
		local tp = ArenaKit.Polar(pr, outward, pr.r - 4.5)
		makeTower(tp, 20, 1.1, ArenaKit.Polar(pr, 0, 0) - tp, pr.folder)
		ArenaKit.Reserve(pr, tp, 5)
		makeArenaPad(ArenaKit.Polar(pr, 0, 0), 3.5, pr.folder)
		ArenaKit.Reserve(pr, ArenaKit.Polar(pr, 0, 0), 4)
		makeFlagstones(pr, 4, 10)
		makeLavaCracks(pr, 3, 5)
		dress(pr, 5, 2, 2, 1, 0)
		ArenaKit.AddPowerPad(pr.pos, powerPads)
	end

	-- Scenery: distant floating rocks, towers and spires rising from the sea.
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = arena
	for i, d in ipairs(DECOR) do
		local folder = ArenaKit.MakeIslandBase(d.pos, d.r, "Decor" .. i, PALETTE, Enum.Material.Slate, scenery, STYLE)
		local isle = ArenaKit.NewIsle(d.pos, d.r, folder)
		if d.tower then
			makeTower(ArenaKit.Polar(isle, 0, 0), 12, 0.9, Vector3.new(-d.pos.X, 0, -d.pos.Z), folder)
			ArenaKit.Reserve(isle, ArenaKit.Polar(isle, 0, 0), 4)
		end
		propsAt(isle, 2, 3, d.r - 2, 2.2, function(p) makeSpire(p, 1, folder) end)
		makeLavaCracks(isle, 3, 2)
		if i % 2 == 0 then
			makeLavaRun(isle, ArenaKit.AngleTo(d.pos, Vector3.zero), d.r * 0.4, folder)
		end
	end
	for i = 1, 12 do
		local a = (i / 12) * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local dist = rng:NextNumber(230, 330)
		local h = rng:NextNumber(70, 140)
		local w = rng:NextNumber(14, 26)
		-- Jagged stacked spire: a crusted, still-glowing base and tapering
		-- basalt above, sitting in a ring of hot lava.
		local base = Vector3.new(math.cos(a) * dist, LAVA_SEA_Y - 2, math.sin(a) * dist)
		local y, ww = base.Y, w
		for k, frac in ipairs({ 0.42, 0.34, 0.24 }) do
			local hk = h * frac
			local cf = CFrame.new(base.X + rng:NextNumber(-1.5, 1.5), y + hk / 2, base.Z + rng:NextNumber(-1.5, 1.5))
				* CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(0, 6), rng:NextNumber(-0.08, 0.08))
			deco(NP("SeaSpire", Vector3.new(ww, hk, ww * 0.8), cf, k == 1 and crustShade() or rockShade(), k == 1 and Enum.Material.CrackedLava or Enum.Material.Basalt, scenery))
			if k == 2 then
				glowPart(NP("SeaSpireSeam", Vector3.new(0.7, hk * 0.8, 0.4), cf * CFrame.new(ww * 0.2, 0, -ww * 0.41), LAVA, Enum.Material.Neon, scenery))
			end
			y += hk * 0.92
			ww *= rng:NextNumber(0.62, 0.78)
		end
		hot(glowPart(DISC("SpireGlow", w * 1.9, 0.4, Vector3.new(base.X, LAVA_SEA_Y + 0.2, base.Z), LAVA_GLOW, Enum.Material.Neon, scenery)))
	end
	for i = 1, 26 do
		local a = rng:NextNumber(0, math.pi * 2)
		local dist = rng:NextNumber(150, 280)
		local p = Vector3.new(math.cos(a) * dist, rng:NextNumber(-40, 70), math.sin(a) * dist)
		local s = rng:NextNumber(3, 8)
		for k = 1, 3 do
			local off = Vector3.new(rng:NextNumber(-1, 1) * s * 0.4, -k * s * 0.35, rng:NextNumber(-1, 1) * s * 0.4)
			local size = Vector3.new(s * rng:NextNumber(0.8, 1.4), s * rng:NextNumber(0.8, 1.6), s * rng:NextNumber(0.8, 1.2))
			deco(NP("FloatRock", size, CFrame.new(p + off) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)), rockShade(), Enum.Material.Basalt, scenery))
		end
		if i % 3 == 0 then
			glowPart(NP("FloatSeam", Vector3.new(0.4, s, 0.3), CFrame.new(p) * CFrame.Angles(0, a, 0.3), LAVA, Enum.Material.Neon, scenery))
		end
	end

	-- Lava sea: a molten glow underneath, brighter hot patches, and drifting
	-- plates of cooled crust (CrackedLava) with glowing lava showing between.
	-- LavaFX (client) drifts the crust, pulses the hot spots and pops bubbles.
	glowPart(DISC("LavaSea", 1400, 2, Vector3.new(0, LAVA_SEA_Y - 1, 0), Color3.fromRGB(255, 96, 22), Enum.Material.Neon, scenery))
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(30, 460)
		hot(glowPart(DISC("HotPatch", rng:NextNumber(20, 60), 0.3, Vector3.new(math.cos(a) * d, LAVA_SEA_Y + 0.05, math.sin(a) * d), LAVA_GLOW, Enum.Material.Neon, scenery)))
	end
	local function nearFall(p: Vector3, r: number): boolean
		for _, s in ipairs(FALL_SPOTS) do
			if (Vector3.new(s.X, 0, s.Z) - p).Magnitude < r then
				return true
			end
		end
		return false
	end
	local function crust(size: Vector3, cf: CFrame)
		local plate = deco(NP("Crust", size, cf, crustShade(), Enum.Material.CrackedLava, scenery))
		plate.CastShadow = false
		CollectionService:AddTag(plate, "LavaCrust")
	end
	local SPACING = 60
	for gx = -8, 8 do
		for gz = -8, 8 do
			local c = Vector3.new(gx * SPACING + rng:NextNumber(-10, 10), 0, gz * SPACING + rng:NextNumber(-10, 10))
			if c.Magnitude < 480 and not nearFall(c, 24) then
				local size = Vector3.new(rng:NextNumber(34, 52), rng:NextNumber(1.2, 2.2), rng:NextNumber(26, 46))
				local cf = CFrame.new(c.X, LAVA_SEA_Y + 0.5, c.Z) * CFrame.Angles(rng:NextNumber(-0.02, 0.02), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.02, 0.02))
				crust(size, cf)
				if rng:NextNumber() < 0.7 then
					local sub = Vector3.new(size.X * rng:NextNumber(0.45, 0.7), size.Y * 0.9, size.Z * rng:NextNumber(0.45, 0.7))
					crust(sub, cf * CFrame.new(rng:NextNumber(-0.5, 0.5) * size.X, 0.2, rng:NextNumber(-0.5, 0.5) * size.Z) * CFrame.Angles(0, rng:NextNumber(0.3, 1.2), 0))
				end
			end
		end
	end
	for _ = 1, 60 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(20, 470)
		local p = Vector3.new(math.cos(a) * d, LAVA_SEA_Y + 0.4, math.sin(a) * d)
		if not nearFall(p, 16) then
			crust(Vector3.new(rng:NextNumber(6, 14), rng:NextNumber(0.8, 1.4), rng:NextNumber(5, 12)), CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0))
		end
	end
	local seaVent = marker("LavaSeaVent", Vector3.new(0, LAVA_SEA_Y + 0.6, 0), scenery)
	seaVent:SetAttribute("Radius", 470)
	seaVent:SetAttribute("SurfaceY", LAVA_SEA_Y + 0.4)
	seaVent:SetAttribute("Sea", true)
	CollectionService:AddTag(seaVent, "LavaVent")
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local d = rng:NextNumber(90, 230)
		local src = marker("LavaHaze", Vector3.new(math.cos(a) * d, LAVA_SEA_Y + 1, math.sin(a) * d), scenery)
		local haze = smokeEmitter(src, 1.2, 16, 46, 16, 6)
		haze.Color = ColorSequence.new(Color3.fromRGB(120, 64, 56), Color3.fromRGB(52, 36, 40))
		haze.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		emberEmitter(src, 7, 14, 60)
	end

	-- Smoky haze drifting between the platforms and the sea, dusk sky.
	ArenaKit.MakeCloudBank(arena, Color3.fromRGB(96, 64, 62), 38, -66, -36, 50, 320, 0.45)
	ArenaKit.MakeCloudBank(arena, Color3.fromRGB(62, 46, 52), 14, 80, 115, 120, 320, 0.5)
	ArenaKit.ApplyAtmosphere({
		Density = 0.42, Offset = 0.2,
		Color = Color3.fromRGB(170, 82, 60), Decay = Color3.fromRGB(80, 30, 30),
		Glare = 0, Haze = 2.6,
		Ambient = Color3.fromRGB(128, 82, 72), OutdoorAmbient = Color3.fromRGB(168, 104, 88),
		ClockTime = 17.9, FogColor = Color3.fromRGB(96, 44, 34), FogEnd = 1300,
		Brightness = 1.6,
		HideCelestial = true,
	})
	arena:SetAttribute("SpawnCount", #spawns:GetChildren())
	return arena
end

return Volcano
