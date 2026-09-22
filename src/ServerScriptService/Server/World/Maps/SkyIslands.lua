--!strict
-- Map 1/3: Sky Islands — lush grassy floating islands rebuilt to match
-- reference art: prominent windmill, stone well, dense trees, waterfalls,
-- fences, lamp-posts, barrels, crates, and stone cobble paths.

local Workspace = game:GetService("Workspace")
local ArenaKit = require(script.Parent.Parent.ArenaKit)

local SkyIslands = { Id = "SkyIslands", Name = "Sky Islands" }

local PALETTE: ArenaKit.Palette = {
	Top = Color3.fromRGB(118, 196, 100), TopDark = Color3.fromRGB(90, 162, 84),
	Stone = Color3.fromRGB(148, 148, 158), StoneDark = Color3.fromRGB(108, 108, 120),
	Wood = Color3.fromRGB(148, 102, 62), WoodDark = Color3.fromRGB(108, 72, 46),
}
local LEAF  = Color3.fromRGB(78, 178, 88)
local LEAF2 = Color3.fromRGB(56, 158, 68)
local WATER = Color3.fromRGB(110, 200, 235)
local STONE = Color3.fromRGB(160, 156, 146)
local COBBLE = Color3.fromRGB(136, 132, 124)

-- Per-map layout — the windmill island sits highest and most central;
-- team islands are large and close; neutrals fill the mid-range.
local LAYOUT = {
	Center   = { pos = Vector3.new(0, 22, 0),    r = 38 },
	Outer    = {
		{ pos = Vector3.new(0,   4, -88),  r = 28, team = "Blue" },
		{ pos = Vector3.new(0,   4,  88),  r = 28, team = "Red"  },
		{ pos = Vector3.new(-80, 10, -10), r = 24               },
		{ pos = Vector3.new( 80, 14,  10), r = 24               },
		{ pos = Vector3.new(-58, 20, -62), r = 20               },
		{ pos = Vector3.new( 58, 24,  62), r = 20               },
	},
	Satellites = {
		{ pos = Vector3.new( 34, 32,  38), r = 10 },
		{ pos = Vector3.new(-34, 36, -38), r =  9 },
		{ pos = Vector3.new(  0, 46,   0), r =  8 },
		{ pos = Vector3.new(-20, 12,  46), r =  7 },
		{ pos = Vector3.new( 20, 10, -46), r =  7 },
		{ pos = Vector3.new(-92, 4,   52), r =  6 },
		{ pos = Vector3.new( 92, 6,  -52), r =  6 },
	},
}

-- ─── Decoration helpers ───────────────────────────────────────────────────────

local function makeTree(pos: Vector3, parent: Instance, scale: number?)
	local s = scale or 1
	local trunk = ArenaKit.NewPart("Trunk", Vector3.new(1.2*s, 7*s, 1.2*s), CFrame.new(pos + Vector3.new(0, 3.5*s, 0)), PALETTE.Wood, Enum.Material.Wood, parent)
	trunk.CanCollide = false
	local canopy = ArenaKit.NewPart("Canopy", Vector3.new(7*s, 7*s, 7*s), CFrame.new(pos + Vector3.new(0, 9*s, 0)), LEAF, Enum.Material.Grass, parent)
	canopy.Shape = Enum.PartType.Ball
	canopy.CanCollide = false
	local top = ArenaKit.NewPart("CanopyTop", Vector3.new(4.5*s, 4.5*s, 4.5*s), CFrame.new(pos + Vector3.new(0, 12*s, 0)), LEAF2, Enum.Material.Grass, parent)
	top.Shape = Enum.PartType.Ball
	top.CanCollide = false
end

