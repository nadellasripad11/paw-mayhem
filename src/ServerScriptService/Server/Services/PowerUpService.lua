--!strict
-- PowerUpService: periodically spawns readable power-up pickups at arena pads.
-- On touch, grants the toucher a timed effect stored in Runtime state (read by
-- WeaponService and the movement status loop). Server-authoritative.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local GameConfig = require(Shared.Config.GameConfig)
local Progression = require(Shared.Config.Progression)

local EconomyService = require(script.Parent.EconomyService)
local Runtime = require(script.Parent.Runtime)
local PlayerService = require(script.Parent.PlayerService)

local PowerUpService = {}

local activePickups: { [string]: BasePart } = {}
local nextId = 0

local function getPads(): { BasePart }
	local pads = {}
	local arena = Workspace:FindFirstChild("Arena")
	local folder = arena and arena:FindFirstChild("PowerUpPads")
	if folder then
		for _, p in ipairs(folder:GetChildren()) do
			if p:IsA("BasePart") then
				table.insert(pads, p)
			end
		end
	end
	return pads
end

local function grant(player: Player, powerId: string)
	local state = Runtime.Get(player)
	if not state or not state.Alive then
		return
	end
	state.PowerUp = { Id = powerId, Expires = os.clock() + GameConfig.PowerUps.Duration }
	EconomyService.AddStat(player, "PowerupsGrabbed", 1)
	Remotes.Get("PowerUpActive"):FireClient(player, {
		powerId = powerId,
		duration = GameConfig.PowerUps.Duration,
	})
end

local function spawnPickup()
	local pads = getPads()
	if #pads == 0 then
		return
	end
	local pad = pads[math.random(1, #pads)]
	local def = Progression.PowerUps[math.random(1, #Progression.PowerUps)]

	nextId += 1
	local id = "pu_" .. nextId

	local orb = Instance.new("Part")
	orb.Name = id
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.new(2.4, 2.4, 2.4)
	orb.Color = def.Color
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.Position = pad.Position + Vector3.new(0, 3, 0)
	orb:SetAttribute("PowerId", def.Id)

	local light = Instance.new("PointLight")
	light.Color = def.Color
	light.Range = 12
	light.Brightness = 3
	light.Parent = orb

	orb.Parent = Workspace:FindFirstChild("Arena") or Workspace
	activePickups[id] = orb

	Remotes.Get("PowerUpSpawned"):FireAllClients({
		id = id,
		powerId = def.Id,
		position = orb.Position,
		color = def.Color,
	})

	local taken = false
	local conn
	conn = orb.Touched:Connect(function(hit)
		if taken then
			return
		end
		local model = hit:FindFirstAncestorOfClass("Model")
		local player = model and Players:GetPlayerFromCharacter(model)
		if player then
			taken = true
			if conn then
				conn:Disconnect()
			end
			grant(player, def.Id)
			Remotes.Get("PowerUpTaken"):FireAllClients({
				id = id,
				playerName = player.DisplayName,
				powerId = def.Id,
				position = orb.Position,
				color = def.Color,
			})
			activePickups[id] = nil
			orb:Destroy()
		end
	end)

	-- Auto-despawn if untouched.
	task.delay(GameConfig.PowerUps.RespawnAfterPickup + GameConfig.PowerUps.Duration, function()
		if activePickups[id] then
			activePickups[id] = nil
			orb:Destroy()
		end
	end)
end

function PowerUpService.Start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.PowerUps.SpawnInterval)
			if PlayerService.MatchActive then
				spawnPickup()
			end
		end
	end)
end

return PowerUpService
