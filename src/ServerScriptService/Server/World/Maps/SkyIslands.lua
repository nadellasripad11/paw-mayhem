--!strict
-- Map 1/3 — Sky Islands. A tight cluster of grassy floating islands stepping
-- down from a windmill hill: stone stairs to fountain plazas, rope bridges to
-- the flanks, cottages, round bushy trees, streams spilling into waterfalls
-- and a sea of clouds below. Point-symmetric so Blue and Red play the same map.

local Workspace = game:GetService("Workspace")
local ArenaKit = require(script.Parent.Parent.ArenaKit)

local SkyIslands = { Id = "SkyIslands", Name = "Sky Islands" }

local PALETTE: ArenaKit.Palette = {
	Top = Color3.fromRGB(108, 188, 74), TopDark = Color3.fromRGB(80, 158, 60),
	Stone = Color3.fromRGB(158, 136, 118), StoneDark = Color3.fromRGB(100, 86, 88),
	Wood = Color3.fromRGB(164, 114, 68), WoodDark = Color3.fromRGB(104, 68, 42),
}
local STYLE: ArenaKit.IslandStyle = { cliffMaterial = Enum.Material.Slate, drip = Color3.fromRGB(86, 164, 62) }

local LEAVES = { Color3.fromRGB(58, 146, 58), Color3.fromRGB(82, 170, 64), Color3.fromRGB(122, 198, 80) }
local PINE = { Color3.fromRGB(44, 116, 62), Color3.fromRGB(58, 136, 70) }
local TRUNK = Color3.fromRGB(122, 84, 54)
local TRUNK_DARK = Color3.fromRGB(92, 62, 42)
local WATER = Color3.fromRGB(118, 204, 242)
local FOAM = Color3.fromRGB(232, 248, 255)
local COBBLE = Color3.fromRGB(184, 176, 162)
local COBBLE_DARK = Color3.fromRGB(142, 136, 126)
local STONE_WALL = Color3.fromRGB(196, 186, 168)
local PLASTER = Color3.fromRGB(240, 228, 204)
local ROOF = Color3.fromRGB(184, 74, 56)
local ROOF_DARK = Color3.fromRGB(148, 58, 46)
local ROPE = Color3.fromRGB(150, 118, 84)
local IRON = Color3.fromRGB(58, 56, 60)
local LAMP = Color3.fromRGB(255, 214, 140)
local TEAM_COLOR = { Blue = Color3.fromRGB(64, 160, 255), Red = Color3.fromRGB(240, 72, 72) }
local FLOWERS = {
	Color3.fromRGB(255, 132, 190), Color3.fromRGB(255, 222, 84), Color3.fromRGB(196, 140, 255),
	Color3.fromRGB(255, 110, 96), Color3.fromRGB(250, 250, 250),
}

-- ── Layout (point-symmetric: Blue at -Z, Red at +Z) ─────────────────────────
local LAYOUT = {
	center = { pos = Vector3.new(0, 20, 0), r = 32 },
	plazaB = { pos = Vector3.new(0, 13, -70), r = 24 },
	plazaR = { pos = Vector3.new(0, 13, 70), r = 24 },
	teamB = { pos = Vector3.new(0, 7, -134), r = 28, team = "Blue" },
	teamR = { pos = Vector3.new(0, 7, 134), r = 28, team = "Red" },
	flankBL = { pos = Vector3.new(-68, 14, -40), r = 20 },
	flankBR = { pos = Vector3.new(68, 14, -40), r = 20 },
	flankRL = { pos = Vector3.new(-68, 14, 40), r = 20 },
	flankRR = { pos = Vector3.new(68, 14, 40), r = 20 },
	millL = { pos = Vector3.new(-86, 17, 0), r = 16 },
	millR = { pos = Vector3.new(86, 17, 0), r = 16 },
	padBL = { pos = Vector3.new(-52, 9, -114), r = 14 },
	padBR = { pos = Vector3.new(52, 9, -114), r = 14 },
	padRL = { pos = Vector3.new(-52, 9, 114), r = 14 },
	padRR = { pos = Vector3.new(52, 9, 114), r = 14 },
}
local LINKS = {
	{ "center", "plazaB", "stairs" }, { "center", "plazaR", "stairs" },
	{ "plazaB", "teamB", "bridge" }, { "plazaR", "teamR", "bridge" },
	{ "center", "flankBL", "bridge" }, { "center", "flankBR", "bridge" },
	{ "center", "flankRL", "bridge" }, { "center", "flankRR", "bridge" },
	{ "plazaB", "flankBL", "bridge" }, { "plazaB", "flankBR", "bridge" },
	{ "plazaR", "flankRL", "bridge" }, { "plazaR", "flankRR", "bridge" },
	{ "flankBL", "millL", "bridge" }, { "flankRL", "millL", "bridge" },
	{ "flankBR", "millR", "bridge" }, { "flankRR", "millR", "bridge" },
	{ "teamB", "padBL", "bridge" }, { "teamB", "padBR", "bridge" },
	{ "teamR", "padRL", "bridge" }, { "teamR", "padRR", "bridge" },
	{ "padBL", "plazaB", "bridge" }, { "padBR", "plazaB", "bridge" },
	{ "padRL", "plazaR", "bridge" }, { "padRR", "plazaR", "bridge" },
}
-- Unreachable scenery islands out in the sky.
local DECOR = {
	{ pos = Vector3.new(-150, 30, -60), r = 10, kind = "mill" },
	{ pos = Vector3.new(150, 26, 60), r = 10, kind = "mill" },
	{ pos = Vector3.new(-172, 8, 42), r = 13, kind = "house" },
	{ pos = Vector3.new(172, 12, -42), r = 13, kind = "house" },
	{ pos = Vector3.new(-124, 46, 112), r = 8, kind = "trees" },
	{ pos = Vector3.new(124, 42, -112), r = 8, kind = "trees" },
	{ pos = Vector3.new(-112, -8, -176), r = 12, kind = "trees" },
	{ pos = Vector3.new(112, -6, 176), r = 12, kind = "trees" },
	{ pos = Vector3.new(-204, 22, -132), r = 9, kind = "trees" },
	{ pos = Vector3.new(204, 18, 132), r = 9, kind = "trees" },
	{ pos = Vector3.new(0, 52, -214), r = 9, kind = "house" },
	{ pos = Vector3.new(0, 48, 214), r = 9, kind = "house" },
	{ pos = Vector3.new(-200, 50, 20), r = 7, kind = "trees" },
	{ pos = Vector3.new(200, 54, -20), r = 7, kind = "trees" },
}

