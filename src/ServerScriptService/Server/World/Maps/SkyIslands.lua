--!strict
-- Map 1/3 — Sky Islands. Rebuilt to closely match reference art:
-- two-tier centre stack (windmill high + mid combat island), circular stone
-- fountain, paved arena rings, rope-rail bridges, waterfalls, dense foliage.

local Workspace = game:GetService("Workspace")
local ArenaKit   = require(script.Parent.Parent.ArenaKit)

local SkyIslands = { Id = "SkyIslands", Name = "Sky Islands" }

-- ── Palette ──────────────────────────────────────────────────────────────────
local PALETTE: ArenaKit.Palette = {
	Top      = Color3.fromRGB(112, 192, 94),   TopDark   = Color3.fromRGB(84, 158, 78),
	Stone    = Color3.fromRGB(145, 145, 155),  StoneDark = Color3.fromRGB(105, 105, 118),
	Wood     = Color3.fromRGB(145, 100, 60),   WoodDark  = Color3.fromRGB(106, 70, 44),
}
local LEAF1  = Color3.fromRGB(72, 176, 82)
local LEAF2  = Color3.fromRGB(50, 152, 62)
local WATER  = Color3.fromRGB(100, 196, 230)
local STONE  = Color3.fromRGB(158, 154, 144)
local COBBLE = Color3.fromRGB(132, 128, 120)
local CREAM  = Color3.fromRGB(230, 218, 194)

-- ── Layout ───────────────────────────────────────────────────────────────────
-- Two-tier centre matches the reference: windmill island is highest + largest;
-- a mid-combat island sits directly below it; team islands flank the bottom.
local CP   = Vector3.new( 0,  30,  0)   local CR = 40  -- windmill island
local MP   = Vector3.new( 0,   8,  0)   local MR = 32  -- mid-tier island
local OUTER = {
	{ pos = Vector3.new(  0,  0, -95), r = 30, team = "Blue" },
	{ pos = Vector3.new(  0,  0,  95), r = 30, team = "Red"  },
	{ pos = Vector3.new(-88, 10, -12), r = 24               },
	{ pos = Vector3.new( 88, 14,  12), r = 24               },
	{ pos = Vector3.new(-62, 20, -66), r = 20               },
	{ pos = Vector3.new( 62, 24,  66), r = 20               },
}
local SATS = {
	{ pos = Vector3.new( 36, 36,  40), r = 10 },
	{ pos = Vector3.new(-36, 40, -40), r =  9 },
	{ pos = Vector3.new(  0, 50,   0), r =  8 },
	{ pos = Vector3.new(-22, 14,  48), r =  7 },
	{ pos = Vector3.new( 22, 12, -48), r =  7 },
	{ pos = Vector3.new(-96,  4,  54), r =  6 },
	{ pos = Vector3.new( 96,  6, -54), r =  6 },
}

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function makeTree(pos: Vector3, parent: Instance, s: number?)
	s = s or 1
	local trunk = ArenaKit.NewPart("Trunk", Vector3.new(1.3*s, 8*s, 1.3*s), CFrame.new(pos + Vector3.new(0, 4*s, 0)), PALETTE.Wood, Enum.Material.Wood, parent)
	trunk.CanCollide = false
	local c1 = ArenaKit.NewPart("C1", Vector3.new(8*s, 7.5*s, 8*s), CFrame.new(pos + Vector3.new(0, 10*s, 0)), LEAF1, Enum.Material.Grass, parent)
	c1.Shape = Enum.PartType.Ball; c1.CanCollide = false
	local c2 = ArenaKit.NewPart("C2", Vector3.new(5.5*s, 5*s, 5.5*s), CFrame.new(pos + Vector3.new(0, 13.5*s, 0)), LEAF2, Enum.Material.Grass, parent)
	c2.Shape = Enum.PartType.Ball; c2.CanCollide = false
end

