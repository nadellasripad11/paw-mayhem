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

CatBuilder.Tag = "PawCat"

local ROOT_SIZE = Vector3.new(2, 2, 1.4)
-- The invisible root is the only collider. HipHeight lifts it so the
-- Humanoid hovers instead of dragging the box along the floor (which snagged
-- on seams and shoved the cat sideways); 0.4 puts the feet on the ground.
local HIP_HEIGHT = 0.4

local V = Vector3.new
local HEAD_POS = V(0, 1.41, 0) -- head centre in root space
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
		return outfit.Color, Color3.fromRGB(234, 222, 200), Color3.fromRGB(58, 48, 54), outfit.Color:Lerp(Color3.new(0, 0, 0), 0.25)
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

-- The torso is ~0.74x as wide and ~0.82x as deep as the original design that
-- the outfit/back-item offsets were authored against; squeeze them to fit.
local SLIM_X, SLIM_Z = 0.74, 0.82
local function slim(p: BasePart, cf: CFrame): CFrame
	p.Size = V(p.Size.X * SLIM_X, p.Size.Y * 0.92, p.Size.Z * SLIM_Z)
	local pos = cf.Position
	return CFrame.new(pos.X * SLIM_X, pos.Y, pos.Z * SLIM_Z) * cf.Rotation
end

-- ── outfit details (torso, root space) ──────────────────────────────────────
local function addOutfitDetails(root: BasePart, outfit, top: Color3)
	local id = outfit.Id
	local dark = top:Lerp(Color3.new(0, 0, 0), 0.22)
	local function add(p: BasePart, cf: CFrame)
		weld(root, p, slim(p, cf))
	end
	if id == "Hoodie" then
		add(oval("Hood", V(1.35, 0.55, 0.95), top), CFrame.new(0, 0.55, 0.4))
		for i = -1, 1, 2 do
			add(part("Lapel", V(0.1, 0.95, 0.08), dark), CFrame.new(0.36 * i, -0.02, -0.49) * CFrame.Angles(0, math.rad(-20 * i), 0))
			add(part("Drawstring", V(0.05, 0.4, 0.05), Color3.fromRGB(244, 244, 250)), CFrame.new(0.15 * i, 0.2, -0.6))
			add(oval("Aglet", V(0.09, 0.11, 0.09), Color3.fromRGB(200, 205, 215)), CFrame.new(0.15 * i, -0.01, -0.61))
			add(part("PocketFlap", V(0.3, 0.08, 0.05), dark), CFrame.new(0.42 * i, -0.3, -0.34) * CFrame.Angles(0, math.rad(-30 * i), 0))
		end
		local tag = part("DogTag", V(0.03, 0.2, 0.2), Color3.fromRGB(206, 210, 220), Enum.PartType.Cylinder)
		tag.Material = Enum.Material.Metal
		add(tag, CFrame.new(-0.02, 0.36, -0.6) * ROT_Y90)
		local leather = Color3.fromRGB(128, 84, 52)
		add(part("Strap", V(0.09, 1.1, 0.05), leather), CFrame.new(-0.02, 0.05, -0.63) * CFrame.Angles(0, 0, math.rad(-53)))
		add(oval("Satchel", V(0.46, 0.4, 0.18), leather), CFrame.new(-0.5, -0.36, -0.3))
		add(oval("SatchelFlap", V(0.46, 0.2, 0.2), leather:Lerp(Color3.new(0, 0, 0), 0.2)), CFrame.new(-0.5, -0.24, -0.32))
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
			add(part("BackpackStrap", V(0.12, 0.7, 0.05), acc.Color:Lerp(Color3.new(0, 0, 0), 0.3)), CFrame.new(0.4 * i, 0.18, -0.46) * CFrame.Angles(0, math.rad(-30 * i), 0))
		end
	elseif acc.Shape == "Jetpack" then
		for i = -1, 1, 2 do
			local tank = part("JetTank", V(0.9, 0.42, 0.42), acc.Color, Enum.PartType.Cylinder)
			tank.Material = Enum.Material.Metal
			weld(root, tank, CFrame.new(0.2 * i, 0.12, 0.6) * ROT_Z90)
			weld(root, oval("JetCap", V(0.42, 0.26, 0.42), acc.Color), CFrame.new(0.2 * i, 0.57, 0.6))
			weld(root, part("JetNozzle", V(0.22, 0.3, 0.3), Color3.fromRGB(60, 60, 70), Enum.PartType.Cylinder), CFrame.new(0.2 * i, -0.43, 0.6) * ROT_Z90)
			local flame = oval("JetFlame", V(0.22, 0.42, 0.22), Color3.fromRGB(255, 150, 50))
			flame.Material = Enum.Material.Neon
			weld(root, flame, CFrame.new(0.2 * i, -0.72, 0.6))
		end
	end