local rng = Random.new(20260922)
local NP = ArenaKit.NewPart
local DISC = ArenaKit.NewDisc

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	return p
end

local function ball(name: string, d: number, pos: Vector3, color: Color3, parent: Instance): BasePart
	local p = NP(name, Vector3.new(d, d, d), CFrame.new(pos), color, Enum.Material.SmoothPlastic, parent)
	p.Shape = Enum.PartType.Ball
	p.CanCollide = false
	return p
end

local function faceYaw(dir: Vector3): number
	return math.atan2(-dir.X, -dir.Z)
end

-- ── Foliage ──────────────────────────────────────────────────────────────────

local function makeTree(pos: Vector3, s: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Tree"
	m.Parent = parent
	local h = 5.6 * s
	NP("Trunk", Vector3.new(1.3 * s, h, 1.3 * s), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), TRUNK, Enum.Material.Wood, m)
	deco(NP("Roots", Vector3.new(2.3 * s, 0.7 * s, 2.3 * s), CFrame.new(pos + Vector3.new(0, 0.3 * s, 0)) * CFrame.Angles(0, math.rad(45), 0), TRUNK_DARK, Enum.Material.Wood, m))
	local top = pos + Vector3.new(0, h + 1.9 * s, 0)
	ball("Crown", 7.4 * s, top, LEAVES[2], m)
	for k = 1, 4 do
		local a = k * math.pi / 2 + rng:NextNumber(-0.45, 0.45)
		ball("Leaf" .. k, rng:NextNumber(4.2, 5.6) * s, top + Vector3.new(math.cos(a) * 3 * s, rng:NextNumber(-1.3, 0.3) * s, math.sin(a) * 3 * s), LEAVES[rng:NextInteger(1, 2)], m)
	end
	ball("Top", 4.8 * s, top + Vector3.new(rng:NextNumber(-0.6, 0.6) * s, 2.7 * s, rng:NextNumber(-0.6, 0.6) * s), LEAVES[3], m)
end

