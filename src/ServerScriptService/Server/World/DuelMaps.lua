--!strict
-- DuelMaps: the small arenas 1v1 / 2v2 duels are fought on. Each duel gets
-- its own copy, built far away from everything else when it starts and
-- removed when it ends, so any number of duels can run at once. Every map is
-- two sides facing each other across something you can get knocked off:
--   * Sky Bridge: two garden islands joined by plank bridges with a small
--     round island halfway; crates and a rock to duck behind
--   * Rooftop Duel: two neon-lit roofs over a foggy drop, a steel beam and a
--     plank across the gap, AC units and a water tank for cover
--   * Crystal Ring: one round slate platform over the void with a glowing
--     crystal in the middle and four small ones round it
-- Blue starts on the -Z side, Red on the +Z side.

local ArenaKit = require(script.Parent.ArenaKit)

local DuelMaps = {}

export type Layout = { name: string, spawns: { [string]: { CFrame } }, killY: number }

local BLUE = Color3.fromRGB(70, 150, 255)
local RED = Color3.fromRGB(255, 80, 90)
local WOOD = Color3.fromRGB(150, 104, 68)
local WOOD_DARK = Color3.fromRGB(104, 70, 46)
local STONE = Color3.fromRGB(176, 172, 166)
local GRASS: ArenaKit.Palette = {
	Top = Color3.fromRGB(134, 196, 112), TopDark = Color3.fromRGB(96, 170, 86),
	Stone = Color3.fromRGB(150, 144, 136), StoneDark = Color3.fromRGB(118, 112, 110),
	Wood = WOOD, WoodDark = WOOD_DARK,
}

local rng = Random.new()

