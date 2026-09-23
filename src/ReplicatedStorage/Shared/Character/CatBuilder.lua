--!strict
-- CatBuilder: builds an original, cute chibi-cat character entirely from
-- Roblox primitives (no Toolbox / no external mesh or texture assets).
--
-- The result is a custom Humanoid rig:
--   Model
--     HumanoidRootPart (invisible collision root; PrimaryPart)
--     Humanoid
--     Body / Head / Ears / Tail / Legs / Muzzle / Eyes ... (welded cosmetics)
--
-- Customization (fur/outfit/hat/accessory) recolors and adds parts. All parts
-- are Massless except the root so the Humanoid mass stays predictable for the
-- knockback model.

local Cats = require(script.Parent.Parent.Config.Cats)
local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local CatBuilder = {}

local ROOT_SIZE = Vector3.new(2, 2, 1.4)
-- The invisible HumanoidRootPart is the ONLY collider (all cosmetics are
-- Massless + CanCollide=false). HipHeight lifts it so the Humanoid hovers
-- instead of dragging the box along the floor, which snagged on seams and
-- shoved the cat sideways. 0.4 puts the stubby legs (1.4 below root centre)
-- exactly on the ground.
local HIP_HEIGHT = 0.4

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
		-- Ball parts are always perfect spheres; a built-in sphere mesh on a
		-- block stretches to the part size, giving real ovals.
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

local function ball(name: string, d: number, color: Color3): BasePart
	return part(name, Vector3.new(d, d, d), color, Enum.PartType.Ball)
end

local function weld(a: BasePart, b: BasePart, cf: CFrame)
	local w = Instance.new("Motor6D")
	w.Name = b.Name .. "_Joint"
	w.Part0 = a
	w.Part1 = b
	w.C0 = cf
	w.C1 = CFrame.new()
	w.Parent = a
	b.CFrame = a.CFrame * cf
end

-- Resolve customization with fallbacks to defaults.
local function resolve(custom)
	custom = custom or {}
	local fur = Cats.FurById[custom.Fur] or Cats.FurById[Cats.Default.Fur]
	local outfit = Cats.OutfitById[custom.Outfit] or Cats.OutfitById[Cats.Default.Outfit]
	local hat = Cats.HatById[custom.Hat] or Cats.HatById[Cats.Default.Hat]
	local acc = Cats.AccessoryById[custom.Accessory] or Cats.AccessoryById[Cats.Default.Accessory]
	return fur, outfit, hat, acc
end

local function addHat(root: BasePart, head: BasePart, hat)
	if not hat or hat.Shape == "None" then
		return
	end
	if hat.Shape == "Cap" then
		local dome = part("Cap", Vector3.new(1.7, 0.7, 1.7), hat.Color, Enum.PartType.Ball)
		dome.Parent = root
		weld(root, dome, CFrame.new(0, 2.55, 0))
		local brim = part("CapBrim", Vector3.new(1.6, 0.15, 0.9), hat.Color)
		brim.Parent = root
		weld(root, brim, CFrame.new(0, 2.35, -0.9))
	elseif hat.Shape == "Beanie" then
		local b = part("Beanie", Vector3.new(1.8, 1.0, 1.8), hat.Color, Enum.PartType.Ball)
		b.Parent = root
		weld(root, b, CFrame.new(0, 2.5, 0))
	elseif hat.Shape == "Crown" then
		-- Cylinders run along X, so X is the band's height after the roll.
		local band = part("Crown", Vector3.new(0.45, 1.3, 1.3), hat.Color, Enum.PartType.Cylinder)
		band.Parent = root
		weld(root, band, CFrame.new(0, 2.62, 0) * CFrame.Angles(0, 0, math.rad(90)))
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			local spike = part("CrownPoint", Vector3.new(0.24, 0.42, 0.24), hat.Color)
			spike.Parent = root
			weld(root, spike, CFrame.new(math.sin(a) * 0.55, 2.98, -math.cos(a) * 0.55) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, math.rad(45), 0))
			local gem = ball("CrownGem", 0.16, Color3.fromRGB(255, 90, 120))
			gem.Parent = root
			weld(root, gem, CFrame.new(math.sin(a) * 0.55, 3.24, -math.cos(a) * 0.55))
		end
	elseif hat.Shape == "Helmet" then
		local h = part("Helmet", Vector3.new(2.1, 2.1, 2.1), hat.Color, Enum.PartType.Ball)
		h.Transparency = 0.35
		h.Material = Enum.Material.Glass
		h.Parent = root
		weld(root, h, CFrame.new(0, 2.3, 0))
	end
end