local function makePine(pos: Vector3, s: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Pine"
	m.Parent = parent
	NP("Trunk", Vector3.new(1.1 * s, 3.4 * s, 1.1 * s), CFrame.new(pos + Vector3.new(0, 1.7 * s, 0)), TRUNK_DARK, Enum.Material.Wood, m)
	for k = 0, 3 do
		deco(DISC("Tier" .. k, (7.2 - k * 1.6) * s, 2.3 * s, pos + Vector3.new(0, (3.6 + k * 2.0) * s, 0), PINE[k % 2 + 1], Enum.Material.SmoothPlastic, m))
	end
	ball("Tip", 1.4 * s, pos + Vector3.new(0, 11.4 * s, 0), PINE[2], m)
end

local function makeBush(pos: Vector3, parent: Instance)
	for k = 1, 3 do
		local d = rng:NextNumber(2.2, 3.4)
		local a = k * 2.1 + rng:NextNumber(0, 0.8)
		ball("Bush", d, pos + Vector3.new(math.cos(a) * 1.1, d * 0.3, math.sin(a) * 1.1), LEAVES[rng:NextInteger(1, 3)], parent).CastShadow = false
	end
end

local function makeFlowers(pos: Vector3, parent: Instance)
	ball("FlowerLeaves", 1.8, pos + Vector3.new(0, 0.35, 0), LEAVES[1], parent).CastShadow = false
	local col = FLOWERS[rng:NextInteger(1, #FLOWERS)]
	for _ = 1, 4 do
		local off = Vector3.new(rng:NextNumber(-1.2, 1.2), rng:NextNumber(0.5, 0.9), rng:NextNumber(-1.2, 1.2))
		ball("Bloom", 0.62, pos + off, col, parent).CastShadow = false
	end
end

local function makeRock(pos: Vector3, s: number, parent: Instance)
	for k = 1, 2 do
		local sz = Vector3.new(rng:NextNumber(1.8, 3.2), rng:NextNumber(1.2, 2.2), rng:NextNumber(1.6, 2.8)) * s
		local cf = CFrame.new(pos + Vector3.new((k - 1.5) * 1.2 * s, sz.Y * 0.25, rng:NextNumber(-0.5, 0.5) * s))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3))
		deco(NP("Rock", sz, cf, Color3.fromRGB(150, 144, 136):Lerp(Color3.fromRGB(118, 112, 110), rng:NextNumber()), Enum.Material.Slate, parent))
	end
end

-- ── Props ────────────────────────────────────────────────────────────────────

local function makeCrate(pos: Vector3, s: number, yaw: number, parent: Instance)
	local cf = CFrame.new(pos + Vector3.new(0, 1.8 * s, 0)) * CFrame.Angles(0, yaw, 0)
	NP("Crate", Vector3.new(3.6, 3.6, 3.6) * s, cf, Color3.fromRGB(176, 124, 72), Enum.Material.WoodPlanks, parent)
	for _, y in ipairs({ -1.45, 1.45 }) do
		deco(NP("Band", Vector3.new(3.75, 0.5, 3.75) * s, cf * CFrame.new(0, y * s, 0), PALETTE.WoodDark, Enum.Material.Wood, parent))
	end
	deco(NP("Cross", Vector3.new(0.45, 4.6, 0.3) * s, cf * CFrame.new(0, 0, -1.84 * s) * CFrame.Angles(0, 0, math.rad(45)), PALETTE.WoodDark, Enum.Material.Wood, parent))
end

local function makeCrateStack(pos: Vector3, parent: Instance)
	local yaw = rng:NextNumber(0, 6.28)
	makeCrate(pos, 1, yaw, parent)
	makeCrate(pos + Vector3.new(3.9 * math.cos(yaw), 0, 3.9 * math.sin(yaw)), 0.85, yaw + 0.3, parent)
	makeCrate(pos + Vector3.new(0, 3.6, 0), 0.75, yaw + 0.5, parent)
end

local function makeBarrel(pos: Vector3, parent: Instance)
	DISC("Barrel", 2.4, 3, pos + Vector3.new(0, 1.5, 0), Color3.fromRGB(150, 100, 58), Enum.Material.WoodPlanks, parent)
	for _, y in ipairs({ 0.5, 2.5 }) do
		deco(DISC("Hoop", 2.55, 0.28, pos + Vector3.new(0, y, 0), IRON, Enum.Material.Metal, parent))
	end
	deco(DISC("Lid", 2.1, 0.1, pos + Vector3.new(0, 3.02, 0), Color3.fromRGB(180, 130, 80), Enum.Material.Wood, parent))
end

local function makeLamp(pos: Vector3, parent: Instance)
	NP("LampBase", Vector3.new(1.4, 1, 1.4), CFrame.new(pos + Vector3.new(0, 0.5, 0)), STONE_WALL, Enum.Material.Slate, parent)
	deco(NP("LampPole", Vector3.new(0.45, 7, 0.45), CFrame.new(pos + Vector3.new(0, 4.5, 0)), IRON, Enum.Material.Metal, parent))
	deco(NP("LampCap", Vector3.new(1.6, 0.4, 1.6), CFrame.new(pos + Vector3.new(0, 9.9, 0)), IRON, Enum.Material.Metal, parent))
	local glow = deco(NP("Lantern", Vector3.new(1.1, 1.3, 1.1), CFrame.new(pos + Vector3.new(0, 9.1, 0)), LAMP, Enum.Material.Neon, parent))
	glow.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Range = 16
	light.Brightness = 0.8
	light.Parent = glow
end

local function makeBench(pos: Vector3, yaw: number, parent: Instance)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	deco(NP("Seat", Vector3.new(4.4, 0.35, 1.3), cf * CFrame.new(0, 1.2, 0), PALETTE.Wood, Enum.Material.WoodPlanks, parent))
	deco(NP("Back", Vector3.new(4.4, 1.1, 0.3), cf * CFrame.new(0, 2, 0.6), PALETTE.Wood, Enum.Material.WoodPlanks, parent))
	for _, x in ipairs({ -1.8, 1.8 }) do
		deco(NP("Leg", Vector3.new(0.4, 1.1, 1.2), cf * CFrame.new(x, 0.55, 0), STONE_WALL, Enum.Material.Slate, parent))
	end
end

local function makeBanner(pos: Vector3, color: Color3, yaw: number, parent: Instance)
	local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	NP("BannerPole", Vector3.new(0.5, 11, 0.5), cf * CFrame.new(0, 5.5, 0), PALETTE.WoodDark, Enum.Material.Wood, parent)
	deco(NP("BannerBar", Vector3.new(4.2, 0.35, 0.35), cf * CFrame.new(0, 10.3, -0.35), PALETTE.WoodDark, Enum.Material.Wood, parent))
	deco(NP("Banner", Vector3.new(3.6, 5.2, 0.15), cf * CFrame.new(0, 7.5, -0.4), color, Enum.Material.Fabric, parent))
	local tip = ball("BannerTip", 0.8, (cf * CFrame.new(0, 11.3, 0)).Position, Color3.fromRGB(255, 214, 80), parent)
	tip.Material = Enum.Material.Neon
end

-- Flush cobble disc with a darker rim and a ring of paving blocks.
local function makePlaza(center: Vector3, radius: number, parent: Instance, rim: Color3?)
	deco(DISC("PlazaRim", radius * 2 + 1.4, 0.24, center + Vector3.new(0, 0.07, 0), rim or COBBLE_DARK, Enum.Material.Slate, parent))
	deco(DISC("Plaza", radius * 2, 0.24, center + Vector3.new(0, 0.1, 0), COBBLE, Enum.Material.Cobblestone, parent))
	local n = math.floor(radius * 1.6)
	for i = 1, n do
		local a = i / n * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * (radius - 1.2), 0.2, math.sin(a) * (radius - 1.2))
		deco(NP("Paver", Vector3.new(1.3, 0.22, 2 * math.pi * radius / n * 0.9), CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))), COBBLE_DARK, Enum.Material.Slate, parent))
	end
end

-- Cobble tiles from `from` to `to` (surface level).
local function makePath(from: Vector3, to: Vector3, parent: Instance)
	local len = (to - from).Magnitude
	local n = math.floor(len / 2.5)
	for i = 0, n do
		local p = from:Lerp(to, i / math.max(1, n)) + Vector3.new(0, 0.12, 0)
		local cf = CFrame.lookAt(p, p + (to - from)) * CFrame.Angles(0, rng:NextNumber(-0.12, 0.12), 0)
		deco(NP("PathStone", Vector3.new(rng:NextNumber(3.4, 4.2), 0.2, 2.0), cf, COBBLE:Lerp(COBBLE_DARK, rng:NextNumber(0, 0.6)), Enum.Material.Slate, parent))
	end
end

-- Wooden fence arcs around the rim, skipping walkways.
local function makeRimFence(isle: any, parent: Instance)
	local r = isle.r - 1.4
	local step = math.rad(360 / math.max(16, math.floor(2 * math.pi * r / 5)))
	local prev: Vector3? = nil
	for a = 0, math.pi * 2 + step * 0.5, step do
		if ArenaKit.Blocked(isle, a, r, 5.5) then
			prev = nil
		else
			local p = ArenaKit.Polar(isle, a, r)
			deco(NP("FencePost", Vector3.new(0.5, 3, 0.5), CFrame.new(p + Vector3.new(0, 1.5, 0)), PALETTE.WoodDark, Enum.Material.Wood, parent))
			if prev then
				for _, y in ipairs({ 1.1, 2.3 }) do
					ArenaKit.Beam("FenceRail", prev + Vector3.new(0, y, 0), p + Vector3.new(0, y, 0), 0.32, PALETTE.Wood, Enum.Material.Wood, parent)
				end
			end
			prev = p
		end
	end
end

-- ── Buildings ────────────────────────────────────────────────────────────────

