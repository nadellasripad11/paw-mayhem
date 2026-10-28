--!strict
-- mapfeatureservice: the living bits of each map that need the server. the
-- maps build them (arenakit); this runs them.
--   * volcano lava geysers (tag geyser): they rumble and glow for 2 seconds,
--     then blast anyone standing on them sky-high
--   * rooftops neon billboards (tag billboard): one flickers and buzzes, then
--     surges and knocks back every cat near it
--   * rooftops window-cleaner lifts (tag lift, a prismaticconstraint): ride
--     up and down between a step roof and a high perch
--   * toybox ball pits (tag ballpit): cats inside are hidden (no name tag,
--     bots don't spot them from afar, and they wade slowly)
--   * the golden column: in mayhem mode one swim column glows gold and pays
--     coins every second to anyone riding it
-- geysers and billboards only go off while a match is being played.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Runtime = require(script.Parent.Runtime)
local PlayerService = require(script.Parent.PlayerService)
local HazardService = require(script.Parent.HazardService)
local EconomyService = require(script.Parent.EconomyService)

local MapFeatureService = {}

local rng = Random.new()
local GOLD = Color3.fromRGB(255, 206, 60)
local GOLDEN_COINS = 5 -- per second in the golden column

local function live(inst: Instance): boolean
	return inst.Parent ~= nil and inst:IsDescendantOf(Workspace)
end

local function inBox(part: BasePart, pos: Vector3, extraUp: number?): boolean
	local lp = part.CFrame:PointToObjectSpace(pos)
	local half = part.Size / 2
	return math.abs(lp.X) <= half.X and math.abs(lp.Z) <= half.Z and lp.Y >= -half.Y and lp.Y <= half.Y + (extraUp or 0)
end

-- ── lava geysers ─────────────────────────────────────────────────────────────
local function geyserLoop(vent: BasePart)
	local smoke = vent:FindFirstChild("Smoke", true) :: ParticleEmitter?
	local burst = vent:FindFirstChild("Burst", true) :: ParticleEmitter?
	local rumble = vent:FindFirstChild("Rumble") :: Sound?
	local blast = vent:FindFirstChild("Blast") :: Sound?
	local glow = vent:FindFirstChildOfClass("PointLight")
	local baseColor = vent.Color
	task.wait(rng:NextNumber(3, 10))
	while live(vent) do
		if PlayerService.MatchActive then
			-- warning: smoke, a rumble and the vent glowing brighter.
			if smoke then
				smoke.Enabled = true
			end
			if rumble then
				rumble:Play()
			end
			TweenService:Create(vent, TweenInfo.new(2), { Transparency = 0, Color = Color3.fromRGB(255, 220, 120) }):Play()
			if glow then
				TweenService:Create(glow, TweenInfo.new(2), { Brightness = 2, Range = 22 }):Play()
			end
			task.wait(2)
			if not live(vent) then
				return
			end
			-- blast: a jet of lava and everyone on the vent goes flying.
			if burst then
				burst:Emit(60)
			end
			if blast then
				blast:Play()
			end
			local pos = vent.Position
			local jet = Instance.new("Part")
			jet.Name = "GeyserJet"
			jet.Shape = Enum.PartType.Cylinder
			jet.Size = Vector3.new(4, 4.4, 4.4)
			jet.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			jet.Color = Color3.fromRGB(255, 130, 40)
			jet.Material = Enum.Material.Neon
			jet.Anchored = true
			jet.CanCollide = false
			jet.CanQuery = false
			jet.CanTouch = false
			jet.CastShadow = false
			jet.Parent = vent.Parent
			TweenService:Create(jet, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = Vector3.new(34, 4.4, 4.4), CFrame = CFrame.new(pos + Vector3.new(0, 17, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			}):Play()
			TweenService:Create(jet, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.25), { Transparency = 1 }):Play()
			Debris:AddItem(jet, 1.6)
			for _, m in ipairs(HazardService.Cats()) do
				local off = (m.PrimaryPart :: BasePart).Position - pos
				local flat = Vector3.new(off.X, 0, off.Z)
				if flat.Magnitude < 4.5 and off.Y > -1 and off.Y < 10 then
					local push = flat.Magnitude > 0.1 and flat.Unit * 18 or Vector3.zero
					HazardService.Hit(m, 10, push + Vector3.new(0, 150, 0))
				end
			end
			if smoke then
				smoke.Enabled = false
			end
			TweenService:Create(vent, TweenInfo.new(1.5), { Transparency = 0.35, Color = baseColor }):Play()
			if glow then
				TweenService:Create(glow, TweenInfo.new(1.5), { Brightness = 1, Range = 14 }):Play()
			end
		end
		task.wait(rng:NextNumber(9, 16))
	end
end

-- ── neon billboards ──────────────────────────────────────────────────────────
local function billboardLoop(panel: BasePart)
	local buzz = panel:FindFirstChild("Buzz") :: Sound?
	local zap = panel:FindFirstChild("Zap") :: Sound?
	local sparks = panel:FindFirstChild("Sparks") :: ParticleEmitter?
	local flash = panel:FindFirstChildOfClass("PointLight")
	local baseColor = panel.Color
	task.wait(rng:NextNumber(8, 20))
	while live(panel) do
		if PlayerService.MatchActive then
			-- flicker and buzz...
			if buzz then
				buzz:Play()
			end
			local untilT = os.clock() + 2.5
			local on = true
			while os.clock() < untilT and live(panel) do
				on = not on
				panel.Material = on and Enum.Material.Neon or Enum.Material.SmoothPlastic
				panel.Color = on and baseColor or baseColor:Lerp(Color3.new(0, 0, 0), 0.7)
				task.wait(rng:NextNumber(0.05, 0.16))
			end
			if not live(panel) then
				return
			end
			-- ...then the surge.
			if buzz then
				buzz:Stop()
			end
			if zap then
				zap:Play()
			end
			if sparks then
				sparks:Emit(80)
			end
			if flash then
				flash.Brightness = 2.5
				TweenService:Create(flash, TweenInfo.new(0.6), { Brightness = 0 }):Play()
			end
			local center = panel:GetAttribute("BlastAt")
			if typeof(center) == "Vector3" then
				HazardService.Blast(center, 16, 10, 80)
			end
			-- dark for a moment, then back on.
			panel.Material = Enum.Material.SmoothPlastic
			panel.Color = baseColor:Lerp(Color3.new(0, 0, 0), 0.8)
			task.wait(3)
			if live(panel) then
				panel.Material = Enum.Material.Neon
				panel.Color = baseColor
			end
		end
		task.wait(rng:NextNumber(18, 32))
	end
end

-- ── window-cleaner lifts ─────────────────────────────────────────────────────
local function liftLoop(slider: PrismaticConstraint)
	local deck = slider.Attachment1 and slider.Attachment1.Parent
	if deck and deck:IsA("BasePart") then
		pcall(function()
			deck:SetNetworkOwner(nil)
		end)
	end
	local high = slider.UpperLimit
	local up = false
	while live(slider) do
		task.wait(up and 6 or 5)
		up = not up
		slider.TargetPosition = up and high or 0
	end
end

-- ── each tagged thing gets its loop ──────────────────────────────────────────
local function watch(tag: string, class: string, loop: (any) -> ())
	local function add(inst: Instance)
		if inst:IsA(class) and live(inst) then
			task.spawn(loop, inst)
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst)
		-- (after the map builder has finished setting it up.)
		task.defer(add, inst)
	end)
