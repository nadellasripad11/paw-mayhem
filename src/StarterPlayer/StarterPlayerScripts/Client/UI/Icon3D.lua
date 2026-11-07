--!strict
-- icon3d: chunky 3d icons for the menu (rivals-style), each a little model of
-- parts in a viewportframe - no uploaded images. kinds:
--   clipboard (tasks), basket (shop), wingshield (pass), cathead (customize,
--   in your cat's colours), coin, gem, trophy (ranks).
-- icon3d.create(kind, parent, size, position, opts) -> viewportframe

local Icon3D = {}

local function sphereMesh(p: BasePart)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
end

local function builder(model: Model)
	local function part(size: Vector3, cf: CFrame, color: Color3, opts: { [string]: any }?): BasePart
		local o = opts or {}
		local p: BasePart
		if o.wedge then
			p = Instance.new("WedgePart")
		else
			p = Instance.new("Part")
		end
		p.Anchored = true
		p.CanCollide = false
		p.CastShadow = false
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Material = o.material or Enum.Material.SmoothPlastic
		p.Reflectance = o.reflectance or 0
		p.Size = size
		p.CFrame = cf
		p.Color = color
		if o.shape then
			(p :: Part).Shape = o.shape
		end
		if o.sphere then
			sphereMesh(p)
		end
		p.Parent = model
		return p
	end
	return part
end

local C = Color3.fromRGB
local BUILD: { [string]: (Model, { [string]: any }) -> CFrame } = {}

-- a clipboard with a ticked list (tasks).
BUILD.Clipboard = function(model)
	local part = builder(model)
	part(Vector3.new(3, 3.9, 0.22), CFrame.new(), C(176, 112, 62), { material = Enum.Material.Wood })
	part(Vector3.new(2.6, 3.3, 0.06), CFrame.new(0, -0.15, 0.14), C(250, 250, 246))
	part(Vector3.new(1.3, 0.42, 0.28), CFrame.new(0, 1.75, 0.18), C(196, 202, 214), { material = Enum.Material.Metal, reflectance = 0.15 })
	part(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 2.02, 0.16) * CFrame.Angles(0, math.rad(90), 0), C(196, 202, 214), { shape = Enum.PartType.Cylinder, material = Enum.Material.Metal })
	for i = 0, 2 do
		local y = 0.75 - i * 0.85
		-- a green tick and a grey line
		part(Vector3.new(0.16, 0.34, 0.05), CFrame.new(-0.95, y - 0.05, 0.19) * CFrame.Angles(0, 0, math.rad(40)), C(70, 200, 90))
		part(Vector3.new(0.16, 0.6, 0.05), CFrame.new(-0.72, y + 0.05, 0.19) * CFrame.Angles(0, 0, math.rad(-35)), C(70, 200, 90))
		part(Vector3.new(1.35, 0.14, 0.04), CFrame.new(0.3, y, 0.18), C(150, 160, 178))
	end
	return CFrame.Angles(0, math.rad(-22), math.rad(-10))
end

