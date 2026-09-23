--!strict
-- EventService: one map-specific event roughly every minute of a match.
--   Volcano     ERUPTION  — meteors arc out of the crater onto red warning
--                           circles, blast cats away and leave burning ground.
--   Sky Islands WIND GUST — a strong wind pushes everyone one way (the push is
--                           applied by each client; bots are nudged here).
--   Toybox      STAMPEDE  — giant bouncy balls bounce across the islands and
--                           bowl over anything in their path.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local GameConfig = require(Shared.Config.GameConfig)

local PlayerService = require(script.Parent.PlayerService)
local HazardService = require(script.Parent.HazardService)
local DropService = require(script.Parent.DropService)
local ArenaBuilder = require(script.Parent.Parent.World.ArenaBuilder)

local EventService = {}

local rng = Random.new()
local holder: Folder? = nil

local function folder(): Folder
	if not holder or not holder.Parent then
		local f = Instance.new("Folder")
		f.Name = "MapEvent"
		f.Parent = Workspace
		holder = f
	end
	return holder :: Folder
end

local function newPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = folder()
	return p
end

local function disc(name: string, diameter: number, thickness: number, pos: Vector3, color: Color3, material: Enum.Material?): Part
	local p = newPart(name, Vector3.new(thickness, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material or Enum.Material.Neon)
	p.Shape = Enum.PartType.Cylinder
	p.CastShadow = false
	return p
end

local function announce(title: string, sub: string, color: Color3)
	Remotes.Get("Announce"):FireAllClients({ title = title, sub = sub, color = color })
end

local function fade(p: BasePart, seconds: number, props: { [string]: any })
	local t = TweenService:Create(p, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t.Completed:Connect(function()
		p:Destroy()
	end)
	t:Play()
end

-- ── Volcano: eruption ────────────────────────────────────────────────────────
local LAVA = Color3.fromRGB(255, 110, 28)
local LAVA_GLOW = Color3.fromRGB(255, 196, 80)

local function burningGround(spot: Vector3)
	local crust = disc("Scorch", 9, 0.3, spot + Vector3.new(0, 0.12, 0), Color3.fromRGB(84, 40, 30), Enum.Material.CrackedLava)
	local glow = disc("Burning", 6.5, 0.35, spot + Vector3.new(0, 0.18, 0), LAVA_GLOW)
	CollectionService:AddTag(glow, "LavaHot")
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(90, 70, 66))
	smoke.Size = NumberSequence.new(2, 6)
	smoke.Transparency = NumberSequence.new(0.5, 1)
	smoke.Lifetime = NumberRange.new(1.5, 2.5)
	smoke.Speed = NumberRange.new(3, 6)
	smoke.Rate = 6
	smoke.EmissionDirection = Enum.NormalId.Right
	smoke.Parent = glow
	local untilT = os.clock() + 7
	while os.clock() < untilT and glow.Parent do
		for _, m in ipairs(HazardService.Cats()) do
			local off = (m.PrimaryPart :: BasePart).Position - spot
			if Vector3.new(off.X, 0, off.Z).Magnitude < 3.8 and off.Y > -1 and off.Y < 4.5 then
				HazardService.Hit(m, 4, Vector3.new(0, 26, 0))
			end
		end
		task.wait(0.5)
	end
	fade(glow, 0.8, { Transparency = 1 })
	fade(crust, 1.2, { Transparency = 1 })
end

local function meteor(from: Vector3, spot: Vector3)
	local warning = disc("MeteorWarning", 12, 0.15, spot + Vector3.new(0, 0.1, 0), Color3.fromRGB(255, 50, 40))
	warning.Transparency = 0.6
	TweenService:Create(warning, TweenInfo.new(0.25, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.2 }):Play()

	local rock = newPart("Meteor", Vector3.one * 3.6, CFrame.new(from), Color3.fromRGB(70, 44, 40), Enum.Material.Basalt)
	rock.Shape = Enum.PartType.Ball
	local core = newPart("MeteorCore", Vector3.one * 2.2, CFrame.new(from), LAVA, Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	core.Transparency = 0.2
	local fire = Instance.new("Fire")
	fire.Size = 7
	fire.Heat = 14
	fire.Color = LAVA
	fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
	fire.Parent = rock
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = "rbxasset://textures/particles/smoke_main.dds"
	trail.Color = ColorSequence.new(Color3.fromRGB(80, 60, 58))
	trail.Size = NumberSequence.new(2.5, 7)
	trail.Transparency = NumberSequence.new(0.35, 1)
	trail.Lifetime = NumberRange.new(1, 1.8)
	trail.Speed = NumberRange.new(0.5, 2)
	trail.Rate = 40
	trail.Parent = rock

	local flight = 1.7
	local apex = (from + spot) / 2 + Vector3.new(0, 45, 0)
	local t0 = os.clock()
	while true do
		local k = math.clamp((os.clock() - t0) / flight, 0, 1)
		local a = from:Lerp(apex, k)
		local b = apex:Lerp(spot, k)
		local p = a:Lerp(b, k)
		rock.CFrame = CFrame.new(p) * CFrame.Angles(k * 9, k * 6, 0)
		core.CFrame = CFrame.new(p)
		if k >= 1 or not rock.Parent then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if not rock.Parent then
		return
	end
	warning:Destroy()
	rock:Destroy()
	core:Destroy()

	local boom = newPart("Blast", Vector3.one * 2, CFrame.new(spot), LAVA_GLOW, Enum.Material.Neon)
	boom.Shape = Enum.PartType.Ball
	boom.CastShadow = false
	fade(boom, 0.45, { Size = Vector3.one * 18, Transparency = 1 })
	HazardService.Blast(spot + Vector3.new(0, 1, 0), 11, 14, 70)
	burningGround(spot)
end

local function eruption()
	announce("ERUPTION!", "Meteors incoming — stay off the red circles!", LAVA)
	local crater = Vector3.new(0, 68, 0)
	for _ = 1, 14 do
		local spot = DropService.RandomSpot()
		if spot then
			task.spawn(meteor, crater + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3)), spot)
		end
		task.wait(rng:NextNumber(0.5, 0.9))
	end
