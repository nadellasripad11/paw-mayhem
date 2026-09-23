--!strict
-- LavaFX: client-side life for the Volcano's lava. The server builds static,
-- tagged parts; here crust plates ("LavaCrust") drift and bob, hot spots
-- ("LavaHot") pulse between orange and yellow, and bubbles swell and pop at
-- "LavaVent" areas near the camera. All of it is local, so nothing replicates.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local LavaFX = {}

local HOT_A = Color3.fromRGB(255, 100, 24)
local HOT_B = Color3.fromRGB(255, 204, 88)
local BUBBLE_EVERY = 0.08
local MAX_BUBBLES = 45
local SEA_SAMPLE_RADIUS = 240
local VENT_RANGE = 380

type CrustInfo = { base: CFrame, phase: number, speed: number, drift: number }

local crust: { [BasePart]: CrustInfo } = {}
local hotParts: { [BasePart]: number } = {}
local vents: { [BasePart]: boolean } = {}
local crustDirty = true
local crustList: { BasePart } = {}
local crustInfo: { CrustInfo } = {}
local rng = Random.new()
local bubbles = 0
local fxFolder: Folder? = nil

local function folder(): Folder
	if not fxFolder or not fxFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "LavaFX"
		f.Parent = Workspace
		fxFolder = f
	end
	return fxFolder :: Folder
end

local function track(tag: string, add: (BasePart) -> (), remove: (BasePart) -> ())
	local function onAdd(inst: Instance)
		if inst:IsA("BasePart") then
			add(inst)
		end
	end
	local function onRemove(inst: Instance)
		if inst:IsA("BasePart") then
			remove(inst)
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		onAdd(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdd)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemove)
end

local function fxPart(shape: Enum.PartType, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder()
	return p
end

local function pop(pos: Vector3, d: number)
	-- Splash ring (flat disc: cylinder axis rolled upright).
	local ring = fxPart(Enum.PartType.Cylinder, Vector3.new(0.15, d, d), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), HOT_B)
	ring.Transparency = 0.2
	local t = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, d * 2.8, d * 2.8), Transparency = 1 })
	t.Completed:Connect(function()
		ring:Destroy()
	end)
	t:Play()
	-- A few spatter blobs thrown up and out.
	for _ = 1, 3 do
		local blob = fxPart(Enum.PartType.Ball, Vector3.one * rng:NextNumber(0.3, 0.6), CFrame.new(pos), HOT_A:Lerp(HOT_B, rng:NextNumber()))
		local a = rng:NextNumber(0, math.pi * 2)
		local target = pos + Vector3.new(math.cos(a) * d * 0.9, rng:NextNumber(1.2, 2.6) * d * 0.6, math.sin(a) * d * 0.9)
		local tb = TweenService:Create(blob, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(target), Transparency = 1 })
		tb.Completed:Connect(function()
			blob:Destroy()
		end)
		tb:Play()
	end
end

local function bubble(pos: Vector3)
	bubbles += 1
	local d = rng:NextNumber(1.2, 3.4)
	local b = fxPart(Enum.PartType.Ball, Vector3.one * 0.2, CFrame.new(pos), HOT_B:Lerp(HOT_A, rng:NextNumber()))
	local grow = TweenService:Create(b, TweenInfo.new(rng:NextNumber(0.6, 1.2), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * d,
		CFrame = CFrame.new(pos + Vector3.new(0, d * 0.2, 0)),
	})
	grow.Completed:Connect(function()
		b:Destroy()
		bubbles -= 1
		pop(pos, d)
	end)
	grow:Play()
end

-- Pick a spot on the lava near the camera, or nil if none is close.
local function bubbleSpot(camPos: Vector3): Vector3?
	local nearVents = {}
	local sea: BasePart? = nil
	for v in pairs(vents) do
		if v:GetAttribute("Sea") then
			sea = v
		elseif (v.Position - camPos).Magnitude < VENT_RANGE then
			table.insert(nearVents, v)
		end
	end
	if #nearVents > 0 and (not sea or rng:NextNumber() < 0.35) then
		local v = nearVents[rng:NextInteger(1, #nearVents)]
		local r = (v:GetAttribute("Radius") :: number?) or 6
		local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * r
		local y = (v:GetAttribute("SurfaceY") :: number?) or v.Position.Y
		return Vector3.new(v.Position.X + math.cos(a) * d, y, v.Position.Z + math.sin(a) * d)
	end
	if sea then
		local y = (sea:GetAttribute("SurfaceY") :: number?) or sea.Position.Y
		if camPos.Y - y > 400 then
			return nil
		end
		local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * SEA_SAMPLE_RADIUS
		local p = Vector3.new(camPos.X + math.cos(a) * d, y, camPos.Z + math.sin(a) * d)
		local r = (sea:GetAttribute("Radius") :: number?) or 400
		if Vector3.new(p.X - sea.Position.X, 0, p.Z - sea.Position.Z).Magnitude < r then
			return p
		end
	end
	return nil
end

function LavaFX.Start()
	track("LavaCrust", function(p)
		crust[p] = { base = p.CFrame, phase = rng:NextNumber(0, math.pi * 2), speed = rng:NextNumber(0.05, 0.12), drift = rng:NextNumber(0.8, 2.2) }
		crustDirty = true
	end, function(p)
		crust[p] = nil
		crustDirty = true
	end)
	track("LavaHot", function(p)
		hotParts[p] = rng:NextNumber(0, math.pi * 2)
	end, function(p)
		hotParts[p] = nil
	end)
	track("LavaVent", function(p)
		vents[p] = true
	end, function(p)
		vents[p] = nil
	end)

	local t, hotClock, bubbleClock = 0, 0, 0
	local cfs: { CFrame } = {}
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		if crustDirty then
			crustDirty = false
			table.clear(crustList)
			table.clear(crustInfo)
			for p, info in pairs(crust) do
				table.insert(crustList, p)
				table.insert(crustInfo, info)
			end
		end
		local n = #crustList
		if n > 0 then
			for i = 1, n do
				local c = crustInfo[i]
				local w = t * c.speed + c.phase
				local off = Vector3.new(math.sin(w) * c.drift, math.sin(t * 0.7 + c.phase) * 0.12, math.cos(w * 0.8) * c.drift)
				cfs[i] = (c.base + off) * CFrame.Angles(0, math.sin(w * 0.5) * 0.03, 0)
			end
			for i = n + 1, #cfs do
				cfs[i] = nil
			end
			Workspace:BulkMoveTo(crustList, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		end

		hotClock += dt
		if hotClock >= 0.05 then
			hotClock = 0
			for p, phase in pairs(hotParts) do
				p.Color = HOT_A:Lerp(HOT_B, 0.5 + 0.5 * math.sin(t * 1.6 + phase))
			end
		end

		bubbleClock += dt
		if next(vents) and bubbleClock >= BUBBLE_EVERY then
			bubbleClock = 0
			if bubbles < MAX_BUBBLES then
				local spot = bubbleSpot(Workspace.CurrentCamera.CFrame.Position)
				if spot then
					bubble(spot)
				end
			end
		end
	end)
end

return LavaFX
