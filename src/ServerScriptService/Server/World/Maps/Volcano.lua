--!strict
-- Map 2/3: Volcano — obsidian islands, glowing lava falls, charred spike
-- "trees", a smoking central lava vent instead of a windmill. Same tested
-- island layout as Sky Islands (ArenaKit.StandardLayout), completely
-- different theme — original, no copied assets.

local Workspace = game:GetService("Workspace")
local ArenaKit = require(script.Parent.Parent.ArenaKit)

local Volcano = { Id = "Volcano", Name = "Volcano" }

local PALETTE: ArenaKit.Palette = {
	Top = Color3.fromRGB(58, 48, 54), TopDark = Color3.fromRGB(40, 32, 38), -- basalt
	Stone = Color3.fromRGB(70, 58, 62), StoneDark = Color3.fromRGB(46, 38, 42),
	Wood = Color3.fromRGB(52, 38, 34), WoodDark = Color3.fromRGB(30, 22, 20), -- charred wood
}
local LAVA = Color3.fromRGB(255, 110, 40)
local LAVA_BRIGHT = Color3.fromRGB(255, 190, 60)
local EMBER = Color3.fromRGB(255, 140, 60)

-- Charred dead spike in place of a tree.
local function makeSpike(pos: Vector3, parent: Instance)
	local h = 5 + math.random() * 4
	local spike = ArenaKit.NewPart("Spike", Vector3.new(1.2, h, 1.2), CFrame.new(pos + Vector3.new(0, h / 2, 0)), PALETTE.WoodDark, Enum.Material.Basalt, parent)
	-- taper via a smaller cap so it reads as a burnt point, not a plain box
	ArenaKit.NewPart("SpikeTip", Vector3.new(0.3, 1.2, 0.3), CFrame.new(pos + Vector3.new(0, h + 0.4, 0)), PALETTE.WoodDark, Enum.Material.Basalt, parent)
end

-- Small glowing ember cluster in place of a flower.
local function makeEmber(pos: Vector3, parent: Instance)
	local glow = ArenaKit.NewPart("Ember", Vector3.new(0.5, 0.3, 0.5), CFrame.new(pos + Vector3.new(0, 0.15, 0)), EMBER, Enum.Material.Neon, parent)
	glow.Shape = Enum.PartType.Ball
	glow.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = EMBER
	light.Range = 6
	light.Brightness = 1.5
	light.Parent = glow
end

local function scatterDecor(center: Vector3, radius: number, parent: Instance, spikes: number, embers: number)
	for _ = 1, spikes do
		local a = math.random() * math.pi * 2
		local r = radius * (0.3 + math.random() * 0.55)
		makeSpike(center + Vector3.new(math.cos(a) * r, 1.6, math.sin(a) * r), parent)
	end
	for _ = 1, embers do
		local a = math.random() * math.pi * 2
		local r = radius * (0.2 + math.random() * 0.7)
		makeEmber(center + Vector3.new(math.cos(a) * r, 1.6, math.sin(a) * r), parent)
	end
end

local function makeCrate(pos: Vector3, parent: Instance)
	ArenaKit.NewPart("Crate", Vector3.new(4, 4, 4), CFrame.new(pos + Vector3.new(0, 3.6, 0)), PALETTE.Wood, Enum.Material.Basalt, parent).CanCollide = true
	ArenaKit.NewPart("Trim", Vector3.new(4.1, 0.4, 4.1), CFrame.new(pos + Vector3.new(0, 5.4, 0)), PALETTE.WoodDark, Enum.Material.Basalt, parent)
end

