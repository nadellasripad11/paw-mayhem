--!strict
-- PracticeService: a floating practice island away from the arena, open
-- between matches: a calm training garden in the sky. PRACTICE in the menu
-- drops you there with your loadout; three target cats stand on wooden
-- decks - blast them and watch their knockback % climb until they fly off
-- the edge (they reset themselves). Fall off and you're put back. When a
-- match starts, everyone practising is pulled out.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local CatBuilder = require(Shared.Character.CatBuilder)
local Knockback = require(Shared.Character.Knockback)

local PlayerService = require(script.Parent.PlayerService)
local WeaponService = require(script.Parent.WeaponService)
local ArenaKit = require(script.Parent.Parent.World.ArenaKit)

local PracticeService = {}

local CENTER = Vector3.new(0, 120, 2600)
local RADIUS = 32
local SURFACE_Y = CENTER.Y + ArenaKit.SURFACE
local FALL_Y = CENTER.Y - 45
local PALETTE: ArenaKit.Palette = {
	Top = Color3.fromRGB(122, 200, 108), TopDark = Color3.fromRGB(96, 170, 86),
	Stone = Color3.fromRGB(150, 144, 136), StoneDark = Color3.fromRGB(118, 112, 110),
	Wood = Color3.fromRGB(176, 124, 72), WoodDark = Color3.fromRGB(120, 82, 50),
}

type Dummy = { model: Model, root: BasePart, stand: CFrame, fluff: number }
local dummies: { Dummy } = {}

local function standAt(angle: number, dist: number): CFrame
	local p = Vector3.new(CENTER.X + math.cos(angle) * dist, SURFACE_Y + 1.9, CENTER.Z + math.sin(angle) * dist)
	return CFrame.lookAt(p, Vector3.new(CENTER.X, p.Y, CENTER.Z))
end

local function resetDummy(d: Dummy)
	d.fluff = 0
	d.model:SetAttribute("Fluff", 0)
	d.root.AssemblyLinearVelocity = Vector3.zero
	d.root.AssemblyAngularVelocity = Vector3.zero
	d.model:PivotTo(d.stand)
end

-- ── the training garden ──────────────────────────────────────────────────────
-- A calm little sky garden in soft colours: cobbled circle in the middle, a
-- red gate by the spawn, blossom trees shedding petals, stone lanterns, a
-- koi pond, stepping stones out to the target range (wooden platforms with
-- archery targets behind), and small floating islets, a waterfall and clouds
-- around it. Only the island top is solid; everything else is decoration.

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

local grng = Random.new(20260925)

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

-- Ground point on the island at (x, z) offsets from the centre.
local function at(dx: number, dz: number, lift: number?): Vector3
	return Vector3.new(CENTER.X + dx, SURFACE_Y + (lift or 0), CENTER.Z + dz)
end

local function blossomTree(pos: Vector3, s: number, parent: Instance)
	local h = 5 * s
	part("Trunk", Vector3.new(0.9 * s, h, 0.9 * s), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(grng:NextNumber(-6, 6))), WOOD_DARK, Enum.Material.Wood, parent)
	local top = pos + Vector3.new(0, h + 1.2 * s, 0)
	ball("Blossom", 6.2 * s, top, BLOSSOM[1], parent)
	for k = 1, 5 do
		local a = k / 5 * math.pi * 2 + grng:NextNumber(-0.3, 0.3)
		ball("Blossom", grng:NextNumber(3.4, 4.6) * s, top + Vector3.new(math.cos(a) * 2.6 * s, grng:NextNumber(-1, 0.8) * s, math.sin(a) * 2.6 * s), BLOSSOM[grng:NextInteger(1, 3)], parent)
	end
	-- Petals drifting down.
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(BLOSSOM[2])
	e.Size = NumberSequence.new(0.35)
	e.Lifetime = NumberRange.new(4, 6)
	e.Rate = 2.5
	e.Speed = NumberRange.new(0.5, 1.5)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0.6, -1.4, 0.3)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Parent = ball("Canopy", 0.1, top, BLOSSOM[1], parent)
end

local function bush(pos: Vector3, parent: Instance)
	for k = 1, 3 do
		local d = grng:NextNumber(1.8, 2.8)
		local a = k * 2.1
		ball("Bush", d, pos + Vector3.new(math.cos(a) * 0.9, d * 0.3, math.sin(a) * 0.9), LEAF[grng:NextInteger(1, 2)], parent)
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
		part("GateFoot", Vector3.new(1.3, 0.6, 1.3), CFrame.new(pos + Vector3.new(x, 0.3, 0)), Color3.fromRGB(60, 50, 48), Enum.Material.SmoothPlastic, parent)
	end
	part("GateTop", Vector3.new(11.6, 0.7, 1.2), CFrame.new(pos + Vector3.new(0, 7.8, 0)), Color3.fromRGB(58, 48, 46), Enum.Material.SmoothPlastic, parent)
	part("GateBeam", Vector3.new(10.6, 0.6, 1.0), CFrame.new(pos + Vector3.new(0, 7.1, 0)), TORII, Enum.Material.SmoothPlastic, parent)
	part("GateTie", Vector3.new(9.4, 0.45, 0.7), CFrame.new(pos + Vector3.new(0, 5.8, 0)), TORII, Enum.Material.SmoothPlastic, parent)
