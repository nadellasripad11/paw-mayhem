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
-- Massless + CanCollide=false), so it must collide or the cat falls through the
-- floor. HipHeight 0 rests the root's bottom on the ground; cosmetics are welded
-- so the stubby legs sit at that bottom.
local HIP_HEIGHT = 0

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
	p.Massless = true
	if shape then
		p.Shape = shape
	end
	return p
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
		local band = part("Crown", Vector3.new(1.5, 0.5, 1.5), hat.Color, Enum.PartType.Cylinder)
		band.Parent = root
		weld(root, band, CFrame.new(0, 2.7, 0) * CFrame.Angles(0, 0, math.rad(90)))
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
		local g = part("Glasses", Vector3.new(1.6, 0.4, 0.15), acc.Color)
		g.Parent = root
		weld(root, g, CFrame.new(0, 2.15, -0.85))
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
	local bodyColor = (outfit.Id ~= "None") and outfit.Color or fur.Body
	local body = part("Body", Vector3.new(2, 1.9, 1.5), bodyColor, Enum.PartType.Ball)
	body.Parent = model
	weld(root, body, CFrame.new(0, 0.1, 0))

	local belly = part("Belly", Vector3.new(1.4, 1.3, 1.0), fur.Accent, Enum.PartType.Ball)
	belly.Parent = model
	weld(root, belly, CFrame.new(0, -0.1, -0.55))

	-- Head ---------------------------------------------------------------
	local head = ball("Head", 1.9, fur.Body)
	head.Parent = model
	weld(root, head, CFrame.new(0, 1.55, 0))

	-- Muzzle / nose
	local muzzle = part("Muzzle", Vector3.new(1.0, 0.7, 0.6), fur.Accent, Enum.PartType.Ball)
	muzzle.Parent = model
	weld(root, muzzle, CFrame.new(0, 1.35, -0.75))

	local nose = part("Nose", Vector3.new(0.24, 0.18, 0.18), Color3.fromRGB(255, 150, 170), Enum.PartType.Ball)
	nose.Parent = model
	weld(root, nose, CFrame.new(0, 1.42, -1.0))

	-- Eyes (big and cute)
	for i = -1, 1, 2 do
		local eyeWhite = part("EyeWhite", Vector3.new(0.55, 0.62, 0.35), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
		eyeWhite.Parent = model
		weld(root, eyeWhite, CFrame.new(0.42 * i, 1.7, -0.78))
		local pupil = part("Pupil", Vector3.new(0.3, 0.38, 0.3), Color3.fromRGB(35, 30, 45), Enum.PartType.Ball)
		pupil.Parent = model
		weld(root, pupil, CFrame.new(0.44 * i, 1.68, -0.92))
		local shine = part("Shine", Vector3.new(0.12, 0.12, 0.12), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball)
		shine.Parent = model
		weld(root, shine, CFrame.new(0.5 * i, 1.78, -1.0))
	end

	-- Ears (triangular via wedges) + inner ear
	for i = -1, 1, 2 do
		local ear = Instance.new("WedgePart")
		ear.Name = "Ear"
		ear.Size = Vector3.new(0.6, 0.8, 0.7)
		ear.Color = fur.Body
		ear.Material = Enum.Material.SmoothPlastic
		ear.CanCollide = false
		ear.CanQuery = false
		ear.Massless = true
		ear.Parent = model
		weld(root, ear, CFrame.new(0.6 * i, 2.5, 0.1) * CFrame.Angles(0, math.rad(-20 * i), math.rad(-8 * i)))
		local innerEar = part("InnerEar", Vector3.new(0.3, 0.4, 0.35), fur.Accent, Enum.PartType.Ball)
		innerEar.Parent = model
		weld(root, innerEar, CFrame.new(0.6 * i, 2.4, 0.0))
	end

	-- Legs (stubby)
	for i = -1, 1, 2 do
		local frontLeg = part("FrontLeg", Vector3.new(0.55, 0.8, 0.55), fur.Body, Enum.PartType.Ball)
		frontLeg.Parent = model
		weld(root, frontLeg, CFrame.new(0.55 * i, -1.0, -0.45))
		local backLeg = part("BackLeg", Vector3.new(0.6, 0.85, 0.6), fur.Body, Enum.PartType.Ball)
		backLeg.Parent = model
		weld(root, backLeg, CFrame.new(0.6 * i, -1.0, 0.45))
	end

	-- Tail (segmented curl)
	for s = 1, 4 do
		local seg = part("Tail" .. s, Vector3.new(0.5 - s * 0.05, 0.5 - s * 0.05, 0.5), fur.Body, Enum.PartType.Ball)
		seg.Parent = model
		local cf = CFrame.new(0, 0.2 + s * 0.35, 0.9 + s * 0.18) * CFrame.Angles(math.rad(-30 * s / 2), 0, 0)
		weld(root, seg, cf)
	end
	local tip = part("TailTip", Vector3.new(0.35, 0.35, 0.35), fur.Accent, Enum.PartType.Ball)
	tip.Parent = model
	weld(root, tip, CFrame.new(0, 1.7, 1.65) * CFrame.Angles(math.rad(-70), 0, 0))

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
