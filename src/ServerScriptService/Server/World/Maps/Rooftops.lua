--!strict
-- Map 4/4: Neon Rooftops - skyscraper roofs at dusk over a foggy drop. Its
-- own layout (not the shared island one): a tall centre tower roof (the King
-- of the Hill spot), raised flank roofs, stepping-stone rooftops and two team
-- bases with a side roof each way (three spawns per team). Plank bridges link
-- the roofs and jump pads fling you up to the tower. Fall between buildings
-- and you're out. AC units and water tanks are solid cover.

local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
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

-- A window-cleaner lift beside step roof `step` (`sx`, `sz` = which corner):
-- a yellow deck on a slider (MapFeatureService drives it) riding from the
-- roof up to a high perch over the tower, with cables and a pulley beam.
local function makeLift(step: Roof, sx: number, sz: number, parent: Instance)
	local x, zDeck, zPerch = 30.5 * sx, 33.5 * sz, 26.5 * sz
	local low, high = step.top, 26
	local metal = Color3.fromRGB(58, 62, 74)
	NP("Platform", Vector3.new(10, 1, 8), CFrame.new(x, high - 0.5, zPerch), Color3.fromRGB(70, 74, 86), Enum.Material.DiamondPlate, parent)
	NP("PerchStrip", Vector3.new(10, 0.15, 0.3), CFrame.new(x, high + 0.08, zPerch - sz * 3.85), NEON[2], Enum.Material.Neon, parent).CanCollide = false
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		NP("PostPerch", Vector3.new(0.8, 60, 0.8), CFrame.new(x + c[1] * 4.5, high - 30.5, zPerch + c[2] * 3.5), metal, Enum.Material.Metal, parent).CanCollide = false
	end
	for _, cx in ipairs({ -2.7, 2.7 }) do
		NP("StringCable", Vector3.new(0.15, high + 4 - low, 0.15), CFrame.new(x + cx, (high + 4 + low) / 2, zDeck), metal, Enum.Material.Metal, parent).CanCollide = false
	end
	NP("ArmPulley", Vector3.new(6.2, 0.6, 0.6), CFrame.new(x, high + 4, zDeck), metal, Enum.Material.Metal, parent).CanCollide = false
	-- The deck on its slider (it starts flush with the step roof).
	local guide = NP("LiftGuide", Vector3.one * 0.4, CFrame.new(x, low - 0.3, zDeck), metal, Enum.Material.Metal, parent)
	guide.Transparency = 1
	guide.CanCollide = false
	local deck = NP("Platform", Vector3.new(5, 0.6, 5), CFrame.new(x, low - 0.3, zDeck), Color3.fromRGB(255, 196, 40), Enum.Material.DiamondPlate, parent)
	for _, s in ipairs({ -1, 1 }) do
		local rail = NP("RailLift", Vector3.new(0.25, 1.4, 5), CFrame.new(x + s * 2.4, low + 0.7, zDeck), metal, Enum.Material.Metal, parent)
		rail.CanCollide = false
		rail.Massless = true
		rail.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = deck
		weld.Part1 = rail
		weld.Parent = deck
	end
	local up = CFrame.fromMatrix(Vector3.zero, Vector3.yAxis, Vector3.zAxis) -- the slide axis (X) points up
	local a0 = Instance.new("Attachment")
	a0.CFrame = up
	a0.Parent = guide
	local a1 = Instance.new("Attachment")
	a1.CFrame = up
	a1.Parent = deck
	local slider = Instance.new("PrismaticConstraint")
	slider.Attachment0 = a0
	slider.Attachment1 = a1
	slider.LimitsEnabled = true
	slider.LowerLimit = 0
	slider.UpperLimit = high - low
	slider.ActuatorType = Enum.ActuatorType.Servo
	slider.Speed = 7
	slider.ServoMaxForce = 1e7
	slider.TargetPosition = 0
	slider.Parent = deck
	deck.Anchored = false
	CollectionService:AddTag(slider, "Lift")
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

	-- Fan shafts off the outer side of both flank roofs: ride the updraft.
	for _, key in ipairs({ "flankL", "flankR" }) do
		local r = R[key]
		ArenaKit.AddSwimColumn("Wind", ArenaKit.NewIsle(Vector3.new(r.x, r.top - ArenaKit.SURFACE, r.z), r.sx / 2, r.folder), r.x < 0 and math.pi or 0, r.folder)
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
	-- Rooftop life: a helipad on the tower, string lights, neon edges,
	-- satellite dishes, planters; traffic glowing far below.
	do
		local c = R.center
		local pad = NP("Helipad", Vector3.new(0.12, 14, 14), CFrame.new(c.x, c.top + 0.03, c.z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(40, 42, 50), Enum.Material.Concrete, c.folder)
		pad.Shape = Enum.PartType.Cylinder
		pad.CanCollide = false
		local ring = NP("HeliRing", Vector3.new(0.1, 14.8, 14.8), CFrame.new(c.x, c.top + 0.02, c.z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 200, 80), Enum.Material.Neon, c.folder)
		ring.Shape = Enum.PartType.Cylinder
		ring.CanCollide = false
		for _, bar in ipairs({ { -2, 0, 0.9, 7 }, { 2, 0, 0.9, 7 }, { 0, 0, 4, 0.9 } }) do
			NP("HeliH", Vector3.new(bar[3], 0.06, bar[4]), CFrame.new(c.x + bar[1], c.top + 0.08, c.z + bar[2]), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, c.folder).CanCollide = false
		end
	end
	for _, r in pairs(R) do
		-- Neon trim along the parapet.
		local trim = NEON[rng:NextInteger(1, #NEON)]
		for _, e in ipairs({ { 0, r.sz / 2, r.sx, 0.2 }, { 0, -r.sz / 2, r.sx, 0.2 }, { r.sx / 2, 0, 0.2, r.sz }, { -r.sx / 2, 0, 0.2, r.sz } }) do
			NP("Parapet", Vector3.new(e[3], 0.12, e[4]), CFrame.new(r.x + e[1], r.top + 0.86, r.z + e[2]), trim, Enum.Material.Neon, r.folder).CanCollide = false
		end
		-- String lights corner to corner.
		local h = r.top + 4.5
		local corners = { Vector3.new(r.x - r.sx / 2 + 1, h, r.z - r.sz / 2 + 1), Vector3.new(r.x + r.sx / 2 - 1, h, r.z + r.sz / 2 - 1) }
		NP("Post", Vector3.new(0.25, 4.6, 0.25), CFrame.new(corners[1] - Vector3.new(0, 2.3, 0)), Color3.fromRGB(60, 60, 70), Enum.Material.Metal, r.folder).CanCollide = false
		NP("Post", Vector3.new(0.25, 4.6, 0.25), CFrame.new(corners[2] - Vector3.new(0, 2.3, 0)), Color3.fromRGB(60, 60, 70), Enum.Material.Metal, r.folder).CanCollide = false
		local nBulbs = 10
		for k = 0, nBulbs do
			local t = k / nBulbs
			local p = corners[1]:Lerp(corners[2], t) - Vector3.new(0, math.sin(t * math.pi) * 1.4, 0)
			local b = NP("Bulb", Vector3.one * 0.45, CFrame.new(p), Color3.fromRGB(255, 226, 150), Enum.Material.Neon, r.folder)
			b.Shape = Enum.PartType.Ball
			b.CanCollide = false
		end
		-- A satellite dish or a planter in a free corner.
		local spot = Vector3.new(r.x + r.sx / 2 - 2.5, r.top, r.z - r.sz / 2 + 2.5)
		if rng:NextNumber() < 0.5 then
			NP("Post", Vector3.new(0.4, 2, 0.4), CFrame.new(spot + Vector3.new(0, 1, 0)), Color3.fromRGB(170, 176, 186), Enum.Material.Metal, r.folder).CanCollide = false
			local dish = NP("Bulb", Vector3.new(0.4, 3, 3), CFrame.new(spot + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, math.rad(45), math.rad(55)), Color3.fromRGB(220, 224, 232), Enum.Material.Metal, r.folder)
			dish.Shape = Enum.PartType.Cylinder
			dish.CanCollide = false
		else
			NP("Crate", Vector3.new(3, 1.2, 1.6), CFrame.new(spot + Vector3.new(0, 0.6, 0)), Color3.fromRGB(110, 80, 60), Enum.Material.WoodPlanks, r.folder)
			for k = -1, 1 do
				local leaf = NP("Bush", Vector3.one * 1.3, CFrame.new(spot + Vector3.new(k * 0.9, 1.6, 0)), Color3.fromRGB(70, 150, 80), Enum.Material.Grass, r.folder)
				leaf.Shape = Enum.PartType.Ball
				leaf.CanCollide = false
			end
		end
	end
	-- Traffic streaming through the streets far below.
	for k = 1, 16 do
		local along = rng:NextNumber() < 0.5
		local off = rng:NextNumber(-150, 150)
		local len = rng:NextNumber(30, 80)
		local streak = NP("Window", along and Vector3.new(len, 0.6, 1.2) or Vector3.new(1.2, 0.6, len), CFrame.new(along and rng:NextNumber(-120, 120) or off, -58, along and off or rng:NextNumber(-120, 120)), k % 2 == 0 and Color3.fromRGB(255, 210, 120) or Color3.fromRGB(255, 80, 80), Enum.Material.Neon, arena)
		streak.CanCollide = false
		streak.Transparency = 0.3
	end

	-- Window-cleaner lifts from each step roof up to a high perch over the tower.
	for _, key in ipairs({ "stepBL", "stepBR", "stepRL", "stepRR" }) do
		local r = R[key]
		makeLift(r, r.x > 0 and 1 or -1, r.z > 0 and 1 or -1, r.folder)
	end
	-- Neon billboards on the flank roofs: they flicker, then surge.
	ArenaKit.AddBillboard(Vector3.new(R.flankL.x, R.flankL.top, 8), Vector3.zero, Color3.fromRGB(255, 90, 200), "MEOW COLA", R.flankL.folder)
	ArenaKit.AddBillboard(Vector3.new(R.flankR.x, R.flankR.top, -8), Vector3.zero, Color3.fromRGB(80, 220, 255), "FISH TV", R.flankR.folder)

	arena:SetAttribute("KillFloorY", -45)
	arena:SetAttribute("SpawnCount", #spawns:GetChildren())
	return arena
end

return Rooftops