end

local function pond(pos: Vector3, r: number, parent: Instance)
	disc("PondBed", r * 2 + 0.6, 0.2, pos + Vector3.new(0, 0.05, 0), Color3.fromRGB(96, 110, 104), Enum.Material.Slate, parent)
	local water = disc("Pond", r * 2, 0.2, pos + Vector3.new(0, 0.15, 0), WATER, Enum.Material.Glass, parent)
	water.Transparency = 0.25
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		local sz = Vector3.new(grng:NextNumber(1.2, 1.9), grng:NextNumber(0.5, 0.9), grng:NextNumber(1.1, 1.7))
		part("PondStone", sz, CFrame.new(pos + Vector3.new(math.cos(a) * (r + 0.6), sz.Y * 0.3, math.sin(a) * (r + 0.6))) * CFrame.Angles(0, grng:NextNumber(0, 6.28), 0), STONE, Enum.Material.Slate, parent)
	end
	for k = 1, 3 do
		local a = grng:NextNumber(0, 6.28)
		disc("LilyPad", 1.1, 0.06, pos + Vector3.new(math.cos(a) * r * 0.5, 0.28, math.sin(a) * r * 0.5), LEAF[1], Enum.Material.SmoothPlastic, parent)
	end
	-- Two koi circling slowly.
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

-- Archery target on two legs, facing the plaza.
local function archeryTarget(pos: Vector3, parent: Instance)
	local face = CFrame.lookAt(pos + Vector3.new(0, 2.6, 0), Vector3.new(CENTER.X, pos.Y + 2.6, CENTER.Z))
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
		local p = from:Lerp(to, i / math.max(1, n)) + Vector3.new(grng:NextNumber(-0.4, 0.4), 0.1, grng:NextNumber(-0.4, 0.4))
		disc("SteppingStone", grng:NextNumber(1.6, 2.1), 0.2, p, COBBLE:Lerp(COBBLE_DARK, grng:NextNumber(0, 0.5)), Enum.Material.Slate, parent)
	end
end