-- a red shopping basket with a handle (shop).
BUILD.Basket = function(model)
	local part = builder(model)
	local red, dark = C(232, 52, 58), C(170, 30, 38)
	part(Vector3.new(3.2, 0.28, 2.1), CFrame.new(0, -0.8, 0), dark)
	for i = -3, 3 do
		local x = i * 0.5
		part(Vector3.new(0.24, 1.7, 0.16), CFrame.new(x, 0, 1.05) * CFrame.Angles(math.rad(-10), 0, 0), red)
		part(Vector3.new(0.24, 1.7, 0.16), CFrame.new(x, 0, -1.05) * CFrame.Angles(math.rad(10), 0, 0), red)
	end
	for i = -1, 1 do
		local z = i * 0.6
		part(Vector3.new(0.16, 1.7, 0.24), CFrame.new(1.6, 0, z) * CFrame.Angles(0, 0, math.rad(10)), red)
		part(Vector3.new(0.16, 1.7, 0.24), CFrame.new(-1.6, 0, z) * CFrame.Angles(0, 0, math.rad(-10)), red)
	end
	-- rim
	part(Vector3.new(3.5, 0.26, 0.26), CFrame.new(0, 0.82, 1.2), dark)
	part(Vector3.new(3.5, 0.26, 0.26), CFrame.new(0, 0.82, -1.2), dark)
	part(Vector3.new(0.26, 0.26, 2.6), CFrame.new(1.75, 0.82, 0), dark)
	part(Vector3.new(0.26, 0.26, 2.6), CFrame.new(-1.75, 0.82, 0), dark)
	-- handle: an arc over the top
	for k = 0, 10 do
		local a = math.pi * k / 10
		part(Vector3.new(0.34, 0.2, 0.2), CFrame.new(math.cos(a) * 1.45, 0.85 + math.sin(a) * 1.2, 0) * CFrame.Angles(0, 0, a + math.pi / 2), C(60, 60, 70))
	end
	return CFrame.Angles(math.rad(20), math.rad(-28), 0)
end

-- a shield with wings (pass).
BUILD.WingShield = function(model)
	local part = builder(model)
	local blue, rim = C(150, 190, 240), C(225, 235, 250)
	part(Vector3.new(1.9, 1.4, 0.4), CFrame.new(0, 0.45, 0), blue, { material = Enum.Material.Metal, reflectance = 0.1 })
	part(Vector3.new(1.36, 1.36, 0.4), CFrame.new(0, -0.25, 0) * CFrame.Angles(0, 0, math.rad(45)), blue, { material = Enum.Material.Metal, reflectance = 0.1 })
	part(Vector3.new(2.05, 0.18, 0.46), CFrame.new(0, 1.15, 0), rim, { material = Enum.Material.Metal })
	-- a raised gold star-ish emblem
	part(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.2, 0.24) * CFrame.Angles(0, 0, math.rad(45)), C(255, 210, 80))
	part(Vector3.new(0.5, 0.5, 0.52), CFrame.new(0, 0.2, 0.24), C(255, 210, 80))
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, 3 do
			local len = 1.9 - k * 0.32
			local a = math.rad(15 + k * 18)
			local cf = CFrame.new(s * (1.0 + math.cos(a) * len * 0.5), 0.75 - k * 0.35 + math.sin(a) * len * 0.35, -0.05 - k * 0.04)
				* CFrame.Angles(0, 0, s * a)
			part(Vector3.new(len, 0.5, 0.18), cf, k % 2 == 0 and C(255, 255, 255) or C(232, 238, 248), { sphere = true })
		end
	end
	return CFrame.Angles(0, math.rad(-18), 0)
end

-- your cat's head (customize).
BUILD.CatHead = function(model, o)
	local part = builder(model)
	local fur, accent = o.fur or C(255, 170, 80), o.accent or C(255, 236, 222)
	part(Vector3.new(2.6, 2.2, 2.3), CFrame.new(), fur, { sphere = true })
	for _, s in ipairs({ -1, 1 }) do
		part(Vector3.new(0.3, 1.0, 0.9), CFrame.new(s * 0.78, 1.15, -0.05) * CFrame.Angles(0, math.rad(90), math.rad(-s * 18)), fur, { wedge = true })
		part(Vector3.new(0.32, 0.62, 0.5), CFrame.new(s * 0.78, 1.1, 0.06) * CFrame.Angles(0, math.rad(90), math.rad(-s * 18)), C(255, 160, 180), { wedge = true })
		part(Vector3.new(0.36, 0.5, 0.2), CFrame.new(s * 0.5, 0.2, 1.07), C(30, 26, 34), { sphere = true })
		part(Vector3.new(0.12, 0.14, 0.08), CFrame.new(s * 0.45, 0.32, 1.17), C(255, 255, 255), { sphere = true })
	end
	part(Vector3.new(1.1, 0.7, 0.4), CFrame.new(0, -0.35, 1.0), accent, { sphere = true })
	part(Vector3.new(0.3, 0.2, 0.14), CFrame.new(0, -0.18, 1.2), C(255, 136, 160), { sphere = true })
	return CFrame.Angles(math.rad(-6), math.rad(-22), 0)
