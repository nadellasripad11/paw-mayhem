--!strict
-- LobbyService: the walkable lobby everyone spawns into (like Rivals). A big
-- garden island in the sky with railings round the edge:
--   * spawn in the middle, facing the duel pads straight ahead (DuelService)
--   * behind you: the practice range - target cats on decks whose knockback %
--     climbs until they fly off (they reset themselves)
--   * left: the armory - every blaster on a pedestal
--   * right: the boutique - cats wearing featured looks
--   * front-right: the leaderboard board (top trophies)
-- Nobody can hurt anyone here; fall off and you're put back.

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

local PlayerService = require(script.Parent.PlayerService)
local WeaponService = require(script.Parent.WeaponService)
local LeaderboardService = require(script.Parent.LeaderboardService)
local ArenaKit = require(script.Parent.Parent.World.ArenaKit)

local LobbyService = {}

local CENTER = Vector3.new(0, 150, 2600)
local RADIUS = 64
local SURFACE_Y = CENTER.Y + ArenaKit.SURFACE
local FALL_Y = CENTER.Y - 30
local PALETTE: ArenaKit.Palette = {
	Top = Color3.fromRGB(122, 200, 108), TopDark = Color3.fromRGB(96, 170, 86),
	Stone = Color3.fromRGB(150, 144, 136), StoneDark = Color3.fromRGB(118, 112, 110),
	Wood = Color3.fromRGB(176, 124, 72), WoodDark = Color3.fromRGB(120, 82, 50),
}

local GRASS = Color3.fromRGB(134, 196, 112)
local COBBLE = Color3.fromRGB(206, 200, 188)
local COBBLE_DARK = Color3.fromRGB(162, 154, 144)
local STONE = Color3.fromRGB(176, 172, 166)
local WOOD = Color3.fromRGB(150, 104, 68)
local WOOD_DARK = Color3.fromRGB(104, 70, 46)
local TORII = Color3.fromRGB(214, 70, 58)
local BLOSSOM = { Color3.fromRGB(255, 196, 214), Color3.fromRGB(252, 170, 196), Color3.fromRGB(255, 222, 232) }
local LEAF = { Color3.fromRGB(104, 172, 96), Color3.fromRGB(88, 150, 84) }
local WATER = Color3.fromRGB(104, 178, 214)
local LAMP = Color3.fromRGB(255, 214, 150)
local INK = Color3.fromRGB(28, 32, 46)

local rng = Random.new(20260926)

-- Spawn faces +Z, so the player's left is +X and their right is -X.
local LEFT, RIGHT = 1, -1

-- Where the duel pads sit (DuelService builds them): straight ahead of spawn.
LobbyService.DuelPads = {
	{ kind = "1v1", x = -27, z = 34 },
	{ kind = "1v1", x = -9, z = 34 },
	{ kind = "2v2", x = 9, z = 34 },
	{ kind = "2v2", x = 27, z = 34 },
}

-- ── building helpers ─────────────────────────────────────────────────────────
local function at(dx: number, dz: number, lift: number?): Vector3
	return Vector3.new(CENTER.X + dx, SURFACE_Y + (lift or 0), CENTER.Z + dz)
end
LobbyService.At = at

-- A CFrame at pos whose front (-Z) looks at the middle of the island.
local function facingMiddle(pos: Vector3): CFrame
	return CFrame.lookAt(pos, Vector3.new(CENTER.X, pos.Y, CENTER.Z))
end

local function deco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return deco(ArenaKit.NewPart(name, size, cf, color, material, parent))
end

local function ball(name: string, d: number, pos: Vector3, color: Color3, parent: Instance): BasePart
	local p = part(name, Vector3.one * d, CFrame.new(pos), color, Enum.Material.SmoothPlastic, parent)
	;(p :: Part).Shape = Enum.PartType.Ball
	p.CastShadow = false
	return p
end

