--!strict
-- Map 1/3: Sky Islands — grassy floating islands, a windmill, waterfalls,
-- wooden bridges. The original arena, refactored onto ArenaKit so it shares
-- its island/bridge/spawn geometry with the other two maps.

local Workspace = game:GetService("Workspace")
local ArenaKit = require(script.Parent.Parent.ArenaKit)

local SkyIslands = { Id = "SkyIslands", Name = "Sky Islands" }

local PALETTE: ArenaKit.Palette = {
	Top = Color3.fromRGB(126, 200, 108), TopDark = Color3.fromRGB(96, 170, 92),
	Stone = Color3.fromRGB(150, 150, 160), StoneDark = Color3.fromRGB(110, 110, 122),
	Wood = Color3.fromRGB(150, 105, 65), WoodDark = Color3.fromRGB(110, 75, 48),
}
local LEAF = Color3.fromRGB(90, 180, 100)
local WATER = Color3.fromRGB(120, 205, 240)

local function makeTree(pos: Vector3, parent: Instance)
	ArenaKit.NewPart("Trunk", Vector3.new(1.4, 7, 1.4), CFrame.new(pos + Vector3.new(0, 3.5, 0)), PALETTE.Wood, Enum.Material.Wood, parent)
	for i = 1, 3 do
		local d = 7 - i * 1.4
		local leaf = ArenaKit.NewPart("Leaves", Vector3.new(d, d, d), CFrame.new(pos + Vector3.new(0, 6 + i * 2.2, 0)), LEAF, Enum.Material.Grass, parent)
		leaf.Shape = Enum.PartType.Ball
	end
end

