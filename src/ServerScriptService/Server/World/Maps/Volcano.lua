--!strict
-- Map 2/3 — Volcano. Tiered basalt platforms surround a towering lava
-- mountain. Dark purple-grey rock, glowing orange lava cracks and falls,
-- scaffolding towers, stone paving rings, and a fiery orange sky.

local Workspace = game:GetService("Workspace")
local ArenaKit  = require(script.Parent.Parent.ArenaKit)

local Volcano = { Id = "Volcano", Name = "Volcano" }

-- ── Palette ──────────────────────────────────────────────────────────────────
local PALETTE: ArenaKit.Palette = {
	Top      = Color3.fromRGB(70, 58, 78),   TopDark   = Color3.fromRGB(48, 38, 55),
	Stone    = Color3.fromRGB(82, 68, 88),   StoneDark = Color3.fromRGB(52, 42, 58),
	Wood     = Color3.fromRGB(60, 38, 30),   WoodDark  = Color3.fromRGB(36, 22, 16),
}
local LAVA       = Color3.fromRGB(255, 108, 20)
local LAVA_GLOW  = Color3.fromRGB(255, 185, 55)
local LAVA_DARK  = Color3.fromRGB(200, 70, 10)
local EMBER      = Color3.fromRGB(255, 145, 55)
local BASALT     = Color3.fromRGB(56, 44, 62)
local ROCK_MID   = Color3.fromRGB(68, 54, 74)
local ROCK_LIGHT = Color3.fromRGB(88, 72, 96)

-- ── Layout ───────────────────────────────────────────────────────────────────
-- Volcano peak is the top-centre. Platforms ring it in tiers stepping downward.
-- Team islands sit at the bottom flanks — identical height, opposite sides.
local VP  = Vector3.new(0, 38, 0)  -- volcano base reference for bridges
local VR  = 22                     -- approx island radius for bridge maths

