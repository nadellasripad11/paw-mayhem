--!strict
-- LobbyService: the lobby everyone spawns into: one closed, connected steel
-- bunker (Rivals-style hub), dark plate floors and wall panels under a steel
-- roof with light panels. Signs and displays are the only things that glow.
--   * the middle: a round grated platform where everyone spawns, facing the
--     hall; featured blasters float over lit pedestals round it (F to equip),
--     with today's free gift and an arcade machine for codes
--   * ahead: the big DUELS sign over the Matchmaking hall you walk through -
--     rows of 1v1 / 2v2 pads down both sides with screens above them
--     (DuelService builds the pads); WIN STREAKS and DUELS LIVE boards
--     either side of the way in
--   * behind the spawn: the SHOOTING RANGE bay - a glass grid with targets
--     behind it; walk through to the range (the Practice Dimension), a
--     platform of target cats you can knock off the edge (and back)
--   * left: WEAPONS, every blaster racked on the back wall (F to equip)
--   * right: the MARKET, featured cats in glass cases, every rank tier and a
--     gold cat statue
--   * between the spawn and the Market: the all-time leaderboards
-- Every room opens straight off the main hall; nobody can hurt anyone here.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
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
local DataService = require(script.Parent.DataService)
local WeaponService = require(script.Parent.WeaponService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local ArenaKit = require(script.Parent.Parent.World.ArenaKit)

local LobbyService = {}

local CENTER = Vector3.new(0, 150, 2600)
local SURFACE_Y = CENTER.Y + ArenaKit.SURFACE
local FALL_Y = CENTER.Y - 30

-- Floors, as rectangles relative to CENTER: { x0, x1, z0, z1 }. Spawn faces
-- +Z, so the player's left is +X and their right is -X.
local PLAZA = { -44, 44, -40, 30 }
local GUNS_ROOM = { 44, 86, -18, 18 }
local COLLECTION_ROOM = { -86, -44, -18, 18 }
local MATCH_HALL = { -20, 20, 30, 112 }
local GATE = { -16, 16, -62, -40 } -- the portal alcove behind the spawn
local AREAS = { PLAZA, GUNS_ROOM, COLLECTION_ROOM, MATCH_HALL, GATE }
-- The outside wall of the whole building, walked round in order.
local OUTLINE = {
	{ -44, -40 }, { -16, -40 }, { -16, -62 }, { 16, -62 }, { 16, -40 }, { 44, -40 }, { 44, -18 }, { 86, -18 },
	{ 86, 18 }, { 44, 18 }, { 44, 30 }, { 20, 30 }, { 20, 112 }, { -20, 112 }, { -20, 30 },
	{ -44, 30 }, { -44, 18 }, { -86, 18 }, { -86, -18 }, { -44, -18 },
}
local HEIGHT = 22 -- walls up to the roof, everywhere
local HALL_WALL = 14 -- where the hall's screens and signs sit under

-- The Practice Dimension floats on its own, far away.
local PRACTICE = Vector3.new(CENTER.X, CENTER.Y, CENTER.Z - 420)

-- Duel pads (DuelService builds them) down both sides of the matchmaking
-- hall; `wall` is the side their screen hangs on (+1 = left / +X).
LobbyService.DuelPads = {}
for _, side in ipairs({ 1, -1 }) do
	for _, p in ipairs({ { "1v1", 42 }, { "1v1", 56 }, { "1v1", 70 }, { "2v2", 85 }, { "2v2", 100 } }) do
		table.insert(LobbyService.DuelPads, { kind = p[1], x = side * 11, z = p[2], wall = side, screenX = side * 18.75 })
	end
end

-- Colours: a dark steel bunker with blue, cyan and gold light.
local FLOOR_PLATE = Color3.fromRGB(62, 66, 76) -- steel floor plate
local SEAM = Color3.fromRGB(40, 43, 52)
local PANEL = Color3.fromRGB(72, 76, 88) -- wall panels
local STEEL_DARK = Color3.fromRGB(40, 42, 50)
local BEAM = Color3.fromRGB(30, 32, 40) -- steel girders
local CAUTION = Color3.fromRGB(255, 196, 40)
local NAVY = Color3.fromRGB(22, 28, 56)
local NAVY_LIGHT = Color3.fromRGB(36, 46, 86)
local HALL_FLOOR = Color3.fromRGB(38, 42, 60)
local BLUE = Color3.fromRGB(70, 165, 255)
local PURPLE = Color3.fromRGB(165, 105, 255)
local CYAN = Color3.fromRGB(90, 220, 255)
local GOLD = Color3.fromRGB(255, 200, 90)
local WOOD = Color3.fromRGB(122, 84, 56)
local METAL = Color3.fromRGB(60, 64, 82)
local INK = Color3.fromRGB(14, 18, 34)
local GLASS = Color3.fromRGB(190, 220, 255)
local WHITE = Color3.new(1, 1, 1)

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

-- A plain coloured part (no glow) for the few coloured details left.
local function neon(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): BasePart
	local p = part(name, size, cf, color, Enum.Material.SmoothPlastic, parent)
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

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
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
	-- Each line gets a share of the board's height by its size, and its text
	-- scales to fill that share (so it reads from across the room).
	local total = 0
	for _, l in ipairs(lines) do
		total += l.size
	end
	for i, l in ipairs(lines) do
		local t = Instance.new("TextLabel")
		t.LayoutOrder = i
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(0.9, 0, 0.82 * l.size / total, 0)
		t.Text = l.text
		t.TextScaled = true
		t.Font = Enum.Font.FredokaOne
		t.TextColor3 = l.color
		t.Parent = gui
	end
	return gui
end

-- A navy board facing `toward`, with a glowing edge and (optional) text.
local function board(name: string, pos: Vector3, toward: Vector3, w: number, h: number, edge: Color3, lines: any, parent: Instance): BasePart
	local face = CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
	part(name .. "Edge", Vector3.new(w + 0.5, h + 0.5, 0.2), face * CFrame.new(0, 0, 0.25), edge:Lerp(NAVY, 0.55), Enum.Material.SmoothPlastic, parent)
	local b = part(name, Vector3.new(w, h, 0.5), face, NAVY, Enum.Material.SmoothPlastic, parent)
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
	for _, r in ipairs(AREAS) do
		if x > r[1] and x < r[2] and z > r[3] and z < r[4] then
			return true
		end
	end
	return false
end

-- ── props ────────────────────────────────────────────────────────────────────
-- A lit sign: a dark backing, a bright tube round the edge and glowing
-- letters. Signs and displays are the only things in the lobby that glow.
local function neonSign(name: string, pos: Vector3, toward: Vector3, w: number, h: number, color: Color3, text: string, parent: Instance, tilt: number?): BasePart
	local face = CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z)) * CFrame.Angles(0, 0, math.rad(tilt or 0))
	local back = part(name, Vector3.new(w, h, 0.4), face, Color3.fromRGB(14, 16, 22), Enum.Material.SmoothPlastic, parent)
	local t = 0.2
	for _, e in ipairs({ { 0, h / 2 - t, w - t, t }, { 0, -h / 2 + t, w - t, t }, { w / 2 - t, 0, t, h - t }, { -w / 2 + t, 0, t, h - t } }) do
		part(name .. "Tube", Vector3.new(e[3], e[4], 0.14), face * CFrame.new(e[1], e[2], -0.26), color, Enum.Material.Neon, parent).CastShadow = false
	end
	local gui = sign(back, Enum.NormalId.Front, { { text = text, size = 100, color = color:Lerp(WHITE, 0.55) } })
	for _, l in ipairs(gui:GetChildren()) do
		if l:IsA("TextLabel") then
			l.TextStrokeColor3 = color
			l.TextStrokeTransparency = 0
		end
	end
	light(back, color, math.max(w, 12), 1.1)
	return back
