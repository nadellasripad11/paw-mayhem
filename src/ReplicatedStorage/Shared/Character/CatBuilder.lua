--!strict
-- CatBuilder: builds an original chibi cat entirely from Roblox primitives
-- (no Toolbox / external meshes or textures; rounded pieces use the built-in
-- sphere mesh so they can be true ovals).
--
--   Model
--     HumanoidRootPart (invisible collision root; PrimaryPart)
--     Humanoid
--     Torso / hips / chest, Head (+ face, ears, hats), arms, legs, tail
--
-- The head, arms, legs and tail hang off named Motor6D pivots (PawNeck,
-- PawShoulderL/R, PawHipL/R, PawTail) whose rest pose is stored in a
-- "BaseC0" attribute; CatBuilder.Pose animates them. Every cosmetic part is
-- Massless + CanCollide=false so the root alone drives physics/knockback.

local CollectionService = game:GetService("CollectionService")

local Cats = require(script.Parent.Parent.Config.Cats)
local BlasterBuilder = require(script.Parent.BlasterBuilder)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local CatBuilder = {}

-- Smooth Blender meshes (tools/blender/build_cat.py). Used when the imported
-- ReplicatedStorage.CatMeshes model is present; otherwise the cat falls back
-- to the primitive build below.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CatMeshData = require(script.Parent.CatMeshData)

CatBuilder.Tag = "PawCat"

local ROOT_SIZE = Vector3.new(2, 2, 1.4)
-- The invisible root is the only collider. HipHeight lifts it so the
-- Humanoid hovers instead of dragging the box along the floor (which snagged
-- on seams and shoved the cat sideways); 0.4 puts the feet on the ground.
local HIP_HEIGHT = 0.4

local V = Vector3.new
local HEAD_POS = V(0, 1.2, 0) -- head centre in root space
local PINK = Color3.fromRGB(255, 172, 192)
local ROT_Z90 = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y
local ROT_Y90 = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis X -> Z