local function makeCottage(pos: Vector3, facing: Vector3, s: number, roofColor: Color3, parent: Instance)
	local f = Instance.new("Model")
	f.Name = "Cottage"
	f.Parent = parent
	local base = CFrame.new(pos) * CFrame.Angles(0, faceYaw(facing), 0)
	local w, d, h = 9 * s, 7.6 * s, 6 * s
	NP("Foundation", Vector3.new(w + 0.8, 1, d + 0.8), base * CFrame.new(0, 0.5, 0), STONE_WALL, Enum.Material.Slate, f)
	NP("Walls", Vector3.new(w, h, d), base * CFrame.new(0, 1 + h / 2, 0), PLASTER, Enum.Material.SmoothPlastic, f)
	for _, x in ipairs({ -w / 2, w / 2 }) do
		for _, z in ipairs({ -d / 2, d / 2 }) do
			deco(NP("Post", Vector3.new(0.6, h, 0.6), base * CFrame.new(x, 1 + h / 2, z), PALETTE.WoodDark, Enum.Material.Wood, f))
		end
	end
	deco(NP("Beam", Vector3.new(w + 0.3, 0.5, d + 0.3), base * CFrame.new(0, 1 + h * 0.52, 0), PALETTE.WoodDark, Enum.Material.Wood, f))
	-- 45° pitched roof: a box turned 45° about X fills both gables exactly,
	-- and two tilted slabs form the roof planes.
	local wallTop = 1 + h
	local roofH = d / 2
	local sq = d / math.sqrt(2)
	deco(NP("Gables", Vector3.new(w - 0.1, sq, sq), base * CFrame.new(0, wallTop, 0) * CFrame.Angles(math.rad(45), 0, 0), PLASTER, Enum.Material.SmoothPlastic, f))
	local ridge = Vector3.new(0, wallTop + roofH, 0)
	for _, side in ipairs({ 1, -1 }) do
		local eave = Vector3.new(0, wallTop, side * d / 2)
		local dir = (eave - ridge).Unit
		local normal = Vector3.new(0, 1, side).Unit
		local len = (eave - ridge).Magnitude + 1.3
		local c = (ridge + eave) / 2 + dir * 0.6 + normal * 0.28
		local wc = base:PointToWorldSpace(c)
		NP("Roof", Vector3.new(w + 1.4, 0.55, len), CFrame.lookAt(wc, wc + base:VectorToWorldSpace(dir), base:VectorToWorldSpace(normal)), roofColor, Enum.Material.Slate, f)
	end
	deco(NP("Ridge", Vector3.new(w + 1.6, 0.6, 0.8), base * CFrame.new(0, wallTop + roofH + 0.35, 0), roofColor:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Slate, f))
	NP("Chimney", Vector3.new(1.4, 3.6, 1.4) * s, base * CFrame.new(w * 0.28, wallTop + roofH * 0.7, d * 0.15), Color3.fromRGB(150, 104, 90), Enum.Material.Brick, f)
	-- Front (-Z) door, windows, flower boxes
	deco(NP("DoorFrame", Vector3.new(2.6, 4.2, 0.3) * s, base * CFrame.new(0, 1 + 2.1 * s, -d / 2 - 0.1), PALETTE.WoodDark, Enum.Material.Wood, f))
	deco(NP("Door", Vector3.new(2.0, 3.8, 0.3) * s, base * CFrame.new(0, 1 + 1.9 * s, -d / 2 - 0.2), Color3.fromRGB(132, 84, 50), Enum.Material.WoodPlanks, f))
	for _, x in ipairs({ -w * 0.3, w * 0.3 }) do
		deco(NP("WinFrame", Vector3.new(2.1, 2.1, 0.3) * s, base * CFrame.new(x, 1 + h * 0.62, -d / 2 - 0.1), PALETTE.WoodDark, Enum.Material.Wood, f))
		local glass = deco(NP("Window", Vector3.new(1.6, 1.6, 0.3) * s, base * CFrame.new(x, 1 + h * 0.62, -d / 2 - 0.18), Color3.fromRGB(150, 214, 250), Enum.Material.Glass, f))
		glass.Transparency = 0.15
		deco(NP("FlowerBox", Vector3.new(2.3, 0.6, 0.7) * s, base * CFrame.new(x, 1 + h * 0.62 - 1.35 * s, -d / 2 - 0.4), PALETTE.Wood, Enum.Material.Wood, f))
		for k = -1, 1 do
			ball("BoxBloom", 0.55 * s, (base * CFrame.new(x + k * 0.7 * s, 1 + h * 0.62 - 0.9 * s, -d / 2 - 0.45)).Position, FLOWERS[rng:NextInteger(1, #FLOWERS)], f).CastShadow = false
		end
	end
	for _, x in ipairs({ -w / 2 - 0.1, w / 2 + 0.1 }) do
		local glass = deco(NP("SideWindow", Vector3.new(0.3, 1.6, 1.6) * s, base * CFrame.new(x, 1 + h * 0.62, 0), Color3.fromRGB(150, 214, 250), Enum.Material.Glass, f))
		glass.Transparency = 0.15
	end
end

-- Round stone-and-plaster windmill with a conical roof and turning lattice sails.
local function makeWindmill(pos: Vector3, facing: Vector3, s: number, parent: Instance)
	local f = Instance.new("Model")
	f.Name = "Windmill"
	f.Parent = parent
	local base = CFrame.new(pos) * CFrame.Angles(0, faceYaw(facing), 0)
	local function at(y: number, z: number?): Vector3
		return (base * CFrame.new(0, y * s, (z or 0) * s)).Position
	end
	deco(DISC("Plinth", 13 * s, 0.5, at(0.1), STONE_WALL, Enum.Material.Slate, f))
	DISC("StoneTower", 10 * s, 10 * s, at(1 + 5), Color3.fromRGB(176, 166, 150), Enum.Material.Cobblestone, f)
	deco(DISC("Band", 10.8 * s, 0.8 * s, at(11), PALETTE.WoodDark, Enum.Material.Wood, f))
	deco(DISC("Balcony", 13 * s, 0.4 * s, at(11.5), PALETTE.Wood, Enum.Material.WoodPlanks, f))
	local prev: Vector3? = nil
	for i = 0, 12 do
		local a = i / 12 * math.pi * 2
		local p = (base * CFrame.new(math.cos(a) * 6.2 * s, 11.7 * s, math.sin(a) * 6.2 * s)).Position
		deco(NP("RailPost", Vector3.new(0.3, 1.6, 0.3) * s, CFrame.new(p + Vector3.new(0, 0.8 * s, 0)), PALETTE.WoodDark, Enum.Material.Wood, f))
		if prev then
			ArenaKit.Beam("Rail", prev + Vector3.new(0, 1.5 * s, 0), p + Vector3.new(0, 1.5 * s, 0), 0.25 * s, PALETTE.Wood, Enum.Material.Wood, f)
		end
		prev = p
	end
	DISC("UpperTower", 8.6 * s, 8 * s, at(12 + 4), PLASTER, Enum.Material.SmoothPlastic, f)
	for k = 0, 5 do
		deco(DISC("Roof" .. k, (9.8 - k * 1.6) * s, 1.4 * s, at(20.7 + k * 1.35), k % 2 == 0 and ROOF or ROOF_DARK, Enum.Material.Slate, f))
	end
	ball("Finial", 1.2 * s, at(29.2), Color3.fromRGB(230, 190, 90), f).Material = Enum.Material.Metal
	-- Door and windows on the facing side
	deco(NP("Door", Vector3.new(2.6, 4.4, 0.5) * s, base * CFrame.new(0, (1 + 2.2) * s, -5 * s), PALETTE.WoodDark, Enum.Material.WoodPlanks, f))
	for _, spec in ipairs({ { 0, 8, -5 }, { 0, 16.5, -4.3 }, { 3.2, 15.5, -3.1 }, { -3.2, 15.5, -3.1 } }) do
		local p = base * CFrame.new(spec[1] * s, spec[2] * s, spec[3] * s)
		local cf = CFrame.lookAt(p.Position, p.Position + (p.Position - at(spec[2])))
		deco(NP("WinFrame", Vector3.new(1.9, 2.2, 0.4) * s, cf, PALETTE.WoodDark, Enum.Material.Wood, f))
		local g = deco(NP("Window", Vector3.new(1.4, 1.7, 0.45) * s, cf, Color3.fromRGB(150, 214, 250), Enum.Material.Glass, f))
		g.Transparency = 0.15
	end

	-- Sails: welded to an anchored hub so only the hub's CFrame replicates.
	local hubCF = base * CFrame.new(0, 18.5 * s, -7.6 * s)
	ArenaKit.Beam("Shaft", at(18.5, -3.5), hubCF.Position, 0.9 * s, PALETTE.WoodDark, Enum.Material.Wood, f)
	local hub = NP("Hub", Vector3.new(1.8, 1.8, 1.6) * s, hubCF, PALETTE.WoodDark, Enum.Material.Wood, f)
	hub.CanCollide = false
	local sailParts = {}
	local function sp(p: BasePart)
		p.CanCollide = false
		p.Anchored = false
		p.Massless = true
		table.insert(sailParts, p)
	end
	for i = 0, 3 do
		local th = i * math.pi / 2 + math.rad(20)
		local dir = Vector3.new(math.cos(th), math.sin(th), 0)
		local side = Vector3.new(-math.sin(th), math.cos(th), 0)
		local function L(v: Vector3): Vector3
			return hubCF:PointToWorldSpace(v)
		end
		sp(ArenaKit.Beam("Arm", L(Vector3.zero), L(dir * 12 * s), 0.6 * s, PALETTE.WoodDark, Enum.Material.Wood, f))
		sp(ArenaKit.Beam("Frame", L(dir * 2.6 * s + side * 3 * s - Vector3.new(0, 0, 0.1)), L(dir * 11.6 * s + side * 3 * s - Vector3.new(0, 0, 0.1)), 0.3 * s, PALETTE.WoodDark, Enum.Material.Wood, f))
		for k = 0, 5 do
			local t = (2.6 + k * 1.8) * s
			sp(ArenaKit.Beam("Slat", L(dir * t - Vector3.new(0, 0, 0.1)), L(dir * t + side * 3 * s - Vector3.new(0, 0, 0.1)), 0.25 * s, PALETTE.Wood, Enum.Material.Wood, f))
		end
		local cloth = NP("Sail", Vector3.new(2.8 * s, 9 * s, 0.12), CFrame.fromMatrix(L(dir * 7.1 * s + side * 1.5 * s - Vector3.new(0, 0, 0.2)), hubCF:VectorToWorldSpace(side), hubCF:VectorToWorldSpace(dir)), Color3.fromRGB(250, 246, 236), Enum.Material.Fabric, f)
		cloth.Transparency = 0.08
		sp(cloth)
	end
	for _, p in ipairs(sailParts) do
		local w = Instance.new("WeldConstraint")
		w.Part0 = hub
		w.Part1 = p
		w.Parent = p
	end
	task.spawn(function()
		local a = 0
		while hub.Parent do
			a += 0.02
			hub.CFrame = hubCF * CFrame.Angles(0, 0, a)
			task.wait(1 / 30)
		end
	end)
end

-- Tiered stone fountain with a water curtain.
local function makeFountain(pos: Vector3, parent: Instance)
	DISC("Basin", 12, 1.3, pos + Vector3.new(0, 0.65, 0), STONE_WALL, Enum.Material.Slate, parent)
	local pool = deco(DISC("Pool", 10.4, 0.1, pos + Vector3.new(0, 1.33, 0), WATER, Enum.Material.Glass, parent))
	pool.Transparency = 0.15
	for i = 1, 16 do
		local a = i / 16 * math.pi * 2
		local p = pos + Vector3.new(math.cos(a) * 5.6, 1.5, math.sin(a) * 5.6)
		deco(NP("BasinLip", Vector3.new(1, 0.5, 2.4), CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))), COBBLE, Enum.Material.Slate, parent))
	end
	DISC("Pedestal", 2, 3.2, pos + Vector3.new(0, 2.9, 0), STONE_WALL, Enum.Material.Slate, parent)
	deco(DISC("Bowl", 5.4, 0.7, pos + Vector3.new(0, 4.6, 0), COBBLE, Enum.Material.Slate, parent))
	deco(DISC("BowlWater", 4.8, 0.12, pos + Vector3.new(0, 4.98, 0), WATER, Enum.Material.Glass, parent)).Transparency = 0.15
	local curtain = deco(DISC("Curtain", 5, 3.2, pos + Vector3.new(0, 2.95, 0), FOAM, Enum.Material.Glass, parent))
	curtain.Transparency = 0.55
	curtain.CastShadow = false
	deco(DISC("Pedestal2", 1.1, 1.8, pos + Vector3.new(0, 5.8, 0), STONE_WALL, Enum.Material.Slate, parent))
	deco(DISC("Bowl2", 2.8, 0.45, pos + Vector3.new(0, 6.8, 0), COBBLE, Enum.Material.Slate, parent))
	local spout = ball("Spout", 1.3, pos + Vector3.new(0, 7.5, 0), FOAM, parent)
	spout.Material = Enum.Material.Glass
	spout.Transparency = 0.2
