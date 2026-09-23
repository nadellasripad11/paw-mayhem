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
local LobbyScene = require(script.Parent.Parent.Lobby.LobbyScene)

local CameraController = {}

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local yaw, pitch = 0, 0.15
local distance = GameConfig.Camera.ThirdPersonDistance
local enabled = false
local lobbyView = false
local lookTouch: InputObject? = nil
local touchLastPos: Vector2? = nil
local shake = 0 -- decaying shake magnitude
local parallax = Vector2.zero
local camDist = 0

-- Distance to the first solid, visible part between two points. Walk-through
-- decoration (trees, lips, planks) and invisible walkway/guard collision are
-- skipped so they don't yank the camera in as you move past them.
local function blockerDistance(char: Model, from: Vector3, to: Vector3): number?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	local ignore: { Instance } = { char }
	for _ = 1, 6 do
		params.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(from, to - from, params)
		if not hit then
			return nil
		end
		if hit.Instance.Transparency < 0.6 then
			return (hit.Position - from).Magnitude
		end
		table.insert(ignore, hit.Instance)
	end
	return nil
end

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

-- A touch that starts on free screen space (not the joystick or a HUD button)
-- becomes the look drag. Only that finger turns the camera, so moving the
-- joystick while holding Fire can't swing the view.
local function onInputBegan(input: InputObject, gpe: boolean)
	if input.UserInputType == Enum.UserInputType.Touch and enabled and not gpe and not lookTouch then
		if input.Position.X > camera.ViewportSize.X * 0.4 then
			lookTouch = input
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
			local settings = require(script.Parent.Parent.ClientState).Settings
			local sens = 0.004 * ((settings.MouseSensitivity or GameConfig.Camera.Sensitivity) + 0.2)
			local invert = settings.InvertY and -1 or 1
			yaw -= d.X * sens
			pitch = math.clamp(pitch - d.Y * sens * invert, MIN_PITCH, MAX_PITCH)
		end
	elseif input == lookTouch then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		if touchLastPos then
			local d = pos - touchLastPos
			local settings = require(script.Parent.Parent.ClientState).Settings
			local sens = 0.006 * (0.5 + settings.MobileSensitivity)
			local invert = settings.InvertY and -1 or 1
			yaw -= d.X * sens
			pitch = math.clamp(pitch - d.Y * sens * invert, MIN_PITCH, MAX_PITCH)
		end
		touchLastPos = pos
	end
end

local function onInputEnded(input: InputObject)
	if input == lookTouch then
		lookTouch = nil
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
	if lobbyView then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = LobbyScene.FieldOfView
		local t = os.clock()
		local vp = camera.ViewportSize
		local mouse = UserInputService:GetMouseLocation()
		local target = Vector2.zero
		if vp.X > 0 and vp.Y > 0 then
			target = Vector2.new(math.clamp(mouse.X / vp.X - 0.5, -0.5, 0.5), math.clamp(mouse.Y / vp.Y - 0.5, -0.5, 0.5))
		end
		parallax = parallax:Lerp(target, math.clamp(dt * 3, 0, 1))
		camera.CFrame = LobbyScene.GetCameraCFrame()
			* CFrame.new(math.sin(t * 0.23) * 0.18 + parallax.X * 0.7, math.sin(t * 0.19) * 0.1 - parallax.Y * 0.35, 0)
			* CFrame.Angles(parallax.Y * 0.006, -parallax.X * 0.01, 0)
		return
	end
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
	camera.FieldOfView = require(script.Parent.Parent.ClientState).Settings.FieldOfView or GameConfig.Camera.FieldOfView

	local focus = root.Position + Vector3.new(0, 1.5, 0)
	local rot = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	local shoulder = GameConfig.Camera.ShoulderOffset

	-- Camera sits behind + offset from the shoulder. It snaps in when a wall
	-- blocks it and eases back out, so it never pops back and forth.
	local offset = rot:VectorToWorldSpace(Vector3.new(shoulder.X, shoulder.Y, distance))
	local want = offset.Magnitude
	local block = blockerDistance(char, focus, focus + offset)
	if block then
		want = math.max(2, block - 1)
	end
	if camDist <= 0 or want < camDist then
		camDist = want
	else
		camDist += (want - camDist) * math.clamp(dt * 5, 0, 1)
	end
	local camPos = focus + offset.Unit * camDist

	local lookAt = focus + rot:VectorToWorldSpace(Vector3.new(shoulder.X, shoulder.Y, -20))
	local finalCF = CFrame.lookAt(camPos, lookAt)

	-- Apply decaying shake.
	if shake > 0.001 then
		local s = shake
		finalCF = finalCF * CFrame.new((math.random() - 0.5) * s * 0.4, (math.random() - 0.5) * s * 0.4, 0)
			* CFrame.Angles((math.random() - 0.5) * s * 0.015, (math.random() - 0.5) * s * 0.015, 0)
		shake = math.max(0, shake - dt * 4)
	end
	camera.CFrame = finalCF

	-- Face where you aim, shooter-style, so the held blaster points at the
	-- crosshair (the cat's front is its -Z, same as the camera's look).
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 and not char:GetAttribute("Emoting") then
		hum.AutoRotate = false
		local want = CFrame.Angles(0, yaw, 0)
		if root.CFrame.LookVector:Dot(want.LookVector) < 0.9999 then
			root.CFrame = CFrame.new(root.Position) * want
		end
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
	lookTouch = nil
	touchLastPos = nil
	camDist = 0
	local spawnRoot = on and player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if spawnRoot then
		local lv = spawnRoot.CFrame.LookVector
		yaw = math.atan2(-lv.X, -lv.Z)
	end
	if on then
		lobbyView = false
	end
	if on then
		if not isMobile() and UserInputService.MouseEnabled then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		end
	else
		if not lobbyView then
			camera.CameraType = Enum.CameraType.Custom
		end
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

function CameraController.SetLobbyView(on: boolean)
	lobbyView = on
	local ok, err = pcall(LobbyScene.SetActive, on)
	if not ok then
		warn("[PAW MAYHEM] Lobby scene toggle failed: " .. tostring(err))
	end
	if on then
		enabled = false
		camera.CameraType = Enum.CameraType.Scriptable
		camera.FieldOfView = LobbyScene.FieldOfView
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	else
		camera.CameraType = Enum.CameraType.Custom
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
