--!strict
-- LobbyService: the lobby everyone spawns into: one closed, connected
-- building on a floating island (stone walls all round, a frosted glass roof
-- over everything), laid out like the reference (Rivals-style):
--   * the middle: a glowing paw pad where everyone spawns, facing forward
--   * ahead: the Matchmaking hall you walk through - rows of 1v1 / 2v2 pads
--     down both sides with screens above them (DuelService builds the pads),
--     a dark walkway with arrows down the middle
--   * at the end of that hall: the Practice Dimension portal, to a floating
--     platform of target cats you can knock off the edge (and a portal back)
--   * left: the GUNS shop, every blaster racked on the back wall (F to equip)
--   * right: the COLLECTION, featured cats in glass cases, every rank tier
--     and a gold cat statue
--   * between the spawn and the Collection: the leaderboards
-- Every room opens straight off the main hall; nobody can hurt anyone here.

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

-- Floors, as rectangles relative to CENTER: { x0, x1, z0, z1 }. Spawn faces
-- +Z, so the player's left is +X and their right is -X.
local PLAZA = { -44, 44, -40, 30 }
local GUNS_ROOM = { 44, 86, -18, 18 }
local COLLECTION_ROOM = { -86, -44, -18, 18 }
local MATCH_HALL = { -20, 20, 30, 112 }
local GATE = { -24, 24, 112, 134 }
local AREAS = { PLAZA, GUNS_ROOM, COLLECTION_ROOM, MATCH_HALL, GATE }
-- The outside wall of the whole building, walked round in order.
local OUTLINE = {
	{ -44, -40 }, { 44, -40 }, { 44, -18 }, { 86, -18 }, { 86, 18 }, { 44, 18 }, { 44, 30 }, { 20, 30 },
	{ 20, 112 }, { 24, 112 }, { 24, 134 }, { -24, 134 }, { -24, 112 }, { -20, 112 }, { -20, 30 },
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

-- Colours from the reference: light stone, navy panels, blue/purple light.
local STONE = Color3.fromRGB(214, 210, 202)
local GROUT = Color3.fromRGB(184, 180, 174)
local STONE_WALL = Color3.fromRGB(170, 164, 156)
local STONE_DARK = Color3.fromRGB(116, 112, 108)
local NAVY = Color3.fromRGB(22, 28, 56)
local NAVY_LIGHT = Color3.fromRGB(36, 46, 86)
local HALL_FLOOR = Color3.fromRGB(38, 42, 60)
local BLUE = Color3.fromRGB(70, 165, 255)
local PURPLE = Color3.fromRGB(165, 105, 255)
local CYAN = Color3.fromRGB(90, 220, 255)
local GOLD = Color3.fromRGB(255, 200, 90)
local WOOD = Color3.fromRGB(122, 84, 56)
local METAL = Color3.fromRGB(60, 64, 82)
local LEAF = { Color3.fromRGB(86, 164, 72), Color3.fromRGB(68, 142, 60), Color3.fromRGB(104, 180, 84) }
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

-- A navy board facing `toward`, with a glowing edge and (optional) text.
local function board(name: string, pos: Vector3, toward: Vector3, w: number, h: number, edge: Color3, lines: any, parent: Instance): BasePart
	local face = CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
	neon(name .. "Edge", Vector3.new(w + 0.5, h + 0.5, 0.2), face * CFrame.new(0, 0, 0.25), edge, parent)
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
local function bushes(pos: Vector3, w: number, d: number, parent: Instance)
	for _ = 1, math.max(3, math.floor(w * d / 6)) do
		local s = rng:NextNumber(1.6, 2.6)
		ball("Leaves", s, pos + Vector3.new(rng:NextNumber(-w / 2 + 0.8, w / 2 - 0.8), s * 0.35, rng:NextNumber(-d / 2 + 0.8, d / 2 - 0.8)), LEAF[rng:NextInteger(1, #LEAF)], parent)
	end
end

local function planter(pos: Vector3, w: number, d: number, parent: Instance)
	solid("Planter", Vector3.new(w, 1.8, d), CFrame.new(pos + Vector3.new(0, 0.9, 0)), STONE_WALL, Enum.Material.Slate, parent)
	part("PlanterCap", Vector3.new(w + 0.4, 0.25, d + 0.4), CFrame.new(pos + Vector3.new(0, 1.85, 0)), STONE, Enum.Material.Slate, parent)
	part("Soil", Vector3.new(w - 0.6, 0.2, d - 0.6), CFrame.new(pos + Vector3.new(0, 1.9, 0)), Color3.fromRGB(70, 52, 40), Enum.Material.Ground, parent)
	bushes(pos + Vector3.new(0, 1.9, 0), w - 0.8, d - 0.8, parent)
end

local function lantern(pos: Vector3, parent: Instance)
	part("LanternPost", Vector3.new(0.5, 6, 0.5), CFrame.new(pos + Vector3.new(0, 3, 0)), METAL, Enum.Material.Metal, parent)
	part("LanternArm", Vector3.new(1.4, 0.3, 0.3), CFrame.new(pos + Vector3.new(0.5, 6, 0)), METAL, Enum.Material.Metal, parent)
	local lamp = neon("Lamp", Vector3.new(0.9, 1.2, 0.9), CFrame.new(pos + Vector3.new(1.1, 5.2, 0)), Color3.fromRGB(255, 214, 150), parent)
	light(lamp, Color3.fromRGB(255, 214, 150), 14, 0.9)
	part("LampCap", Vector3.new(1.2, 0.3, 1.2), CFrame.new(pos + Vector3.new(1.1, 5.95, 0)), METAL, Enum.Material.Metal, parent)
end

-- A tall navy banner with a glowing paw-coloured stripe.
local function banner(pos: Vector3, toward: Vector3, color: Color3, parent: Instance)
	local face = CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
	part("Banner", Vector3.new(3, 8, 0.15), face, Color3.fromRGB(120, 30, 40), Enum.Material.Fabric, parent)
	neon("BannerStripe", Vector3.new(3.05, 0.3, 0.17), face * CFrame.new(0, -3.4, 0), color, parent)
	part("BannerRod", Vector3.new(3.6, 0.25, 0.25), face * CFrame.new(0, 4.1, 0), WOOD, Enum.Material.Wood, parent)
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
	bubble.MaxDistance = 60
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

-- ── the ground: stone plaza, the hall floor, the rock underneath ─────────────
local function buildGround(f: Instance)
	for i, r in ipairs(AREAS) do
		local w, d = r[2] - r[1], r[4] - r[3]
		local mid = at((r[1] + r[2]) / 2, (r[3] + r[4]) / 2)
		local hall = r == MATCH_HALL
		local room = r == GUNS_ROOM or r == COLLECTION_ROOM
		solid("Floor" .. i, Vector3.new(w + 0.2, 2, d + 0.2), CFrame.new(mid - Vector3.new(0, 1, 0)), hall and HALL_FLOOR or room and WOOD or STONE,
			hall and Enum.Material.SmoothPlastic or room and Enum.Material.WoodPlanks or Enum.Material.Slate, f)
		-- Frosted glass roof (closed, but the daylight comes through) on beams.
		local roof = solid("Roof" .. i, Vector3.new(w + 2, 1, d + 2), CFrame.new(mid + Vector3.new(0, HEIGHT + 0.5, 0)), Color3.fromRGB(205, 228, 255), Enum.Material.Glass, f)
		roof.Transparency = 0.45
		roof.CastShadow = false
		roof.CanQuery = false
		local long = w >= d
		local span = long and w or d
		for k = 4, span - 4, 8 do
			local off = long and Vector3.new(r[1] + k - (r[1] + r[2]) / 2, 0, 0) or Vector3.new(0, 0, r[3] + k - (r[3] + r[4]) / 2)
			part("RoofBeam", long and Vector3.new(0.9, 1, d) or Vector3.new(w, 1, 0.9), CFrame.new(mid + off + Vector3.new(0, HEIGHT - 0.5, 0)), METAL, Enum.Material.Metal, f).CastShadow = false
		end
		if not hall and not room then
			-- Stone tiles.
			for x = r[1] + 6, r[2] - 1, 6 do
				part("Grout", Vector3.new(0.12, 0.04, d), CFrame.new(at(x, (r[3] + r[4]) / 2, 0.02)), GROUT, Enum.Material.SmoothPlastic, f)
			end
			for z = r[3] + 6, r[4] - 1, 6 do
				part("Grout", Vector3.new(w, 0.04, 0.12), CFrame.new(at((r[1] + r[2]) / 2, z, 0.02)), GROUT, Enum.Material.SmoothPlastic, f)
			end
		end
		-- Rock underneath, tapering away.
		part("Foundation", Vector3.new(w + 4, 6, d + 4), CFrame.new(mid - Vector3.new(0, 5, 0)), STONE_DARK, Enum.Material.Rock, f)
		part("Taper", Vector3.new(w * 0.75, 10, d * 0.75), CFrame.new(mid - Vector3.new(0, 13, 0)), STONE_DARK:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Rock, f)
		part("Taper", Vector3.new(w * 0.45, 12, d * 0.45), CFrame.new(mid - Vector3.new(0, 24, 0)), STONE_DARK:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Rock, f)
	end

	-- Walls all the way round: stone along the plaza and rooms, navy along the
	-- matchmaking hall and the gate; trim, light strips and a stone base inside.
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
		solid("Wall", Vector3.new(2, HEIGHT, len + 2), CFrame.lookAt(c, c + dir), navy and NAVY or STONE_WALL, navy and Enum.Material.SmoothPlastic or Enum.Material.Slate, f)
		local face = base + normal * 0.02
		local along = CFrame.lookAt(face, face + dir)
		part("WallBase", Vector3.new(0.2, 2.4, len), along * CFrame.new(0, 1.2, 0), navy and STONE_WALL or STONE_DARK, Enum.Material.Slate, f)
		neon("WallTrim", Vector3.new(0.25, 0.3, len), along * CFrame.new(0, HEIGHT - 1, 0), navy and BLUE or PURPLE, f)
		if not navy then
			part("WallPanel", Vector3.new(0.15, 9, math.max(len - 3, 1)), along * CFrame.new(0, 9.5, 0), NAVY, Enum.Material.SmoothPlastic, f)
		end
		for k = 6, len - 3, 12 do
			neon("LightStrip", Vector3.new(0.25, 7, 0.3), along * CFrame.new(0, 9.5, k - len / 2), navy and PURPLE or BLUE, f).Transparency = 0.2
		end
	end
	-- Over each way through from the main hall: a wall above the opening with
	-- its sign (the Guns and Collection rooms; the matchmaking arch has its own).
	for _, h in ipairs({ { 44, -1, "GUNS", BLUE }, { -44, 1, "COLLECTION", PURPLE } }) do
		local x, side = h[1], h[2]
		solid("Header", Vector3.new(2, HEIGHT - 14, 36), CFrame.new(at(x, 0, 14 + (HEIGHT - 14) / 2)), STONE_WALL, Enum.Material.Slate, f)
		board(h[3] .. "Sign", at(x + side * 1.3, 0, 17.8), at(0, 0, 17.8), 24, 4.4, h[4], {
			{ text = h[3], size = 140, color = WHITE },
		}, f)
		neon("OpeningGlow", Vector3.new(0.3, 0.3, 36), CFrame.new(at(x + side * 1.2, 0, 14.2)), h[4], f)
		for _, z in ipairs({ -18.5, 18.5 }) do
			solid("OpeningPillar", Vector3.new(3, HEIGHT, 3), CFrame.new(at(x, z, HEIGHT / 2)), STONE_WALL, Enum.Material.Slate, f)
			lantern(at(x + side * 3, z * 0.95), f)
		end
	end
	for _, p in ipairs({ { 0, 0 }, { -24, -24 }, { 24, -24 }, { -24, 18 }, { 24, 18 }, { 65, 0 }, { -65, 0 } }) do
		local holder = part("CeilingLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at(p[1], p[2], HEIGHT - 3)), WHITE, Enum.Material.SmoothPlastic, f)
		holder.Transparency = 1
		light(holder, Color3.fromRGB(235, 240, 255), 36, 0.7)
	end

	-- Sky: little floating islands round about, clouds below.
	for _, s in ipairs({ { -170, 60, 30, 9 }, { 170, 40, -10, 10 }, { -150, -110, 18, 7 }, { 160, -120, 45, 8 }, { -40, 230, 55, 9 }, { 70, 250, 20, 7 }, { -210, 160, 40, 8 }, { 220, 150, 10, 9 } }) do
		local isle = Instance.new("Folder")
		isle.Name = "SkyIsle"
		isle.Parent = f
		local c = Vector3.new(CENTER.X + s[1], CENTER.Y + s[3], CENTER.Z + s[2])
		ArenaKit.MakeIslandBase(c, s[4], "Isle", {
			Top = LEAF[1], TopDark = LEAF[2], Stone = STONE_WALL, StoneDark = STONE_DARK, Wood = WOOD, WoodDark = WOOD,
		}, Enum.Material.Grass, isle)
		for _, d in ipairs(isle:GetDescendants()) do
			if d:IsA("BasePart") then
				deco(d)
			end
		end
		local top = c + Vector3.new(0, ArenaKit.SURFACE, 0)
		part("Trunk", Vector3.new(0.8, 5, 0.8), CFrame.new(top + Vector3.new(0, 2.5, 0)), WOOD, Enum.Material.Wood, isle)
		ball("Leaves", 6, top + Vector3.new(0, 6, 0), LEAF[rng:NextInteger(1, 3)], isle)
	end
	for _ = 1, 22 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(110, 260)
		local c = Vector3.new(CENTER.X + math.cos(a) * r, CENTER.Y + rng:NextNumber(-50, -20), CENTER.Z + 40 + math.sin(a) * r)
		for _ = 1, 4 do
			local s = rng:NextNumber(10, 22)
			ball("Cloud", s, c + Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-2, 4), rng:NextNumber(-12, 12)), WHITE, f).Transparency = 0.15
		end
	end
end

-- ── the middle: spawn ────────────────────────────────────────────────────────
local function buildSpawn(f: Instance)
	-- A raised pale stone pad with a glowing blue frame and a paw print.
	local c = at(0, 0)
	solid("SpawnPad", Vector3.new(18, 0.4, 18), CFrame.new(c + Vector3.new(0, 0.2, 0)), Color3.fromRGB(236, 234, 230), Enum.Material.Slate, f)
	for _, e in ipairs({ { 0, 9, 18.4, 0.4 }, { 0, -9, 18.4, 0.4 }, { 9, 0, 0.4, 18.4 }, { -9, 0, 0.4, 18.4 } }) do
		neon("SpawnFrame", Vector3.new(e[3], 0.2, e[4]), CFrame.new(c + Vector3.new(e[1], 0.42, e[2])), BLUE, f)
	end
	neon("SpawnGlow", Vector3.new(20, 0.06, 20), CFrame.new(c + Vector3.new(0, 0.02, 0)), BLUE, f).Transparency = 0.7
	local paw = c + Vector3.new(0, 0.42, -1)
	disc("Paw", 6, 0.06, paw, Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic, f)
	for _, t in ipairs({ { -3.1, 3 }, { -1.1, 4.4 }, { 1.1, 4.4 }, { 3.1, 3 } }) do
		disc("PawToe", 2.3, 0.06, paw + Vector3.new(t[1], 0, t[2]), Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic, f)
	end
	-- Glowing paths from the pad to each area.
	for _, s in ipairs({ -6, 6 }) do
		neon("Path", Vector3.new(0.3, 0.05, 21), CFrame.new(at(s, 19.5, 0.03)), BLUE, f).Transparency = 0.25
		neon("Path", Vector3.new(35, 0.05, 0.3), CFrame.new(at(26.5, s, 0.03)), BLUE, f).Transparency = 0.25
		neon("Path", Vector3.new(35, 0.05, 0.3), CFrame.new(at(-26.5, s, 0.03)), BLUE, f).Transparency = 0.25
	end
	-- Planters, lanterns and a terrace behind the spawn looking out at the sky.
	for _, p in ipairs({ { 15, 22, 8, 4 }, { -15, 22, 8, 4 }, { 18, -16, 6, 6 }, { -18, -16, 6, 6 }, { 34, 25, 10, 3 }, { -34, 25, 10, 3 }, { 0, -34, 14, 3 } }) do
		planter(at(p[1], p[2]), p[3], p[4], f)
	end
	for _, p in ipairs({ { 9, 26 }, { -9, 26 }, { 26, -30 }, { -14, -30 }, { 12, -30 } }) do
		lantern(at(p[1], p[2]), f)
	end
end

-- ── ahead: the matchmaking hall (walk-through) and the practice gate ────────
local function buildMatchHall(f: Instance)
	-- The entrance arch: stone pillars, a beam and the big sign.
	for _, x in ipairs({ -22, 22 }) do
		solid("ArchPillar", Vector3.new(4, HEIGHT, 4), CFrame.new(at(x, 30, HEIGHT / 2)), STONE_WALL, Enum.Material.Slate, f)
		banner(at(x, 27.8, 12), at(x, 0, 12), PURPLE, f)
	end
	solid("ArchHeader", Vector3.new(40, HEIGHT - 14, 2), CFrame.new(at(0, 30, 14 + (HEIGHT - 14) / 2)), NAVY, Enum.Material.SmoothPlastic, f)
	board("MatchSign", at(0, 28.6, 17.8), at(0, 0, 17.8), 30, 5, BLUE, {
		{ text = "MATCHMAKING", size = 150, color = WHITE },
	}, f)
	board("MatchSignBack", at(0, 31.4, 17.8), at(0, 60, 17.8), 30, 5, BLUE, {
		{ text = "LOBBY", size = 150, color = WHITE },
	}, f)

	-- The walkway: a darker lane with glowing arrows, purple and gold edges.
	part("Walkway", Vector3.new(10, 0.06, 82), CFrame.new(at(0, 71, 0.03)), Color3.fromRGB(26, 28, 40), Enum.Material.SmoothPlastic, f)
	neon("WalkEdge", Vector3.new(0.35, 0.07, 82), CFrame.new(at(5, 71, 0.04)), PURPLE, f)
	neon("WalkEdge", Vector3.new(0.35, 0.07, 82), CFrame.new(at(-5, 71, 0.04)), GOLD, f)
	for z = 38, 106, 9 do
		for _, s in ipairs({ -1, 1 }) do
			local p = at(s * 0.9, z, 0.05)
			neon("Arrow", Vector3.new(2.6, 0.07, 0.45), CFrame.new(p) * CFrame.Angles(0, s * math.rad(35), 0), WHITE, f).Transparency = 0.35
		end
	end
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
		part("RoofBeam", Vector3.new(41, 0.8, 1), CFrame.new(at(0, z, HALL_WALL + 0.8)), METAL, Enum.Material.Metal, f).CastShadow = false
		neon("BeamLight", Vector3.new(30, 0.15, 0.35), CFrame.new(at(0, z, HALL_WALL + 0.3)), z % 16 == 2 and BLUE or PURPLE, f).Transparency = 0.2
	end
	for _, x in ipairs({ -12, 12 }) do
		part("RoofRail", Vector3.new(0.8, 0.8, 80), CFrame.new(at(x, 72, HALL_WALL + 1.6)), METAL, Enum.Material.Metal, f).CastShadow = false
	end
	for z = 40, 104, 16 do
		local holder = part("HallLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at(0, z, HALL_WALL - 1)), WHITE, Enum.Material.SmoothPlastic, f)
		holder.Transparency = 1
		light(holder, Color3.fromRGB(190, 210, 255), 26, 0.9)
	end

	-- The gate at the far end: pillars, banners, a lit sign over the portal.
	for _, x in ipairs({ -11, 11 }) do
		solid("GatePillar", Vector3.new(3.5, HEIGHT, 3.5), CFrame.new(at(x, 127, HEIGHT / 2)), STONE_WALL, Enum.Material.Slate, f)
		banner(at(x, 125, 13), at(x, 0, 13), CYAN, f)
		lantern(at(x * 1.6, 116), f)
	end
	solid("GateBeam", Vector3.new(26, 2, 3.5), CFrame.new(at(0, 127, 20)), NAVY, Enum.Material.SmoothPlastic, f)
	board("GateSign", at(0, 125, 17.5), at(0, 0, 17.5), 18, 3.6, CYAN, {
		{ text = "PRACTICE DIMENSION", size = 80, color = WHITE },
	}, f)
	for _, x in ipairs({ -18, 18 }) do
		planter(at(x, 122), 5, 8, f)
	end
end

-- ── left: the GUNS shop ──────────────────────────────────────────────────────
-- A side room off the main hall: a panel on the back wall, glowing trim and
-- lights (its walls, roof and sign are part of the building).
local function shopRoom(name: string, backX: number, openSide: number, glow: Color3, f: Instance): Folder
	local b = Instance.new("Folder")
	b.Name = name
	b.Parent = f
	part("BackPanel", Vector3.new(0.2, 11, 32), CFrame.new(at(backX + openSide * 0.12, 0, 7.5)), NAVY, Enum.Material.SmoothPlastic, b)
	neon("BackGlow", Vector3.new(0.25, 0.3, 32), CFrame.new(at(backX + openSide * 0.2, 0, 13.2)), glow, b)
	local midX = backX + openSide * 21
	for _, z in ipairs({ -9, 9 }) do
		local holder = part("RoomLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(at(midX, z, HEIGHT - 4)), WHITE, Enum.Material.SmoothPlastic, b)
		holder.Transparency = 1
		light(holder, glow:Lerp(WHITE, 0.6), 26, 1)
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
		neon("RackGlow", Vector3.new(0.1, 0.2, 5.2), CFrame.new(pos + Vector3.new(0.05, -1.5, 0)), w.TrailColor, b)
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
	neon("CounterGlow", Vector3.new(0.2, 0.25, 12), CFrame.new(at(68.45, 10, 2.6)), BLUE, b)
	for _, c in ipairs({ { 80, -15 }, { 77, -15.2 }, { 80, 15 } }) do
		solid("Crate", Vector3.new(2.6, 2.6, 2.6), CFrame.new(at(c[1], c[2], 1.3)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), WOOD, Enum.Material.WoodPlanks, b)
	end
	shopkeeper({ Fur = "Black", Outfit = "Ninja", Hat = "Cap" }, at(48, -12), at(0, 0), "Check out new skins!", "Shop", b)
end

-- ── right: the COLLECTION ────────────────────────────────────────────────────
local FEATURED = {
	{ Fur = "Galaxy", Outfit = "Royal", Hat = "DiamondCrown" },
	{ Fur = "Sakura", Outfit = "Streetwear", Hat = "PartyHat" },
	{ Fur = "Midnight", Outfit = "Ninja", Hat = "Headphones", Accessory = "Sunglasses" },
	{ Fur = "RoyalGold", Outfit = "Space", Hat = "Halo", Accessory = "Jetpack" },
}

local function glassCase(pos: Vector3, size: Vector3, glow: Color3, parent: Instance): BasePart
	local stand = solid("CaseStand", Vector3.new(size.X + 0.6, 1.2, size.Z + 0.6), CFrame.new(pos + Vector3.new(0, 0.6, 0)), NAVY, Enum.Material.SmoothPlastic, parent)
	neon("CaseGlow", Vector3.new(size.X + 0.7, 0.2, size.Z + 0.7), CFrame.new(pos + Vector3.new(0, 1.25, 0)), glow, parent)
	local glass = solid("CaseGlass", size, CFrame.new(pos + Vector3.new(0, 1.2 + size.Y / 2, 0)), GLASS, Enum.Material.Glass, parent)
	glass.Transparency = 0.75
	glass.CastShadow = false
	glass.CanQuery = false
	part("CaseTop", Vector3.new(size.X + 0.4, 0.3, size.Z + 0.4), CFrame.new(pos + Vector3.new(0, 1.35 + size.Y, 0)), NAVY, Enum.Material.SmoothPlastic, parent)
	local glowBlock = part("CaseLight", Vector3.new(0.2, 0.2, 0.2), CFrame.new(pos + Vector3.new(0, size.Y, 0)), glow, Enum.Material.SmoothPlastic, parent)
	glowBlock.Transparency = 1
	light(glowBlock, glow, 9, 1.2)
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
		part("TierGem", Vector3.new(1.2, 1.2, 1.2), CFrame.new(pos + Vector3.new(0, 2.6, 0)) * CFrame.Angles(math.rad(45), math.rad(45), 0), tier.Color, Enum.Material.Neon, b)
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
	neon("PlinthGlow", Vector3.new(7.4, 0.25, 7.4), CFrame.new(plinth + Vector3.new(0, 2.05, 0)), GOLD, b)
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
				d.Color = GOLD
				d.Material = Enum.Material.Foil
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

-- ── between spawn and the Collection: the leaderboards ─────────────────────
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

local function buildBoards(f: Instance)
	-- Two boards on a stone base, angled towards the spawn, a crown above.
	local spot = at(-30, -14)
	solid("BoardBase", Vector3.new(24, 1.2, 4), CFrame.lookAt(spot + Vector3.new(0, 0.6, 0), at(0, -2, 0.6)), STONE_WALL, Enum.Material.Slate, f)
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
type Dummy = { model: Model, root: BasePart, stand: CFrame, fluff: number }
local dummies: { Dummy } = {}

local function practiceAt(dx: number, dz: number, lift: number?): Vector3
	return Vector3.new(PRACTICE.X + dx, SURFACE_Y + (lift or 0), PRACTICE.Z + dz)
end

local PRACTICE_ARRIVE = CFrame.lookAt(practiceAt(0, 10, 1.9), practiceAt(0, -10, 1.9))
local HUB_ARRIVE = CFrame.lookAt(at(0, 112, 1.9), at(0, 0, 1.9)) -- back out of the gate, facing the plaza

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

-- A glowing ring you walk through. Returns the invisible trigger in it.
local function portal(center: Vector3, facing: Vector3, color: Color3, label: string?, parent: Instance): BasePart
	local face = CFrame.lookAt(center, center + facing)
	local r = 7
	for k = 0, 27 do
		local a = k / 28 * math.pi * 2
		local p = face * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0)
		neon("PortalRing", Vector3.new(1.8, 1.8, 1.2), CFrame.new(p.Position) * face.Rotation * CFrame.Angles(0, 0, a), color, parent)
	end
	local film = part("PortalFilm", Vector3.new(0.2, r * 2 - 1, r * 2 - 1), face * CFrame.Angles(0, math.rad(90), 0), color, Enum.Material.Neon, parent)
	local filmShape = film :: Part
	filmShape.Shape = Enum.PartType.Cylinder
	film.Transparency = 0.5
	film.CastShadow = false
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	swirl.Color = ColorSequence.new(color, WHITE)
	swirl.Size = NumberSequence.new(0.6, 0)
	swirl.Lifetime = NumberRange.new(0.8, 1.4)
	swirl.Rate = 30
	swirl.Speed = NumberRange.new(2, 4)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.LightEmission = 1
	swirl.Parent = film
	light(film, color, 20, 1.6)
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

local function buildPractice(lobby: Instance, hall: Instance)
	local p = Instance.new("Folder")
	p.Name = "PracticeDimension"
	p.Parent = lobby
	-- The platform: a dark floor with a glowing grid, rails on three sides,
	-- open at the far end so target cats can be knocked off it.
	local floorMid = practiceAt(0, -12)
	solid("PracticeFloor", Vector3.new(64, 2, 64), CFrame.new(floorMid - Vector3.new(0, 1, 0)), HALL_FLOOR, Enum.Material.SmoothPlastic, p)
	for x = -24, 24, 8 do
		neon("Grid", Vector3.new(0.12, 0.05, 64), CFrame.new(practiceAt(x, -12, 0.02)), PURPLE, p).Transparency = 0.6
	end
	for z = -40, 16, 8 do
		neon("Grid", Vector3.new(64, 0.05, 0.12), CFrame.new(practiceAt(0, z, 0.02)), PURPLE, p).Transparency = 0.6
	end
	part("Underside", Vector3.new(60, 8, 60), CFrame.new(floorMid - Vector3.new(0, 6, 0)), NAVY, Enum.Material.SmoothPlastic, p)
	neon("Rim", Vector3.new(64.4, 0.4, 0.4), CFrame.new(practiceAt(0, -44, -0.2)), PURPLE, p)
	for _, side in ipairs({ { 32, -12, 0.4, 64 }, { -32, -12, 0.4, 64 }, { 0, 20, 64, 0.4 } }) do
		local rail = solid("Rail", Vector3.new(side[3], 3, side[4]), CFrame.new(practiceAt(side[1], side[2], 1.5)), GLASS, Enum.Material.Glass, p)
		rail.Transparency = 0.5
		local wall = solid("PracticeWall", Vector3.new(side[3], 40, side[4]), CFrame.new(practiceAt(side[1], side[2], 20)), GLASS, Enum.Material.Glass, p)
		wall.Transparency = 1
		wall.CanQuery = false
		wall.CastShadow = false
	end
	board("PracticeTitle", practiceAt(0, 19.6, 18.5), practiceAt(0, 0, 18.5), 22, 4, PURPLE, {
		{ text = "PRACTICE DIMENSION", size = 80, color = WHITE },
	}, p)

	-- Three target cats on glowing decks, archery targets behind them.
	for i, dx in ipairs({ -11, 0, 11 }) do
		local dz = i == 2 and -26 or -23
		local deck = practiceAt(dx, dz)
		disc("TargetDeck", 6.4, 0.2, deck + Vector3.new(0, 0.05, 0), PURPLE, Enum.Material.Neon, p).Transparency = 0.5
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

	-- Portals: the gate at the end of the matchmaking hall, and back.
	linkPortal(portal(at(0, 126, 8.5), Vector3.new(0, 0, -1), CYAN, nil, hall), PRACTICE_ARRIVE)
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
	buildBoards(plaza)
	buildGuns(f)
	buildCollection(f)
	buildPractice(f, plaza)
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
		-- Target cats knocked off the Practice Dimension come back fresh.
		for _, dm in ipairs(dummies) do
			if dm.root.Position.Y < FALL_Y or not nearPractice(dm.root.Position) then
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
