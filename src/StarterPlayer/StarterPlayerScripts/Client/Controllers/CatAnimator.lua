--!strict
-- CatAnimator: procedural walk + idle for every cat (players, bots and the 3D
-- menu previews), posed locally each frame with CatBuilder.Pose. Rising or
-- falling fast (jumps, launches) blends into the mid-air pose, and a cat
-- flying from a big hit streaks a speed trail behind it. A cat blasted off
-- the map goes out with a star twinkle and a ding.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local SoundController = require(script.Parent.SoundController)

local CatAnimator = {}

local lastHurtAt = 0

local MAX_DIST = 180
local TRAIL_ON, TRAIL_OFF = 48, 30 -- studs/s: a launch, not a sprint

local trails: { [Model]: Trail } = setmetatable({}, { __mode = "k" }) :: any
local twinkled: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any
local OFF_MAP = 175 -- studs from the middle: past every island

-- "Blasted off!" twinkle where a launched cat leaves the arena.
local function blastOff(pos: Vector3)
	local star = Instance.new("Part")
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.one * 2
	star.Material = Enum.Material.Neon
	star.Color = Color3.fromRGB(255, 240, 170)
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false
	star.CastShadow = false
	star.Position = pos
	star.Parent = Workspace
	local light = Instance.new("PointLight")
	light.Color = star.Color
	light.Range = 40
	light.Brightness = 6
	light.Parent = star
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 250, 210))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(10, 26)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Enabled = false
	e.Parent = star
	e:Emit(40)
	TweenService:Create(star, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.one * 7 }):Play()
	task.delay(0.5, function()
		TweenService:Create(star, TweenInfo.new(0.4), { Size = Vector3.one * 0.2, Transparency = 1 }):Play()
		TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	end)
	Debris:AddItem(star, 1.2)
	SoundController.PlayAt("Knockout", pos, 1.3)
end

local function trailFor(model: Model, root: BasePart): Trail
	local t = trails[model]
	if t and t.Parent then
		return t
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "LaunchTrailTop"
	a0.Position = Vector3.new(0, 1.1, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "LaunchTrailBottom"
	a1.Position = Vector3.new(0, -0.9, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "LaunchTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.FaceCamera = true
	trail.LightEmission = 0.4
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 220, 150))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Enabled = false
	trail.Parent = root
	trails[model] = trail
	return trail
end

function CatAnimator.Start()
	require(ReplicatedStorage.Shared.Net.Remotes).Get("YouWereHit").OnClientEvent:Connect(function()
		lastHurtAt = os.clock()
	end)
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local camPos = Workspace.CurrentCamera.CFrame.Position
		for _, inst in ipairs(CollectionService:GetTagged(CatBuilder.Tag)) do
			local root = inst:IsA("Model") and inst.PrimaryPart
			if root then
				local move, air = 0, 0
				local inWorld = inst:IsDescendantOf(Workspace)
				if not inWorld or (root.Position - camPos).Magnitude <= MAX_DIST then
					if inWorld then
						local v = root.AssemblyLinearVelocity
						move = Vector3.new(v.X, 0, v.Z).Magnitude / GameConfig.Character.WalkSpeed
						air = math.clamp((math.abs(v.Y) - 6) / 14, 0, 1)
						local speed = v.Magnitude
						local p = root.Position
						local model = inst :: Model
						if speed > 40 and (Vector3.new(p.X, 0, p.Z).Magnitude > OFF_MAP or p.Y < -40) and os.clock() - (twinkled[model] or 0) > 4 then
							twinkled[model] = os.clock()
							blastOff(p)
						end
						local trail = trails[inst :: Model]
						if speed > TRAIL_ON then
							local tr = trailFor(inst :: Model, root)
							-- Only real launches thump: going up fast, and for your own cat only
							-- right after a hit (not your own dash / pounce).
							local mine = inst == Players.LocalPlayer.Character
							if not tr.Enabled and v.Y > 12 and inst:GetAttribute("Replay") == nil and (not mine or os.clock() - lastHurtAt < 0.5) then
								SoundController.Launch(root.Position)
							end
							tr.Enabled = true
						elseif trail and speed < TRAIL_OFF then
							trail.Enabled = false
						end
					end
					local seed = inst:GetAttribute("PoseSeed")
					CatBuilder.Pose(inst :: Model, t + (typeof(seed) == "number" and seed or 0), move, air)
				end
			end
		end
	end)
end

return CatAnimator
