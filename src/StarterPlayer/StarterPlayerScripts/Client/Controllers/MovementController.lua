--!strict
-- MovementController: sprint toggle + applies the server's SpeedMult attribute
-- (Frost slow / Speed Boost) on top of walk/sprint, and plays knockback the
-- server sends us. Movement direction itself is handled by Roblox's default
-- control module, which follows our camera.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local MovementController = {}

local player = Players.LocalPlayer
local sprinting = false
local enabled = true
local activeLaunch: LinearVelocity? = nil

MovementController.SprintChanged = nil :: ((boolean) -> ())?

local function setSprint(on: boolean)
	sprinting = on
	if MovementController.SprintChanged then
		MovementController.SprintChanged(on)
	end
end

function MovementController.ToggleSprint()
	setSprint(not sprinting)
end

function MovementController.SetSprint(on: boolean)
	setSprint(on)
end

function MovementController.IsSprinting(): boolean
	return sprinting
end

-- A short LinearVelocity burst: long enough to read as a hit, short enough that
-- the player keeps steering. Bigger hits push a little longer.
local function launch(velocity: Vector3)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 or root.Anchored then
		return
	end
	if activeLaunch then
		activeLaunch:Destroy()
	end
	local att = root:FindFirstChild("LaunchAttachment") :: Attachment?
	if not att then
		local a = Instance.new("Attachment")
		a.Name = "LaunchAttachment"
		a.Parent = root
		att = a
	end
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = velocity
	lv.MaxForce = root.AssemblyMass * 4000
	lv.Parent = root
	activeLaunch = lv
	if velocity.Y > 2 then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	local duration = math.clamp(0.12 + velocity.Magnitude / 900, 0.12, 0.3)
	task.delay(duration, function()
		lv:Destroy()
		if activeLaunch == lv then
			activeLaunch = nil
		end
	end)
end

local function step()
	if not enabled then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then
		return
	end
	local base = sprinting and GameConfig.Character.SprintSpeed or GameConfig.Character.WalkSpeed
	local mult = char:GetAttribute("SpeedMult")
	if typeof(mult) ~= "number" then
		mult = 1
	end
	hum.WalkSpeed = base * mult
end

function MovementController.Start()
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			setSprint(true)
		elseif input.KeyCode == Enum.KeyCode.ButtonL3 then
			MovementController.ToggleSprint()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			setSprint(false)
		end
	end)
	Remotes.Get("Launch").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and typeof(data.velocity) == "Vector3" then
			launch(data.velocity)
		end
	end)
	RunService.Heartbeat:Connect(step)
end

return MovementController