local function disc(name: string, d: number, h: number, pos: Vector3, color: Color3, material: Enum.Material, parent: Instance): BasePart
	return deco(ArenaKit.NewDisc(name, d, h, pos, color, material, parent))
end

local function sign(parent: BasePart, face: Enum.NormalId, lines: { { text: string, size: number, color: Color3 } })
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.Parent = parent
	local list = Instance.new("UIListLayout")
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
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

local function blossomTree(pos: Vector3, s: number, parent: Instance)
	local h = 5 * s
	part("Trunk", Vector3.new(0.9 * s, h, 0.9 * s), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))), WOOD_DARK, Enum.Material.Wood, parent)
	local top = pos + Vector3.new(0, h + 1.2 * s, 0)
	ball("Blossom", 6.2 * s, top, BLOSSOM[1], parent)
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		ball("Blossom", rng:NextNumber(3.4, 4.6) * s, top + Vector3.new(math.cos(a) * 2.6 * s, rng:NextNumber(-1, 0.8) * s, math.sin(a) * 2.6 * s), BLOSSOM[rng:NextInteger(1, 3)], parent)
	end
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(BLOSSOM[2])
	e.Size = NumberSequence.new(0.35)
	e.Lifetime = NumberRange.new(4, 6)
	e.Rate = 2
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0.6, -1.4, 0.3)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Parent = ball("Canopy", 0.1, top, BLOSSOM[1], parent)
end

local function bush(pos: Vector3, parent: Instance)
	for k = 1, 3 do
		local d = rng:NextNumber(1.8, 2.8)
		local a = k * 2.1
		ball("Bush", d, pos + Vector3.new(math.cos(a) * 0.9, d * 0.3, math.sin(a) * 0.9), LEAF[rng:NextInteger(1, 2)], parent)
	end
end

local function lantern(pos: Vector3, parent: Instance)
	part("LanternBase", Vector3.new(1.6, 0.5, 1.6), CFrame.new(pos + Vector3.new(0, 0.25, 0)), STONE, Enum.Material.Slate, parent)
	part("LanternPillar", Vector3.new(0.6, 2.2, 0.6), CFrame.new(pos + Vector3.new(0, 1.6, 0)), STONE, Enum.Material.Slate, parent)
	local light = part("LanternLight", Vector3.new(1.1, 1, 1.1), CFrame.new(pos + Vector3.new(0, 3.2, 0)), LAMP, Enum.Material.Neon, parent)
	local glow = Instance.new("PointLight")
	glow.Color = LAMP
	glow.Range = 12
	glow.Brightness = 0.7
	glow.Parent = light
	part("LanternRoof", Vector3.new(1.9, 0.4, 1.9), CFrame.new(pos + Vector3.new(0, 3.9, 0)), STONE:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Slate, parent)
	ball("LanternTop", 0.5, pos + Vector3.new(0, 4.25, 0), STONE, parent)
end

local function torii(pos: Vector3, parent: Instance)
	for _, x in ipairs({ -4.2, 4.2 }) do
		local post = part("GatePost", Vector3.new(7.5, 0.9, 0.9), CFrame.new(pos + Vector3.new(x, 3.75, 0)) * CFrame.Angles(0, 0, math.rad(90)), TORII, Enum.Material.SmoothPlastic, parent)
		;(post :: Part).Shape = Enum.PartType.Cylinder
	end
	part("GateTop", Vector3.new(11.6, 0.7, 1.2), CFrame.new(pos + Vector3.new(0, 7.8, 0)), Color3.fromRGB(58, 48, 46), Enum.Material.SmoothPlastic, parent)
	part("GateBeam", Vector3.new(10.6, 0.6, 1.0), CFrame.new(pos + Vector3.new(0, 7.1, 0)), TORII, Enum.Material.SmoothPlastic, parent)
	part("GateTie", Vector3.new(9.4, 0.45, 0.7), CFrame.new(pos + Vector3.new(0, 5.8, 0)), TORII, Enum.Material.SmoothPlastic, parent)