end

-- ── head: face, ears, markings, hats, glasses (head space) ──────────────────
local function buildHead(root: BasePart, fur, hat, acc): BasePart
	local head = oval("Head", V(2.2, 1.9, 1.85), fur.Body)
	joint("PawNeck", root, head, CFrame.new(0, 0.55, 0), CFrame.new(0, 0.86, 0))
	local function add(p: BasePart, cf: CFrame)
		weld(head, p, cf)
	end
	local marking = fur.Marking or fur.Accent

	-- Fluffy side tufts (sweeping out and back, not forward) + a tuft on top
	for i = -1, 1, 2 do
		add(oval("CheekFluff", V(0.5, 0.42, 0.62), fur.Body), CFrame.new(0.9 * i, -0.34, -0.12) * CFrame.Angles(0, 0, math.rad(-24 * i)))
		add(oval("CheekFluff", V(0.34, 0.28, 0.44), fur.Body), CFrame.new(1.04 * i, -0.2, 0.02) * CFrame.Angles(0, 0, math.rad(-38 * i)))
	end
	add(oval("Tuft", V(0.26, 0.44, 0.22), fur.Body), CFrame.new(-0.08, 0.96, -0.12) * CFrame.Angles(0, 0, math.rad(15)))
	add(oval("Tuft", V(0.22, 0.38, 0.2), fur.Body), CFrame.new(0.1, 0.93, -0.08) * CFrame.Angles(0, 0, math.rad(-22)))

	-- Small muzzle, tiny pink nose and a little "w" mouth
	for i = -1, 1, 2 do
		add(oval("MuzzlePuff", V(0.3, 0.22, 0.2), fur.Accent), CFrame.new(0.11 * i, -0.38, -0.86))
		local mouth = part("Mouth", V(0.13, 0.035, 0.03), Color3.fromRGB(110, 60, 70))
		add(mouth, CFrame.new(0.058 * i, -0.39, -0.955) * CFrame.Angles(0, math.rad(-14 * i), math.rad(24 * i)))
	end
	add(oval("Chin", V(0.24, 0.12, 0.16), fur.Accent), CFrame.new(0, -0.5, -0.8))
	add(oval("Nose", V(0.15, 0.1, 0.1), Color3.fromRGB(255, 138, 162)), CFrame.new(0, -0.26, -0.945))

	-- Eyes: big, dark and glossy. Dark rim, coloured iris that glows lighter
	-- at the bottom, a large pupil and two white highlights.
	local eyeColor = fur.Eye or Color3.fromRGB(52, 160, 140)
	for i = -1, 1, 2 do
		local turn = CFrame.Angles(0, math.rad(-16 * i), 0)
		local function at(x: number, y: number, z: number): CFrame
			return CFrame.new(0.44 * i + x * i, y, z) * turn
		end
		add(oval("EyeWhite", V(0.54, 0.66, 0.24), Color3.fromRGB(28, 22, 32)), at(0, -0.04, -0.8))
		add(oval("Iris", V(0.47, 0.59, 0.24), eyeColor:Lerp(Color3.fromRGB(20, 16, 26), 0.35)), at(0, -0.04, -0.815))
		add(oval("IrisGlow", V(0.36, 0.26, 0.22), eyeColor:Lerp(Color3.new(1, 1, 1), 0.2)), at(0, -0.19, -0.835))
		add(oval("Pupil", V(0.3, 0.4, 0.22), Color3.fromRGB(16, 12, 22)), at(0, -0.02, -0.85))
		add(oval("Shine", V(0.19, 0.21, 0.08), Color3.new(1, 1, 1)), at(0.07, 0.11, -0.93))
		add(oval("Shine", V(0.09, 0.09, 0.07), Color3.new(1, 1, 1)), at(-0.08, -0.17, -0.92))
		local shut = part("ClosedEye", V(0.42, 0.07, 0.05), Color3.fromRGB(40, 30, 40))
		shut.Transparency = 1
		add(shut, at(0, -0.04, -0.9) * CFrame.Angles(0, 0, math.rad(-8 * i)))
		local blush = oval("Blush", V(0.3, 0.15, 0.06), Color3.fromRGB(255, 150, 175))
		blush.Transparency = 0.45
		add(blush, CFrame.new(0.7 * i, -0.34, -0.7) * CFrame.Angles(0, math.rad(-38 * i), 0))
	end

	-- Ears: two mirrored wedges each (a wedge's tall side is its back face),
	-- pink inside. Calico gets one patched ear.
	for i = -1, 1, 2 do
		local earColor = (fur.Pattern == "Calico" and i == -1) and marking or fur.Body
		local earCF = CFrame.new(0.56 * i, 1.04, 0.05) * CFrame.Angles(0, 0, math.rad(-14 * i))
		add(wedge("Ear", V(0.32, 1.2, 0.5), earColor), earCF * CFrame.new(-0.25, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
		add(wedge("Ear", V(0.32, 1.2, 0.5), earColor), earCF * CFrame.new(0.25, 0, 0) * CFrame.Angles(0, math.rad(-90), 0))
		add(wedge("InnerEar", V(0.06, 0.8, 0.3), PINK), earCF * CFrame.new(-0.15, -0.1, -0.2) * CFrame.Angles(0, math.rad(90), 0))
		add(wedge("InnerEar", V(0.06, 0.8, 0.3), PINK), earCF * CFrame.new(0.15, -0.1, -0.2) * CFrame.Angles(0, math.rad(-90), 0))
	end

	-- Fur markings
	if fur.Pattern == "Tiger" then
		for i = -1, 1 do
			local z = i == 0 and -0.64 or -0.6
			add(part("TigerStripe", V(0.12, 0.42, 0.06), marking), CFrame.new(i * 0.26, 0.68, z - 0.02) * CFrame.Angles(math.rad(-40), 0, math.rad(i * 14)))
		end
		for i = -1, 1, 2 do
			for k = 0, 1 do
				add(part("CheekStripe", V(0.28, 0.07, 0.06), marking), CFrame.new(0.95 * i, -0.06 - k * 0.16, -0.47) * CFrame.Angles(0, math.rad(-58 * i), math.rad(8 * i)))
			end
		end
	elseif fur.Pattern == "Calico" then
		add(oval("CalicoPatch", V(0.6, 0.52, 0.14), marking), CFrame.new(0.48, 0.42, -0.6) * CFrame.Angles(0, math.rad(-35), 0))
		add(oval("CalicoPatch", V(0.5, 0.4, 0.12), Color3.fromRGB(60, 50, 50)), CFrame.new(-0.62, 0.2, -0.58) * CFrame.Angles(0, math.rad(40), 0))
	end

	-- Hats
	if hat and hat.Shape == "Cap" then
		add(oval("Cap", V(1.9, 0.8, 1.85), hat.Color), CFrame.new(0, 0.68, 0.02))
		add(part("CapBrim", V(1.3, 0.1, 0.75), hat.Color:Lerp(Color3.new(0, 0, 0), 0.15)), CFrame.new(0, 0.55, -0.9) * CFrame.Angles(math.rad(-8), 0, 0))
		add(oval("CapButton", V(0.16, 0.1, 0.16), hat.Color:Lerp(Color3.new(1, 1, 1), 0.3)), CFrame.new(0, 1.08, 0.02))
	elseif hat and hat.Shape == "Beanie" then
		add(oval("Beanie", V(2.05, 1.05, 2.0), hat.Color), CFrame.new(0, 0.68, 0.04))
		add(oval("BeanieCuff", V(2.12, 0.26, 2.05), hat.Color:Lerp(Color3.new(0, 0, 0), 0.18)), CFrame.new(0, 0.36, 0.04))
		add(oval("Pompom", V(0.38, 0.38, 0.38), Color3.fromRGB(250, 246, 240)), CFrame.new(0, 1.26, 0.04))
	elseif hat and hat.Shape == "Crown" then
		local band = part("Crown", V(0.38, 1.05, 1.05), hat.Color, Enum.PartType.Cylinder)
		band.Material = Enum.Material.Metal
		add(band, CFrame.new(0, 1.05, 0) * ROT_Z90)
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			local spike = part("CrownPoint", V(0.2, 0.34, 0.2), hat.Color)
			spike.Material = Enum.Material.Metal
			add(spike, CFrame.new(math.sin(a) * 0.44, 1.35, -math.cos(a) * 0.44) * CFrame.Angles(0, -a + math.rad(45), 0))
			add(oval("CrownGem", V(0.14, 0.14, 0.14), Color3.fromRGB(255, 90, 120)), CFrame.new(math.sin(a) * 0.44, 1.55, -math.cos(a) * 0.44))
		end
		add(oval("CrownJewel", V(0.18, 0.18, 0.08), Color3.fromRGB(90, 170, 255)), CFrame.new(0, 1.05, -0.53))
	elseif hat and hat.Shape == "Helmet" then
		local glass = oval("Helmet", V(3.0, 3.0, 3.0), hat.Color)
		glass.Material = Enum.Material.Glass
		glass.Transparency = 0.6
		add(glass, CFrame.new(0, 0.35, 0))
		add(part("HelmetRing", V(0.2, 1.8, 1.8), Color3.fromRGB(230, 236, 246), Enum.PartType.Cylinder), CFrame.new(0, -1.05, 0) * ROT_Z90)
	end

	-- Glasses
	if acc and acc.Shape == "Glasses" then
		for i = -1, 1, 2 do
			local lens = oval("Lens", V(0.6, 0.5, 0.1), acc.Color)
			lens.Reflectance = 0.25
			add(lens, CFrame.new(0.44 * i, -0.04, -0.96) * CFrame.Angles(0, math.rad(-16 * i), 0))
		end
		add(part("GlassesBridge", V(0.26, 0.06, 0.06), acc.Color), CFrame.new(0, 0.0, -1.0))
	end
	return head
end

-- ── limbs ────────────────────────────────────────────────────────────────────
-- Armed cats hold both arms forward around the blaster (the gun is welded to
-- the right hand); unarmed arms hang at the sides.
local function buildArm(root: BasePart, i: number, sleeve: Color3, cuff: Color3?, fur, armed: boolean): BasePart
	local arm = oval("Arm", V(0.32, 0.7, 0.32), sleeve)
	local pivot = armed
		and CFrame.new(0.48 * i, 0.34, -0.02) * CFrame.Angles(0, math.rad(34 * i), 0) * CFrame.Angles(math.rad(72), 0, 0)
		or CFrame.new(0.52 * i, 0.34, -0.02) * CFrame.Angles(0, 0, math.rad(8 * i))
	joint(i < 0 and "PawShoulderL" or "PawShoulderR", root, arm, pivot, CFrame.new(0, -0.34, 0))
	if cuff then
		weld(arm, part("Cuff", V(0.1, 0.36, 0.36), cuff, Enum.PartType.Cylinder), CFrame.new(0, -0.27, 0) * ROT_Z90)
	end
	local hand = oval("Hand", V(0.33, 0.31, 0.34), fur.Body)
	weld(arm, hand, CFrame.new(0, -0.42, -0.04))
	weld(arm, oval("PawPad", V(0.16, 0.12, 0.06), PINK), CFrame.new(0, -0.45, -0.23))
	return hand
end

local GUN_SCALE = 0.36

local function attachBlaster(model: Model, root: BasePart, hand: BasePart, weapon)
	local gunCF = root.CFrame * CFrame.fromMatrix(V(0.08, 0.16, -0.95), V(0, 0, -1), V(0, 1, 0))
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

local function buildLeg(root: BasePart, i: number, shorts: Color3?, fur)
	local leg = oval("Leg", V(0.38, 0.56, 0.4), fur.Body)
	joint(i < 0 and "PawHipL" or "PawHipR", root, leg, CFrame.new(0.27 * i, -0.62, 0), CFrame.new(0, -0.26, 0))
	if shorts then
		weld(leg, oval("ShortsLeg", V(0.48, 0.34, 0.5), shorts), CFrame.new(0, 0.16, 0))
	end
	weld(leg, oval("Foot", V(0.44, 0.28, 0.62), fur.Body), CFrame.new(0, -0.36, -0.1))
	for k = -1, 1 do
		weld(leg, oval("Toe", V(0.1, 0.07, 0.09), fur.Accent), CFrame.new(k * 0.1, -0.28, -0.36))
	end
end

local function buildTail(root: BasePart, fur)
	local pivot = V(0, -0.42, 0.5)
	local points = {
		V(0, -0.5, 0.6), V(0.05, -0.3, 0.85), V(0.12, -0.05, 1.02), V(0.2, 0.22, 1.1),
		V(0.27, 0.5, 1.08), V(0.32, 0.74, 0.98), V(0.34, 0.92, 0.84),
	}
	local marking = fur.Marking or fur.Accent
	local base = oval("Tail1", V(0.38, 0.38, 0.38), fur.Body)
	joint("PawTail", root, base, CFrame.new(pivot), CFrame.new(points[1] - pivot))
	for s = 2, #points do
		local color = fur.Body
		if s == #points then
			color = fur.Pattern == "Calico" and marking or fur.Accent
		elseif fur.Pattern == "Tiger" and s % 2 == 0 then
			color = marking
		end
		local d = 0.38 - s * 0.012
		weld(base, oval("Tail" .. s, V(d, d, d), color), CFrame.new(points[s] - points[1]))
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
	weld(root, oval("Torso", V(1.08, 1.12, 0.86), top), CFrame.new(0, 0.02, 0))
	weld(root, oval("Chest", V(0.58, 0.82, 0.28), chest), CFrame.new(0, -0.02, -0.34))
	weld(root, oval("Hips", V(1.06, 0.62, 0.88), shorts or fur.Body), CFrame.new(0, -0.5, 0.02))

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