end

-- ── ball pits + the golden column (checked a few times a second) ────────────
local hidden: { [Model]: boolean } = {}
local golden: BasePart? = nil
local paidAt = 0

local function updatePits()
	local pits = {}
	for _, p in ipairs(CollectionService:GetTagged("BallPit")) do
		if p:IsA("BasePart") and live(p) then
			table.insert(pits, p)
		end
	end
	local now: { [Model]: boolean } = {}
	if #pits > 0 then
		for _, m in ipairs(HazardService.Cats()) do
			local pos = (m.PrimaryPart :: BasePart).Position
			for _, pit in ipairs(pits) do
				if inBox(pit, pos) then
					now[m] = true
					break
				end
			end
		end
	end
	for m in pairs(hidden) do
		if not now[m] then
			m:SetAttribute("Hidden", nil)
		end
	end
	for m in pairs(now) do
		if not hidden[m] then
			m:SetAttribute("Hidden", true)
		end
	end
	hidden = now
end

local function swimZones(): { BasePart }
	local out = {}
	local arena = Workspace:FindFirstChild("Arena")
	for _, z in ipairs(CollectionService:GetTagged("SwimZone")) do
		if z:IsA("BasePart") and arena and z:IsDescendantOf(arena) then
			table.insert(out, z)
		end
	end
	return out
end

local function updateGolden()
	local want = Runtime.Mayhem and PlayerService.MatchActive
	local g = golden
	if not want then
		if g then
			g:SetAttribute("Golden", nil)
			golden = nil
		end
		return
	end
	if not g or not live(g) then
		local zones = swimZones()
		if #zones == 0 then
			return
		end
		g = zones[rng:NextInteger(1, #zones)]
		golden = g
		g:SetAttribute("Golden", true)
		Remotes.Get("Announce"):FireAllClients({ title = "GOLDEN COLUMN!", sub = "Ride the glowing column for bonus coins", color = GOLD })
	end
	local zone = g :: BasePart
	if os.clock() - paidAt < 1 then
		return
	end
	paidAt = os.clock()
	for _, p in ipairs(Players:GetPlayers()) do
		local s = Runtime.Get(p)
		local root = p.Character and p.Character.PrimaryPart
		if s and s.Alive and s.Context == "Match" and root and inBox(zone, root.Position) then
			EconomyService.AddCoins(p, GOLDEN_COINS)
			EconomyService.Push(p)
		end
	end
end

function MapFeatureService.Start()
	watch("Geyser", "BasePart", geyserLoop)
	watch("Billboard", "BasePart", billboardLoop)
	watch("Lift", "PrismaticConstraint", liftLoop)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		updatePits()
		updateGolden()
	end)
end

return MapFeatureService
