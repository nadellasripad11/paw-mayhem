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
	-- PrimaryPart must be inside the model for PivotTo to work reliably.
	hub.Parent = blades
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

local function makeHouse(pos: Vector3, parent: Instance, scale: number?)
	local s = scale or 1
	local folder = Instance.new("Folder")
	folder.Name = "VillageHouse"
	folder.Parent = parent

	local body = ArenaKit.NewPart("HouseBody", Vector3.new(8 * s, 6 * s, 7 * s), CFrame.new(pos + Vector3.new(0, 3 * s, 0)), Color3.fromRGB(232, 220, 196), Enum.Material.Concrete, folder)
	body.CanCollide = true
	local roof = Instance.new("WedgePart")
	roof.Name = "HouseRoof"
	roof.Size = Vector3.new(10 * s, 4 * s, 8 * s)
	roof.CFrame = CFrame.new(pos + Vector3.new(0, 8 * s, 0)) * CFrame.Angles(0, math.rad(90), 0)
	roof.Color = Color3.fromRGB(174, 88, 72)
	roof.Material = Enum.Material.Slate
	roof.Anchored = true
	roof.CanCollide = true
	roof.Parent = folder

	local door = ArenaKit.NewPart("Door", Vector3.new(1.5 * s, 2.8 * s, 0.2 * s), CFrame.new(pos + Vector3.new(0, 1.6 * s, -3.6 * s)), Color3.fromRGB(92, 64, 52), Enum.Material.Wood, folder)
	door.CanCollide = false
	for _, x in ipairs({ -2.25, 2.25 }) do
		local window = ArenaKit.NewPart("Window", Vector3.new(1.8 * s, 1.6 * s, 0.18 * s), CFrame.new(pos + Vector3.new(x * s, 3.7 * s, -3.61 * s)), Color3.fromRGB(126, 211, 239), Enum.Material.Glass, folder)
		window.Transparency = 0.15
		window.CanCollide = false
	end
	local chimney = ArenaKit.NewPart("Chimney", Vector3.new(1.2 * s, 3 * s, 1.2 * s), CFrame.new(pos + Vector3.new(2.5 * s, 9 * s, 0)), Color3.fromRGB(126, 92, 82), Enum.Material.Brick, folder)
	chimney.CanCollide = true
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

local function makeSkyLantern(pos: Vector3, parent: Instance, tint: Color3?)
	local pole = ArenaKit.NewPart("LanternPole", Vector3.new(0.35, 5, 0.35), CFrame.new(pos + Vector3.new(0, 2.5, 0)), PALETTE.WoodDark, Enum.Material.Wood, parent)
	pole.CanCollide = false
	local lamp = ArenaKit.NewPart("Lantern", Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 5.5, 0)), tint or Color3.fromRGB(255, 220, 120), Enum.Material.Neon, parent)
	lamp.Shape = Enum.PartType.Ball
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = tint or Color3.fromRGB(255, 220, 120)
	light.Range = 10
	light.Brightness = 0.8
	light.Parent = lamp
end

local function makeSkyFence(origin: Vector3, length: number, parent: Instance)
	local posts = math.max(2, math.floor(length / 4))
	for i = 0, posts do
		local x = -length / 2 + (length / posts) * i
		ArenaKit.NewPart("FencePost", Vector3.new(0.45, 2.8, 0.45), CFrame.new(origin + Vector3.new(x, 1.4, 0)), PALETTE.WoodDark, Enum.Material.Wood, parent)
	end
	for _, y in ipairs({ 1.1, 2.1 }) do
		ArenaKit.NewPart("FenceRail", Vector3.new(length, 0.28, 0.28), CFrame.new(origin + Vector3.new(0, y, 0)), PALETTE.Wood, Enum.Material.Wood, parent)
	end
end

