--!strict
-- EffectsController: world + screen VFX driven by server events.
--   PlayEffect(Tracer)  -> neon bolt from muzzle to hit point
--   YouWereHit          -> camera shake + red screen flash
--   HitConfirm          -> hitmarker callback (HUD draws it)
--   PowerUpTaken/Spawned -> pickup sparkle
-- Purely cosmetic; no gameplay authority here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)

local CameraController = require(script.Parent.CameraController)
local ClientState = require(script.Parent.Parent.ClientState)

local EffectsController = {}
local player = Players.LocalPlayer

-- Callbacks the HUD can hook.
EffectsController.OnHitConfirm = nil :: ((data: any) -> ())?
EffectsController.OnHurt = nil :: ((data: any) -> ())?

local flashGui: ScreenGui? = nil
local flashFrame: Frame? = nil

local function ensureFlash()
	if flashFrame and flashFrame.Parent then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PawHurtFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	flashGui = gui
	flashFrame = frame
end

local function flashHurt()
	ensureFlash()
	local frame = flashFrame :: Frame
	frame.BackgroundTransparency = 0.55
	task.spawn(function()
		for i = 1, 12 do
			frame.BackgroundTransparency = 0.55 + i * 0.0375
			task.wait(0.02)
		end
		frame.BackgroundTransparency = 1
	end)
end

local function drawTracer(from: Vector3, to: Vector3, color: Color3)
	local dist = (to - from).Magnitude
	if dist < 0.1 then
		return
	end
	local bolt = Instance.new("Part")
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = color
	bolt.Size = Vector3.new(0.3, 0.3, dist)
	bolt.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	bolt.Parent = workspace
	Debris:AddItem(bolt, 0.12)

	-- impact spark
	local spark = Instance.new("Part")
	spark.Shape = Enum.PartType.Ball
	spark.Anchored = true
	spark.CanCollide = false
	spark.CanQuery = false
	spark.Material = Enum.Material.Neon
	spark.Color = color
	spark.Size = Vector3.new(1, 1, 1)
	spark.Position = to
	spark.Parent = workspace
	Debris:AddItem(spark, 0.15)
end

local function pickupSparkle(pos: Vector3, color: Color3)
	local burst = Instance.new("Part")
	burst.Shape = Enum.PartType.Ball
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.Material = Enum.Material.Neon
	burst.Color = color
	burst.Size = Vector3.new(3, 3, 3)
	burst.Position = pos
	burst.Transparency = 0.2
	burst.Parent = workspace
	task.spawn(function()
		for i = 1, 10 do
			burst.Size = burst.Size + Vector3.new(1, 1, 1)
			burst.Transparency = 0.2 + i * 0.08
			task.wait(0.02)
		end
		burst:Destroy()
	end)
end

function EffectsController.Start()
	Remotes.Get("PlayEffect").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if data.kind == "Tracer" then
			drawTracer(data.from, data.to, data.color or Color3.fromRGB(180, 120, 255))
		end
	end)

	Remotes.Get("YouWereHit").OnClientEvent:Connect(function(data)
		CameraController.AddShake(0.8)
		if ClientState.Settings.ShowDamage then
			flashHurt()
		end
		if EffectsController.OnHurt then
			EffectsController.OnHurt(data)
		end
	end)

	Remotes.Get("HitConfirm").OnClientEvent:Connect(function(data)
		if EffectsController.OnHitConfirm then
			EffectsController.OnHitConfirm(data)
		end
	end)

	Remotes.Get("PowerUpTaken").OnClientEvent:Connect(function(data)
		-- sparkle handled where the orb was; keep simple
	end)

	Remotes.Get("PowerUpSpawned").OnClientEvent:Connect(function(data)
		if data and data.position then
			pickupSparkle(data.position, data.color or Color3.fromRGB(255, 255, 255))
		end
	end)
end

return EffectsController