end

-- ── Sky Islands: wind gust ───────────────────────────────────────────────────
local function windGust()
	local a = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local duration, strength = 8, 16
	announce("WIND GUST!", "Hold on tight — the wind is pushing everyone!", Color3.fromRGB(170, 230, 255))
	Remotes.Get("MapEvent"):FireAllClients({ kind = "Wind", dir = dir, duration = duration, strength = strength })
	-- Bots are simulated here, so push them directly.
	local untilT = os.clock() + duration
	while os.clock() < untilT do
		for _, m in ipairs(HazardService.Cats()) do
			if m:GetAttribute("IsBot") then
				local root = m.PrimaryPart :: BasePart
				root.AssemblyLinearVelocity += dir * 2.2
			end
		end
		task.wait(0.1)
	end
end

-- ── Toybox: bouncy-ball stampede ─────────────────────────────────────────────
local BALL_COLORS = { Color3.fromRGB(255, 110, 150), Color3.fromRGB(110, 200, 255), Color3.fromRGB(255, 214, 90), Color3.fromRGB(170, 130, 255), Color3.fromRGB(120, 226, 150) }

local function rollBall(spot: Vector3)
	local a = rng:NextNumber(0, math.pi * 2)
	local dir = Vector3.new(math.cos(a), 0, math.sin(a))
	local d = rng:NextNumber(8, 11)
	local color = BALL_COLORS[rng:NextInteger(1, #BALL_COLORS)]
	local ball = newPart("StampedeBall", Vector3.one * d, CFrame.new(spot), color, Enum.Material.SmoothPlastic)
	ball.Shape = Enum.PartType.Ball
	local stripe = newPart("Stripe", Vector3.new(d * 0.22, d * 1.01, d * 1.01), CFrame.new(spot), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	stripe.Shape = Enum.PartType.Cylinder
	local from, to = spot - dir * 110, spot + dir * 110
	local duration = 4.5
	local axis = dir:Cross(Vector3.yAxis)
	local hit: { [Model]: number } = {}
	local t0 = os.clock()
	while true do
		local t = os.clock() - t0
		local k = math.clamp(t / duration, 0, 1)
		local p = from:Lerp(to, k) + Vector3.new(0, d / 2 + math.abs(math.sin(t * math.pi * 1.6)) * 7, 0)
		local spin = CFrame.fromAxisAngle(axis, -t * 5)
		ball.CFrame = CFrame.new(p) * spin
		stripe.CFrame = CFrame.new(p) * spin * CFrame.Angles(0, math.rad(90), 0)
		for _, m in ipairs(HazardService.Cats()) do
			local root = m.PrimaryPart :: BasePart
			if (root.Position - p).Magnitude < d / 2 + 2 and os.clock() - (hit[m] or 0) > 1 then
				hit[m] = os.clock()
				HazardService.Hit(m, 10, dir * 62 + Vector3.new(0, 38, 0))
			end
		end
		if k >= 1 or not ball.Parent then
			break
		end
		RunService.Heartbeat:Wait()
	end
	ball:Destroy()
	stripe:Destroy()
end

local function stampede()
	announce("BALL STAMPEDE!", "Giant bouncy balls incoming — jump or dash out of the way!", Color3.fromRGB(255, 150, 210))
	for _ = 1, 7 do
		local spot = DropService.RandomSpot()
		if spot then
			task.spawn(rollBall, spot)
		end
		task.wait(rng:NextNumber(0.5, 1.1))
	end
end

local EVENTS: { [string]: () -> () } = {
	Volcano = eruption,
	SkyIslands = windGust,
	Toybox = stampede,
}

function EventService.Start()
	task.spawn(function()
		local wasActive = false
		local nextEvent = 0
		while true do
			task.wait(0.5)
			local active = PlayerService.MatchActive
			local now = os.clock()
			if active and not wasActive then
				nextEvent = now + GameConfig.Events.FirstDelay
			elseif not active and wasActive and holder then
				holder:Destroy()
				holder = nil
			end
			wasActive = active
			if active and now >= nextEvent and #Players:GetPlayers() > 0 then
				nextEvent = now + GameConfig.Events.Interval
				local map = ArenaBuilder.CurrentMap
				local run = map and EVENTS[map.Id]
				if run then
					task.spawn(run)
				end
			end
		end
	end)
end

return EventService
