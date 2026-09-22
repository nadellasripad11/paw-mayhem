--!strict
-- MovementController: sprint toggle + applies the server's SpeedMult attribute
-- (Frost slow / Speed Boost) on top of walk/sprint. Movement direction itself
-- is handled by Roblox's default control module, which follows our camera.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local MovementController = {}

local player = Players.LocalPlayer
local sprinting = false
local enabled = true

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
	RunService.Heartbeat:Connect(step)
end

return MovementController
