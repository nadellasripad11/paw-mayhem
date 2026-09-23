-- LobbyScene: the real 3D world behind the home screen. Built locally on each
-- client (never replicated) far away from the arena, so the menu camera looks at
-- an actual lit scene: your own cat holding your blaster on a mossy ledge,
-- floating islands with windmills, houses and waterfalls, clouds, flowers and
-- fences. Everything is procedural Parts — no Toolbox models.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)
local BlasterBuilder = require(ReplicatedStorage.Shared.Character.BlasterBuilder)
local ClientState = require(script.Parent.Parent.ClientState)

local LobbyScene = {}
LobbyScene.FieldOfView = 50

local ORIGIN = Vector3.new(0, 260, -2600)
local SCENE = CFrame.new(ORIGIN)
-- Scene space: camera looks down -Z, +X is screen right, +Z is toward camera.
local CAMERA_POS = Vector3.new(0, 9, 27.5)
local CAMERA_LOOK = Vector3.new(1, 7.4, 0)

local folder: Folder? = nil
local built = false
local active = false
local rng = Random.new(1422)
local animators: { (number) -> () } = {}
local postEffects: { Instance } = {}
local cloudsInstance: Instance? = nil
local ownAtmosphere: Atmosphere? = nil
local saved: { [string]: any }? = nil
local savedAtmo: { [string]: any }? = nil
local renderConn: RBXScriptConnection? = nil
local lightingConns: { RBXScriptConnection } = {}

local LIGHTING = {
	ClockTime = 14.2,
	-- Kept moderate: brighter settings pushed white fur and flowers past the
	-- bloom threshold and washed the whole mascot out.
	Brightness = 2.1,
	Ambient = Color3.fromRGB(100, 108, 130),
	OutdoorAmbient = Color3.fromRGB(146, 154, 176),
	EnvironmentDiffuseScale = 0.6,
	EnvironmentSpecularScale = 0.4,
	ExposureCompensation = -0.2,
	ShadowSoftness = 0.35,
	FogEnd = 100000,
	GlobalShadows = true,
}

local ATMOSPHERE = {
	Density = 0.4,
	Offset = 0.25,
	Color = Color3.fromRGB(206, 230, 252),
	Decay = Color3.fromRGB(120, 170, 228),
	Glare = 0.55,
	Haze = 1.9,
}

-- Palette
local GRASS_TOP = Color3.fromRGB(116, 198, 76)
local GRASS_DARK = Color3.fromRGB(82, 162, 62)
local GRASS_BLADES = { Color3.fromRGB(96, 184, 70), Color3.fromRGB(128, 206, 84), Color3.fromRGB(74, 150, 58) }
local LEAVES = { Color3.fromRGB(92, 176, 72), Color3.fromRGB(112, 194, 82), Color3.fromRGB(74, 152, 64) }
local ROCK = { Color3.fromRGB(176, 146, 118), Color3.fromRGB(154, 124, 101), Color3.fromRGB(132, 108, 92), Color3.fromRGB(190, 164, 134) }
local TRUNK = Color3.fromRGB(122, 86, 60)
local WOOD = Color3.fromRGB(150, 104, 70)
local WOOD_LIGHT = Color3.fromRGB(176, 128, 86)
local WOOD_DARK = Color3.fromRGB(96, 64, 44)
local PLASTER = Color3.fromRGB(240, 224, 196)
local ROOF = Color3.fromRGB(190, 96, 62)
local ROOF_DARK = Color3.fromRGB(128, 76, 56)
local SAIL = Color3.fromRGB(246, 238, 220)
local STEM = Color3.fromRGB(86, 164, 70)
local YELLOW = Color3.fromRGB(255, 212, 76)
local WHITE = Color3.new(1, 1, 1)

local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- ── primitive helpers ────────────────────────────────────────────────────────
local function W(x: number, y: number, z: number): CFrame
	return SCENE * CFrame.new(x, y, z)
end