end

-- Yellow and black caution stripes along the floor (`cf`'s X axis).
local function caution(name: string, cf: CFrame, length: number, width: number, parent: Instance)
	local n = math.max(2, math.floor(length / 1.2))
	local step = length / n
	for i = 0, n - 1 do
		part(name, Vector3.new(step, 0.05, width), cf * CFrame.new(-length / 2 + step * (i + 0.5), 0, 0), i % 2 == 0 and CAUTION or Color3.fromRGB(24, 24, 28), Enum.Material.SmoothPlastic, parent)
	end
end

-- Crates and a barrel stacked in a corner.
local function crates(pos: Vector3, parent: Instance)
	solid("Crate", Vector3.new(3, 3, 3), CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), WOOD, Enum.Material.WoodPlanks, parent)
	solid("Crate", Vector3.new(2.4, 2.4, 2.4), CFrame.new(pos + Vector3.new(0.3, 4.2, 0.2)) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), WOOD, Enum.Material.WoodPlanks, parent)
	local barrel = ArenaKit.NewPart("Barrel", Vector3.new(3.2, 2.2, 2.2), CFrame.new(pos + Vector3.new(3, 1.6, 0.5)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(46, 90, 150), Enum.Material.Metal, parent) :: Part
	barrel.Shape = Enum.PartType.Cylinder
end

-- A pedestal with a lit ring and a cone of light over it, and a name plate
-- on the side facing `toward`. Returns the pedestal and where to float
-- something over it.
local function holoPedestal(pos: Vector3, toward: Vector3, color: Color3, label: string, parent: Instance): (BasePart, Vector3)
	local base = ArenaKit.NewDisc("Pedestal", 4.4, 1.2, pos + Vector3.new(0, 0.6, 0), STEEL_DARK, Enum.Material.Metal, parent)
	disc("PedestalGlow", 3.9, 0.12, pos + Vector3.new(0, 1.24, 0), color, Enum.Material.Neon, parent).CastShadow = false
	disc("PedestalTop", 3.4, 0.14, pos + Vector3.new(0, 1.27, 0), Color3.fromRGB(24, 26, 32), Enum.Material.Metal, parent)
	local a0 = Instance.new("Attachment")
	a0.Parent = base
	a0.WorldPosition = pos + Vector3.new(0, 1.4, 0)
	local a1 = Instance.new("Attachment")
	a1.Parent = base
	a1.WorldPosition = pos + Vector3.new(0, 7.5, 0)
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.Width0, beam.Width1 = 3.4, 1.4
	beam.Color = ColorSequence.new(color)
	beam.Transparency = NumberSequence.new(0.6, 1)
	beam.LightEmission = 1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Parent = base
	light(base, color, 10, 1)
	local front = CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
	local plate = part("PedestalPlate", Vector3.new(3, 0.7, 0.1), front * CFrame.new(0, 0.6, -2.25), INK, Enum.Material.SmoothPlastic, parent)
	sign(plate, Enum.NormalId.Front, { { text = label, size = 30, color = color:Lerp(WHITE, 0.4) } })
	return base, pos + Vector3.new(0, 4.4, 0)
end

-- Displays that turn slowly and bob (each client spins them: LobbyLook).
local function spinning(m: Model)
	m:SetAttribute("SpinPivot", m:GetPivot())
	CollectionService:AddTag(m, "LobbySpin")
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

-- A shopkeeper cat with a speech bubble that opens a screen when you talk to it.
local function shopkeeper(look: any, pos: Vector3, toward: Vector3, line: string, panel: string, parent: Instance)
	local cat = displayCat(look, CFrame.lookAt(pos + Vector3.new(0, 1.9, 0), Vector3.new(toward.X, pos.Y + 1.9, toward.Z)), parent)
	local root = cat.PrimaryPart
	if not root then
		return
	end
	local bubble = Instance.new("BillboardGui")
	bubble.Size = UDim2.fromOffset(150, 46)
	bubble.StudsOffset = Vector3.new(0, 4.2, 0)
	bubble.MaxDistance = 28
	bubble.Parent = root
	local frame = Instance.new("TextLabel")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = NAVY
	frame.BackgroundTransparency = 0.1
	frame.TextColor3 = WHITE
	frame.Font = Enum.Font.GothamBold
	frame.TextScaled = true
	frame.Text = line
	frame.Parent = bubble
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = WHITE
	stroke.Transparency = 0.5
	stroke.Thickness = 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = frame
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = frame
	prompt(root, "Talk", line, panel)
end

-- ── the ground: steel plate floors, the steel roof, the rock underneath ─────
local function buildGround(f: Instance)
	for i, r in ipairs(AREAS) do
		local w, d = r[2] - r[1], r[4] - r[3]
		local mid = at((r[1] + r[2]) / 2, (r[3] + r[4]) / 2)
		local hall = r == MATCH_HALL
		local room = r == GUNS_ROOM or r == COLLECTION_ROOM
		solid("Floor" .. i, Vector3.new(w + 0.2, 2, d + 0.2), CFrame.new(mid - Vector3.new(0, 1, 0)), hall and HALL_FLOOR or room and Color3.fromRGB(54, 57, 66) or FLOOR_PLATE,
			hall and Enum.Material.SmoothPlastic or room and Enum.Material.Concrete or Enum.Material.DiamondPlate, f)
		-- A steel roof on girders (it casts no shadow, so the daylight still
		-- lights the inside).
		local roof = solid("Roof" .. i, Vector3.new(w + 2, 1, d + 2), CFrame.new(mid + Vector3.new(0, HEIGHT + 0.5, 0)), Color3.fromRGB(26, 28, 34), Enum.Material.Metal, f)
		roof.CastShadow = false
		roof.CanQuery = false
		local long = w >= d
		local span = long and w or d
		for k = 4, span - 4, 8 do
			local off = long and Vector3.new(r[1] + k - (r[1] + r[2]) / 2, 0, 0) or Vector3.new(0, 0, r[3] + k - (r[3] + r[4]) / 2)
			part("RoofBeam", long and Vector3.new(1.4, 1.6, d) or Vector3.new(w, 1.6, 1.4), CFrame.new(mid + off + Vector3.new(0, HEIGHT - 0.8, 0)), BEAM, Enum.Material.Metal, f).CastShadow = false
		end
		-- Light panels in the ceiling.
		for x = r[1] + 11, r[2] - 5, 22 do
			for z = r[3] + 11, r[4] - 5, 22 do
				local lp = part("LightPanel", Vector3.new(6, 0.3, 2), CFrame.new(at(x, z, HEIGHT - 1.8)), Color3.fromRGB(214, 222, 236), Enum.Material.Neon, f)
				lp.CastShadow = false
				local sl = Instance.new("SurfaceLight")
				sl.Face = Enum.NormalId.Bottom
				sl.Range = 40
				sl.Brightness = 1.2
				sl.Angle = 110
				sl.Color = Color3.fromRGB(230, 236, 255)
				sl.Shadows = false
				sl.Parent = lp
			end
		end
		if not hall and not room then
			-- Plate seams.
			for x = r[1] + 6, r[2] - 1, 6 do
				part("Grout", Vector3.new(0.12, 0.04, d), CFrame.new(at(x, (r[3] + r[4]) / 2, 0.02)), SEAM, Enum.Material.SmoothPlastic, f)
			end
			for z = r[3] + 6, r[4] - 1, 6 do
				part("Grout", Vector3.new(w, 0.04, 0.12), CFrame.new(at((r[1] + r[2]) / 2, z, 0.02)), SEAM, Enum.Material.SmoothPlastic, f)
			end
		end
		-- Rock underneath, tapering away.
		part("Foundation", Vector3.new(w + 4, 6, d + 4), CFrame.new(mid - Vector3.new(0, 5, 0)), STEEL_DARK, Enum.Material.Rock, f)
		part("Taper", Vector3.new(w * 0.75, 10, d * 0.75), CFrame.new(mid - Vector3.new(0, 13, 0)), STEEL_DARK:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Rock, f)
		part("Taper", Vector3.new(w * 0.45, 12, d * 0.45), CFrame.new(mid - Vector3.new(0, 24, 0)), STEEL_DARK:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Rock, f)
	end

	-- Walls all the way round: steel panels along the plaza and rooms, navy
	-- along the matchmaking hall; a rail, a cap and girder pillars inside.
	for i, a in ipairs(OUTLINE) do
		local b = OUTLINE[i % #OUTLINE + 1]
		local pa, pb = Vector3.new(a[1], 0, a[2]), Vector3.new(b[1], 0, b[2])
		local len = (pb - pa).Magnitude
		local dir = (pb - pa).Unit
		local normal = Vector3.new(-dir.Z, 0, dir.X)
		local midXZ = (pa + pb) / 2
		if not inside(midXZ.X + normal.X * 2, midXZ.Z + normal.Z * 2) then
			normal = -normal -- into the building
		end
		local base = at(midXZ.X, midXZ.Z)
		local navy = math.min(a[2], b[2]) >= 30 and not (a[2] == 30 and b[2] == 30)
		local c = base + Vector3.new(0, HEIGHT / 2, 0) - normal
		solid("Wall", Vector3.new(2, HEIGHT, len + 2), CFrame.lookAt(c, c + dir), navy and NAVY or PANEL, navy and Enum.Material.SmoothPlastic or Enum.Material.Metal, f)
		local face = base + normal * 0.02
		local along = CFrame.lookAt(face, face + dir)
		part("WallBase", Vector3.new(0.2, 2.4, len), along * CFrame.new(0, 1.2, 0), navy and PANEL or STEEL_DARK, Enum.Material.Metal, f)
		if not navy then
			-- A rail along the wall and girder pillars every 16 studs.
			part("WallRail", Vector3.new(0.4, 0.6, len), along * CFrame.new(0, 4.2, 0), BEAM, Enum.Material.Metal, f)
			part("WallCap", Vector3.new(0.6, 1, len), along * CFrame.new(0, HEIGHT - 2, 0), BEAM, Enum.Material.Metal, f)
			for k = 8, len - 4, 16 do
				local at2 = face + normal * 0.6 - dir * (k - len / 2) + Vector3.new(0, (HEIGHT - 2.4) / 2 + 2.4, 0)
				part("Pillar", Vector3.new(1.4, HEIGHT - 2.4, 2.2), CFrame.lookAt(at2, at2 + dir), STEEL_DARK, Enum.Material.Metal, f)
			end
		end
	end
	-- Over each way through from the main hall: a wall above the opening with
	-- its lit sign (WEAPONS and the MARKET; the matchmaking arch has its own),
	-- caution stripes across the floor.
	for _, h in ipairs({ { 44, -1, "WEAPONS", BLUE }, { -44, 1, "MARKET", GOLD } }) do
		local x, side = h[1], h[2]
		solid("Header", Vector3.new(2, HEIGHT - 14, 36), CFrame.new(at(x, 0, 14 + (HEIGHT - 14) / 2)), PANEL, Enum.Material.Metal, f)
		neonSign(h[3] .. "Sign", at(x + side * 1.3, 0, 17.6), at(0, 0, 17.6), 22, 4.6, h[4], h[3], f)
		caution("DoorStripe", CFrame.new(at(x, 0, 0.03)) * CFrame.Angles(0, math.rad(90), 0), 34, 1, f)
		for _, z in ipairs({ -18.5, 18.5 }) do
			solid("OpeningPillar", Vector3.new(3, HEIGHT, 3), CFrame.new(at(x, z, HEIGHT / 2)), PANEL, Enum.Material.Metal, f)
		end
	end
	for _, p in ipairs({ { 0, 0 }, { -24, -24 }, { 24, -24 }, { -24, 18 }, { 24, 18 }, { 65, 0 }, { -65, 0 } }) do
		local holder = part("CeilingLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at(p[1], p[2], HEIGHT - 3)), WHITE, Enum.Material.SmoothPlastic, f)
		holder.Transparency = 1
		light(holder, Color3.fromRGB(235, 240, 255), 36, 0.7)
	end

end

-- ── the middle: spawn ────────────────────────────────────────────────────────
local function buildSpawn(f: Instance)
	-- A round raised steel platform: grates between radial ribs (every fourth
	-- one lit), a thin lit ring round the edge and our paw on the hub.
	local c = at(0, 0)
	ArenaKit.NewDisc("SpawnPlatform", 30, 0.5, c + Vector3.new(0, 0.25, 0), Color3.fromRGB(44, 47, 56), Enum.Material.DiamondPlate, f)
	disc("SpawnRim", 31.2, 0.3, c + Vector3.new(0, 0.15, 0), BEAM, Enum.Material.Metal, f)
	disc("SpawnGlow", 29.2, 0.06, c + Vector3.new(0, 0.53, 0), BLUE, Enum.Material.Neon, f).CastShadow = false
	disc("SpawnGrate", 28.2, 0.08, c + Vector3.new(0, 0.55, 0), Color3.fromRGB(30, 32, 38), Enum.Material.Metal, f)
	local rib = Color3.fromRGB(78, 82, 96)
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local mid = c + dir * 8.75 + Vector3.new(0, 0.6, 0)
		local lit = k % 4 == 0
		part("SpawnRib", Vector3.new(lit and 0.25 or 0.4, 0.06, 10.5), CFrame.lookAt(mid, mid + dir), lit and BLUE or rib, lit and Enum.Material.Neon or Enum.Material.Metal, f).CastShadow = false
	end
	for _, r in ipairs({ 7.5, 11 }) do
		local n = math.floor(r * 2 * math.pi / 1.6)
		for k = 0, n - 1 do
			local a = (k + 0.5) / n * math.pi * 2
			local p = c + Vector3.new(math.cos(a) * r, 0.6, math.sin(a) * r)
			part("SpawnRing", Vector3.new(0.3, 0.05, 2 * math.pi * r / n + 0.05), CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))), rib, Enum.Material.Metal, f).CastShadow = false
		end
	end
	disc("SpawnHub", 7, 0.12, c + Vector3.new(0, 0.6, 0), Color3.fromRGB(70, 74, 88), Enum.Material.Metal, f)
	local paw = c + Vector3.new(0, 0.68, -0.4)
	local pale = Color3.fromRGB(236, 240, 248)
	disc("Paw", 2.6, 0.06, paw, pale, Enum.Material.SmoothPlastic, f)
	for _, t in ipairs({ { -1.3, 1.3 }, { -0.45, 1.9 }, { 0.45, 1.9 }, { 1.3, 1.3 } }) do
		disc("PawToe", 1, 0.06, paw + Vector3.new(t[1], 0, t[2]), pale, Enum.Material.SmoothPlastic, f)
	end
	-- Crates and barrels in the corners.
	for _, p in ipairs({ { 39, -35 }, { -39, -35 }, { 25, -37 }, { -25, -37 } }) do
		crates(at(p[1], p[2]), f)
	end
