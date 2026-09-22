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

function Toybox.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, Toybox.Name)
	local layout = ArenaKit.StandardLayout

	local centerPos = layout.Center.pos
	local centerR = layout.Center.r
	local center = ArenaKit.MakeIslandBase(centerPos, centerR, "CenterIsland", PALETTE, Enum.Material.SmoothPlastic, arena)
	scatterDecor(centerPos, centerR, center, 8, 30)
	makeBlockTower(centerPos + Vector3.new(0, 1.6, 0), center)
	makePlatform(Vector3.new(0, 8, 0), Vector3.new(16, 1.5, 16), center)
	makeCrate(Vector3.new(-14, 1.6, 10), center)
	makeCrate(Vector3.new(14, 1.6, -10), center)
	ArenaKit.AddPowerPad(Vector3.new(0, 9, 0), powerPads)
	ArenaKit.AddHexSpawns(centerPos, centerR, nil, spawns)

	for i, o in ipairs(layout.Outer) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "Island" .. i, PALETTE, Enum.Material.SmoothPlastic, arena)
		scatterDecor(o.pos, o.r, isl, 5, 16)
		makeStreamerFall(o.pos + Vector3.new(o.r - 2, 1, 0), 36 + i * 3, isl)
		makeStreamerFall(o.pos + Vector3.new(-(o.r - 2), 1, 4), 30 + i * 3, isl)
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

	return arena
end

return Toybox