local function makeForge(pos: Vector3, parent: Instance, scale: number?)
	local s = scale or 1
	local folder = Instance.new("Folder")
	folder.Name = "ObsidianForge"
	folder.Parent = parent
	for _, x in ipairs({ -2.6, 2.6 }) do
		ArenaKit.NewPart("Pillar", Vector3.new(2.2 * s, 8 * s, 2.2 * s), CFrame.new(pos + Vector3.new(x * s, 4 * s, 0)), PALETTE.StoneDark, Enum.Material.Basalt, folder)
	end
	ArenaKit.NewPart("Lintel", Vector3.new(8 * s, 2 * s, 2.2 * s), CFrame.new(pos + Vector3.new(0, 8 * s, 0)), PALETTE.Stone, Enum.Material.Basalt, folder)
	local core = ArenaKit.NewPart("Core", Vector3.new(3.4 * s, 3.4 * s, 0.8 * s), CFrame.new(pos + Vector3.new(0, 4.1 * s, -1.2 * s)), LAVA_BRIGHT, Enum.Material.Neon, folder)
	core.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = LAVA_BRIGHT
	light.Range = 14 * s
	light.Brightness = 1.4
	light.Parent = core
	for _, x in ipairs({ -4.8, 4.8 }) do
		local crystal = ArenaKit.NewPart("Crystal", Vector3.new(1.2 * s, 4 * s, 1.2 * s), CFrame.new(pos + Vector3.new(x * s, 2 * s, 1.8 * s)) * CFrame.Angles(0, 0, math.rad(x > 0 and -16 or 16)), LAVA, Enum.Material.Neon, folder)
		crystal.CanCollide = false
	end
end

local function makePlatform(pos: Vector3, size: Vector3, parent: Instance)
	ArenaKit.NewPart("Platform", size, CFrame.new(pos), PALETTE.Stone, Enum.Material.Basalt, parent).CanCollide = true
	for _, ox in ipairs({ -1, 1 }) do
		for _, oz in ipairs({ -1, 1 }) do
			ArenaKit.NewPart("Leg", Vector3.new(0.8, pos.Y + 1.6, 0.8), CFrame.new(pos.X + ox * (size.X / 2 - 1), pos.Y / 2, pos.Z + oz * (size.Z / 2 - 1)), PALETTE.StoneDark, Enum.Material.Basalt, parent)
		end
	end
end

