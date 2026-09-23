--!strict
-- DropService: sky supply crates and fish snacks during a match.
--   * A crate parachutes onto a random playable island every ~30s (every 8s
--     in Mayhem Mode). A golden light beam and ring mark the landing spot so
--     players race for it; the first cat to reach it gets a random reward: a
--     legendary blaster for the rest of that life, Overdrive, a full heal plus
--     shield, or a bag of coins.
--   * Fish snacks pop up around the map; eating one heals and sheds some
--     knockback damage.
-- Pickups are checked by distance on the server (reliable, no Touched spam).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local GameConfig = require(Shared.Config.GameConfig)
local Weapons = require(Shared.Config.Weapons)
local CatBuilder = require(Shared.Character.CatBuilder)

local Runtime = require(script.Parent.Runtime)
local PlayerService = require(script.Parent.PlayerService)
local EconomyService = require(script.Parent.EconomyService)
local PowerUpService = require(script.Parent.PowerUpService)

local DropService = {}

local GOLD = Color3.fromRGB(255, 204, 64)
local WOOD = Color3.fromRGB(156, 106, 62)
local WOOD_DARK = Color3.fromRGB(98, 64, 40)
local IRON = Color3.fromRGB(62, 64, 76)

local rng = Random.new()
local holder: Folder? = nil
local activeSnacks = 0

local function folder(): Folder
	if not holder or not holder.Parent then
		local f = Instance.new("Folder")
		f.Name = "Drops"
		f.Parent = Workspace
		holder = f
	end
	return holder :: Folder
end

local function newPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, parent: Instance): Part
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
	p.Parent = parent
	return p
end

