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
	-- Two layered beams make every shot read at a distance: a soft glowing
	-- silhouette first, then a crisp bright core, like the reference blasters.
	local glow = Instance.new("Part")
	glow.Anchored = true
	glow.CanCollide = false
	glow.CanQuery = false
	glow.Material = Enum.Material.Neon
	glow.Color = color
	glow.Transparency = 0.5
	glow.Size = Vector3.new(0.72, 0.72, dist)
	glow.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	glow.Parent = workspace
	Debris:AddItem(glow, 0.13)

	local bolt = Instance.new("Part")
	bolt.Anchored = true
	bolt.CanCollide = false
	bolt.CanQuery = false
	bolt.Material = Enum.Material.Neon
	bolt.Color = color
	bolt.Size = Vector3.new(0.22, 0.22, dist)
	bolt.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	bolt.Parent = workspace
	Debris:AddItem(bolt, 0.12)

	-- A short radial hit burst keeps impacts visible without adding gameplay
	-- objects or physics load.
	for i = 1, 5 do
		local spark = Instance.new("Part")
		spark.Shape = Enum.PartType.Ball
		spark.Anchored = true
		spark.CanCollide = false
		spark.CanQuery = false
		spark.Material = Enum.Material.Neon
		spark.Color = color
		spark.Size = Vector3.new(0.65, 0.65, 0.65)
		local angle = (math.pi * 2 / 5) * i
		spark.Position = to + Vector3.new(math.cos(angle), math.sin(angle * 2) * 0.45, math.sin(angle)) * 0.4
		spark.Parent = workspace
		Debris:AddItem(spark, 0.16)
	end
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
	for i = 1, 6 do
		local shard = Instance.new("Part")
		shard.Shape = Enum.PartType.Ball
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanQuery = false
		shard.Material = Enum.Material.Neon
		shard.Color = color
		shard.Size = Vector3.new(0.45, 0.45, 0.45)
		shard.Position = pos
		shard.Parent = workspace
		local angle = (math.pi * 2 / 6) * i
		task.spawn(function()
			for step = 1, 7 do
				shard.Position += Vector3.new(math.cos(angle) * 0.32, 0.22, math.sin(angle) * 0.32)
				shard.Transparency = step / 8
				task.wait(0.025)
			end
			shard:Destroy()
		end)
	end
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
		CameraController.AddShake(0.35)
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
		if data and data.position then
			pickupSparkle(data.position, data.color or Color3.fromRGB(255, 255, 255))
		end
	end)

	Remotes.Get("PowerUpSpawned").OnClientEvent:Connect(function(data)
		if data and data.position then
			pickupSparkle(data.position, data.color or Color3.fromRGB(255, 255, 255))
		end
	end)
end

return EffectsController