-- Central landmark: a smoking lava vent with a slow-pulsing glow, standing in
-- for the windmill. No moving blades, but the light genuinely animates.
local function makeLavaVent(pos: Vector3, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "LavaVent"
	folder.Parent = parent
	ArenaKit.NewPart("Cone1", Vector3.new(14, 10, 14), CFrame.new(pos + Vector3.new(0, 5, 0)), PALETTE.StoneDark, Enum.Material.Basalt, folder).CanCollide = true
	ArenaKit.NewPart("Cone2", Vector3.new(9, 7, 9), CFrame.new(pos + Vector3.new(0, 11, 0)), PALETTE.Stone, Enum.Material.Basalt, folder).CanCollide = true
	local pool = ArenaKit.NewPart("Pool", Vector3.new(6, 1, 6), CFrame.new(pos + Vector3.new(0, 14.6, 0)), LAVA, Enum.Material.Neon, folder)
	pool.Shape = Enum.PartType.Cylinder
	pool.CFrame = CFrame.new(pos + Vector3.new(0, 14.6, 0)) * CFrame.Angles(0, 0, math.rad(90))
	pool.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = LAVA
	light.Range = 26
	light.Brightness = 2
	light.Parent = pool

	task.spawn(function()
		local t = 0
		while pool.Parent do
			t += 0.05
			local pulse = 0.5 + math.sin(t) * 0.5
			pool.Color = LAVA:Lerp(LAVA_BRIGHT, pulse)
			light.Brightness = 1.6 + pulse * 1.2
			task.wait(0.1)
		end
	end)
end

-- Glowing "lava fall" in place of a waterfall — a molten sheet with a rising
-- ash-smoke mist above the pool where it lands.
local function makeLavaFall(top: Vector3, height: number, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "LavaFall"
	folder.Parent = parent
	local sheet = ArenaKit.NewPart("Lava", Vector3.new(8, height, 1), CFrame.new(top - Vector3.new(0, height / 2, 0)), LAVA, Enum.Material.Neon, folder)
	sheet.Transparency = 0.15
	sheet.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = LAVA
	light.Range = 16
	light.Brightness = 1.2
	light.Parent = sheet
	local ash = ArenaKit.NewPart("Ash", Vector3.new(10, 4, 6), CFrame.new(top - Vector3.new(0, height, 0)), Color3.fromRGB(60, 55, 58), Enum.Material.ForceField, folder)
	ash.Transparency = 0.5
	ash.CanCollide = false
end

local function makeLavaChannel(pos: Vector3, length: number, parent: Instance)
	local bed = ArenaKit.NewPart("LavaChannelBed", Vector3.new(length, 0.5, 3.2), CFrame.new(pos + Vector3.new(0, 1.9, 0)), PALETTE.StoneDark, Enum.Material.Basalt, parent)
	bed.CanCollide = false
	local flow = ArenaKit.NewPart("LavaChannel", Vector3.new(length - 0.8, 0.22, 1.45), CFrame.new(pos + Vector3.new(0, 2.2, 0)), LAVA, Enum.Material.Neon, parent)
	flow.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = LAVA
	light.Range = 11
	light.Brightness = 0.7
	light.Parent = flow
end

local function makeCrystalField(pos: Vector3, parent: Instance, tint: Color3?)
	local color = tint or LAVA_BRIGHT
	for i = 1, 5 do
		local angle = math.rad(i * 67)
		local offset = Vector3.new(math.cos(angle) * (2 + i * 0.5), 0, math.sin(angle) * (2 + i * 0.5))
		local crystal = ArenaKit.NewPart("EmberCrystal", Vector3.new(1.3, 3 + (i % 3) * 1.6, 1.3), CFrame.new(pos + offset + Vector3.new(0, 2, 0)) * CFrame.Angles(math.rad(-12 + i * 5), angle, math.rad(18 - i * 4)), color, Enum.Material.Neon, parent)
		crystal.CanCollide = false
	end
end

local function makeVolcanoGate(pos: Vector3, parent: Instance)
	for _, x in ipairs({ -5, 5 }) do
		local pillar = ArenaKit.NewPart("GatePillar", Vector3.new(2.4, 10, 2.4), CFrame.new(pos + Vector3.new(x, 5, 0)), PALETTE.StoneDark, Enum.Material.Basalt, parent)
		pillar.CanCollide = true
	end
	local lintel = ArenaKit.NewPart("GateLintel", Vector3.new(12, 2.5, 2.8), CFrame.new(pos + Vector3.new(0, 10, 0)), PALETTE.Stone, Enum.Material.Basalt, parent)
	lintel.CanCollide = true
	local flame = ArenaKit.NewPart("GateFlame", Vector3.new(5, 0.45, 0.35), CFrame.new(pos + Vector3.new(0, 10.1, -1.5)), LAVA_BRIGHT, Enum.Material.Neon, parent)
	flame.CanCollide = false
end

local function makeVolcanoChain(origin: Vector3, length: number, parent: Instance)
	for i = 1, math.floor(length / 2) do
		local link = ArenaKit.NewPart("ChainLink", Vector3.new(0.65, 0.65, 0.35), CFrame.new(origin + Vector3.new(0, -i * 1.8, 0)) * CFrame.Angles(0, math.rad(i * 18), math.rad(90)), PALETTE.Stone, Enum.Material.Metal, parent)
		link.Shape = Enum.PartType.Ball
		link.CanCollide = false
	end
end

local function makeVolcanoTeamMarker(pos: Vector3, teamId: string, parent: Instance)
	local color = teamId == "Red" and Color3.fromRGB(255, 82, 60) or Color3.fromRGB(80, 170, 255)
	local pole = ArenaKit.NewPart("ForgeBannerPole", Vector3.new(0.45, 8, 0.45), CFrame.new(pos + Vector3.new(0, 4, 0)), PALETTE.WoodDark, Enum.Material.Basalt, parent)
	pole.CanCollide = false
	local banner = ArenaKit.NewPart("ForgeBanner", Vector3.new(4.4, 2.1, 0.18), CFrame.new(pos + Vector3.new(2.1, 6.4, 0)), color, Enum.Material.Fabric, parent)
	banner.CanCollide = false
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 10
	glow.Brightness = 0.8
	glow.Parent = banner
end

function Volcano.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, Volcano.Name)
	local layout = ArenaKit.StandardLayout

	local centerPos = layout.Center.pos
	local centerR = layout.Center.r
	local center = ArenaKit.MakeIslandBase(centerPos, centerR, "CenterIsland", PALETTE, Enum.Material.Basalt, arena)
	scatterDecor(centerPos, centerR, center, 7, 28)
	makeLavaVent(centerPos + Vector3.new(0, 1.6, 0), center)
	makeForge(Vector3.new(-15, 1.6, -8), center, 0.9)
	makeVolcanoGate(Vector3.new(0, 1.6, -15), center)
	makeLavaChannel(Vector3.new(0, 1.6, 10), 18, center)
	makeCrystalField(Vector3.new(-10, 1.6, 12), center)
	makeCrystalField(Vector3.new(12, 1.6, -10), center, EMBER)
	makeVolcanoChain(Vector3.new(-20, 8, 0), 7, center)
	makePlatform(Vector3.new(0, 8, 0), Vector3.new(16, 1.5, 16), center)
	makeCrate(Vector3.new(-14, 1.6, 10), center)
	makeCrate(Vector3.new(14, 1.6, -10), center)
	ArenaKit.AddPowerPad(Vector3.new(0, 9, 0), powerPads)

	for i, o in ipairs(layout.Outer) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "Island" .. i, PALETTE, Enum.Material.Basalt, arena)
		scatterDecor(o.pos, o.r, isl, 4, 14)
		makeLavaFall(o.pos + Vector3.new(o.r - 2, 1, 0), 40 + i * 4, isl)
		makeLavaFall(o.pos + Vector3.new(-(o.r - 2), 1, 4), 34 + i * 3, isl)
		if i == 3 or i == 4 or i == 5 or i == 6 then
			makeForge(o.pos + Vector3.new(-5, 1.6, 4), isl, 0.65)
		end
		if o.team then
			makeVolcanoTeamMarker(o.pos + Vector3.new(-8, 1.6, -8), o.team, isl)
			makeVolcanoGate(o.pos + Vector3.new(0, 1.6, 8), isl)
			makeCrystalField(o.pos + Vector3.new(8, 1.6, -6), isl, o.team == "Red" and LAVA or LAVA_BRIGHT)
		else
			makeLavaChannel(o.pos + Vector3.new(0, 1.6, -8), 14, isl)
			makeVolcanoChain(o.pos + Vector3.new(-10, 8, 0), 5, isl)
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
		local isl = ArenaKit.MakeIslandBase(s.pos, s.r, "Satellite" .. si, PALETTE, Enum.Material.Basalt, arena)
		scatterDecor(s.pos, s.r, isl, 1, 5)
	end

	ArenaKit.ScatterDebris(arena, 22, PALETTE, false)
	ArenaKit.MakeClouds(arena, Color3.fromRGB(90, 70, 70), 0.5) -- smoky haze instead of white clouds
	ArenaKit.ApplyAtmosphere({
		Density = 0.42, Offset = 0.1, Color = Color3.fromRGB(255, 150, 100),
		Decay = Color3.fromRGB(120, 50, 40), Glare = 0.4, Haze = 2.2,
		Ambient = Color3.fromRGB(70, 40, 40), OutdoorAmbient = Color3.fromRGB(110, 70, 60),
		ClockTime = 20, FogColor = Color3.fromRGB(60, 30, 30), FogEnd = 2400,
	})
	arena:SetAttribute("SpawnCount", #spawns:GetChildren())

	return arena
end

return Volcano