end

-- a gold coin with a paw on it.
BUILD.Coin = function(model)
	local part = builder(model)
	local gold = C(255, 196, 50)
	part(Vector3.new(0.4, 2.4, 2.4), CFrame.Angles(0, math.rad(90), 0), gold, { shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, reflectance = 0.2 })
	part(Vector3.new(0.44, 1.9, 1.9), CFrame.Angles(0, math.rad(90), 0), C(240, 170, 30), { shape = Enum.PartType.Cylinder, material = Enum.Material.Metal })
	local paw = C(255, 226, 120)
	part(Vector3.new(0.75, 0.62, 0.2), CFrame.new(0, -0.22, 0.24), paw, { sphere = true })
	for i, x in ipairs({ -0.42, -0.14, 0.14, 0.42 }) do
		local y = (i == 1 or i == 4) and 0.18 or 0.36
		part(Vector3.new(0.26, 0.3, 0.18), CFrame.new(x, y, 0.24), paw, { sphere = true })
	end
	return CFrame.Angles(0, math.rad(-25), math.rad(8))
end

-- a purple gem.
BUILD.Gem = function(model)
	local part = builder(model)
	local p = C(200, 90, 255)
	part(Vector3.new(1.7, 1.7, 1.7), CFrame.Angles(math.rad(45), 0, math.rad(35)), p, { material = Enum.Material.Glass, reflectance = 0.25 })
	part(Vector3.new(1.2, 1.2, 1.2), CFrame.Angles(math.rad(45), 0, math.rad(35)), C(240, 170, 255))
	return CFrame.Angles(0, math.rad(20), 0)
end

-- a grey gear (settings).
BUILD.Gear = function(model)
	local part = builder(model)
	local steel, dark = C(196, 204, 220), C(70, 76, 92)
	part(Vector3.new(0.6, 2.4, 2.4), CFrame.Angles(0, math.rad(90), 0), steel, { shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, reflectance = 0.1 })
	part(Vector3.new(0.66, 0.9, 0.9), CFrame.Angles(0, math.rad(90), 0), dark, { shape = Enum.PartType.Cylinder })
	for k = 0, 7 do
		local a = k * math.pi / 4
		part(Vector3.new(0.7, 0.6, 0.6), CFrame.new(math.cos(a) * 1.35, math.sin(a) * 1.35, 0) * CFrame.Angles(0, 0, a), steel, { material = Enum.Material.Metal })
	end
	return CFrame.Angles(math.rad(-15), math.rad(-25), 0)
end

-- a gold / silver / bronze podium (leaderboard).
BUILD.Podium = function(model)
	local part = builder(model)
	part(Vector3.new(1.1, 2.2, 1.1), CFrame.new(0, 1.1, 0), C(255, 200, 60), { material = Enum.Material.Metal, reflectance = 0.1 })
	part(Vector3.new(1.1, 1.5, 1.1), CFrame.new(-1.15, 0.75, 0), C(200, 210, 225), { material = Enum.Material.Metal })
	part(Vector3.new(1.1, 1.0, 1.1), CFrame.new(1.15, 0.5, 0), C(205, 130, 70), { material = Enum.Material.Metal })
	part(Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(45)), C(255, 230, 120))
	return CFrame.Angles(math.rad(12), math.rad(-25), 0)
end

