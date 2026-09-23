--!strict
-- CombatController: turns fire input (mouse / touch button / gamepad R2) into
-- rate-limited FireWeapon requests. The server is authoritative; this only
-- predicts the muzzle flash + crosshair kick for feel. Ammo is unlimited.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Weapons = require(Shared.Config.Weapons)

local CameraController = require(script.Parent.CameraController)
local ClientState = require(script.Parent.Parent.ClientState)

local CombatController = {}

local player = Players.LocalPlayer
local firing = false
local lastShot = 0
local enabled = false

-- Fires whenever a local shot goes out, so the HUD can kick the crosshair.
CombatController.OnLocalShot = nil :: ((weaponId: string) -> ())?

local function currentWeapon()
	local profile = ClientState.Profile
	local id = profile and profile.Loadout.Weapon or Weapons.DefaultLoadout
	return Weapons.Get(id) or Weapons.Get(Weapons.DefaultLoadout)
end

local function muzzlePosition(): Vector3
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return Vector3.new()
	end
	-- Shots leave the barrel of the blaster the cat is holding.
	local tip = char and char:FindFirstChild("MuzzlePoint", true)
	if tip and tip:IsA("BasePart") then
		return tip.Position
	end
	-- The custom camera can look independently from the Humanoid's current
	-- facing direction. Place the visual muzzle on the camera's horizontal aim
	-- so the local flash, server origin validation, and crosshair all agree.
	local _, aim = CameraController.GetAimRay()
	local flatAim = Vector3.new(aim.X, 0, aim.Z)
	local facing = flatAim.Magnitude > 0.01 and flatAim.Unit or root.CFrame.LookVector
	return root.Position + facing * 1.5 + Vector3.new(0, 0.8, 0)
end

local function tryFire()
	if not enabled then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local weapon = currentWeapon()
	if not weapon then
		return
	end
	local interval = 1 / weapon.FireRate
	local now = os.clock()
	if now - lastShot < interval then
		return
	end
	lastShot = now

	local muzzle = muzzlePosition()
	local dir = CameraController.GetShootDirection(muzzle)

	Remotes.Get("FireWeapon"):FireServer({
		origin = muzzle,
		direction = dir,
	})

	-- local muzzle flash
	CombatController.MuzzleFlash(muzzle, weapon)
	if CombatController.OnLocalShot then
		CombatController.OnLocalShot(weapon.Id)
	end
end

function CombatController.MuzzleFlash(pos: Vector3, weapon)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(1.4, 1.4, 1.4)
	flash.Position = pos
	flash.Color = weapon.MuzzleColor
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.Transparency = 0.1
	flash.Parent = workspace
	task.spawn(function()
		for i = 1, 6 do
			flash.Size = flash.Size + Vector3.new(0.3, 0.3, 0.3)
			flash.Transparency = 0.1 + i * 0.15
			task.wait()
		end
		flash:Destroy()
	end)
end

function CombatController.SetFiring(on: boolean)
	firing = on
end

function CombatController.SetEnabled(on: boolean)
	enabled = on
	if not on then
		firing = false
	end
end

function CombatController.Start()
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = true
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			firing = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = false
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			firing = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		if firing then
			tryFire()
		end
	end)
end

return CombatController