end

local function pond(pos: Vector3, r: number, parent: Instance)
	disc("PondBed", r * 2 + 0.6, 0.2, pos + Vector3.new(0, 0.05, 0), Color3.fromRGB(96, 110, 104), Enum.Material.Slate, parent)
	local water = disc("Pond", r * 2, 0.2, pos + Vector3.new(0, 0.15, 0), WATER, Enum.Material.Glass, parent)
	water.Transparency = 0.25
	for k = 1, 12 do
		local a = k / 12 * math.pi * 2
		local sz = Vector3.new(rng:NextNumber(1.2, 1.9), rng:NextNumber(0.5, 0.9), rng:NextNumber(1.1, 1.7))
		part("PondStone", sz, CFrame.new(pos + Vector3.new(math.cos(a) * (r + 0.6), sz.Y * 0.3, math.sin(a) * (r + 0.6))) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), STONE, Enum.Material.Slate, parent)
	end
	for k = 1, 2 do
		local koi = part("Koi", Vector3.new(0.9, 0.2, 0.35), CFrame.new(pos + Vector3.new(0, 0.2, 0)), k == 1 and Color3.fromRGB(255, 140, 70) or Color3.fromRGB(250, 250, 250), Enum.Material.SmoothPlastic, parent)
		task.spawn(function()
			local t = k * 3
			while koi.Parent do
				t += 0.05
				local a = t * 0.5 * (k == 1 and 1 or -1)
				local p = pos + Vector3.new(math.cos(a) * r * 0.55, 0.2, math.sin(a) * r * 0.55)
				koi.CFrame = CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a)) * (k == 1 and 1 or -1))
				task.wait(0.05)
			end
		end)
	end
end

local function archeryTarget(pos: Vector3, faceTo: Vector3, parent: Instance)
	local face = CFrame.lookAt(pos + Vector3.new(0, 2.6, 0), Vector3.new(faceTo.X, pos.Y + 2.6, faceTo.Z))
	for _, x in ipairs({ -1, 1 }) do
		part("TargetLeg", Vector3.new(0.3, 3, 0.3), face * CFrame.new(x, -1.2, 0.4) * CFrame.Angles(math.rad(-12), 0, 0), WOOD_DARK, Enum.Material.Wood, parent)
	end
	for i, ring in ipairs({ { 3.2, Color3.fromRGB(250, 246, 238) }, { 2.4, Color3.fromRGB(214, 70, 58) }, { 1.6, Color3.fromRGB(250, 246, 238) }, { 0.8, Color3.fromRGB(214, 70, 58) } }) do
		local p = part("TargetRing", Vector3.new(0.12, ring[1], ring[1]), face * CFrame.new(0, 0, -0.05 * i) * CFrame.Angles(0, math.rad(90), 0), ring[2], Enum.Material.SmoothPlastic, parent)
		;(p :: Part).Shape = Enum.PartType.Cylinder
	end
end

local function steppingStones(from: Vector3, to: Vector3, parent: Instance)
	local n = math.floor((to - from).Magnitude / 2.6)
	for i = 0, n do
		local p = from:Lerp(to, i / math.max(1, n)) + Vector3.new(rng:NextNumber(-0.4, 0.4), 0.1, rng:NextNumber(-0.4, 0.4))
		disc("SteppingStone", rng:NextNumber(1.6, 2.1), 0.2, p, COBBLE:Lerp(COBBLE_DARK, rng:NextNumber(0, 0.5)), Enum.Material.Slate, parent)
	end
end

local function cloud(pos: Vector3, size: number, parent: Instance)
	for _ = 1, 4 do
		local s = size * rng:NextNumber(0.55, 1)
		local b = ball("Cloud", s, pos + Vector3.new(rng:NextNumber(-1, 1) * size * 0.8, rng:NextNumber(-0.1, 0.3) * size, rng:NextNumber(-1, 1) * size * 0.8), Color3.new(1, 1, 1), parent)
		b.Transparency = 0.15
	end
