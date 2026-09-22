--!strict
-- ArenaKit: shared building blocks used by every map (SkyIslands, Volcano,
-- Toybox). Each map supplies its own palette + decoration functions; the
-- island/bridge/spawn/power-pad geometry — and, critically, the safety
-- guarantees around spawn placement — live here ONCE so every map gets them
-- identically instead of being re-derived (and possibly re-broken) per map.

local ArenaKit = {}

export type Palette = {
	Top: Color3, TopDark: Color3, -- island top surface (grass/rock/foam...)
	Stone: Color3, StoneDark: Color3, -- tapered underside tiers
	Wood: Color3, WoodDark: Color3, -- bridges/structures
}

function ArenaKit.NewPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Standard grass/rock-topped floating island with a tapered stone underside
-- and a thin invisible collision Floor (matches the original Sky Islands
-- shape, generalized to any palette/top material).
function ArenaKit.MakeIslandBase(center: Vector3, radius: number, name: string, palette: Palette, topMaterial: Enum.Material?, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	local top = ArenaKit.NewPart("Top", Vector3.new(radius * 2, 3, radius * 2), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), palette.Top, topMaterial or Enum.Material.Grass, folder)
	top.Shape = Enum.PartType.Cylinder

	local rim = ArenaKit.NewPart("Rim", Vector3.new(radius * 2 + 1, 1, radius * 2 + 1), CFrame.new(center + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)), palette.TopDark, topMaterial or Enum.Material.Grass, folder)
	rim.Shape = Enum.PartType.Cylinder

	local layers = 6
	for i = 1, layers do
		local frac = i / layers
		local r = radius * (1 - frac * 0.85)
		local y = center.Y - 1.5 - i * 3.2
		local c = (i % 2 == 0) and palette.Stone or palette.StoneDark
		local disc = ArenaKit.NewPart("Stone" .. i, Vector3.new(r * 2, 3.2, r * 2), CFrame.new(center.X, y, center.Z) * CFrame.Angles(0, 0, math.rad(90)), c, Enum.Material.Slate, folder)
		disc.Shape = Enum.PartType.Cylinder
	end

	local floor = ArenaKit.NewPart("Floor", Vector3.new(radius * 2, 1, radius * 2), CFrame.new(center + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), palette.Top, topMaterial or Enum.Material.Grass, folder)
	floor.Shape = Enum.PartType.Cylinder
	floor.Transparency = 1

	return folder
end

function ArenaKit.MakeBridge(a: Vector3, b: Vector3, parent: Instance, palette: Palette)
	local folder = Instance.new("Folder")
	folder.Name = "Bridge"
	folder.Parent = parent
	local dist = (b - a).Magnitude
	local mid = (a + b) / 2
	local look = CFrame.lookAt(mid, b)
	local planks = math.max(1, math.floor(dist / 3))
	for i = 0, planks do
		local t = i / planks
		local pos = a:Lerp(b, t)
		local plank = ArenaKit.NewPart("Plank", Vector3.new(5, 0.6, 2.6), CFrame.new(pos) * (look - look.Position), palette.Wood, Enum.Material.WoodPlanks, folder)
		plank.CanCollide = true
	end
	for _, side in ipairs({ -2.6, 2.6 }) do
		ArenaKit.NewPart("Rail", Vector3.new(0.3, 0.3, dist), CFrame.lookAt(mid + Vector3.new(0, 1.5, 0), b) * CFrame.new(side, 0, 0), palette.WoodDark, Enum.Material.Wood, folder)
	end
end