end

-- Stream across the top that spills off the edge as a waterfall.
local function makeWaterfall(isle: any, angle: number, height: number, parent: Instance)
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local from = ArenaKit.Polar(isle, angle, isle.r * 0.5)
	local lip = ArenaKit.Polar(isle, angle, isle.r + 0.2)
	local len = (lip - from).Magnitude
	deco(NP("StreamBank", Vector3.new(6, 0.22, len), CFrame.lookAt((from + lip) / 2 + Vector3.new(0, 0.08, 0), lip + Vector3.new(0, 0.08, 0)), COBBLE_DARK, Enum.Material.Slate, parent))
	local stream = deco(NP("Stream", Vector3.new(4.4, 0.25, len), CFrame.lookAt((from + lip) / 2 + Vector3.new(0, 0.14, 0), lip + Vector3.new(0, 0.14, 0)), WATER, Enum.Material.Glass, parent))
	stream.Transparency = 0.12
	local edge = lip + out * 0.9
	local sheet = deco(NP("Fall", Vector3.new(4.8, height, 1.2), CFrame.lookAt(edge - Vector3.new(0, height / 2 - 0.3, 0), edge - Vector3.new(0, height / 2 - 0.3, 0) + out), WATER, Enum.Material.Glass, parent))
	sheet.Transparency = 0.18
	sheet.CastShadow = false
	local foam = deco(NP("FallFoam", Vector3.new(5.4, 1.2, 1.8), CFrame.lookAt(edge + Vector3.new(0, 0.1, 0), edge + Vector3.new(0, 0.1, 0) + out), FOAM, Enum.Material.SmoothPlastic, parent))
	foam.CastShadow = false
	local mist = deco(NP("FallMist", Vector3.new(6.5, height * 0.5, 2.6), CFrame.lookAt(edge - Vector3.new(0, height * 0.72, 0), edge - Vector3.new(0, height * 0.72, 0) + out), FOAM, Enum.Material.SmoothPlastic, parent))
	mist.Transparency = 0.62
	mist.CastShadow = false
