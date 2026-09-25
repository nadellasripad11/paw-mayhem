--!strict
-- Map 4/4: Neon Rooftops - skyscraper roofs at dusk over a foggy drop. Its
-- own layout (not the shared island one): a tall centre tower roof (the King
-- of the Hill spot), raised flank roofs, stepping-stone rooftops and two team
-- bases with a side roof each way (three spawns per team). Plank bridges link
-- the roofs and jump pads fling you up to the tower. Fall between buildings
-- and you're out. AC units and water tanks are solid cover.

local Workspace = game:GetService("Workspace")
local ArenaKit = require(script.Parent.Parent.ArenaKit)

local Rooftops = { Id = "Rooftops", Name = "Neon Rooftops" }

local PALETTE: ArenaKit.Palette = {
	Top = Color3.fromRGB(88, 92, 108), TopDark = Color3.fromRGB(70, 74, 90),
	Stone = Color3.fromRGB(60, 62, 78), StoneDark = Color3.fromRGB(44, 46, 60),
	Wood = Color3.fromRGB(150, 110, 80), WoodDark = Color3.fromRGB(110, 80, 58),
}
local FACADES = { Color3.fromRGB(52, 56, 76), Color3.fromRGB(64, 58, 84), Color3.fromRGB(46, 60, 78), Color3.fromRGB(70, 64, 72) }
local NEON = { Color3.fromRGB(255, 90, 200), Color3.fromRGB(80, 220, 255), Color3.fromRGB(255, 200, 80), Color3.fromRGB(150, 110, 255) }
local TEAM = { Blue = Color3.fromRGB(64, 150, 255), Red = Color3.fromRGB(255, 82, 90) }

local rng = Random.new(20260925)
local NP = ArenaKit.NewPart

-- name, centre (x, z), roof top height, size (x, z), team
local ROOFS = {
	{ "center", 0, 0, 18, 30, 30 },
	{ "flankL", -60, 0, 14, 24, 30 },
	{ "flankR", 60, 0, 14, 24, 30 },
	{ "stepBL", -30, -45, 6, 18, 18 },
	{ "stepBR", 30, -45, 6, 18, 18 },
	{ "stepRL", -30, 45, 6, 18, 18 },
	{ "stepRR", 30, 45, 6, 18, 18 },
	{ "baseB", 0, -90, 8, 34, 26, "Blue" },
	{ "baseR", 0, 90, 8, 34, 26, "Red" },
	{ "sideBL", -45, -80, 12, 22, 22, "Blue" },
	{ "sideBR", 45, -80, 12, 22, 22, "Blue" },
	{ "sideRL", -45, 80, 12, 22, 22, "Red" },
	{ "sideRR", 45, 80, 12, 22, 22, "Red" },
}
local LINKS = {
	{ "baseB", "sideBL" }, { "baseB", "sideBR" }, { "baseR", "sideRL" }, { "baseR", "sideRR" },
	{ "sideBL", "stepBL" }, { "sideBR", "stepBR" }, { "sideRL", "stepRL" }, { "sideRR", "stepRR" },
	{ "stepBL", "center" }, { "stepBR", "center" }, { "stepRL", "center" }, { "stepRR", "center" },
	{ "stepBL", "flankL" }, { "stepRL", "flankL" }, { "stepBR", "flankR" }, { "stepRR", "flankR" },
	{ "flankL", "center" }, { "flankR", "center" },
}

type Roof = { name: string, x: number, z: number, top: number, sx: number, sz: number, team: string?, folder: Folder }

-- Point on roof `a`'s top, `inset` studs inside its edge, on the way to `b`.
local function edgeToward(a: Roof, b: Roof, inset: number): Vector3
	local d = Vector3.new(b.x - a.x, 0, b.z - a.z)
	local tx = math.abs(d.X) > 1e-3 and (a.sx / 2) / math.abs(d.X) or math.huge
	local tz = math.abs(d.Z) > 1e-3 and (a.sz / 2) / math.abs(d.Z) or math.huge
	local p = Vector3.new(a.x, a.top, a.z) + d * math.min(tx, tz)
	return p - d.Unit * inset
end

