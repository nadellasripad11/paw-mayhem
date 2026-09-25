--!strict
-- CatAnimator: procedural walk + idle for every cat (players, bots and the 3D
-- menu previews), posed locally each frame with CatBuilder.Pose. Rising or
-- falling fast (jumps, launches) blends into the mid-air pose, and a cat
-- flying from a big hit streaks a speed trail behind it.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local CatAnimator = {}

local MAX_DIST = 180
local TRAIL_ON, TRAIL_OFF = 48, 30 -- studs/s: a launch, not a sprint

local trails: { [Model]: Trail } = setmetatable({}, { __mode = "k" }) :: any

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
						local trail = trails[inst :: Model]
						if speed > TRAIL_ON then
							trailFor(inst :: Model, root).Enabled = true
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
