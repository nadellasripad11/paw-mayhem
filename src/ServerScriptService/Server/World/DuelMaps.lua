--!strict
-- duelmaps: the arenas 1v1 - 5v5 duels are fought on, built the same way as
-- sky islands: grassy floating islands with cliffs underneath, joined by stone
-- stairs and rope bridges, dressed with round trees, bushes, flowers, rocks,
-- lamps and crate cover, swimmable waterfalls off the side islands, a sea of
-- clouds below and scenery islands drifting round. each duel gets its own
-- copy, built far away when it starts and removed when it ends.
--   * meadow       (green)  - two bases, a raised centre hill, two flanks
--   * sakura garden (pink)  - two bases, twin middle terraces, a top perch
--   * autumn ridge (orange) - the meadow layout in autumn colours, with pines
--   * frost peaks  (snow)   - the terrace layout in snow, pines and ice
-- blue starts on the -z side, red on the +z side.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ArenaKit = require(script.Parent.ArenaKit)
local MeshLib = require(ReplicatedStorage.Shared.MeshLib)

local DuelMaps = {}

export type Layout = { name: string, spawns: { [string]: { CFrame } }, killY: number }

local BLUE = Color3.fromRGB(70, 150, 255)
local RED = Color3.fromRGB(255, 80, 90)
local LAMP = Color3.fromRGB(255, 214, 140)
local IRON = Color3.fromRGB(58, 56, 60)
local WHITE = Color3.new(1, 1, 1)

type Theme = {
	name: string,
	palette: ArenaKit.Palette,
	top: Enum.Material,
	style: ArenaKit.IslandStyle,
	leaves: { Color3 },
	trunk: Color3,
	flowers: { Color3 },
	pines: boolean,
	snowy: boolean,
	stairs: ArenaKit.StairStyle,
	clouds: Color3,
}

local COBBLE = Color3.fromRGB(184, 176, 162)
local function stairStyle(step: Color3, wall: Color3, under: Color3): ArenaKit.StairStyle
	return { step = step, stepAlt = step:Lerp(Color3.new(0, 0, 0), 0.12), wall = wall, under = under, material = Enum.Material.Slate }
end

local THEMES: { [string]: Theme } = {
	Meadow = {
		name = "MEADOW",
		palette = {
			Top = Color3.fromRGB(108, 188, 74), TopDark = Color3.fromRGB(80, 158, 60),
			Stone = Color3.fromRGB(158, 136, 118), StoneDark = Color3.fromRGB(100, 86, 88),
			Wood = Color3.fromRGB(164, 114, 68), WoodDark = Color3.fromRGB(104, 68, 42),
		},
		top = Enum.Material.Grass,
		style = { meshes = true, cliffMaterial = Enum.Material.Slate, drip = Color3.fromRGB(86, 164, 62) },
		leaves = { Color3.fromRGB(58, 146, 58), Color3.fromRGB(82, 170, 64), Color3.fromRGB(122, 198, 80) },
		trunk = Color3.fromRGB(122, 84, 54),
		flowers = { Color3.fromRGB(255, 132, 190), Color3.fromRGB(255, 222, 84), Color3.fromRGB(196, 140, 255), Color3.fromRGB(250, 250, 250) },
		pines = false, snowy = false,
		stairs = stairStyle(COBBLE, Color3.fromRGB(196, 186, 168), Color3.fromRGB(100, 86, 88)),
		clouds = WHITE,
	},
	Sakura = {
		name = "SAKURA GARDEN",
		palette = {
			Top = Color3.fromRGB(150, 206, 120), TopDark = Color3.fromRGB(122, 184, 100),
			Stone = Color3.fromRGB(170, 150, 150), StoneDark = Color3.fromRGB(118, 100, 108),
			Wood = Color3.fromRGB(150, 94, 70), WoodDark = Color3.fromRGB(96, 58, 46),
		},
		top = Enum.Material.Grass,
		style = { meshes = true, cliffMaterial = Enum.Material.Slate, drip = Color3.fromRGB(120, 186, 96) },
		leaves = { Color3.fromRGB(255, 186, 210), Color3.fromRGB(252, 160, 190), Color3.fromRGB(255, 220, 232) },
		trunk = Color3.fromRGB(96, 62, 50),
		flowers = { Color3.fromRGB(255, 160, 200), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 210, 120) },
		pines = false, snowy = false,
		stairs = stairStyle(Color3.fromRGB(200, 190, 186), Color3.fromRGB(176, 120, 110), Color3.fromRGB(118, 100, 108)),
		clouds = Color3.fromRGB(255, 236, 244),
	},
	Autumn = {
		name = "AUTUMN RIDGE",
		palette = {
			Top = Color3.fromRGB(170, 172, 84), TopDark = Color3.fromRGB(146, 140, 66),
			Stone = Color3.fromRGB(150, 128, 108), StoneDark = Color3.fromRGB(96, 80, 72),
			Wood = Color3.fromRGB(140, 94, 58), WoodDark = Color3.fromRGB(90, 58, 36),
		},
		top = Enum.Material.Grass,
		style = { meshes = true, cliffMaterial = Enum.Material.Slate, drip = Color3.fromRGB(176, 150, 70) },
		leaves = { Color3.fromRGB(240, 130, 40), Color3.fromRGB(220, 80, 40), Color3.fromRGB(250, 186, 60) },
		trunk = Color3.fromRGB(100, 66, 44),
		flowers = { Color3.fromRGB(255, 200, 60), Color3.fromRGB(230, 90, 50), Color3.fromRGB(250, 240, 200) },
		pines = true, snowy = false,
		stairs = stairStyle(Color3.fromRGB(176, 160, 140), Color3.fromRGB(150, 120, 96), Color3.fromRGB(96, 80, 72)),
		clouds = Color3.fromRGB(255, 240, 220),
	},
	Frost = {
		name = "FROST PEAKS",
		palette = {
			Top = Color3.fromRGB(236, 242, 248), TopDark = Color3.fromRGB(210, 222, 236),
			Stone = Color3.fromRGB(140, 150, 168), StoneDark = Color3.fromRGB(96, 104, 124),
			Wood = Color3.fromRGB(130, 96, 70), WoodDark = Color3.fromRGB(84, 60, 44),
		},
		top = Enum.Material.Snow,
		style = { meshes = true, cliffMaterial = Enum.Material.Slate, drip = Color3.fromRGB(230, 238, 248) },
		leaves = { Color3.fromRGB(44, 110, 76), Color3.fromRGB(60, 130, 90), Color3.fromRGB(80, 150, 106) },
		trunk = Color3.fromRGB(90, 64, 48),
		flowers = { Color3.fromRGB(170, 220, 255), Color3.fromRGB(255, 255, 255) },
		pines = true, snowy = true,
		stairs = stairStyle(Color3.fromRGB(200, 210, 224), Color3.fromRGB(150, 160, 180), Color3.fromRGB(96, 104, 124)),
		clouds = Color3.fromRGB(236, 244, 255),
	},
}

