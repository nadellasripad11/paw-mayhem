--!strict
-- CatAnimator: procedural walk + idle for every cat (players, bots and the 3D
-- menu previews), posed locally each frame with CatBuilder.Pose.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local CatAnimator = {}

local MAX_DIST = 180

function CatAnimator.Start()
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local camPos = Workspace.CurrentCamera.CFrame.Position
		for _, inst in ipairs(CollectionService:GetTagged(CatBuilder.Tag)) do
			local root = inst:IsA("Model") and inst.PrimaryPart
			if root then
				local move = 0
				local inWorld = inst:IsDescendantOf(Workspace)
				if not inWorld or (root.Position - camPos).Magnitude <= MAX_DIST then
					if inWorld then
						local v = root.AssemblyLinearVelocity
						move = Vector3.new(v.X, 0, v.Z).Magnitude / GameConfig.Character.WalkSpeed
					end
					local seed = inst:GetAttribute("PoseSeed")
					CatBuilder.Pose(inst :: Model, t + (typeof(seed) == "number" and seed or 0), move)
				end
			end
		end
	end)
end

return CatAnimator