local function makeFlower(pos: Vector3, parent: Instance)
	local colors = { Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 220, 120), Color3.fromRGB(180, 150, 255), Color3.fromRGB(255, 120, 120) }
	ArenaKit.NewPart("Stem", Vector3.new(0.2, 1.2, 0.2), CFrame.new(pos + Vector3.new(0, 0.6, 0)), Color3.fromRGB(90, 170, 90), Enum.Material.Grass, parent)
	local bloom = ArenaKit.NewPart("Bloom", Vector3.new(0.7, 0.5, 0.7), CFrame.new(pos + Vector3.new(0, 1.3, 0)), colors[math.random(1, #colors)], Enum.Material.SmoothPlastic, parent)
	bloom.Shape = Enum.PartType.Ball
end

local function scatterDecor(center: Vector3, radius: number, parent: Instance, trees: number, flowers: number)
	for _ = 1, trees do
		local a = math.random() * math.pi * 2
		local r = radius * (0.3 + math.random() * 0.55)
		makeTree(center + Vector3.new(math.cos(a) * r, 1.6, math.sin(a) * r), parent)
	end
	for _ = 1, flowers do
		local a = math.random() * math.pi * 2
		local r = radius * (0.2 + math.random() * 0.7)
		makeFlower(center + Vector3.new(math.cos(a) * r, 1.6, math.sin(a) * r), parent)
	end
end

local function makeCrate(pos: Vector3, parent: Instance)
	ArenaKit.NewPart("Crate", Vector3.new(4, 4, 4), CFrame.new(pos + Vector3.new(0, 3.6, 0)), PALETTE.Wood, Enum.Material.WoodPlanks, parent).CanCollide = true
	ArenaKit.NewPart("Trim", Vector3.new(4.1, 0.4, 4.1), CFrame.new(pos + Vector3.new(0, 5.4, 0)), PALETTE.WoodDark, Enum.Material.Wood, parent)
end

local function makePlatform(pos: Vector3, size: Vector3, parent: Instance)
	ArenaKit.NewPart("Platform", size, CFrame.new(pos), PALETTE.Wood, Enum.Material.WoodPlanks, parent).CanCollide = true
	for _, ox in ipairs({ -1, 1 }) do
		for _, oz in ipairs({ -1, 1 }) do
			ArenaKit.NewPart("Leg", Vector3.new(0.8, pos.Y + 1.6, 0.8), CFrame.new(pos.X + ox * (size.X / 2 - 1), pos.Y / 2, pos.Z + oz * (size.Z / 2 - 1)), PALETTE.WoodDark, Enum.Material.Wood, parent)
		end
	end
end

local function makeWindmill(pos: Vector3, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Windmill"
	folder.Parent = parent
	ArenaKit.NewPart("Tower", Vector3.new(5, 16, 5), CFrame.new(pos + Vector3.new(0, 8, 0)), Color3.fromRGB(235, 225, 210), Enum.Material.Concrete, folder).CanCollide = true
	ArenaKit.NewPart("Roof", Vector3.new(6, 4, 6), CFrame.new(pos + Vector3.new(0, 18, 0)), Color3.fromRGB(180, 90, 80), Enum.Material.Slate, folder)
	local hub = ArenaKit.NewPart("Hub", Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 15, -3)), PALETTE.WoodDark, Enum.Material.Wood, folder)
	hub.Shape = Enum.PartType.Ball

	local blades = Instance.new("Model")
	blades.Name = "Blades"
	blades.Parent = folder
	for i = 0, 3 do
		local ang = math.rad(i * 90)
		local blade = ArenaKit.NewPart("Blade", Vector3.new(1, 9, 0.4), CFrame.new(pos + Vector3.new(0, 15, -3.4)) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 4.5, 0), Color3.fromRGB(240, 240, 235), Enum.Material.SmoothPlastic, blades)
		blade.CanCollide = false
	end
	blades.PrimaryPart = hub

	local pivot = CFrame.new(pos + Vector3.new(0, 15, -3))
	task.spawn(function()
		local a = 0
		while blades.Parent do
			a += 0.02
			pcall(function()
				blades:PivotTo(pivot * CFrame.Angles(0, 0, a))
			end)
			task.wait()
		end
	end)
end

local function makeWaterfall(top: Vector3, height: number, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Waterfall"
	folder.Parent = parent
	local sheet = ArenaKit.NewPart("Water", Vector3.new(8, height, 1), CFrame.new(top - Vector3.new(0, height / 2, 0)), WATER, Enum.Material.Glass, folder)
	sheet.Transparency = 0.35
	sheet.CanCollide = false
	local mist = ArenaKit.NewPart("Mist", Vector3.new(10, 4, 6), CFrame.new(top - Vector3.new(0, height, 0)), Color3.fromRGB(230, 250, 255), Enum.Material.ForceField, folder)
	mist.Transparency = 0.6
	mist.CanCollide = false
end

function SkyIslands.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, SkyIslands.Name)
	local layout = ArenaKit.StandardLayout

	local centerPos = layout.Center.pos
	local centerR = layout.Center.r
	local center = ArenaKit.MakeIslandBase(centerPos, centerR, "CenterIsland", PALETTE, Enum.Material.Grass, arena)
	scatterDecor(centerPos, centerR, center, 9, 36)
	makeWindmill(centerPos + Vector3.new(0, 1.6, 0), center)
	makePlatform(Vector3.new(0, 8, 0), Vector3.new(16, 1.5, 16), center)
	makeCrate(Vector3.new(-14, 1.6, 10), center)
	makeCrate(Vector3.new(14, 1.6, -10), center)
	ArenaKit.AddPowerPad(Vector3.new(0, 9, 0), powerPads)
	ArenaKit.AddHexSpawns(centerPos, centerR, nil, spawns)

	for i, o in ipairs(layout.Outer) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "Island" .. i, PALETTE, Enum.Material.Grass, arena)
		scatterDecor(o.pos, o.r, isl, 6, 18)
		makeWaterfall(o.pos + Vector3.new(o.r - 2, 1, 0), 40 + i * 4, isl)
		makeWaterfall(o.pos + Vector3.new(-(o.r - 2), 1, 4), 34 + i * 3, isl)
		local dir = centerPos - o.pos
		local edgeA = o.pos + Vector3.new(0, 1.6, 0) + dir.Unit * (o.r - 2)
		local edgeB = centerPos + Vector3.new(0, 1.6, 0) - dir.Unit * (centerR - 2)
		ArenaKit.MakeBridge(edgeA, edgeB, arena, PALETTE)
		ArenaKit.AddHexSpawns(o.pos, o.r, o.team, spawns)
		if not o.team then
			ArenaKit.AddPowerPad(o.pos, powerPads)
			makeCrate(o.pos + Vector3.new(6, 0, 6), isl)
		end
	end

	for si, s in ipairs(layout.Satellites) do
		local isl = ArenaKit.MakeIslandBase(s.pos, s.r, "Satellite" .. si, PALETTE, Enum.Material.Grass, arena)
		scatterDecor(s.pos, s.r, isl, 1, 6)
	end

	ArenaKit.ScatterDebris(arena, 22, PALETTE)
	ArenaKit.MakeClouds(arena, Color3.fromRGB(255, 255, 255))
	ArenaKit.ApplyAtmosphere({
		Density = 0.28, Offset = 0.15, Color = Color3.fromRGB(200, 220, 255),
		Decay = Color3.fromRGB(95, 140, 200), Glare = 0.25, Haze = 1.4,
	})

	return arena
end

return SkyIslands