-- A single spawn marker. teamId may be nil for a universal/neutral spawn.
function ArenaKit.AddSpawn(pos: Vector3, teamId: string?, spawns: Folder)
	local pad = Instance.new("Part")
	pad.Name = "Spawn_" .. (teamId or "Neutral") .. "_" .. tostring(#spawns:GetChildren() + 1)
	pad.Size = Vector3.new(4, 1, 4)
	pad.Position = pos
	pad.Anchored = true
	pad.CanCollide = false
	pad.Transparency = 1
	pad:SetAttribute("Team", teamId)
	pad.Parent = spawns
end

-- Exactly 6 spawns per island, hexagon-arranged at half the island's radius —
-- always well inside the solid top, always a safe short drop above the
-- collidable Floor, never near an edge. Used identically by every map.
function ArenaKit.AddHexSpawns(center: Vector3, radius: number, teamId: string?, spawns: Folder)
	local r = radius * 0.5
	for k = 0, 5 do
		local ang = math.rad(k * 60)
		local offset = Vector3.new(math.cos(ang) * r, 3, math.sin(ang) * r)
		ArenaKit.AddSpawn(center + offset, teamId, spawns)
	end
end

function ArenaKit.AddPowerPad(pos: Vector3, pads: Folder)
	local pad = ArenaKit.NewPart("PowerPad", Vector3.new(4, 0.4, 4), CFrame.new(pos + Vector3.new(0, 1.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, pads)
	pad.Shape = Enum.PartType.Cylinder
	pad.Transparency = 0.5
	pad.CanCollide = false
end

-- Small floating debris scattered through open air between islands.
function ArenaKit.MakeDebris(pos: Vector3, size: number, parent: Instance, palette: Palette, topAccent: boolean?)
	local rock = ArenaKit.NewPart("Rock", Vector3.new(size, size * 0.7, size), CFrame.new(pos), palette.StoneDark, Enum.Material.Slate, parent)
	rock.Shape = Enum.PartType.Ball
	rock.CanCollide = false
	if topAccent ~= false and math.random() > 0.4 then
		local tuft = ArenaKit.NewPart("Tuft", Vector3.new(size * 0.5, size * 0.2, size * 0.5), CFrame.new(pos + Vector3.new(0, size * 0.4, 0)), palette.Top, Enum.Material.SmoothPlastic, parent)
		tuft.Shape = Enum.PartType.Ball
		tuft.CanCollide = false
	end
end

function ArenaKit.ScatterDebris(arena: Instance, count: number, palette: Palette, topAccent: boolean?)
	for i = 1, count do
		local angle = math.random() * math.pi * 2
		local dist = 20 + math.random() * 75
		local height = -10 + math.random() * 40
		local pos = Vector3.new(math.cos(angle) * dist, height, math.sin(angle) * dist)
		ArenaKit.MakeDebris(pos, 2 + math.random() * 3, arena, palette, topAccent)
	end
end

function ArenaKit.MakeClouds(arena: Instance, color: Color3, lowTransparency: number?)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local cloud = ArenaKit.NewPart("Cloud", Vector3.new(30, 6, 30), CFrame.new(math.cos(a) * 90, -40, math.sin(a) * 90), color, Enum.Material.SmoothPlastic, arena)
		cloud.Shape = Enum.PartType.Ball
		cloud.Transparency = lowTransparency or 0.3
		cloud.CanCollide = false
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.4
		local cloud = ArenaKit.NewPart("CloudHigh", Vector3.new(24, 5, 24), CFrame.new(math.cos(a) * 60, 55 + math.random() * 20, math.sin(a) * 60), color, Enum.Material.SmoothPlastic, arena)
		cloud.Shape = Enum.PartType.Ball
		cloud.Transparency = (lowTransparency or 0.3) + 0.15
		cloud.CanCollide = false
	end
end

-- Fresh Arena/Spawns/PowerUpPads folder structure — identical shape every map
-- must produce so PlayerService/PowerUpService work unchanged regardless of
-- which map is active.
function ArenaKit.SetupFolders(workspaceService: Workspace, mapName: string): (Folder, Folder, Folder)
	local existing = workspaceService:FindFirstChild("Arena")
	if existing then
		existing:Destroy()
	end
	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena:SetAttribute("MapName", mapName)
	arena.Parent = workspaceService

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = arena

	local powerPads = Instance.new("Folder")
	powerPads.Name = "PowerUpPads"
	powerPads.Parent = arena

	return arena, spawns, powerPads
end

-- Shared island layout used by every map — positions/radii are the same ones
-- whose spawn-safety math (hex spawns at half-radius, always above a solid
-- collidable Floor) was already verified. Reusing it means every new map
-- inherits that same safety guarantee and the same tested team balance,
-- instead of re-deriving island placement (and re-risking a bad one) per map.
ArenaKit.StandardLayout = {
	Center = { pos = Vector3.new(0, 0, 0), r = 34 },
	Outer = {
		{ pos = Vector3.new(0, 6, -70), r = 22, team = "Blue" },
		{ pos = Vector3.new(0, 6, 70), r = 22, team = "Red" },
		{ pos = Vector3.new(-70, 4, 0), r = 20, team = nil },
		{ pos = Vector3.new(70, 4, 0), r = 20, team = nil },
		{ pos = Vector3.new(-52, 10, -52), r = 16, team = nil },
		{ pos = Vector3.new(52, 10, 52), r = 16, team = nil },
	},
	Satellites = {
		{ pos = Vector3.new(30, 18, 30), r = 8 },
		{ pos = Vector3.new(-30, 22, -30), r = 7 },
	},
}

function ArenaKit.ApplyAtmosphere(opts: any)
	local Lighting = game:GetService("Lighting")
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if existing then
		existing:Destroy()
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = opts.Density or 0.28
	atmosphere.Offset = opts.Offset or 0.15
	atmosphere.Color = opts.Color or Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = opts.Decay or Color3.fromRGB(95, 140, 200)
	atmosphere.Glare = opts.Glare or 0.25
	atmosphere.Haze = opts.Haze or 1.4
	atmosphere.Parent = Lighting

	if opts.Ambient then
		Lighting.Ambient = opts.Ambient
	end
	if opts.OutdoorAmbient then
		Lighting.OutdoorAmbient = opts.OutdoorAmbient
	end
	if opts.ClockTime then
		Lighting.ClockTime = opts.ClockTime
	end
	if opts.FogColor then
		Lighting.FogColor = opts.FogColor
	end
	if opts.FogEnd then
		Lighting.FogEnd = opts.FogEnd
	end
end

return ArenaKit