end

-- ── the practice range (behind spawn) ────────────────────────────────────────
type Dummy = { model: Model, root: BasePart, stand: CFrame, fluff: number }
local dummies: { Dummy } = {}
local RANGE = { x = 0, z = -36 }

local function resetDummy(d: Dummy)
	d.fluff = 0
	d.model:SetAttribute("Fluff", 0)
	d.root.AssemblyLinearVelocity = Vector3.zero
	d.root.AssemblyAngularVelocity = Vector3.zero
	d.model:PivotTo(d.stand)
end

local function buildRange(folder: Instance)
	local r = Instance.new("Folder")
	r.Name = "PracticeRange"
	r.Parent = folder
	torii(at(RANGE.x, RANGE.z + 12), r)
	for i, dx in ipairs({ -11, 0, 11 }) do
		local dz = RANGE.z - (i == 2 and 13 or 10)
		local deck = at(RANGE.x + dx, dz)
		disc("TargetDeck", 6, 0.3, deck + Vector3.new(0, 0.1, 0), WOOD, Enum.Material.WoodPlanks, r)
		disc("TargetDeckRing", 6.4, 0.2, deck + Vector3.new(0, 0.05, 0), Color3.fromRGB(250, 246, 238), Enum.Material.SmoothPlastic, r)
		archeryTarget(at(RANGE.x + dx, dz - 7), at(RANGE.x, 0), r)
		local stand = CFrame.lookAt(deck + Vector3.new(0, 1.9, 0), at(RANGE.x, 0, 1.9))
		local model = CatBuilder.Build(nil, "TARGET", nil)
		model.Name = "TARGET"
		model:SetAttribute("IsDummy", true)
		model:SetAttribute("Team", "Dummy")
		model:SetAttribute("Fluff", 0)
		local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		hum.WalkSpeed, hum.JumpPower = 0, 0
		hum.MaxHealth, hum.Health = 1e9, 1e9
		model:PivotTo(stand)
		model.Parent = r
		local root = model.PrimaryPart :: BasePart
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		table.insert(dummies, { model = model, root = root, stand = stand, fluff = 0 })
	end
	steppingStones(at(0, -16), at(0, RANGE.z + 10), r)
	local board = part("RangeSign", Vector3.new(10, 2.4, 0.3), CFrame.new(at(RANGE.x, RANGE.z + 12, 9.6)), INK, Enum.Material.SmoothPlastic, r)
	sign(board, Enum.NormalId.Back, { { text = "PRACTICE", size = 60, color = Color3.fromRGB(255, 226, 120) } })
	sign(board, Enum.NormalId.Front, { { text = "PRACTICE", size = 60, color = Color3.fromRGB(255, 226, 120) } })
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

-- A big title board on two posts, facing the middle.
local function titleSign(pos: Vector3, text: string, color: Color3, parent: Instance)
	local face = facingMiddle(pos + Vector3.new(0, 8, 0))
	for _, x in ipairs({ -6.5, 6.5 }) do
		part("SignPost", Vector3.new(0.7, 8, 0.7), face * CFrame.new(x, -4, 0.3), WOOD_DARK, Enum.Material.Wood, parent)
	end
	local board = part("TitleSign", Vector3.new(16, 3, 0.4), face, INK, Enum.Material.SmoothPlastic, parent)
	sign(board, Enum.NormalId.Front, { { text = text, size = 80, color = color } })
end