-- Solid, walkable / cover part.
local function solid(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return ArenaKit.NewPart(name, size, cf, color, material, parent)
end

-- Decoration you pass through.
local function deco(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local p = ArenaKit.NewPart(name, size, cf, color, material, parent)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

-- Turn a part into a cylinder (its X axis is the cylinder axis).
local function cyl(p: BasePart): BasePart
	;(p :: Part).Shape = Enum.PartType.Cylinder
	return p
end

local function ball(d: number, pos: Vector3, color: Color3, parent: Instance): BasePart
	local p = deco("Leaves", Vector3.one * d, CFrame.new(pos), color, Enum.Material.SmoothPlastic, parent)
	;(p :: Part).Shape = Enum.PartType.Ball
	p.CastShadow = false
	return p
end

-- Two spawns per side, facing the other side.
local function spawnPair(center: Vector3, facing: number): { CFrame }
	local out = {}
	for _, x in ipairs({ -3, 3 }) do
		local p = center + Vector3.new(x, 1.9, 0)
		table.insert(out, CFrame.lookAt(p, p + Vector3.new(0, 0, facing)))
	end
	return out
end

local function blossom(pos: Vector3, parent: Instance)
	deco("Trunk", Vector3.new(0.9, 5, 0.9), CFrame.new(pos + Vector3.new(0, 2.5, 0)), WOOD_DARK, Enum.Material.Wood, parent)
	local top = pos + Vector3.new(0, 6.2, 0)
	ball(6, top, Color3.fromRGB(255, 196, 214), parent)
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2
		ball(4, top + Vector3.new(math.cos(a) * 2.4, rng:NextNumber(-0.8, 0.6), math.sin(a) * 2.4), k % 2 == 0 and Color3.fromRGB(252, 170, 196) or Color3.fromRGB(255, 222, 232), parent)
	end
end

-- ── Sky Bridge ───────────────────────────────────────────────────────────────
local function skyBridge(o: Vector3, f: Instance): Layout
	local surf = o.Y + ArenaKit.SURFACE
	local spawns = {}
	for _, side in ipairs({ -1, 1 }) do
		local team = side < 0 and "Blue" or "Red"
		local c = o + Vector3.new(0, 0, side * 30)
		ArenaKit.MakeIslandBase(c, 11, team .. "Isle", GRASS, Enum.Material.Grass, f)
		deco("TeamStrip", Vector3.new(9, 0.2, 0.6), CFrame.new(o.X, surf + 0.06, c.Z - side * 9.6), side < 0 and BLUE or RED, Enum.Material.Neon, f)
		blossom(Vector3.new(o.X + 6, surf, c.Z + side * 5), f)
		solid("Crate", Vector3.new(3, 3, 3), CFrame.new(o.X - 5, surf + 1.5, c.Z - side * 4) * CFrame.Angles(0, 0.35 * side, 0), WOOD, Enum.Material.WoodPlanks, f)
		solid("Crate", Vector3.new(2, 2, 2), CFrame.new(o.X - 3.2, surf + 1, c.Z - side * 5.5) * CFrame.Angles(0, -0.2 * side, 0), WOOD_DARK, Enum.Material.WoodPlanks, f)
		-- Plank bridge from this island to the middle one (no rails).
		local a, b = o.Z + side * 19.5, o.Z + side * 5.5
		local len = math.abs(a - b)
		solid("Bridge", Vector3.new(5, 0.6, len), CFrame.new(o.X, surf - 0.3, (a + b) / 2), WOOD, Enum.Material.WoodPlanks, f)
		for k = 0, math.floor(len / 1.4) do
			deco("Plank", Vector3.new(5.1, 0.08, 0.18), CFrame.new(o.X, surf + 0.01, math.min(a, b) + k * 1.4), WOOD_DARK, Enum.Material.Wood, f)
		end
		for _, x in ipairs({ -2.6, 2.6 }) do
			for _, z in ipairs({ a, b }) do
				deco("RopePost", Vector3.new(0.4, 2, 0.4), CFrame.new(o.X + x, surf + 1, z), WOOD_DARK, Enum.Material.Wood, f)
			end
		end
		spawns[team] = spawnPair(Vector3.new(o.X, surf, c.Z + side * 4), -side)
	end
	ArenaKit.MakeIslandBase(o, 6, "MidIsle", GRASS, Enum.Material.Grass, f)
	solid("MidRock", Vector3.new(4, 2.6, 1.8), CFrame.new(o.X, surf + 1.3, o.Z) * CFrame.Angles(0, 0.2, 0), STONE, Enum.Material.Slate, f)
	return { name = "SKY BRIDGE", spawns = spawns, killY = o.Y - 35 }
end

-- ── Rooftop Duel ─────────────────────────────────────────────────────────────
local function rooftops(o: Vector3, f: Instance): Layout
	local top = o.Y
	local spawns = {}
	local wall = Color3.fromRGB(46, 44, 62)
	local roof = Color3.fromRGB(92, 92, 104)
	local neon = { Color3.fromRGB(255, 90, 200), Color3.fromRGB(90, 220, 255), Color3.fromRGB(255, 210, 90) }
	for _, side in ipairs({ -1, 1 }) do
		local team = side < 0 and "Blue" or "Red"
		local cz = o.Z + side * 20
		solid("Roof", Vector3.new(22, 1, 18), CFrame.new(o.X, top - 0.5, cz), roof, Enum.Material.Concrete, f)
		deco("Building", Vector3.new(22, 90, 18), CFrame.new(o.X, top - 46, cz), wall, Enum.Material.Concrete, f)
		-- Lit windows on the face over the gap.
		local face = cz - side * 9.05
		for row = 1, 9 do
			for col = -3, 3 do
				if rng:NextNumber() < 0.55 then
					deco("Window", Vector3.new(1.8, 1.3, 0.1), CFrame.new(o.X + col * 2.8, top - 4 - row * 4, face), neon[rng:NextInteger(1, #neon)], Enum.Material.Neon, f)
				end
			end
		end
		-- Low parapet on the three outer edges.
		solid("Parapet", Vector3.new(22, 1.2, 0.6), CFrame.new(o.X, top + 0.6, cz + side * 8.7), roof, Enum.Material.Concrete, f)
		for _, x in ipairs({ -10.7, 10.7 }) do
			solid("Parapet", Vector3.new(0.6, 1.2, 18), CFrame.new(o.X + x, top + 0.6, cz), roof, Enum.Material.Concrete, f)
		end
		deco("TeamStrip", Vector3.new(20, 0.15, 0.5), CFrame.new(o.X, top + 0.02, cz - side * 8.5), side < 0 and BLUE or RED, Enum.Material.Neon, f)
		-- Cover: an AC unit and a water tank on legs.
		local ac = solid("ACUnit", Vector3.new(4, 2.6, 3), CFrame.new(o.X - 5, top + 1.3, cz - side * 2), Color3.fromRGB(190, 196, 204), Enum.Material.DiamondPlate, f)
		deco("Fan", Vector3.new(0.1, 2, 2), CFrame.new(ac.Position + Vector3.new(0, 1.35, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 64, 72), Enum.Material.Metal, f)
		cyl(solid("Tank", Vector3.new(5, 4.4, 4.4), CFrame.new(o.X + 7.5, top + 4.2, cz + side * 4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 110, 80), Enum.Material.Wood, f))
		for _, lx in ipairs({ -1.6, 1.6 }) do
			for _, lz in ipairs({ -1.6, 1.6 }) do
				solid("TankLeg", Vector3.new(0.4, 2, 0.4), CFrame.new(o.X + 7.5 + lx, top + 1, cz + side * 4 + lz), Color3.fromRGB(60, 60, 70), Enum.Material.Metal, f)
			end
		end
		-- A neon sign on the side of the building.
		deco("Sign", Vector3.new(0.3, 3, 8), CFrame.new(o.X - side * 11.2, top - 6, cz), neon[side < 0 and 2 or 1], Enum.Material.Neon, f)
		spawns[team] = spawnPair(Vector3.new(o.X, top, cz + side * 5), -side)
	end
	-- Across the gap: a steel beam and a narrow plank.
	solid("Beam", Vector3.new(1.4, 0.8, 24), CFrame.new(o.X - 5, top - 0.4, o.Z), Color3.fromRGB(120, 70, 60), Enum.Material.Metal, f)
	solid("Plank", Vector3.new(3, 0.4, 24), CFrame.new(o.X + 4, top - 0.2, o.Z), WOOD, Enum.Material.WoodPlanks, f)
	-- Fog far below.
	local fog = deco("Fog", Vector3.new(200, 2, 200), CFrame.new(o.X, top - 60, o.Z), Color3.fromRGB(120, 110, 150), Enum.Material.SmoothPlastic, f)
	fog.Transparency = 0.35
	return { name = "ROOFTOP DUEL", spawns = spawns, killY = top - 35 }
end

-- ── Crystal Ring ─────────────────────────────────────────────────────────────
local function crystalRing(o: Vector3, f: Instance): Layout
	local surf = o.Y
	local slate = Color3.fromRGB(58, 56, 76)
	local glow = Color3.fromRGB(170, 120, 255)
	local ice = Color3.fromRGB(200, 180, 255)
	cyl(solid("Floor", Vector3.new(2, 40, 40), CFrame.new(o.X, surf - 1, o.Z) * CFrame.Angles(0, 0, math.rad(90)), slate, Enum.Material.Slate, f))
	cyl(deco("Rim", Vector3.new(0.4, 40.8, 40.8), CFrame.new(o.X, surf - 0.9, o.Z) * CFrame.Angles(0, 0, math.rad(90)), glow, Enum.Material.Neon, f))
	cyl(deco("Inlay", Vector3.new(0.1, 26, 26), CFrame.new(o.X, surf + 0.02, o.Z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(78, 74, 100), Enum.Material.Slate, f))
	-- Tapering rock underneath.
	local r, y = 19, surf - 2
	for _ = 1, 4 do
		r *= 0.7
		cyl(deco("Under", Vector3.new(5, r * 2, r * 2), CFrame.new(o.X, y - 2.5, o.Z) * CFrame.Angles(0, 0, math.rad(90)), slate:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Slate, f))
		y -= 5
	end
	-- The big crystal in the middle, and four small ones round it.
	local function crystal(pos: Vector3, w: number, h: number)
		local c = solid("Crystal", Vector3.new(w, h, w), CFrame.new(pos + Vector3.new(0, h / 2 - 0.3, 0)) * CFrame.Angles(0, math.rad(45), math.rad(rng:NextNumber(-6, 6))), ice, Enum.Material.Glass, f)
		c.Transparency = 0.2
		deco("Core", Vector3.new(w * 0.45, h * 0.8, w * 0.45), c.CFrame, glow, Enum.Material.Neon, f)
	end
	crystal(Vector3.new(o.X, surf, o.Z), 3.4, 9)
	for k = 0, 3 do
		local a = math.rad(45 + k * 90)
		crystal(Vector3.new(o.X + math.cos(a) * 10, surf, o.Z + math.sin(a) * 10), 1.8, 4)
	end
	local light = Instance.new("PointLight")
	light.Color = glow
	light.Range = 30
	light.Brightness = 1.2
	light.Parent = f:FindFirstChild("Core")
	-- Shards drifting round the edge.
	for _ = 1, 10 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(26, 40)
		deco("Shard", Vector3.new(1, rng:NextNumber(2, 4), 1), CFrame.new(o.X + math.cos(a) * d, surf + rng:NextNumber(-8, 8), o.Z + math.sin(a) * d) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), ice, Enum.Material.Glass, f).Transparency = 0.3
	end
	local spawns = {}
	for _, side in ipairs({ -1, 1 }) do
		local team = side < 0 and "Blue" or "Red"
		deco("TeamArc", Vector3.new(8, 0.12, 0.5), CFrame.new(o.X, surf + 0.03, o.Z + side * 17), side < 0 and BLUE or RED, Enum.Material.Neon, f)
		spawns[team] = spawnPair(Vector3.new(o.X, surf, o.Z + side * 15), -side)
	end
	return { name = "CRYSTAL RING", spawns = spawns, killY = surf - 35 }
end

DuelMaps.List = {
	{ Id = "SkyBridge", Build = skyBridge },
	{ Id = "Rooftops", Build = rooftops },
	{ Id = "CrystalRing", Build = crystalRing },
}

-- Build a random duel map at `origin` into `parent`.
function DuelMaps.BuildRandom(origin: Vector3, parent: Instance): Layout
	local def = DuelMaps.List[rng:NextInteger(1, #DuelMaps.List)]
	return def.Build(origin, parent)
end

return DuelMaps
