--!strict
-- CameraController: custom third-person over-the-shoulder camera.
-- Drives a Scriptable camera each frame (so Roblox's default camera yields) and
-- feeds look input from mouse, right-side touch drag, and the gamepad's right
-- stick. Exposes the current aim direction/ray for CombatController.
-- Movement stays on Roblox's default control module, which follows this camera.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local CameraController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local yaw, pitch = 0, 0.15
local distance = GameConfig.Camera.ThirdPersonDistance
local enabled = false
local touchRotating = false
local touchLastPos: Vector2? = nil
local shake = 0 -- decaying shake magnitude

-- Add a camera shake impulse (respects the CameraShake setting).
function CameraController.AddShake(amount: number)
	local ClientState = require(script.Parent.Parent.ClientState)
	if not ClientState.Settings.CameraShake then
		return
	end
	shake = math.min(2.5, shake + amount)
end

local MIN_PITCH, MAX_PITCH = -1.2, 1.2

local function isMobile()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- Right-side of screen begins a look drag on mobile (left side is the joystick).
local function onInputBegan(input: InputObject, gpe: boolean)
	if input.UserInputType == Enum.UserInputType.Touch and enabled then
		local vpx = camera.ViewportSize.X
		if input.Position.X > vpx * 0.4 then
			touchRotating = true
			touchLastPos = Vector2.new(input.Position.X, input.Position.Y)
		end
	end
end

local function onInputChanged(input: InputObject, gpe: boolean)
	if not enabled then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
			local d = input.Delta
			yaw -= d.X * 0.004 * (GameConfig.Camera.Sensitivity + 0.2)
			pitch = math.clamp(pitch - d.Y * 0.004 * (GameConfig.Camera.Sensitivity + 0.2), MIN_PITCH, MAX_PITCH)
		end
	elseif input.UserInputType == Enum.UserInputType.Touch and touchRotating then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if touchLastPos then
			local d = pos - touchLastPos
			local sens = 0.006 * (0.5 + require(script.Parent.Parent.ClientState).Settings.MobileSensitivity)
			yaw -= d.X * sens
			pitch = math.clamp(pitch - d.Y * sens, MIN_PITCH, MAX_PITCH)
		end
		touchLastPos = pos
	end
end

local function onInputEnded(input: InputObject)
	if input.UserInputType == Enum.UserInputType.Touch then
		touchRotating = false
		touchLastPos = nil
	end
end

local function updateGamepad(dt: number)
	local right = UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
	for _, state in ipairs(right) do
		if state.KeyCode == Enum.KeyCode.Thumbstick2 then
			local v = state.Position
			if v.Magnitude > 0.12 then
				yaw -= v.X * dt * 2.4 * (GameConfig.Camera.Sensitivity + 0.5)
				pitch = math.clamp(pitch + v.Y * dt * 2.0 * (GameConfig.Camera.Sensitivity + 0.5), MIN_PITCH, MAX_PITCH)
			end
		end
	end
end

local function step(dt: number)
	if not enabled then
		return
	end
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end

	updateGamepad(dt)

	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = GameConfig.Camera.FieldOfView

	local focus = root.Position + Vector3.new(0, 1.5, 0)
	local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local shoulder = GameConfig.Camera.ShoulderOffset

	-- Camera sits behind + offset from the shoulder.
	local offset = rot:VectorToWorldSpace(Vector3.new(shoulder.X, shoulder.Y, distance))
	local camPos = focus + offset

	-- Collision: pull the camera in if something blocks it.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = Workspace:Raycast(focus, camPos - focus, params)
	if hit then
		camPos = focus + (camPos - focus).Unit * math.max(2, (hit.Position - focus).Magnitude - 1)
	end

	local lookAt = focus + rot:VectorToWorldSpace(Vector3.new(shoulder.X, shoulder.Y, -20))
	local finalCF = CFrame.lookAt(camPos, lookAt)

	-- Apply decaying shake.
	if shake > 0.001 then
		local s = shake
		finalCF = finalCF * CFrame.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
			* CFrame.Angles((math.random() - 0.5) * s * 0.05, (math.random() - 0.5) * s * 0.05, 0)
		shake = math.max(0, shake - dt * 4)
	end
	camera.CFrame = finalCF

	-- Rotate the character to face the aim yaw so shots go where you look.
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.MoveDirection.Magnitude < 0.05 then
		-- face camera yaw while standing still
	end
end

-- Aim direction: the camera look vector (crosshair is centered).
function CameraController.GetAimRay(): (Vector3, Vector3)
	local origin = camera.CFrame.Position
	local dir = camera.CFrame.LookVector
	return origin, dir
end

-- Aim from the muzzle toward the crosshair world point.
function CameraController.GetShootDirection(muzzlePos: Vector3): Vector3
	local origin, dir = CameraController.GetAimRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local char = player.Character
	if char then
		params.FilterDescendantsInstances = { char }
	end
	local hit = Workspace:Raycast(origin, dir * 500, params)
	local target = hit and hit.Position or (origin + dir * 500)
	return (target - muzzlePos).Unit
end

function CameraController.SetEnabled(on: boolean)
	enabled = on
	if on then
		if not isMobile() and UserInputService.MouseEnabled then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		end
	else
		camera.CameraType = Enum.CameraType.Custom
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

function CameraController.Start()
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputEnded:Connect(onInputEnded)
	RunService:BindToRenderStep("PawCamera", Enum.RenderPriority.Camera.Value + 1, step)

	-- Re-assert lock when window regains focus.
	UserInputService.WindowFocused:Connect(function()
		if enabled and UserInputService.MouseEnabled then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end
	end)
end

return CameraController