-- ── weapons showcase (left) ──────────────────────────────────────────────────
local function buildWeapons(folder: Instance)
	local f = Instance.new("Folder")
	f.Name = "WeaponShowcase"
	f.Parent = folder
	local list = Weapons.List
	for i, w in ipairs(list) do
		local row = (i - 1) // 5
		local col = (i - 1) % 5
		local pos = at(LEFT * (36 + row * 10), -18 + col * 9)
		local pedestal = ArenaKit.NewPart("Pedestal", Vector3.new(3, 3, 3), CFrame.new(pos + Vector3.new(0, 1.5, 0)), STONE, Enum.Material.Slate, f)
		part("PedestalTop", Vector3.new(3.4, 0.3, 3.4), CFrame.new(pos + Vector3.new(0, 3.1, 0)), WOOD_DARK, Enum.Material.Wood, f)
		-- Guns point along +X with their show side on +Z: turn that side to the middle.
		local toMiddle = Vector3.new(-LEFT, 0, 0)
		local base = CFrame.fromMatrix(pos + Vector3.new(0, 4.4, 0), Vector3.yAxis:Cross(toMiddle), Vector3.yAxis, toMiddle)
		local gun = BlasterBuilder.Build(w.Id, nil, base * CFrame.Angles(0, 0, math.rad(8)), 0.7)
		for _, p in ipairs(gun:GetDescendants()) do
			if p:IsA("BasePart") then
				deco(p)
			end
		end
		gun.Parent = f
		local plaque = part("Plaque", Vector3.new(2.8, 1, 0.1), facingMiddle(pos + Vector3.new(-LEFT * 1.56, 1.6, 0)), INK, Enum.Material.SmoothPlastic, f)
		sign(plaque, Enum.NormalId.Front, {
			{ text = string.upper(w.Name), size = 18, color = Color3.new(1, 1, 1) },
			{ text = string.upper(w.Class), size = 12, color = w.TrailColor },
		})
		prompt(pedestal, "Equip", w.Name, "Loadout", w.Id)
	end
	titleSign(at(LEFT * 54, 0), "ARMORY", Color3.fromRGB(150, 220, 255), f)
end

-- ── cosmetics showcase (right) ───────────────────────────────────────────────
local FEATURED = {
	{ Fur = "Galaxy", Outfit = "Royal", Hat = "DiamondCrown" },
	{ Fur = "Sakura", Outfit = "Streetwear", Hat = "PartyHat" },
	{ Fur = "Midnight", Outfit = "Ninja", Hat = "Headphones", Accessory = "Sunglasses" },
	{ Fur = "RoyalGold", Outfit = "Space", Hat = "Halo", Accessory = "Jetpack" },
}

local function buildCosmetics(folder: Instance)
	local f = Instance.new("Folder")
	f.Name = "CosmeticShowcase"
	f.Parent = folder
	for i, look in ipairs(FEATURED) do
		local pos = at(RIGHT * 40, -15 + (i - 1) * 10)
		local stage = ArenaKit.NewDisc("Stage", 5, 1, pos + Vector3.new(0, 0.5, 0), Color3.fromRGB(240, 236, 228), Enum.Material.Marble, f)
		disc("StageGlow", 5.4, 0.2, pos + Vector3.new(0, 0.1, 0), Color3.fromRGB(255, 214, 120), Enum.Material.Neon, f).Transparency = 0.4
		local cat = CatBuilder.Build(look, "Featured", nil)
		cat:SetAttribute("NoOverhead", true)
		for _, d in ipairs(cat:GetDescendants()) do
			if d:IsA("BasePart") then
				d.CanCollide = false
				d.CanQuery = false
			end
		end
		local root = cat.PrimaryPart :: BasePart
		root.Anchored = true
		cat:PivotTo(facingMiddle(pos + Vector3.new(0, 2.9, 0)))
		cat.Parent = f
		prompt(stage, "Shop", "Featured look", "Shop")
	end
	titleSign(at(RIGHT * 52, 0), "BOUTIQUE", Color3.fromRGB(255, 170, 210), f)
end