local function addAccessory(root: BasePart, acc)
	if not acc or acc.Shape == "None" then
		return
	end
	if acc.Shape == "Glasses" then
		for i = -1, 1, 2 do
			local lens = part("Lens", Vector3.new(0.58, 0.48, 0.1), acc.Color, Enum.PartType.Ball)
			lens.Reflectance = 0.25
			lens.Parent = root
			weld(root, lens, CFrame.new(0.4 * i, 1.67, -1.04))
		end
		local bridge = part("GlassesBridge", Vector3.new(0.3, 0.06, 0.06), acc.Color)
		bridge.Parent = root
		weld(root, bridge, CFrame.new(0, 1.74, -1.06))
	elseif acc.Shape == "Backpack" then
		local bp = part("Backpack", Vector3.new(1.2, 1.3, 0.6), acc.Color)
		bp.Parent = root
		weld(root, bp, CFrame.new(0, 0.7, 0.85))
	elseif acc.Shape == "Jetpack" then
		local jp = part("Jetpack", Vector3.new(1.1, 1.3, 0.7), acc.Color)
		jp.Parent = root
		weld(root, jp, CFrame.new(0, 0.8, 0.85))
		for i = -1, 1, 2 do
			local nozzle = part("Nozzle", Vector3.new(0.35, 0.5, 0.35), Color3.fromRGB(60, 60, 70), Enum.PartType.Cylinder)
			nozzle.Parent = root
			weld(root, nozzle, CFrame.new(0.4 * i, 0.1, 0.95) * CFrame.Angles(math.rad(90), 0, 0))
		end
	end
end

-- Small front-facing fur markings keep the catalog variants visually distinct
-- in-world without adding textures or external assets.
local function addFurMarkings(root: BasePart, fur)
	if not fur or fur.Pattern == "Solid" then
		return
	end
	local marking = fur.Marking or fur.Accent
	if fur.Pattern == "Tiger" then
		for i = -1, 1 do
			local stripe = part("TigerStripe", Vector3.new(0.16, 0.55, 0.06), marking)
			stripe.Parent = root
			weld(root, stripe, CFrame.new(i * 0.32, 1.88, -0.88) * CFrame.Angles(0, 0, math.rad(i * 12)))
		end
		for i = -1, 1 do
			local stripe = part("TigerBodyStripe", Vector3.new(0.18, 0.42, 0.05), marking)
			stripe.Parent = root
			weld(root, stripe, CFrame.new(i * 0.48, 0.28, -0.77) * CFrame.Angles(0, 0, math.rad(i * 18)))
		end
	elseif fur.Pattern == "Calico" then
		local patch = part("CalicoPatch", Vector3.new(0.46, 0.42, 0.08), marking, Enum.PartType.Ball)
		patch.Parent = root
		weld(root, patch, CFrame.new(0.34, 1.92, -0.82))
		local patch2 = part("CalicoBodyPatch", Vector3.new(0.52, 0.62, 0.08), marking, Enum.PartType.Ball)
		patch2.Parent = root
		weld(root, patch2, CFrame.new(-0.42, 0.25, -0.72))
	end
end

