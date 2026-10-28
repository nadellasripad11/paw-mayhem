--!strict
-- maplife: little bits of life on the maps that only need this client.
--   * birds (birdspot parts, sky islands): a few birds peck about on the
--     grass and scatter into the sky when a cat comes near, then come back
--     a while later
--   * the shooting range's floating targets (rangetarget): they pop
--     when you shoot them and come back a few seconds later

local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)
local SoundController = require(script.Parent.SoundController)

local MapLife = {}

local SCARE_RADIUS = 9
local BACK_AFTER = 25
local FLIGHT = 1.8
local COLORS = {
	{ Color3.fromRGB(240, 240, 236), Color3.fromRGB(150, 150, 156) },
	{ Color3.fromRGB(110, 150, 220), Color3.fromRGB(240, 236, 220) },
	{ Color3.fromRGB(210, 120, 80), Color3.fromRGB(236, 220, 200) },
}

type Bird = { model: Model, wings: { BasePart } }
type Flock = { spot: BasePart, birds: { Bird }, backAt: number }
type Flight = { bird: Bird, from: CFrame, to: Vector3, t0: number }

local flocks: { [BasePart]: Flock } = {}
local flights: { Flight } = {}
local holder: Folder? = nil

local function part(name: string, size: Vector3, color: Color3, shape: Enum.PartType?, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
	return p
end

local function folder(): Folder
	local f = holder
	if f and f.Parent then
		return f
	end
	local nf = Instance.new("Folder")
	nf.Name = "PawBirds"
	nf.Parent = Workspace
	holder = nf
	return nf
end

local function makeBird(pos: Vector3): Bird
	local c = COLORS[math.random(1, #COLORS)]
	local m = Instance.new("Model")
	m.Name = "Bird"
	local body = part("Body", Vector3.new(0.9, 0.6, 0.6), c[1], Enum.PartType.Ball, m)
	local head = part("Head", Vector3.one * 0.42, c[1], Enum.PartType.Ball, m)
	local beak = part("Beak", Vector3.new(0.12, 0.12, 0.26), Color3.fromRGB(255, 170, 40), nil, m)
	local wings = {}
	for _, s in ipairs({ -1, 1 }) do
		table.insert(wings, part("Wing", Vector3.new(0.6, 0.08, 0.4), c[2], nil, m))
		wings[#wings]:SetAttribute("Side", s)
	end
	m.PrimaryPart = body
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	body.CFrame = cf
	head.CFrame = cf * CFrame.new(0, 0.3, -0.4)
	beak.CFrame = cf * CFrame.new(0, 0.28, -0.68)
	for _, w in ipairs(wings) do
		w.CFrame = cf * CFrame.new((w:GetAttribute("Side") :: number) * 0.42, 0.05, 0.05)
	end
	m.Parent = folder()
	return { model = m, wings = wings }
end

local function land(f: Flock)
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + math.random()
		local pos = f.spot.Position + Vector3.new(math.cos(a) * 1.8, 0.3, math.sin(a) * 1.8)
		f.birds[i] = makeBird(pos)
	end
	f.backAt = 0
end

local function scatter(f: Flock)
	SoundController.PlayAt("Whoosh", f.spot.Position, 1.7, 0.6)
	for _, b in ipairs(f.birds) do
		local from = b.model:GetPivot()
		local a = math.random() * math.pi * 2
		local to = from.Position + Vector3.new(math.cos(a) * 40, 24 + math.random() * 12, math.sin(a) * 40)
		table.insert(flights, { bird = b, from = from, to = to, t0 = os.clock() })
	end
	f.birds = {}
	f.backAt = os.clock() + BACK_AFTER
end

local function addSpot(inst: Instance)
	if inst:IsA("BasePart") and not flocks[inst] then
		local f: Flock = { spot = inst, birds = {}, backAt = 0 }
		flocks[inst] = f
		land(f)
	end
end

local function removeSpot(inst: Instance)
	local f = flocks[inst :: BasePart]
	if f then
		for _, b in ipairs(f.birds) do
			b.model:Destroy()
		end
		flocks[inst :: BasePart] = nil
	end
end

-- a floating target was shot: pop it, bring it back after a moment.
local popped: { [BasePart]: boolean } = {}
function MapLife.HitTarget(target: BasePart)
	if popped[target] then
		return
	end
	popped[target] = true
	SoundController.PlayAt("Pop", target.Position, 1.2)
	local a = Instance.new("Attachment")
	a.WorldPosition = target.Position
	a.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 90, 90), Color3.new(1, 1, 1))
	e.Size = NumberSequence.new(1, 0)
	e.Speed = NumberRange.new(10, 20)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Lifetime = NumberRange.new(0.3, 0.6)
	e.Rate = 0
	e.Parent = a
	e:Emit(20)
	task.delay(1, function()
		a:Destroy()
	end)
	local parts = { target }
	for _, d in ipairs(target:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
		end
	end
	for _, p in ipairs(parts) do
		p.LocalTransparencyModifier = 1
	end
	target.CanQuery = false
	task.delay(3, function()
		for _, p in ipairs(parts) do
			p.LocalTransparencyModifier = 0
		end
		target.CanQuery = true
		popped[target] = nil
	end)
end

function MapLife.Start()
	for _, inst in ipairs(CollectionService:GetTagged("BirdSpot")) do
		addSpot(inst)
	end
	CollectionService:GetInstanceAddedSignal("BirdSpot"):Connect(addSpot)
	CollectionService:GetInstanceRemovedSignal("BirdSpot"):Connect(removeSpot)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		-- birds in the air: fly up and away, flapping, then gone.
		for i = #flights, 1, -1 do
			local fl = flights[i]
			local t = (now - fl.t0) / FLIGHT
			if t >= 1 or not fl.bird.model.Parent then
				fl.bird.model:Destroy()
				table.remove(flights, i)
			else
				local e = 1 - (1 - t) * (1 - t)
				local pos = fl.from.Position:Lerp(fl.to, e)
				local look = CFrame.lookAt(pos, pos + (fl.to - fl.from.Position) * Vector3.new(1, 0.3, 1))
				fl.bird.model:PivotTo(look)
				local flap = math.sin(now * 40) * 0.8
				for _, w in ipairs(fl.bird.wings) do
					local s = w:GetAttribute("Side") :: number
					w.CFrame = look * CFrame.new(s * 0.42, 0.05, 0.05) * CFrame.Angles(0, 0, s * flap)
				end
			end
		end
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		-- cats nearby scare them; empty spots fill again after a while.
		local cats = {}
		for _, m in ipairs(CollectionService:GetTagged(CatBuilder.Tag)) do
			if m:IsA("Model") and m.PrimaryPart then
				table.insert(cats, (m.PrimaryPart :: BasePart).Position)
			end
		end
		for spot, f in pairs(flocks) do
			if not spot.Parent then
				removeSpot(spot)
			elseif #f.birds > 0 then
				for _, p in ipairs(cats) do
					if (p - spot.Position).Magnitude < SCARE_RADIUS then
						scatter(f)
						break
					end
				end
			elseif now >= f.backAt then
				local clear = true
				for _, p in ipairs(cats) do
					if (p - spot.Position).Magnitude < SCARE_RADIUS * 1.5 then
						clear = false
						break
					end
				end
				if clear then
					land(f)
				end
			end
		end
	end)
end

return MapLife