-- ── leaderboard board (front right) ──────────────────────────────────────────
local boardRows: { TextLabel } = {}

local function buildBoard(folder: Instance)
	local pos = at(RIGHT * 40, 40)
	local face = facingMiddle(pos + Vector3.new(0, 9, 0))
	for _, x in ipairs({ -9, 9 }) do
		ArenaKit.NewPart("BoardPost", Vector3.new(1, 9, 1), face * CFrame.new(x, -4.5, 0.6), WOOD_DARK, Enum.Material.Wood, folder)
	end
	local board = ArenaKit.NewPart("LeaderBoard", Vector3.new(20, 13, 0.6), face, INK, Enum.Material.SmoothPlastic, folder)
	part("BoardFrame", Vector3.new(21, 14, 0.4), face * CFrame.new(0, 0, 0.3), Color3.fromRGB(255, 214, 120), Enum.Material.Neon, folder)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 30
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.16, 0)
	title.Text = "TOP TROPHIES"
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 214, 90)
	title.Parent = gui
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.BackgroundTransparency = 1
		row.Position = UDim2.new(0.06, 0, 0.17 + (i - 1) * 0.08, 0)
		row.Size = UDim2.new(0.88, 0, 0.075, 0)
		row.Font = Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i <= 3 and ({ Color3.fromRGB(255, 214, 90), Color3.fromRGB(210, 220, 235), Color3.fromRGB(226, 150, 96) })[i] or Color3.new(1, 1, 1)
		row.Text = ""
		row.Parent = gui
		boardRows[i] = row
	end
end

local function refreshBoard()
	local ok, entries = pcall(LeaderboardService.Top, "Trophies")
	if not ok or typeof(entries) ~= "table" then
		return
	end
	for i, row in ipairs(boardRows) do
		local e = entries[i]
		row.Text = e and string.format("%d.  %s  —  %d", i, tostring(e.name), math.floor(tonumber(e.value) or 0)) or ""
	end
end