local function newPart(className: string, parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local p = Instance.new(className) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function block(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return newPart("Part", parent, size, cf, color, material)
end

-- Ellipsoid (a Ball part is forced uniform; a Sphere mesh stretches to Size).
local function ell(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local p = newPart("Part", parent, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Cylinder whose axis runs along cf's X axis.
local function cyl(parent: Instance, length: number, dia: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	local p = newPart("Part", parent, Vector3.new(length, dia, dia), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function vcyl(parent: Instance, height: number, dia: number, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return cyl(parent, height, dia, cf * CFrame.Angles(0, 0, math.pi / 2), color, material)
end

local function wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): BasePart
	return newPart("WedgePart", parent, size, cf, color, material)
end

-- Isosceles triangle prism (apex up) from two mirrored wedges. `cf` sits at the
-- middle of the base edge; the triangle lies in cf's XY plane.
local function triangle(parent: Instance, cf: CFrame, halfWidth: number, height: number, thickness: number, color: Color3, material: Enum.Material?): { BasePart }
	local size = Vector3.new(thickness, height, halfWidth)
	local a = wedge(parent, size, cf * CFrame.new(-halfWidth / 2, height / 2, 0) * CFrame.Angles(0, math.rad(90), 0), color, material)
	local b = wedge(parent, size, cf * CFrame.new(halfWidth / 2, height / 2, 0) * CFrame.Angles(0, math.rad(-90), 0), color, material)
	return { a, b }
end

-- Gable roof: ridge runs along cf's Z axis, `cf` at the roof's center.
local function gable(parent: Instance, cf: CFrame, width: number, height: number, depth: number, color: Color3)
	triangle(parent, cf * CFrame.new(0, -height / 2, 0), width / 2, height, depth, color, Enum.Material.SmoothPlastic)
end

local function noShadows(model: Instance)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
end

-- ── decorations ──────────────────────────────────────────────────────────────
local function tree(parent: Instance, x: number, y: number, z: number, s: number)
	vcyl(parent, 3.2 * s, 0.75 * s, W(x, y + 1.6 * s, z), TRUNK, Enum.Material.Wood)
	ell(parent, Vector3.new(4.2, 3.6, 4.2) * s, W(x, y + 4.3 * s, z), LEAVES[1])
	ell(parent, Vector3.new(3.0, 2.6, 3.0) * s, W(x - 1.3 * s, y + 3.6 * s, z + 0.6 * s), LEAVES[2])
	ell(parent, Vector3.new(3.0, 2.8, 3.0) * s, W(x + 1.2 * s, y + 3.8 * s, z - 0.4 * s), LEAVES[3])
	ell(parent, Vector3.new(2.6, 2.2, 2.6) * s, W(x + 0.2 * s, y + 5.9 * s, z + 0.2 * s), LEAVES[2])
end

local function bush(parent: Instance, x: number, y: number, z: number, s: number)
	ell(parent, Vector3.new(3.4, 2.4, 3.0) * s, W(x, y + 0.9 * s, z), LEAVES[1])
	ell(parent, Vector3.new(2.4, 1.9, 2.2) * s, W(x - 1.4 * s, y + 0.7 * s, z + 0.4 * s), LEAVES[3])
	ell(parent, Vector3.new(2.2, 1.8, 2.0) * s, W(x + 1.5 * s, y + 0.7 * s, z + 0.2 * s), LEAVES[2])
end

local function house(parent: Instance, x: number, y: number, z: number, s: number, yaw: number)
	local b = W(x, y, z) * CFrame.Angles(0, yaw, 0)
	block(parent, Vector3.new(4, 3.2, 3.6) * s, b * CFrame.new(0, 1.6 * s, 0), PLASTER)
	for _, dx in ipairs({ -1, 1 }) do
		block(parent, Vector3.new(0.35, 3.3, 0.35) * s, b * CFrame.new(dx * 2 * s, 1.65 * s, 1.8 * s), WOOD_DARK, Enum.Material.Wood)
		block(parent, Vector3.new(0.35, 3.3, 0.35) * s, b * CFrame.new(dx * 2 * s, 1.65 * s, -1.8 * s), WOOD_DARK, Enum.Material.Wood)
	end
	block(parent, Vector3.new(4.2, 0.35, 0.35) * s, b * CFrame.new(0, 3.15 * s, 1.8 * s), WOOD_DARK, Enum.Material.Wood)
	gable(parent, b * CFrame.new(0, 3.2 * s + 1.1 * s, 0), 5 * s, 2.2 * s, 4.4 * s, ROOF)
	block(parent, Vector3.new(1, 1.7, 0.2) * s, b * CFrame.new(0.7 * s, 0.85 * s, 1.82 * s), WOOD_DARK, Enum.Material.Wood)
	block(parent, Vector3.new(0.9, 0.8, 0.2) * s, b * CFrame.new(-1.0 * s, 1.95 * s, 1.82 * s), Color3.fromRGB(255, 222, 150))
	block(parent, Vector3.new(0.6, 1.4, 0.6) * s, b * CFrame.new(1.2 * s, 4.6 * s, -0.8 * s), Color3.fromRGB(170, 150, 140), Enum.Material.Brick)
end

-- A lookout hut on stilts like the one on the reference's right island.
local function hut(parent: Instance, x: number, y: number, z: number, s: number, yaw: number)
	local b = W(x, y, z) * CFrame.Angles(0, yaw, 0)
	for _, dx in ipairs({ -1, 1 }) do
		for _, dz in ipairs({ -1, 1 }) do
			block(parent, Vector3.new(0.4, 3, 0.4) * s, b * CFrame.new(dx * 1.8 * s, 1.5 * s, dz * 1.6 * s), WOOD_DARK, Enum.Material.Wood)
		end
	end
	block(parent, Vector3.new(4.4, 0.4, 4) * s, b * CFrame.new(0, 3.1 * s, 0), WOOD_LIGHT, Enum.Material.WoodPlanks)
	block(parent, Vector3.new(3.6, 2.4, 3.2) * s, b * CFrame.new(0, 4.5 * s, 0), WOOD, Enum.Material.WoodPlanks)
	block(parent, Vector3.new(1.2, 0.9, 0.2) * s, b * CFrame.new(0, 4.7 * s, 1.62 * s), Color3.fromRGB(255, 222, 150))
	gable(parent, b * CFrame.new(0, 5.7 * s + 1.1 * s, 0), 5 * s, 2.2 * s, 4.4 * s, ROOF_DARK)
	block(parent, Vector3.new(4.6, 0.25, 0.25) * s, b * CFrame.new(0, 3.9 * s, 2 * s), WOOD_LIGHT, Enum.Material.Wood)
end

type Windmill = { hub: CFrame, parts: { BasePart }, rel: { CFrame }, speed: number, island: any }

local function windmill(parent: Instance, x: number, y: number, z: number, s: number, yaw: number): Windmill
	local b = W(x, y, z) * CFrame.Angles(0, yaw, 0)
	block(parent, Vector3.new(3.6, 3, 3.6) * s, b * CFrame.new(0, 1.5 * s, 0), Color3.fromRGB(206, 196, 180), Enum.Material.Slate)
	block(parent, Vector3.new(3.0, 3, 3.0) * s, b * CFrame.new(0, 4.5 * s, 0), WOOD_LIGHT, Enum.Material.WoodPlanks)
	block(parent, Vector3.new(2.6, 2.2, 2.6) * s, b * CFrame.new(0, 7.1 * s, 0), WOOD, Enum.Material.WoodPlanks)
	gable(parent, b * CFrame.new(0, 8.2 * s + 0.9 * s, 0), 3.4 * s, 1.8 * s, 3.2 * s, ROOF_DARK)
	block(parent, Vector3.new(0.9, 1.5, 0.2) * s, b * CFrame.new(0, 0.75 * s, 1.82 * s), WOOD_DARK, Enum.Material.Wood)
	block(parent, Vector3.new(0.7, 0.7, 0.2) * s, b * CFrame.new(0, 4.6 * s, 1.52 * s), Color3.fromRGB(255, 222, 150))
	local hub = b * CFrame.new(0, 7.2 * s, 1.55 * s)
	cyl(parent, 0.9 * s, 0.9 * s, hub * CFrame.Angles(0, math.pi / 2, 0), WOOD_DARK, Enum.Material.Wood)
	local parts, rel = {}, {}
	for i = 0, 3 do
		local spin = CFrame.Angles(0, 0, i * math.pi / 2)
		local armRel = spin * CFrame.new(0, 2.5 * s, 0.55 * s)
		local sailRel = spin * CFrame.new(0.72 * s, 2.9 * s, 0.5 * s)
		table.insert(parts, block(parent, Vector3.new(0.28, 4.6, 0.22) * s, hub * armRel, WOOD_DARK, Enum.Material.Wood))
		table.insert(rel, armRel)
		table.insert(parts, block(parent, Vector3.new(1.35, 3.6, 0.1) * s, hub * sailRel, SAIL, Enum.Material.Fabric))
		table.insert(rel, sailRel)
	end
	for _, p in ipairs(parts) do
		p:SetAttribute("Spin", true)
	end
	return { hub = hub, parts = parts, rel = rel, speed = rng:NextNumber(0.55, 0.9), island = nil }
end

local function flower(parent: Instance, x: number, y: number, z: number, s: number, petal: Color3, center: Color3?)
	local stemH = 1.8 * s
	vcyl(parent, stemH, 0.16 * s, W(x, y + stemH / 2, z), STEM)
	ell(parent, Vector3.new(0.9, 0.18, 0.45) * s, W(x + 0.35 * s, y + stemH * 0.4, z) * CFrame.Angles(0, 0, math.rad(25)), STEM)
	ell(parent, Vector3.new(0.9, 0.18, 0.45) * s, W(x - 0.35 * s, y + stemH * 0.3, z) * CFrame.Angles(0, 0, math.rad(-25)), STEM)
	local head = W(x, y + stemH, z) * CFrame.Angles(math.rad(50), 0, 0)
	for i = 0, 4 do
		local a = i * (2 * math.pi / 5)
		ell(parent, Vector3.new(0.95, 0.2, 0.62) * s, head * CFrame.Angles(0, a, 0) * CFrame.new(0.5 * s, 0, 0), petal)
	end
	ell(parent, Vector3.new(0.5, 0.3, 0.5) * s, head * CFrame.new(0, 0.08 * s, 0), center or YELLOW)
end

local function tuft(parent: Instance, x: number, y: number, z: number, s: number)
	for _ = 1, 4 do
		local h = rng:NextNumber(0.9, 1.7) * s
		block(parent, Vector3.new(0.22 * s, h, 0.08 * s),
			W(x + rng:NextNumber(-0.35, 0.35) * s, y + h / 2 - 0.05, z + rng:NextNumber(-0.3, 0.3) * s)
				* CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.35, 0.35)),
			GRASS_BLADES[rng:NextInteger(1, #GRASS_BLADES)])
	end
end

local function fence(parent: Instance, a: Vector3, b: Vector3, posts: number, s: number)
	local prev: Vector3? = nil
	for i = 0, posts - 1 do
		local p = a:Lerp(b, i / (posts - 1))
		block(parent, Vector3.new(0.7, 3.4, 0.7) * s, W(p.X, p.Y + 1.7 * s, p.Z), WOOD, Enum.Material.Wood)
		gable(parent, W(p.X, p.Y + 3.4 * s + 0.25 * s, p.Z), 0.72 * s, 0.5 * s, 0.72 * s, WOOD)
		if prev then
			for _, hy in ipairs({ 1.2, 2.5 }) do
				local p1 = W(prev.X, prev.Y + hy * s, prev.Z).Position
				local p2 = W(p.X, p.Y + hy * s, p.Z).Position
				block(parent, Vector3.new(0.22 * s, 0.45 * s, (p2 - p1).Magnitude + 0.4), CFrame.lookAt((p1 + p2) / 2, p2), WOOD_LIGHT, Enum.Material.Wood)
			end
		end
		prev = p
	end
end

local function cloud(parent: Instance, x: number, y: number, z: number, s: number)
	for i = 1, 6 do
		local p = ell(parent,
			Vector3.new(rng:NextNumber(6, 10), rng:NextNumber(3.5, 5.5), rng:NextNumber(5, 8)) * s,
			W(x + (i - 3.5) * 3 * s + rng:NextNumber(-1, 1) * s, y + rng:NextNumber(-0.8, 1.2) * s, z + rng:NextNumber(-1.5, 1.5) * s),
			WHITE)
		p.CastShadow = false
	end
end

local function waterfall(parent: Instance, x: number, yTop: number, z: number, h: number, w: number)
	local main = block(parent, Vector3.new(w, h, 0.5), W(x, yTop - h / 2, z), Color3.fromRGB(140, 205, 250), Enum.Material.Glass)
	main.Transparency = 0.2
	main.CastShadow = false
	local core = block(parent, Vector3.new(w * 0.55, h, 0.55), W(x - w * 0.1, yTop - h / 2, z + 0.05), Color3.fromRGB(218, 242, 255))
	core.Transparency = 0.35
	core.CastShadow = false
	local lip = ell(parent, Vector3.new(w * 1.15, 0.9, 1.3), W(x, yTop, z), Color3.fromRGB(232, 248, 255))
	lip.CastShadow = false

	local top = block(parent, Vector3.new(w, 0.2, 0.2), W(x, yTop, z + 0.4), WHITE)
	top.Transparency = 1
	local fall = Instance.new("ParticleEmitter")
	fall.Texture = SMOKE
	fall.EmissionDirection = Enum.NormalId.Bottom
	fall.Speed = NumberRange.new(14, 18)
	fall.Lifetime = NumberRange.new(h / 17, h / 15)
	fall.Size = NumberSequence.new(w * 0.22, w * 0.32)
	fall.Squash = NumberSequence.new(-1.2)
	fall.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	fall.Color = ColorSequence.new(WHITE)
	fall.LightEmission = 0.25
	fall.Rate = 6 * w
	fall.SpreadAngle = Vector2.new(4, 4)
	fall.Parent = top

	local base = block(parent, Vector3.new(w, 0.5, 0.5), W(x, yTop - h, z + 0.4), WHITE)
	base.Transparency = 1
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = SMOKE
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Speed = NumberRange.new(1, 3)
	mist.Lifetime = NumberRange.new(1.6, 2.6)
	mist.Size = NumberSequence.new(w * 0.7, w * 1.6)
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Color = ColorSequence.new(WHITE)
	mist.LightEmission = 0.3
	mist.Rate = 5
	mist.SpreadAngle = Vector2.new(70, 70)
	mist.Parent = base
end

type Island = { model: Model, phase: number, amp: number }

local function island(parent: Instance, name: string, x: number, y: number, z: number, r: number, depth: number, bob: number?): Island
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	vcyl(m, 1.4, r * 2, W(x, y, z), GRASS_TOP, Enum.Material.Grass)
	local rimCount = math.clamp(math.floor(r * 1.1), 6, 18)
	for k = 1, rimCount do
		local a = (k / rimCount) * math.pi * 2
		ell(m, Vector3.new(r * 0.45, 1.6, r * 0.35), W(x + math.cos(a) * r * 0.9, y - 0.35, z + math.sin(a) * r * 0.9) * CFrame.Angles(0, -a, 0), GRASS_DARK, Enum.Material.Grass)
	end
	local layers = math.clamp(math.floor(depth / 4), 3, 6)
	local lh = depth / layers
	local top = y - 0.7
	for i = 1, layers do
		local t = (i - 1) / layers
		local lr = r * (1 - t * 0.78)
		local cy = top - lh * (i - 0.5)
		vcyl(m, lh, lr * 1.75, W(x, cy, z), ROCK[(i % #ROCK) + 1], Enum.Material.Sandstone)
		local n = math.clamp(math.floor(lr * 0.9), 4, 12)
		for k = 1, n do
			local a = (k / n) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
			local bw = math.max(1.2, lr * rng:NextNumber(0.45, 0.7))
			block(m, Vector3.new(bw, lh * rng:NextNumber(0.95, 1.3), bw * 0.8),
				W(x + math.cos(a) * lr * 0.74, cy + rng:NextNumber(-0.2, 0.2) * lh, z + math.sin(a) * lr * 0.74)
					* CFrame.Angles(0, -a + math.pi / 2 + rng:NextNumber(-0.25, 0.25), 0),
				ROCK[rng:NextInteger(1, #ROCK)], Enum.Material.Sandstone)
		end
	end
	ell(m, Vector3.new(r * 0.55, depth * 0.3, r * 0.55), W(x, top - depth - depth * 0.08, z), ROCK[3], Enum.Material.Sandstone)
	for _ = 1, math.floor(r * 0.5) do
		local a = rng:NextNumber(0, math.pi * 2)
		local len = rng:NextNumber(1.5, math.max(2, depth * 0.3))
		block(m, Vector3.new(0.35, len, 0.35), W(x + math.cos(a) * r * 0.97, y - 0.8 - len / 2, z + math.sin(a) * r * 0.97), GRASS_DARK, Enum.Material.Grass)
	end
	return { model = m, phase = rng:NextNumber(0, math.pi * 2), amp = bob or 0 }
end

-- ── the Catto mascot ─────────────────────────────────────────────────────────
-- The real in-game cat (your equipped look) scaled up, holding your equipped
-- blaster. CatAnimator poses it (breathing, head sway, tail, blinking).
local MASCOT_SCALE = 4
local GUN_SCALE = 0.36
local mascotRoot: CFrame? = nil
local mascotParent: Instance? = nil
local mascot: Model? = nil
local mascotSig = ""

-- Place every jointed part from its joints, walking out from the root.
local function resolveJoints(model: Model)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local motors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") or d:IsA("Weld") then
			table.insert(motors, d)
		end
	end
	local queue, seen = { root }, { [root] = true }
	local i = 1
	while queue[i] do
		local p0 = queue[i]
		i += 1
		for _, m in ipairs(motors) do
			local j = m :: any
			if j.Part0 == p0 and j.Part1 and not seen[j.Part1] then
				j.Part1.CFrame = p0.CFrame * j.C0 * j.C1:Inverse()
				seen[j.Part1] = true
				table.insert(queue, j.Part1)
			end
		end
	end
end

-- Scale parts, joint offsets and stored rest poses about `pivot`.
local function scaleAbout(inst: Instance, pivot: CFrame, s: number)
	local function scaled(cf: CFrame): CFrame
		return cf - cf.Position + cf.Position * s
	end
	for _, d in ipairs(inst:GetDescendants()) do
		if d:IsA("BasePart") then
			local rel = pivot:ToObjectSpace(d.CFrame)
			d.Size *= s
			d.CFrame = pivot * scaled(rel)
		elseif d:IsA("Motor6D") or d:IsA("Weld") then
			local j = d :: any
			j.C0 = scaled(j.C0)
			j.C1 = scaled(j.C1)
			local base = d:GetAttribute("BaseC0")
			if typeof(base) == "CFrame" then
				d:SetAttribute("BaseC0", scaled(base))
			end
		end
	end
end

local function loadoutNow()
	local p = ClientState.Profile
	local cat = p and p.Loadout and p.Loadout.Cat or {}
	local weaponId = p and p.Loadout and p.Loadout.Weapon or "PawBlaster"
	local skinId = p and p.Loadout and p.Loadout.Skin or "Default"
	return cat, weaponId, skinId
end

local function buildMascot()
	if not mascotRoot or not mascotParent then
		return
	end
	local cat, weaponId, skinId = loadoutNow()
	local model = CatBuilder.Build(cat)
	model.Name = "CattoMascot"
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:Destroy()
	end
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	model:PivotTo(CFrame.identity)

	-- Arms raised forward to hold the blaster.
	for _, i in ipairs({ -1, 1 }) do
		local m = model:FindFirstChild(i < 0 and "PawShoulderL" or "PawShoulderR", true) :: Motor6D?
		if m then
			local hold = CFrame.new(0.62 * i, 0.36, -0.02) * CFrame.Angles(0, 0, math.rad(-14 * i)) * CFrame.Angles(math.rad(72), 0, 0)
			m.C0 = hold
			m:SetAttribute("BaseC0", hold)
		end
	end
	resolveJoints(model)

	-- Blaster across the body, muzzle to screen-right and a little toward the
	-- camera, gripped by the right hand.
	local hands = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "Hand" then
			table.insert(hands, d)
		end
	end
	if #hands == 2 then
		local mid = (hands[1].Position + hands[2].Position) / 2 + Vector3.new(0, 0.06, -0.14)
		local dir = Vector3.new(-1, 0.06, -0.38).Unit
		local z = dir:Cross(Vector3.yAxis).Unit
		local gunCF = CFrame.fromMatrix(mid, dir, z:Cross(dir).Unit, z)
		local gun = BlasterBuilder.Build(weaponId, skinId, gunCF, GUN_SCALE)
		local grip = hands[1].Position.X > hands[2].Position.X and hands[1] or hands[2]
		for _, p in ipairs(gun:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.Massless = true
				local w = Instance.new("Weld")
				w.Part0 = grip
				w.Part1 = p
				w.C0 = grip.CFrame:ToObjectSpace(p.CFrame)
				w.Parent = p
			end
		end
		gun.Parent = model
	end

	scaleAbout(model, CFrame.identity, MASCOT_SCALE)
	model:PivotTo(mascotRoot)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanQuery = false
			d.CanTouch = false
		end
	end
	if mascot then
		mascot:Destroy()
	end
	mascot = model
	model.Parent = mascotParent
end

local function refreshMascot()
	local cat, weaponId, skinId = loadoutNow()
	local sig = table.concat({ cat.Fur or "", cat.Outfit or "", cat.Hat or "", cat.Accessory or "", weaponId, skinId }, "|")
	if sig ~= mascotSig then
		mascotSig = sig
		local ok, err = pcall(buildMascot)
		if not ok then
			warn("[CATTO] Lobby mascot failed to build: " .. tostring(err))
		end
	end
end

-- ── world layout ─────────────────────────────────────────────────────────────
local function buildForeground(parent: Instance)
	local fg = Instance.new("Model")
	fg.Name = "Foreground"
	fg.Parent = parent

	block(fg, Vector3.new(110, 6, 34), W(0, -5.5, 3), GRASS_TOP, Enum.Material.Grass)
	for i = -10, 10 do
		local x = i * 5.2 + rng:NextNumber(-1, 1)
		block(fg, Vector3.new(rng:NextNumber(5, 7), rng:NextNumber(5, 8), rng:NextNumber(4, 6)),
			W(x, -7 + rng:NextNumber(-1, 0.5), -14 + rng:NextNumber(-0.5, 0.5)) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
			ROCK[rng:NextInteger(1, #ROCK)], Enum.Material.Sandstone)
		ell(fg, Vector3.new(rng:NextNumber(5, 8), 2, rng:NextNumber(3, 5)), W(x, -2.7, -13.2), GRASS_DARK, Enum.Material.Grass)
	end
	for _ = 1, 12 do
		local x = rng:NextNumber(-34, 34)
		if math.abs(x - 4) > 7 then
			bush(fg, x, -2.6, rng:NextNumber(-12.5, -10.5), rng:NextNumber(1.0, 1.6))
		end
	end

	-- mossy rock ledge the mascot stands on (top of grass cap = y -1.0)
	local ledge = {
		{ Vector3.new(4.6, 3.2, 4.4), Vector3.new(1.6, -2.8, 1.0), 12 },
		{ Vector3.new(5.0, 3.6, 4.6), Vector3.new(6.4, -3.0, 0.4), -18 },
		{ Vector3.new(4.2, 3.0, 4.0), Vector3.new(3.8, -2.7, 3.4), 30 },
		{ Vector3.new(4.4, 3.2, 4.2), Vector3.new(4.2, -2.8, -2.6), -8 },
		{ Vector3.new(3.2, 2.4, 3.0), Vector3.new(8.9, -2.8, 2.4), 22 },
		{ Vector3.new(3.0, 2.2, 2.8), Vector3.new(-0.6, -2.9, 2.6), -26 },
	}
	for i, r in ipairs(ledge) do
		block(fg, r[1], W(r[2].X, r[2].Y, r[2].Z) * CFrame.Angles(0, math.rad(r[3]), 0), ROCK[(i % #ROCK) + 1], Enum.Material.Sandstone)
	end
	vcyl(fg, 1.1, 10.5, W(4, -1.55, 0.4), GRASS_TOP, Enum.Material.Grass)
	for k = 1, 9 do
		local a = (k / 9) * math.pi * 2
		ell(fg, Vector3.new(2.8, 0.9, 2.2), W(4 + math.cos(a) * 5, -1.35, 0.4 + math.sin(a) * 5) * CFrame.Angles(0, -a, 0), GRASS_DARK, Enum.Material.Grass)
	end

	-- flowers (pink cluster bottom-left, whites, oranges bottom-right)
	local PINK = Color3.fromRGB(255, 122, 184)
	local PINK2 = Color3.fromRGB(255, 160, 205)
	flower(fg, -5.0, -2.5, 4.5, 1.7, PINK)
	flower(fg, -2.6, -2.5, 5.2, 1.4, PINK2)
	flower(fg, -7.4, -2.5, 3.2, 1.3, PINK)
	flower(fg, -3.8, -2.5, 2.2, 1.1, PINK2)
	flower(fg, 0.2, -2.5, 4.6, 0.9, WHITE)
	flower(fg, -9.6, -2.5, 5.0, 0.9, WHITE)
	flower(fg, 8.2, -1.0, 2.0, 0.7, WHITE)
	flower(fg, 1.2, -1.0, 3.6, 0.6, Color3.fromRGB(255, 236, 120))
	flower(fg, 13.5, -2.5, 3.5, 1.4, Color3.fromRGB(255, 150, 60))
	flower(fg, 16.0, -2.5, 2.0, 1.2, Color3.fromRGB(255, 176, 70))
	flower(fg, -11.0, -2.5, 2.0, 0.9, Color3.fromRGB(190, 140, 255))
	flower(fg, 11.0, -2.5, 5.0, 0.8, WHITE)

	for _ = 1, 44 do
		local x = rng:NextNumber(-32, 32)
		local z = rng:NextNumber(-10, 6)
		local nearLedge = (Vector2.new(x - 4, z - 0.4)).Magnitude < 6.5
		if not nearLedge then
			tuft(fg, x, -2.5, z, rng:NextNumber(0.9, 1.5))
		end
	end

	tree(fg, -19, -2.5, -5, 2.4)
	tree(fg, -27, -2.5, -9, 2.0)
	bush(fg, -13, -2.5, -1, 1.6)
	bush(fg, 19, -2.5, -8, 1.5)
	fence(fg, Vector3.new(-18, -2.5, -9), Vector3.new(-7, -2.5, -11), 4, 1)
	fence(fg, Vector3.new(10.5, -2.5, 4.5), Vector3.new(21, -2.5, -3), 4, 1.15)
end

local function buildIslands(parent: Instance): ({ Island }, { Windmill })
	local isles: { Island } = {}
	local mills: { Windmill } = {}
	local function mill(isl: Island, x: number, y: number, z: number, s: number, yaw: number)
		local w = windmill(isl.model, x, y, z, s, yaw)
		w.island = isl
		table.insert(mills, w)
	end

	-- A: big island right, behind the mascot
	local a = island(parent, "IslandRight", 34, 11, -46, 13, 24, 0.45)
	table.insert(isles, a)
	mill(a, 33, 11.7, -50, 1.7, -0.3)
	hut(a.model, 42, 11.7, -40, 1.3, 0.4)
	tree(a.model, 26, 11.7, -41, 1.2)
	tree(a.model, 40, 11.7, -54, 1.3)
	bush(a.model, 29, 11.7, -37, 1.0)
	fence(a.model, Vector3.new(24, 11.7, -37.5), Vector3.new(35, 11.7, -35), 4, 0.8)
	waterfall(a.model, 30, 11.2, -33.6, 30, 3.5)
	waterfall(a.model, 41, 11.2, -36.4, 22, 2.2)

	-- B: high island top-center with the tall windmill and houses
	local b = island(parent, "IslandTop", -6, 30, -86, 10, 19, 0.5)
	table.insert(isles, b)
	mill(b, -5, 30.7, -88, 1.5, 0.2)
	house(b.model, -11, 30.7, -83, 1.1, -0.3)
	house(b.model, 1, 30.7, -81, 0.9, 0.5)
	tree(b.model, -12, 30.7, -90, 1.0)
	tree(b.model, 3, 30.7, -90, 1.1)
	waterfall(b.model, 1, 30.2, -79, 26, 2.8)

	-- D: left island behind the logo
	local d = island(parent, "IslandLeft", -40, 20, -78, 12, 20, 0.4)
	table.insert(isles, d)
	tree(d.model, -44, 20.7, -80, 1.4)
	tree(d.model, -36, 20.7, -84, 1.2)
	tree(d.model, -47, 20.7, -72, 1.1)
	house(d.model, -35, 20.7, -73, 1.0, 0.2)
	waterfall(d.model, -32, 20.2, -69.5, 22, 2.4)

	-- small floaters
	local c1 = island(parent, "Floater1", -15, 16, -70, 4, 8, 0.6)
	tree(c1.model, -15, 16.7, -70, 0.8)
	local c2 = island(parent, "Floater2", -26, 8, -62, 3, 6, 0.7)
	bush(c2.model, -26, 8.7, -62, 0.6)
	local c3 = island(parent, "Floater3", 9, 20, -110, 4.5, 9, 0.5)
	mill(c3, 9, 20.7, -111, 0.7, 0.1)
	local c4 = island(parent, "Floater4", 22, -4, -64, 4, 8, 0.6)
	tree(c4.model, 22, -3.3, -64, 0.8)
	for _, isl in ipairs({ c1, c2, c3, c4 }) do
		table.insert(isles, isl)
	end

	-- far islands (static, hazed by the atmosphere)
	local far = {
		{ -14, 0, -150, 10, 16, true, true },
		{ -40, -6, -175, 8, 13, true, false },
		{ 6, -10, -190, 7, 11, false, false },
		{ 40, 6, -200, 11, 18, true, true },
		{ 70, 22, -170, 9, 14, false, false },
		{ -80, 12, -210, 10, 15, true, false },
		{ -60, 34, -140, 6, 10, false, false },
		{ 95, -4, -240, 12, 18, true, true },
		{ -120, -2, -260, 14, 20, false, true },
		{ 20, 40, -260, 8, 12, false, false },
	}
	for i, f in ipairs(far) do
		local x, y, z, r, depth, hasMill, hasHouse = f[1], f[2], f[3], f[4], f[5], f[6], f[7]
		local isl = island(parent, "FarIsland" .. i, x, y, z, r, depth, 0)
		if hasMill then
			mill(isl, x + r * 0.2, y + 0.7, z - r * 0.2, r * 0.16, rng:NextNumber(-0.4, 0.4))
		end
		if hasHouse then
			house(isl.model, x - r * 0.4, y + 0.7, z + r * 0.2, r * 0.11, rng:NextNumber(-0.5, 0.5))
		end
		tree(isl.model, x - r * 0.1, y + 0.7, z + r * 0.45, r * 0.1)
		tree(isl.model, x + r * 0.5, y + 0.7, z + r * 0.3, r * 0.09)
		noShadows(isl.model)
	end
	return isles, mills
end

local function buildClouds(parent: Instance)
	local m = Instance.new("Model")
	m.Name = "Clouds"
	m.Parent = parent
	for i = 1, 14 do
		cloud(m, -260 + i * 38 + rng:NextNumber(-10, 10), rng:NextNumber(-42, -26), -300 + rng:NextNumber(-40, 40), 3.5)
	end
	cloud(m, -30, -18, -110, 2.2)
	cloud(m, 40, -20, -120, 2.5)
	cloud(m, 0, -25, -160, 2.8)
	cloud(m, -20, 60, -170, 3)
	cloud(m, 60, 62, -200, 3.5)
	cloud(m, -90, 55, -190, 3)
	cloud(m, 130, 40, -260, 4)
	cloud(m, -150, 70, -280, 4)
end

-- ── animation wiring ─────────────────────────────────────────────────────────
local function islandOffset(isl: Island?, t: number): Vector3
	if not isl or isl.amp == 0 then
		return Vector3.zero
	end
	return Vector3.new(0, math.sin(t * 0.45 + isl.phase) * isl.amp, 0)
end

local function wireAnimation(isles: { Island }, mills: { Windmill })
	for _, isl in ipairs(isles) do
		if isl.amp > 0 then
			local parts, base = {}, {}
			for _, d in ipairs(isl.model:GetDescendants()) do
				if d:IsA("BasePart") and not d:GetAttribute("Spin") then
					table.insert(parts, d)
					table.insert(base, d.CFrame)
				end
			end
			local cfs = table.create(#parts)
			table.insert(animators, function(t: number)
				local off = islandOffset(isl, t)
				for i = 1, #parts do
					cfs[i] = base[i] + off
				end
				Workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			end)
		end
	end
	for _, w in ipairs(mills) do
		local cfs = table.create(#w.parts)
		table.insert(animators, function(t: number)
			local hub = w.hub + islandOffset(w.island, t)
			local spin = CFrame.Angles(0, 0, -t * w.speed)
			for i = 1, #w.parts do
				cfs[i] = hub * spin * w.rel[i]
			end
			Workspace:BulkMoveTo(w.parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end)
	end
end

-- ── lighting / post effects ──────────────────────────────────────────────────
local function same(a: any, b: any): boolean
	if typeof(a) == "number" and typeof(b) == "number" then
		return math.abs(a - b) < 1e-3
	elseif typeof(a) == "Color3" and typeof(b) == "Color3" then
		return math.abs(a.R - b.R) < 0.004 and math.abs(a.G - b.G) < 0.004 and math.abs(a.B - b.B) < 0.004
	end
	return a == b
end

-- Point the whole scene so the sun sits behind the camera's upper-left, lighting
-- the mascot's face like the key art.
local function orientToSun()
	local ok, sun = pcall(function()
		local prev = Lighting.ClockTime
		Lighting.ClockTime = LIGHTING.ClockTime
		local dir = Lighting:GetSunDirection()
		Lighting.ClockTime = prev
		return dir
	end)
	if not ok or typeof(sun) ~= "Vector3" then
		return
	end
	local h = Vector3.new(sun.X, 0, sun.Z)
	if h.Magnitude < 0.05 then
		return
	end
	h = h.Unit
	local want = Vector3.new(-0.57, 0, 0.82)
	local theta = math.atan2(h.X, h.Z) - math.atan2(want.X, want.Z)
	SCENE = CFrame.new(ORIGIN) * CFrame.Angles(0, theta, 0)
end

local function overrideAtmosphere(atmo: Atmosphere)
	if atmo ~= ownAtmosphere and (not savedAtmo or savedAtmo.inst ~= atmo) then
		local s: { [string]: any } = { inst = atmo }
		for k in pairs(ATMOSPHERE) do
			s[k] = (atmo :: any)[k]
		end
		savedAtmo = s
	end
	for k, v in pairs(ATMOSPHERE) do
		if not same((atmo :: any)[k], v) then
			(atmo :: any)[k] = v
		end
	end
end

local function applyLighting()
	local s: { [string]: any } = {}
	for k in pairs(LIGHTING) do
		s[k] = (Lighting :: any)[k]
	end
	saved = s
	for k, v in pairs(LIGHTING) do
		pcall(function()
			(Lighting :: any)[k] = v
		end)
	end
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmo then
		ownAtmosphere = Instance.new("Atmosphere")
		atmo = ownAtmosphere
		atmo.Parent = Lighting
	end
	overrideAtmosphere(atmo :: Atmosphere)

	-- The server may retune lighting when it builds a map while we're in the
	-- menu: remember its new value for later, then keep the menu look.
	table.insert(lightingConns, Lighting.Changed:Connect(function(prop)
		local want = LIGHTING[prop]
		if want == nil or not saved then
			return
		end
		local now = (Lighting :: any)[prop]
		if not same(now, want) then
			saved[prop] = now
			pcall(function()
				(Lighting :: any)[prop] = want
			end)
		end
	end))
	table.insert(lightingConns, Lighting.ChildAdded:Connect(function(child)
		if child:IsA("Atmosphere") and child ~= ownAtmosphere then
			if ownAtmosphere then
				ownAtmosphere:Destroy()
				ownAtmosphere = nil
			end
			task.defer(overrideAtmosphere, child)
		end
	end))
end

local function restoreLighting()
	for _, c in ipairs(lightingConns) do
		c:Disconnect()
	end
	table.clear(lightingConns)
	if saved then
		for k, v in pairs(saved) do
			pcall(function()
				(Lighting :: any)[k] = v
			end)
		end
	end
	saved = nil
	if savedAtmo and savedAtmo.inst.Parent then
		for k, v in pairs(savedAtmo) do
			if k ~= "inst" then
				(savedAtmo.inst :: any)[k] = v
			end
		end
	end
	savedAtmo = nil
	if ownAtmosphere then
		ownAtmosphere:Destroy()
		ownAtmosphere = nil
	end
end

local function buildPostEffects()
	local cam = Workspace.CurrentCamera
	local dof = Instance.new("DepthOfFieldEffect")
	dof.FarIntensity = 0.62
	dof.NearIntensity = 0.12
	dof.FocusDistance = 27
	dof.InFocusRadius = 7
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.32
	bloom.Size = 26
	bloom.Threshold = 1.9
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.1
	cc.Contrast = 0.04
	cc.Brightness = 0
	cc.TintColor = Color3.fromRGB(255, 246, 232)
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.09
	rays.Spread = 0.7
	for _, e in ipairs({ dof, bloom, cc, rays } :: { any }) do
		e.Name = "CattoLobby" .. e.ClassName
		e.Enabled = false
		e.Parent = cam
		table.insert(postEffects, e)
	end
	if not Workspace.Terrain:FindFirstChildOfClass("Clouds") then
		local c = Instance.new("Clouds")
		c.Cover = 0.55
		c.Density = 0.6
		c.Color = WHITE
		cloudsInstance = c
	end
end

-- ── public API ───────────────────────────────────────────────────────────────
function LobbyScene.Build()
	if built then
		return
	end
	built = true
	orientToSun()
	local f = Instance.new("Folder")
	f.Name = "CattoLobbyScene"
	folder = f

	local function section(name: string, fn: () -> ())
		local ok, err = pcall(fn)
		if not ok then
			warn("[CATTO] Lobby scene section '" .. name .. "' failed (skipped): " .. tostring(err))
		end
	end
	section("foreground", function()
		buildForeground(f)
	end)
	section("mascot", function()
		-- Feet sit 1.4 below the cat's root; it faces -Z, so turn it to the camera.
		mascotRoot = W(4, -1.0 + 1.4 * MASCOT_SCALE, 0) * CFrame.Angles(0, math.rad(180 - 12), 0)
		mascotParent = f
		refreshMascot()
		ClientState.ProfileChanged:Connect(refreshMascot)
	end)
	section("islands", function()
		local isles, mills = buildIslands(f)
		wireAnimation(isles, mills)
	end)
	section("clouds", function()
		buildClouds(f)
	end)
	section("effects", buildPostEffects)
end

function LobbyScene.GetCameraCFrame(): CFrame
	return SCENE * CFrame.lookAt(CAMERA_POS, CAMERA_LOOK)
end

-- Graphics Quality: Low = no post effects, Medium = colour + bloom only.
LobbyScene.Quality = "High"
function LobbyScene.EffectAllowed(e: Instance): boolean
	if LobbyScene.Quality == "Low" then
		return false
	elseif LobbyScene.Quality == "Medium" then
		return e:IsA("ColorCorrectionEffect") or e:IsA("BloomEffect")
	end
	return true
end

function LobbyScene.ApplyQuality(q: string)
	LobbyScene.Quality = q
	for _, e in ipairs(postEffects) do
		(e :: any).Enabled = active and LobbyScene.EffectAllowed(e)
	end
end

function LobbyScene.SetActive(on: boolean)
	if on == active then
		return
	end
	if on and not built then
		LobbyScene.Build()
	end
	active = on
	if folder then
		folder.Parent = on and Workspace or nil
	end
	for _, e in ipairs(postEffects) do
		(e :: any).Enabled = on and LobbyScene.EffectAllowed(e)
	end
	if cloudsInstance then
		cloudsInstance.Parent = on and Workspace.Terrain or nil
	end
	if on then
		applyLighting()
		renderConn = RunService.RenderStepped:Connect(function()
			local t = os.clock()
			for _, fn in ipairs(animators) do
				fn(t)
			end
		end)
	else
		if renderConn then
			renderConn:Disconnect()
			renderConn = nil
		end
		restoreLighting()
	end
end

return LobbyScene