local function islet(pos: Vector3, r: number, parent: Instance)
	ArenaKit.MakeIslandBase(pos, r, "Islet", PALETTE, Enum.Material.Grass, parent)
	for _, d in ipairs(parent:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	blossomTree(pos + Vector3.new(grng:NextNumber(-1, 1), ArenaKit.SURFACE, grng:NextNumber(-1, 1)), 0.8, parent)
end

local function cloud(pos: Vector3, size: number, parent: Instance)
	for k = 1, 4 do
		local s = size * grng:NextNumber(0.55, 1)
		local b = ball("Cloud", s, pos + Vector3.new(grng:NextNumber(-1, 1) * size * 0.8, grng:NextNumber(-0.1, 0.3) * size, grng:NextNumber(-1, 1) * size * 0.8), Color3.new(1, 1, 1), parent)
		b.Transparency = 0.15
	end
end

local function decorate(folder: Folder)
	local d = Instance.new("Folder")
	d.Name = "Garden"
	d.Parent = folder
	-- Soften the grass colour of the island top.
	local top = folder:FindFirstChild("Floor", true)
	if top and top:IsA("BasePart") then
		top.Color = GRASS
	end
	-- Cobbled circle in the middle, with a paver ring.
	disc("PlazaRim", 24.6, 0.22, at(0, -4, 0.05), COBBLE_DARK, Enum.Material.Slate, d)
	disc("Plaza", 23, 0.22, at(0, -4, 0.08), COBBLE, Enum.Material.Cobblestone, d)
	-- Red gate behind the spawn, lanterns round the plaza.
	torii(at(0, -19), d)
	for _, p in ipairs({ { -10, -12 }, { 10, -12 }, { -11, 4 }, { 11, 4 } }) do
		lantern(at(p[1], p[2]), d)
	end
	-- Koi pond on the left, blossom trees and bushes round the edge.
	pond(at(-19, 4), 4.6, d)
	for _, t in ipairs({ { -24, -10, 1.1 }, { 22, -12, 1.2 }, { -22, 18, 1 }, { 25, 10, 0.9 }, { 6, -27, 0.8 }, { -12, -26, 0.9 } }) do
		blossomTree(at(t[1], t[2]), t[3], d)
	end
	for _, b in ipairs({ { -16, -16 }, { 16, -18 }, { -28, 2 }, { 28, -2 }, { 14, 26 }, { -8, 29 } }) do
		bush(at(b[1], b[2]), d)
	end
	-- Target range: wooden platforms (under the target cats) and archery
	-- targets behind them, with stepping stones from the plaza.
	for k = 0, 2 do
		local a = math.rad(60 + k * 30)
		local p = at(math.cos(a) * RADIUS * 0.62, math.sin(a) * RADIUS * 0.62)
		disc("TargetDeck", 6, 0.3, p + Vector3.new(0, 0.1, 0), WOOD, Enum.Material.WoodPlanks, d)
		disc("TargetDeckRing", 6.4, 0.2, p + Vector3.new(0, 0.05, 0), Color3.fromRGB(250, 246, 238), Enum.Material.SmoothPlastic, d)
		archeryTarget(at(math.cos(a) * RADIUS * 0.84, math.sin(a) * RADIUS * 0.84), d)
	end
	steppingStones(at(0, 8), at(0, 18), d)
	-- Around the island: floating islets, a waterfall off the edge, clouds.
	local scenery = Instance.new("Folder")
	scenery.Name = "Scenery"
	scenery.Parent = folder
	for _, s in ipairs({ { -70, -10, 30, 6 }, { 64, 22, -20, 7 }, { -30, -8, 72, 5 }, { 40, 18, 66, 5 }, { 10, 30, -74, 6 } }) do
		local f = Instance.new("Folder")
		f.Parent = scenery
		islet(Vector3.new(CENTER.X + s[1], CENTER.Y + s[2], CENTER.Z + s[3]), s[4], f)
	end
	local fallTop = at(-RADIUS + 1, 12, -0.3)
	local fall = part("Waterfall", Vector3.new(1, 70, 5), CFrame.new(fallTop - Vector3.new(1.5, 35, 0)), Color3.fromRGB(190, 230, 250), Enum.Material.Glass, scenery)
	fall.Transparency = 0.35
	for k = 1, 16 do
		local a = grng:NextNumber(0, math.pi * 2)
		local r = grng:NextNumber(45, 140)
		cloud(Vector3.new(CENTER.X + math.cos(a) * r, CENTER.Y + grng:NextNumber(-40, -12), CENTER.Z + math.sin(a) * r), grng:NextNumber(10, 22), scenery)
	end
end

local function buildIsland()
	local folder = Instance.new("Folder")
	folder.Name = "PracticeIsland"
	-- The intro cinematic and the mentor lesson (client) stage themselves here.
	folder:SetAttribute("Center", CENTER)
	folder:SetAttribute("Surface", SURFACE_Y)
	folder.Parent = Workspace
	ArenaKit.MakeIslandBase(CENTER, RADIUS, "Island", PALETTE, Enum.Material.Grass, folder)
	decorate(folder)
	-- Three target cats on glowing pads, spread round the far side.
	for k = 0, 2 do
		local angle = math.rad(60 + k * 30)
		local stand = standAt(angle, RADIUS * 0.62)
		local model = CatBuilder.Build(nil, "TARGET", nil)
		model.Name = "TARGET"
		model:SetAttribute("IsDummy", true)
		model:SetAttribute("Team", "Dummy")
		model:SetAttribute("Fluff", 0)
		local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.MaxHealth = 1e9
		hum.Health = 1e9
		model:PivotTo(stand)
		model.Parent = folder
		local root = model.PrimaryPart :: BasePart
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		table.insert(dummies, { model = model, root = root, stand = stand, fluff = 0 })
	end
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

local function spawnAt(player: Player)
	PlayerService.Spawn(player)
	local char = player.Character
	if char then
		local a = math.random() * math.pi * 2
		local p = Vector3.new(CENTER.X + math.cos(a) * 6, SURFACE_Y + 3, CENTER.Z - 12 + math.sin(a) * 4)
		char:PivotTo(CFrame.lookAt(p, Vector3.new(CENTER.X, p.Y, CENTER.Z + 20)))
	end
end

function PracticeService.Leave(player: Player)
	if not player:GetAttribute("Practicing") then
		return
	end
	player:SetAttribute("Practicing", nil)
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end
end

-- A match is starting: everyone practising goes back to the lobby.
function PracticeService.EndAll()
	for _, p in ipairs(Players:GetPlayers()) do
		PracticeService.Leave(p)
	end
end

function PracticeService.Start()
	buildIsland()
	WeaponService.OnDummyHit = hitDummy

	Remotes.Get("Practice").OnServerEvent:Connect(function(player, on)
		if on == true then
			if PlayerService.MatchActive or player:GetAttribute("Practicing") then
				return
			end
			player:SetAttribute("Practicing", true)
			spawnAt(player)
		else
			PracticeService.Leave(player)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		-- Targets knocked off the island come back fresh.
		for _, d in ipairs(dummies) do
			if d.root.Position.Y < FALL_Y or (d.root.Position - CENTER).Magnitude > 400 then
				resetDummy(d)
			end
		end
		-- Players who fall off are put back on.
		for _, p in ipairs(Players:GetPlayers()) do
			local root = p:GetAttribute("Practicing") and p.Character and p.Character.PrimaryPart
			if root and root.Position.Y < FALL_Y then
				spawnAt(p)
			end
		end
	end)
end

return PracticeService