end

-- ── Connections ──────────────────────────────────────────────────────────────

-- Rope bridge: invisible smooth collision deck + side guards, visual planks,
-- stringers, posts, rope rails and end lanterns.
local function makeRopeBridge(A: any, B: any, parent: Instance)
	local f = Instance.new("Folder")
	f.Name = "RopeBridge"
	f.Parent = parent
	local a, b = ArenaKit.WalkwayCollision(A, B, f, 5.8, 1.2)
	local span = (b - a).Magnitude
	local dir = (b - a).Unit
	local right = CFrame.lookAt(a, b).RightVector
	for i = 0, math.floor(span / 1.35) do
		local p = a + dir * (i * 1.35 + 0.6) + Vector3.new(0, -0.12, 0)
		local plank = deco(NP("Plank", Vector3.new(rng:NextNumber(5.6, 6.1), 0.3, 1.05), CFrame.lookAt(p, p + dir) * CFrame.Angles(0, rng:NextNumber(-0.04, 0.04), 0), PALETTE.Wood:Lerp(PALETTE.WoodDark, rng:NextNumber(0, 0.35)), Enum.Material.WoodPlanks, f))
		plank.CastShadow = true
	end
	for _, x in ipairs({ -2.5, 2.5 }) do
		ArenaKit.Beam("Stringer", a + right * x - Vector3.new(0, 0.5, 0), b + right * x - Vector3.new(0, 0.5, 0), 0.5, PALETTE.WoodDark, Enum.Material.Wood, f)
	end
	local posts = math.max(1, math.floor(span / 7))
	for side = -1, 1, 2 do
		local prev: Vector3? = nil
		for k = 0, posts do
			local p = a:Lerp(b, k / posts) + right * side * 2.9
			local endPost = k == 0 or k == posts
			local ph = endPost and 3.6 or 2.9
			deco(NP("Post", Vector3.new(endPost and 0.7 or 0.4, ph, endPost and 0.7 or 0.4), CFrame.new(p + Vector3.new(0, ph / 2 - 0.4, 0)), PALETTE.WoodDark, Enum.Material.Wood, f))
			if prev then
				for _, y in ipairs({ 1.2, 2.4 }) do
					ArenaKit.Beam("Rope", prev + Vector3.new(0, y, 0), p + Vector3.new(0, y, 0), 0.22, ROPE, Enum.Material.Fabric, f)
				end
			end
			if endPost and side == 1 then
				local lantern = deco(NP("Lantern", Vector3.new(0.8, 1, 0.8), CFrame.new(p + Vector3.new(0, 3.8, 0)), LAMP, Enum.Material.Neon, f))
				lantern.CastShadow = false
				local l = Instance.new("PointLight")
				l.Color = LAMP
				l.Range = 12
				l.Brightness = 0.6
				l.Parent = lantern
			end
			prev = p
		end
	end
end

local STAIRS: ArenaKit.StairStyle = {
	step = COBBLE, stepAlt = COBBLE:Lerp(COBBLE_DARK, 0.3), wall = STONE_WALL, under = PALETTE.StoneDark, material = Enum.Material.Slate,
}

-- ── Island dressing ──────────────────────────────────────────────────────────