local function addOutfitDetails(root: BasePart, outfit)
	if not outfit or outfit.Id == "None" then
		return
	end
	local id = outfit.Id
	if id == "Hoodie" then
		local hood = part("Hood", Vector3.new(1.72, 0.7, 1.55), outfit.Color, Enum.PartType.Ball)
		hood.Parent = root
		weld(root, hood, CFrame.new(0, 1.15, 0.18))
		for i = -1, 1, 2 do
			local cord = part("Drawstring", Vector3.new(0.06, 0.42, 0.06), Color3.fromRGB(240, 240, 248))
			cord.Parent = root
			weld(root, cord, CFrame.new(0.2 * i, 0.5, -0.68))
			local aglet = part("Aglet", Vector3.new(0.1, 0.12, 0.1), Color3.fromRGB(200, 205, 215), Enum.PartType.Ball)
			aglet.Parent = root
			weld(root, aglet, CFrame.new(0.2 * i, 0.27, -0.74))
		end
		local pocket = part("Pocket", Vector3.new(0.95, 0.32, 0.08), outfit.Color:Lerp(Color3.new(0, 0, 0), 0.18))
		pocket.Parent = root
		weld(root, pocket, CFrame.new(0, -0.36, -0.82))
	elseif id == "Streetwear" then
		local collar = part("StreetwearCollar", Vector3.new(1.5, 0.35, 1.25), outfit.Color:Lerp(Color3.new(1, 1, 1), 0.18), Enum.PartType.Ball)
		collar.Parent = root
		weld(root, collar, CFrame.new(0, 0.95, 0))
		local zipper = part("StreetwearZipper", Vector3.new(0.08, 0.95, 0.08), Color3.fromRGB(220, 235, 245))
		zipper.Parent = root
		weld(root, zipper, CFrame.new(0, 0.18, -0.84))
	elseif id == "Robot" then
		local plate = part("RobotChest", Vector3.new(1.1, 0.9, 0.3), outfit.Color:Lerp(Color3.new(1, 1, 1), 0.2), Enum.PartType.Ball)
		plate.Parent = root
		weld(root, plate, CFrame.new(0, 0.2, -0.74))
		local core = part("RobotCore", Vector3.new(0.42, 0.42, 0.12), Color3.fromRGB(35, 210, 255), Enum.PartType.Ball)
		core.Material = Enum.Material.Neon
		core.Parent = root
		weld(root, core, CFrame.new(0, 0.2, -0.9))
	elseif id == "Ninja" then
		local sash = part("NinjaSash", Vector3.new(1.9, 0.18, 1.55), Color3.fromRGB(165, 40, 60))
		sash.Parent = root
		weld(root, sash, CFrame.new(0, 0.45, 0))
	elseif id == "Royal" then
		local cape = part("RoyalCape", Vector3.new(1.75, 1.85, 0.28), outfit.Color)
		cape.Parent = root
		weld(root, cape, CFrame.new(0, 0.25, 0.72))
		local sash = part("RoyalSash", Vector3.new(0.18, 1.25, 0.1), Color3.fromRGB(255, 210, 80))
		sash.Parent = root
		weld(root, sash, CFrame.new(0, 0.22, -0.84))
	elseif id == "Space" then
		local suit = part("SpaceSuit", Vector3.new(1.82, 1.45, 1.45), outfit.Color, Enum.PartType.Ball)
		suit.Parent = root
		weld(root, suit, CFrame.new(0, 0.12, 0))
		local lifePack = part("SpacePack", Vector3.new(1.15, 1.2, 0.38), Color3.fromRGB(120, 150, 190))
		lifePack.Parent = root
		weld(root, lifePack, CFrame.new(0, 0.45, 0.82))
	end
end