-- a warm gold trophy cup (ranks).
BUILD.Trophy = function(model)
	local part = builder(model)
	local gold, dark = C(232, 182, 76), C(120, 78, 30)
	local metal = { material = Enum.Material.Metal, reflectance = 0.12 }
	local function cyl(h: number, d: number, y: number, color: Color3)
		part(Vector3.new(h, d, d), CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), color, {
			shape = Enum.PartType.Cylinder, material = Enum.Material.Metal, reflectance = 0.12,
		})
	end
	part(Vector3.new(1.9, 0.45, 1.2), CFrame.new(0, -1.55, 0), dark) -- base block
	cyl(0.25, 1.2, -1.2, gold) -- foot
	cyl(0.9, 0.38, -0.7, gold) -- stem
	cyl(0.3, 1.0, -0.25, gold) -- cup bottom
	cyl(1.3, 1.8, 0.5, gold) -- cup
	cyl(0.12, 1.9, 1.18, C(248, 214, 120)) -- rim
	for _, s in ipairs({ -1, 1 }) do
		-- handles: three short bars bent into a loop
		part(Vector3.new(0.5, 0.18, 0.18), CFrame.new(s * 1.12, 0.95, 0), gold, metal)
		part(Vector3.new(0.18, 0.75, 0.18), CFrame.new(s * 1.32, 0.6, 0), gold, metal)
		part(Vector3.new(0.5, 0.18, 0.18), CFrame.new(s * 1.12, 0.25, 0), gold, metal)
	end
	part(Vector3.new(0.5, 0.5, 0.12), CFrame.new(0, 0.5, 0.88) * CFrame.Angles(0, 0, math.rad(45)), C(255, 240, 190)) -- star plate
	return CFrame.Angles(math.rad(10), math.rad(-20), 0)
end

-- a yellow smiley (emotes).
BUILD.Smiley = function(model)
	local part = builder(model)
	part(Vector3.new(2.4, 2.4, 2.4), CFrame.new(), C(255, 214, 60), { sphere = true })
	for _, s in ipairs({ -1, 1 }) do
		part(Vector3.new(0.3, 0.5, 0.2), CFrame.new(s * 0.45, 0.35, 1.1), C(40, 30, 30), { sphere = true })
	end
	for k = -2, 2 do
		local a = k * 0.32
		part(Vector3.new(0.24, 0.16, 0.16), CFrame.new(math.sin(a) * 0.7, -0.35 - math.cos(a) * 0.12 + 0.12, 1.08 - math.abs(k) * 0.05), C(40, 30, 30), { sphere = true })
	end
	return CFrame.Angles(0, math.rad(-18), 0)
end

local function frame(vf: ViewportFrame, model: Model, aspect: number, fill: number)
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 26
	local t = math.tan(math.rad(cam.FieldOfView / 2))
	local radius = size.Magnitude / 2
	local dist = radius / (t * math.min(1, aspect)) / fill
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, 0, dist), cf.Position)
	cam.Parent = vf
	vf.CurrentCamera = cam
end

-- draws (or redraws) \`kind\` in a viewport. opts: fur / accent (cathead),
-- fill (how much of the frame it fills, default 0.95).
function Icon3D.Set(vf: ViewportFrame, kind: string, opts: { [string]: any }?)
	for _, c in ipairs(vf:GetChildren()) do
		if c:IsA("Model") or c:IsA("Camera") then
			c:Destroy()
		end
	end
	local build = BUILD[kind]
	if not build then
		return
	end
	local model = Instance.new("Model")
	local tilt = build(model, opts or {})
	-- turn the whole model for its 3/4 view
	local pivot = model:GetBoundingBox()
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			p.CFrame = pivot * tilt * pivot:ToObjectSpace(p.CFrame)
		end
	end
	model.Parent = vf
	local abs = vf.AbsoluteSize
	frame(vf, model, abs.Y > 0 and abs.X / abs.Y or 1, (opts and opts.fill) or 0.95)
end

function Icon3D.Create(kind: string, parent: Instance, size: UDim2, position: UDim2?, opts: { [string]: any }?): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.Name = kind .. "Icon"
	vf.BackgroundTransparency = 1
	vf.Size = size
	vf.Position = position or UDim2.new()
	vf.Ambient = Color3.fromRGB(165, 165, 185)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	vf.LightDirection = Vector3.new(-0.5, -1, -0.8)
	vf.Parent = parent
	Icon3D.Set(vf, kind, opts)
	return vf
end

return Icon3D