local function scatterNature(isle: any, trees: number, bushes: number, flowers: number, rocks: number, minD: number)
	local maxD = isle.r - 3
	for _ = 1, trees do
		local p = ArenaKit.TryPlace(isle, rng, math.max(minD, isle.r * 0.45), maxD, 3.6, 5.5)
		if p then
			if rng:NextNumber() < 0.28 then
				makePine(p, rng:NextNumber(0.8, 1.1), isle.folder)
			else
				makeTree(p, rng:NextNumber(0.75, 1.1), isle.folder)
			end
		end
	end
	for _ = 1, bushes do
		local p = ArenaKit.TryPlace(isle, rng, minD, maxD + 1, 1.8, 5.2)
		if p then
			makeBush(p, isle.folder)
		end
	end
	for _ = 1, flowers do
		local p = ArenaKit.TryPlace(isle, rng, minD, maxD + 1, 1.4, 4.5)
		if p then
			makeFlowers(p, isle.folder)
		end
	end
	for _ = 1, rocks do
		local p = ArenaKit.TryPlace(isle, rng, isle.r * 0.7, maxD + 1.5, 2, 5.5)
		if p then
			makeRock(p, rng:NextNumber(0.8, 1.3), isle.folder)
		end
	end
end

local function pathsToLinks(isle: any, fromR: number)
	for _, a in ipairs(isle.links) do
		makePath(ArenaKit.Polar(isle, a, fromR), ArenaKit.Polar(isle, a, isle.r - 1), isle.folder)
	end
end

local function addFalls(isle: any, count: number, height: number)
	for _, a in ipairs(ArenaKit.OpenAngles(isle, count)) do
		table.insert(isle.reserved, a)
		makeWaterfall(isle, a, height, isle.folder)
	end
end

local function propsAt(isle: any, n: number, minD: number, maxD: number, fn: (Vector3) -> ())
	for _ = 1, n do
		local p = ArenaKit.TryPlace(isle, rng, minD, maxD, 3.2, 5.5)
		if p then
			fn(p)
		end
	end
end

-- ── Build ────────────────────────────────────────────────────────────────────