-- ── the island ───────────────────────────────────────────────────────────────
local function buildLobby()
	local f = Instance.new("Folder")
	f.Name = "Lobby"
	-- The intro cinematic and Mochi's lesson (client) stage themselves here.
	f:SetAttribute("Center", CENTER)
	f:SetAttribute("Surface", SURFACE_Y)
	f:SetAttribute("Stage", at(0, 14))
	f:SetAttribute("Range", at(RANGE.x, RANGE.z))
	f.Parent = Workspace
	ArenaKit.MakeIslandBase(CENTER, RADIUS, "Island", PALETTE, Enum.Material.Grass, f)
	local top = f:FindFirstChild("Floor", true)
	if top and top:IsA("BasePart") then
		top.Color = GRASS
	end
	local d = Instance.new("Folder")
	d.Name = "Garden"
	d.Parent = f
	-- Spawn plaza with lanterns.
	disc("PlazaRim", 30.6, 0.22, at(0, -4, 0.05), COBBLE_DARK, Enum.Material.Slate, d)
	disc("Plaza", 29, 0.22, at(0, -4, 0.08), COBBLE, Enum.Material.Cobblestone, d)
	for _, p in ipairs({ { -13, -14 }, { 13, -14 }, { -14, 8 }, { 14, 8 } }) do
		lantern(at(p[1], p[2]), d)
	end
	steppingStones(at(0, 11), at(0, 26), d)
	-- Railings round the edge (solid) so you stay in - except behind the
	-- practice range, where the target cats get knocked off the island.
	local posts = math.floor(2 * math.pi * (RADIUS - 3) / 6)
	local prev: Vector3? = nil
	for k = 0, posts do
		local a = k / posts * math.pi * 2
		local p = at(math.cos(a) * (RADIUS - 3), math.sin(a) * (RADIUS - 3))
		local rel = p - CENTER
		if not (rel.Z < 0 and math.abs(rel.X) < 22.5) then
			ArenaKit.NewPart("RailPost", Vector3.new(0.6, 4, 0.6), CFrame.new(p + Vector3.new(0, 2, 0)), WOOD_DARK, Enum.Material.Wood, d)
		end
		local mid = prev and (prev + p) / 2 - CENTER
		if prev and mid and not (mid.Z < 0 and math.abs(mid.X) < 26) then
			for _, y in ipairs({ 1.6, 3.4 }) do
				local rail = ArenaKit.Beam("RailBar", prev + Vector3.new(0, y, 0), p + Vector3.new(0, y, 0), 0.4, WOOD, Enum.Material.Wood, d)
				rail.CanCollide = true
			end
			-- Invisible wall above the rail: no jumping out of the lobby.
			local wall = ArenaKit.Beam("LobbyWall", prev + Vector3.new(0, 20, 0), p + Vector3.new(0, 20, 0), 1, WOOD, nil, d)
			wall.Size = Vector3.new(1, 40, wall.Size.Z + 0.5)
			wall.Transparency = 1
			wall.CanCollide = true
			wall.CanQuery = false
			wall.CastShadow = false
		end
		prev = p
	end
	-- Trees, bushes and a koi pond round the edge.
	for _, t in ipairs({ { -50, -30 }, { 50, -30 }, { -52, 22 }, { 46, 36 }, { -24, -54 }, { 24, -54 }, { 20, 54 }, { 0, 57 } }) do
		blossomTree(at(t[1], t[2]), rng:NextNumber(0.9, 1.2), d)
	end
	for _, b in ipairs({ { -20, -24 }, { 20, -26 }, { -56, 12 }, { 56, -14 }, { 34, 48 }, { -40, -44 }, { 44, -44 }, { -12, 56 } }) do
		bush(at(b[1], b[2]), d)
	end
	pond(at(LEFT * 32, -40), 5, d)

	buildRange(f)
	buildWeapons(f)
	buildCosmetics(f)
	buildBoard(f)

	-- Around the island: clouds below and a waterfall off the edge.
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = f
	local fall = part("Waterfall", Vector3.new(1, 80, 6), CFrame.new(at(-RADIUS + 1, -20, -40)), Color3.fromRGB(190, 230, 250), Enum.Material.Glass, scenery)
	fall.Transparency = 0.35
	for _ = 1, 18 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(70, 170)
		cloud(Vector3.new(CENTER.X + math.cos(a) * r, CENTER.Y + rng:NextNumber(-45, -15), CENTER.Z + math.sin(a) * r), rng:NextNumber(12, 24), scenery)
	end
end

-- ── players ──────────────────────────────────────────────────────────────────
local function spawnCFrame(): CFrame
	local p = at(rng:NextNumber(-4, 4), -8 + rng:NextNumber(-2, 2), 1.9)
	return CFrame.lookAt(p, p + Vector3.new(0, 0, 1)) -- facing the duel pads
end

-- Put a player (back) in the lobby.
function LobbyService.Spawn(player: Player)
	if not player.Parent then
		return
	end
	PlayerService.Spawn(player, { context = "Lobby", team = "Lobby", cframe = spawnCFrame() })
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
	refreshBoard()
	task.spawn(function()
		while true do
			task.wait(60)
			refreshBoard()
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		for _, dm in ipairs(dummies) do
			if dm.root.Position.Y < FALL_Y or (dm.root.Position - CENTER).Magnitude > 400 then
				resetDummy(dm)
			end
		end
		-- Anyone who falls off the lobby is put back in the middle.
		for _, p in ipairs(Players:GetPlayers()) do
			local root = p:GetAttribute("Context") == "Lobby" and p.Character and p.Character.PrimaryPart
			if root and root.Position.Y < FALL_Y then
				p.Character:PivotTo(spawnCFrame())
				root.AssemblyLinearVelocity = Vector3.zero
			end
		end
	end)
end

return LobbyService
