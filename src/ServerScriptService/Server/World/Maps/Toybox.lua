--!strict
-- Map 3/3: Toybox — bright candy-colored block islands, balloon "trees", a
-- giant stacked-block tower with a spinning pinwheel instead of a windmill,
-- and colorful ribbon-streamer falls. Same tested island layout as the other
-- two maps (ArenaKit.StandardLayout); completely different theme.

local Workspace = game:GetService("Workspace")
local ArenaKit = require(script.Parent.Parent.ArenaKit)

local Toybox = { Id = "Toybox", Name = "Toybox" }

local PALETTE: ArenaKit.Palette = {
	Top = Color3.fromRGB(120, 210, 235), TopDark = Color3.fromRGB(90, 180, 210), -- candy blue platform
	Stone = Color3.fromRGB(255, 205, 90), StoneDark = Color3.fromRGB(230, 170, 60), -- toy-block yellow
	Wood = Color3.fromRGB(230, 90, 90), WoodDark = Color3.fromRGB(190, 60, 60), -- toy red
}
local BALLOON_COLORS = {
	Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(255, 210, 90), Color3.fromRGB(170, 130, 255), Color3.fromRGB(130, 220, 140),
}
local BLOCK_COLORS = {
	Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(255, 210, 90), Color3.fromRGB(170, 130, 255),
}