local function makeSkyPath(origin: Vector3, direction: Vector3, count: number, parent: Instance)
	local unit = direction.Magnitude > 0 and direction.Unit or Vector3.new(1, 0, 0)
	for i = 1, count do
		local offset = unit * ((i - 1) * 3.1)
		local stone = ArenaKit.NewPart("PathStone", Vector3.new(2.4, 0.28, 1.65), CFrame.new(origin + offset + Vector3.new(0, 1.75, 0)) * CFrame.Angles(0, math.rad((i % 3) * 9), 0), PALETTE.Stone, Enum.Material.Slate, parent)
		stone.Shape = Enum.PartType.Ball
		stone.CanCollide = false
	end
end

local function makeSkySign(pos: Vector3, textColor: Color3, parent: Instance)
	local post = ArenaKit.NewPart("SignPost", Vector3.new(0.35, 3.6, 0.35), CFrame.new(pos + Vector3.new(0, 1.8, 0)), PALETTE.WoodDark, Enum.Material.Wood, parent)
	post.CanCollide = false
	local board = ArenaKit.NewPart("SignBoard", Vector3.new(4.8, 1.6, 0.25), CFrame.new(pos + Vector3.new(0, 3.6, 0)), PALETTE.Wood, Enum.Material.WoodPlanks, parent)
	board.CanCollide = false
	local glow = ArenaKit.NewPart("SignGlow", Vector3.new(3.8, 0.2, 0.08), CFrame.new(pos + Vector3.new(0, 3.6, -0.16)), textColor, Enum.Material.Neon, parent)
	glow.CanCollide = false
end

local function makeSkyArch(pos: Vector3, parent: Instance)
	for _, x in ipairs({ -4, 4 }) do
		ArenaKit.NewPart("ArchPillar", Vector3.new(1.4, 7, 1.4), CFrame.new(pos + Vector3.new(x, 3.5, 0)), PALETTE.Stone, Enum.Material.Slate, parent)
	end
	ArenaKit.NewPart("ArchTop", Vector3.new(9.4, 1.4, 1.6), CFrame.new(pos + Vector3.new(0, 7, 0)), PALETTE.Wood, Enum.Material.WoodPlanks, parent)
end

local function makeSkyTeamBanner(pos: Vector3, teamId: string, parent: Instance)
	local color = teamId == "Red" and Color3.fromRGB(255, 90, 102) or Color3.fromRGB(70, 175, 255)
	local pole = ArenaKit.NewPart("TeamBannerPole", Vector3.new(0.45, 8, 0.45), CFrame.new(pos + Vector3.new(0, 4, 0)), PALETTE.WoodDark, Enum.Material.Wood, parent)
	pole.CanCollide = false
	local flag = ArenaKit.NewPart("TeamBanner", Vector3.new(4.2, 2.2, 0.15), CFrame.new(pos + Vector3.new(2, 6.7, 0)), color, Enum.Material.Fabric, parent)
	flag.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 12
	light.Brightness = 0.45
	light.Parent = flag
end