end

-- ── round the spawn: floating displays ──────────────────────────────────────
local SHOWCASE = { "Starfall", "VoidCannon", "GoldenPurr" }

local function buildDisplays(f: Instance)
	local spawnAt = at(0, 0)
	local byId = {}
	for _, w in ipairs(Weapons.List) do
		byId[w.Id] = w
	end
	-- Featured blasters floating over lit pedestals, between the spawn and
	-- WEAPONS (F to equip).
	for i, spot in ipairs({ { 22, -12 }, { 25, -1 }, { 22, 10 } }) do
		local w = byId[SHOWCASE[i]]
		if w then
			local pos = at(spot[1], spot[2])
			local base, top = holoPedestal(pos, spawnAt, w.TrailColor, string.upper(w.Name), f)
			local toFront = ((spawnAt - pos) * Vector3.new(1, 0, 1)).Unit
			local gun = BlasterBuilder.Build(w.Id, nil, CFrame.fromMatrix(top, Vector3.yAxis:Cross(toFront), Vector3.yAxis, toFront), 1.4)
			for _, d in ipairs(gun:GetDescendants()) do
				if d:IsA("BasePart") then
					deco(d)
				end
			end
			gun.Parent = f
			spinning(gun)
			prompt(base, "Equip", w.Name, "Loadout", w.Id)
		end
	end

	-- Today's free gift: a present turning over a gold pedestal (opens the Shop).
	local giftBase, giftTop = holoPedestal(at(-19, 12), spawnAt, GOLD, "FREE GIFT", f)
	local gift = Instance.new("Model")
	gift.Name = "Gift"
	local box = part("GiftBox", Vector3.new(2.4, 2.4, 2.4), CFrame.new(giftTop), Color3.fromRGB(226, 60, 80), Enum.Material.SmoothPlastic, gift)
	part("GiftRibbon", Vector3.new(2.5, 2.5, 0.5), CFrame.new(giftTop), GOLD, Enum.Material.SmoothPlastic, gift)
	part("GiftRibbon", Vector3.new(0.5, 2.5, 2.5), CFrame.new(giftTop), GOLD, Enum.Material.SmoothPlastic, gift)
	for _, s in ipairs({ -1, 1 }) do
		ball("GiftBow", 1, giftTop + Vector3.new(s * 0.45, 1.5, 0), GOLD, gift)
	end
	gift.PrimaryPart = box
	gift.Parent = f
	spinning(gift)
	prompt(giftBase, "Open", "Free daily gift", "Shop")

	-- An arcade cabinet: its screen takes reward codes (opens Settings).
	local spot = at(-25, 1)
	local face = CFrame.lookAt(spot, Vector3.new(spawnAt.X, spot.Y, spawnAt.Z))
	local pink = Color3.fromRGB(255, 90, 200)
	local cab = solid("ArcadeCabinet", Vector3.new(3.4, 6.4, 2.8), face * CFrame.new(0, 3.2, 0.3), Color3.fromRGB(52, 30, 92), Enum.Material.SmoothPlastic, f)
	part("ArcadeDeck", Vector3.new(3.4, 0.5, 1.4), face * CFrame.new(0, 3.3, -1.5) * CFrame.Angles(math.rad(12), 0, 0), Color3.fromRGB(30, 18, 56), Enum.Material.SmoothPlastic, f)
	part("Joystick", Vector3.new(0.2, 0.6, 0.2), face * CFrame.new(-0.9, 3.8, -1.5), INK, Enum.Material.SmoothPlastic, f)
	ball("JoystickTop", 0.5, (face * CFrame.new(-0.9, 4.15, -1.5)).Position, Color3.fromRGB(230, 60, 70), f)
	for i, col in ipairs({ Color3.fromRGB(80, 200, 255), Color3.fromRGB(255, 210, 70), Color3.fromRGB(120, 230, 120) }) do
		disc("ArcadeButton", 0.42, 0.12, (face * CFrame.new(0.1 + (i - 1) * 0.55, 3.62, -1.5)).Position, col, Enum.Material.Neon, f).CastShadow = false
	end
	local screen = part("ArcadeScreen", Vector3.new(2.8, 2.2, 0.1), face * CFrame.new(0, 4.7, -1.13) * CFrame.Angles(math.rad(-8), 0, 0), Color3.fromRGB(10, 12, 20), Enum.Material.SmoothPlastic, f)
	sign(screen, Enum.NormalId.Front, {
		{ text = "PAW ARCADE", size = 34, color = Color3.fromRGB(120, 220, 255) },
		{ text = "ENTER A CODE", size = 22, color = Color3.fromRGB(255, 220, 120) },
	})
	light(screen, Color3.fromRGB(120, 200, 255), 10, 0.8)
	neonSign("ArcadeMarquee", (face * CFrame.new(0, 6.0, -1.25)).Position, spawnAt, 3.4, 0.9, pink, "ARCADE", f)
	for _, s in ipairs({ -1, 1 }) do
		part("ArcadeEdge", Vector3.new(0.12, 6.2, 0.12), face * CFrame.new(s * 1.72, 3.2, -1.12), pink, Enum.Material.Neon, f).CastShadow = false
	end
	prompt(cab, "Redeem", "Codes", "Settings")
