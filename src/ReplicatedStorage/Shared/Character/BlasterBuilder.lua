--!strict
-- BlasterBuilder: builds each weapon as a chunky 3D toy blaster from plain
-- Parts (no meshes or uploaded assets). Every weapon has its own silhouette;
-- skins swap the whole colour scheme. Guns point along +X with their "show"
-- side facing +Z.

local BlasterBuilder = {}

export type Palette = {
	Body: Color3, -- main shell
	Accent: Color3, -- caps, rings, tanks
	Dark: Color3, -- barrels, grips, mechanical bits
	Glow: Color3, -- neon stripes, muzzle energy
	Trim: Color3, -- small details / gems
}

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

BlasterBuilder.WeaponPalettes = {
	PawBlaster = { Body = c(150, 228, 70), Accent = c(160, 90, 255), Dark = c(42, 36, 58), Glow = c(200, 255, 120), Trim = c(236, 236, 246) },
	Starfall = { Body = c(232, 238, 252), Accent = c(104, 128, 255), Dark = c(44, 48, 82), Glow = c(120, 205, 255), Trim = c(196, 150, 255) },
	BoomPaw = { Body = c(255, 128, 36), Accent = c(255, 192, 70), Dark = c(40, 36, 46), Glow = c(255, 214, 96), Trim = c(130, 130, 140) },
	RapidPaw = { Body = c(232, 88, 222), Accent = c(90, 170, 255), Dark = c(46, 36, 72), Glow = c(255, 150, 244), Trim = c(230, 232, 255) },
	FrostBlaster = { Body = c(150, 218, 255), Accent = c(236, 248, 255), Dark = c(40, 72, 122), Glow = c(120, 240, 255), Trim = c(92, 160, 255) },
	VoidCannon = { Body = c(72, 40, 112), Accent = c(140, 80, 232), Dark = c(26, 20, 38), Glow = c(206, 116, 255), Trim = c(112, 92, 142) },
	BubbleBlaster = { Body = c(246, 246, 255), Accent = c(255, 140, 210), Dark = c(92, 82, 122), Glow = c(150, 230, 255), Trim = c(172, 222, 255) },
	GoldenPurr = { Body = c(255, 198, 58), Accent = c(255, 238, 166), Dark = c(122, 72, 22), Glow = c(255, 246, 176), Trim = c(232, 60, 82) },
	CometClaw = { Body = c(240, 246, 255), Accent = c(110, 200, 255), Dark = c(34, 44, 78), Glow = c(150, 236, 255), Trim = c(255, 226, 120) },
	PurrfectStorm = { Body = c(96, 58, 170), Accent = c(210, 150, 255), Dark = c(28, 22, 46), Glow = c(190, 240, 255), Trim = c(255, 230, 110) },
}

BlasterBuilder.SkinPalettes = {
	Ocean = { Body = c(58, 138, 255), Accent = c(110, 230, 255), Dark = c(22, 40, 92), Glow = c(124, 242, 255), Trim = c(200, 240, 255) },
	Inferno = { Body = c(228, 48, 40), Accent = c(255, 150, 40), Dark = c(52, 20, 20), Glow = c(255, 212, 82), Trim = c(255, 112, 40) },
	Golden = { Body = c(255, 196, 50), Accent = c(255, 240, 182), Dark = c(112, 64, 18), Glow = c(255, 250, 190), Trim = c(255, 255, 255) },
	Galaxy = { Body = c(108, 58, 220), Accent = c(240, 110, 222), Dark = c(24, 20, 62), Glow = c(170, 204, 255), Trim = c(255, 202, 255) },
	Neon = { Body = c(40, 44, 72), Accent = c(60, 240, 255), Dark = c(20, 20, 34), Glow = c(255, 80, 222), Trim = c(60, 240, 255) },
	Candy = { Body = c(255, 160, 212), Accent = c(255, 255, 255), Dark = c(204, 92, 152), Glow = c(150, 232, 255), Trim = c(255, 230, 122) },
	Void = { Body = c(46, 26, 82), Accent = c(130, 70, 222), Dark = c(16, 12, 26), Glow = c(192, 102, 255), Trim = c(92, 70, 132) },
	Aurora = { Body = c(40, 70, 110), Accent = c(90, 230, 200), Dark = c(18, 28, 48), Glow = c(170, 120, 255), Trim = c(120, 255, 210) },
	Molten = { Body = c(36, 30, 34), Accent = c(255, 110, 40), Dark = c(20, 16, 18), Glow = c(255, 180, 60), Trim = c(255, 80, 30) },
	Sakura = { Body = c(255, 214, 228), Accent = c(255, 120, 170), Dark = c(120, 70, 90), Glow = c(255, 170, 205), Trim = c(255, 255, 255) },
	Glitch = { Body = c(24, 26, 38), Accent = c(60, 255, 200), Dark = c(12, 12, 20), Glow = c(255, 60, 220), Trim = c(60, 255, 200) },
	Starlight = { Body = c(30, 36, 90), Accent = c(150, 170, 255), Dark = c(14, 16, 40), Glow = c(255, 240, 150), Trim = c(255, 255, 255) },
	VIPGold = { Body = c(255, 206, 60), Accent = c(30, 26, 36), Dark = c(24, 20, 28), Glow = c(255, 240, 160), Trim = c(255, 255, 255) },
}