function SkyIslands.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, SkyIslands.Name)

	local I: { [string]: any } = {}
	for key, spec in pairs(LAYOUT) do
		local folder = ArenaKit.MakeIslandBase(spec.pos, spec.r, key, PALETTE, Enum.Material.Grass, arena, STYLE)
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
			makeRopeBridge(I[l[1]], I[l[2]], bridges)
		end
	end

	-- Supply drops land on any playable island; jump pads on the team bases
	-- and windmill islands fling you onto the windmill hill.
	for _, isle in pairs(I) do
		ArenaKit.MarkPlayable(isle.folder)
	end
	local pads = Instance.new("Folder")
	pads.Name = "JumpPads"
	pads.Parent = arena
	for _, spec in ipairs({ { "teamB", 0.75 }, { "teamB", -0.75 }, { "teamR", 0.75 }, { "teamR", -0.75 }, { "millL", 0 }, { "millR", 0 } }) do
		local from, c = I[spec[1]], I.center
		-- Mill pads land beside (not on) the cottages that sit east/west of centre.
		local turn = spec[2] ~= 0 and -spec[2] * 0.6 or 0.6
		local land = ArenaKit.FacingPoint(c, from.pos, c.r * 0.62, turn)
		ArenaKit.Reserve(c, land, 4)
		ArenaKit.AddJumpPad(from, ArenaKit.AngleTo(from.pos, c.pos) + spec[2], from.r * 0.55, land, pads)
	end

	-- Windmill hill (centre high ground)
	do
		local c = I.center
		local cottageA = { 0, math.pi }
		for _, a in ipairs(cottageA) do
			table.insert(c.reserved, a)
		end
		makePlaza(ArenaKit.Polar(c, 0, 0), 15, c.folder)
		makeWindmill(ArenaKit.Polar(c, 0, 0), Vector3.new(0, 0, -1), 1, c.folder)
		ArenaKit.Reserve(c, ArenaKit.Polar(c, 0, 0), 16)
		for _, a in ipairs(cottageA) do
			local p = ArenaKit.Polar(c, a, 22)
			makeCottage(p, (ArenaKit.Polar(c, 0, 0) - p) * Vector3.new(1, 0, 1), 1, a == 0 and ROOF or Color3.fromRGB(96, 124, 176), c.folder)
			ArenaKit.Reserve(c, p, 7.5)
		end
		addFalls(c, 2, 60)
		for _, a in ipairs({ math.rad(45), math.rad(135), math.rad(225), math.rad(315) }) do
			if not ArenaKit.Blocked(c, a, 14, 3) then
				makeLamp(ArenaKit.Polar(c, a, 14), c.folder)
			end
		end
		pathsToLinks(c, 15)
		propsAt(c, 3, 17, 27, function(p) makeCrateStack(p, c.folder) end)
		propsAt(c, 3, 17, 28, function(p) makeBarrel(p, c.folder) end)
		scatterNature(c, 10, 10, 12, 4, 17)
		makeRimFence(c, c.folder)
		ArenaKit.AddPowerPad(c.pos + Vector3.new(11, 0, 0), powerPads)
		ArenaKit.AddPowerPad(c.pos + Vector3.new(-11, 0, 0), powerPads)
	end

	-- Fountain plazas
	for _, key in ipairs({ "plazaB", "plazaR" }) do
		local p = I[key]
		makePlaza(ArenaKit.Polar(p, 0, 0), 12, p.folder)
		makeFountain(ArenaKit.Polar(p, 0, 0), p.folder)
		ArenaKit.Reserve(p, ArenaKit.Polar(p, 0, 0), 13)
		addFalls(p, 2, 50)
		for k = 0, 3 do
			local a = k * math.pi / 2 + math.pi / 4
			if not ArenaKit.Blocked(p, a, 9, 3) then
				makeBench(ArenaKit.Polar(p, a, 9.5), -a - math.pi / 2, p.folder)
			end
		end
		for k = 0, 5 do
			local a = k * math.pi / 3 + math.pi / 6
			if not ArenaKit.Blocked(p, a, 13, 3) then
				makeLamp(ArenaKit.Polar(p, a, 13), p.folder)
			end
		end
		pathsToLinks(p, 12)
		propsAt(p, 2, 14, 20, function(q) makeBarrel(q, p.folder) end)
		scatterNature(p, 7, 8, 10, 3, 14)
		makeRimFence(p, p.folder)
	end

	-- Team bases
	for _, key in ipairs({ "teamB", "teamR" }) do
		local t = I[key]
		local col = TEAM_COLOR[t.team]
		local back = ArenaKit.AngleTo(Vector3.zero, t.pos)
		table.insert(t.reserved, back)
		makePlaza(ArenaKit.Polar(t, 0, 0), 13, t.folder, col)
		ArenaKit.Reserve(t, ArenaKit.Polar(t, 0, 0), 14)
		local home = ArenaKit.Polar(t, back, 20)
		makeCottage(home, (ArenaKit.Polar(t, 0, 0) - home) * Vector3.new(1, 0, 1), 1.1, col:Lerp(ROOF_DARK, 0.35), t.folder)
		ArenaKit.Reserve(t, home, 8)
		addFalls(t, 2, 55)
		for _, off in ipairs({ -0.5, 0.5 }) do
			local a = back + math.pi + off
			local p = ArenaKit.Polar(t, a, 15.5)
			makeBanner(p, col, faceYaw(ArenaKit.Polar(t, 0, 0) - p), t.folder)
			ArenaKit.Reserve(t, p, 1.5)
		end
		for k = 0, 3 do
			local a = back + math.pi / 4 + k * math.pi / 2
			if not ArenaKit.Blocked(t, a, 14.5, 3) then
				makeLamp(ArenaKit.Polar(t, a, 14.5), t.folder)
			end
		end
		pathsToLinks(t, 13)
		propsAt(t, 3, 16, 24, function(p) makeCrateStack(p, t.folder) end)
		propsAt(t, 2, 16, 25, function(p) makeBarrel(p, t.folder) end)
		scatterNature(t, 8, 8, 10, 3, 16)
		makeRimFence(t, t.folder)
		ArenaKit.AddTeamTriangleSpawns(t.pos, t.r, t.team, spawns)
		ArenaKit.AddTeamSpawnBeacons(t.pos, t.r, t.team, t.folder)
	end

	-- Flank islands
	for _, key in ipairs({ "flankBL", "flankBR", "flankRL", "flankRR" }) do
		local fl = I[key]
		makePlaza(ArenaKit.Polar(fl, 0, 0), 7, fl.folder)
		ArenaKit.Reserve(fl, ArenaKit.Polar(fl, 0, 0), 8)
		pathsToLinks(fl, 7)
		addFalls(fl, 1, 50)
		propsAt(fl, 2, 9, 15, function(p) makeCrateStack(p, fl.folder) end)
		propsAt(fl, 1, 9, 15, function(p) makeBarrel(p, fl.folder) end)
		propsAt(fl, 1, 9, 14, function(p) makeLamp(p, fl.folder) end)
		scatterNature(fl, 5, 6, 7, 2, 9)
		makeRimFence(fl, fl.folder)
		ArenaKit.AddPowerPad(fl.pos, powerPads)
	end

	-- Windmill side islands
	for _, key in ipairs({ "millL", "millR" }) do
		local m = I[key]
		local facing = Vector3.new(-m.pos.X, 0, 0).Unit
		makeWindmill(ArenaKit.Polar(m, 0, 0), facing, 0.72, m.folder)
		ArenaKit.Reserve(m, ArenaKit.Polar(m, 0, 0), 11)
		pathsToLinks(m, 7)
		addFalls(m, 1, 55)
		scatterNature(m, 4, 5, 6, 2, 11)
		makeRimFence(m, m.folder)
		ArenaKit.AddPowerPad(m.pos + Vector3.new(facing.X * 9.5, 0, 0), powerPads)
	end

	-- Side pads by the team bases
	for _, key in ipairs({ "padBL", "padBR", "padRL", "padRR" }) do
		local p = I[key]
		pathsToLinks(p, 0)
		propsAt(p, 1, 4, 9, function(q) makeCrateStack(q, p.folder) end)
		propsAt(p, 1, 4, 10, function(q) makeBarrel(q, p.folder) end)
		scatterNature(p, 3, 4, 5, 1, 5)
		makeRimFence(p, p.folder)
	end

	-- Scenery islands
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = arena
	for i, d in ipairs(DECOR) do
		local folder = ArenaKit.MakeIslandBase(d.pos, d.r, "Decor" .. i, PALETTE, Enum.Material.Grass, scenery, STYLE)
		local isle = ArenaKit.NewIsle(d.pos, d.r, folder)
		local toCenter = Vector3.new(-d.pos.X, 0, -d.pos.Z).Unit
		if d.kind == "mill" then
			makeWindmill(ArenaKit.Polar(isle, 0, 0), toCenter, 0.55, folder)
			ArenaKit.Reserve(isle, ArenaKit.Polar(isle, 0, 0), 5)
		elseif d.kind == "house" then
			makeCottage(ArenaKit.Polar(isle, 0, 0), toCenter, 0.8, ROOF, folder)
			ArenaKit.Reserve(isle, ArenaKit.Polar(isle, 0, 0), 6)
		end
		scatterNature(isle, d.kind == "trees" and 4 or 2, 3, 3, 1, 2)
		if i % 3 == 0 then
			makeWaterfall(isle, ArenaKit.AngleTo(d.pos, Vector3.zero), 35, folder)
		end
	end

	ArenaKit.MakeCloudBank(arena, Color3.fromRGB(255, 255, 255), 42, -70, -38, 40, 300, 0.12)
	ArenaKit.MakeCloudBank(arena, Color3.fromRGB(255, 255, 255), 12, 70, 100, 140, 320, 0.35)
	ArenaKit.ApplyAtmosphere({
		Density = 0.24, Offset = 0.12,
		Color = Color3.fromRGB(200, 230, 255), Decay = Color3.fromRGB(110, 172, 232),
		Glare = 0.3, Haze = 1.1,
		Ambient = Color3.fromRGB(138, 160, 190), OutdoorAmbient = Color3.fromRGB(172, 192, 216),
		ClockTime = 11, FogColor = Color3.fromRGB(190, 225, 255), FogEnd = 1500,
		Brightness = 2.4,
	})
	arena:SetAttribute("SpawnCount", #spawns:GetChildren())
	return arena
end

return SkyIslands