local rng = Random.new()

-- ── parts ────────────────────────────────────────────────────────────────────
local function solid(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return ArenaKit.NewPart(name, size, cf, color, material, parent)
end

local function deco(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local p = ArenaKit.NewPart(name, size, cf, color, material, parent)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function ball(name: string, d: number, pos: Vector3, color: Color3, parent: Instance): BasePart
	local p = deco(name, Vector3.one * d, CFrame.new(pos), color, Enum.Material.SmoothPlastic, parent)
	;(p :: Part).Shape = Enum.PartType.Ball
	p.CastShadow = false
	return p
end

local function disc(name: string, d: number, h: number, pos: Vector3, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local p = ArenaKit.NewDisc(name, d, h, pos, color, material, parent)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- ── props (the sky islands set, themed) ──────────────────────────────────────
local function tree(th: Theme, pos: Vector3, s: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Tree"
	m.Parent = parent
	local h = 5.6 * s
	if MeshLib.Has("TreeTrunk") then
		-- the sculpted tree: a rooted trunk and a full, lumpy canopy. the old
		-- trunk stays as invisible collision.
		local yaw = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		solid("Trunk", Vector3.new(1.3 * s, h, 1.3 * s), CFrame.new(pos + Vector3.new(0, h / 2, 0)), th.trunk, Enum.Material.Wood, m).Transparency = 1
		MeshLib.Place("TreeTrunk", CFrame.new(pos) * yaw, s, th.trunk, Enum.Material.Wood, m)
		local top = CFrame.new(pos + Vector3.new(0, h + 1.9 * s, 0)) * yaw
		MeshLib.Place(rng:NextNumber() < 0.5 and "TreeCanopyA" or "TreeCanopyB", top, s, th.leaves[rng:NextInteger(1, #th.leaves)], Enum.Material.SmoothPlastic, m)
		if th.snowy then
			ball("Snow", 5 * s, top.Position + Vector3.new(0, 2.6 * s, 0), WHITE, m)
		end
		return
	end
	solid("Trunk", Vector3.new(1.3 * s, h, 1.3 * s), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), th.trunk, Enum.Material.Wood, m)
	deco("Roots", Vector3.new(2.3 * s, 0.7 * s, 2.3 * s), CFrame.new(pos + Vector3.new(0, 0.3 * s, 0)) * CFrame.Angles(0, math.rad(45), 0), th.trunk:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Wood, m)
	local top = pos + Vector3.new(0, h + 1.9 * s, 0)
	ball("Crown", 7.4 * s, top, th.leaves[2], m)
	for k = 1, 4 do
		local a = k * math.pi / 2 + rng:NextNumber(-0.45, 0.45)
		ball("Leaf", rng:NextNumber(4.2, 5.6) * s, top + Vector3.new(math.cos(a) * 3 * s, rng:NextNumber(-1.3, 0.3) * s, math.sin(a) * 3 * s), th.leaves[rng:NextInteger(1, #th.leaves)], m)
	end
	if th.snowy then
		ball("Snow", 5 * s, top + Vector3.new(0, 2.4 * s, 0), WHITE, m)
	end
end

local function pine(th: Theme, pos: Vector3, s: number, parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Pine"
	m.Parent = parent
	if MeshLib.Has("PineFoliage") then
		local yaw = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		solid("Trunk", Vector3.new(1.1 * s, 3.4 * s, 1.1 * s), CFrame.new(pos + Vector3.new(0, 1.7 * s, 0)), th.trunk, Enum.Material.Wood, m).Transparency = 1
		MeshLib.Place("PineTrunk", yaw, s, th.trunk, Enum.Material.Wood, m)
		MeshLib.Place("PineFoliage", yaw, s, th.snowy and th.leaves[1] or Color3.fromRGB(48, 122, 66), Enum.Material.SmoothPlastic, m)
		if th.snowy then
			MeshLib.Place("PineSnow", yaw, s, WHITE, Enum.Material.Snow, m)
		end
		return
	end
	solid("Trunk", Vector3.new(1.1 * s, 3.4 * s, 1.1 * s), CFrame.new(pos + Vector3.new(0, 1.7 * s, 0)), th.trunk, Enum.Material.Wood, m)
	local green = th.snowy and th.leaves or { Color3.fromRGB(44, 116, 62), Color3.fromRGB(58, 136, 70) }
	for k = 0, 3 do
		disc("Tier", (7.2 - k * 1.6) * s, 2.3 * s, pos + Vector3.new(0, (3.6 + k * 2.0) * s, 0), green[k % 2 + 1], Enum.Material.SmoothPlastic, m)
		if th.snowy then
			disc("SnowTier", (6.4 - k * 1.6) * s, 0.5 * s, pos + Vector3.new(0, (4.8 + k * 2.0) * s, 0), WHITE, Enum.Material.Snow, m)
		end
	end
	ball("Tip", 1.4 * s, pos + Vector3.new(0, 11.4 * s, 0), th.snowy and WHITE or green[2], m)
end

local function bush(th: Theme, pos: Vector3, parent: Instance)
	if MeshLib.Has("BushA") then
		local color = th.snowy and th.leaves[rng:NextInteger(1, 3)] or th.leaves[rng:NextInteger(1, #th.leaves)]:Lerp(Color3.fromRGB(70, 150, 60), th.name == "SAKURA GARDEN" and 0.6 or 0)
		MeshLib.Place("BushA", CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.85, 1.25), color, Enum.Material.SmoothPlastic, parent)
		return
	end
	for k = 1, 3 do
		local d = rng:NextNumber(2.2, 3.4)
		local a = k * 2.1 + rng:NextNumber(0, 0.8)
		ball("Bush", d, pos + Vector3.new(math.cos(a) * 1.1, d * 0.3, math.sin(a) * 1.1), th.snowy and th.leaves[rng:NextInteger(1, 3)] or th.leaves[rng:NextInteger(1, #th.leaves)]:Lerp(Color3.fromRGB(70, 150, 60), th.name == "SAKURA GARDEN" and 0.6 or 0), parent)
	end
end

local function flowers(th: Theme, pos: Vector3, parent: Instance)
	ball("FlowerLeaves", 1.8, pos + Vector3.new(0, 0.35, 0), Color3.fromRGB(80, 160, 60), parent)
	local col = th.flowers[rng:NextInteger(1, #th.flowers)]
	for _ = 1, 4 do
		ball("Bloom", 0.62, pos + Vector3.new(rng:NextNumber(-1.2, 1.2), rng:NextNumber(0.5, 0.9), rng:NextNumber(-1.2, 1.2)), col, parent)
	end
end

local function rock(th: Theme, pos: Vector3, s: number, parent: Instance)
	if MeshLib.Has("RockA") then
		local names = { "RockA", "RockB", "RockC" }
		for k = 1, 2 do
			local p = pos + Vector3.new((k - 1.5) * 1.3 * s, 0, rng:NextNumber(-0.5, 0.5) * s)
			MeshLib.Place(names[rng:NextInteger(1, 3)], CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), s * rng:NextNumber(0.75, 1.1), th.palette.Stone:Lerp(th.palette.StoneDark, rng:NextNumber()), Enum.Material.Slate, parent)
		end
		return
	end
	for k = 1, 2 do
		local sz = Vector3.new(rng:NextNumber(1.8, 3.2), rng:NextNumber(1.2, 2.2), rng:NextNumber(1.6, 2.8)) * s
		local cf = CFrame.new(pos + Vector3.new((k - 1.5) * 1.2 * s, sz.Y * 0.25, rng:NextNumber(-0.5, 0.5) * s))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3))
		deco("Rock", sz, cf, th.palette.Stone:Lerp(th.palette.StoneDark, rng:NextNumber()), Enum.Material.Slate, parent)
	end
end

local function lamp(pos: Vector3, parent: Instance)
	local base = solid("LampBase", Vector3.new(1.4, 1, 1.4), CFrame.new(pos + Vector3.new(0, 0.5, 0)), Color3.fromRGB(196, 186, 168), Enum.Material.Slate, parent)
	local glow
	if MeshLib.Has("LampIron") then
		-- the sculpted lamp: a stone plinth, a tapered iron post and a lantern
		-- cage round the glowing glass.
		base.Transparency = 1
		MeshLib.Place("LampStone", CFrame.new(pos), 1, Color3.fromRGB(196, 186, 168), Enum.Material.Slate, parent)
		MeshLib.Place("LampIron", CFrame.new(pos), 1, IRON, Enum.Material.Metal, parent)
		glow = deco("Lantern", Vector3.new(1, 1.3, 1), CFrame.new(pos + Vector3.new(0, 9.15, 0)), LAMP, Enum.Material.Neon, parent)
	else
		deco("LampPole", Vector3.new(0.45, 7, 0.45), CFrame.new(pos + Vector3.new(0, 4.5, 0)), IRON, Enum.Material.Metal, parent)
		deco("LampCap", Vector3.new(1.6, 0.4, 1.6), CFrame.new(pos + Vector3.new(0, 9.9, 0)), IRON, Enum.Material.Metal, parent)
		glow = deco("Lantern", Vector3.new(1.1, 1.3, 1.1), CFrame.new(pos + Vector3.new(0, 9.1, 0)), LAMP, Enum.Material.Neon, parent)
	end
	glow.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Range = 16
	light.Brightness = 0.8
	light.Parent = glow
end

local function crates(th: Theme, pos: Vector3, parent: Instance)
	local yaw = rng:NextNumber(0, 6.28)
	local a = solid("Crate", Vector3.new(3, 3, 3), CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, yaw, 0), th.palette.Wood, Enum.Material.WoodPlanks, parent)
	local b = solid("Crate", Vector3.new(2.2, 2.2, 2.2), CFrame.new(pos + Vector3.new(1.4, 1.1, 1.6)) * CFrame.Angles(0, yaw + 0.5, 0), th.palette.WoodDark, Enum.Material.WoodPlanks, parent)
	if MeshLib.Has("CrateBody") then
		-- framed, braced wooden crates; the boxes stay as invisible cover.
		for _, c in ipairs({ { a, 1, th.palette.Wood }, { b, 2.2 / 3, th.palette.WoodDark } }) do
			local box: BasePart, s: number = c[1], c[2]
			local bottom = box.CFrame * CFrame.new(0, -box.Size.Y / 2, 0)
			box.Transparency = 1
			MeshLib.Place("CrateBody", bottom, s, c[3], Enum.Material.Wood, parent)
			MeshLib.Place("CrateFrame", bottom, s, c[3]:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Wood, parent)
		end
	end
end

-- scatter themed props on an island (keeping clear of paths and each other).
local function dress(th: Theme, isle: any, trees: number, bushes: number, flowerN: number, rocks: number, minD: number, parent: Instance)
	local function place(n: number, rad: number, fn: (Vector3) -> ())
		for _ = 1, n do
			local p = ArenaKit.TryPlace(isle, rng, minD, isle.r - 2.5, rad, 4.5)
			if p then
				ArenaKit.Reserve(isle, p, rad)
				fn(p)
			end
		end
	end
	place(trees, 3.6, function(p)
		if th.pines and rng:NextNumber() < 0.5 then
			pine(th, p, rng:NextNumber(0.75, 1), parent)
		else
			tree(th, p, rng:NextNumber(0.7, 0.95), parent)
		end
	end)
	place(bushes, 1.8, function(p)
		bush(th, p, parent)
	end)
	place(flowerN, 1.3, function(p)
		flowers(th, p, parent)
	end)
	place(rocks, 2.2, function(p)
		rock(th, p, rng:NextNumber(0.7, 1.1), parent)
	end)
end

-- ── finishing touches ────────────────────────────────────────────────────────
-- a stone path from an island's middle to each way off it.
local function paths(th: Theme, isle: any, parent: Instance)
	for _, a in ipairs(isle.links) do
		local from, to = ArenaKit.Polar(isle, a, 4, 0.04), ArenaKit.Polar(isle, a, isle.r - 1, 0.04)
		deco("Path", Vector3.new(4.2, 0.08, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), th.stairs.step, Enum.Material.Slate, parent)
		for k = 1, math.floor((to - from).Magnitude / 2.2) do
			local p = from:Lerp(to, k / ((to - from).Magnitude / 2.2))
			deco("PathStone", Vector3.new(4.3, 0.1, 0.18), CFrame.lookAt(p, to) + Vector3.new(0, 0.01, 0), th.stairs.stepAlt, Enum.Material.Slate, parent)
		end
	end
end

-- a low wooden fence round the rim, leaving the ways off open.
local function fence(th: Theme, isle: any, parent: Instance)
	local r = isle.r - 1.2
	local step = math.rad(360 / math.max(16, math.floor(2 * math.pi * r / 4.5)))
	local prev: Vector3? = nil
	for a = 0, math.pi * 2 + step * 0.5, step do
		if ArenaKit.Blocked(isle, a, r, 5.5) then
			prev = nil
		else
			local p = ArenaKit.Polar(isle, a, r)
			deco("FencePost", Vector3.new(0.45, 2.4, 0.45), CFrame.new(p + Vector3.new(0, 1.2, 0)), th.palette.WoodDark, Enum.Material.Wood, parent)
			if prev then
				for _, y in ipairs({ 0.9, 1.9 }) do
					deco("FenceRail", Vector3.new(0.25, 0.25, (p - prev).Magnitude), CFrame.lookAt((prev + p) / 2 + Vector3.new(0, y, 0), p + Vector3.new(0, y, 0)), th.palette.Wood, Enum.Material.Wood, parent)
				end
			end
			prev = p
		end
	end
end

-- a little gazebo (solid posts, a peaked roof) - cover and a landmark.
local function gazebo(th: Theme, pos: Vector3, color: Color3, parent: Instance)
	for _, c in ipairs({ { -2.2, -2.2 }, { 2.2, -2.2 }, { -2.2, 2.2 }, { 2.2, 2.2 } }) do
		solid("GazeboPost", Vector3.new(0.6, 5, 0.6), CFrame.new(pos + Vector3.new(c[1], 2.5, c[2])), th.palette.Wood, Enum.Material.Wood, parent)
	end
	deco("GazeboRoof", Vector3.new(6.4, 0.5, 6.4), CFrame.new(pos + Vector3.new(0, 5.2, 0)), th.palette.WoodDark, Enum.Material.Wood, parent)
	for k = 0, 3 do
		local w = 6 - k * 1.5
		deco("GazeboTop", Vector3.new(w, 0.7, w), CFrame.new(pos + Vector3.new(0, 5.7 + k * 0.6, 0)) * CFrame.Angles(0, math.rad(45 * (k % 2)), 0), color, Enum.Material.SmoothPlastic, parent)
	end
end

-- a team flag on a pole.
local function flag(pos: Vector3, color: Color3, parent: Instance)
	deco("FlagPole", Vector3.new(0.35, 9, 0.35), CFrame.new(pos + Vector3.new(0, 4.5, 0)), Color3.fromRGB(230, 230, 236), Enum.Material.Metal, parent)
	deco("Flag", Vector3.new(0.1, 2.2, 3.4), CFrame.new(pos + Vector3.new(0, 7.6, 1.7)), color, Enum.Material.Fabric, parent)
	ball("FlagTop", 0.6, pos + Vector3.new(0, 9.1, 0), Color3.fromRGB(255, 210, 80), parent)
end

-- a stone lookout tower with a ladder up to its top deck.
local function lookout(th: Theme, isle: any, parent: Instance)
	local base = ArenaKit.Polar(isle, 0, 0)
	local tower = ArenaKit.NewDisc("TowerBody", 5, 10, base + Vector3.new(0, 5, 0), th.palette.Stone, Enum.Material.Slate, parent)
	tower.CanCollide = true
	ArenaKit.NewDisc("Platform", 8, 0.6, base + Vector3.new(0, 10.3, 0), th.palette.Wood, Enum.Material.WoodPlanks, parent)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		deco("Rail", Vector3.new(0.3, 1.2, 3.2), CFrame.new(base + Vector3.new(math.cos(a) * 3.8, 11.2, math.sin(a) * 3.8)) * CFrame.Angles(0, -a, 0), th.palette.WoodDark, Enum.Material.Wood, parent)
	end
	for k = 0, 2 do
		disc("TowerRoof", 7 - k * 2, 0.8, base + Vector3.new(0, 14.4 + k * 0.8, 0), th.palette.WoodDark:Lerp(Color3.fromRGB(184, 74, 56), 0.6), Enum.Material.SmoothPlastic, parent)
	end
	for _, c in ipairs({ { -3.4, -3.4 }, { 3.4, 3.4 } }) do
		deco("RoofPost", Vector3.new(0.35, 3.6, 0.35), CFrame.new(base + Vector3.new(c[1], 12.4, c[2])), th.palette.WoodDark, Enum.Material.Wood, parent)
	end
	ArenaKit.AddLadder(base + Vector3.new(0, 0, -5), 11, Vector3.new(0, 0, -1), parent)
end

-- a small waterfall spilling off an island's edge (just to look at).
local function miniFall(isle: any, angle: number, parent: Instance)
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local lip = ArenaKit.Polar(isle, angle, isle.r + 0.6)
	local water = Color3.fromRGB(118, 204, 242)
	local fall = deco("Fall", Vector3.new(3.4, 30, 0.8), CFrame.lookAt(lip - Vector3.new(0, 15, 0), lip - Vector3.new(0, 15, 0) + out), water, Enum.Material.Glass, parent)
	fall.Transparency = 0.2
	fall.CastShadow = false
	deco("FallFoam", Vector3.new(4, 0.8, 1.4), CFrame.lookAt(lip, lip + out), WHITE, Enum.Material.SmoothPlastic, parent).CastShadow = false
	local from = ArenaKit.Polar(isle, angle, isle.r * 0.6, 0.1)
	deco("Stream", Vector3.new(2.6, 0.2, (lip - from).Magnitude), CFrame.lookAt((from + lip) / 2 + Vector3.new(0, 0.1, 0), lip + Vector3.new(0, 0.1, 0)), water, Enum.Material.Glass, parent).Transparency = 0.15
end

-- weather for the theme: petals, leaves, snow or sparkles drifting down.
local function weather(th: Theme, o: Vector3, f: Instance)
	local p = deco("Weather", Vector3.new(150, 1, 150), CFrame.new(o + Vector3.new(0, 45, 0)), WHITE, Enum.Material.SmoothPlastic, f)
	p.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.EmissionDirection = Enum.NormalId.Bottom
	e.Lifetime = NumberRange.new(10, 14)
	e.Speed = NumberRange.new(3, 6)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Acceleration = Vector3.new(1.5, 0, 0.8)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Rate = 25
	if th.snowy then
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(WHITE)
		e.Size = NumberSequence.new(0.35)
		e.Rate = 60
	elseif th.name == "SAKURA GARDEN" then
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 180, 210))
		e.Size = NumberSequence.new(0.5)
	elseif th.pines then
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(240, 140, 50), Color3.fromRGB(220, 80, 40))
		e.Size = NumberSequence.new(0.6)
	else
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(255, 255, 210))
		e.Size = NumberSequence.new(0.25)
		e.LightEmission = 0.8
		e.Rate = 12
	end
	e.Parent = p
end

-- ── the sky round the arena ──────────────────────────────────────────────────
local function sky(th: Theme, o: Vector3, f: Instance)
	-- a sea of clouds well below: wide, flat banks rather than balls.
	for _ = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(30, 170)
		local c = o + Vector3.new(math.cos(a) * r, rng:NextNumber(-62, -48), math.sin(a) * r)
		for _ = 1, 3 do
			local d = rng:NextNumber(26, 44)
			local cloud = deco("Cloud", Vector3.new(d, d * 0.28, d * 0.8), CFrame.new(c + Vector3.new(rng:NextNumber(-14, 14), rng:NextNumber(-2, 2), rng:NextNumber(-14, 14))) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), th.clouds, Enum.Material.SmoothPlastic, f) :: Part
			cloud.Shape = Enum.PartType.Ball
			cloud.Transparency = 0.12
			cloud.CastShadow = false
		end
	end
	-- scenery islands drifting further out, each with a tree.
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(95, 130)
		local c = o + Vector3.new(math.cos(a) * r, rng:NextNumber(-6, 22), math.sin(a) * r)
		local folder = ArenaKit.MakeIslandBase(c, rng:NextNumber(6, 10), "SceneryIsle", th.palette, th.top, f, th.style)
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		local top = c + Vector3.new(0, ArenaKit.SURFACE, 0)
		if th.pines then
			pine(th, top, 0.8, folder)
		else
			tree(th, top, 0.8, folder)
		end
	end
	-- a few thin high clouds far out.
	for _ = 1, 6 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(110, 180)
		local d = rng:NextNumber(30, 50)
		local cloud = deco("HighCloud", Vector3.new(d, d * 0.22, d * 0.6), CFrame.new(o + Vector3.new(math.cos(a) * r, rng:NextNumber(45, 75), math.sin(a) * r)), th.clouds, Enum.Material.SmoothPlastic, f) :: Part
		cloud.Shape = Enum.PartType.Ball
		cloud.Transparency = 0.4
		cloud.CastShadow = false
	end
end

-- ── building one ─────────────────────────────────────────────────────────────
-- \`shape\`: "hill" (bases, a raised centre hill, two flanks) or "terraces"
-- (bases, twin middle terraces, a high perch between them).
local function build(th: Theme, shape: string, o: Vector3, f: Instance): Layout
	local I: { [string]: any } = {}
	local function isle(key: string, off: Vector3, r: number)
		local pos = o + off
		local folder = ArenaKit.MakeIslandBase(pos, r, key, th.palette, th.top, f, th.style)
		I[key] = ArenaKit.NewIsle(pos, r, folder)
	end
	isle("baseB", Vector3.new(0, 0, -46), 16)
	isle("baseR", Vector3.new(0, 0, 46), 16)
	local links: { { any } }
	if shape == "Hill" then
		isle("center", Vector3.new(0, 6, 0), 15)
		isle("flankL", Vector3.new(-35, 2, 0), 11)
		isle("flankR", Vector3.new(35, 2, 0), 11)
		links = {
			{ "baseB", "center", "stairs" }, { "baseR", "center", "stairs" },
			{ "baseB", "flankL", "bridge" }, { "baseB", "flankR", "bridge" },
			{ "baseR", "flankL", "bridge" }, { "baseR", "flankR", "bridge" },
		}
	else
		isle("midL", Vector3.new(-29, 3, -2), 11)
		isle("midR", Vector3.new(29, 3, 2), 11)
		isle("perch", Vector3.new(0, 11, 0), 7)
		links = {
			{ "baseB", "midL", "bridge" }, { "baseB", "midR", "bridge" },
			{ "baseR", "midL", "bridge" }, { "baseR", "midR", "bridge" },
			{ "midL", "perch", "stairs" }, { "midR", "perch", "stairs" },
		}
	end
	for _, l in ipairs(links) do
		ArenaKit.Link(I[l[1]], I[l[2]])
	end
	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = f
	for _, l in ipairs(links) do
		local A, B = I[l[1]], I[l[2]]
		if l[3] == "stairs" then
			ArenaKit.MakeStairs(A, B, paths, th.stairs)
		else
			local pa, pb = ArenaKit.EdgePoints(A, B, 2)
			ArenaKit.MakeBridge(pa, pb, paths, th.palette)
		end
	end

	-- bases: a plaza for each team with its colour, lamps, crate cover.
	local spawns: { [string]: { CFrame } } = {}
	for _, key in ipairs({ "baseB", "baseR" }) do
		local b = I[key]
		local side = key == "baseB" and -1 or 1
		local team = side < 0 and "Blue" or "Red"
		local color = side < 0 and BLUE or RED
		disc("Plaza", 12, 0.12, b.pos + Vector3.new(0, ArenaKit.SURFACE + 0.04, 0), th.stairs.step, Enum.Material.Slate, b.folder)
		disc("TeamRing", 12.8, 0.08, b.pos + Vector3.new(0, ArenaKit.SURFACE + 0.02, 0), color, Enum.Material.Neon, b.folder).Transparency = 0.35
		ArenaKit.Reserve(b, ArenaKit.Polar(b, 0, 0), 6.5)
		local list = {}
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			local p = ArenaKit.Polar(b, a, 3.2, 1.9)
			table.insert(list, CFrame.lookAt(p, p + Vector3.new(0, 0, -side)))
		end
		spawns[team] = list
		for _, a in ipairs(ArenaKit.OpenAngles(b, 2)) do
			local p = ArenaKit.Polar(b, a, b.r - 3)
			lamp(p, b.folder)
			ArenaKit.Reserve(b, p, 1.6)
		end
		for _ = 1, 2 do
			local p = ArenaKit.TryPlace(b, rng, 7.5, b.r - 3, 2.5, 4.5)
			if p then
				ArenaKit.Reserve(b, p, 2.5)
				crates(th, p, b.folder)
			end
		end
		do
			local p = ArenaKit.TryPlace(b, rng, 8, b.r - 4, 3.6, 5)
			if p then
				ArenaKit.Reserve(b, p, 3.6)
				gazebo(th, p, color, b.folder)
			end
		end
		for _, a in ipairs(ArenaKit.OpenAngles(b, 2)) do
			flag(ArenaKit.Polar(b, a, b.r - 2.2), color, b.folder)
			ArenaKit.Reserve(b, ArenaKit.Polar(b, a, b.r - 2.2), 1.2)
		end
		local fa = ArenaKit.OpenAngles(b, 1)[1]
		table.insert(b.reserved, fa)
		miniFall(b, fa, b.folder)
		dress(th, b, 4, 4, 6, 2, 7.5, b.folder)
	end

	-- the middle: cover, trees, a landmark, waterfalls off the side islands.
	local mid = shape == "Hill" and { "center", "flankL", "flankR" } or { "midL", "midR", "perch" }
	for _, key in ipairs(mid) do
		local m = I[key]
		local big = m.r >= 12
		if big then
			-- centre hill: a stone ring with a tree in it.
			disc("HillPlaza", 10, 0.12, m.pos + Vector3.new(0, ArenaKit.SURFACE + 0.04, 0), th.stairs.step, Enum.Material.Slate, m.folder)
			for k = 0, 7 do
				local a = k / 8 * math.pi * 2
				solid("StoneBlock", Vector3.new(1.6, 1.4, 1.6), CFrame.new(ArenaKit.Polar(m, a, 5.2, 0.7)) * CFrame.Angles(0, a, 0), th.palette.Stone, Enum.Material.Slate, m.folder)
			end
			lookout(th, m, m.folder)
			ArenaKit.Reserve(m, ArenaKit.Polar(m, 0, 0), 6.5)
			dress(th, m, 3, 4, 6, 2, 7, m.folder)
		elseif key == "perch" then
			gazebo(th, ArenaKit.Polar(m, 0, 0), Color3.fromRGB(255, 200, 90), m.folder)
			ArenaKit.Reserve(m, ArenaKit.Polar(m, 0, 0), 3.6)
			dress(th, m, 0, 2, 2, 0, 2.5, m.folder)
		else
			ArenaKit.AddSwimColumn("Water", m, ArenaKit.OpenAngles(m, 1)[1], m.folder)
			local p = ArenaKit.TryPlace(m, rng, 2, m.r - 3, 2.5, 4.5)
			if p then
				ArenaKit.Reserve(m, p, 2.5)
				crates(th, p, m.folder)
			end
			dress(th, m, 2, 3, 4, 1, 2.5, m.folder)
		end
	end
	-- paths to every way off, fences round the rims.
	for _, isle in pairs(I) do
		paths(th, isle, isle.folder)
		fence(th, isle, isle.folder)
	end
	weather(th, o, f)
	if th.snowy then
		-- ice crystals on the bases for frost peaks.
		for _, key in ipairs({ "baseB", "baseR" }) do
			local p = ArenaKit.TryPlace(I[key], rng, 7, I[key].r - 3, 2, 4.5)
			if p then
				local c = solid("Ice", Vector3.new(1.6, 4.5, 1.6), CFrame.new(p + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(45), math.rad(8)), Color3.fromRGB(190, 230, 255), Enum.Material.Ice, I[key].folder)
				c.Transparency = 0.15
			end
		end
	end

	sky(th, o, f)
	-- (deep enough that the bottom of a waterfall is still in play.)
	return { name = th.name, spawns = spawns, killY = o.Y - 62 }
end

DuelMaps.List = {
	{ Id = "Meadow", Name = "MEADOW", Build = function(o: Vector3, f: Instance): Layout
		return build(THEMES.Meadow, "Hill", o, f)
	end },
	{ Id = "Sakura", Name = "SAKURA GARDEN", Build = function(o: Vector3, f: Instance): Layout
		return build(THEMES.Sakura, "Terraces", o, f)
	end },
	{ Id = "Autumn", Name = "AUTUMN RIDGE", Build = function(o: Vector3, f: Instance): Layout
		return build(THEMES.Autumn, "Hill", o, f)
	end },
	{ Id = "Frost", Name = "FROST PEAKS", Build = function(o: Vector3, f: Instance): Layout
		return build(THEMES.Frost, "Terraces", o, f)
	end },
}

-- build duel map \`id\` (a random one if unknown) at \`origin\` into \`parent\`.
function DuelMaps.Build(id: string?, origin: Vector3, parent: Instance): Layout
	for _, def in ipairs(DuelMaps.List) do
		if def.Id == id then
			return def.Build(origin, parent)
		end
	end
	return DuelMaps.BuildRandom(origin, parent)
end

-- build a random duel map at \`origin\` into \`parent\`.
function DuelMaps.BuildRandom(origin: Vector3, parent: Instance): Layout
	local def = DuelMaps.List[rng:NextInteger(1, #DuelMaps.List)]
	return def.Build(origin, parent)
end

return DuelMaps