local function part(name: string, size: Vector3, color: Color3, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	if shape == Enum.PartType.Ball then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = p
	elseif shape then
		p.Shape = shape
	end
	return p
end

local function oval(name: string, size: Vector3, color: Color3): BasePart
	return part(name, size, color, Enum.PartType.Ball)
end

local function wedge(name: string, size: Vector3, color: Color3): BasePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.Color = color
	w.Material = Enum.Material.SmoothPlastic
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.Massless = true
	return w
end

-- Rigidly attach b to a at offset cf (in a's space).
local function weld(a: BasePart, b: BasePart, cf: CFrame)
	local w = Instance.new("Motor6D")
	w.Name = b.Name .. "_Joint"
	w.Part0 = a
	w.Part1 = b
	w.C0 = cf
	w.Parent = a
	b.CFrame = a.CFrame * cf
	b.Parent = a.Parent
end

-- Attach b to a through a named pivot so it can be rotated about `pivot`.
local function joint(name: string, a: BasePart, b: BasePart, pivot: CFrame, offset: CFrame)
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0 = a
	m.Part1 = b
	m.C0 = pivot
	m.C1 = offset:Inverse()
	m:SetAttribute("BaseC0", pivot)
	m.Parent = a
	b.CFrame = a.CFrame * pivot * offset
	b.Parent = a.Parent
end

local function resolve(custom)
	custom = custom or {}
	local fur = Cats.FurById[custom.Fur] or Cats.FurById[Cats.Default.Fur]
	local outfit = Cats.OutfitById[custom.Outfit] or Cats.OutfitById[Cats.Default.Outfit]
	local hat = Cats.HatById[custom.Hat] or Cats.HatById[Cats.Default.Hat]
	local acc = Cats.AccessoryById[custom.Accessory] or Cats.AccessoryById[Cats.Default.Accessory]
	return fur, outfit, hat, acc
end

-- Clothing colours per outfit: jacket/top, inner chest, shorts, sleeve cuffs.
local function outfitColors(outfit, fur)
	local id = outfit.Id
	if id == "None" then
		return fur.Body, fur.Accent, nil, nil
	elseif id == "Hoodie" then
		-- Open hoodie over a peach tee, dark shorts
		return outfit.Color, Color3.fromRGB(242, 178, 152), Color3.fromRGB(46, 42, 54), outfit.Color:Lerp(Color3.new(0, 0, 0), 0.25)
	elseif id == "Streetwear" then
		return outfit.Color, outfit.Color:Lerp(Color3.new(1, 1, 1), 0.2), Color3.fromRGB(62, 92, 140), Color3.fromRGB(236, 240, 246)
	elseif id == "Robot" then
		return outfit.Color, outfit.Color:Lerp(Color3.new(1, 1, 1), 0.3), outfit.Color:Lerp(Color3.new(0, 0, 0), 0.3), Color3.fromRGB(35, 210, 255)
	elseif id == "Ninja" then
		return outfit.Color, Color3.fromRGB(46, 46, 58), Color3.fromRGB(24, 24, 30), Color3.fromRGB(165, 40, 60)
	elseif id == "Royal" then
		return outfit.Color, Color3.fromRGB(246, 232, 200), Color3.fromRGB(70, 36, 96), Color3.fromRGB(255, 210, 80)
	elseif id == "Space" then
		return outfit.Color, Color3.fromRGB(196, 206, 222), outfit.Color, Color3.fromRGB(255, 140, 60)
	end
	return outfit.Color, fur.Accent, outfit.Color:Lerp(Color3.new(0, 0, 0), 0.3), nil
end

-- Outfit / back-item offsets were authored for the original 1.45 x 1.15 x
-- 1.05 torso centred at y 0.02; map them onto the compact torso (1.3 x 1.0 x
-- 1.0 centred at y -0.2).
local function slim(p: BasePart, cf: CFrame): CFrame
	p.Size = V(p.Size.X * 0.9, p.Size.Y * 0.87, p.Size.Z * 0.95)
	local pos = cf.Position
	return CFrame.new(pos.X * 0.9, (pos.Y - 0.02) * 0.87 - 0.2, pos.Z * 0.95) * cf.Rotation
end

-- ── outfit details (torso, root space) ──────────────────────────────────────
local function addOutfitDetails(root: BasePart, outfit, top: Color3)
	local id = outfit.Id
	local dark = top:Lerp(Color3.new(0, 0, 0), 0.22)
	local function add(p: BasePart, cf: CFrame)
		weld(root, p, slim(p, cf))
	end
	if id == "Hoodie" then
		local function put(p: BasePart, cf: CFrame)
			weld(root, p, cf)
		end
		-- Hood bunched behind the neck + jacket collar
		put(oval("Hood", V(1.15, 0.52, 0.72), top), CFrame.new(0, 0.26, 0.38))
		put(oval("HoodRim", V(0.95, 0.24, 0.5), dark), CFrame.new(0, 0.36, 0.3))
		put(oval("Collar", V(1.02, 0.26, 0.92), top), CFrame.new(0, 0.24, 0))
		-- Open front: two jacket panels framing the tee
		for i = -1, 1, 2 do
			put(oval("Lapel", V(0.42, 0.94, 0.24), top), CFrame.new(0.4 * i, -0.22, -0.4) * CFrame.Angles(0, math.rad(-18 * i), math.rad(-3 * i)))
			put(part("LapelEdge", V(0.05, 0.86, 0.05), dark), CFrame.new(0.24 * i, -0.2, -0.53) * CFrame.Angles(0, 0, math.rad(-3 * i)))
			-- Drawstrings with metal tips
			put(part("Drawstring", V(0.045, 0.42, 0.045), Color3.fromRGB(246, 246, 250)), CFrame.new(0.15 * i, 0.04, -0.56))
			put(oval("Aglet", V(0.08, 0.11, 0.08), Color3.fromRGB(200, 205, 215)), CFrame.new(0.15 * i, -0.19, -0.57))
			-- Dog-tag chain
			put(part("TagChain", V(0.025, 0.26, 0.025), Color3.fromRGB(180, 186, 196)), CFrame.new(0.07 * i, 0.16, -0.55) * CFrame.Angles(0, 0, math.rad(28 * i)))
		end
		put(oval("JacketHem", V(1.34, 0.2, 1.04), dark), CFrame.new(0, -0.62, 0))
		local tag = oval("DogTag", V(0.17, 0.24, 0.05), Color3.fromRGB(214, 218, 228))
		tag.Material = Enum.Material.Metal
		put(tag, CFrame.new(-0.01, 0.02, -0.575))
		-- Tan patch pocket (lower right as you face the cat)
		put(part("Pocket", V(0.3, 0.26, 0.05), Color3.fromRGB(214, 140, 72)), CFrame.new(-0.46, -0.46, -0.39) * CFrame.Angles(0, math.rad(34), 0))
		put(part("PocketFlap", V(0.32, 0.07, 0.06), Color3.fromRGB(176, 104, 48)), CFrame.new(-0.46, -0.34, -0.395) * CFrame.Angles(0, math.rad(34), 0))
		-- Crossbody strap + satchel (on the other hip)
		local leather = Color3.fromRGB(150, 88, 54)
		put(part("Strap", V(0.09, 1.2, 0.05), leather), CFrame.new(0, -0.16, -0.575) * CFrame.Angles(0, 0, math.rad(53)))
		put(part("StrapBack", V(0.09, 1.1, 0.05), leather), CFrame.new(0, -0.16, 0.52) * CFrame.Angles(0, 0, math.rad(-53)))
		local satchel = CFrame.new(0.56, -0.54, -0.28) * CFrame.Angles(0, math.rad(-40), 0)
		put(oval("Satchel", V(0.44, 0.4, 0.2), leather), satchel)
		put(oval("SatchelFlap", V(0.44, 0.2, 0.22), leather:Lerp(Color3.new(0, 0, 0), 0.22)), satchel * CFrame.new(0, 0.1, -0.02))
		put(part("Buckle", V(0.08, 0.08, 0.03), Color3.fromRGB(230, 190, 90)), satchel * CFrame.new(0, 0.03, -0.12))
	elseif id == "Streetwear" then
		add(part("Zipper", V(0.05, 0.9, 0.05), Color3.fromRGB(222, 236, 246)), CFrame.new(0, -0.02, -0.61))
		add(oval("Collar", V(1.1, 0.28, 0.95), top:Lerp(Color3.new(1, 1, 1), 0.18)), CFrame.new(0, 0.5, 0))
		for i = -1, 1, 2 do
			add(part("Stripe", V(0.07, 0.7, 0.05), Color3.fromRGB(236, 240, 246)), CFrame.new(0.5 * i, 0, -0.38) * CFrame.Angles(0, math.rad(-38 * i), 0))
		end
	elseif id == "Robot" then
		local core = oval("RobotCore", V(0.3, 0.3, 0.1), Color3.fromRGB(35, 210, 255))
		core.Material = Enum.Material.Neon
		add(core, CFrame.new(0, 0.05, -0.62))
		for _, p in ipairs({ V(-0.25, 0.28), V(0.25, 0.28), V(-0.25, -0.2), V(0.25, -0.2) }) do
			add(oval("Bolt", V(0.08, 0.08, 0.06), Color3.fromRGB(90, 96, 110)), CFrame.new(p.X, p.Y, -0.6))
		end
	elseif id == "Ninja" then
		add(oval("Belt", V(1.38, 0.2, 1.0), Color3.fromRGB(165, 40, 60)), CFrame.new(0, -0.28, 0))
		for i = -1, 1, 2 do
			add(part("BeltTail", V(0.12, 0.4, 0.05), Color3.fromRGB(165, 40, 60)), CFrame.new(0.12 * i, -0.48, 0.5) * CFrame.Angles(0, 0, math.rad(12 * i)))
		end
	elseif id == "Royal" then
		add(part("Cape", V(1.35, 1.5, 0.12), dark), CFrame.new(0, -0.15, 0.6) * CFrame.Angles(math.rad(8), 0, 0))
		add(oval("Ruff", V(1.2, 0.3, 1.0), Color3.fromRGB(250, 248, 240)), CFrame.new(0, 0.5, 0))
		add(part("Sash", V(0.12, 1.1, 0.05), Color3.fromRGB(255, 210, 80)), CFrame.new(-0.02, 0.05, -0.63) * CFrame.Angles(0, 0, math.rad(-53)))
		add(oval("Medal", V(0.2, 0.2, 0.06), Color3.fromRGB(255, 210, 80)), CFrame.new(0.2, 0.15, -0.64))
	elseif id == "Space" then
		add(part("LifePack", V(0.9, 1.0, 0.36), Color3.fromRGB(150, 170, 200)), CFrame.new(0, 0.1, 0.7))
		for k, c in ipairs({ Color3.fromRGB(255, 80, 90), Color3.fromRGB(80, 220, 120), Color3.fromRGB(80, 170, 255) }) do
			local b = oval("SuitButton", V(0.1, 0.1, 0.06), c)
			b.Material = Enum.Material.Neon
			add(b, CFrame.new(-0.16 + (k - 1) * 0.16, 0.12, -0.61))
		end
		add(oval("Collar", V(1.15, 0.26, 1.0), Color3.fromRGB(200, 210, 226)), CFrame.new(0, 0.5, 0))
	end
end

-- ── accessories (root space) ────────────────────────────────────────────────
local function addBackItem(root: BasePart, acc)
	local function add(p: BasePart, cf: CFrame)
		weld(root, p, slim(p, cf))
	end
	if acc.Shape == "Backpack" then
		add(oval("Backpack", V(0.95, 1.05, 0.5), acc.Color), CFrame.new(0, 0.05, 0.66))
		add(oval("BackpackPocket", V(0.7, 0.42, 0.22), acc.Color:Lerp(Color3.new(0, 0, 0), 0.2)), CFrame.new(0, -0.18, 0.88))
		for i = -1, 1, 2 do
			add(part("BackpackStrap", V(0.12, 0.7, 0.05), acc.Color:Lerp(Color3.new(0, 0, 0), 0.3)), CFrame.new(0.4 * i, 0.18, -0.52) * CFrame.Angles(0, math.rad(-30 * i), 0))
		end
	elseif acc.Shape == "Jetpack" then
		for i = -1, 1, 2 do
			local tank = part("JetTank", V(0.9, 0.42, 0.42), acc.Color, Enum.PartType.Cylinder)
			tank.Material = Enum.Material.Metal
			add(tank, CFrame.new(0.26 * i, 0.12, 0.72) * ROT_Z90)
			add(oval("JetCap", V(0.42, 0.26, 0.42), acc.Color), CFrame.new(0.26 * i, 0.57, 0.72))
			add(part("JetNozzle", V(0.22, 0.3, 0.3), Color3.fromRGB(60, 60, 70), Enum.PartType.Cylinder), CFrame.new(0.26 * i, -0.43, 0.72) * ROT_Z90)
			local flame = oval("JetFlame", V(0.22, 0.42, 0.22), Color3.fromRGB(255, 150, 50))
			flame.Material = Enum.Material.Neon
			add(flame, CFrame.new(0.26 * i, -0.72, 0.72))
		end
	end
end

-- ── head: face, ears, markings, hats, glasses (head space) ──────────────────
-- A big, wide kitten head: huge round glossy eyes, little brows, a
-- down-pointing forehead marking, pink nose, ":3" mouth, spiky cheek fluff
-- and tall, wide ears with pink insides.
local function earPair(add: (BasePart, CFrame) -> (), cf: CFrame, color: Color3, w: number, h: number, t: number, name: string)
	add(wedge(name, V(t, h, w / 2), color), cf * CFrame.new(-w / 4, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
	add(wedge(name, V(t, h, w / 2), color), cf * CFrame.new(w / 4, 0, 0) * CFrame.Angles(0, math.rad(-90), 0))
end

local function buildHead(root: BasePart, fur, hat, acc): BasePart
	local head = oval("Head", V(2.4, 1.95, 2.0), fur.Body)
	joint("PawNeck", root, head, CFrame.new(0, 0.3, 0), CFrame.new(0, 0.9, 0))
	local function add(p: BasePart, cf: CFrame)
		weld(head, p, cf)
	end
	local marking = fur.Marking or fur.Body:Lerp(Color3.fromRGB(150, 80, 40), 0.22)
	local browColor = fur.Body:Lerp(Color3.new(0, 0, 0), 0.28)

	-- Spiky cheek fluff sweeping out to the sides + a tuft on top
	for i = -1, 1, 2 do
		add(oval("CheekFluff", V(0.64, 0.34, 0.52), fur.Body), CFrame.new(1.05 * i, -0.28, -0.2) * CFrame.Angles(0, 0, math.rad(-24 * i)))
		add(oval("CheekFluff", V(0.52, 0.28, 0.46), fur.Body), CFrame.new(1.0 * i, -0.52, -0.1) * CFrame.Angles(0, 0, math.rad(-52 * i)))
		add(oval("CheekFluff", V(0.36, 0.22, 0.36), fur.Body), CFrame.new(1.13 * i, -0.06, -0.04) * CFrame.Angles(0, 0, math.rad(-8 * i)))
	end
	add(oval("Tuft", V(0.24, 0.46, 0.2), fur.Body), CFrame.new(-0.12, 0.98, -0.1) * CFrame.Angles(0, 0, math.rad(20)))
	add(oval("Tuft", V(0.22, 0.42, 0.2), fur.Body), CFrame.new(0.06, 1.0, -0.06) * CFrame.Angles(0, 0, math.rad(-6)))
	add(oval("Tuft", V(0.2, 0.34, 0.18), fur.Body), CFrame.new(0.2, 0.94, -0.04) * CFrame.Angles(0, 0, math.rad(-28)))

	-- Forehead marking: a small triangle pointing down between the eyes
	if fur.Pattern ~= "Tiger" then
		local tri = CFrame.new(0, 0.5, -0.83) * CFrame.Angles(math.rad(34), 0, 0) * CFrame.Angles(0, 0, math.pi)
		earPair(add, tri, marking, 0.36, 0.4, 0.05, "ForeheadMark")
	end

	-- Muzzle: soft light puffs, pink nose, ":3" mouth
	for i = -1, 1, 2 do
		add(oval("MuzzlePuff", V(0.34, 0.24, 0.22), fur.Accent), CFrame.new(0.12 * i, -0.42, -0.9))
		local mouth = part("Mouth", V(0.14, 0.035, 0.03), Color3.fromRGB(110, 58, 66))
		add(mouth, CFrame.new(0.062 * i, -0.44, -1.025) * CFrame.Angles(0, math.rad(-14 * i), math.rad(26 * i)))
	end
	add(oval("Chin", V(0.24, 0.12, 0.16), fur.Accent), CFrame.new(0, -0.56, -0.86))
	add(oval("Nose", V(0.2, 0.12, 0.12), Color3.fromRGB(255, 136, 160)), CFrame.new(0, -0.28, -0.965))
	add(oval("NoseShine", V(0.07, 0.04, 0.03), Color3.fromRGB(255, 210, 222)), CFrame.new(0.03, -0.25, -1.025))

	-- Eyes: big and round. Dark rim, deep iris that glows lighter at the
	-- bottom, big pupil, one large + one small highlight (same side on both
	-- eyes, like a single light).
	local eyeColor = fur.Eye or Color3.fromRGB(52, 160, 140)
	for i = -1, 1, 2 do
		local base = CFrame.new(0.5 * i, -0.02, -0.86) * CFrame.Angles(0, math.rad(-21 * i), 0)
		local function at(x: number, y: number, z: number): CFrame
			return base * CFrame.new(x, y, z)
		end
		add(oval("EyeWhite", V(0.66, 0.72, 0.22), Color3.fromRGB(22, 16, 26)), at(0, 0, 0))
		add(oval("Iris", V(0.58, 0.64, 0.22), eyeColor:Lerp(Color3.fromRGB(16, 20, 26), 0.45)), at(0, 0, -0.02))
		add(oval("IrisGlow", V(0.44, 0.3, 0.2), eyeColor:Lerp(Color3.new(1, 1, 1), 0.12)), at(0, -0.15, -0.04))
		add(oval("Pupil", V(0.36, 0.42, 0.2), Color3.fromRGB(12, 8, 18)), at(0, 0.03, -0.05))
		add(oval("Shine", V(0.22, 0.24, 0.08), Color3.new(1, 1, 1)), at(0.11, 0.13, -0.14))
		add(oval("Shine", V(0.1, 0.1, 0.06), Color3.new(1, 1, 1)), at(-0.12, -0.15, -0.13))
		local shut = part("ClosedEye", V(0.5, 0.07, 0.05), Color3.fromRGB(40, 30, 40))
		shut.Transparency = 1
		add(shut, at(0, -0.02, -0.1) * CFrame.Angles(0, 0, math.rad(-8 * i)))
		-- Little brows
		add(oval("Brow", V(0.26, 0.08, 0.07), browColor), CFrame.new(0.5 * i, 0.44, -0.8) * CFrame.Angles(0, math.rad(-20 * i), math.rad(-10 * i)))
		-- Blush
		local blush = oval("Blush", V(0.34, 0.17, 0.06), Color3.fromRGB(255, 150, 175))
		blush.Transparency = 0.4
		add(blush, CFrame.new(0.8 * i, -0.33, -0.7) * CFrame.Angles(0, math.rad(-42 * i), 0))
	end

	-- Ears: tall, wide triangles tilted outward, pink inside with a tuft of
	-- pale fur. Calico gets one patched ear.
	for i = -1, 1, 2 do
		local earColor = (fur.Pattern == "Calico" and i == -1) and marking or fur.Body
		local earCF = CFrame.new(0.68 * i, 0.98, 0.04) * CFrame.Angles(0, math.rad(-8 * i), 0) * CFrame.Angles(0, 0, math.rad(-22 * i))
		earPair(add, earCF, earColor, 1.0, 1.3, 0.3, "Ear")
		earPair(add, earCF * CFrame.new(0, -0.1, -0.17), PINK, 0.64, 0.9, 0.06, "InnerEar")
		add(oval("EarFluff", V(0.26, 0.42, 0.12), fur.Accent), earCF * CFrame.new(0, -0.3, -0.21))
	end

	-- Fur markings
	if fur.Pattern == "Tiger" then
		for i = -1, 1 do
			local z = i == 0 and -0.72 or -0.68
			add(part("TigerStripe", V(0.12, 0.42, 0.06), marking), CFrame.new(i * 0.26, 0.68, z) * CFrame.Angles(math.rad(-40), 0, math.rad(i * 14)))
		end
		for i = -1, 1, 2 do
			for k = 0, 1 do
				add(part("CheekStripe", V(0.28, 0.07, 0.06), marking), CFrame.new(1.02 * i, -0.06 - k * 0.16, -0.5) * CFrame.Angles(0, math.rad(-58 * i), math.rad(8 * i)))
			end
		end
	elseif fur.Pattern == "Calico" then
		add(oval("CalicoPatch", V(0.6, 0.52, 0.14), marking), CFrame.new(0.52, 0.42, -0.76) * CFrame.Angles(0, math.rad(-35), 0))
		add(oval("CalicoPatch", V(0.5, 0.4, 0.12), Color3.fromRGB(60, 50, 50)), CFrame.new(-0.72, 0.2, -0.72) * CFrame.Angles(0, math.rad(40), 0))
	end

	-- Hats
	if hat and hat.Shape == "Cap" then
		add(oval("Cap", V(2.1, 0.85, 2.02), hat.Color), CFrame.new(0, 0.68, 0.02))
		add(part("CapBrim", V(1.4, 0.1, 0.8), hat.Color:Lerp(Color3.new(0, 0, 0), 0.15)), CFrame.new(0, 0.54, -0.98) * CFrame.Angles(math.rad(-8), 0, 0))
		add(oval("CapButton", V(0.16, 0.1, 0.16), hat.Color:Lerp(Color3.new(1, 1, 1), 0.3)), CFrame.new(0, 1.12, 0.02))
	elseif hat and hat.Shape == "Beanie" then
		add(oval("Beanie", V(2.24, 1.1, 2.16), hat.Color), CFrame.new(0, 0.68, 0.04))
		add(oval("BeanieCuff", V(2.32, 0.28, 2.22), hat.Color:Lerp(Color3.new(0, 0, 0), 0.18)), CFrame.new(0, 0.36, 0.04))
		add(oval("Pompom", V(0.4, 0.4, 0.4), Color3.fromRGB(250, 246, 240)), CFrame.new(0, 1.3, 0.04))
	elseif hat and hat.Shape == "Crown" then
		local band = part("Crown", V(0.38, 1.05, 1.05), hat.Color, Enum.PartType.Cylinder)
		band.Material = Enum.Material.Metal
		add(band, CFrame.new(0, 1.07, 0) * ROT_Z90)
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			local spike = part("CrownPoint", V(0.2, 0.34, 0.2), hat.Color)
			spike.Material = Enum.Material.Metal
			add(spike, CFrame.new(math.sin(a) * 0.44, 1.37, -math.cos(a) * 0.44) * CFrame.Angles(0, -a + math.rad(45), 0))
			add(oval("CrownGem", V(0.14, 0.14, 0.14), Color3.fromRGB(255, 90, 120)), CFrame.new(math.sin(a) * 0.44, 1.57, -math.cos(a) * 0.44))
		end
		add(oval("CrownJewel", V(0.18, 0.18, 0.08), Color3.fromRGB(90, 170, 255)), CFrame.new(0, 1.07, -0.53))
	elseif hat and hat.Shape == "Helmet" then
		local glass = oval("Helmet", V(3.3, 3.2, 3.2), hat.Color)
		glass.Material = Enum.Material.Glass
		glass.Transparency = 0.6
		add(glass, CFrame.new(0, 0.3, 0))
		add(part("HelmetRing", V(0.2, 2.0, 2.0), Color3.fromRGB(230, 236, 246), Enum.PartType.Cylinder), CFrame.new(0, -1.08, 0) * ROT_Z90)
	end

	-- Glasses
	if acc and acc.Shape == "Glasses" then
		for i = -1, 1, 2 do
			local lens = oval("Lens", V(0.72, 0.62, 0.1), acc.Color)
			lens.Reflectance = 0.25
			add(lens, CFrame.new(0.5 * i, -0.02, -0.99) * CFrame.Angles(0, math.rad(-21 * i), 0))
		end
		add(part("GlassesBridge", V(0.26, 0.06, 0.06), acc.Color), CFrame.new(0, 0.02, -1.04))
	end
	return head
end

-- ── limbs ────────────────────────────────────────────────────────────────────
-- Armed cats hold both arms forward around the blaster (the gun is welded to
-- the right hand); unarmed arms hang at the sides.
local function buildArm(root: BasePart, i: number, sleeve: Color3, cuff: Color3?, fur, armed: boolean): BasePart
	local arm = oval("Arm", V(0.42, 0.66, 0.42), sleeve)
	local pivot = armed
		and CFrame.new(0.58 * i, 0.12, -0.02) * CFrame.Angles(0, math.rad(34 * i), 0) * CFrame.Angles(math.rad(72), 0, 0)
		or CFrame.new(0.66 * i, 0.12, 0) * CFrame.Angles(0, 0, math.rad(12 * i))
	joint(i < 0 and "PawShoulderL" or "PawShoulderR", root, arm, pivot, CFrame.new(0, -0.3, 0))
	if cuff then
		weld(arm, part("Cuff", V(0.1, 0.44, 0.44), cuff, Enum.PartType.Cylinder), CFrame.new(0, -0.28, 0) * ROT_Z90)
	end
	local hand = oval("Hand", V(0.4, 0.38, 0.4), fur.Body)
	weld(arm, hand, CFrame.new(0, -0.44, -0.02))
	weld(arm, oval("PawPad", V(0.18, 0.13, 0.06), PINK), CFrame.new(0, -0.47, -0.23))
	return hand
end

local GUN_SCALE = 0.36

local function attachBlaster(model: Model, root: BasePart, hand: BasePart, weapon)
	local gunCF = root.CFrame * CFrame.fromMatrix(V(0.08, -0.06, -1.0), V(0, 0, -1), V(0, 1, 0))
	local gun = BlasterBuilder.Build(weapon.Id, weapon.Skin, gunCF, GUN_SCALE)
	gun.Name = "Blaster"
	for _, p in ipairs(gun:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.Massless = true
			local w = Instance.new("Weld")
			w.Part0 = hand
			w.Part1 = p
			w.C0 = hand.CFrame:ToObjectSpace(p.CFrame)
			w.Parent = p
		end
	end
	gun.Parent = model
	model:SetAttribute("Armed", true)
end

-- Short, chunky legs with big round paws.
local function buildLeg(root: BasePart, i: number, shorts: Color3?, fur)
	local leg = oval("Leg", V(0.56, 0.54, 0.56), fur.Body)
	joint(i < 0 and "PawHipL" or "PawHipR", root, leg, CFrame.new(0.3 * i, -0.78, 0), CFrame.new(0, -0.18, 0))
	if shorts then
		weld(leg, oval("ShortsLeg", V(0.68, 0.38, 0.68), shorts), CFrame.new(0, 0.12, 0))
	end
	weld(leg, oval("Foot", V(0.6, 0.34, 0.74), fur.Body), CFrame.new(0, -0.28, -0.1))
	for k = -1, 1 do
		weld(leg, oval("Toe", V(0.13, 0.09, 0.1), fur.Accent), CFrame.new(k * 0.13, -0.3, -0.44))
	end
end

-- A big fluffy tail curling up behind the cat (on the viewer's left).
local function buildTail(root: BasePart, fur)
	local pivot = V(0, -0.6, 0.45)
	local points = {
		V(0.14, -0.62, 0.58), V(0.46, -0.58, 0.7), V(0.8, -0.44, 0.7), V(1.06, -0.18, 0.62),
		V(1.18, 0.14, 0.54), V(1.16, 0.46, 0.46), V(1.04, 0.7, 0.4),
	}
	local marking = fur.Marking or fur.Accent
	local base = oval("Tail1", V(0.46, 0.46, 0.46), fur.Body)
	joint("PawTail", root, base, CFrame.new(pivot), CFrame.new(points[1] - pivot))
	for k = 2, #points do
		local color = fur.Body
		if k == #points then
			color = fur.Pattern == "Calico" and marking or fur.Accent
		elseif fur.Pattern == "Tiger" and k % 2 == 0 then
			color = marking
		end
		local d = 0.5 - k * 0.018
		weld(base, oval("Tail" .. k, V(d, d, d), color), CFrame.new(points[k] - points[1]))
	end
end

-- ── Blender mesh pass ────────────────────────────────────────────────────────
-- Primitive parts the meshes replace. Anchors (joints, the blaster hand) stay
-- but go invisible; everything else is removed.
local MESH_REPLACES = {
	CheekFluff = true, Tuft = true, ForeheadMark = true, MuzzlePuff = true, Mouth = true, Chin = true,
	Nose = true, NoseShine = true, EyeWhite = true, Iris = true, IrisGlow = true, Pupil = true, Shine = true,
	Brow = true, Blush = true, Ear = true, InnerEar = true, EarFluff = true,
	Torso = true, Hips = true, Hood = true, HoodRim = true, Collar = true, Lapel = true, LapelEdge = true,
	Drawstring = true, Aglet = true, TagChain = true, DogTag = true, JacketHem = true, Pocket = true,
	PocketFlap = true, Strap = true, StrapBack = true, Satchel = true, SatchelFlap = true, Buckle = true,
	Cuff = true, PawPad = true, ShortsLeg = true, Foot = true, Toe = true,
	Tail2 = true, Tail3 = true, Tail4 = true, Tail5 = true, Tail6 = true, Tail7 = true,
}
local MESH_ANCHORS = { Head = true, Arm = true, Leg = true, Tail1 = true, Hand = true }
local HOODIE_ONLY = { Jacket = true, Shirt = true, Drawstrings = true, DogTag = true, Pocket = true, Bag = true }

local function meshLibrary(): Instance?
	local lib = ReplicatedStorage:FindFirstChild("CatMeshes")
	-- Only once the imported model (not just the empty folder) is there.
	if lib and lib:FindFirstChild("HeadFur", true) then
		return lib
	end
	return nil
end

function CatBuilder.HasMeshes(): boolean
	return meshLibrary() ~= nil
end

local function applyMeshes(model: Model, root: BasePart, fur, outfit, top: Color3, chest: Color3, shorts: Color3?, cuff: Color3?)
	local lib = meshLibrary()
	if not lib then
		return
	end
	local hoodie = outfit.Id == "Hoodie"
	local marking = fur.Marking or fur.Body:Lerp(Color3.fromRGB(150, 80, 40), 0.22)
	local eyeColor = fur.Eye or Color3.fromRGB(52, 160, 140)
	local colors: { [string]: Color3 } = {
		HeadFur = fur.Body, Hand = fur.Body, Leg = fur.Body, Tail = fur.Body,
		Muzzle = fur.Accent, TailTip = fur.Pattern == "Calico" and marking or fur.Accent,
		ForeheadMark = marking, InnerEar = PINK, PawPad = PINK, Blush = Color3.fromRGB(255, 150, 175),
		Nose = Color3.fromRGB(255, 136, 160), Mouth = Color3.fromRGB(110, 58, 66),
		Brows = fur.Body:Lerp(Color3.new(0, 0, 0), 0.28),
		EyeWhite = Color3.fromRGB(22, 16, 26), Iris = eyeColor:Lerp(Color3.fromRGB(16, 20, 26), 0.45),
		IrisGlow = eyeColor:Lerp(Color3.new(1, 1, 1), 0.12), Pupil = Color3.fromRGB(12, 8, 18), Shine = Color3.new(1, 1, 1),
		Jacket = top, Sleeve = top, Body = top, Shirt = chest, Cuff = cuff or top,
		Drawstrings = Color3.fromRGB(246, 246, 250), DogTag = Color3.fromRGB(214, 218, 228),
		Pocket = Color3.fromRGB(214, 140, 72), Bag = Color3.fromRGB(150, 88, 54),
		Hips = shorts or fur.Body, ShortsLeg = shorts or fur.Body,
	}

	-- Anchors: the rig parts each mesh welds to.
	local anchors: { [string]: { BasePart } } = { Root = { root } }
	local function add(key: string, p: Instance?)
		if p and p:IsA("BasePart") then
			anchors[key] = anchors[key] or {}
			table.insert(anchors[key], p)
		end
	end
	add("Head", model:FindFirstChild("Head"))
	add("Tail", model:FindFirstChild("Tail1"))
	for _, jn in ipairs({ "PawShoulderL", "PawShoulderR" }) do
		local m = root:FindFirstChild(jn) :: Motor6D?
		add("Arm", m and m.Part1)
	end
	for _, jn in ipairs({ "PawHipL", "PawHipR" }) do
		local m = root:FindFirstChild(jn) :: Motor6D?
		add("Leg", m and m.Part1)
	end

	-- Swap: drop the primitive details, hide the anchors.
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") and d ~= root then
			if MESH_ANCHORS[d.Name] then
				d.Transparency = 1
			elseif MESH_REPLACES[d.Name] or (d.Name == "Chest" and hoodie) then
				d:Destroy()
			end
		end
	end

	for _, entry in ipairs(CatMeshData) do
		local name = entry.Name
		local wanted = true
		if HOODIE_ONLY[name] then
			wanted = hoodie
		elseif name == "Body" then
			wanted = not hoodie
		elseif name == "ShortsLeg" then
			wanted = shorts ~= nil
		elseif name == "Cuff" then
			wanted = cuff ~= nil
		elseif name == "ForeheadMark" then
			wanted = fur.Pattern ~= "Tiger"
		end
		local src = wanted and lib:FindFirstChild(name, true)
		if src and src:IsA("MeshPart") then
			for _, anchor in ipairs(anchors[entry.Anchor] or {}) do
				local m = src:Clone()
				m.Name = name
				m.Size = entry.Size
				m.Anchored = false
				m.CanCollide = false
				m.CanQuery = false
				m.CanTouch = false
				m.Massless = true
				m.CastShadow = true
				m.Material = name == "DogTag" and Enum.Material.Metal or Enum.Material.SmoothPlastic
				m.Color = colors[name] or fur.Body
				m.Transparency = name == "Blush" and 0.4 or 0
				m.TextureID = ""
				weld(anchor, m, CFrame.new(entry.Center))
			end
		end
	end
end

-- Build and return the fully assembled cat Model (not yet parented).
-- `weapon` ({ Id, Skin }) puts that blaster in the cat's hands.
function CatBuilder.Build(custom: any?, displayName: string?, weapon: any?): Model
	local fur, outfit, hat, acc = resolve(custom)
	local top, chest, shorts, cuff = outfitColors(outfit, fur)

	local model = Instance.new("Model")
	model.Name = "Cat"

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = ROOT_SIZE
	root.Transparency = 1
	root.CanCollide = true -- the sole collider for the rig
	root.Material = Enum.Material.SmoothPlastic
	root.TopSurface = Enum.SurfaceType.Smooth
	root.BottomSurface = Enum.SurfaceType.Smooth
	root.Parent = model
	model.PrimaryPart = root

	-- Torso, chest and hips
	weld(root, oval("Torso", V(1.3, 1.0, 1.0), top), CFrame.new(0, -0.2, 0))
	weld(root, oval("Chest", V(0.64, 0.8, 0.3), chest), CFrame.new(0, -0.22, -0.38))
	weld(root, oval("Hips", V(1.22, 0.5, 0.96), shorts or fur.Body), CFrame.new(0, -0.68, 0.02))

	local armed = weapon ~= nil and typeof(weapon.Id) == "string"
	local rightHand: BasePart? = nil
	for i = -1, 1, 2 do
		local hand = buildArm(root, i, top, cuff, fur, armed)
		if i == 1 then
			rightHand = hand
		end
		buildLeg(root, i, shorts, fur)
	end
	buildTail(root, fur)
	buildHead(root, fur, hat, acc)
	if outfit.Id ~= "None" then
		addOutfitDetails(root, outfit, top)
	end
	if acc then
		addBackItem(root, acc)
	end
	if armed and rightHand then
		attachBlaster(model, root, rightHand, weapon)
	end
	applyMeshes(model, root, fur, outfit, top, chest, shorts, cuff)

	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.AutomaticScalingEnabled = false
	humanoid.HipHeight = HIP_HEIGHT
	humanoid.WalkSpeed = GameConfig.Character.WalkSpeed
	humanoid.JumpPower = GameConfig.Character.JumpPower
	humanoid.UseJumpPower = true
	humanoid.MaxHealth = GameConfig.Character.Health
	humanoid.Health = GameConfig.Character.Health
	humanoid.AutoRotate = true
	humanoid.BreakJointsOnDeath = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model

	root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)
	model:SetAttribute("PoseSeed", math.random() * 10)
	CollectionService:AddTag(model, CatBuilder.Tag)

	if displayName then
		local nameTag = Instance.new("StringValue")
		nameTag.Name = "DisplayName"
		nameTag.Value = displayName
		nameTag.Parent = model
	end

	return model
end

-- Swap the blaster in a built cat's hands (e.g. a supply-drop weapon).
function CatBuilder.SetBlaster(model: Model, weapon: any)
	local old = model:FindFirstChild("Blaster")
	if old then
		old:Destroy()
	end
	local shoulder = model:FindFirstChild("PawShoulderR", true)
	local arm = shoulder and shoulder:IsA("Motor6D") and shoulder.Part1
	local root = model.PrimaryPart
	if not arm or not root then
		return
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 == arm and d.Part1 and d.Part1.Name == "Hand" then
			attachBlaster(model, root, d.Part1, weapon)
			return
		end
	end
end

-- ── posing ───────────────────────────────────────────────────────────────────
local JOINTS = { "PawNeck", "PawShoulderL", "PawShoulderR", "PawHipL", "PawHipR", "PawTail" }
local OPEN_EYE = { EyeWhite = true, Iris = true, IrisGlow = true, Pupil = true, Shine = true }

type PoseRig = {
	joints: { [string]: { motor: Motor6D, base: CFrame } },
	open: { BasePart },
	shut: { BasePart },
	closed: boolean,
	armed: boolean,
}
local rigCache: { [Model]: PoseRig } = setmetatable({}, { __mode = "k" }) :: any

local function rigFor(model: Model): PoseRig
	local rig = rigCache[model]
	if rig then
		return rig
	end
	local r: PoseRig = { joints = {}, open = {}, shut = {}, closed = false, armed = model:GetAttribute("Armed") == true }
	for _, name in ipairs(JOINTS) do
		local m = model:FindFirstChild(name, true)
		if m and m:IsA("Motor6D") then
			local base = m:GetAttribute("BaseC0")
			if typeof(base) == "CFrame" then
				r.joints[name] = { motor = m, base = base }
			end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			if OPEN_EYE[d.Name] then
				table.insert(r.open, d)
			elseif d.Name == "ClosedEye" then
				table.insert(r.shut, d)
			end
		end
	end
	rigCache[model] = r
	return r
end

-- Poses the cat for time `t`; `move` is 0 standing still, ~1 at walk speed.
function CatBuilder.Pose(model: Model, t: number, move: number)
	local rig = rigFor(model)
	local j = rig.joints

	local closed = (t % 3.7) < 0.12
	if closed ~= rig.closed then
		rig.closed = closed
		for _, p in ipairs(rig.open) do
			p.Transparency = closed and 1 or 0
		end
		for _, p in ipairs(rig.shut) do
			p.Transparency = closed and 0 or 1
		end
	end
	local walk = math.clamp(move, 0, 1)
	local phase = t * (7 + 5 * math.clamp(move, 0, 1.6))
	local swing = math.sin(phase) * 0.65 * walk
	local breathe = math.sin(t * 2.2)
	local idle = 1 - walk
	local function set(name: string, rot: CFrame)
		local e = j[name]
		if e then
			e.motor.C0 = e.base * rot
		end
	end
	set("PawHipL", CFrame.Angles(swing, 0, 0))
	set("PawHipR", CFrame.Angles(-swing, 0, 0))
	if rig.armed then
		-- Arms stay on the blaster: a small breathing / step bob only.
		local aim = CFrame.Angles(breathe * 0.02 + math.abs(math.cos(phase)) * 0.05 * walk, 0, 0)
		set("PawShoulderL", aim)
		set("PawShoulderR", aim)
	else
		set("PawShoulderL", CFrame.Angles(-swing * 0.8, 0, -(0.05 + breathe * 0.04) * idle))
		set("PawShoulderR", CFrame.Angles(swing * 0.8, 0, (0.05 + breathe * 0.04) * idle))
	end
	set("PawNeck", CFrame.Angles(breathe * 0.025 + math.abs(math.cos(phase)) * 0.05 * walk, math.sin(t * 0.7) * 0.08 * idle, math.sin(t * 0.9) * 0.05 * idle))
	set("PawTail", CFrame.Angles(math.sin(t * 1.6) * 0.1, math.sin(t * 2.4 + phase * walk * 0.5) * (0.3 + 0.2 * walk), 0))
end

return CatBuilder