local TIER0 = { pos = Vector3.new(0,  22, 0),   r = 28 }  -- volcano foot island
local TIER1 = {
	{ pos = Vector3.new(-50, 14, -10), r = 20 },
	{ pos = Vector3.new( 50, 16,  10), r = 20 },
}
local TIER2 = {
	{ pos = Vector3.new(-80, 6, -8),  r = 24 },
	{ pos = Vector3.new( 80, 8,  8),  r = 24 },
}
local TEAMS = {
	{ pos = Vector3.new(  0,  0, -95), r = 28, team = "Blue" },
	{ pos = Vector3.new(  0,  0,  95), r = 28, team = "Red"  },
}
local LOWER = {
	{ pos = Vector3.new(-55, 4, -64), r = 18 },
	{ pos = Vector3.new( 55, 6,  64), r = 18 },
	{ pos = Vector3.new(-30, 2,  72), r = 16 },
	{ pos = Vector3.new( 30, 0, -72), r = 16 },
}
local SATS = {
	{ pos = Vector3.new( 28, 32,  26), r = 9 },
	{ pos = Vector3.new(-28, 36, -26), r = 8 },
	{ pos = Vector3.new( 0,  48,   0), r = 7 },
	{ pos = Vector3.new(-90, 10,  42), r = 6 },
	{ pos = Vector3.new( 90,  8, -42), r = 6 },
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function lavaLight(parent: BasePart, range: number, brightness: number)
	local pl = Instance.new("PointLight")
	pl.Color = LAVA; pl.Range = range; pl.Brightness = brightness; pl.Parent = parent
end

-- Charred spike "tree"
local function makeSpike(pos: Vector3, parent: Instance)
	local h = 4.5 + math.random()*5
	ArenaKit.NewPart("Spike",    Vector3.new(1.1, h,   1.1), CFrame.new(pos + Vector3.new(0, h/2, 0)),   PALETTE.WoodDark, Enum.Material.Basalt, parent).CanCollide = false
	ArenaKit.NewPart("SpikeTip", Vector3.new(0.3, 1.1, 0.3), CFrame.new(pos + Vector3.new(0, h+0.4, 0)), PALETTE.WoodDark, Enum.Material.Basalt, parent).CanCollide = false
end

-- Glowing ember cluster (replaces flower)
local function makeEmber(pos: Vector3, parent: Instance)
	local g = ArenaKit.NewPart("Ember", Vector3.new(0.55, 0.35, 0.55), CFrame.new(pos + Vector3.new(0, 0.18, 0)), EMBER, Enum.Material.Neon, parent)
	g.Shape = Enum.PartType.Ball; g.CanCollide = false; g.CastShadow = false
	lavaLight(g, 7, 1.4)
end

local function scatter(center: Vector3, radius: number, parent: Instance, spikes: number, embers: number)
	for _ = 1, spikes do
		local a = math.random()*math.pi*2; local r = radius*(0.28+math.random()*0.58)
		makeSpike(center + Vector3.new(math.cos(a)*r, 1.6, math.sin(a)*r), parent)
	end
	for _ = 1, embers do
		local a = math.random()*math.pi*2; local r = radius*(0.12+math.random()*0.78)
		makeEmber(center + Vector3.new(math.cos(a)*r, 1.6, math.sin(a)*r), parent)
	end
end

-- Scaffolding observation tower (key visual from reference)
local function makeScaffold(pos: Vector3, height: number, parent: Instance)
	local f = Instance.new("Folder"); f.Name = "Scaffold"; f.Parent = parent
	for _, xz in ipairs({ {-2.2, -2.2}, {2.2, -2.2}, {-2.2, 2.2}, {2.2, 2.2} }) do
		ArenaKit.NewPart("Post", Vector3.new(0.52, height, 0.52), CFrame.new(pos + Vector3.new(xz[1], height/2, xz[2])), PALETTE.WoodDark, Enum.Material.Wood, f).CanCollide = false
	end
	local tiers = math.floor(height / 4)
	for i = 1, tiers do
		local yy = i * 4
		ArenaKit.NewPart("H1", Vector3.new(5.5, 0.45, 0.45), CFrame.new(pos + Vector3.new(0, yy, -2.2)), PALETTE.Wood, Enum.Material.Wood, f).CanCollide = false
		ArenaKit.NewPart("H2", Vector3.new(5.5, 0.45, 0.45), CFrame.new(pos + Vector3.new(0, yy,  2.2)), PALETTE.Wood, Enum.Material.Wood, f).CanCollide = false
		ArenaKit.NewPart("H3", Vector3.new(0.45, 0.45, 5.5), CFrame.new(pos + Vector3.new(-2.2, yy, 0)), PALETTE.Wood, Enum.Material.Wood, f).CanCollide = false
		ArenaKit.NewPart("H4", Vector3.new(0.45, 0.45, 5.5), CFrame.new(pos + Vector3.new( 2.2, yy, 0)), PALETTE.Wood, Enum.Material.Wood, f).CanCollide = false
		-- diagonal brace
		if i % 2 == 0 then
			ArenaKit.NewPart("Diag", Vector3.new(6.5, 0.4, 0.4), CFrame.new(pos + Vector3.new(0, yy-2, 0)) * CFrame.Angles(0, math.rad(45), math.rad(30)), PALETTE.WoodDark, Enum.Material.Wood, f).CanCollide = false
		end
	end
	-- Platform top
	ArenaKit.NewPart("TopPlat", Vector3.new(5.5, 0.65, 5.5), CFrame.new(pos + Vector3.new(0, height+0.3, 0)), PALETTE.Wood, Enum.Material.WoodPlanks, f).CanCollide = true
	-- Glowing lantern on top
	local orb = ArenaKit.NewPart("Lantern", Vector3.new(1.0, 1.0, 1.0), CFrame.new(pos + Vector3.new(0, height+1.4, 0)), LAVA_GLOW, Enum.Material.Neon, f)
	orb.Shape = Enum.PartType.Ball; orb.CanCollide = false
	lavaLight(orb, 18, 1.6)
end

-- Lava crack lines on platform surface
local function makeLavaCracks(center: Vector3, radius: number, parent: Instance)
	for i = 1, 6 do
		local ang = math.rad(i*58 + math.random()*25)
		local len = radius*(0.28 + math.random()*0.38)
		local p = center + Vector3.new(math.cos(ang)*len*0.5, 1.65, math.sin(ang)*len*0.5)
		local crack = ArenaKit.NewPart("Crack"..i, Vector3.new(len, 0.32, 0.9 + math.random()*0.6), CFrame.new(p) * CFrame.Angles(0, ang, 0), LAVA, Enum.Material.Neon, parent)
		crack.CanCollide = false; crack.CastShadow = false
		lavaLight(crack, 9, 0.65)
	end
end

-- Decorative stone paving circle
local function makeArenaRing(center: Vector3, radius: number, parent: Instance)
	local segs = 12
	for i = 0, segs-1 do
		local ang = math.rad(i*(360/segs))
		local p = center + Vector3.new(math.cos(ang)*radius, 1.64, math.sin(ang)*radius)
		ArenaKit.NewPart("Ring"..i, Vector3.new(4.6, 0.38, 2.8), CFrame.new(p) * CFrame.Angles(0, ang, 0), ROCK_LIGHT, Enum.Material.Slate, parent).CanCollide = false
	end
	ArenaKit.NewPart("RingCtr", Vector3.new(radius*0.9, 0.36, radius*0.9), CFrame.new(center + Vector3.new(0, 1.62, 0)), ROCK_MID, Enum.Material.Slate, parent).CanCollide = false
end

-- Lava fall (glowing molten stream between tiers)
local function makeLavaFall(top: Vector3, height: number, parent: Instance)
	local f = Instance.new("Folder"); f.Name = "LF"; f.Parent = parent
	local sheet = ArenaKit.NewPart("Sheet", Vector3.new(7.5, height, 1.6), CFrame.new(top - Vector3.new(0, height/2, 0)), LAVA, Enum.Material.Neon, f)
	sheet.Transparency = 0.08; sheet.CanCollide = false
	lavaLight(sheet, 22, 1.5)
	local glow = ArenaKit.NewPart("Glow", Vector3.new(12, height*0.6, 5), CFrame.new(top - Vector3.new(0, height*0.5, 0)), LAVA_DARK, Enum.Material.Neon, f)
	glow.Transparency = 0.7; glow.CanCollide = false
	local pool = ArenaKit.NewPart("Pool", Vector3.new(10, 0.55, 10), CFrame.new(top - Vector3.new(0, height+1.5, 0)), LAVA_GLOW, Enum.Material.Neon, f)
	pool.Transparency = 0.22; pool.CanCollide = false
	lavaLight(pool, 18, 2.0)
end

-- Lava channel flowing across a platform
local function makeLavaChannel(pos: Vector3, length: number, yaw: number, parent: Instance)
	local cf = CFrame.new(pos + Vector3.new(0, 1.88, 0)) * CFrame.Angles(0, yaw, 0)
	ArenaKit.NewPart("Bed",  Vector3.new(length, 0.52, 3.5), cf, BASALT, Enum.Material.Basalt, parent).CanCollide = false
	local flow = ArenaKit.NewPart("Flow", Vector3.new(length-0.8, 0.24, 1.55), cf, LAVA, Enum.Material.Neon, parent)
	flow.CanCollide = false
	lavaLight(flow, 13, 0.85)
end

-- Lava pool (flat glowing square)
local function makeLavaPool(pos: Vector3, size: number, parent: Instance)
	local pool = ArenaKit.NewPart("LavaPool", Vector3.new(size, 0.4, size), CFrame.new(pos + Vector3.new(0, 1.62, 0)), LAVA, Enum.Material.Neon, parent)
	pool.CanCollide = false
	lavaLight(pool, 16, 1.2)
end

-- Obsidian gate/arch
local function makeGate(pos: Vector3, parent: Instance)
	for _, x in ipairs({ -5.5, 5.5 }) do
		ArenaKit.NewPart("GatePil", Vector3.new(2.5, 10.5, 2.5), CFrame.new(pos + Vector3.new(x, 5.25, 0)), BASALT, Enum.Material.Basalt, parent).CanCollide = true
	end
	ArenaKit.NewPart("Lintel",  Vector3.new(14, 2.6, 3.0), CFrame.new(pos + Vector3.new(0, 10.8, 0)), ROCK_MID, Enum.Material.Basalt, parent).CanCollide = true
	local flame = ArenaKit.NewPart("Flame",  Vector3.new(6.5, 0.5, 0.4), CFrame.new(pos + Vector3.new(0, 11.1, -1.4)), LAVA_GLOW, Enum.Material.Neon, parent)
	flame.CanCollide = false
	lavaLight(flame, 12, 1.2)
end

-- Team marker banner
local function makeBanner(pos: Vector3, teamId: string, parent: Instance)
	local col = teamId=="Red" and Color3.fromRGB(255,72,55) or Color3.fromRGB(70,165,255)
	ArenaKit.NewPart("Pole",   Vector3.new(0.55, 11, 0.55), CFrame.new(pos + Vector3.new(0,5.5,0)), PALETTE.WoodDark, Enum.Material.Basalt, parent).CanCollide = false
	local flag = ArenaKit.NewPart("Flag", Vector3.new(5.8, 3.0, 0.22), CFrame.new(pos + Vector3.new(2.9,9.2,0)), col, Enum.Material.Fabric, parent)
	flag.CanCollide = false
	local tip = ArenaKit.NewPart("Tip", Vector3.new(0.8,0.8,0.8), CFrame.new(pos + Vector3.new(0,11.7,0)), LAVA_GLOW, Enum.Material.Neon, parent)
	tip.Shape = Enum.PartType.Ball; tip.CanCollide = false
	lavaLight(tip, 10, 0.7)
	local pl = Instance.new("PointLight"); pl.Color=col; pl.Range=12; pl.Brightness=0.55; pl.Parent=flag
end

-- Crate (charred volcanic crate)
local function makeCrate(pos: Vector3, parent: Instance)
	ArenaKit.NewPart("Crate",   Vector3.new(3.8,3.8,3.8), CFrame.new(pos + Vector3.new(0,3.5,0)), PALETTE.Wood, Enum.Material.Basalt, parent).CanCollide = true
	ArenaKit.NewPart("CrateT",  Vector3.new(4.1,0.4,4.1), CFrame.new(pos + Vector3.new(0,5.3,0)), PALETTE.WoodDark, Enum.Material.Basalt, parent).CanCollide = false
	ArenaKit.NewPart("CrateB",  Vector3.new(4.1,0.4,4.1), CFrame.new(pos + Vector3.new(0,1.8,0)), PALETTE.WoodDark, Enum.Material.Basalt, parent).CanCollide = false
end

-- Crystal shard cluster
local function makeCrystals(pos: Vector3, parent: Instance, color: Color3?)
	local c = color or LAVA_GLOW
	for i = 1, 5 do
		local ang = math.rad(i*68)
		local off = Vector3.new(math.cos(ang)*(2+i*0.4), 0, math.sin(ang)*(2+i*0.4))
		local cry = ArenaKit.NewPart("Crystal"..i, Vector3.new(1.2, 3+(i%3)*1.8, 1.2), CFrame.new(pos+off+Vector3.new(0,2,0)) * CFrame.Angles(math.rad(-10+i*6), ang, math.rad(20-i*5)), c, Enum.Material.Neon, parent)
		cry.CanCollide = false
		lavaLight(cry, 8, 0.7)
	end
end

-- ── THE VOLCANO MOUNTAIN ──────────────────────────────────────────────────────
-- Built from stacked rectangular tiers (wider at base, narrowing to crater peak)
-- with lava streams, glowing crater, and ash smoke.
local function buildVolcanoMountain(base: Vector3, parent: Instance)
	local f = Instance.new("Folder"); f.Name = "VolcanoMountain"; f.Parent = parent

	-- Stacked mountain tiers (wider → narrower)
	local tiers = {
		{ w=50, h=9,  y=4.5  },
		{ w=40, h=9,  y=13.5 },
		{ w=31, h=8,  y=21.5 },
		{ w=24, h=8,  y=29.5 },
		{ w=17, h=7,  y=37   },
		{ w=12, h=6,  y=43.5 },
		{ w= 8, h=5,  y=49.5 },
		{ w= 5, h=4,  y=54   },
	}
	for i, t in ipairs(tiers) do
		local col = (i % 2 == 0) and PALETTE.Stone or BASALT
		ArenaKit.NewPart("Tier"..i, Vector3.new(t.w, t.h, t.w), CFrame.new(base + Vector3.new(0, t.y, 0)), col, Enum.Material.Basalt, f).CanCollide = true
		-- Edge ridge/detail on each tier
		for _, side in ipairs({ {t.w*0.5+0.5, 0, 0}, {-t.w*0.5-0.5, 0, 0}, {0, 0, t.w*0.5+0.5}, {0, 0, -t.w*0.5-0.5} }) do
			local ridgePart = ArenaKit.NewPart("Ridge"..i, Vector3.new(t.w+2, 1.2, 1.4), CFrame.new(base + Vector3.new(0, t.y + t.h/2, 0) + Vector3.new(side[1], side[2], side[3])) * CFrame.Angles(0, side[1]~=0 and math.rad(90) or 0, 0), PALETTE.StoneDark, Enum.Material.Basalt, f)
			ridgePart.CanCollide = false
		end
	end

	-- Crater lip at peak
	for i = 0, 7 do
		local ang = math.rad(i*45)
		local cp = base + Vector3.new(math.cos(ang)*3.5, 57, math.sin(ang)*3.5)
		ArenaKit.NewPart("CraterLip"..i, Vector3.new(2.8, 2.4, 2.0), CFrame.new(cp) * CFrame.Angles(0, ang, 0), BASALT, Enum.Material.Basalt, f).CanCollide = false
	end

	-- Crater glowing lava pool
	local crater = ArenaKit.NewPart("Crater", Vector3.new(5.5, 0.6, 5.5), CFrame.new(base + Vector3.new(0, 56.5, 0)), LAVA_GLOW, Enum.Material.Neon, f)
	crater.CanCollide = false
	local craterLight = Instance.new("PointLight"); craterLight.Color=LAVA_GLOW; craterLight.Range=60; craterLight.Brightness=3.5; craterLight.Parent=crater

	-- Pulsing crater animation
	task.spawn(function()
		local t = 0
		while crater.Parent do
			t += 0.04
			local pulse = 0.5 + math.sin(t)*0.5
			crater.Color = LAVA:Lerp(LAVA_GLOW, pulse)
			craterLight.Brightness = 2.5 + pulse * 2.0
			task.wait(0.08)
		end
	end)

	-- Lava streams running down the mountain face (front + back)
	for _, ox in ipairs({ 1.5, -1.5 }) do
		for side = 1, 2 do
			local dir = side == 1 and 1 or -1
			for i, t in ipairs(tiers) do
				if i < #tiers then
					local nextT = tiers[i+1]
					local streamZ = dir * (t.w*0.5 - 1.5)
					local streamX = ox
					local sh = t.h + 1
					local sp = base + Vector3.new(streamX, t.y, streamZ)
					local stream = ArenaKit.NewPart("Stream"..i..side, Vector3.new(2.8, sh, 1.2), CFrame.new(sp), LAVA, Enum.Material.Neon, f)
					stream.Transparency = 0.12; stream.CanCollide = false
					lavaLight(stream, 14, 1.0)
				end
			end
		end
	end

	-- Smoke columns above crater
	for k = 1, 4 do
		local ang = math.rad(k*90)
		local col = ArenaKit.NewPart("Smoke"..k, Vector3.new(4+k, 6+k*2, 4+k), CFrame.new(base + Vector3.new(math.cos(ang)*2, 60+k*5, math.sin(ang)*2)), Color3.fromRGB(50, 42, 48), Enum.Material.ForceField, f)
		col.Transparency = 0.6+k*0.08; col.CanCollide = false
	end
end

-- ── Build ─────────────────────────────────────────────────────────────────────

function Volcano.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, Volcano.Name)

	-- ── Volcano mountain (centre, towering above everything) ──────────────
	local volcBase = Vector3.new(0, TIER0.pos.Y + 1.6, 0)
	buildVolcanoMountain(volcBase, arena)

	-- ── Tier-0: Volcano foot island ───────────────────────────────────────
	local t0p = TIER0.pos; local t0r = TIER0.r
	local footIsl = ArenaKit.MakeIslandBase(t0p, t0r, "FootIsland", PALETTE, Enum.Material.Basalt, arena)
	makeArenaRing(t0p, 16, footIsl)
	makeLavaCracks(t0p, t0r, footIsl)
	makeLavaPool(t0p + Vector3.new(-10, 0, -8), 8, footIsl)
	makeLavaPool(t0p + Vector3.new( 10, 0,  8), 6, footIsl)
	makeLavaChannel(t0p + Vector3.new(0, 0, 8), 22, 0, footIsl)
	makeLavaChannel(t0p + Vector3.new(0, 0,-8), 18, math.rad(45), footIsl)
	makeScaffold(t0p + Vector3.new(-t0r+6, 1.6, -t0r+6), 14, footIsl)
	makeScaffold(t0p + Vector3.new( t0r-6, 1.6,  t0r-6), 12, footIsl)
	makeGate(t0p + Vector3.new(0, 1.6, t0r-12), footIsl)
	makeGate(t0p + Vector3.new(0, 1.6, -(t0r-12)), footIsl)
	makeCrystals(t0p + Vector3.new(-12, 1.6,  8), footIsl)
	makeCrystals(t0p + Vector3.new( 12, 1.6, -8), footIsl, EMBER)
	makeCrate(t0p + Vector3.new(-16, 1.6, 10), footIsl)
	makeCrate(t0p + Vector3.new( 16, 1.6,-10), footIsl)
	scatter(t0p, t0r, footIsl, 5, 20)
	-- Massive lava falls OFF the foot island
	makeLavaFall(t0p + Vector3.new( t0r-3, 1, 5), 80, arena)
	makeLavaFall(t0p + Vector3.new(-(t0r-3), 1, -5), 75, arena)
	ArenaKit.AddPowerPad(t0p, powerPads)

	-- ── Tier-1: flanking mid-high platforms ───────────────────────────────
	for i, o in ipairs(TIER1) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "T1_"..i, PALETTE, Enum.Material.Basalt, arena)
		makeArenaRing(o.pos, 10, isl)
		makeLavaCracks(o.pos, o.r, isl)
		makeLavaChannel(o.pos + Vector3.new(0,0,5), 16, 0, isl)
		makeScaffold(o.pos + Vector3.new(-o.r+5, 1.6, -o.r+5), 12, isl)
		makeScaffold(o.pos + Vector3.new( o.r-5, 1.6,  o.r-5), 10, isl)
		makeGate(o.pos + Vector3.new(0, 1.6, -(o.r-10)), isl)
		makeCrystals(o.pos + Vector3.new(8, 1.6, -6), isl)
		makeCrate(o.pos + Vector3.new(-10, 1.6, 8), isl)
		makeCrate(o.pos + Vector3.new( 10, 1.6,-8), isl)
		scatter(o.pos, o.r, isl, 3, 12)
		makeLavaFall(o.pos + Vector3.new(0, 1, o.r-3), 50+i*5, isl)
		makeLavaFall(o.pos + Vector3.new(o.r-3, 1, 0), 46+i*4, isl)
		ArenaKit.AddPowerPad(o.pos, powerPads)

		-- Bridge: T1 → foot island
		do
			local dir = t0p - o.pos
			ArenaKit.MakeBridge(
				o.pos + dir.Unit*(o.r-2) + Vector3.new(0,1.6,0),
				t0p   - dir.Unit*(t0r-2) + Vector3.new(0,1.6,0),
				arena, PALETTE)
		end
	end

	-- ── Tier-2: wide mid platforms ────────────────────────────────────────
	for i, o in ipairs(TIER2) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "T2_"..i, PALETTE, Enum.Material.Basalt, arena)
		makeArenaRing(o.pos, 12, isl)
		makeLavaCracks(o.pos, o.r, isl)
		makeScaffold(o.pos + Vector3.new(-o.r+6, 1.6, -o.r+6), 14, isl)
		makeScaffold(o.pos + Vector3.new( o.r-6, 1.6,  o.r-6), 14, isl)
		makeScaffold(o.pos + Vector3.new(-o.r+6, 1.6,  o.r-6), 10, isl)
		makeLavaChannel(o.pos, 20, 0, isl)
		makeLavaChannel(o.pos + Vector3.new(0,0,3), 14, math.rad(90), isl)
		makeGate(o.pos + Vector3.new(0, 1.6, -(o.r-10)), isl)
		makeGate(o.pos + Vector3.new(0, 1.6,  (o.r-10)), isl)
		makeLavaPool(o.pos + Vector3.new(8, 0,-8), 7, isl)
		makeCrystals(o.pos + Vector3.new(-10, 1.6, -8), isl, LAVA_GLOW)
		makeCrystals(o.pos + Vector3.new( 10, 1.6,  8), isl, EMBER)
		makeCrate(o.pos + Vector3.new(-14, 1.6,  10), isl)
		makeCrate(o.pos + Vector3.new( 14, 1.6, -10), isl)
		scatter(o.pos, o.r, isl, 4, 16)
		makeLavaFall(o.pos + Vector3.new(o.r-3, 1, 4), 56+i*5, isl)
		makeLavaFall(o.pos + Vector3.new(-(o.r-3), 1, -4), 50+i*4, isl)
		ArenaKit.AddPowerPad(o.pos, powerPads)

		-- Bridge: T2 → nearest T1
		do
			local nearest = TIER1[i]
			local dir = nearest.pos - o.pos
			ArenaKit.MakeBridge(
				o.pos + dir.Unit*(o.r-2) + Vector3.new(0,1.6,0),
				nearest.pos - dir.Unit*(nearest.r-2) + Vector3.new(0,1.6,0),
				arena, PALETTE)
		end
	end

	-- ── Team islands ──────────────────────────────────────────────────────
	for _, o in ipairs(TEAMS) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "Team_"..o.team, PALETTE, Enum.Material.Basalt, arena)
		makeArenaRing(o.pos, 14, isl)
		makeLavaCracks(o.pos, o.r, isl)
		-- 4 scaffold towers at corners
		for _, xz in ipairs({ {-o.r+8, -o.r+8}, {o.r-8, -o.r+8}, {-o.r+8, o.r-8}, {o.r-8, o.r-8} }) do
			makeScaffold(o.pos + Vector3.new(xz[1], 1.6, xz[2]), 12, isl)
		end
		makeGate(o.pos + Vector3.new(0, 1.6,  (o.r-11)), isl)
		makeGate(o.pos + Vector3.new(0, 1.6, -(o.r-11)), isl)
		makeBanner(o.pos + Vector3.new(-o.r+10, 1.6, -10), o.team, isl)
		makeBanner(o.pos + Vector3.new( o.r-10, 1.6,  10), o.team, isl)
		makeBanner(o.pos + Vector3.new( 0,      1.6, -o.r+10), o.team, isl)
		makeLavaChannel(o.pos + Vector3.new(0,0,0), 24, 0, isl)
		makeLavaChannel(o.pos + Vector3.new(0,0,3), 18, math.rad(90), isl)
		makeLavaPool(o.pos + Vector3.new(-10, 0,-10), 8, isl)
		makeLavaPool(o.pos + Vector3.new( 10, 0, 10), 6, isl)
		makeCrystals(o.pos + Vector3.new(-14, 1.6,  10), isl, o.team=="Red" and LAVA or LAVA_GLOW)
		makeCrystals(o.pos + Vector3.new( 14, 1.6, -10), isl, EMBER)
		makeCrate(o.pos + Vector3.new(-16, 1.6,  14), isl)
		makeCrate(o.pos + Vector3.new( 16, 1.6, -14), isl)
		makeCrate(o.pos + Vector3.new( 14, 1.6,  16), isl)
		scatter(o.pos, o.r, isl, 6, 22)
		makeLavaFall(o.pos + Vector3.new(o.r-3, 1, 6), 60, isl)
		makeLavaFall(o.pos + Vector3.new(-(o.r-3), 1, -6), 56, isl)
		ArenaKit.AddTeamTriangleSpawns(o.pos, o.r, o.team, spawns)
		ArenaKit.AddTeamSpawnBeacons(o.pos, o.r, o.team, isl)

		-- Bridge: Team → nearest T2
		do
			local nearest = (o.pos.Z < 0) and TIER2[1] or TIER2[2]
			local dir = nearest.pos - o.pos
			ArenaKit.MakeBridge(
				o.pos + dir.Unit*(o.r-2) + Vector3.new(0,1.6,0),
				nearest.pos - dir.Unit*(nearest.r-2) + Vector3.new(0,1.6,0),
				arena, PALETTE)
		end
	end

	-- ── Lower flanking islands ────────────────────────────────────────────
	for i, o in ipairs(LOWER) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "Lower"..i, PALETTE, Enum.Material.Basalt, arena)
		scatter(o.pos, o.r, isl, 2, 8)
		makeScaffold(o.pos + Vector3.new(0, 1.6, 0), 10, isl)
		makeLavaCracks(o.pos, o.r, isl)
		makeLavaFall(o.pos + Vector3.new(o.r-2, 1, 0), 42+i*3, isl)
		makeCrate(o.pos + Vector3.new(6, 1.6, 6), isl)
		-- Bridge to nearest team island
		local nearestTeam = (o.pos.Z < 0) and TEAMS[1] or TEAMS[2]
		local dir = nearestTeam.pos - o.pos
		ArenaKit.MakeBridge(
			o.pos + dir.Unit*(o.r-2) + Vector3.new(0,1.6,0),
			nearestTeam.pos - dir.Unit*(nearestTeam.r-2) + Vector3.new(0,1.6,0),
			arena, PALETTE)
	end

	-- ── Satellite rocks ───────────────────────────────────────────────────
	for si, s in ipairs(SATS) do
		local isl = ArenaKit.MakeIslandBase(s.pos, s.r, "Sat"..si, PALETTE, Enum.Material.Basalt, arena)
		scatter(s.pos, s.r, isl, 1, 4)
		if si <= 3 then
			local anchP = si <= 2 and TIER1[si] or { pos = t0p, r = t0r }
			local dir = anchP.pos - s.pos
			ArenaKit.MakeBridge(s.pos + dir.Unit*(s.r-1) + Vector3.new(0,1.6,0), anchP.pos - dir.Unit*(anchP.r-2) + Vector3.new(0,1.6,0), arena, PALETTE)
		end
		makeScaffold(s.pos + Vector3.new(0, 1.6, 0), 8, isl)
		makeCrystals(s.pos + Vector3.new(0, 1.6, 0), isl, si==1 and LAVA_GLOW or EMBER)
	end

	-- ── Ambiance (orange hell) ────────────────────────────────────────────
	ArenaKit.ScatterDebris(arena, 30, PALETTE, false)
	ArenaKit.MakeClouds(arena, Color3.fromRGB(100, 55, 25), 0.45)
	ArenaKit.ApplyAtmosphere({
		Density = 0.44, Offset = 0.08,
		Color   = Color3.fromRGB(255, 145, 88),  Decay = Color3.fromRGB(128, 48, 30),
		Glare   = 0.55, Haze = 2.8,
		Ambient         = Color3.fromRGB(80, 44, 38),
		OutdoorAmbient  = Color3.fromRGB(120, 72, 55),
		ClockTime       = 20,
		FogColor        = Color3.fromRGB(70, 32, 24),
		FogEnd          = 900,
	})
	arena:SetAttribute("SpawnCount", #spawns:GetChildren())
	return arena
end

return Volcano
