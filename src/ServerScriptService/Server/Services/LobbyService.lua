--!strict
-- LobbyService: the lobby everyone spawns into, an indoor hall shaped like a
-- plus sign (two long halls crossing), in the spirit of Rivals:
--   * middle (the hub): where everyone spawns, facing the duel hall
--   * straight ahead: the duel hall, rows of 1v1 / 2v2 pads with wall
--     screens (DuelService builds the pads)
--   * behind you: a portal to the Practice Centre, a floating platform of
--     target cats you can knock off the edge (and a portal back)
--   * left: the Armory, every blaster on a pedestal (F to equip)
--   * right: the Museum, featured looks, every rank tier and a gold cat statue
--   * between the right and the middle: the leaderboards
-- Walls and a glass roof keep you in; nobody can hurt anyone here.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local CatBuilder = require(Shared.Character.CatBuilder)
local BlasterBuilder = require(Shared.Character.BlasterBuilder)
local Knockback = require(Shared.Character.Knockback)
local Weapons = require(Shared.Config.Weapons)
local Ranks = require(Shared.Config.Ranks)

local PlayerService = require(script.Parent.PlayerService)
local WeaponService = require(script.Parent.WeaponService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local ArenaKit = require(script.Parent.Parent.World.ArenaKit)

local LobbyService = {}

local CENTER = Vector3.new(0, 150, 2600)
local SURFACE_Y = CENTER.Y + ArenaKit.SURFACE
local FALL_Y = CENTER.Y - 30
local HEIGHT = 26 -- walls up to the glass roof

-- The halls, as rectangles relative to CENTER: { x0, x1, z0, z1 }.
-- Spawn faces +Z, so the player's left is +X and their right is -X.
local HUB = { -28, 28, -28, 28 }
local DUEL_HALL = { -18, 18, 28, 112 }
local PORTAL_HALL = { -12, 12, -60, -28 }
local ARMORY = { 28, 96, -12, 12 }
local MUSEUM = { -96, -28, -12, 12 }
local HALLS = { HUB, DUEL_HALL, PORTAL_HALL, ARMORY, MUSEUM }
-- The outline of the whole plus shape, walked round in order.
local OUTLINE = {
	{ -18, 112 }, { 18, 112 }, { 18, 28 }, { 28, 28 }, { 28, 12 }, { 96, 12 }, { 96, -12 }, { 28, -12 },
	{ 28, -28 }, { 12, -28 }, { 12, -60 }, { -12, -60 }, { -12, -28 }, { -28, -28 }, { -28, -12 },
	{ -96, -12 }, { -96, 12 }, { -28, 12 }, { -28, 28 }, { -18, 28 },
}

-- The Practice Centre floats on its own, far behind the hall.
local PRACTICE = Vector3.new(CENTER.X, CENTER.Y, CENTER.Z - 420)

-- Duel pads (DuelService builds them): down both sides of the duel hall;
-- `wall` is the side wall their screen hangs on (+1 = left / +X).
LobbyService.DuelPads = {
	{ kind = "1v1", x = 10.5, z = 40, wall = 1 },
	{ kind = "1v1", x = -10.5, z = 40, wall = -1 },
	{ kind = "1v1", x = 10.5, z = 58, wall = 1 },
	{ kind = "1v1", x = -10.5, z = 58, wall = -1 },
	{ kind = "1v1", x = 10.5, z = 76, wall = 1 },
	{ kind = "1v1", x = -10.5, z = 76, wall = -1 },
	{ kind = "2v2", x = 10.5, z = 96, wall = 1 },
	{ kind = "2v2", x = -10.5, z = 96, wall = -1 },
}

-- Colours: a clean night-blue hall with cyan and purple light.
local FLOOR = Color3.fromRGB(30, 34, 52)
local FLOOR_LINE = Color3.fromRGB(44, 52, 80)
local WALL = Color3.fromRGB(22, 26, 42)
local PANEL = Color3.fromRGB(34, 40, 64)
local METAL = Color3.fromRGB(70, 76, 98)
local CYAN = Color3.fromRGB(60, 210, 255)
local PURPLE = Color3.fromRGB(170, 110, 255)
local GOLD = Color3.fromRGB(255, 200, 90)
local INK = Color3.fromRGB(16, 20, 34)
local GLASS = Color3.fromRGB(170, 215, 255)

local rng = Random.new(20261018)

-- ── building helpers ─────────────────────────────────────────────────────────
local function at(dx: number, dz: number, lift: number?): Vector3
	return Vector3.new(CENTER.X + dx, SURFACE_Y + (lift or 0), CENTER.Z + dz)
end
LobbyService.At = at

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return deco(ArenaKit.NewPart(name, size, cf, color, material, parent))
end

local function solid(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return ArenaKit.NewPart(name, size, cf, color, material, parent)
end

local function neon(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): BasePart
	local p = part(name, size, cf, color, Enum.Material.Neon, parent)
	p.CastShadow = false
	return p
end

local function ball(name: string, d: number, pos: Vector3, color: Color3, parent: Instance): BasePart
	local p = part(name, Vector3.one * d, CFrame.new(pos), color, Enum.Material.SmoothPlastic, parent)
	local shaped = p :: Part
	shaped.Shape = Enum.PartType.Ball
	p.CastShadow = false
	return p
end

local function disc(name: string, d: number, h: number, pos: Vector3, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return deco(ArenaKit.NewDisc(name, d, h, pos, color, material, parent))
end

-- Text on one face of a part, one label per line.
local function sign(parent: BasePart, face: Enum.NormalId, lines: { { text: string, size: number, color: Color3 } })
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.Parent = parent
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = gui
	for i, l in ipairs(lines) do
		local t = Instance.new("TextLabel")
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0, l.size * 1.25)
		t.Text = l.text
		t.TextSize = l.size
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = l.color
		t.Parent = gui
	end
	return gui
end

-- A dark board facing `toward`, with a glowing edge and (optional) text.
local function board(name: string, pos: Vector3, toward: Vector3, w: number, h: number, edge: Color3, lines: any, parent: Instance): BasePart
	local face = CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
	neon(name .. "Edge", Vector3.new(w + 0.6, h + 0.6, 0.2), face * CFrame.new(0, 0, 0.25), edge, parent)
	local b = part(name, Vector3.new(w, h, 0.4), face, INK, Enum.Material.SmoothPlastic, parent)
	if lines then
		sign(b, Enum.NormalId.Front, lines)
	end
	return b
end

-- A prompt that opens a screen on the client (Loadout, Shop...).
local function prompt(parent: BasePart, action: string, object: string, panel: string, weaponId: string?)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.MaxActivationDistance = 9
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.F -- E is pounce
	p:SetAttribute("OpenPanel", panel)
	if weaponId then
		p:SetAttribute("WeaponId", weaponId)
	end
	p.Parent = parent
end

local function inside(x: number, z: number): boolean
	for _, r in ipairs(HALLS) do
		if x > r[1] and x < r[2] and z > r[3] and z < r[4] then
			return true
		end
	end
	return false
end

-- ── the hall: floors, walls, glass roof ──────────────────────────────────────
local function buildShell(f: Instance)
	for i, r in ipairs(HALLS) do
		local w, d = r[2] - r[1], r[4] - r[3]
		local mid = at((r[1] + r[2]) / 2, (r[3] + r[4]) / 2)
		solid("Floor" .. i, Vector3.new(w + 0.2, 2, d + 0.2), CFrame.new(mid - Vector3.new(0, 1, 0)), FLOOR, Enum.Material.SmoothPlastic, f)
		-- Tile lines every 8 studs.
		for x = r[1] + 8, r[2] - 1, 8 do
			part("TileLine", Vector3.new(0.15, 0.05, d), CFrame.new(at(x, (r[3] + r[4]) / 2, 0.02)), FLOOR_LINE, Enum.Material.SmoothPlastic, f)
		end
		for z = r[3] + 8, r[4] - 1, 8 do
			part("TileLine", Vector3.new(w, 0.05, 0.15), CFrame.new(at((r[1] + r[2]) / 2, z, 0.02)), FLOOR_LINE, Enum.Material.SmoothPlastic, f)
		end
		-- Glass roof (solid, so nobody jumps out) with metal beams across it.
		local roof = solid("Roof" .. i, Vector3.new(w + 2, 1, d + 2), CFrame.new(mid + Vector3.new(0, HEIGHT + 0.5, 0)), GLASS, Enum.Material.Glass, f)
		roof.Transparency = 0.8
		roof.CastShadow = false
		roof.CanQuery = false
		local long = w >= d
		local span = long and w or d
		for k = 6, span - 6, 12 do
			local off = long and Vector3.new(r[1] + k - (r[1] + r[2]) / 2, 0, 0) or Vector3.new(0, 0, r[3] + k - (r[3] + r[4]) / 2)
			local beam = part("RoofBeam", long and Vector3.new(0.8, 0.8, d) or Vector3.new(w, 0.8, 0.8), CFrame.new(mid + off + Vector3.new(0, HEIGHT - 0.4, 0)), METAL, Enum.Material.Metal, f)
			beam.CastShadow = false
		end
	end

	-- Walls round the outline, each with glowing trim on the inside.
	for i, a in ipairs(OUTLINE) do
		local b = OUTLINE[i % #OUTLINE + 1]
		local pa, pb = Vector3.new(a[1], 0, a[2]), Vector3.new(b[1], 0, b[2])
		local len = (pb - pa).Magnitude
		local dir = (pb - pa).Unit
		local normal = Vector3.new(-dir.Z, 0, dir.X)
		local midXZ = (pa + pb) / 2
		if not inside(midXZ.X + normal.X * 2, midXZ.Z + normal.Z * 2) then
			normal = -normal -- point it into the hall
		end
		local base = at(midXZ.X, midXZ.Z)
		local centre = base + Vector3.new(0, HEIGHT / 2, 0) - normal
		solid("Wall", Vector3.new(2, HEIGHT, len + 2), CFrame.lookAt(centre, centre + dir), WALL, Enum.Material.SmoothPlastic, f)
		local face = base + normal * 0.05
		local along = CFrame.lookAt(face, face + dir)
		neon("FloorTrim", Vector3.new(0.2, 0.35, len), along * CFrame.new(0, 0.4, 0), CYAN, f)
		neon("TopTrim", Vector3.new(0.2, 0.35, len), along * CFrame.new(0, HEIGHT - 1.2, 0), PURPLE, f)
		part("Panel", Vector3.new(0.15, 10, math.max(len - 2, 1)), along * CFrame.new(0, 7, 0), PANEL, Enum.Material.SmoothPlastic, f)
		-- Upright light strips every 12 studs.
		for k = 6, len - 3, 12 do
			neon("LightStrip", Vector3.new(0.25, 9, 0.3), along * CFrame.new(0, 7, k - len / 2), CYAN:Lerp(PURPLE, rng:NextNumber()), f).Transparency = 0.15
		end
	end
	-- Soft light so the hall glows (the roof lets the sky in too).
	for _, p in ipairs({ { 0, 0 }, { 0, 50 }, { 0, 90 }, { 60, 0 }, { -60, 0 }, { 0, -45 } }) do
		local holder = part("Light", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at(p[1], p[2], HEIGHT - 3)), CYAN, Enum.Material.SmoothPlastic, f)
		holder.Transparency = 1
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(200, 225, 255)
		l.Range = 40
		l.Brightness = 0.8
		l.Shadows = false
		l.Parent = holder
	end

	-- A sign hanging over the way into each hall, readable from both sides.
	for _, s in ipairs({
		{ "DUELS", 0, 28, 30, CYAN },
		{ "PRACTICE", 0, -28, 20, PURPLE },
		{ "ARMORY", 28, 0, 20, Color3.fromRGB(120, 220, 255) },
		{ "MUSEUM", -28, 0, 20, GOLD },
	}) do
		local pos = at(s[2], s[3], 19)
		local face = CFrame.lookAt(pos, at(0, 0, 19))
		neon("SignEdge", Vector3.new(s[4] + 0.6, 4.6, 0.2), face, s[5], f)
		local b = part("HallSign", Vector3.new(s[4], 4, 0.6), face, INK, Enum.Material.SmoothPlastic, f)
		sign(b, Enum.NormalId.Front, { { text = s[1], size = 110, color = s[5] } })
		sign(b, Enum.NormalId.Back, { { text = s[1], size = 110, color = s[5] } })
		for _, x in ipairs({ -s[4] / 2 + 1, s[4] / 2 - 1 }) do
			part("SignCable", Vector3.new(0.15, HEIGHT - 21, 0.15), face * CFrame.new(x, (HEIGHT - 21) / 2 + 2, 0), METAL, Enum.Material.Metal, f)
		end
	end
end

-- ── the hub (spawn) ──────────────────────────────────────────────────────────
local function blossom(pos: Vector3, parent: Instance)
	part("Trunk", Vector3.new(0.8, 4.5, 0.8), CFrame.new(pos + Vector3.new(0, 2.25, 0)), Color3.fromRGB(104, 70, 46), Enum.Material.Wood, parent)
	local top = pos + Vector3.new(0, 5.4, 0)
	ball("Blossom", 5, top, Color3.fromRGB(255, 196, 214), parent)
	for k = 1, 4 do
		local a = k / 4 * math.pi * 2
		ball("Blossom", 3.4, top + Vector3.new(math.cos(a) * 2, rng:NextNumber(-0.6, 0.6), math.sin(a) * 2), k % 2 == 0 and Color3.fromRGB(252, 170, 196) or Color3.fromRGB(255, 222, 232), parent)
	end
end

local function planter(pos: Vector3, parent: Instance)
	solid("Planter", Vector3.new(7, 1.6, 7), CFrame.new(pos + Vector3.new(0, 0.8, 0)), PANEL, Enum.Material.SmoothPlastic, parent)
	neon("PlanterTrim", Vector3.new(7.2, 0.2, 7.2), CFrame.new(pos + Vector3.new(0, 1.65, 0)), CYAN, parent).Transparency = 0.3
	part("Soil", Vector3.new(6.4, 0.2, 6.4), CFrame.new(pos + Vector3.new(0, 1.62, 0)), Color3.fromRGB(70, 52, 40), Enum.Material.Ground, parent)
	blossom(pos + Vector3.new(0, 1.6, 0), parent)
end

local function buildHub(f: Instance)
	-- A big glowing paw print where you spawn.
	local pawAt = at(0, -6, 0.05)
	disc("PawPad", 9, 0.1, pawAt, CYAN, Enum.Material.Neon, f).Transparency = 0.55
	for _, t in ipairs({ { -4.6, 4.2 }, { -1.6, 6.2 }, { 1.6, 6.2 }, { 4.6, 4.2 } }) do
		disc("PawToe", 3.6, 0.1, pawAt + Vector3.new(t[1], 0, t[2]), CYAN, Enum.Material.Neon, f).Transparency = 0.55
	end
	disc("SpawnRing", 22, 0.08, at(0, -2, 0.03), PANEL, Enum.Material.SmoothPlastic, f)
	-- A screen box hanging over the middle: PAW MAYHEM on all four sides.
	local box = at(0, 0, 16)
	part("ScreenCable", Vector3.new(0.3, HEIGHT - 19, 0.3), CFrame.new(box + Vector3.new(0, (HEIGHT - 19) / 2 + 2.5, 0)), METAL, Enum.Material.Metal, f)
	local cube = part("ScreenBox", Vector3.new(14, 5, 14), CFrame.new(box), INK, Enum.Material.SmoothPlastic, f)
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
		sign(cube, face, { { text = "PAW MAYHEM", size = 110, color = Color3.new(1, 1, 1) }, { text = "PLAY  ·  DUEL  ·  PRACTICE", size = 36, color = CYAN } })
	end
	neon("ScreenTrimTop", Vector3.new(14.4, 0.3, 14.4), CFrame.new(box + Vector3.new(0, 2.6, 0)), PURPLE, f)
	neon("ScreenTrimBottom", Vector3.new(14.4, 0.3, 14.4), CFrame.new(box - Vector3.new(0, 2.6, 0)), CYAN, f)
	-- Blossom planters in three corners (the fourth has the leaderboards).
	for _, c in ipairs({ { 22, 22 }, { 22, -22 }, { -22, -22 } }) do
		planter(at(c[1], c[2]), f)
	end
end

-- ── leaderboards (between the right and the middle) ─────────────────────────
type Board = { metric: string, rows: { TextLabel } }
local boards: { Board } = {}

local function buildBoard(metric: string, title: string, pos: Vector3, toward: Vector3, w: number, h: number, parent: Instance)
	local b = board("LeaderBoard", pos, toward, w, h, GOLD, nil, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 30
	gui.Parent = b
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0.15, 0)
	head.Text = title
	head.Font = Enum.Font.FredokaOne
	head.TextScaled = true
	head.TextColor3 = GOLD
	head.Parent = gui
	local rows = {}
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0.06, 0, 0.17 + (i - 1) * 0.08, 0)
		row.Size = UDim2.new(0.88, 0, 0.072, 0)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i <= 3 and ({ GOLD, Color3.fromRGB(210, 220, 235), Color3.fromRGB(226, 150, 96) })[i] or Color3.new(1, 1, 1)
		row.Text = ""
		row.Parent = gui
		rows[i] = row
	end
	table.insert(boards, { metric = metric, rows = rows })
end

local function refreshBoards()
	for _, bd in ipairs(boards) do
		local ok, entries = pcall(LeaderboardService.Top, bd.metric)
		if ok and typeof(entries) == "table" then
			for i, row in ipairs(bd.rows) do
				local e = entries[i]
				row.Text = e and string.format("%d.  %s  ·  %d", i, tostring(e.name), math.floor(tonumber(e.value) or 0)) or ""
			end
		end
	end
end

local function buildBoards(f: Instance)
	-- On the hub's right wall by the duel hall, and the front wall beside it.
	buildBoard("Trophies", "TOP TROPHIES", at(-26.8, 20, 8.5), at(0, 20, 8.5), 13, 12, f)
	buildBoard("Wins", "MOST WINS", at(-23, 26.8, 8.5), at(-23, 0, 8.5), 8.5, 12, f)
end

-- ── duel hall dressing (the pads themselves are DuelService's) ──────────────
local function buildDuelHall(f: Instance)
	-- A glowing lane down the middle and a big screen on the far wall.
	neon("Lane", Vector3.new(0.5, 0.06, 82), CFrame.new(at(0, 70, 0.04)), CYAN, f).Transparency = 0.3
	for z = 36, 104, 8 do
		neon("LaneArrow", Vector3.new(2.2, 0.06, 0.5), CFrame.new(at(0, z, 0.05)), CYAN, f).Transparency = 0.45
	end
	board("DuelScreen", at(0, 110.8, 11), at(0, 0, 11), 26, 9, CYAN, {
		{ text = "DUELS", size = 150, color = Color3.new(1, 1, 1) },
		{ text = "Stand on a pad  ·  First to 5 knockouts  ·  Alone 15s = vs BOT", size = 40, color = CYAN },
	}, f)
end

-- ── the Practice Centre (through the portal) ────────────────────────────────
type Dummy = { model: Model, root: BasePart, stand: CFrame, fluff: number }
local dummies: { Dummy } = {}

local function practiceAt(dx: number, dz: number, lift: number?): Vector3
	return Vector3.new(PRACTICE.X + dx, SURFACE_Y + (lift or 0), PRACTICE.Z + dz)
end

local PRACTICE_ARRIVE = CFrame.lookAt(practiceAt(0, 10, 1.9), practiceAt(0, -10, 1.9))
local HUB_ARRIVE = CFrame.lookAt(at(0, -18, 1.9), at(0, 10, 1.9))

local function resetDummy(d: Dummy)
	d.fluff = 0
	d.model:SetAttribute("Fluff", 0)
	d.root.AssemblyLinearVelocity = Vector3.zero
	d.root.AssemblyAngularVelocity = Vector3.zero
	d.model:PivotTo(d.stand)
end

local function archeryTarget(pos: Vector3, faceTo: Vector3, parent: Instance)
	local face = CFrame.lookAt(pos + Vector3.new(0, 2.6, 0), Vector3.new(faceTo.X, pos.Y + 2.6, faceTo.Z))
	for _, x in ipairs({ -1, 1 }) do
		part("TargetLeg", Vector3.new(0.3, 3, 0.3), face * CFrame.new(x, -1.2, 0.4) * CFrame.Angles(math.rad(-12), 0, 0), METAL, Enum.Material.Metal, parent)
	end
	for i, ring in ipairs({ { 3.2, Color3.fromRGB(250, 246, 238) }, { 2.4, Color3.fromRGB(214, 70, 58) }, { 1.6, Color3.fromRGB(250, 246, 238) }, { 0.8, Color3.fromRGB(214, 70, 58) } }) do
		local p = part("TargetRing", Vector3.new(0.12, ring[1], ring[1]), face * CFrame.new(0, 0, -0.05 * i) * CFrame.Angles(0, math.rad(90), 0), ring[2], Enum.Material.SmoothPlastic, parent)
		local shaped = p :: Part
		shaped.Shape = Enum.PartType.Cylinder
	end
end

local function cloud(pos: Vector3, size: number, parent: Instance)
	for _ = 1, 4 do
		local s = size * rng:NextNumber(0.55, 1)
		ball("Cloud", s, pos + Vector3.new(rng:NextNumber(-1, 1) * size * 0.8, rng:NextNumber(-0.1, 0.3) * size, rng:NextNumber(-1, 1) * size * 0.8), Color3.new(1, 1, 1), parent).Transparency = 0.15
	end
end

-- A glowing ring you walk through. Returns the invisible trigger in it.
local function portal(center: Vector3, facing: Vector3, color: Color3, label: string, parent: Instance): BasePart
	local face = CFrame.lookAt(center, center + facing)
	local r = 6.5
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		local p = face * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0)
		neon("PortalRing", Vector3.new(1.8, 1.8, 1.2), CFrame.new(p.Position) * face.Rotation * CFrame.Angles(0, 0, a), color, parent)
	end
	local film = part("PortalFilm", Vector3.new(0.2, r * 2 - 1, r * 2 - 1), face * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Neon, parent)
	local filmShape = film :: Part
	filmShape.Shape = Enum.PartType.Cylinder
	film.Transparency = 0.55
	film.CastShadow = false
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	swirl.Size = NumberSequence.new(0.6, 0)
	swirl.Lifetime = NumberRange.new(0.8, 1.4)
	swirl.Rate = 30
	swirl.Speed = NumberRange.new(2, 4)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.LightEmission = 1
	swirl.Parent = film
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 18
	glow.Brightness = 1.5
	glow.Parent = film
	solid("PortalBase", Vector3.new(r * 2 + 3, 1, 3), face * CFrame.new(0, -r - 0.5, 0), PANEL, Enum.Material.SmoothPlastic, parent)
	board("PortalSign", center + Vector3.new(0, r + 2.2, 0) + facing * 0.5, center + facing * 10, 14, 2.6, color, {
		{ text = label, size = 64, color = Color3.new(1, 1, 1) },
	}, parent)
	local trigger = Instance.new("Part")
	trigger.Name = "PortalTrigger"
	trigger.Size = Vector3.new(r * 1.7, r * 1.7, 2)
	trigger.CFrame = face
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.Transparency = 1
	trigger.Parent = parent
	return trigger
end

-- Walking into a portal's trigger sends you to `dest`.
local lastPortal: { [Player]: number } = {}
local function linkPortal(trigger: BasePart, dest: CFrame)
	trigger.Touched:Connect(function(hit)
		local model = hit:FindFirstAncestorOfClass("Model")
		local player = model and Players:GetPlayerFromCharacter(model)
		if not player or player:GetAttribute("Context") ~= "Lobby" then
			return
		end
		if os.clock() - (lastPortal[player] or 0) < 1.5 then
			return
		end
		lastPortal[player] = os.clock()
		local char = player.Character
		local root = char and char.PrimaryPart
		if char and root then
			root.AssemblyLinearVelocity = Vector3.zero
			char:PivotTo(dest)
		end
	end)
end

local function buildPractice(lobby: Instance, hall: Instance)
	local p = Instance.new("Folder")
	p.Name = "PracticeCentre"
	p.Parent = lobby
	-- The platform: a dark floor with a glowing grid, rails on three sides,
	-- open at the far end so target cats can be knocked off it.
	local floorMid = practiceAt(0, -12)
	solid("PracticeFloor", Vector3.new(64, 2, 64), CFrame.new(floorMid - Vector3.new(0, 1, 0)), FLOOR, Enum.Material.SmoothPlastic, p)
	for x = -24, 24, 8 do
		neon("Grid", Vector3.new(0.12, 0.05, 64), CFrame.new(practiceAt(x, -12, 0.02)), PURPLE, p).Transparency = 0.6
	end
	for z = -40, 16, 8 do
		neon("Grid", Vector3.new(64, 0.05, 0.12), CFrame.new(practiceAt(0, z, 0.02)), PURPLE, p).Transparency = 0.6
	end
	part("Underside", Vector3.new(60, 8, 60), CFrame.new(floorMid - Vector3.new(0, 6, 0)), WALL, Enum.Material.SmoothPlastic, p)
	neon("Rim", Vector3.new(64.4, 0.4, 0.4), CFrame.new(practiceAt(0, -44, -0.2)), PURPLE, p)
	for _, side in ipairs({ { 32, -12, 0.4, 64 }, { -32, -12, 0.4, 64 }, { 0, 20, 64, 0.4 } }) do
		local rail = solid("Rail", Vector3.new(side[3], 3, side[4]), CFrame.new(practiceAt(side[1], side[2], 1.5)), GLASS, Enum.Material.Glass, p)
		rail.Transparency = 0.5
		local wall = solid("PracticeWall", Vector3.new(side[3], 40, side[4]), CFrame.new(practiceAt(side[1], side[2], 20)), GLASS, Enum.Material.Glass, p)
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CastShadow = false
	end
	board("PracticeTitle", practiceAt(0, 19.6, 18), practiceAt(0, 0, 18), 22, 4, PURPLE, {
		{ text = "PRACTICE CENTRE", size = 90, color = Color3.new(1, 1, 1) },
	}, p)

	-- Three target cats on glowing decks, archery targets behind them.
	for i, dx in ipairs({ -11, 0, 11 }) do
		local dz = i == 2 and -26 or -23
		local deck = practiceAt(dx, dz)
		disc("TargetDeck", 6.4, 0.2, deck + Vector3.new(0, 0.05, 0), PURPLE, Enum.Material.Neon, p).Transparency = 0.5
		disc("TargetDeckTop", 5.8, 0.3, deck + Vector3.new(0, 0.12, 0), PANEL, Enum.Material.SmoothPlastic, p)
		archeryTarget(practiceAt(dx, dz - 8), practiceAt(0, 10), p)
		local standCF = CFrame.lookAt(deck + Vector3.new(0, 1.9, 0), practiceAt(0, 10, 1.9))
		local model = CatBuilder.Build(nil, "TARGET", nil)
		model.Name = "TARGET"
		model:SetAttribute("IsDummy", true)
		model:SetAttribute("Team", "Dummy")
		model:SetAttribute("Fluff", 0)
		local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		hum.WalkSpeed, hum.JumpPower = 0, 0
		hum.MaxHealth, hum.Health = 1e9, 1e9
		model:PivotTo(standCF)
		model.Parent = p
		local root = model.PrimaryPart :: BasePart
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		table.insert(dummies, { model = model, root = root, stand = standCF, fluff = 0 })
	end
	for _ = 1, 14 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(60, 150)
		cloud(Vector3.new(PRACTICE.X + math.cos(a) * r, PRACTICE.Y + rng:NextNumber(-40, -12), PRACTICE.Z + math.sin(a) * r), rng:NextNumber(12, 22), p)
	end

	-- Portals: behind the hub to here, and back.
	linkPortal(portal(at(0, -54, 7.5), Vector3.new(0, 0, 1), PURPLE, "PRACTICE CENTRE", hall), PRACTICE_ARRIVE)
	linkPortal(portal(practiceAt(0, 16, 7.5), Vector3.new(0, 0, -1), CYAN, "BACK TO LOBBY", p), HUB_ARRIVE)
end

-- A player's shot hit a target cat: same knockback maths as a real hit.
local function hitDummy(shooter: Player, model: Model, weapon: any, dir: Vector3)
	for _, d in ipairs(dummies) do
		if d.model == model then
			d.fluff += weapon.Damage
			model:SetAttribute("Fluff", math.floor(d.fluff))
			local dV = Knockback.ComputeDeltaV(dir, d.fluff, weapon.Knockback, 1)
			if dV.Y > 2 then
				(model:FindFirstChildOfClass("Humanoid") :: Humanoid):ChangeState(Enum.HumanoidStateType.Freefall)
			end
			d.root:ApplyImpulse(dV * d.root.AssemblyMass)
			Remotes.Get("HitConfirm"):FireClient(shooter, {
				victim = "TARGET", damage = weapon.Damage, accumulated = d.fluff, position = d.root.Position,
			})
			return
		end
	end
end

-- ── the Armory (left) ────────────────────────────────────────────────────────
local function buildArmory(f: Instance)
	local a = Instance.new("Folder")
	a.Name = "Armory"
	a.Parent = f
	for i, w in ipairs(Weapons.List) do
		local side = i % 2 == 1 and 1 or -1 -- alternate walls
		local x = 38 + math.floor((i - 1) / 2) * 11
		local pos = at(x, side * 7.5)
		local toMiddle = Vector3.new(0, 0, -side)
		local pedestal = solid("Pedestal", Vector3.new(3.4, 3, 3.4), CFrame.new(pos + Vector3.new(0, 1.5, 0)), PANEL, Enum.Material.SmoothPlastic, a)
		neon("PedestalGlow", Vector3.new(3.6, 0.2, 3.6), CFrame.new(pos + Vector3.new(0, 3.05, 0)), w.TrailColor, a)
		local holo = part("Holo", Vector3.new(0.2, 3.2, 3.2), CFrame.new(pos + Vector3.new(0, 3.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), w.TrailColor, Enum.Material.Neon, a)
		local holoShape = holo :: Part
		holoShape.Shape = Enum.PartType.Cylinder
		holo.Transparency = 0.6
		-- Guns point along +X with their show side on +Z: turn that side to the walkway.
		local base = CFrame.fromMatrix(pos + Vector3.new(0, 4.6, 0), Vector3.yAxis:Cross(toMiddle), Vector3.yAxis, toMiddle)
		local gun = BlasterBuilder.Build(w.Id, nil, base * CFrame.Angles(0, 0, math.rad(8)), 0.75)
		for _, d in ipairs(gun:GetDescendants()) do
			if d:IsA("BasePart") then
				deco(d)
			end
		end
		gun.Parent = a
		local front = pos + Vector3.new(0, 1.6, 0) + toMiddle * 1.76
		local plaque = part("Plaque", Vector3.new(3, 1.1, 0.1), CFrame.lookAt(front, front + toMiddle), INK, Enum.Material.SmoothPlastic, a)
		sign(plaque, Enum.NormalId.Front, {
			{ text = string.upper(w.Name), size = 18, color = Color3.new(1, 1, 1) },
			{ text = string.upper(w.Rarity or w.Class), size = 12, color = w.TrailColor },
		})
		prompt(pedestal, "Equip", w.Name, "Loadout", w.Id)
	end
	board("ArmoryTitle", at(94.8, 0, 10), at(0, 0, 10), 18, 5, Color3.fromRGB(120, 220, 255), {
		{ text = "ARMORY", size = 120, color = Color3.new(1, 1, 1) },
		{ text = "Walk up to a blaster and press F to equip it", size = 34, color = Color3.fromRGB(120, 220, 255) },
	}, a)
end

-- ── the Museum (right) ───────────────────────────────────────────────────────
local FEATURED = {
	{ Fur = "Galaxy", Outfit = "Royal", Hat = "DiamondCrown" },
	{ Fur = "Sakura", Outfit = "Streetwear", Hat = "PartyHat" },
	{ Fur = "Midnight", Outfit = "Ninja", Hat = "Headphones", Accessory = "Sunglasses" },
	{ Fur = "RoyalGold", Outfit = "Space", Hat = "Halo", Accessory = "Jetpack" },
}

-- A cat you can look at but not touch (no name tag, no collisions).
local function displayCat(look: any, cf: CFrame, parent: Instance): Model
	local cat = CatBuilder.Build(look, "Display", nil)
	cat:SetAttribute("NoOverhead", true)
	for _, d in ipairs(cat:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.Anchored = true
		end
	end
	cat:PivotTo(cf)
	cat.Parent = parent
	return cat
end

local function buildMuseum(f: Instance)
	local m = Instance.new("Folder")
	m.Name = "Museum"
	m.Parent = f
	-- Featured looks along one wall (+Z side), facing the walkway.
	for i, look in ipairs(FEATURED) do
		local pos = at(-38 - (i - 1) * 13, 7.5)
		local stage = solid("Stage", Vector3.new(5, 1, 5), CFrame.new(pos + Vector3.new(0, 0.5, 0)), Color3.fromRGB(236, 232, 224), Enum.Material.Marble, m)
		neon("StageGlow", Vector3.new(5.4, 0.2, 5.4), CFrame.new(pos + Vector3.new(0, 0.1, 0)), GOLD, m).Transparency = 0.3
		displayCat(look, CFrame.lookAt(pos + Vector3.new(0, 2.9, 0), pos + Vector3.new(0, 2.9, -10)), m)
		prompt(stage, "Shop", "Featured look", "Shop")
	end
	-- Every rank tier along the other wall: a glowing gem and what it takes.
	for i, tier in ipairs(Ranks.Tiers) do
		local pos = at(-36 - (i - 1) * 8, -7.5)
		solid("TierStand", Vector3.new(2.6, 3.2, 2.6), CFrame.new(pos + Vector3.new(0, 1.6, 0)), PANEL, Enum.Material.SmoothPlastic, m)
		local gem = part("TierGem", Vector3.new(1.6, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, 4.4, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0), tier.Color, Enum.Material.Neon, m)
		local light = Instance.new("PointLight")
		light.Color = tier.Color
		light.Range = 8
		light.Brightness = 1
		light.Parent = gem
		local front = pos + Vector3.new(0, 1.8, 1.36)
		local plaque = part("TierPlaque", Vector3.new(2.6, 1, 0.1), CFrame.lookAt(front, front + Vector3.new(0, 0, 1)), INK, Enum.Material.SmoothPlastic, m)
		sign(plaque, Enum.NormalId.Front, {
			{ text = string.upper(tier.Name), size = 18, color = tier.Color },
			{ text = tostring(tier.Min) .. " TROPHIES", size = 11, color = Color3.new(1, 1, 1) },
		})
	end
	-- A giant gold cat at the end of the hall, looking back down it.
	local plinth = at(-88, 0)
	solid("Plinth", Vector3.new(9, 2, 9), CFrame.new(plinth + Vector3.new(0, 1, 0)), Color3.fromRGB(236, 232, 224), Enum.Material.Marble, m)
	neon("PlinthGlow", Vector3.new(9.4, 0.25, 9.4), CFrame.new(plinth + Vector3.new(0, 2.05, 0)), GOLD, m)
	local ok, err = pcall(function()
		local statue = displayCat({ Fur = "RoyalGold", Outfit = "Royal", Hat = "Crown" }, CFrame.lookAt(plinth + Vector3.new(0, 4.9, 0), plinth + Vector3.new(10, 4.9, 0)), m)
		for _, d in ipairs(statue:GetDescendants()) do
			if d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
				d:Destroy()
			elseif d:IsA("MeshPart") then
				d.TextureID = ""
			end
		end
		for _, d in ipairs(statue:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Color = GOLD
				d.Material = Enum.Material.Foil
			end
		end
		statue:ScaleTo(3)
		-- Stand it on the plinth after scaling.
		local box, size = statue:GetBoundingBox()
		statue:PivotTo(statue:GetPivot() + Vector3.new(0, plinth.Y + 2 - (box.Position.Y - size.Y / 2), 0))
	end)
	if not ok then
		warn("[PAW MAYHEM] museum statue skipped: " .. tostring(err))
	end
	board("MuseumPlaque", at(-82.5, 0, 2.2), at(0, 0, 2.2), 4, 1.4, GOLD, {
		{ text = "PAW MAYHEM  ·  SEASON 1", size = 22, color = GOLD },
	}, m)
end

-- ── putting it together ──────────────────────────────────────────────────────
local function buildLobby()
	local f = Instance.new("Folder")
	f.Name = "Lobby"
	-- The intro cinematic and Mochi's lesson (client) stage themselves in the
	-- Practice Centre; "Range" is where the client lets you aim and shoot.
	f:SetAttribute("Center", CENTER)
	f:SetAttribute("Surface", SURFACE_Y)
	f:SetAttribute("Stage", practiceAt(0, -12))
	f:SetAttribute("Range", practiceAt(0, -12))
	f.Parent = Workspace
	local hall = Instance.new("Folder")
	hall.Name = "Hall"
	hall.Parent = f
	buildShell(hall)
	buildHub(hall)
	buildBoards(hall)
	buildDuelHall(hall)
	buildArmory(f)
	buildMuseum(f)
	buildPractice(f, hall)
end

-- ── players ──────────────────────────────────────────────────────────────────
local function spawnCFrame(): CFrame
	local p = at(rng:NextNumber(-4, 4), -8 + rng:NextNumber(-2, 2), 1.9)
	return CFrame.lookAt(p, p + Vector3.new(0, 0, 1)) -- facing the duel hall
end

-- Put a player (back) in the lobby.
function LobbyService.Spawn(player: Player)
	if not player.Parent then
		return
	end
	PlayerService.Spawn(player, { context = "Lobby", team = "Lobby", cframe = spawnCFrame() })
end

local function nearPractice(pos: Vector3): boolean
	return Vector3.new(pos.X - PRACTICE.X, 0, pos.Z - PRACTICE.Z).Magnitude < 150
end

function LobbyService.Start()
	buildLobby()
	WeaponService.OnDummyHit = hitDummy
	PlayerService.OnLobbyDeath = function(player)
		task.delay(1.5, function()
			if player:GetAttribute("Context") == "Lobby" then
				LobbyService.Spawn(player)
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastPortal[player] = nil
	end)
	task.spawn(function()
		while true do
			refreshBoards()
			task.wait(60)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		-- Target cats knocked off the Practice Centre come back fresh.
		for _, dm in ipairs(dummies) do
			if dm.root.Position.Y < FALL_Y or not nearPractice(dm.root.Position) then
				resetDummy(dm)
			end
		end
		-- Anyone who falls is put back where they were (practice or hub).
		for _, p in ipairs(Players:GetPlayers()) do
			local char = p:GetAttribute("Context") == "Lobby" and p.Character
			local root = char and char.PrimaryPart
			if char and root and root.Position.Y < FALL_Y then
				root.AssemblyLinearVelocity = Vector3.zero
				char:PivotTo(nearPractice(root.Position) and PRACTICE_ARRIVE or spawnCFrame())
			end
		end
	end)
end

return LobbyService