local function makeFlower(pos: Vector3, parent: Instance)
	local colors = {
		Color3.fromRGB(255, 140, 200), Color3.fromRGB(255, 220, 80),
		Color3.fromRGB(200, 140, 255), Color3.fromRGB(255, 100, 100),
		Color3.fromRGB(140, 220, 255),
	}
	local stem = ArenaKit.NewPart("Stem", Vector3.new(0.18, 1.1, 0.18), CFrame.new(pos + Vector3.new(0, 0.55, 0)), Color3.fromRGB(80, 165, 82), Enum.Material.Grass, parent)
	stem.CanCollide = false
	local bloom = ArenaKit.NewPart("Bloom", Vector3.new(0.75, 0.5, 0.75), CFrame.new(pos + Vector3.new(0, 1.2, 0)), colors[math.random(1, #colors)], Enum.Material.Neon, parent)
	bloom.Shape = Enum.PartType.Ball
	bloom.CanCollide = false
	bloom.CastShadow = false
end

local function scatterDecor(center: Vector3, radius: number, parent: Instance, trees: number, flowers: number)
	for _ = 1, trees do
		local a = math.random() * math.pi * 2
		local r = radius * (0.25 + math.random() * 0.60)
		makeTree(center + Vector3.new(math.cos(a)*r, 1.6, math.sin(a)*r), parent, 0.75 + math.random()*0.55)
	end
	for _ = 1, flowers do
		local a = math.random() * math.pi * 2
		local r = radius * (0.12 + math.random() * 0.78)
		makeFlower(center + Vector3.new(math.cos(a)*r, 1.6, math.sin(a)*r), parent)
	end
end

local function makeCrate(pos: Vector3, parent: Instance)
	local box = ArenaKit.NewPart("Crate", Vector3.new(3.8, 3.8, 3.8), CFrame.new(pos + Vector3.new(0, 3.5, 0)), PALETTE.Wood, Enum.Material.WoodPlanks, parent)
	box.CanCollide = true
	ArenaKit.NewPart("CrateTrimH", Vector3.new(4.1, 0.36, 4.1), CFrame.new(pos + Vector3.new(0, 5.3, 0)), PALETTE.WoodDark, Enum.Material.Wood, parent).CanCollide = false
	ArenaKit.NewPart("CrateTrimL", Vector3.new(4.1, 0.36, 4.1), CFrame.new(pos + Vector3.new(0, 1.8, 0)), PALETTE.WoodDark, Enum.Material.Wood, parent).CanCollide = false
end

local function makeBarrel(pos: Vector3, parent: Instance)
	local body = ArenaKit.NewPart("Barrel", Vector3.new(2.2, 2.8, 2.2), CFrame.new(pos + Vector3.new(0, 2.0, 0)), PALETTE.Wood, Enum.Material.WoodPlanks, parent)
	body.CanCollide = true
	for _, yy in ipairs({ 0.8, 1.6, 2.6 }) do
		ArenaKit.NewPart("Hoop", Vector3.new(2.5, 0.26, 2.5), CFrame.new(pos + Vector3.new(0, yy, 0)), PALETTE.WoodDark, Enum.Material.Metal, parent).CanCollide = false
	end
end

local function makeWell(pos: Vector3, parent: Instance)
	-- Stone base and water
	ArenaKit.NewPart("WellBase", Vector3.new(4.5, 1.2, 4.5), CFrame.new(pos + Vector3.new(0, 0.6, 0)), STONE, Enum.Material.Slate, parent).CanCollide = true
	local water = ArenaKit.NewPart("WellWater", Vector3.new(3.2, 0.3, 3.2), CFrame.new(pos + Vector3.new(0, 1.35, 0)), WATER, Enum.Material.Glass, parent)
	water.Transparency = 0.35
	water.CanCollide = false
	-- Low stone wall (4 sides)
	for _, info in ipairs({
		{ Vector3.new(4.4, 1.4, 0.5), Vector3.new(0, 1.9, 2.0)  },
		{ Vector3.new(4.4, 1.4, 0.5), Vector3.new(0, 1.9, -2.0) },
		{ Vector3.new(0.5, 1.4, 4.4), Vector3.new(2.0, 1.9, 0)  },
		{ Vector3.new(0.5, 1.4, 4.4), Vector3.new(-2.0, 1.9, 0) },
	}) do
		ArenaKit.NewPart("WellWall", info[1], CFrame.new(pos + info[2]), STONE, Enum.Material.Slate, parent).CanCollide = false
	end
	-- Corner posts
	for _, xz in ipairs({ {-2,  -2}, { 2, -2}, {-2, 2}, { 2, 2} }) do
		ArenaKit.NewPart("Post", Vector3.new(0.42, 4.8, 0.42), CFrame.new(pos + Vector3.new(xz[1], 3.6, xz[2])), PALETTE.WoodDark, Enum.Material.Wood, parent).CanCollide = false
	end
	-- Crossbeams
	ArenaKit.NewPart("Beam1", Vector3.new(4.6, 0.4, 0.42), CFrame.new(pos + Vector3.new(0, 6.0, 0)), PALETTE.WoodDark, Enum.Material.Wood, parent).CanCollide = false
	ArenaKit.NewPart("Beam2", Vector3.new(0.42, 0.4, 4.6), CFrame.new(pos + Vector3.new(0, 6.0, 0)), PALETTE.WoodDark, Enum.Material.Wood, parent).CanCollide = false
	-- Roof halves (two wedges)
	for _, z in ipairs({ -1, 1 }) do
		local roof = Instance.new("WedgePart")
		roof.Name = "WellRoof"
		roof.Size = Vector3.new(5.2, 2.2, 2.4)
		roof.CFrame = CFrame.new(pos + Vector3.new(0, 7.0, z * 1.2)) * CFrame.Angles(0, z > 0 and 0 or math.rad(180), 0)
		roof.Color = PALETTE.Wood
		roof.Material = Enum.Material.WoodPlanks
		roof.Anchored = true
		roof.CanCollide = false
		roof.Parent = parent
	end
end

local function makeWindmill(pos: Vector3, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Windmill"
	folder.Parent = parent
	-- Base stone platform
	ArenaKit.NewPart("MillBase", Vector3.new(8, 1.4, 8), CFrame.new(pos + Vector3.new(0, 0.7, 0)), STONE, Enum.Material.Slate, folder).CanCollide = true
	-- Lower stone tower
	ArenaKit.NewPart("TowerLow", Vector3.new(5.4, 11, 5.4), CFrame.new(pos + Vector3.new(0, 6.5, 0)), STONE, Enum.Material.Slate, folder).CanCollide = true
	-- Upper plaster tower
	ArenaKit.NewPart("TowerHigh", Vector3.new(4.6, 10, 4.6), CFrame.new(pos + Vector3.new(0, 16, 0)), Color3.fromRGB(230, 218, 195), Enum.Material.Concrete, folder).CanCollide = true
	-- Band trim at junction
	ArenaKit.NewPart("TowerTrim", Vector3.new(6.2, 1.0, 6.2), CFrame.new(pos + Vector3.new(0, 11.5, 0)), PALETTE.WoodDark, Enum.Material.Wood, folder).CanCollide = false
	-- Balcony railing at trim
	for _, ang in ipairs({ 0, 90, 180, 270 }) do
		local a = math.rad(ang)
		ArenaKit.NewPart("BalcRail", Vector3.new(5.8, 0.3, 0.3), CFrame.new(pos + Vector3.new(math.sin(a)*0.1, 12.5, math.cos(a)*0.1)) * CFrame.Angles(0, a, 0), PALETTE.Wood, Enum.Material.Wood, folder).CanCollide = false
	end
	-- Roof
	ArenaKit.NewPart("Roof", Vector3.new(7, 5.5, 7), CFrame.new(pos + Vector3.new(0, 24, 0)), Color3.fromRGB(162, 78, 68), Enum.Material.Slate, folder)
	local tip = ArenaKit.NewPart("RoofTip", Vector3.new(2, 2.5, 2), CFrame.new(pos + Vector3.new(0, 27.5, 0)), Color3.fromRGB(140, 60, 52), Enum.Material.Slate, folder)
	tip.Shape = Enum.PartType.Ball

	-- Hub (blade pivot point)
	local hub = ArenaKit.NewPart("Hub", Vector3.new(1.6, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, 19, -3.0)), PALETTE.WoodDark, Enum.Material.Wood, folder)
	hub.Shape = Enum.PartType.Ball

	local blades = Instance.new("Model")
	blades.Name = "Blades"
	blades.Parent = folder
	hub.Parent = blades
	blades.PrimaryPart = hub

	for i = 0, 3 do
		local ang = math.rad(i * 90 + 20)
		-- Spoke arm
		local arm = ArenaKit.NewPart("Arm" .. i, Vector3.new(0.6, 11, 0.6), CFrame.new(pos + Vector3.new(0, 19, -3.4)) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 5.5, 0), PALETTE.WoodDark, Enum.Material.Wood, blades)
		arm.CanCollide = false
		-- Wide blade sail
		local blade = ArenaKit.NewPart("Blade" .. i, Vector3.new(4.0, 9.0, 0.32), CFrame.new(pos + Vector3.new(0, 19, -3.7)) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 5.5, 0), Color3.fromRGB(246, 241, 230), Enum.Material.SmoothPlastic, blades)
		blade.CanCollide = false
	end

	local pivot = CFrame.new(pos + Vector3.new(0, 19, -3.0))
	task.spawn(function()
		local a = 0
		while blades.Parent do
			a += 0.018
			pcall(function() blades:PivotTo(pivot * CFrame.Angles(0, 0, a)) end)
			task.wait()
		end
	end)
end

local function makeHouse(pos: Vector3, parent: Instance, scale: number?)
	local s = scale or 1
	local folder = Instance.new("Folder")
	folder.Name = "House"
	folder.Parent = parent
	-- Stone foundation
	ArenaKit.NewPart("Foundation", Vector3.new(9.5*s, 1.0*s, 8.5*s), CFrame.new(pos + Vector3.new(0, 0.5*s, 0)), STONE, Enum.Material.Slate, folder).CanCollide = true
	-- Body
	ArenaKit.NewPart("HouseBody", Vector3.new(9*s, 7*s, 8*s), CFrame.new(pos + Vector3.new(0, 4*s, 0)), Color3.fromRGB(228, 214, 188), Enum.Material.Concrete, folder).CanCollide = true
	-- Roof
	local roof = Instance.new("WedgePart")
	roof.Name = "HouseRoof"
	roof.Size = Vector3.new(11*s, 5*s, 9*s)
	roof.CFrame = CFrame.new(pos + Vector3.new(0, 9.5*s, 0)) * CFrame.Angles(0, math.rad(90), 0)
	roof.Color = Color3.fromRGB(165, 80, 64)
	roof.Material = Enum.Material.Slate
	roof.Anchored = true
	roof.CanCollide = true
	roof.Parent = folder
	-- Door
	ArenaKit.NewPart("Door", Vector3.new(1.8*s, 3.2*s, 0.22*s), CFrame.new(pos + Vector3.new(0, 1.6*s, -4.1*s)), PALETTE.WoodDark, Enum.Material.Wood, folder).CanCollide = false
	-- Windows
	for _, x in ipairs({ -2.6, 2.6 }) do
		local win = ArenaKit.NewPart("Window", Vector3.new(1.9*s, 1.8*s, 0.18*s), CFrame.new(pos + Vector3.new(x*s, 4.2*s, -4.11*s)), Color3.fromRGB(120, 210, 245), Enum.Material.Glass, folder)
		win.Transparency = 0.2
		win.CanCollide = false
	end
	-- Chimney
	ArenaKit.NewPart("Chimney", Vector3.new(1.4*s, 3.8*s, 1.4*s), CFrame.new(pos + Vector3.new(2.8*s, 11*s, 0)), Color3.fromRGB(128, 88, 78), Enum.Material.Brick, folder).CanCollide = true
	-- Window boxes (flower)
	for _, x in ipairs({ -2.6, 2.6 }) do
		ArenaKit.NewPart("FlowerBox", Vector3.new(2.0*s, 0.5*s, 0.8*s), CFrame.new(pos + Vector3.new(x*s, 3.0*s, -4.3*s)), Color3.fromRGB(80, 130, 60), Enum.Material.Grass, folder).CanCollide = false
	end
end

local function makeWaterfall(top: Vector3, height: number, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Waterfall"
	folder.Parent = parent
	local sheet = ArenaKit.NewPart("Water", Vector3.new(6.5, height, 1.4), CFrame.new(top - Vector3.new(0, height/2, 0)), WATER, Enum.Material.Glass, folder)
	sheet.Transparency = 0.26
	sheet.CanCollide = false
	local mist = ArenaKit.NewPart("Mist", Vector3.new(10, 5, 8), CFrame.new(top - Vector3.new(0, height + 2, 0)), Color3.fromRGB(225, 248, 255), Enum.Material.ForceField, folder)
	mist.Transparency = 0.55
	mist.CanCollide = false
	local pool = ArenaKit.NewPart("Pool", Vector3.new(8, 0.4, 8), CFrame.new(top - Vector3.new(0, height + 1.4, 0)), WATER, Enum.Material.Glass, folder)
	pool.Transparency = 0.34
	pool.CanCollide = false
end

local function makeLampPost(pos: Vector3, parent: Instance, color: Color3?)
	local c = color or Color3.fromRGB(255, 230, 140)
	ArenaKit.NewPart("LampPole", Vector3.new(0.48, 6.5, 0.48), CFrame.new(pos + Vector3.new(0, 3.25, 0)), STONE, Enum.Material.Slate, parent).CanCollide = false
	ArenaKit.NewPart("LampArm", Vector3.new(0.32, 0.32, 2.0), CFrame.new(pos + Vector3.new(0, 6.6, 1.0)), STONE, Enum.Material.Slate, parent).CanCollide = false
	local orb = ArenaKit.NewPart("LampOrb", Vector3.new(1.1, 1.1, 1.1), CFrame.new(pos + Vector3.new(0, 6.8, 1.9)), c, Enum.Material.Neon, parent)
	orb.Shape = Enum.PartType.Ball
	orb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = c
	light.Range = 15
	light.Brightness = 0.7
	light.Parent = orb
end

local function makeFence(origin: Vector3, length: number, yaw: number, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Fence"
	folder.Parent = parent
	local posts = math.max(2, math.floor(length / 3.5))
	for i = 0, posts do
		local t = i / posts
		local ox = math.cos(yaw) * (length * t - length/2)
		local oz = math.sin(yaw) * (length * t - length/2)
		ArenaKit.NewPart("Post", Vector3.new(0.46, 3.4, 0.46), CFrame.new(origin + Vector3.new(ox, 1.7, oz)), PALETTE.WoodDark, Enum.Material.Wood, folder).CanCollide = false
	end
	for _, yy in ipairs({ 1.1, 2.5 }) do
		ArenaKit.NewPart("Rail", Vector3.new(length, 0.30, 0.32), CFrame.new(origin + Vector3.new(0, yy, 0)) * CFrame.Angles(0, yaw, 0), PALETTE.Wood, Enum.Material.Wood, folder).CanCollide = false
	end
end

local function makeArch(pos: Vector3, parent: Instance)
	for _, x in ipairs({ -4.8, 4.8 }) do
		ArenaKit.NewPart("Pillar", Vector3.new(1.8, 8.5, 1.8), CFrame.new(pos + Vector3.new(x, 4.25, 0)), STONE, Enum.Material.Slate, parent).CanCollide = true
	end
	ArenaKit.NewPart("ArchLintel", Vector3.new(12, 1.8, 2.2), CFrame.new(pos + Vector3.new(0, 8.5, 0)), STONE, Enum.Material.Slate, parent).CanCollide = true
	ArenaKit.NewPart("ArchBeam", Vector3.new(10, 0.5, 0.5), CFrame.new(pos + Vector3.new(0, 7.5, -1.1)), PALETTE.WoodDark, Enum.Material.Wood, parent).CanCollide = false
end

local function makeTeamBanner(pos: Vector3, teamId: string, parent: Instance)
	local color = teamId == "Red" and Color3.fromRGB(255, 80, 95) or Color3.fromRGB(60, 170, 255)
	ArenaKit.NewPart("BannerPole", Vector3.new(0.52, 11, 0.52), CFrame.new(pos + Vector3.new(0, 5.5, 0)), PALETTE.WoodDark, Enum.Material.Wood, parent).CanCollide = false
	local flag = ArenaKit.NewPart("Flag", Vector3.new(5.5, 3.0, 0.20), CFrame.new(pos + Vector3.new(2.75, 9.0, 0)), color, Enum.Material.Fabric, parent)
	flag.CanCollide = false
	local tip = ArenaKit.NewPart("Tip", Vector3.new(0.7, 0.7, 0.7), CFrame.new(pos + Vector3.new(0, 11.5, 0)), Color3.fromRGB(255, 226, 60), Enum.Material.Neon, parent)
	tip.Shape = Enum.PartType.Ball
	tip.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 0.45
	light.Parent = flag
end

local function makeStonePath(origin: Vector3, dir: Vector3, count: number, parent: Instance)
	for i = 1, count do
		local offset = dir.Unit * ((i - 1) * 2.9)
		ArenaKit.NewPart("PathStone" .. i, Vector3.new(2.6, 0.34, 2.0), CFrame.new(origin + offset + Vector3.new(0, 1.63, 0)) * CFrame.Angles(0, math.rad((i%3 - 1) * 9), 0), COBBLE, Enum.Material.Slate, parent).CanCollide = false
	end
end

local function makeSteps(base: Vector3, dir: Vector3, count: number, parent: Instance)
	for i = 1, count do
		ArenaKit.NewPart("Step" .. i, Vector3.new(8, 0.38*i, 1.1), CFrame.new(base + dir.Unit*(i-1)*1.1 + Vector3.new(0, 0.19*i + 1.62, 0)), COBBLE, Enum.Material.Slate, parent).CanCollide = true
	end
end

-- ─── Build ───────────────────────────────────────────────────────────────────

function SkyIslands.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, SkyIslands.Name)

	-- ── Windmill / Center Island (highest, most detailed) ─────────────────
	local cp = LAYOUT.Center.pos
	local cr = LAYOUT.Center.r
	local center = ArenaKit.MakeIslandBase(cp, cr, "WindmillIsland", PALETTE, Enum.Material.Grass, arena)

	-- Hero structures
	makeWindmill(cp + Vector3.new(0, 1.6, -14), center)
	makeWell(cp + Vector3.new(9, 1.6, -5), center)
	makeHouse(cp + Vector3.new(-19, 1.6, -9), center, 0.90)
	makeHouse(cp + Vector3.new(16, 1.6, 9), center, 0.76)

	-- Raised stone terrace around windmill
	ArenaKit.NewPart("Terrace", Vector3.new(18, 1.1, 18), CFrame.new(cp + Vector3.new(-1, 2.75, -11)), COBBLE, Enum.Material.Slate, center).CanCollide = true
	makeSteps(cp + Vector3.new(-1, 0, -0.5), Vector3.new(0, 0, -1), 4, center)
	makeSteps(cp + Vector3.new(-10, 0, -11), Vector3.new(1, 0, 0), 3, center)

	-- Arch entrances at each bridge point
	makeArch(cp + Vector3.new(0, 1.6, 24), center)
	makeArch(cp + Vector3.new(-30, 1.6, 0), center)
	makeArch(cp + Vector3.new(30, 1.6, 0), center)

	-- Stone paths
	makeStonePath(cp + Vector3.new(0, 0, 20), Vector3.new(0, 0, -1), 8, center)
	makeStonePath(cp + Vector3.new(-5, 0, 4), Vector3.new(0, 0, -1), 4, center)

	-- Fences (perimeter)
	makeFence(cp + Vector3.new(-24, 1.6, -8), 26, math.rad(90), center)
	makeFence(cp + Vector3.new(-32, 1.6, 5), 18, 0, center)
	makeFence(cp + Vector3.new(32, 1.6, -5), 18, 0, center)
	makeFence(cp + Vector3.new(24, 1.6, 8), 22, math.rad(90), center)

	-- Lamp posts
	makeLampPost(cp + Vector3.new(-11, 1.6, 17), center)
	makeLampPost(cp + Vector3.new(11, 1.6, 17), center)
	makeLampPost(cp + Vector3.new(-21, 1.6, 4), center)
	makeLampPost(cp + Vector3.new(21, 1.6, -4), center)
	makeLampPost(cp + Vector3.new(0, 1.6, -28), center, Color3.fromRGB(200, 230, 255))

	-- Props
	makeCrate(cp + Vector3.new(-17, 1.6, 13), center)
	makeCrate(cp + Vector3.new(19, 1.6, -13), center)
	makeBarrel(cp + Vector3.new(-11, 1.6, -17), center)
	makeBarrel(cp + Vector3.new(13, 1.6, 15), center)
	makeBarrel(cp + Vector3.new(9, 1.6, -18), center)

	-- Dense foliage
	scatterDecor(cp, cr, center, 13, 55)

	-- Waterfalls on three sides
	makeWaterfall(cp + Vector3.new(cr - 4, 1.2, 8), 75, center)
	makeWaterfall(cp + Vector3.new(-(cr - 4), 1.2, -8), 68, center)
	makeWaterfall(cp + Vector3.new(6, 1.2, cr - 4), 62, center)

	ArenaKit.AddPowerPad(cp + Vector3.new(-1, 3.8, -11), powerPads)

	-- ── Outer Islands ─────────────────────────────────────────────────────
	for i, o in ipairs(LAYOUT.Outer) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "Island" .. i, PALETTE, Enum.Material.Grass, arena)
		scatterDecor(o.pos, o.r, isl, 7, 26)
		makeWaterfall(o.pos + Vector3.new(o.r - 3, 1, 5), 48 + i * 4, isl)
		makeWaterfall(o.pos + Vector3.new(-(o.r - 3), 1, -5), 42 + i * 3, isl)

		if o.team then
			makeArch(o.pos + Vector3.new(0, 1.6, o.r - 10), isl)
			makeTeamBanner(o.pos + Vector3.new(-o.r + 9, 1.6, -9), o.team, isl)
			makeTeamBanner(o.pos + Vector3.new(o.r - 9, 1.6, 9), o.team, isl)
			makeFence(o.pos + Vector3.new(0, 1.6, -(o.r - 7)), 22, 0, isl)
			makeFence(o.pos + Vector3.new(-(o.r - 7), 1.6, 0), 22, math.rad(90), isl)
			makeFence(o.pos + Vector3.new(o.r - 7, 1.6, 0), 22, math.rad(90), isl)
			makeStonePath(o.pos + Vector3.new(0, 0, o.r - 12), Vector3.new(0, 0, -1), 8, isl)
			makeWell(o.pos + Vector3.new(0, 1.6, -4), isl)
			makeHouse(o.pos + Vector3.new(-9, 1.6, -9), isl, 0.80)
			makeLampPost(o.pos + Vector3.new(-9, 1.6, 9), isl)
			makeLampPost(o.pos + Vector3.new(9, 1.6, 9), isl)
			makeLampPost(o.pos + Vector3.new(0, 1.6, -18), isl)
			makeCrate(o.pos + Vector3.new(11, 1.6, -11), isl)
			makeBarrel(o.pos + Vector3.new(-11, 1.6, 11), isl)
			makeBarrel(o.pos + Vector3.new(11, 1.6, 5), isl)
			ArenaKit.AddTeamTriangleSpawns(o.pos, o.r, o.team, spawns)
			ArenaKit.AddTeamSpawnBeacons(o.pos, o.r, o.team, isl)
		else
			if i == 3 or i == 5 then
				makeWindmill(o.pos + Vector3.new(0, 1.6, -5), isl)
			else
				makeHouse(o.pos + Vector3.new(-5, 1.6, 3), isl, 0.72)
			end
			makeArch(o.pos + Vector3.new(0, 1.6, -(o.r - 10)), isl)
			makeFence(o.pos + Vector3.new(0, 1.6, o.r - 7), 20, 0, isl)
			makeLampPost(o.pos + Vector3.new(-9, 1.6, 7), isl)
			makeLampPost(o.pos + Vector3.new(9, 1.6, -7), isl)
			makeCrate(o.pos + Vector3.new(7, 1.6, 7), isl)
			makeBarrel(o.pos + Vector3.new(-7, 1.6, -7), isl)
			makeBarrel(o.pos + Vector3.new(7, 1.6, -5), isl)
			ArenaKit.AddPowerPad(o.pos, powerPads)
		end

		-- Bridge each outer island → center
		local toCenter = cp - o.pos
		local edgeOuter = o.pos + toCenter.Unit * (o.r - 2) + Vector3.new(0, 1.6, 0)
		local edgeCenter = cp - toCenter.Unit * (cr - 2) + Vector3.new(0, 1.6, 0)
		ArenaKit.MakeBridge(edgeOuter, edgeCenter, arena, PALETTE)
	end

	-- Extra cross-bridges for more paths
	do
		local bl  = LAYOUT.Outer[1]   -- Blue
		local nl  = LAYOUT.Outer[3]   -- left neutral
		local rd  = LAYOUT.Outer[2]   -- Red
		local nr  = LAYOUT.Outer[4]   -- right neutral
		local ul  = LAYOUT.Outer[5]   -- upper-left neutral
		local ur  = LAYOUT.Outer[6]   -- upper-right neutral

		local function xBridge(a: any, b: any)
			local d = b.pos - a.pos
			ArenaKit.MakeBridge(
				a.pos + d.Unit * (a.r - 2) + Vector3.new(0, 1.6, 0),
				b.pos - d.Unit * (b.r - 2) + Vector3.new(0, 1.6, 0),
				arena, PALETTE
			)
		end
		xBridge(bl, nl)   -- Blue ↔ left neutral
		xBridge(rd, nr)   -- Red ↔ right neutral
		xBridge(nl, ul)   -- left neutral ↔ upper-left
		xBridge(nr, ur)   -- right neutral ↔ upper-right
	end

	-- ── Satellite Islands ─────────────────────────────────────────────────
	for si, s in ipairs(LAYOUT.Satellites) do
		local isl = ArenaKit.MakeIslandBase(s.pos, s.r, "Satellite" .. si, PALETTE, Enum.Material.Grass, arena)
		scatterDecor(s.pos, s.r, isl, 2, 7)
		if si == 1 then
			makeLampPost(s.pos + Vector3.new(0, 1.6, 0), isl, Color3.fromRGB(180, 220, 255))
		elseif si == 2 then
			makeBarrel(s.pos + Vector3.new(0, 1.6, 0), isl)
		elseif si == 3 then
			makeWell(s.pos + Vector3.new(0, 1.6, 0), isl)
		end
		-- Bridge small sats to the center
		if si <= 3 then
			local d = cp - s.pos
			ArenaKit.MakeBridge(
				s.pos + d.Unit * (s.r - 1) + Vector3.new(0, 1.6, 0),
				cp - d.Unit * (cr - 2) + Vector3.new(0, 1.6, 0),
				arena, PALETTE
			)
		end
	end

	-- ── Ambiance ──────────────────────────────────────────────────────────
	ArenaKit.ScatterDebris(arena, 30, PALETTE)
	ArenaKit.MakeClouds(arena, Color3.fromRGB(255, 255, 255), 0.24)
	ArenaKit.ApplyAtmosphere({
		Density = 0.14, Offset = 0.20,
		Color = Color3.fromRGB(192, 228, 255), Decay = Color3.fromRGB(90, 165, 228),
		Glare = 0.38, Haze = 0.65,
		Ambient = Color3.fromRGB(148, 188, 235), OutdoorAmbient = Color3.fromRGB(188, 220, 255),
		ClockTime = 10.5, FogColor = Color3.fromRGB(170, 218, 255), FogEnd = 1200,
	})
	arena:SetAttribute("SpawnCount", #spawns:GetChildren())

	return arena
end

return SkyIslands