-- A big toy balloon on a string, in place of a tree.
local function makeBalloon(pos: Vector3, parent: Instance)
	local color = BALLOON_COLORS[math.random(1, #BALLOON_COLORS)]
	local h = 4 + math.random() * 2
	ArenaKit.NewPart("String", Vector3.new(0.15, h, 0.15), CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color3.fromRGB(230, 230, 230), Enum.Material.SmoothPlastic, parent)
	local balloon = ArenaKit.NewPart("Balloon", Vector3.new(3, 3.6, 3), CFrame.new(pos + Vector3.new(0, h + 1.6, 0)), color, Enum.Material.SmoothPlastic, parent)
	balloon.Shape = Enum.PartType.Ball
	balloon.CanCollide = false
end

-- A small colorful toy block, in place of a flower.
local function makeBlock(pos: Vector3, parent: Instance)
	local color = BLOCK_COLORS[math.random(1, #BLOCK_COLORS)]
	ArenaKit.NewPart("ToyBlock", Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, math.rad(math.random(0, 45)), 0), color, Enum.Material.SmoothPlastic, parent)
end

local function scatterDecor(center: Vector3, radius: number, parent: Instance, balloons: number, blocks: number)
	for _ = 1, balloons do
		local a = math.random() * math.pi * 2
		local r = radius * (0.3 + math.random() * 0.55)
		makeBalloon(center + Vector3.new(math.cos(a) * r, 1.6, math.sin(a) * r), parent)
	end
	for _ = 1, blocks do
		local a = math.random() * math.pi * 2
		local r = radius * (0.2 + math.random() * 0.7)
		makeBlock(center + Vector3.new(math.cos(a) * r, 1.6, math.sin(a) * r), parent)
	end
end

local function makeCrate(pos: Vector3, parent: Instance)
	local color = BLOCK_COLORS[math.random(1, #BLOCK_COLORS)]
	ArenaKit.NewPart("ToyCrate", Vector3.new(4, 4, 4), CFrame.new(pos + Vector3.new(0, 3.6, 0)), color, Enum.Material.SmoothPlastic, parent).CanCollide = true
	ArenaKit.NewPart("Trim", Vector3.new(4.1, 0.4, 4.1), CFrame.new(pos + Vector3.new(0, 5.4, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, parent)
end

local function makeToyHouse(pos: Vector3, parent: Instance, scale: number?)
	local s = scale or 1
	local folder = Instance.new("Folder")
	folder.Name = "ToyHouse"
	folder.Parent = parent
	local colors = BLOCK_COLORS
	local body = ArenaKit.NewPart("HouseBlock", Vector3.new(7 * s, 5 * s, 6 * s), CFrame.new(pos + Vector3.new(0, 2.5 * s, 0)), colors[math.random(1, #colors)], Enum.Material.SmoothPlastic, folder)
	body.CanCollide = true
	local roof = Instance.new("WedgePart")
	roof.Name = "HouseRoof"
	roof.Size = Vector3.new(9 * s, 3.5 * s, 7 * s)
	roof.CFrame = CFrame.new(pos + Vector3.new(0, 6.75 * s, 0)) * CFrame.Angles(0, math.rad(90), 0)
	roof.Color = Color3.fromRGB(255, 255, 255)
	roof.Material = Enum.Material.SmoothPlastic
	roof.Anchored = true
	roof.Parent = folder
	local door = ArenaKit.NewPart("Door", Vector3.new(1.3 * s, 2.3 * s, 0.2 * s), CFrame.new(pos + Vector3.new(0, 1.3 * s, -3.1 * s)), Color3.fromRGB(90, 120, 180), Enum.Material.Neon, folder)
	door.CanCollide = false
	for _, x in ipairs({ -2 * s, 2 * s }) do
		local window = ArenaKit.NewPart("Window", Vector3.new(1.5 * s, 1.3 * s, 0.2 * s), CFrame.new(pos + Vector3.new(x, 3.2 * s, -3.11 * s)), Color3.fromRGB(255, 238, 133), Enum.Material.Neon, folder)
		window.CanCollide = false
	end
	local flag = ArenaKit.NewPart("FlagPole", Vector3.new(0.25 * s, 3.5 * s, 0.25 * s), CFrame.new(pos + Vector3.new(2.5 * s, 8.1 * s, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, folder)
	flag.CanCollide = false
	ArenaKit.NewPart("Flag", Vector3.new(1.6 * s, 0.8 * s, 0.2 * s), CFrame.new(pos + Vector3.new(3.2 * s, 9.2 * s, 0)), colors[math.random(1, #colors)], Enum.Material.Neon, folder).CanCollide = false
end

local function makePlatform(pos: Vector3, size: Vector3, parent: Instance)
	ArenaKit.NewPart("Platform", size, CFrame.new(pos), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, parent).CanCollide = true
	for _, ox in ipairs({ -1, 1 }) do
		for _, oz in ipairs({ -1, 1 }) do
			ArenaKit.NewPart("Leg", Vector3.new(0.8, pos.Y + 1.6, 0.8), CFrame.new(pos.X + ox * (size.X / 2 - 1), pos.Y / 2, pos.Z + oz * (size.Z / 2 - 1)), PALETTE.Wood, Enum.Material.SmoothPlastic, parent)
		end
	end
end

-- Central landmark: a stacked-block tower with a spinning colorful pinwheel
-- on top, standing in for the windmill.
local function makeBlockTower(pos: Vector3, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "BlockTower"
	folder.Parent = parent
	local stackColors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 210, 90), Color3.fromRGB(120, 200, 255), Color3.fromRGB(170, 130, 255) }
	for i = 0, 3 do
		local size = 6 - i * 0.6
		local block = ArenaKit.NewPart("Block" .. i, Vector3.new(size, 4, size), CFrame.new(pos + Vector3.new(0, 2 + i * 4, 0)), stackColors[i + 1], Enum.Material.SmoothPlastic, folder)
		block.CanCollide = true
	end

	local hub = ArenaKit.NewPart("Hub", Vector3.new(0.8, 0.8, 0.8), CFrame.new(pos + Vector3.new(0, 18, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, folder)
	hub.Shape = Enum.PartType.Ball
	local blades = Instance.new("Model")
	blades.Name = "Pinwheel"
	blades.Parent = folder
	hub.Parent = blades
	local wheelColors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 210, 90), Color3.fromRGB(130, 220, 140) }
	for i = 0, 3 do
		local ang = math.rad(i * 90)
		local blade = ArenaKit.NewPart("Vane", Vector3.new(0.2, 4, 2.6), CFrame.new(pos + Vector3.new(0, 18, 0)) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 2, 0), wheelColors[i + 1], Enum.Material.SmoothPlastic, blades)
		blade.CanCollide = false
	end
	blades.PrimaryPart = hub

	local pivot = CFrame.new(pos + Vector3.new(0, 18, 0))
	task.spawn(function()
		local a = 0
		while blades.Parent do
			a += 3
			pcall(function()
				blades:PivotTo(pivot * CFrame.Angles(0, 0, math.rad(a)))
			end)
			task.wait()
		end
	end)
end

-- Colorful ribbon-streamer cascade in place of a waterfall.
local function makeStreamerFall(top: Vector3, height: number, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Streamers"
	folder.Parent = parent
	for i, color in ipairs(BALLOON_COLORS) do
		local x = (i - 3) * 1.6
		local ribbon = ArenaKit.NewPart("Ribbon", Vector3.new(1.2, height, 0.3), CFrame.new(top + Vector3.new(x, -height / 2, 0)), color, Enum.Material.SmoothPlastic, folder)
		ribbon.Transparency = 0.15
		ribbon.CanCollide = false
	end
end

local function makeToyRail(origin: Vector3, length: number, parent: Instance)
	for _, x in ipairs({ -length / 2, length / 2 }) do
		local post = ArenaKit.NewPart("ToyRailPost", Vector3.new(0.6, 3.2, 0.6), CFrame.new(origin + Vector3.new(x, 1.6, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, parent)
		post.CanCollide = true
	end
	local rail = ArenaKit.NewPart("ToyRail", Vector3.new(length, 0.5, 0.5), CFrame.new(origin + Vector3.new(0, 2.8, 0)), Color3.fromRGB(255, 120, 150), Enum.Material.SmoothPlastic, parent)
	rail.CanCollide = true
end

local function makeToySlide(pos: Vector3, parent: Instance, color: Color3)
	local ramp = Instance.new("WedgePart")
	ramp.Name = "ToySlide"
	ramp.Size = Vector3.new(8, 5, 12)
	ramp.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.rad(90), 0)
	ramp.Color = color
	ramp.Material = Enum.Material.SmoothPlastic
	ramp.Anchored = true
	ramp.CanCollide = true
	ramp.Parent = parent
	local strip = ArenaKit.NewPart("SlideStrip", Vector3.new(2.2, 0.18, 8), CFrame.new(pos + Vector3.new(0, 4.7, -1)), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, parent)
	strip.CanCollide = false
end

local function makeToyDice(pos: Vector3, parent: Instance)
	local dice = ArenaKit.NewPart("GiantDice", Vector3.new(5.2, 5.2, 5.2), CFrame.new(pos + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, math.rad(18), 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, parent)
	dice.CanCollide = true
	for _, side in ipairs({ Vector3.new(0, 0, -2.66), Vector3.new(0, 0, 2.66), Vector3.new(-2.66, 0, 0) }) do
		local pip = ArenaKit.NewPart("DicePip", Vector3.new(0.65, 0.65, 0.12), CFrame.new(pos + Vector3.new(0, 2.6, 0) + side), Color3.fromRGB(90, 130, 220), Enum.Material.Neon, parent)
		pip.Shape = Enum.PartType.Ball
		pip.CanCollide = false
	end
end

local function makeToyArch(pos: Vector3, parent: Instance)
	local colors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 210, 90) }
	for i, x in ipairs({ -4, 0, 4 }) do
		local pillar = ArenaKit.NewPart("ToyArchBlock", Vector3.new(2.2, 7 + (i % 2) * 2, 2.2), CFrame.new(pos + Vector3.new(x, 3.5 + (i % 2), 0)), colors[i], Enum.Material.SmoothPlastic, parent)
		pillar.CanCollide = true
	end
	local top = ArenaKit.NewPart("ToyArchTop", Vector3.new(10, 1.8, 2.4), CFrame.new(pos + Vector3.new(0, 8.4, 0)), Color3.fromRGB(170, 130, 255), Enum.Material.SmoothPlastic, parent)
	top.CanCollide = true
end

local function makeToyTeamMarker(pos: Vector3, teamId: string, parent: Instance)
	local color = teamId == "Red" and Color3.fromRGB(255, 100, 150) or Color3.fromRGB(86, 180, 255)
	local pole = ArenaKit.NewPart("ToyTeamPole", Vector3.new(0.45, 7, 0.45), CFrame.new(pos + Vector3.new(0, 3.5, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, parent)
	pole.CanCollide = false
	local flag = ArenaKit.NewPart("ToyTeamFlag", Vector3.new(4.2, 2, 0.18), CFrame.new(pos + Vector3.new(2.1, 5.8, 0)), color, Enum.Material.Neon, parent)
	flag.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 0.7
	light.Parent = flag
end

function Toybox.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, Toybox.Name)
	local layout = ArenaKit.StandardLayout

	local centerPos = layout.Center.pos
	local centerR = layout.Center.r
	local center = ArenaKit.MakeIslandBase(centerPos, centerR, "CenterIsland", PALETTE, Enum.Material.SmoothPlastic, arena)
	scatterDecor(centerPos, centerR, center, 8, 30)
	makeBlockTower(centerPos + Vector3.new(0, 1.6, 0), center)
	makeToyHouse(Vector3.new(-16, 1.6, -8), center, 0.9)
	makeToyHouse(Vector3.new(14, 1.6, 10), center, 0.72)
	makeToyArch(Vector3.new(0, 1.6, -15), center)
	makeToyRail(Vector3.new(-13, 1.6, 3), 16, center)
	makeToySlide(Vector3.new(10, 1.6, -9), center, Color3.fromRGB(255, 120, 150))
	makeToyDice(Vector3.new(-10, 1.6, 12), center)
	makePlatform(Vector3.new(0, 8, 0), Vector3.new(16, 1.5, 16), center)
	makeCrate(Vector3.new(-14, 1.6, 10), center)
	makeCrate(Vector3.new(14, 1.6, -10), center)
	ArenaKit.AddPowerPad(Vector3.new(0, 9, 0), powerPads)

	for i, o in ipairs(layout.Outer) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "Island" .. i, PALETTE, Enum.Material.SmoothPlastic, arena)
		scatterDecor(o.pos, o.r, isl, 5, 16)
		makeStreamerFall(o.pos + Vector3.new(o.r - 2, 1, 0), 36 + i * 3, isl)
		makeStreamerFall(o.pos + Vector3.new(-(o.r - 2), 1, 4), 30 + i * 3, isl)
		if i == 3 or i == 4 or i == 5 or i == 6 then
			makeToyHouse(o.pos + Vector3.new(-5, 1.6, 4), isl, 0.66)
		end
		if o.team then
			makeToyTeamMarker(o.pos + Vector3.new(-8, 1.6, -8), o.team, isl)
			makeToyRail(o.pos + Vector3.new(0, 1.6, 9), 14, isl)
			makeToySlide(o.pos + Vector3.new(8, 1.6, -5), isl, o.team == "Red" and Color3.fromRGB(255, 120, 150) or Color3.fromRGB(120, 200, 255))
		else
			makeToyArch(o.pos + Vector3.new(0, 1.6, -8), isl)
			makeToyDice(o.pos + Vector3.new(7, 1.6, 6), isl)
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
		local isl = ArenaKit.MakeIslandBase(s.pos, s.r, "Satellite" .. si, PALETTE, Enum.Material.SmoothPlastic, arena)
		scatterDecor(s.pos, s.r, isl, 1, 6)
	end

	ArenaKit.ScatterDebris(arena, 22, PALETTE, false)
	ArenaKit.MakeClouds(arena, Color3.fromRGB(255, 245, 250))
	ArenaKit.ApplyAtmosphere({
		Density = 0.18, Offset = 0.2, Color = Color3.fromRGB(255, 220, 240),
		Decay = Color3.fromRGB(180, 210, 255), Glare = 0.2, Haze = 0.9,
		Ambient = Color3.fromRGB(150, 150, 170), OutdoorAmbient = Color3.fromRGB(200, 200, 220),
		ClockTime = 13,
	})
	arena:SetAttribute("SpawnCount", #spawns:GetChildren())

	return arena
end

return Toybox