local V = Vector3.new
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local GLASS = Enum.Material.Glass
local ROT_Y90 = CFrame.Angles(0, math.rad(90), 0) -- cylinder axis X -> Z
local ROT_Z90 = CFrame.Angles(0, 0, math.rad(90)) -- cylinder axis X -> Y

function BlasterBuilder.PaletteFor(weaponId: string, skinId: string?): Palette
	local skin = skinId and BlasterBuilder.SkinPalettes[skinId]
	return skin or BlasterBuilder.WeaponPalettes[weaponId] or BlasterBuilder.WeaponPalettes.PawBlaster
end

-- `base` places the whole gun (the previews use it for a 3/4 angle).
function BlasterBuilder.Build(weaponId: string, skinId: string?, base: CFrame?, scale: number?): Model
	local pal = BlasterBuilder.PaletteFor(weaponId, skinId)
	local origin = base or CFrame.identity
	local s = scale or 1
	local tip = Vector3.new(-math.huge, 0, 0) -- frontmost point, for the muzzle
	local model = Instance.new("Model")
	model.Name = weaponId

	local function part(size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, rot: CFrame?, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.Size = size * s
		if pos.X + size.X / 2 > tip.X then
			tip = Vector3.new(pos.X + size.X / 2, pos.Y, 0)
		end
		p.CFrame = origin * CFrame.new(pos * s) * (rot or CFrame.identity)
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.Parent = model
		return p
	end
	local function box(size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?, rot: CFrame?): Part
		return part(size, pos, color, material, rot)
	end
	-- Cylinder along X unless rotated.
	local function cyl(len: number, d: number, pos: Vector3, color: Color3, material: Enum.Material?, rot: CFrame?): Part
		return part(V(len, d, d), pos, color, material, rot, Enum.PartType.Cylinder)
	end
	local function ball(d: number, pos: Vector3, color: Color3, material: Enum.Material?): Part
		return part(V(d, d, d), pos, color, material, nil, Enum.PartType.Ball)
	end
	local function glass(p: Part, t: number): Part
		p.Transparency = t
		return p
	end

	-- Shared pieces --------------------------------------------------------
	local function grip(pos: Vector3, color: Color3)
		box(V(0.56, 1.35, 0.5), pos, color, nil, CFrame.Angles(0, 0, math.rad(-16)))
		box(V(0.66, 0.16, 0.56), pos + V(-0.2, -0.66, 0), pal.Dark, nil, CFrame.Angles(0, 0, math.rad(-16)))
		for k = 0, 2 do
			box(V(0.58, 0.07, 0.52), pos + V(-0.04 - k * 0.05, 0.25 - k * 0.22, 0), pal.Dark, nil, CFrame.Angles(0, 0, math.rad(-16)))
		end
	end
	local function trigger(pos: Vector3)
		box(V(0.12, 0.36, 0.16), pos, pal.Dark, nil, CFrame.Angles(0, 0, math.rad(-12)))
		box(V(0.78, 0.09, 0.26), pos + V(0.05, -0.26, 0), pal.Dark)
		box(V(0.09, 0.3, 0.26), pos + V(0.42, -0.12, 0), pal.Dark)
	end
	-- Paw print decal on the show (+Z) side.
	local function paw(x: number, y: number, z: number, color: Color3, ps: number)
		cyl(0.05, 0.36 * ps, V(x, y, z), color, nil, ROT_Y90)
		for i, a in ipairs({ -50, -15, 15, 50 }) do
			local r = math.rad(a + 90)
			local d = (i == 1 or i == 4) and 0.12 or 0.15
			cyl(0.05, d * ps, V(x + math.cos(r) * 0.27 * ps, y + math.sin(r) * 0.27 * ps, z), color, nil, ROT_Y90)
		end
	end
	local function muzzle(x: number, y: number, ringD: number, glowD: number, ringColor: Color3)
		cyl(0.3, ringD, V(x, y, 0), ringColor)
		cyl(0.06, glowD, V(x + 0.17, y, 0), pal.Glow, NEON)
	end

	-- Designs ----------------------------------------------------------------
	local builders: { [string]: () -> () } = {}

	builders.PawBlaster = function()
		box(V(2.8, 1.0, 0.9), V(0, 0, 0), pal.Body)
		cyl(2.8, 0.9, V(0, 0.5, 0), pal.Body)
		box(V(0.5, 1.25, 1.0), V(-1.55, 0.15, 0), pal.Accent)
		cyl(0.26, 1.1, V(1.45, 0.3, 0), pal.Accent)
		cyl(1.5, 0.6, V(2.3, 0.3, 0), pal.Dark, METAL)
		muzzle(3.0, 0.3, 0.9, 0.5, pal.Accent)
		cyl(1.5, 0.7, V(-0.3, 1.05, 0), pal.Accent)
		box(V(1.0, 0.22, 0.74), V(-0.3, 1.05, 0), pal.Glow, NEON)
		cyl(0.16, 0.78, V(-1.05, 1.05, 0), pal.Dark)
		cyl(0.16, 0.78, V(0.45, 1.05, 0), pal.Dark)
		box(V(1.8, 0.16, 0.06), V(0.3, -0.12, 0.46), pal.Glow, NEON)
		box(V(1.2, 0.4, 0.72), V(1.1, -0.66, 0), pal.Dark)
		grip(V(-0.85, -0.95, 0), pal.Accent)
		trigger(V(-0.3, -0.66, 0))
		paw(-0.75, 0.22, 0.47, pal.Dark, 1)
	end

	builders.Starfall = function()
		box(V(3.0, 0.76, 0.7), V(0, 0, 0), pal.Body)
		box(V(0.9, 0.5, 0.62), V(1.9, -0.06, 0), pal.Body)
		cyl(2.4, 0.34, V(2.95, 0.06, 0), pal.Dark, METAL)
		for i = 0, 2 do
			cyl(0.12, 0.56, V(2.3 + i * 0.6, 0.06, 0), pal.Glow, NEON)
		end
		muzzle(4.15, 0.06, 0.52, 0.3, pal.Accent)
		cyl(1.6, 0.42, V(0.2, 0.72, 0), pal.Dark)
		cyl(0.24, 0.54, V(1.02, 0.72, 0), pal.Accent)
		cyl(0.05, 0.4, V(1.16, 0.72, 0), pal.Glow, NEON)
		cyl(0.2, 0.5, V(-0.62, 0.72, 0), pal.Accent)
		box(V(0.18, 0.32, 0.2), V(-0.2, 0.45, 0), pal.Dark)
		box(V(0.18, 0.32, 0.2), V(0.6, 0.45, 0), pal.Dark)
		box(V(1.3, 0.6, 0.5), V(-2.05, -0.05, 0), pal.Accent)
		box(V(0.26, 0.95, 0.52), V(-2.78, -0.16, 0), pal.Accent)
		box(V(2.2, 0.12, 0.06), V(0, -0.12, 0.36), pal.Glow, NEON)
		for _, a in ipairs({ 45, -45, 0, 90 }) do
			box(V(0.36, 0.08, 0.04), V(-0.9, 0.12, 0.37), pal.Trim, NEON, CFrame.Angles(0, 0, math.rad(a)))
		end
		grip(V(-0.7, -0.86, 0), pal.Dark)
		trigger(V(-0.15, -0.58, 0))
	end

	builders.BoomPaw = function()
		box(V(2.6, 1.4, 1.2), V(0, 0, 0), pal.Body)
		cyl(2.6, 1.2, V(0, 0.55, 0), pal.Body)
		cyl(1.6, 1.25, V(2.0, 0.25, 0), pal.Dark, METAL)
		cyl(0.14, 1.42, V(1.5, 0.25, 0), pal.Accent)
		cyl(0.14, 1.42, V(2.2, 0.25, 0), pal.Accent)
		cyl(0.42, 1.65, V(2.86, 0.25, 0), pal.Body)
		cyl(0.06, 1.05, V(3.08, 0.25, 0), pal.Dark)
		cyl(0.07, 0.5, V(3.09, 0.25, 0), pal.Glow, NEON)
		cyl(0.9, 1.3, V(-0.1, -1.05, 0), pal.Dark, METAL, ROT_Y90)
		cyl(0.96, 0.62, V(-0.1, -1.05, 0), pal.Accent, nil, ROT_Y90)
		cyl(1.0, 0.24, V(-0.1, -1.05, 0), pal.Glow, NEON, ROT_Y90)
		box(V(1.5, 0.22, 0.3), V(-0.1, 1.58, 0), pal.Dark)
		box(V(0.2, 0.42, 0.3), V(-0.7, 1.36, 0), pal.Dark)
		box(V(0.2, 0.42, 0.3), V(0.5, 1.36, 0), pal.Dark)
		box(V(0.5, 1.25, 1.3), V(-1.5, 0.1, 0), pal.Dark)
		for i = 0, 2 do
			box(V(0.12, 0.8, 0.05), V(-0.85 + i * 0.32, 0.15, 0.61), pal.Glow, NEON)
		end
		grip(V(-1.05, -1.0, 0), pal.Dark)
		paw(0.75, 0.2, 0.62, pal.Dark, 1.1)
	end

	builders.RapidPaw = function()
		box(V(2.4, 0.9, 0.8), V(0, 0, 0), pal.Body)
		cyl(2.4, 0.8, V(0, 0.45, 0), pal.Body)
		for _, y in ipairs({ 0.34, -0.06 }) do
			cyl(1.7, 0.3, V(2.0, y, 0), pal.Dark, METAL)
			cyl(0.22, 0.42, V(2.86, y, 0), pal.Accent)
			cyl(0.05, 0.22, V(2.98, y, 0), pal.Glow, NEON)
		end
		box(V(0.9, 0.98, 0.72), V(1.2, 0.14, 0), pal.Accent)
		box(V(2.2, 0.18, 0.3), V(0, 0.96, 0), pal.Accent)
		box(V(1.8, 0.08, 0.32), V(0, 1.07, 0), pal.Glow, NEON)
		box(V(1.6, 0.1, 0.05), V(0, 0.16, 0.41), pal.Glow, NEON)
		box(V(1.2, 0.1, 0.05), V(-0.2, -0.12, 0.41), pal.Accent)
		box(V(0.45, 1.05, 0.4), V(0.45, -0.86, 0), pal.Dark, nil, CFrame.Angles(0, 0, math.rad(12)))
		box(V(0.75, 0.46, 0.1), V(-1.25, 0.86, 0), pal.Accent, nil, CFrame.Angles(0, 0, math.rad(28)))
		box(V(0.6, 0.85, 0.72), V(-1.45, 0, 0), pal.Accent)
		grip(V(-0.75, -0.85, 0), pal.Body)
		trigger(V(-0.2, -0.56, 0))
	end

	builders.FrostBlaster = function()
		box(V(2.6, 1.0, 0.85), V(0, 0, 0), pal.Body)
		cyl(2.6, 0.85, V(0, 0.5, 0), pal.Body)
		cyl(1.3, 0.56, V(2.0, 0.25, 0), pal.Accent)
		cyl(0.2, 0.8, V(1.45, 0.25, 0), pal.Trim)
		box(V(0.62, 0.62, 0.62), V(2.88, 0.25, 0), pal.Glow, NEON, CFrame.Angles(math.rad(45), 0, math.rad(45)))
		glass(box(V(0.8, 0.8, 0.8), V(2.88, 0.25, 0), pal.Accent, GLASS, CFrame.Angles(math.rad(45), 0, math.rad(45))), 0.55)
		for _, s in ipairs({ { -0.6, 1.2, 18 }, { -0.1, 1.38, -8 }, { 0.42, 1.16, -26 } }) do
			box(V(0.26, 0.9, 0.26), V(s[1], s[2], 0), pal.Glow, NEON, CFrame.Angles(0, math.rad(45), math.rad(s[3])))
		end
		glass(box(V(1.6, 0.5, 0.05), V(0.1, 0, 0.44), pal.Accent, GLASS), 0.2)
		box(V(0.5, 1.15, 0.95), V(-1.5, 0.1, 0), pal.Trim)
		grip(V(-0.8, -0.9, 0), pal.Trim)
		trigger(V(-0.25, -0.62, 0))
		paw(-0.95, 0.25, 0.44, pal.Trim, 0.85)
	end

	builders.VoidCannon = function()
		box(V(2.8, 1.3, 1.1), V(0, 0, 0), pal.Body)
		cyl(2.8, 1.1, V(0, 0.62, 0), pal.Body)
		cyl(2.0, 1.2, V(2.2, 0.2, 0), pal.Dark, METAL)
		for _, x in ipairs({ 1.6, 2.2, 2.8 }) do
			cyl(0.12, 1.36, V(x, 0.2, 0), pal.Glow, NEON)
		end
		cyl(0.45, 1.85, V(3.35, 0.2, 0), pal.Accent)
		cyl(0.06, 1.58, V(3.585, 0.2, 0), pal.Glow, NEON)
		cyl(0.06, 1.3, V(3.6, 0.2, 0), pal.Dark)
		ball(0.62, V(3.5, 0.2, 0), pal.Glow, NEON)
		ball(0.9, V(-0.6, 1.3, 0), pal.Glow, NEON)
		cyl(0.2, 1.06, V(-0.6, 1.3, 0), pal.Dark, METAL, ROT_Z90)
		cyl(1.04, 0.14, V(-0.6, 1.3, 0), pal.Dark, METAL, ROT_Y90)
		box(V(0.3, 0.75, 0.3), V(-1.45, 1.05, 0), pal.Dark, nil, CFrame.Angles(0, 0, math.rad(35)))
		box(V(0.6, 1.4, 1.2), V(-1.6, 0.1, 0), pal.Dark)
		box(V(1.8, 0.12, 0.05), V(0.1, -0.2, 0.56), pal.Glow, NEON)
		grip(V(-1.0, -1.0, 0), pal.Dark)
		trigger(V(-0.45, -0.72, 0))
	end

	builders.BubbleBlaster = function()
		box(V(2.2, 0.95, 0.85), V(0, 0, 0), pal.Body)
		cyl(2.2, 0.85, V(0, 0.48, 0), pal.Body)
		cyl(1.2, 0.6, V(1.7, 0.2, 0), pal.Accent)
		cyl(0.36, 0.96, V(2.4, 0.2, 0), pal.Accent)
		glass(ball(0.95, V(2.98, 0.24, 0), pal.Glow, GLASS), 0.4)
		glass(ball(1.3, V(-0.35, 1.12, 0), pal.Trim, GLASS), 0.4)
		ball(0.8, V(-0.35, 1.12, 0), pal.Accent, NEON)
		cyl(0.3, 0.92, V(-0.35, 0.6, 0), pal.Accent, nil, ROT_Z90)
		box(V(1.4, 0.14, 0.05), V(0.1, -0.1, 0.44), pal.Accent)
		glass(ball(0.36, V(3.45, 0.95, 0.2), pal.Glow, GLASS), 0.35)
		glass(ball(0.22, V(3.75, 0.5, -0.1), pal.Glow, GLASS), 0.35)
		box(V(0.4, 1.05, 0.9), V(-1.3, 0.1, 0), pal.Accent)
		grip(V(-0.7, -0.85, 0), pal.Accent)
		trigger(V(-0.15, -0.58, 0))
		paw(0.6, 0.12, 0.44, pal.Accent, 0.85)
	end

	builders.GoldenPurr = function()
		box(V(2.8, 1.0, 0.9), V(0, 0, 0), pal.Body)
		cyl(2.8, 0.9, V(0, 0.5, 0), pal.Body)
		box(V(0.5, 1.25, 1.0), V(-1.55, 0.15, 0), pal.Accent)
		cyl(1.4, 0.56, V(2.2, 0.3, 0), pal.Accent)
		muzzle(2.95, 0.3, 0.88, 0.5, pal.Body)
		cyl(0.4, 1.0, V(-0.2, 1.1, 0), pal.Body, nil, ROT_Z90)
		for i = 0, 4 do
			local a = i / 5 * math.pi * 2
			local p = V(-0.2 + math.cos(a) * 0.38, 1.52, math.sin(a) * 0.38)
			box(V(0.2, 0.46, 0.2), p, pal.Body, nil, CFrame.Angles(0, -a, 0))
			ball(0.16, p + V(0, 0.28, 0), pal.Glow, NEON)
		end
		ball(0.22, V(-0.2, 1.12, 0.5), pal.Trim, NEON)
		box(V(2.0, 0.14, 0.06), V(0.3, -0.14, 0.46), pal.Trim)
		box(V(1.2, 0.4, 0.72), V(1.1, -0.66, 0), pal.Accent)
		grip(V(-0.85, -0.95, 0), pal.Accent)
		trigger(V(-0.3, -0.66, 0))
		paw(-0.75, 0.22, 0.47, pal.Accent, 1)
	end

	builders.CometClaw = function()
		box(V(3.0, 0.8, 0.72), V(0, 0, 0), pal.Body)
		cyl(3.0, 0.72, V(0, 0.4, 0), pal.Body)
		cyl(2.2, 0.38, V(2.6, 0.2, 0), pal.Dark, METAL)
		for i = 0, 1 do
			cyl(0.14, 0.62, V(2.0 + i * 0.8, 0.2, 0), pal.Accent, NEON)
		end
		ball(0.7, V(3.85, 0.2, 0), pal.Glow, NEON)
		for _, a in ipairs({ 0, 45, 90, 135 }) do
			box(V(1.1, 0.1, 0.1), V(3.85, 0.2, 0), pal.Trim, NEON, CFrame.Angles(a == 90 and math.rad(90) or 0, 0, math.rad(a)))
		end
		for k, s in ipairs({ { 0.9, 0.35 }, { 0.6, 0.6 }, { 0.35, 0.8 } }) do
			box(V(s[1], 0.12, 0.08), V(-1.6 - k * 0.25, 0.55 + k * 0.12, 0), pal.Accent, NEON, CFrame.Angles(0, 0, math.rad(20 + k * 8)))
		end
		cyl(1.4, 0.4, V(0.1, 0.9, 0), pal.Dark)
		cyl(0.06, 0.34, V(0.82, 0.9, 0), pal.Glow, NEON)
		box(V(2.2, 0.1, 0.06), V(0.1, -0.1, 0.37), pal.Accent, NEON)
		grip(V(-0.7, -0.85, 0), pal.Dark)
		trigger(V(-0.15, -0.56, 0))
		paw(-0.9, 0.18, 0.37, pal.Trim, 0.8)
	end

	builders.PurrfectStorm = function()
		box(V(2.6, 1.0, 0.85), V(0, 0, 0), pal.Body)
		cyl(2.6, 0.85, V(0, 0.5, 0), pal.Body)
		for _, y in ipairs({ 0.36, -0.04 }) do
			cyl(1.8, 0.28, V(2.1, y, 0), pal.Dark, METAL)
			cyl(0.05, 0.2, V(3.02, y, 0), pal.Glow, NEON)
		end
		for i = 0, 3 do
			cyl(0.1, 0.9, V(1.4 + i * 0.42, 0.16, 0), i % 2 == 0 and pal.Glow or pal.Accent, NEON)
		end
		for _, z in ipairs({ -0.22, 0.22 }) do
			local ear = Instance.new("WedgePart")
			ear.Anchored = true
			ear.CanCollide = false
			ear.CanQuery = false
			ear.CanTouch = false
			ear.CastShadow = false
			ear.Size = V(0.14, 0.42, 0.3) * s
			ear.Color = pal.Accent
			ear.Material = Enum.Material.SmoothPlastic
			ear.CFrame = origin * CFrame.new(V(-0.2, 1.08, z) * s) * CFrame.Angles(0, math.rad(90), 0)
			ear.Parent = model
		end
		box(V(0.4, 0.5, 0.3), V(-0.6, 1.2, 0), pal.Trim, NEON, CFrame.Angles(0, 0, math.rad(35)))
		box(V(1.8, 0.1, 0.06), V(0.1, -0.12, 0.44), pal.Glow, NEON)
		box(V(0.55, 0.95, 0.76), V(-1.45, 0.05, 0), pal.Accent)
		grip(V(-0.75, -0.9, 0), pal.Dark)
		trigger(V(-0.2, -0.6, 0))
		paw(0.2, 0.2, 0.44, pal.Trim, 0.9)
	end

	local build = builders[weaponId] or builders.PawBlaster
	build()
	-- Invisible marker at the front of the barrel; shots and flashes start here.
	local m = Instance.new("Part")
	m.Name = "MuzzlePoint"
	m.Size = Vector3.one * 0.1
	m.Transparency = 1
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.CFrame = origin * CFrame.new((tip + Vector3.new(0.1, 0, 0)) * s)
	m.Parent = model
	return model
end

return BlasterBuilder