-- Build and return the fully assembled cat Model (not yet parented).
function CatBuilder.Build(custom: any?, displayName: string?): Model
	local fur, outfit, hat, acc = resolve(custom)

	local model = Instance.new("Model")
	model.Name = "Cat"

	-- Root ---------------------------------------------------------------
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

	-- Body (rounded torso) ----------------------------------------------
	local hasOutfit = outfit.Id ~= "None"
	local bodyColor = hasOutfit and outfit.Color or fur.Body
	local body = oval("Body", Vector3.new(2, 1.9, 1.5), bodyColor)
	body.Parent = model
	weld(root, body, CFrame.new(0, 0.1, 0))

	local belly = oval("Belly", Vector3.new(1.3, 1.2, 0.6), fur.Accent)
	belly.Parent = model
	weld(root, belly, CFrame.new(0, -0.1, -0.52))

	-- Arms: sleeves in the outfit colour, paws in fur.
	for i = -1, 1, 2 do
		local arm = oval("Arm", Vector3.new(0.46, 0.9, 0.46), bodyColor)
		arm.Parent = model
		weld(root, arm, CFrame.new(0.93 * i, 0.05, -0.15) * CFrame.Angles(0, 0, math.rad(12 * i)))
		local paw = oval("Paw", Vector3.new(0.42, 0.36, 0.44), fur.Body)
		paw.Parent = model
		weld(root, paw, CFrame.new(1.02 * i, -0.38, -0.2))
	end

	-- Head ---------------------------------------------------------------
	local head = ball("Head", 1.9, fur.Body)
	head.Parent = model
	weld(root, head, CFrame.new(0, 1.55, 0))

	-- Muzzle, nose and a little "w" mouth
	local muzzle = oval("Muzzle", Vector3.new(0.9, 0.56, 0.5), fur.Accent)
	muzzle.Parent = model
	weld(root, muzzle, CFrame.new(0, 1.32, -0.78))

	local nose = oval("Nose", Vector3.new(0.22, 0.15, 0.14), Color3.fromRGB(255, 140, 165))
	nose.Parent = model
	weld(root, nose, CFrame.new(0, 1.44, -1.02))
	for i = -1, 1, 2 do
		local mouth = part("Mouth", Vector3.new(0.16, 0.04, 0.04), Color3.fromRGB(70, 45, 55))
		mouth.Parent = model
		weld(root, mouth, CFrame.new(0.07 * i, 1.3, -1.035) * CFrame.Angles(0, 0, math.rad(-30 * i)))
	end
	addFurMarkings(root, fur)

	-- Eyes: big glossy ovals with a coloured iris and two highlights.
	local eyeColor = fur.Eye or Color3.fromRGB(52, 160, 140)
	for i = -1, 1, 2 do
		local white = oval("EyeWhite", Vector3.new(0.52, 0.64, 0.3), Color3.fromRGB(255, 255, 255))
		white.Parent = model
		weld(root, white, CFrame.new(0.4 * i, 1.66, -0.8))
		local iris = oval("Iris", Vector3.new(0.46, 0.58, 0.28), eyeColor)
		iris.Parent = model
		weld(root, iris, CFrame.new(0.41 * i, 1.65, -0.86))
		local pupil = oval("Pupil", Vector3.new(0.26, 0.36, 0.24), Color3.fromRGB(25, 20, 35))
		pupil.Parent = model
		weld(root, pupil, CFrame.new(0.42 * i, 1.63, -0.93))
		local shine = oval("Shine", Vector3.new(0.16, 0.18, 0.1), Color3.fromRGB(255, 255, 255))
		shine.Parent = model
		weld(root, shine, CFrame.new(0.47 * i, 1.76, -1.0))
		local shine2 = ball("Shine", 0.08, Color3.fromRGB(255, 255, 255))
		shine2.Parent = model
		weld(root, shine2, CFrame.new(0.36 * i, 1.55, -1.01))
		local cheek = oval("Cheek", Vector3.new(0.34, 0.2, 0.08), Color3.fromRGB(255, 150, 175))
		cheek.Transparency = 0.35
		cheek.Parent = model
		weld(root, cheek, CFrame.new(0.62 * i, 1.4, -0.72) * CFrame.Angles(0, math.rad(-35 * i), 0))
	end

	-- Ears: two mirrored wedges per ear form a pointed triangle facing the
	-- front (a wedge's tall side is its back face), with a pink inner ear.
	local function earHalf(name: string, size: Vector3, color: Color3, cf: CFrame)
		local w = Instance.new("WedgePart")
		w.Name = name
		w.Size = size
		w.Color = color
		w.Material = Enum.Material.SmoothPlastic
		w.CanCollide = false
		w.CanQuery = false
		w.CanTouch = false
		w.Massless = true
		w.Parent = model
		weld(root, w, cf)
	end
	for i = -1, 1, 2 do
		local earCF = CFrame.new(0.58 * i, 2.45, 0) * CFrame.Angles(0, 0, math.rad(-14 * i))
		earHalf("Ear", Vector3.new(0.28, 1.0, 0.5), fur.Body, earCF * CFrame.new(-0.25, 0, 0) * CFrame.Angles(0, math.rad(90), 0))
		earHalf("Ear", Vector3.new(0.28, 1.0, 0.5), fur.Body, earCF * CFrame.new(0.25, 0, 0) * CFrame.Angles(0, math.rad(-90), 0))
		local pink = Color3.fromRGB(255, 172, 192)
		earHalf("InnerEar", Vector3.new(0.06, 0.62, 0.28), pink, earCF * CFrame.new(-0.14, -0.08, -0.17) * CFrame.Angles(0, math.rad(90), 0))
		earHalf("InnerEar", Vector3.new(0.06, 0.62, 0.28), pink, earCF * CFrame.new(0.14, -0.08, -0.17) * CFrame.Angles(0, math.rad(-90), 0))
	end

	-- Legs (stubby)
	for i = -1, 1, 2 do
		local frontLeg = oval("FrontLeg", Vector3.new(0.55, 0.8, 0.6), fur.Body)
		frontLeg.Parent = model
		weld(root, frontLeg, CFrame.new(0.55 * i, -1.0, -0.45))
		local backLeg = oval("BackLeg", Vector3.new(0.6, 0.85, 0.6), fur.Body)
		backLeg.Parent = model
		weld(root, backLeg, CFrame.new(0.6 * i, -1.0, 0.45))
	end

	-- Tail (segmented curl)
	for s = 1, 4 do
		local seg = oval("Tail" .. s, Vector3.new(0.5 - s * 0.05, 0.5 - s * 0.05, 0.5), fur.Body)
		seg.Parent = model
		local cf = CFrame.new(0, 0.2 + s * 0.35, 0.9 + s * 0.18) * CFrame.Angles(math.rad(-30 * s / 2), 0, 0)
		weld(root, seg, cf)
	end
	local tip = ball("TailTip", 0.35, fur.Accent)
	tip.Parent = model
	weld(root, tip, CFrame.new(0, 1.7, 1.65) * CFrame.Angles(math.rad(-70), 0, 0))

	addOutfitDetails(root, outfit)
	addHat(root, head, hat)
	addAccessory(root, acc)

	-- Humanoid -----------------------------------------------------------
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

	-- Collision root density.
	root.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0.3, 0.5, 1, 1)

	if displayName then
		local nameTag = Instance.new("StringValue")
		nameTag.Name = "DisplayName"
		nameTag.Value = displayName
		nameTag.Parent = model
	end

	return model
end

return CatBuilder