local function building(r: Roof)
	local f = r.folder
	local facade = FACADES[rng:NextInteger(1, #FACADES)]
	-- The walkable roof (the only thing you stand on) and the tower below it.
	NP("Floor", Vector3.new(r.sx, 1, r.sz), CFrame.new(r.x, r.top - 0.5, r.z), PALETTE.Top, Enum.Material.Concrete, f)
	NP("Building", Vector3.new(r.sx - 0.4, 150, r.sz - 0.4), CFrame.new(r.x, r.top - 1 - 75, r.z), facade, Enum.Material.Concrete, f)
	-- Low parapet round the edge (decoration: you can still be knocked off).
	for _, e in ipairs({ { 0, r.sz / 2, r.sx, 0.4 }, { 0, -r.sz / 2, r.sx, 0.4 }, { r.sx / 2, 0, 0.4, r.sz }, { -r.sx / 2, 0, 0.4, r.sz } }) do
		NP("Parapet", Vector3.new(e[3], 0.8, e[4]), CFrame.new(r.x + e[1], r.top + 0.4, r.z + e[2]), PALETTE.TopDark, Enum.Material.Concrete, f)
	end
	-- Glowing window rows down every face.
	local glow = NEON[rng:NextInteger(1, #NEON)]
	for row = 1, 6 do
		local y = r.top - 4 - row * 7
		for _, face in ipairs({ { 0, r.sz / 2 + 0.05, r.sx * 0.8, 0.1 }, { 0, -r.sz / 2 - 0.05, r.sx * 0.8, 0.1 }, { r.sx / 2 + 0.05, 0, 0.1, r.sz * 0.8 }, { -r.sx / 2 - 0.05, 0, 0.1, r.sz * 0.8 } }) do
			if rng:NextNumber() < 0.8 then
				local w = NP("Window", Vector3.new(face[3], 1.2, face[4]), CFrame.new(r.x + face[1], y, r.z + face[2]), glow, Enum.Material.Neon, f)
				w.Transparency = rng:NextNumber(0.1, 0.5)
			end
		end
	end
end

-- Rooftop cover: an AC unit (with a fan grille) or a water tank on legs.
local function acUnit(pos: Vector3, parent: Instance)
	NP("Crate", Vector3.new(4.5, 3, 3.4), CFrame.new(pos + Vector3.new(0, 1.5, 0)), Color3.fromRGB(180, 186, 196), Enum.Material.Metal, parent)
	local fan = NP("Fan", Vector3.new(0.2, 2.2, 2.2), CFrame.new(pos + Vector3.new(0, 3.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(60, 64, 74), Enum.Material.DiamondPlate, parent)
	fan.Shape = Enum.PartType.Cylinder
	fan.CanCollide = false
end

local function waterTank(pos: Vector3, parent: Instance)
	for _, o in ipairs({ { 1.3, 1.3 }, { -1.3, 1.3 }, { 1.3, -1.3 }, { -1.3, -1.3 } }) do
		NP("Post", Vector3.new(0.3, 3, 0.3), CFrame.new(pos + Vector3.new(o[1], 1.5, o[2])), Color3.fromRGB(90, 70, 60), Enum.Material.Wood, parent)
	end
	local tank = NP("Barrel", Vector3.new(4.5, 4, 4), CFrame.new(pos + Vector3.new(0, 5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 104, 76), Enum.Material.WoodPlanks, parent)
	tank.Shape = Enum.PartType.Cylinder
	local lid = NP("Lid", Vector3.new(0.4, 4.6, 4.6), CFrame.new(pos + Vector3.new(0, 7.4, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(110, 76, 58), Enum.Material.Wood, parent)
	lid.Shape = Enum.PartType.Cylinder
	lid.CanCollide = false
end

local function antenna(pos: Vector3, h: number, parent: Instance)
	NP("Post", Vector3.new(0.3, h, 0.3), CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color3.fromRGB(170, 176, 186), Enum.Material.Metal, parent)
	local light = NP("Bulb", Vector3.new(0.6, 0.6, 0.6), CFrame.new(pos + Vector3.new(0, h, 0)), Color3.fromRGB(255, 60, 70), Enum.Material.Neon, parent)
	light.Shape = Enum.PartType.Ball
end

-- A glowing sign hung on a building face.
local function sign(r: Roof, side: number, text: string)
	local color = NEON[rng:NextInteger(1, #NEON)]
	local board = NP("Banner", Vector3.new(12, 3.2, 0.3), CFrame.new(r.x, r.top - 4, r.z + side * (r.sz / 2 + 0.25)), Color3.fromRGB(20, 20, 30), Enum.Material.SmoothPlastic, r.folder)
	board.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Face = side > 0 and Enum.NormalId.Back or Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Parent = gui
end

-- A random clear spot on a roof, away from its middle and the given points.
local function roofSpot(r: Roof, avoid: { Vector3 }): Vector3?
	for _ = 1, 20 do
		local p = Vector3.new(r.x + rng:NextNumber(-0.38, 0.38) * r.sx, r.top, r.z + rng:NextNumber(-0.38, 0.38) * r.sz)
		local ok = (Vector3.new(p.X - r.x, 0, p.Z - r.z)).Magnitude > 5
		for _, q in ipairs(avoid) do
			if (Vector3.new(p.X - q.X, 0, p.Z - q.Z)).Magnitude < 7 then
				ok = false
				break
			end
		end
		if ok then
			return p
		end
	end
	return nil
end

function Rooftops.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, Rooftops.Name)
	local R: { [string]: Roof } = {}
	for _, spec in ipairs(ROOFS) do
		local folder = Instance.new("Folder")
		folder.Name = spec[1]
		folder.Parent = arena
		local r: Roof = { name = spec[1], x = spec[2], z = spec[3], top = spec[4], sx = spec[5], sz = spec[6], team = spec[7], folder = folder }
		R[r.name] = r
		building(r)
		ArenaKit.MarkPlayable(folder)
	end

	-- Bridges: planks from roof edge to roof edge (the kit's ramp handles
	-- the height difference). Remember where they land so props keep clear.
	local keepClear: { [string]: { Vector3 } } = {}
	local bridges = Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = arena
	for _, l in ipairs(LINKS) do
		local a, b = R[l[1]], R[l[2]]
		local pa, pb = edgeToward(a, b, 2), edgeToward(b, a, 2)
		ArenaKit.MakeBridge(pa, pb, bridges, PALETTE)
		keepClear[a.name] = keepClear[a.name] or {}
		keepClear[b.name] = keepClear[b.name] or {}
		table.insert(keepClear[a.name], pa)
		table.insert(keepClear[b.name], pb)
	end

	-- Spawns: each team's base plus both of its side roofs.
	for _, team in ipairs({ "Blue", "Red" }) do
		local keys = team == "Blue" and { "baseB", "sideBL", "sideBR" } or { "baseR", "sideRL", "sideRR" }
		for _, key in ipairs(keys) do
			local r = R[key]
			local pos = Vector3.new(r.x, r.top - ArenaKit.SURFACE, r.z + (key == "baseB" and -4 or key == "baseR" and 4 or 0))
			ArenaKit.AddTeamSpawnPoint(pos, team, spawns, r.folder)
			table.insert(keepClear[key], Vector3.new(pos.X, r.top, pos.Z))
		end
		-- Team-coloured light strip along the base's front edge.
		local base = R[keys[1]]
		local front = team == "Blue" and 1 or -1
		NP("TeamStrip", Vector3.new(base.sx * 0.9, 0.2, 0.5), CFrame.new(base.x, base.top + 0.05, base.z + front * (base.sz / 2 - 1)), TEAM[team], Enum.Material.Neon, base.folder).CanCollide = false
	end

	-- Jump pads: from each base up onto the tower roof, and from the tower
	-- out to the flanks.
	local pads = Instance.new("Folder")
	pads.Name = "JumpPads"
	pads.Parent = arena
	local function isle(r: Roof)
		local i = ArenaKit.NewIsle(Vector3.new(r.x, r.top - ArenaKit.SURFACE, r.z), math.min(r.sx, r.sz) / 2, r.folder)
		for _, p in ipairs(keepClear[r.name] or {}) do
			ArenaKit.Reserve(i, p, 3)
		end
		return i
	end
	local center = R.center
	local centerIsle = isle(center)
	for _, key in ipairs({ "baseB", "baseR" }) do
		local r = R[key]
		local toward = key == "baseB" and 1 or -1
		local pad = ArenaKit.AddJumpPad(isle(r), math.atan2(toward, 0), r.sz * 0.3, Vector3.new(0, center.top, -toward * 8), pads)
		if pad then
			table.insert(keepClear[key], pad.Position)
		end
	end
	for _, key in ipairs({ "flankL", "flankR" }) do
		local r = R[key]
		ArenaKit.AddJumpPad(centerIsle, math.atan2(0, r.x), 9, Vector3.new(r.x, r.top, 6), pads)
	end

	-- Power-ups on the flanks and the stepping roofs.
	for _, key in ipairs({ "flankL", "flankR", "stepBL", "stepRR" }) do
		local r = R[key]
		ArenaKit.AddPowerPad(Vector3.new(r.x, r.top - ArenaKit.SURFACE, r.z), powerPads)
		table.insert(keepClear[key], Vector3.new(r.x, r.top, r.z))
	end

	-- Rooftop cover and clutter, kept off bridges, spawns and pads.
	for _, r in pairs(R) do
		local avoid = keepClear[r.name] or {}
		local count = math.floor(r.sx * r.sz / 260)
		for k = 1, count do
			local p = roofSpot(r, avoid)
			if p then
				if k % 3 == 0 then
					waterTank(p, r.folder)
				else
					acUnit(p, r.folder)
				end
				table.insert(avoid, p)
			end
		end
		local ap = roofSpot(r, avoid)
		if ap then
			antenna(ap, rng:NextNumber(5, 9), r.folder)
		end
	end

	-- The tower: a helipad ring and signs.
	local ring = NP("Helipad", Vector3.new(0.1, 16, 16), CFrame.new(center.x, center.top + 0.02, center.z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 214, 90), Enum.Material.Neon, center.folder)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.55
	ring.CanCollide = false
	sign(center, 1, "PAW MAYHEM")
	sign(center, -1, "MEOW CITY")
	sign(R.flankL, 1, "FISH 24/7")
	sign(R.flankR, -1, "NINE LIVES")

	-- Distant skyline (scenery only) sinking into the fog.
	local skyline = Instance.new("Folder")
	skyline.Name = "Scenery"
	skyline.Parent = arena
	for k = 1, 46 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(170, 380)
		local w, h = rng:NextNumber(14, 36), rng:NextNumber(60, 170)
		local x, z = math.cos(a) * d, math.sin(a) * d
		local b = NP("Skyline" .. k, Vector3.new(w, h, w * rng:NextNumber(0.7, 1.3)), CFrame.new(x, -60 + h / 2, z), FACADES[rng:NextInteger(1, #FACADES)]:Lerp(Color3.fromRGB(30, 30, 50), 0.4), Enum.Material.Concrete, skyline)
		b.CanCollide = false
		if rng:NextNumber() < 0.6 then
			local win = NP("Window", Vector3.new(w * 1.02, 1.2, w * 1.02), CFrame.new(x, -60 + h * rng:NextNumber(0.5, 0.95), z), NEON[rng:NextInteger(1, #NEON)], Enum.Material.Neon, skyline)
			win.Transparency = 0.4
		end
	end

	ArenaKit.ApplyAtmosphere({
		Density = 0.36, Offset = 0.1, Color = Color3.fromRGB(190, 150, 220), Decay = Color3.fromRGB(90, 70, 140),
		Glare = 0.4, Haze = 2.2, Ambient = Color3.fromRGB(120, 110, 150), OutdoorAmbient = Color3.fromRGB(150, 130, 180),
		ClockTime = 18.2, FogColor = Color3.fromRGB(120, 90, 160), FogEnd = 900, Brightness = 2.2,
	})
	-- Falls between buildings end quickly: out well before the fog floor.
	arena:SetAttribute("KillFloorY", -45)
	arena:SetAttribute("SpawnCount", #spawns:GetChildren())
	return arena
end

return Rooftops