local function makeFlower(pos: Vector3, parent: Instance)
	local cols = { Color3.fromRGB(255,140,200), Color3.fromRGB(255,220,80), Color3.fromRGB(200,140,255), Color3.fromRGB(255,100,100), Color3.fromRGB(140,220,255) }
	local stem = ArenaKit.NewPart("Stem", Vector3.new(0.18, 1.1, 0.18), CFrame.new(pos + Vector3.new(0, 0.55, 0)), Color3.fromRGB(80,165,82), Enum.Material.Grass, parent)
	stem.CanCollide = false
	local b = ArenaKit.NewPart("Bloom", Vector3.new(0.8, 0.55, 0.8), CFrame.new(pos + Vector3.new(0, 1.25, 0)), cols[math.random(1,#cols)], Enum.Material.Neon, parent)
	b.Shape = Enum.PartType.Ball; b.CanCollide = false; b.CastShadow = false
end

local function scatter(center: Vector3, radius: number, parent: Instance, trees: number, flowers: number)
	for _ = 1, trees do
		local a = math.random()*math.pi*2; local r = radius*(0.22 + math.random()*0.62)
		makeTree(center + Vector3.new(math.cos(a)*r, 1.6, math.sin(a)*r), parent, 0.72 + math.random()*0.58)
	end
	for _ = 1, flowers do
		local a = math.random()*math.pi*2; local r = radius*(0.1 + math.random()*0.80)
		makeFlower(center + Vector3.new(math.cos(a)*r, 1.6, math.sin(a)*r), parent)
	end
end

local function makeCrate(pos: Vector3, parent: Instance)
	ArenaKit.NewPart("Crate",     Vector3.new(3.8, 3.8, 3.8), CFrame.new(pos + Vector3.new(0, 3.5, 0)),  PALETTE.Wood,     Enum.Material.WoodPlanks, parent).CanCollide = true
	ArenaKit.NewPart("CrateTopT", Vector3.new(4.1, 0.38, 4.1), CFrame.new(pos + Vector3.new(0, 5.3, 0)), PALETTE.WoodDark, Enum.Material.Wood,       parent).CanCollide = false
	ArenaKit.NewPart("CrateBotT", Vector3.new(4.1, 0.38, 4.1), CFrame.new(pos + Vector3.new(0, 1.8, 0)), PALETTE.WoodDark, Enum.Material.Wood,       parent).CanCollide = false
end

local function makeBarrel(pos: Vector3, parent: Instance)
	ArenaKit.NewPart("Body", Vector3.new(2.3, 3.0, 2.3), CFrame.new(pos + Vector3.new(0, 2.1, 0)), PALETTE.Wood, Enum.Material.WoodPlanks, parent).CanCollide = true
	for _, yy in ipairs({0.8, 1.7, 2.7}) do
		ArenaKit.NewPart("Hoop", Vector3.new(2.6, 0.28, 2.6), CFrame.new(pos + Vector3.new(0, yy, 0)), PALETTE.WoodDark, Enum.Material.Metal, parent).CanCollide = false
	end
end

-- Circular stone fountain (ring of blocks + water pool + centre spire)
local function makeFountain(pos: Vector3, parent: Instance)
	-- Outer base disc (wide flat slab)
	ArenaKit.NewPart("FountBase", Vector3.new(12, 0.9, 12), CFrame.new(pos + Vector3.new(0, 0.45, 0)), STONE, Enum.Material.Slate, parent).CanCollide = true
	-- Water pool
	local pool = ArenaKit.NewPart("Pool", Vector3.new(10, 0.5, 10), CFrame.new(pos + Vector3.new(0, 0.95, 0)), WATER, Enum.Material.Glass, parent)
	pool.Transparency = 0.32; pool.CanCollide = false
	-- Low stone wall ring (8 segments)
	for i = 0, 7 do
		local ang = math.rad(i*45)
		local wp = pos + Vector3.new(math.cos(ang)*5.2, 1.6, math.sin(ang)*5.2)
		ArenaKit.NewPart("FountWall"..i, Vector3.new(4.2, 1.2, 1.5), CFrame.new(wp) * CFrame.Angles(0, ang, 0), STONE, Enum.Material.Slate, parent).CanCollide = false
	end
	-- Corner pillars (4 cardinal)
	for i = 0, 3 do
		local ang = math.rad(i*90 + 22)
		ArenaKit.NewPart("FountPost"..i, Vector3.new(0.8, 4.5, 0.8), CFrame.new(pos + Vector3.new(math.cos(ang)*5.8, 2.7, math.sin(ang)*5.8)), STONE, Enum.Material.Slate, parent).CanCollide = false
	end
	-- Centre spire
	ArenaKit.NewPart("FountSpire", Vector3.new(1.2, 3.5, 1.2), CFrame.new(pos + Vector3.new(0, 2.65, 0)), STONE, Enum.Material.Slate, parent).CanCollide = false
	local spireTop = ArenaKit.NewPart("SpireTop", Vector3.new(1.8, 1.8, 1.8), CFrame.new(pos + Vector3.new(0, 4.8, 0)), WATER, Enum.Material.Neon, parent)
	spireTop.Shape = Enum.PartType.Ball; spireTop.CanCollide = false
	local glow = Instance.new("PointLight"); glow.Color = WATER; glow.Range = 12; glow.Brightness = 0.5; glow.Parent = spireTop
end

-- Decorative circular paved ring (cobble segments around a centre)
local function makeArenaRing(center: Vector3, radius: number, parent: Instance)
	local segs = 14
	for i = 0, segs-1 do
		local ang = math.rad(i*(360/segs))
		local p = center + Vector3.new(math.cos(ang)*radius, 1.64, math.sin(ang)*radius)
		ArenaKit.NewPart("Ring"..i, Vector3.new(4.8, 0.36, 2.8), CFrame.new(p) * CFrame.Angles(0, ang, 0), COBBLE, Enum.Material.Slate, parent).CanCollide = false
	end
	-- Small centre disc
	ArenaKit.NewPart("RingCenter", Vector3.new(radius*0.8, 0.34, radius*0.8), CFrame.new(center + Vector3.new(0, 1.62, 0)), COBBLE, Enum.Material.Slate, parent).CanCollide = false
end

local function makeWindmill(pos: Vector3, parent: Instance)
	local f = Instance.new("Folder"); f.Name = "Windmill"; f.Parent = parent
	-- Stone plinth
	ArenaKit.NewPart("Plinth",    Vector3.new(9, 1.6, 9),   CFrame.new(pos + Vector3.new(0, 0.8,  0)), STONE,            Enum.Material.Slate,    f).CanCollide = true
	-- Stone lower tower
	ArenaKit.NewPart("TowerLow",  Vector3.new(5.8, 12, 5.8), CFrame.new(pos + Vector3.new(0, 7,    0)), STONE,            Enum.Material.Slate,    f).CanCollide = true
	-- Plaster upper tower
	ArenaKit.NewPart("TowerHigh", Vector3.new(5.0, 11, 5.0), CFrame.new(pos + Vector3.new(0, 17.5, 0)), CREAM,            Enum.Material.Concrete, f).CanCollide = true
	-- Trim band
	ArenaKit.NewPart("Trim",      Vector3.new(7.0, 1.2, 7.0), CFrame.new(pos + Vector3.new(0, 13,   0)), PALETTE.WoodDark, Enum.Material.Wood,     f).CanCollide = false
	-- Balcony ring posts
	for i = 0, 7 do
		local ang = math.rad(i*45)
		ArenaKit.NewPart("BalcPost"..i, Vector3.new(0.4, 2.0, 0.4), CFrame.new(pos + Vector3.new(math.cos(ang)*3.1, 14.2, math.sin(ang)*3.1)), PALETTE.WoodDark, Enum.Material.Wood, f).CanCollide = false
	end
	ArenaKit.NewPart("BalcRail",  Vector3.new(0.3, 0.3, 20), CFrame.new(pos + Vector3.new(0, 15.0, 0)),  PALETTE.Wood, Enum.Material.Wood, f).CanCollide = false
	-- Conical roof
	ArenaKit.NewPart("Roof",      Vector3.new(7.5, 6.0, 7.5), CFrame.new(pos + Vector3.new(0, 27, 0)),   Color3.fromRGB(158,72,62),  Enum.Material.Slate, f)
	local tip = ArenaKit.NewPart("RoofTip", Vector3.new(2.0, 2.5, 2.0), CFrame.new(pos + Vector3.new(0, 31, 0)), Color3.fromRGB(136,58,50), Enum.Material.Slate, f)
	tip.Shape = Enum.PartType.Ball
	-- Hub
	local hub = ArenaKit.NewPart("Hub", Vector3.new(1.8, 1.8, 1.8), CFrame.new(pos + Vector3.new(0, 21, -3.2)), PALETTE.WoodDark, Enum.Material.Wood, f)
	hub.Shape = Enum.PartType.Ball
	local blades = Instance.new("Model"); blades.Name = "Blades"; blades.Parent = f
	hub.Parent = blades; blades.PrimaryPart = hub
	for i = 0, 3 do
		local ang = math.rad(i*90 + 18)
		local arm = ArenaKit.NewPart("Arm"..i, Vector3.new(0.65, 12, 0.65),
			CFrame.new(pos + Vector3.new(0, 21, -3.6)) * CFrame.Angles(0,0,ang) * CFrame.new(0,6,0),
			PALETTE.WoodDark, Enum.Material.Wood, blades); arm.CanCollide = false
		local sail = ArenaKit.NewPart("Sail"..i, Vector3.new(4.5, 10, 0.35),
			CFrame.new(pos + Vector3.new(0, 21, -3.9)) * CFrame.Angles(0,0,ang) * CFrame.new(0,6,0),
			Color3.fromRGB(248,244,234), Enum.Material.SmoothPlastic, blades); sail.CanCollide = false
		-- Cross-slat on sail
		local slat = ArenaKit.NewPart("Slat"..i, Vector3.new(3.8, 0.45, 0.42),
			CFrame.new(pos + Vector3.new(0, 21, -4.1)) * CFrame.Angles(0,0,ang) * CFrame.new(0,3,0),
			PALETTE.WoodDark, Enum.Material.Wood, blades); slat.CanCollide = false
	end
	local pivot = CFrame.new(pos + Vector3.new(0, 21, -3.2))
	task.spawn(function()
		local a = 0
		while blades.Parent do a += 0.016; pcall(function() blades:PivotTo(pivot * CFrame.Angles(0,0,a)) end); task.wait() end
	end)
end

local function makeHouse(pos: Vector3, parent: Instance, s: number?)
	s = s or 1
	local f = Instance.new("Folder"); f.Name = "House"; f.Parent = parent
	ArenaKit.NewPart("Fnd",  Vector3.new(9.8*s, 1.0*s, 8.8*s), CFrame.new(pos + Vector3.new(0, 0.5*s, 0)),  STONE,                  Enum.Material.Slate,    f).CanCollide = true
	ArenaKit.NewPart("Body", Vector3.new(9.2*s, 7.2*s, 8.2*s), CFrame.new(pos + Vector3.new(0, 4.1*s, 0)),  Color3.fromRGB(228,214,186), Enum.Material.Concrete, f).CanCollide = true
	local roof = Instance.new("WedgePart")
	roof.Name="Roof"; roof.Size=Vector3.new(11*s, 5.2*s, 9.4*s)
	roof.CFrame=CFrame.new(pos + Vector3.new(0,9.6*s,0))*CFrame.Angles(0,math.rad(90),0)
	roof.Color=Color3.fromRGB(160,78,62); roof.Material=Enum.Material.Slate; roof.Anchored=true; roof.CanCollide=true; roof.Parent=f
	ArenaKit.NewPart("Door",    Vector3.new(1.9*s, 3.4*s, 0.22*s), CFrame.new(pos + Vector3.new(0, 1.7*s, -4.2*s)),     PALETTE.WoodDark, Enum.Material.Wood,  f).CanCollide = false
	for _, x in ipairs({-2.8, 2.8}) do
		local w=ArenaKit.NewPart("Win", Vector3.new(1.9*s, 1.9*s, 0.18*s), CFrame.new(pos + Vector3.new(x*s, 4.2*s, -4.2*s)), Color3.fromRGB(115,208,244), Enum.Material.Glass, f)
		w.Transparency=0.2; w.CanCollide=false
	end
	ArenaKit.NewPart("Chim", Vector3.new(1.4*s, 4.0*s, 1.4*s), CFrame.new(pos + Vector3.new(3*s, 11*s, 0)), Color3.fromRGB(130,90,80), Enum.Material.Brick, f).CanCollide = true
	for _, x in ipairs({-2.8, 2.8}) do
		ArenaKit.NewPart("WinBox", Vector3.new(2.1*s, 0.55*s, 0.8*s), CFrame.new(pos + Vector3.new(x*s, 3.0*s, -4.4*s)), Color3.fromRGB(72,128,56), Enum.Material.Grass, f).CanCollide = false
	end
end

local function makeWaterfall(top: Vector3, height: number, parent: Instance)
	local f = Instance.new("Folder"); f.Name = "WF"; f.Parent = parent
	local w = ArenaKit.NewPart("Sheet", Vector3.new(7, height, 1.5), CFrame.new(top - Vector3.new(0, height/2, 0)), WATER, Enum.Material.Glass, f)
	w.Transparency = 0.24; w.CanCollide = false
	local m = ArenaKit.NewPart("Mist", Vector3.new(11, 5.5, 9), CFrame.new(top - Vector3.new(0, height+2.5, 0)), Color3.fromRGB(225,248,255), Enum.Material.ForceField, f)
	m.Transparency=0.52; m.CanCollide=false
	local p = ArenaKit.NewPart("Pool", Vector3.new(10, 0.5, 10), CFrame.new(top - Vector3.new(0, height+2.0, 0)), WATER, Enum.Material.Glass, f)
	p.Transparency=0.32; p.CanCollide=false
end

local function makeLamp(pos: Vector3, parent: Instance, color: Color3?)
	local c = color or Color3.fromRGB(255,230,140)
	ArenaKit.NewPart("Pole", Vector3.new(0.5, 7, 0.5), CFrame.new(pos + Vector3.new(0, 3.5, 0)), STONE, Enum.Material.Slate, parent).CanCollide = false
	ArenaKit.NewPart("Arm",  Vector3.new(0.35, 0.35, 2.2), CFrame.new(pos + Vector3.new(0, 7.1, 1.1)), STONE, Enum.Material.Slate, parent).CanCollide = false
	local orb = ArenaKit.NewPart("Orb", Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 7.3, 2.1)), c, Enum.Material.Neon, parent)
	orb.Shape = Enum.PartType.Ball; orb.CanCollide = false
	local pl = Instance.new("PointLight"); pl.Color=c; pl.Range=16; pl.Brightness=0.72; pl.Parent=orb
end

local function makeFence(origin: Vector3, length: number, yaw: number, parent: Instance)
	local posts = math.max(2, math.floor(length/3.5))
	for i = 0, posts do
		local t = i/posts
		local ox, oz = math.cos(yaw)*(length*t - length/2), math.sin(yaw)*(length*t - length/2)
		ArenaKit.NewPart("Post", Vector3.new(0.5, 3.6, 0.5), CFrame.new(origin + Vector3.new(ox, 1.8, oz)), PALETTE.WoodDark, Enum.Material.Wood, parent).CanCollide = false
	end
	for _, yy in ipairs({1.1, 2.7}) do
		ArenaKit.NewPart("Rail", Vector3.new(length, 0.32, 0.35), CFrame.new(origin + Vector3.new(0, yy, 0)) * CFrame.Angles(0, yaw, 0), PALETTE.Wood, Enum.Material.Wood, parent).CanCollide = false
	end
end

local function makeArch(pos: Vector3, parent: Instance)
	for _, x in ipairs({-5.2, 5.2}) do
		ArenaKit.NewPart("Pil", Vector3.new(1.9, 9, 1.9), CFrame.new(pos + Vector3.new(x, 4.5, 0)), STONE, Enum.Material.Slate, parent).CanCollide = true
	end
	ArenaKit.NewPart("Lintel",  Vector3.new(13, 2.0, 2.4), CFrame.new(pos + Vector3.new(0, 9.2, 0)),  STONE,            Enum.Material.Slate, parent).CanCollide = true
	ArenaKit.NewPart("ArchBeam",Vector3.new(11, 0.5, 0.5), CFrame.new(pos + Vector3.new(0, 8.2, -1.2)), PALETTE.WoodDark, Enum.Material.Wood,  parent).CanCollide = false
end

local function makeBanner(pos: Vector3, teamId: string, parent: Instance)
	local col = teamId=="Red" and Color3.fromRGB(255,75,90) or Color3.fromRGB(55,168,255)
	ArenaKit.NewPart("Pole",   Vector3.new(0.55, 12, 0.55), CFrame.new(pos + Vector3.new(0,6,0)),     PALETTE.WoodDark, Enum.Material.Wood,   parent).CanCollide = false
	local flag = ArenaKit.NewPart("Flag", Vector3.new(6.0, 3.2, 0.22), CFrame.new(pos + Vector3.new(3.0,10,0)), col, Enum.Material.Fabric, parent)
	flag.CanCollide = false
	local tip = ArenaKit.NewPart("Tip", Vector3.new(0.8,0.8,0.8), CFrame.new(pos + Vector3.new(0,12.6,0)), Color3.fromRGB(255,226,60), Enum.Material.Neon, parent)
	tip.Shape = Enum.PartType.Ball; tip.CanCollide = false
	local pl=Instance.new("PointLight"); pl.Color=col; pl.Range=14; pl.Brightness=0.45; pl.Parent=flag
end

local function makePath(origin: Vector3, dir: Vector3, count: number, parent: Instance)
	for i = 1, count do
		local off = dir.Unit*((i-1)*3.0)
		ArenaKit.NewPart("Path"..i, Vector3.new(2.8, 0.36, 2.1), CFrame.new(origin+off+Vector3.new(0,1.63,0)) * CFrame.Angles(0, math.rad((i%3-1)*10), 0), COBBLE, Enum.Material.Slate, parent).CanCollide = false
	end
end

local function makeSteps(base: Vector3, dir: Vector3, count: number, parent: Instance)
	for i = 1, count do
		ArenaKit.NewPart("Step"..i, Vector3.new(9, 0.4*i, 1.2), CFrame.new(base + dir.Unit*(i-1)*1.2 + Vector3.new(0, 1.62 + 0.4*(i-1)/2, 0)), COBBLE, Enum.Material.Slate, parent).CanCollide = true
	end
end

-- Raised stone terrace block
local function makeTerrace(pos: Vector3, sx: number, sz: number, parent: Instance)
	ArenaKit.NewPart("Terrace", Vector3.new(sx, 1.3, sz), CFrame.new(pos), COBBLE, Enum.Material.Slate, parent).CanCollide = true
end

-- ── Build ─────────────────────────────────────────────────────────────────────

function SkyIslands.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, SkyIslands.Name)

	-- ─────────────────────────────────────────────────────────────────────────
	-- WINDMILL ISLAND  (highest, biggest, the reference's top centrepiece)
	-- ─────────────────────────────────────────────────────────────────────────
	local centerIsl = ArenaKit.MakeIslandBase(CP, CR, "WindmillIsland", PALETTE, Enum.Material.Grass, arena)

	-- Back terrace with windmill on top
	makeTerrace(CP + Vector3.new(0, 2.0, -14), 22, 20, centerIsl)
	makeSteps(CP + Vector3.new(0,0,-2), Vector3.new(0,0,-1), 4, centerIsl)
	makeSteps(CP + Vector3.new(-12, 0, -14), Vector3.new(1, 0, 0), 3, centerIsl)
	makeWindmill(CP + Vector3.new(0, 3.4, -18), centerIsl)  -- sits on terrace

	-- Fountain forward of centre
	makeFountain(CP + Vector3.new(0, 1.6, 4), centerIsl)

	-- Arena paving ring on front lower area
	makeArenaRing(CP + Vector3.new(0, 0, 10), 14, centerIsl)

	-- Houses
	makeHouse(CP + Vector3.new(-21, 1.6, -10), centerIsl, 0.88)
	makeHouse(CP + Vector3.new( 18, 1.6,  7),  centerIsl, 0.74)

	-- Arch gateways (one per bridge + left/right)
	makeArch(CP + Vector3.new(  0, 1.6,  27), centerIsl)
	makeArch(CP + Vector3.new(-33, 1.6,   0), centerIsl)
	makeArch(CP + Vector3.new( 33, 1.6,   0), centerIsl)
	makeArch(CP + Vector3.new(  0, 1.6, -33), centerIsl)

	-- Stone paths
	makePath(CP + Vector3.new(  0, 0,  22), Vector3.new(0,0,-1), 10, centerIsl)
	makePath(CP + Vector3.new( -6, 0,  4),  Vector3.new(0,0,-1),  5, centerIsl)

	-- Fences
	makeFence(CP + Vector3.new(-26, 1.6, -9), 28, math.rad(90), centerIsl)
	makeFence(CP + Vector3.new(-35, 1.6,  5), 20, 0,            centerIsl)
	makeFence(CP + Vector3.new( 35, 1.6, -5), 20, 0,            centerIsl)
	makeFence(CP + Vector3.new( 26, 1.6, 9),  24, math.rad(90), centerIsl)
	makeFence(CP + Vector3.new(  0, 1.6,-33), 22, 0,            centerIsl)

	-- Lamps
	makeLamp(CP + Vector3.new(-13, 1.6, 22), centerIsl)
	makeLamp(CP + Vector3.new( 13, 1.6, 22), centerIsl)
	makeLamp(CP + Vector3.new(-22, 1.6,  2), centerIsl)
	makeLamp(CP + Vector3.new( 22, 1.6, -2), centerIsl)
	makeLamp(CP + Vector3.new(  2, 3.4,-26), centerIsl, Color3.fromRGB(200,230,255))

	-- Props
	makeCrate(CP + Vector3.new(-19, 1.6, 14), centerIsl)
	makeCrate(CP + Vector3.new( 21, 1.6,-14), centerIsl)
	makeBarrel(CP + Vector3.new(-12, 1.6,-20), centerIsl)
	makeBarrel(CP + Vector3.new( 14, 1.6, 17), centerIsl)
	makeBarrel(CP + Vector3.new( 10, 1.6,-22), centerIsl)
	makeBarrel(CP + Vector3.new(-14, 3.4,-18), centerIsl) -- on terrace

	-- Foliage
	scatter(CP, CR, centerIsl, 15, 60)

	-- Waterfalls (3 sides — left, right, back)
	makeWaterfall(CP + Vector3.new(CR-4, 1.2,  10), 80, centerIsl)
	makeWaterfall(CP + Vector3.new(-(CR-4), 1.2, -10), 74, centerIsl)
	makeWaterfall(CP + Vector3.new(  8, 1.2,  CR-4), 65, centerIsl)

	-- Power pad on terrace
	ArenaKit.AddPowerPad(CP + Vector3.new(0, 3.4, -10), powerPads)

	-- ─────────────────────────────────────────────────────────────────────────
	-- MID-TIER ISLAND  (directly below windmill — the reference's second large
	-- platform; has a circular arena ring, waterfall, and bridges outward)
	-- ─────────────────────────────────────────────────────────────────────────
	local midIsl = ArenaKit.MakeIslandBase(MP, MR, "MidIsland", PALETTE, Enum.Material.Grass, arena)

	makeArenaRing(MP, 16, midIsl)           -- big stone combat ring
	makeFountain(MP + Vector3.new(0, 1.6, 0), midIsl)
	scatter(MP, MR, midIsl, 8, 30)
	makeWaterfall(MP + Vector3.new(MR-3, 1.2,  4), 55, midIsl)
	makeWaterfall(MP + Vector3.new(-(MR-3), 1.2, -4), 48, midIsl)
	makeFence(MP + Vector3.new(0, 1.6, -(MR-6)), 26, 0, midIsl)
	makeFence(MP + Vector3.new(0, 1.6,  (MR-6)), 26, 0, midIsl)
	makeArch(MP + Vector3.new(-(MR-8), 1.6, 0), midIsl)
	makeArch(MP + Vector3.new( (MR-8), 1.6, 0), midIsl)
	makeLamp(MP + Vector3.new(-14, 1.6,  10), midIsl)
	makeLamp(MP + Vector3.new( 14, 1.6, -10), midIsl)
	makeCrate(MP + Vector3.new(-18, 1.6, -12), midIsl)
	makeCrate(MP + Vector3.new( 18, 1.6,  12), midIsl)
	makeBarrel(MP + Vector3.new(-8, 1.6,  18), midIsl)
	makeBarrel(MP + Vector3.new( 8, 1.6, -18), midIsl)
	ArenaKit.AddPowerPad(MP + Vector3.new(0, 1.6, 0), powerPads)

	-- Bridge: centre windmill ↔ mid-tier (vertical drop)
	do
		local dir = MP - CP
		ArenaKit.MakeBridge(
			CP + dir.Unit*(CR-2) + Vector3.new(0, 1.6, 0),
			MP - dir.Unit*(MR-2) + Vector3.new(0, 1.6, 0),
			arena, PALETTE)
	end

	-- ─────────────────────────────────────────────────────────────────────────
	-- OUTER ISLANDS
	-- ─────────────────────────────────────────────────────────────────────────
	for i, o in ipairs(OUTER) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "Island"..i, PALETTE, Enum.Material.Grass, arena)
		scatter(o.pos, o.r, isl, 8, 28)
		makeWaterfall(o.pos + Vector3.new(o.r-3,  1, 5), 50+i*4, isl)
		makeWaterfall(o.pos + Vector3.new(-(o.r-3),1,-5), 44+i*3, isl)

		if o.team then
			-- Team island: banners, arch, fences, fountain, house, path, lamps, props
			makeArenaRing(o.pos, 12, isl)
			makeArch(o.pos + Vector3.new(0, 1.6, o.r-11), isl)
			makeBanner(o.pos + Vector3.new(-o.r+10, 1.6, -10), o.team, isl)
			makeBanner(o.pos + Vector3.new( o.r-10, 1.6,  10), o.team, isl)
			makeFence(o.pos + Vector3.new(0,         1.6, -(o.r-8)), 24, 0,            isl)
			makeFence(o.pos + Vector3.new(-(o.r-8),  1.6, 0),        22, math.rad(90), isl)
			makeFence(o.pos + Vector3.new( (o.r-8),  1.6, 0),        22, math.rad(90), isl)
			makePath(o.pos + Vector3.new(0,0, o.r-13), Vector3.new(0,0,-1), 9, isl)
			makeFountain(o.pos + Vector3.new(0, 1.6, -4), isl)
			makeHouse(o.pos + Vector3.new(-10, 1.6, -10), isl, 0.80)
			makeLamp(o.pos + Vector3.new(-10, 1.6,  10), isl)
			makeLamp(o.pos + Vector3.new( 10, 1.6,  10), isl)
			makeLamp(o.pos + Vector3.new(  0, 1.6, -20), isl)
			makeCrate(o.pos + Vector3.new( 12, 1.6, -12), isl)
			makeBarrel(o.pos + Vector3.new(-12, 1.6, 12), isl)
			makeBarrel(o.pos + Vector3.new( 12, 1.6,  6), isl)
			ArenaKit.AddTeamTriangleSpawns(o.pos, o.r, o.team, spawns)
			ArenaKit.AddTeamSpawnBeacons(o.pos, o.r, o.team, isl)
		else
			if i == 3 or i == 5 then
				makeWindmill(o.pos + Vector3.new(0, 1.6, -5), isl)
			else
				makeHouse(o.pos + Vector3.new(-5, 1.6, 3), isl, 0.74)
			end
			makeArch(o.pos + Vector3.new(0, 1.6, -(o.r-10)), isl)
			makeFence(o.pos + Vector3.new(0, 1.6, o.r-7), 20, 0, isl)
			makeLamp(o.pos + Vector3.new(-10, 1.6,  8), isl)
			makeLamp(o.pos + Vector3.new( 10, 1.6, -8), isl)
			makeCrate(o.pos + Vector3.new(8, 1.6,  8), isl)
			makeBarrel(o.pos + Vector3.new(-8, 1.6, -8), isl)
			makeBarrel(o.pos + Vector3.new( 8, 1.6, -5), isl)
			ArenaKit.AddPowerPad(o.pos, powerPads)
		end

		-- Bridge each outer island → mid-tier
		do
			local dir = MP - o.pos
			ArenaKit.MakeBridge(
				o.pos + dir.Unit*(o.r-2) + Vector3.new(0, 1.6, 0),
				MP    - dir.Unit*(MR-2)  + Vector3.new(0, 1.6, 0),
				arena, PALETTE)
		end
	end

	-- Cross-bridges between neighbouring outer islands
	local function xBridge(a: any, b: any)
		local d = b.pos - a.pos
		ArenaKit.MakeBridge(
			a.pos + d.Unit*(a.r-2) + Vector3.new(0,1.6,0),
			b.pos - d.Unit*(b.r-2) + Vector3.new(0,1.6,0),
			arena, PALETTE)
	end
	xBridge(OUTER[1], OUTER[3])   -- Blue  ↔ left neutral
	xBridge(OUTER[2], OUTER[4])   -- Red   ↔ right neutral
	xBridge(OUTER[3], OUTER[5])   -- left neutral  ↔ upper-left
	xBridge(OUTER[4], OUTER[6])   -- right neutral ↔ upper-right

	-- ─────────────────────────────────────────────────────────────────────────
	-- SATELLITE ROCKS
	-- ─────────────────────────────────────────────────────────────────────────
	for si, s in ipairs(SATS) do
		local isl = ArenaKit.MakeIslandBase(s.pos, s.r, "Sat"..si, PALETTE, Enum.Material.Grass, arena)
		scatter(s.pos, s.r, isl, 2, 7)
		if si == 1 then makeLamp(s.pos + Vector3.new(0,1.6,0), isl, Color3.fromRGB(180,225,255))
		elseif si == 2 then makeBarrel(s.pos + Vector3.new(0,1.6,0), isl)
		elseif si == 3 then makeFountain(s.pos + Vector3.new(0,1.6,0), isl)
		end
		-- Bridge tiny sats to centre or mid
		if si <= 3 then
			local anchor = si == 3 and MP or CP
			local aR     = si == 3 and MR or CR
			local d = anchor - s.pos
			ArenaKit.MakeBridge(s.pos + d.Unit*(s.r-1) + Vector3.new(0,1.6,0), anchor - d.Unit*(aR-2) + Vector3.new(0,1.6,0), arena, PALETTE)
		end
	end

	-- ─────────────────────────────────────────────────────────────────────────
	-- AMBIANCE
	-- ─────────────────────────────────────────────────────────────────────────
	ArenaKit.ScatterDebris(arena, 32, PALETTE)
	ArenaKit.MakeClouds(arena, Color3.fromRGB(255,255,255), 0.23)
	ArenaKit.ApplyAtmosphere({
		Density=0.13, Offset=0.21,
		Color=Color3.fromRGB(190,226,255), Decay=Color3.fromRGB(88,163,226),
		Glare=0.40, Haze=0.60,
		Ambient=Color3.fromRGB(145,186,234), OutdoorAmbient=Color3.fromRGB(186,218,255),
		ClockTime=10.5, FogColor=Color3.fromRGB(168,216,255), FogEnd=1300,
	})
	arena:SetAttribute("SpawnCount", #spawns:GetChildren())
	return arena
end

return SkyIslands
