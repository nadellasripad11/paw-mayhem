--!strict
-- PodiumService: after every match the top 3 stand on a winners' stage built
-- just outside the arena — gold in the middle, silver left, bronze right.
-- Real players appear as their actual Roblox avatar (scaled up big so the
-- whole server can see them); bots appear as their cat. Each gets a name +
-- eliminations tag. Clients are sent a camera shot of the stage.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)

local PodiumService = {}

local stage: Model? = nil

-- place -> x offset, pedestal height, colour, avatar scale
local SPOTS = {
	{ x = 0, h = 9, color = Color3.fromRGB(255, 205, 70), scale = 3.2, label = "1ST" },
	{ x = -15, h = 6, color = Color3.fromRGB(214, 222, 236), scale = 2.7, label = "2ND" },
	{ x = 15, h = 4, color = Color3.fromRGB(222, 142, 84), scale = 2.4, label = "3RD" },
}

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function tag(adornee: BasePart, rank: number, name: string, elims: number, color: Color3, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.Size = UDim2.fromScale(14, 5)
	gui.StudsOffsetWorldSpace = Vector3.new(0, height, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 1000
	gui.AlwaysOnTop = true
	gui.Parent = adornee
	local function label(text: string, y: number, h: number, c: Color3)
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0, y)
		l.Size = UDim2.fromScale(1, h)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.Text = text
		l.TextColor3 = c
		l.TextStrokeTransparency = 0.1
		l.TextStrokeColor3 = Color3.fromRGB(20, 16, 34)
		l.Parent = gui
	end
	label(SPOTS[rank].label, 0, 0.3, color)
	label(name, 0.3, 0.4, Color3.new(1, 1, 1))
	label(string.format("%d ELIMINATIONS", elims), 0.72, 0.28, Color3.fromRGB(255, 226, 120))
end

local function standOn(model: Model, top: CFrame, scale: number, faceTo: Vector3)
	pcall(function()
		model:ScaleTo(scale)
	end)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		elseif d:IsA("Script") or d:IsA("LocalScript") then
			d:Destroy()
		end
	end
	local _, size = model:GetBoundingBox()
	local pos = top.Position + Vector3.new(0, size.Y / 2, 0)
	model:PivotTo(CFrame.lookAt(pos, Vector3.new(faceTo.X, pos.Y, faceTo.Z)))
end

local function avatarFor(entry: any): Model?
	if entry.IsBot or not entry.UserId or entry.UserId <= 0 then
		local cat = CatBuilder.Build(nil, entry.Display)
		local hum = cat:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:Destroy()
		end
		return cat
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromUserId(entry.UserId)
	end)
	if ok and model then
		local hum = model:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
		return model
	end
	return nil
end

function PodiumService.Clear()
	if stage then
		stage:Destroy()
		stage = nil
	end
end

-- `top` is up to three board entries {Display, UserId?, Elims, IsBot?}.
function PodiumService.Show(top: { any })
	PodiumService.Clear()
	if #top == 0 then
		return
	end
	local arena = Workspace:FindFirstChild("Arena")
	local center, size = Vector3.new(0, 40, 0), Vector3.new(200, 40, 200)
	if arena and arena:IsA("Model") then
		local cf, s = arena:GetBoundingBox()
		center, size = cf.Position, s
	elseif arena then
		-- Folders have no bounding box: measure the parts.
		local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, d in ipairs(arena:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 1 and d.Size.Magnitude < 400 then
				minV = minV:Min(d.Position)
				maxV = maxV:Max(d.Position)
			end
		end
		if minV.X < math.huge then
			center, size = (minV + maxV) / 2, maxV - minV
		end
	end

	-- Stage floats beside the arena, facing its centre.
	local base = center + Vector3.new(0, 6, size.Z / 2 + 70)
	local model = Instance.new("Model")
	model.Name = "WinnersPodium"
	local look = CFrame.lookAt(base, Vector3.new(center.X, base.Y, center.Z))
	part(model, Vector3.new(58, 3, 30), look * CFrame.new(0, -1.5, 0), Color3.fromRGB(40, 48, 82), Enum.Material.SmoothPlastic)
	part(model, Vector3.new(60, 0.6, 32), look * CFrame.new(0, 0.2, 0), Color3.fromRGB(120, 200, 255), Enum.Material.Neon).Transparency = 0.5
	-- Back wall with a glowing rim
	part(model, Vector3.new(58, 30, 2), look * CFrame.new(0, 14, 13), Color3.fromRGB(28, 36, 70))
	part(model, Vector3.new(58, 1, 2.4), look * CFrame.new(0, 29, 13), Color3.fromRGB(255, 205, 70), Enum.Material.Neon)

	for rank, entry in ipairs(top) do
		local spot = SPOTS[rank]
		if spot then
			local pedCF = look * CFrame.new(spot.x, spot.h / 2 + 0.5, 0)
			local ped = part(model, Vector3.new(12, spot.h, 12), pedCF, spot.color, Enum.Material.SmoothPlastic)
			part(model, Vector3.new(12.4, 0.6, 12.4), pedCF * CFrame.new(0, spot.h / 2, 0), spot.color:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Neon)
			local topCF = pedCF * CFrame.new(0, spot.h / 2 + 0.3, 0)
			local avatar = avatarFor(entry)
			if avatar then
				avatar.Parent = model
				standOn(avatar, topCF, entry.IsBot and spot.scale * 1.4 or spot.scale, center)
				local _, s = avatar:GetBoundingBox()
				tag(ped, rank, entry.Display or "?", entry.Elims or 0, spot.color, spot.h / 2 + s.Y + 4)
			end
			if rank == 1 then
				local sparkle = Instance.new("ParticleEmitter")
				sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
				sparkle.Rate = 30
				sparkle.Lifetime = NumberRange.new(1.2, 2)
				sparkle.Speed = NumberRange.new(4, 9)
				sparkle.SpreadAngle = Vector2.new(60, 60)
				sparkle.Parent = ped
				local light = Instance.new("SpotLight")
				light.Face = Enum.NormalId.Top
				light.Range = 40
				light.Brightness = 3
				light.Color = Color3.fromRGB(255, 230, 170)
				light.Parent = ped
			end
		end
	end
	model.Parent = Workspace
	stage = model

	-- A camera shot framing the stage from the arena side.
	local camPos = (look * CFrame.new(0, 16, -58)).Position
	local focus = (look * CFrame.new(0, 12, 0)).Position
	Remotes.Get("Podium"):FireAllClients({ camera = CFrame.lookAt(camPos, focus), focus = focus })
end

return PodiumService