function SkyIslands.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, SkyIslands.Name)
	local layout = ArenaKit.StandardLayout

	local centerPos = layout.Center.pos
	local centerR = layout.Center.r
	local center = ArenaKit.MakeIslandBase(centerPos, centerR, "CenterIsland", PALETTE, Enum.Material.Grass, arena)
	scatterDecor(centerPos, centerR, center, 9, 36)
	makeWindmill(centerPos + Vector3.new(0, 1.6, 0), center)
	makeHouse(Vector3.new(-16, 1.6, -8), center, 0.95)
	makeHouse(Vector3.new(14, 1.6, 10), center, 0.78)
	makeSkyArch(Vector3.new(0, 1.6, -16), center)
	makeSkyFence(Vector3.new(-14, 1.6, 0), 18, center)
	makeSkyFence(Vector3.new(14, 1.6, 0), 14, center)
	makeSkyPath(Vector3.new(-11, 1.6, -9), Vector3.new(1, 0, 0), 7, center)
	makeSkyPath(Vector3.new(9, 1.6, 8), Vector3.new(-1, 0, 0), 6, center)
	makeSkyLantern(Vector3.new(-10, 1.6, -12), center)
	makeSkyLantern(Vector3.new(10, 1.6, 13), center, Color3.fromRGB(180, 235, 255))
	makeSkySign(Vector3.new(0, 1.6, 18), Color3.fromRGB(180, 235, 255), center)
	makePlatform(Vector3.new(0, 8, 0), Vector3.new(16, 1.5, 16), center)
	makeCrate(Vector3.new(-14, 1.6, 10), center)
	makeCrate(Vector3.new(14, 1.6, -10), center)
	ArenaKit.AddPowerPad(Vector3.new(0, 9, 0), powerPads)

	for i, o in ipairs(layout.Outer) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "Island" .. i, PALETTE, Enum.Material.Grass, arena)
		scatterDecor(o.pos, o.r, isl, 7, 24)
		makeWaterfall(o.pos + Vector3.new(o.r - 2, 1, 0), 40 + i * 4, isl)
		makeWaterfall(o.pos + Vector3.new(-(o.r - 2), 1, 4), 34 + i * 3, isl)
		-- Background landmarks match the reference skyline without touching the
		-- spawn rings or changing the combat footprint.
		if i == 3 or i == 4 or i == 5 then
			makeWindmill(o.pos + Vector3.new(0, 1.6, 0), isl)
		end
		if i == 3 or i == 4 or i == 5 or i == 6 then
			makeHouse(o.pos + Vector3.new(-5, 1.6, 4), isl, 0.72)
		end
		if i == 3 or i == 4 then
			makePlatform(o.pos + Vector3.new(0, 8, 0), Vector3.new(14, 1.5, 14), isl)
		end
		if o.team then
			makeSkyTeamBanner(o.pos + Vector3.new(-8, 1.6, -8), o.team, isl)
			makeSkyFence(o.pos + Vector3.new(0, 1.6, 10), 16, isl)
			makeSkyLantern(o.pos + Vector3.new(8, 1.6, -7), isl, o.team == "Red" and Color3.fromRGB(255, 150, 150) or Color3.fromRGB(160, 220, 255))
		else
			makeSkyArch(o.pos + Vector3.new(0, 1.6, -8), isl)
			makeSkyPath(o.pos + Vector3.new(-8, 1.6, 3), Vector3.new(1, 0, 0), 5, isl)
		end
		local dir = centerPos - o.pos
		local edgeA = o.pos + Vector3.new(0, 1.6, 0) + dir.Unit * (o.r - 2)
		local edgeB = centerPos + Vector3.new(0, 1.6, 0) - dir.Unit * (centerR - 2)
		ArenaKit.MakeBridge(edgeA, edgeB, arena, PALETTE)
		if o.team == "Blue" or o.team == "Red" then
			ArenaKit.AddTeamTriangleSpawns(o.pos, o.r, o.team, spawns)
			ArenaKit.AddTeamSpawnBeacons(o.pos, o.r, o.team, isl)
		end
		if not o.team then
			ArenaKit.AddPowerPad(o.pos, powerPads)
			makeCrate(o.pos + Vector3.new(6, 0, 6), isl)
		end
	end

	for si, s in ipairs(layout.Satellites) do
		local isl = ArenaKit.MakeIslandBase(s.pos, s.r, "Satellite" .. si, PALETTE, Enum.Material.Grass, arena)
		scatterDecor(s.pos, s.r, isl, 2, 8)
		if si == 1 or si == 2 then
			makeWindmill(s.pos + Vector3.new(0, 1.6, 0), isl)
		end
	end

	ArenaKit.ScatterDebris(arena, 22, PALETTE)
	ArenaKit.MakeClouds(arena, Color3.fromRGB(255, 255, 255))
	ArenaKit.ApplyAtmosphere({
		Density = 0.16, Offset = 0.18, Color = Color3.fromRGB(196, 226, 255),
		Decay = Color3.fromRGB(95, 165, 225), Glare = 0.35, Haze = 0.7,
		Ambient = Color3.fromRGB(150, 190, 235), OutdoorAmbient = Color3.fromRGB(190, 220, 255),
		ClockTime = 10.5, FogColor = Color3.fromRGB(176, 220, 255), FogEnd = 900,
	})
	arena:SetAttribute("SpawnCount", #spawns:GetChildren())

	return arena
end

return SkyIslands