local function oval(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, parent: Instance): Part
	local p = newPart(name, size, cf, color, material, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

-- Flat disc lying on the ground (cylinder axis rolled upright).
local function disc(name: string, diameter: number, thickness: number, pos: Vector3, color: Color3, parent: Instance): Part
	local p = newPart(name, Vector3.new(thickness, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.Material.Neon, parent)
	p.Shape = Enum.PartType.Cylinder
	p.CastShadow = false
	return p
end

-- Weld every other part of `model` to `root` so moving the anchored root
-- carries the whole thing.
local function rig(model: Model, root: BasePart)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			p.Anchored = false
			p.Massless = true
			local w = Instance.new("Weld")
			w.Part0 = root
			w.Part1 = p
			w.C0 = root.CFrame:ToObjectSpace(p.CFrame)
			w.Parent = p
		end
	end
end

-- A random walkable spot on a playable island, away from team spawns and
-- never on a roof or prop.
function DropService.RandomSpot(): Vector3?
	local zones = {}
	for _, z in ipairs(CollectionService:GetTagged("DropZone")) do
		if z:IsA("BasePart") and z:IsDescendantOf(Workspace) then
			table.insert(zones, z)
		end
	end
	local arena = Workspace:FindFirstChild("Arena")
	if #zones == 0 or not arena then
		return nil
	end
	local spawns = {}
	local spawnFolder = arena:FindFirstChild("Spawns")
	if spawnFolder then
		for _, s in ipairs(spawnFolder:GetChildren()) do
			if s:IsA("BasePart") then
				table.insert(spawns, s.Position)
			end
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { arena }
	params.RespectCanCollide = true
	for _ = 1, 24 do
		local z = zones[rng:NextInteger(1, #zones)]
		-- Floor discs: diameter is Size.Y, thickness (vertical) is Size.X.
		local r = z.Size.Y / 2 * 0.72
		local a, d = rng:NextNumber(0, math.pi * 2), math.sqrt(rng:NextNumber()) * r
		local top = z.Position.Y + z.Size.X / 2
		local p = Vector3.new(z.Position.X + math.cos(a) * d, top, z.Position.Z + math.sin(a) * d)
		local clear = true
		for _, s in ipairs(spawns) do
			if Vector3.new(s.X - p.X, 0, s.Z - p.Z).Magnitude < 14 then
				clear = false
				break
			end
		end
		if clear then
			local hit = Workspace:Raycast(p + Vector3.new(0, 40, 0), Vector3.new(0, -60, 0), params)
			if hit and math.abs(hit.Position.Y - top) < 2.5 then
				return hit.Position
			end
		end
	end
	return nil
end

local function announce(title: string, sub: string?, color: Color3?, small: boolean?)
	Remotes.Get("Announce"):FireAllClients({ title = title, sub = sub, color = color, small = small })
end

-- Nearest live player (not bot) within reach of `pos`.
local function grabber(pos: Vector3, radius: number): Player?
	for _, player in ipairs(Players:GetPlayers()) do
		local s = Runtime.Get(player)
		local root = player.Character and player.Character.PrimaryPart
		if s and s.Alive and root then
			local off = root.Position - pos
			if Vector3.new(off.X, 0, off.Z).Magnitude <= radius and math.abs(off.Y) < 6 then
				return player
			end
		end
	end
	return nil
end

-- ── rewards ──────────────────────────────────────────────────────────────────
local function rollReward(): string
	local total = 0
	for _, w in pairs(GameConfig.Drops.Rewards) do
		total += w
	end
	local pick = rng:NextNumber(0, total)
	for id, w in pairs(GameConfig.Drops.Rewards) do
		pick -= w
		if pick <= 0 then
			return id
		end
	end
	return "Coins"
end

local function giveReward(player: Player): string
	local cfg = GameConfig.Drops
	local s = Runtime.Get(player)
	local char = player.Character
	local kind = rollReward()
	if kind == "Weapon" and s and char then
		local id = cfg.LegendaryWeapons[rng:NextInteger(1, #cfg.LegendaryWeapons)]
		local w = Weapons.Get(id)
		s.WeaponOverride = id
		char:SetAttribute("WeaponOverride", id)
		CatBuilder.SetBlaster(char, { Id = id })
		return string.upper(w and w.Name or id)
	elseif kind == "Overdrive" then
		PowerUpService.Grant(player, "Overdrive", cfg.OverdriveSeconds)
		return "OVERDRIVE"
	elseif kind == "Heal" and s and char then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum.Health = hum.MaxHealth
		end
		s.Accumulated = math.max(0, s.Accumulated - 60)
		PowerUpService.Grant(player, "Shield", cfg.ShieldSeconds)
		return "FULL HEAL + SHIELD"
	end
	local coins = rng:NextInteger(cfg.CoinsMin, cfg.CoinsMax)
	EconomyService.AddCoins(player, coins)
	EconomyService.Push(player)
	return tostring(coins) .. " COINS"
end

-- ── supply crate ─────────────────────────────────────────────────────────────
local function buildCrate(parent: Instance, at: CFrame): (Model, BasePart, Model)
	local crate = Instance.new("Model")
	crate.Name = "SupplyCrate"
	local root = newPart("CrateBox", Vector3.new(3.2, 3.2, 3.2), at, WOOD, Enum.Material.WoodPlanks, crate)
	crate.PrimaryPart = root
	for _, x in ipairs({ -1.55, 1.55 }) do
		for _, z in ipairs({ -1.55, 1.55 }) do
			newPart("Corner", Vector3.new(0.35, 3.3, 0.35), at * CFrame.new(x, 0, z), IRON, Enum.Material.Metal, crate)
		end
	end
	for _, y in ipairs({ -1.1, 1.1 }) do
		local band = newPart("Band", Vector3.new(3.34, 0.32, 3.34), at * CFrame.new(0, y, 0), GOLD, Enum.Material.Neon, crate)
		band.CastShadow = false
	end
	newPart("Lid", Vector3.new(3.4, 0.3, 3.4), at * CFrame.new(0, 1.7, 0), WOOD_DARK, Enum.Material.WoodPlanks, crate)
	local star = newPart("Emblem", Vector3.new(1.2, 1.2, 0.1), at * CFrame.new(0, 0, -1.62) * CFrame.Angles(0, 0, math.rad(45)), GOLD, Enum.Material.Neon, crate)
	star.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = GOLD
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = root
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(GOLD)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(0.8, 1.4)
	sparkle.Speed = NumberRange.new(2, 5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Rate = 12
	sparkle.Parent = root

	-- Parachute: striped canopy on four lines.
	local chute = Instance.new("Model")
	chute.Name = "Parachute"
	local canopyCF = at * CFrame.new(0, 7.2, 0)
	oval("Canopy", Vector3.new(10, 4, 10), canopyCF, Color3.fromRGB(255, 96, 96), Enum.Material.Fabric, chute)
	oval("CanopyStripe", Vector3.new(4, 4.15, 10.1), canopyCF, Color3.fromRGB(250, 248, 240), Enum.Material.Fabric, chute)
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			local a = (at * CFrame.new(x * 1.4, 1.7, z * 1.4)).Position
			local b = (canopyCF * CFrame.new(x * 4, -0.6, z * 4)).Position
			newPart("Line", Vector3.new(0.08, 0.08, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(230, 230, 230), nil, chute)
		end
	end
	chute.Parent = crate
	crate.Parent = parent
	rig(crate, root)
	return crate, root, chute
end

local function dropCrate()
	local spot = DropService.RandomSpot()
	if not spot then
		return
	end
	local cfg = GameConfig.Drops
	local group = Instance.new("Folder")
	group.Name = "SupplyDrop"
	group.Parent = folder()

	-- Landing marker: a tall golden beam and a ring counting down.
	local beam = newPart("Beacon", Vector3.new(cfg.DropHeight, 1.6, 1.6), CFrame.new(spot + Vector3.new(0, cfg.DropHeight / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), GOLD, Enum.Material.Neon, group)
	beam.Shape = Enum.PartType.Cylinder
	beam.Transparency = 0.55
	beam.CastShadow = false
	local ring = disc("LandingRing", 10, 0.2, spot + Vector3.new(0, 0.1, 0), GOLD, group)
	ring.Transparency = 0.35
	local tagGui = Instance.new("BillboardGui")
	tagGui.Size = UDim2.fromOffset(160, 46)
	tagGui.StudsOffset = Vector3.new(0, 4, 0)
	tagGui.AlwaysOnTop = true
	tagGui.MaxDistance = 400
	tagGui.Parent = ring
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.TextStrokeTransparency = 0.3
	label.Text = "SUPPLY DROP"
	label.Parent = tagGui

	announce("SUPPLY DROP INCOMING", "Follow the golden beam!", GOLD, true)

	local crate, root, chute = buildCrate(group, CFrame.new(spot + Vector3.new(0, cfg.DropHeight, 0)))
	local landAt = CFrame.new(spot + Vector3.new(0, 1.6, 0))
	local start = root.CFrame
	local t0 = os.clock()
	while true do
		local k = math.clamp((os.clock() - t0) / cfg.FallTime, 0, 1)
		local sway = math.sin(os.clock() * 1.7) * 0.12 * (1 - k)
		root.CFrame = start:Lerp(landAt, k) * CFrame.Angles(0, os.clock() * 0.4, sway)
		label.Text = k < 1 and ("DROP IN " .. math.ceil(cfg.FallTime * (1 - k))) or "SUPPLY DROP"
		if k >= 1 or not group.Parent then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if not group.Parent then
		return
	end
	root.CFrame = landAt
	chute:Destroy()
	label.Text = "SUPPLY DROP"

	local expires = os.clock() + cfg.Lifetime
	while group.Parent and os.clock() < expires do
		local player = grabber(spot, cfg.GrabRadius)
		if player then
			local got = giveReward(player)
			announce("SUPPLY DROP GRABBED", player.DisplayName .. " got " .. got, GOLD, true)
			Remotes.Get("PlayEffect"):FireAllClients({ kind = "Burst", position = spot + Vector3.new(0, 2, 0), color = GOLD })
			break
		end
		task.wait(0.1)
	end
	crate:Destroy()
	group:Destroy()
end

-- ── fish snacks ──────────────────────────────────────────────────────────────
local function spawnSnack()
	local spot = DropService.RandomSpot()
	if not spot then
		return
	end
	activeSnacks += 1
	local cfg = GameConfig.Snacks
	local snack = Instance.new("Model")
	snack.Name = "FishSnack"
	local at = CFrame.new(spot + Vector3.new(0, 1.6, 0))
	local body = oval("Fish", Vector3.new(1.8, 0.95, 0.55), at, Color3.fromRGB(255, 150, 70), nil, snack)
	snack.PrimaryPart = body
	oval("Belly", Vector3.new(1.3, 0.5, 0.5), at * CFrame.new(0, -0.18, 0), Color3.fromRGB(255, 226, 180), nil, snack)
	for _, side in ipairs({ -1, 1 }) do
		local tail = Instance.new("WedgePart")
		tail.Size = Vector3.new(0.15, 0.55, 0.6)
		tail.Color = Color3.fromRGB(255, 120, 60)
		tail.Anchored = true
		tail.CanCollide = false
		tail.CanQuery = false
		tail.CFrame = at * CFrame.new(1.05, side * 0.25, 0) * CFrame.Angles(math.rad(side > 0 and 0 or 180), math.rad(90), 0)
		tail.Parent = snack
	end
	for _, z in ipairs({ -0.26, 0.26 }) do
		oval("Eye", Vector3.new(0.2, 0.2, 0.06), at * CFrame.new(-0.55, 0.12, z), Color3.fromRGB(30, 26, 36), nil, snack)
	end
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 190, 120)
	glow.Range = 8
	glow.Parent = body
	snack.Parent = folder()
	rig(snack, body)
	disc("SnackRing", 3.6, 0.15, spot + Vector3.new(0, 0.08, 0), Color3.fromRGB(110, 230, 140), snack).Transparency = 0.45

	task.spawn(function()
		local t0 = os.clock()
		while snack.Parent do
			local t = os.clock() - t0
			body.CFrame = at * CFrame.new(0, math.sin(t * 2.5) * 0.3, 0) * CFrame.Angles(0, t * 1.8, 0)
			local player = grabber(spot, cfg.GrabRadius)
			if player then
				local s = Runtime.Get(player)
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if s and hum then
					hum.Health = math.min(hum.MaxHealth, hum.Health + cfg.Heal)
					s.Accumulated = math.max(0, s.Accumulated - cfg.FluffCut)
				end
				Remotes.Get("Notify"):FireClient(player, { text = "Fish snack!  +" .. cfg.Heal .. " HP", kind = "success" })
				break
			end
			task.wait(0.1)
		end
		snack:Destroy()
		activeSnacks -= 1
	end)
end

function DropService.Clear()
	if holder then
		holder:Destroy()
		holder = nil
	end
	activeSnacks = 0
end

function DropService.Start()
	task.spawn(function()
		local wasActive = false
		local nextCrate, nextSnack = 0, 0
		while true do
			task.wait(0.5)
			local active = PlayerService.MatchActive
			local now = os.clock()
			if active and not wasActive then
				nextCrate = now + GameConfig.Drops.FirstDelay
				nextSnack = now + GameConfig.Snacks.Interval * 0.5
			elseif not active and wasActive then
				DropService.Clear()
			end
			wasActive = active
			if active then
				if now >= nextCrate then
					local cfg = GameConfig.Drops
					nextCrate = now + (Runtime.Mayhem and cfg.MayhemInterval or cfg.Interval + rng:NextNumber(-cfg.IntervalJitter, cfg.IntervalJitter))
					task.spawn(dropCrate)
				end
				if now >= nextSnack then
					nextSnack = now + GameConfig.Snacks.Interval
					if activeSnacks < GameConfig.Snacks.MaxActive then
						spawnSnack()
					end
				end
			end
		end
	end)
end

return DropService