end

-- ── ahead: the matchmaking hall (walk-through) and the practice gate ────────
local function buildMatchHall(f: Instance)
	-- The entrance arch: stone pillars, a beam and the big sign.
	for _, x in ipairs({ -22, 22 }) do
		solid("ArchPillar", Vector3.new(4, HEIGHT, 4), CFrame.new(at(x, 30, HEIGHT / 2)), PANEL, Enum.Material.Metal, f)
	end
	solid("ArchHeader", Vector3.new(40, HEIGHT - 14, 2), CFrame.new(at(0, 30, 14 + (HEIGHT - 14) / 2)), NAVY, Enum.Material.SmoothPlastic, f)
	-- The big DUELS sign over the way in, bolted up slightly crooked.
	neonSign("DuelsSign", at(0, 28.3, 17.6), at(0, 0, 17.6), 22, 6, BLUE, "DUELS", f, -4)
	neonSign("LobbySign", at(0, 31.4, 17.6), at(0, 60, 17.6), 16, 4, CYAN, "LOBBY", f)
	-- Painted arrows on the floor from the spawn to the arch.
	for _, z in ipairs({ 18, 22.5, 27 }) do
		for _, s in ipairs({ -1, 1 }) do
			part("FloorArrow", Vector3.new(0.6, 0.05, 3), CFrame.new(at(s * 0.96, z - 1.15, 0.03)) * CFrame.Angles(0, math.rad(-s * 40), 0), BLUE, Enum.Material.SmoothPlastic, f)
		end
	end

	-- The walkway: a darker lane with glowing arrows, purple and gold edges.
	part("Walkway", Vector3.new(10, 0.06, 82), CFrame.new(at(0, 71, 0.03)), Color3.fromRGB(26, 28, 40), Enum.Material.SmoothPlastic, f)
	-- Mode signs above each block of pads.
	for _, s in ipairs({ { "1V1", 56, BLUE }, { "2V2", 92.5, PURPLE } }) do
		for _, side in ipairs({ 1, -1 }) do
			board("ModeSign", at(side * 18.6, s[2], 12), at(0, s[2], 12), 8, 2.2, s[3], {
				{ text = s[1], size = 70, color = WHITE },
			}, f)
		end
	end
	-- An open roof of beams with light strips under them.
	for z = 34, 110, 8 do
		part("RoofBeam", Vector3.new(41, 1, 1.2), CFrame.new(at(0, z, HALL_WALL + 0.8)), BEAM, Enum.Material.Metal, f).CastShadow = false
	end
	for _, x in ipairs({ -12, 12 }) do
		part("RoofRail", Vector3.new(0.8, 0.8, 80), CFrame.new(at(x, 72, HALL_WALL + 1.6)), METAL, Enum.Material.Metal, f).CastShadow = false
	end
	for z = 40, 104, 16 do
		local holder = part("HallLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at(0, z, HALL_WALL - 1)), WHITE, Enum.Material.SmoothPlastic, f)
		holder.Transparency = 1
		light(holder, Color3.fromRGB(190, 210, 255), 26, 0.9)
	end

	-- The far end of the hall: a big screen.
	board("DuelScreen", at(0, 110.8, 10), at(0, 0, 10), 26, 8, BLUE, {
		{ text = "DUELS", size = 140, color = WHITE },
		{ text = "Stand on a pad  ·  First to 5  ·  Alone 15s = vs BOT", size = 40, color = CYAN },
	}, f)
end

-- ── behind the spawn: the SHOOTING RANGE bay ────────────────────────────────
-- A steel bay door with caution stripes and a rolled-up shutter, a glass grid
-- with targets behind it, LIVE FIRE signs either side. Walking through the
-- glass takes you to the range (the Practice Dimension).
local rangeDoor: BasePart? = nil

local function buildGate(f: Instance)
	solid("GateHeader", Vector3.new(32, HEIGHT - 14, 2), CFrame.new(at(0, -40, 14 + (HEIGHT - 14) / 2)), PANEL, Enum.Material.Metal, f)
	neonSign("RangeSign", at(0, -38.7, 17.6), at(0, 0, 17.6), 24, 4.6, CYAN, "SHOOTING RANGE", f)
	caution("GateStripe", CFrame.new(at(0, -41, 0.03)), 32, 1, f)
	local z = -54
	for _, s in ipairs({ -1, 1 }) do
		solid("BayWall", Vector3.new(8, HEIGHT, 1), CFrame.new(at(s * 12, z, HEIGHT / 2)), PANEL, Enum.Material.Metal, f)
		solid("BayPost", Vector3.new(1, 13, 1.4), CFrame.new(at(s * 7.5, z, 6.5)), STEEL_DARK, Enum.Material.Metal, f)
		for k = 0, 9 do
			part("PostStripe", Vector3.new(1.05, 0.65, 1.45), CFrame.new(at(s * 7.5, z, 0.65 + k * 1.3)), CAUTION, Enum.Material.SmoothPlastic, f)
		end
		-- LIVE FIRE signs on the alcove walls.
		local p = at(s * 15.8, -47, 7)
		local face = CFrame.lookAt(p, Vector3.new(CENTER.X, p.Y, p.Z))
		part("CautionSign", Vector3.new(2.6, 2.6, 0.12), face * CFrame.Angles(0, 0, math.rad(45)), CAUTION, Enum.Material.SmoothPlastic, f)
		local mark = part("CautionMark", Vector3.new(2.4, 2.4, 0.05), face * CFrame.new(0, 0, -0.08), CAUTION, Enum.Material.SmoothPlastic, f)
		mark.Transparency = 1
		sign(mark, Enum.NormalId.Front, { { text = "!", size = 60, color = INK } })
		local plate = part("CautionPlate", Vector3.new(4.4, 1.3, 0.12), face * CFrame.new(0, -2.9, 0), CAUTION, Enum.Material.SmoothPlastic, f)
		sign(plate, Enum.NormalId.Front, { { text = "LIVE FIRE", size = 40, color = INK } })
	end
	solid("BayLintel", Vector3.new(16, 1.2, 1.4), CFrame.new(at(0, z, 13.6)), STEEL_DARK, Enum.Material.Metal, f)
	solid("Shutter", Vector3.new(15, 2.2, 2.4), CFrame.new(at(0, z + 0.3, 15.3)), Color3.fromRGB(96, 100, 112), Enum.Material.Metal, f)
	for k = 0, 4 do
		part("ShutterRib", Vector3.new(15.1, 0.12, 2.5), CFrame.new(at(0, z + 0.3, 14.4 + k * 0.45)), STEEL_DARK, Enum.Material.Metal, f)
	end
	solid("BayTop", Vector3.new(32, HEIGHT - 16.4, 1), CFrame.new(at(0, z, 16.4 + (HEIGHT - 16.4) / 2)), PANEL, Enum.Material.Metal, f)
	-- The glass grid in the doorway (you walk through it).
	local glass = part("BayGlass", Vector3.new(14, 13, 0.3), CFrame.new(at(0, z, 6.5)), Color3.fromRGB(150, 220, 255), Enum.Material.Glass, f)
	glass.Transparency = 0.7
	glass.CastShadow = false
	light(glass, CYAN, 16, 0.9)
	for _, x in ipairs({ -4.2, -1.4, 1.4, 4.2 }) do
		part("Mullion", Vector3.new(0.18, 13, 0.4), CFrame.new(at(x, z, 6.5)), STEEL_DARK, Enum.Material.Metal, f)
	end
	for _, y in ipairs({ 2.6, 5.2, 7.8, 10.4 }) do
		part("Mullion", Vector3.new(14, 0.18, 0.4), CFrame.new(at(0, z, y)), STEEL_DARK, Enum.Material.Metal, f)
	end
	-- Behind the glass: a lane with targets.
	part("RangeLane", Vector3.new(14, 0.05, 7.5), CFrame.new(at(0, -58.4, 0.03)), Color3.fromRGB(30, 32, 38), Enum.Material.SmoothPlastic, f)
	caution("LaneLine", CFrame.new(at(0, -55.2, 0.04)), 14, 0.5, f)
	for _, x in ipairs({ -4.5, 0, 4.5 }) do
		archeryTarget(at(x, -60), at(x, 0), f)
	end
	local lamp = part("RangeLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at(0, -58, 11)), WHITE, Enum.Material.SmoothPlastic, f)
	lamp.Transparency = 1
	light(lamp, Color3.fromRGB(235, 240, 255), 16, 1)
	local trigger = Instance.new("Part")
	trigger.Name = "RangeDoor"
	trigger.Size = Vector3.new(13, 12, 2)
	trigger.CFrame = CFrame.new(at(0, z, 6.5))
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CanQuery = false
	trigger.Transparency = 1
	trigger.Parent = f
	rangeDoor = trigger
end

-- ── left: WEAPONS ────────────────────────────────────────────────────────────
-- A side room off the main hall: a panel on the back wall, glowing trim and
-- lights (its walls, roof and sign are part of the building).
local function shopRoom(name: string, backX: number, openSide: number, glow: Color3, f: Instance): Folder
	local b = Instance.new("Folder")
	b.Name = name
	b.Parent = f
	part("BackPanel", Vector3.new(0.2, 11, 32), CFrame.new(at(backX + openSide * 0.12, 0, 7.5)), NAVY, Enum.Material.SmoothPlastic, b)
	local midX = backX + openSide * 21
	for _, z in ipairs({ -9, 9 }) do
		local holder = part("RoomLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at(midX, z, HEIGHT - 4)), WHITE, Enum.Material.SmoothPlastic, b)
		holder.Transparency = 1
		light(holder, Color3.fromRGB(255, 248, 236), 26, 0.8)
	end
	return b
end

local function buildGuns(f: Instance)
	local b = shopRoom("Guns", 86, -1, BLUE, f)
	-- Every blaster racked on the back wall, two rows, show side out.
	local toFront = Vector3.new(-1, 0, 0)
	for i, w in ipairs(Weapons.List) do
		local row = (i - 1) // 5
		local col = (i - 1) % 5
		local pos = at(84.6, -12 + col * 6, 3.6 + row * 4)
		local plate = part("RackPlate", Vector3.new(0.2, 3.2, 5.2), CFrame.new(pos + Vector3.new(0.2, 0, 0)), NAVY_LIGHT, Enum.Material.SmoothPlastic, b)
		local base = CFrame.fromMatrix(pos + toFront * 0.8, Vector3.yAxis:Cross(toFront), Vector3.yAxis, toFront)
		local gun = BlasterBuilder.Build(w.Id, nil, base, 0.7)
		for _, d in ipairs(gun:GetDescendants()) do
			if d:IsA("BasePart") then
				deco(d)
			end
		end
		gun.Parent = b
		local tag = part("GunTag", Vector3.new(0.1, 0.7, 3.2), CFrame.lookAt(pos + Vector3.new(0, -1.15, 0) + toFront * 0.1, pos + Vector3.new(0, -1.15, 0) + toFront), INK, Enum.Material.SmoothPlastic, b)
		sign(tag, Enum.NormalId.Front, { { text = string.upper(w.Name), size = 16, color = w.TrailColor } })
		prompt(plate, "Equip", w.Name, "Loadout", w.Id)
	end
	-- A counter, crates, and the shopkeeper.
	solid("Counter", Vector3.new(3, 3, 12), CFrame.new(at(70, 10, 1.5)), WOOD, Enum.Material.WoodPlanks, b)
	for _, c in ipairs({ { 80, -15 }, { 77, -15.2 }, { 80, 15 } }) do
		solid("Crate", Vector3.new(2.6, 2.6, 2.6), CFrame.new(at(c[1], c[2], 1.3)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), WOOD, Enum.Material.WoodPlanks, b)
	end
	shopkeeper({ Fur = "Black", Outfit = "Ninja", Hat = "Cap" }, at(48, -12), at(0, 0), "Check out new skins!", "Shop", b)
end

-- ── right: the MARKET ────────────────────────────────────────────────────────
local FEATURED = {
	{ Fur = "Galaxy", Outfit = "Royal", Hat = "DiamondCrown" },
	{ Fur = "Sakura", Outfit = "Streetwear", Hat = "PartyHat" },
	{ Fur = "Midnight", Outfit = "Ninja", Hat = "Headphones", Accessory = "Sunglasses" },
	{ Fur = "RoyalGold", Outfit = "Space", Hat = "Halo", Accessory = "Jetpack" },
}

local function glassCase(pos: Vector3, size: Vector3, glow: Color3, parent: Instance): BasePart
	local stand = solid("CaseStand", Vector3.new(size.X + 0.6, 1.2, size.Z + 0.6), CFrame.new(pos + Vector3.new(0, 0.6, 0)), NAVY, Enum.Material.SmoothPlastic, parent)
	local glass = solid("CaseGlass", size, CFrame.new(pos + Vector3.new(0, 1.2 + size.Y / 2, 0)), GLASS, Enum.Material.Glass, parent)
	glass.Transparency = 0.75
	glass.CastShadow = false
	glass.CanQuery = false
	part("CaseTop", Vector3.new(size.X + 0.4, 0.3, size.Z + 0.4), CFrame.new(pos + Vector3.new(0, 1.35 + size.Y, 0)), NAVY, Enum.Material.SmoothPlastic, parent)
	return stand
end

local function buildCollection(f: Instance)
	local b = shopRoom("Collection", -86, 1, PURPLE, f)
	-- Featured cats in glass cases along the back wall.
	for i, look in ipairs(FEATURED) do
		local pos = at(-81, -13.5 + (i - 1) * 9)
		local stand = glassCase(pos, Vector3.new(5, 6, 5), PURPLE, b)
		displayCat(look, CFrame.lookAt(pos + Vector3.new(0, 3.1, 0), pos + Vector3.new(10, 3.1, 0)), b)
		prompt(stand, "Shop", "Featured look", "Shop")
	end
	-- Every rank tier: a glowing gem in its own little case, along one side.
	for i, tier in ipairs(Ranks.Tiers) do
		local pos = at(-50 - (i - 1) * 4.2, 15)
		glassCase(pos, Vector3.new(2.6, 2.8, 2.6), tier.Color, b)
		part("TierGem", Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 2.6, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0), tier.Color, Enum.Material.Glass, b)
		local front = pos + Vector3.new(0, 0.6, -1.25)
		local plaque = part("TierPlaque", Vector3.new(2.8, 0.9, 0.1), CFrame.lookAt(front, front + Vector3.new(0, 0, -1)), INK, Enum.Material.SmoothPlastic, b)
		sign(plaque, Enum.NormalId.Front, {
			{ text = string.upper(tier.Name), size = 16, color = tier.Color },
			{ text = tostring(tier.Min) .. "+", size = 10, color = WHITE },
		})
	end
	-- A gold cat statue in the middle of the room.
	local plinth = at(-62, -4)
	solid("Plinth", Vector3.new(7, 2, 7), CFrame.new(plinth + Vector3.new(0, 1, 0)), Color3.fromRGB(236, 232, 224), Enum.Material.Marble, b)
	local ok, err = pcall(function()
		local statue = displayCat({ Fur = "RoyalGold", Outfit = "Royal", Hat = "Crown" }, CFrame.lookAt(plinth + Vector3.new(0, 4.9, 0), plinth + Vector3.new(10, 4.9, 0)), b)
		for _, d in ipairs(statue:GetDescendants()) do
			if d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then
				d:Destroy()
			elseif d:IsA("MeshPart") then
				d.TextureID = ""
			end
		end
		for _, d in ipairs(statue:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Color = Color3.fromRGB(198, 150, 56)
				d.Material = Enum.Material.Metal
			end
		end
		statue:ScaleTo(2.4)
		local box, size = statue:GetBoundingBox()
		statue:PivotTo(statue:GetPivot() + Vector3.new(0, plinth.Y + 2 - (box.Position.Y - size.Y / 2), 0))
	end)
	if not ok then
		warn("[PAW MAYHEM] collection statue skipped: " .. tostring(err))
	end
	shopkeeper({ Fur = "White", Outfit = "Royal", Hat = "Crown" }, at(-48, 12), at(0, 0), "Collect rare cats!", "Shop", b)
end

-- ── between spawn and the Market: the leaderboards ─────────────────────────
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
		row.TextColor3 = i <= 3 and ({ GOLD, Color3.fromRGB(210, 220, 235), Color3.fromRGB(226, 150, 96) })[i] or WHITE
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

-- Live boards: the win streaks of everyone in the server, and the duels being
-- played right now (DuelService hands over LobbyService.LiveDuels).
LobbyService.LiveDuels = nil :: (() -> { string })?
local liveRows: { [string]: { TextLabel } } = {}

local function liveBoard(key: string, title: string, pos: Vector3, toward: Vector3, color: Color3, parent: Instance)
	local face = CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
	local w, h = 13, 9
	part(key .. "BoardFrame", Vector3.new(w + 0.8, h + 0.8, 0.3), face * CFrame.new(0, 0, 0.3), STEEL_DARK, Enum.Material.Metal, parent)
	local b = part(key .. "Board", Vector3.new(w, h, 0.4), face, Color3.fromRGB(12, 14, 20), Enum.Material.SmoothPlastic, parent)
	part(key .. "BoardTube", Vector3.new(w - 0.6, 0.16, 0.14), face * CFrame.new(0, h / 2 - 1.6, -0.26), color, Enum.Material.Neon, parent).CastShadow = false
	light(b, color, 12, 0.6)
	-- On two posts with a foot plate.
	local ph = pos.Y - SURFACE_Y - h / 2
	for _, sx in ipairs({ -1, 1 }) do
		part(key .. "BoardPost", Vector3.new(0.6, ph, 0.6), face * CFrame.new(sx * (w / 2 - 1.5), -h / 2 - ph / 2, 0.45), STEEL_DARK, Enum.Material.Metal, parent)
	end
	solid(key .. "BoardFoot", Vector3.new(w - 1, 0.4, 2), face * CFrame.new(0, -h / 2 - ph + 0.2, 0.45), BEAM, Enum.Material.Metal, parent)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 30
	gui.Parent = b
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Position = UDim2.fromScale(0.05, 0.03)
	head.Size = UDim2.fromScale(0.66, 0.13)
	head.Text = title
	head.Font = Enum.Font.FredokaOne
	head.TextScaled = true
	head.TextXAlignment = Enum.TextXAlignment.Left
	head.TextColor3 = WHITE
	head.Parent = gui
	local pill = Instance.new("TextLabel")
	pill.Position = UDim2.fromScale(0.75, 0.045)
	pill.Size = UDim2.fromScale(0.2, 0.1)
	pill.BackgroundColor3 = Color3.fromRGB(230, 50, 64)
	pill.Text = "LIVE"
	pill.Font = Enum.Font.GothamBold
	pill.TextScaled = true
	pill.TextColor3 = WHITE
	pill.Parent = gui
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0.5, 0)
	pc.Parent = pill
	local rows = {}
	for i = 1, 8 do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0.06, 0, 0.23 + (i - 1) * 0.095, 0)
		row.Size = UDim2.new(0.88, 0, 0.075, 0)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i == 1 and GOLD or WHITE
		row.Text = ""
		row.Parent = gui
		rows[i] = row
	end
	liveRows[key] = rows
end

local function setRows(rows: { TextLabel }, lines: { string }, empty: string)
	for i, row in ipairs(rows) do
		row.Text = lines[i] or (i == 1 and #lines == 0 and empty or "")
	end
end

local function refreshLive()
	local streaks = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local profile = DataService.Get(p)
		local n = (profile and profile.Stats and tonumber(profile.Stats.WinStreak)) or 0
		if n > 0 then
			table.insert(streaks, { name = p.DisplayName, n = n })
		end
	end
	table.sort(streaks, function(a, b)
		return a.n > b.n
	end)
	local lines = {}
	for i, s in ipairs(streaks) do
		lines[i] = string.format("%d.  %s  ·  %d in a row", i, s.name, s.n)
	end
	if liveRows.Streaks then
		setRows(liveRows.Streaks, lines, "No streaks yet. Win a duel!")
	end
	local duels = {}
	local source = LobbyService.LiveDuels
	if source then
		local ok, res = pcall(source)
		if ok and typeof(res) == "table" then
			duels = res
		end
	end
	if liveRows.Duels then
		setRows(liveRows.Duels, duels, "No duels right now. Step on a pad!")
	end
end

local function buildBoards(f: Instance)
	-- Either side of the way into the matchmaking hall, facing the spawn.
	liveBoard("Streaks", "WIN STREAKS", at(33, 25.5, 8), at(30, 0, 8), GOLD, f)
	liveBoard("Duels", "DUELS", at(-33, 25.5, 8), at(-30, 0, 8), BLUE, f)
	refreshLive()
	-- Two boards on a stone base, angled towards the spawn, a crown above.
	local spot = at(-30, -14)
	solid("BoardBase", Vector3.new(24, 1.2, 4), CFrame.lookAt(spot + Vector3.new(0, 0.6, 0), at(0, -2, 0.6)), PANEL, Enum.Material.Metal, f)
	local face = CFrame.lookAt(spot, at(0, -2))
	local right = face.RightVector
	buildBoard("Trophies", "TOP TROPHIES", spot + right * -5.6 + Vector3.new(0, 7.5, 0), spot + right * -5.6 + face.LookVector * 10, 10, 12, f)
	buildBoard("Wins", "MOST WINS", spot + right * 5.6 + Vector3.new(0, 7.5, 0), spot + right * 5.6 + face.LookVector * 10, 10, 12, f)
	for _, s in ipairs({ -11, 11 }) do
		part("BoardPost", Vector3.new(0.8, 14, 0.8), CFrame.new(spot + right * s + Vector3.new(0, 7, 0) - face.LookVector * 0.6), METAL, Enum.Material.Metal, f)
	end
	board("BoardsTitle", spot + Vector3.new(0, 15.6, 0), spot + face.LookVector * 10, 14, 2.4, GOLD, {
		{ text = "LEADERBOARDS", size = 70, color = GOLD },
	}, f)
end

-- ── the Practice Dimension (through the portal) ─────────────────────────────
type Dummy = { model: Model, root: BasePart, stand: CFrame, fluff: number, edge: Vector3? }
local dummies: { Dummy } = {}

local function practiceAt(dx: number, dz: number, lift: number?): Vector3
	return Vector3.new(PRACTICE.X + dx, SURFACE_Y + (lift or 0), PRACTICE.Z + dz)
end

local PRACTICE_ARRIVE = CFrame.lookAt(practiceAt(0, 10, 1.9), practiceAt(0, -10, 1.9))
local HUB_ARRIVE = CFrame.lookAt(at(0, -44, 1.9), at(0, 0, 1.9)) -- back out of the gate, facing the plaza

local function resetDummy(d: Dummy)
	d.fluff = 0
	d.model:SetAttribute("Fluff", 0)
	d.root.AssemblyLinearVelocity = Vector3.zero
	d.root.AssemblyAngularVelocity = Vector3.zero
	d.model:PivotTo(d.stand)
end

-- A glowing ring you walk through. Returns the invisible trigger in it.
local function portal(center: Vector3, facing: Vector3, color: Color3, label: string?, parent: Instance): BasePart
	local face = CFrame.lookAt(center, center + facing)
	local r = 7
	for k = 0, 27 do
		local a = k / 28 * math.pi * 2
		local p = face * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0)
		part("PortalRing", Vector3.new(1.9, 1.9, 1.4), CFrame.new(p.Position) * face.Rotation * CFrame.Angles(0, 0, a), PANEL, Enum.Material.Metal, parent)
	end
	local film = part("PortalFilm", Vector3.new(0.2, r * 2 - 1, r * 2 - 1), face * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Glass, parent)
	local filmShape = film :: Part
	filmShape.Shape = Enum.PartType.Cylinder
	film.Transparency = 0.5
	film.CastShadow = false
	solid("PortalBase", Vector3.new(r * 2 + 3, 1, 3), face * CFrame.new(0, -r - 0.5, 0), NAVY, Enum.Material.SmoothPlastic, parent)
	if label then
		board("PortalSign", center + Vector3.new(0, r + 2.2, 0) + facing * 0.5, center + facing * 10, 14, 2.6, color, {
			{ text = label, size = 64, color = WHITE },
		}, parent)
	end
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

local function buildPractice(lobby: Instance)
	local p = Instance.new("Folder")
	p.Name = "PracticeDimension"
	p.Parent = lobby
	-- The platform: a dark floor with a glowing grid, rails on three sides,
	-- open at the far end so target cats can be knocked off it.
	-- (A big floor: 110 wide, 96 deep, open at the far end.)
	local floorMid = practiceAt(0, -24)
	solid("PracticeFloor", Vector3.new(110, 2, 96), CFrame.new(floorMid - Vector3.new(0, 1, 0)), Color3.fromRGB(48, 51, 60), Enum.Material.DiamondPlate, p)
	part("Underside", Vector3.new(104, 8, 90), CFrame.new(floorMid - Vector3.new(0, 6, 0)), STEEL_DARK, Enum.Material.Metal, p)
	-- Lanes for the target cats, caution stripes along the open edge.
	for _, x in ipairs({ -27.5, -16.5, -5.5, 5.5, 16.5, 27.5 }) do
		part("LaneLine", Vector3.new(0.3, 0.05, 60), CFrame.new(practiceAt(x, -36, 0.03)), Color3.fromRGB(200, 204, 214), Enum.Material.SmoothPlastic, p)
	end
	caution("EdgeStripe", CFrame.new(practiceAt(0, -71.2, 0.03)), 110, 1.2, p)
	for _, side in ipairs({ { 55, -24, 0.4, 96 }, { -55, -24, 0.4, 96 }, { 0, 24, 110, 0.4 } }) do
		local rail = solid("Rail", Vector3.new(side[3], 3, side[4]), CFrame.new(practiceAt(side[1], side[2], 1.5)), GLASS, Enum.Material.Glass, p)
		rail.Transparency = 0.5
		local wall = solid("PracticeWall", Vector3.new(side[3], 40, side[4]), CFrame.new(practiceAt(side[1], side[2], 20)), GLASS, Enum.Material.Glass, p)
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CastShadow = false
	end
	neonSign("RangeTitle", practiceAt(0, 23.6, 18.5), practiceAt(0, 0, 18.5), 24, 4.4, CYAN, "SHOOTING RANGE", p)

	-- A floating pedestal to change your blaster (opens the weapons screen).
	do
		local spot = practiceAt(-16, 10)
		local base, top = holoPedestal(spot, practiceAt(0, -10), CYAN, "CHANGE BLASTER", p)
		local toFront = (practiceAt(0, -10) - spot) * Vector3.new(1, 0, 1)
		local gun = BlasterBuilder.Build(Weapons.DefaultLoadout, nil, CFrame.fromMatrix(top, Vector3.yAxis:Cross(toFront.Unit), Vector3.yAxis, toFront.Unit), 1.4)
		for _, d in ipairs(gun:GetDescendants()) do
			if d:IsA("BasePart") then
				deco(d)
			end
		end
		gun.Parent = p
		spinning(gun)
		prompt(base, "Change", "Blaster", "Loadout")
	end

	-- Targets floating in the sky beyond the range: shoot them and they pop
	-- (on your screen) and come back (MapLife).
	for _ = 1, 26 do
		local pos = practiceAt(rng:NextNumber(-60, 60), rng:NextNumber(-130, -40), rng:NextNumber(5, 42))
		local face = CFrame.lookAt(pos, practiceAt(0, 10, pos.Y - SURFACE_Y))
		local d = rng:NextNumber(2.2, 3.4)
		local disc = ArenaKit.NewPart("RangeTarget", Vector3.new(0.3, d, d), face * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(250, 246, 238), Enum.Material.SmoothPlastic, p) :: Part
		disc.Shape = Enum.PartType.Cylinder
		disc.CanCollide = false
		disc.CanTouch = false
		disc.CastShadow = false
		disc.CanQuery = true -- shots have to hit it
		for i, ring in ipairs({ { 0.72, Color3.fromRGB(226, 60, 60) }, { 0.45, Color3.fromRGB(250, 246, 238) }, { 0.2, Color3.fromRGB(226, 60, 60) } }) do
			local r = part("RangeTargetRing", Vector3.new(0.32 + i * 0.02, d * ring[1], d * ring[1]), face * CFrame.Angles(0, math.rad(90), 0), ring[2], Enum.Material.SmoothPlastic, disc) :: Part
			r.Shape = Enum.PartType.Cylinder
			r.CastShadow = false
		end
		CollectionService:AddTag(disc, "RangeTarget")
	end

	-- Three target cats on glowing decks, archery targets behind them.
	for i, dx in ipairs({ -22, -11, 0, 11, 22 }) do
		local dz = i % 2 == 1 and -26 or -23
		local deck = practiceAt(dx, dz)
		disc("TargetDeckTop", 5.8, 0.3, deck + Vector3.new(0, 0.12, 0), NAVY_LIGHT, Enum.Material.SmoothPlastic, p)
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
		local c = Vector3.new(PRACTICE.X + math.cos(a) * r, PRACTICE.Y + rng:NextNumber(-40, -12), PRACTICE.Z + math.sin(a) * r)
		for _ = 1, 4 do
			ball("Cloud", rng:NextNumber(10, 20), c + Vector3.new(rng:NextNumber(-10, 10), rng:NextNumber(-2, 4), rng:NextNumber(-10, 10)), WHITE, p).Transparency = 0.15
		end
	end

	-- In through the range bay's glass, back out through the portal.
	if rangeDoor then
		linkPortal(rangeDoor, PRACTICE_ARRIVE)
	end
	linkPortal(portal(practiceAt(0, 16, 8.5), Vector3.new(0, 0, -1), BLUE, "BACK TO LOBBY", p), HUB_ARRIVE)
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

-- ── putting it together ──────────────────────────────────────────────────────
local function buildLobby()
	local f = Instance.new("Folder")
	f.Name = "Lobby"
	-- The intro cinematic and Mochi's lesson (client) stage themselves in the
	-- Practice Dimension; "Range" is where the client lets you aim and shoot.
	f:SetAttribute("Center", CENTER)
	f:SetAttribute("Surface", SURFACE_Y)
	f:SetAttribute("Stage", practiceAt(0, -12))
	f:SetAttribute("Range", practiceAt(0, -12))
	f.Parent = Workspace
	local plaza = Instance.new("Folder")
	plaza.Name = "Plaza"
	plaza.Parent = f
	buildGround(plaza)
	buildSpawn(plaza)
	buildMatchHall(plaza)
	buildGate(plaza)
	buildBoards(plaza)
	buildDisplays(plaza)
	buildGuns(f)
	buildCollection(f)
	buildPractice(f)
end

-- ── players ──────────────────────────────────────────────────────────────────
local function spawnCFrame(): CFrame
	local p = at(rng:NextNumber(-5, 5), rng:NextNumber(-5, 3), 2.3)
	return CFrame.lookAt(p, p + Vector3.new(0, 0, 1)) -- facing the matchmaking hall
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
	-- TO DUELS (lobby menu): straight to the duel pads at the hall entrance.
	local lastTravel: { [Player]: number } = {}
	Remotes.Get("LobbyTravel").OnServerEvent:Connect(function(player, dest)
		if dest ~= "Duels" or player:GetAttribute("Context") ~= "Lobby" then
			return
		end
		local now = os.clock()
		if now - (lastTravel[player] or 0) < 1 then
			return
		end
		lastTravel[player] = now
		local char = player.Character
		local root = char and char.PrimaryPart
		if char and root then
			root.AssemblyLinearVelocity = Vector3.zero
			char:PivotTo(CFrame.lookAt(at(0, 34, 2.3), at(0, 60, 2.3)))
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastPortal[player] = nil
		lastTravel[player] = nil
	end)
	task.spawn(function()
		while true do
			refreshBoards()
			task.wait(60)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(2)
			refreshLive()
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		-- Target cats knocked off the Practice Dimension come back fresh.
		for _, dm in ipairs(dummies) do
			local pos = dm.root.Position
			if pos.Y >= dm.stand.Position.Y - 4 then
				dm.edge = pos
			end
			if pos.Y < FALL_Y or not nearPractice(pos) then
				if dm.fluff > 0 and dm.edge then
					PlayerService.RingoutBurst(dm.edge, Color3.fromRGB(255, 200, 90))
				end
				dm.edge = nil
				resetDummy(dm)
			end
		end
		-- Anyone who falls is put back where they were (practice or plaza).
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
