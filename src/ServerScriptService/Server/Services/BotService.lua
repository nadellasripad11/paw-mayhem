--!strict
-- BotService: fills matches with CPU-controlled bots when player count is low.
-- Bot count = max(0, 6 - realPlayers), so solo/small sessions stay fun.
-- Difficulty is "decent but beatable": reaction delay + aim scatter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Weapons    = require(Shared.Config.Weapons)
local GameConfig = require(Shared.Config.GameConfig)
local CatBuilder = require(Shared.Character.CatBuilder)
local Knockback  = require(Shared.Character.Knockback)
local Remotes    = require(Shared.Net.Remotes)

local WeaponService   = require(script.Parent.WeaponService)
local EconomyService  = require(script.Parent.EconomyService)
local Runtime         = require(script.Parent.Runtime)

local BotService = {}

-- ── difficulty knobs ────────────────────────────────────────────────────────
local AIM_ERROR_DEG    = 8.0   -- extra aim scatter (degrees)
local REACTION_SECS    = 1.0   -- delay before firing at a new target
local BOT_FIRE_INTERVAL = 1.10 -- minimum seconds between shots
local ATTACK_RANGE     = 75    -- studs: stop chasing and start shooting
local CHASE_SPEED      = 18
local PATROL_SPEED     = 12

local BOT_NAMES = {
	"Whiskers-BOT", "Mittens-BOT", "Pounce-BOT",
	"Scratch-BOT",  "Nyan-BOT",    "Fuzz-BOT",
}

-- ── types ───────────────────────────────────────────────────────────────────
type BotState = {
	id:              number,
	name:            string,
	model:           Model,
	humanoid:        Humanoid,
	root:            BasePart,
	team:            string,
	alive:           boolean,
	accumulated:     number,
	lastAttacker:    Player?,
	lastFireAt:      number,
	target:          Player?,
	targetAcquiredAt: number,
}

-- ── module-level state ───────────────────────────────────────────────────────
local bots:          { [number]: BotState } = {}
local modelToId:     { [Model]: number   } = {}
local nextBotId      = 1
local matchActive    = false

-- Set by MatchService.Start so bot kills update the live scoreboard.
BotService.OnBotEliminated = nil :: ((killer: Player, botTeam: string) -> ())?

-- ── helpers ──────────────────────────────────────────────────────────────────
local function getSpawnCFrame(teamId: string): CFrame
	local arena  = Workspace:FindFirstChild("Arena")
	local spawns = arena  and arena:FindFirstChild("Spawns")
	if not spawns then return CFrame.new(0, 30, 0) end
	local candidates = {}
	for _, s in ipairs(spawns:GetChildren()) do
		if s:IsA("BasePart") then
			local tag = s:GetAttribute("Team")
			if tag == nil or tag == teamId then
				table.insert(candidates, s)
			end
		end
	end
	if #candidates == 0 then return CFrame.new(0, 30, 0) end
	return candidates[math.random(1, #candidates)].CFrame + Vector3.new(0, 1.25, 0)
end

local function pickTeam(): string
	local counts = { Blue = 0, Red = 0 }
	for _, p in ipairs(Players:GetPlayers()) do
		local s = Runtime.Get(p)
		if s and s.Team then
			counts[s.Team] = (counts[s.Team] or 0) + 1
		end
	end
	for _, bot in pairs(bots) do
		counts[bot.team] = (counts[bot.team] or 0) + 1
	end
	return counts.Blue <= counts.Red and "Blue" or "Red"
end

local function findNearestEnemy(bot: BotState): (Player?, number)
	local best: Player? = nil
	local bestDist = math.huge
	for _, p in ipairs(Players:GetPlayers()) do
		local s    = Runtime.Get(p)
		local char = p.Character
		local root = char and (char.PrimaryPart :: BasePart?)
		if s and s.Alive and s.Team ~= bot.team and root then
			local d = (root.Position - bot.root.Position).Magnitude
			if d < bestDist then
				bestDist = d
				best = p
			end
		end
	end
	return best, bestDist
end

local function addAimError(dir: Vector3): Vector3
	local spread = math.rad(AIM_ERROR_DEG)
	local up     = math.abs(dir.Unit.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local right  = dir.Unit:Cross(up).Unit
	local realUp = right:Cross(dir.Unit).Unit
	local a = (math.random() - 0.5) * 2 * spread
	local b = (math.random() - 0.5) * 2 * spread
	return (dir.Unit + right * math.tan(a) + realUp * math.tan(b)).Unit
end

-- ── combat ───────────────────────────────────────────────────────────────────
local function botFireAt(bot: BotState, target: Player)
	local now = os.clock()
	if now - bot.lastFireAt < BOT_FIRE_INTERVAL then return end
	local char = target.Character
	local tRoot = char and (char.PrimaryPart :: BasePart?)
	if not tRoot then return end
	bot.lastFireAt = now

	local weapon = Weapons.Get("PawBlaster")
	if not weapon then return end

	local dir = addAimError((tRoot.Position - bot.root.Position).Unit)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { bot.model }
	params.IgnoreWater = true

	local result = Workspace:Raycast(bot.root.Position, dir * weapon.Range, params)
	local hitPos = bot.root.Position + dir * weapon.Range
	if result then
		hitPos = result.Position
		local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
		local victim   = hitModel and Players:GetPlayerFromCharacter(hitModel)
		if victim then
			BotService.DealDamageToPlayer(bot, victim, weapon, dir)
		end
	end

	Remotes.Get("PlayEffect"):FireAllClients({
		kind  = "Tracer",
		from  = bot.root.Position,
		to    = hitPos,
		color = weapon.TrailColor,
	})
end

-- Apply a bot's shot to a real player.
function BotService.DealDamageToPlayer(bot: BotState, victim: Player, weapon: any, dir: Vector3)
	local vState = Runtime.Get(victim)
	if not vState or not vState.Alive then return end
	if os.clock() < (vState.SpawnProtectUntil or 0) then return end

	local vChar = victim.Character
	local vHum  = vChar and vChar:FindFirstChildOfClass("Humanoid")
	local vRoot = vChar and (vChar.PrimaryPart :: BasePart?)
	if not vHum or not vRoot then return end

	local dmg = weapon.Damage
	vState.Accumulated += dmg
	vHum:TakeDamage(dmg * 0.5)
	vState.LastAttackAt = os.clock()

	local dV     = Knockback.ComputeDeltaV(dir, vState.Accumulated, weapon.Knockback, 0.6)
	local impulse = dV * vRoot.AssemblyMass
	WeaponService.ApplyLaunch(victim, vHum, vRoot, impulse)
	vState.StunUntil = os.clock() + GameConfig.Character.LaunchStunSeconds

	Remotes.Get("YouWereHit"):FireClient(victim, {
		from        = bot.name,
		direction   = dir,
		accumulated = vState.Accumulated,
	})
end

-- Apply a player's shot to a bot (called from WeaponService via callback).
function BotService.HandlePlayerHit(shooter: Player, hitModel: Model, weapon: any, dir: Vector3)
	local botId = modelToId[hitModel]
	if not botId then return end
	local bot = bots[botId]
	if not bot or not bot.alive then return end

	bot.accumulated += weapon.Damage
	bot.humanoid:TakeDamage(weapon.Damage * 0.5)
	bot.lastAttacker = shooter

	local dV = Knockback.ComputeDeltaV(dir, bot.accumulated, weapon.Knockback, 1)
	bot.root:ApplyImpulse(dV * bot.root.AssemblyMass)

	Remotes.Get("HitConfirm"):FireClient(shooter, {
		victim      = bot.name,
		damage      = weapon.Damage,
		accumulated = bot.accumulated,
	})
end

-- ── AI loop ──────────────────────────────────────────────────────────────────
local function runBot(bot: BotState)
	while bot.alive and matchActive do
		local target, dist = findNearestEnemy(bot)

		if not target then
			-- Wander
			local wander = bot.root.Position
				+ Vector3.new((math.random()-0.5)*40, 0, (math.random()-0.5)*40)
			bot.humanoid.WalkSpeed = PATROL_SPEED
			bot.humanoid:MoveTo(wander)
			task.wait(2.5 + math.random() * 1.5)
		else
			local tChar = target.Character
			local tRoot = tChar and (tChar.PrimaryPart :: BasePart?)
			if tRoot then
				bot.humanoid.WalkSpeed = dist <= ATTACK_RANGE and PATROL_SPEED or CHASE_SPEED
				bot.humanoid:MoveTo(tRoot.Position)
			end
			-- Track reaction timer per target
			if target ~= bot.target then
				bot.target = target
				bot.targetAcquiredAt = os.clock()
			end
			if dist <= ATTACK_RANGE and os.clock() - bot.targetAcquiredAt >= REACTION_SECS then
				botFireAt(bot, target)
			end
			task.wait(0.15 + math.random() * 0.15)
		end
	end
end

-- ── spawning ─────────────────────────────────────────────────────────────────
local function spawnBot(botId: number, teamId: string, botName: string)
	local model = CatBuilder.Build(nil, botName, { Id = "PawBlaster" })
	model.Name = botName
	model:SetAttribute("IsBot", true)
	model:SetAttribute("Team", teamId)

	local root = model.PrimaryPart :: BasePart
	pcall(function() root:SetNetworkOwner(nil) end)

	-- Team ring (mirrors PlayerService)
	local ring = Instance.new("Part")
	ring.Name        = "TeamRing"
	ring.Shape       = Enum.PartType.Cylinder
	ring.Size        = Vector3.new(0.2, 3.2, 3.2)
	ring.Color       = teamId == "Blue" and Color3.fromRGB(64, 132, 255) or Color3.fromRGB(255, 82, 82)
	ring.Material    = Enum.Material.Neon
	ring.Transparency = 0.4
	ring.CanCollide  = false
	ring.CanQuery    = false
	ring.Massless    = true
	local weld = Instance.new("Weld")
	weld.Part0  = root
	weld.Part1  = ring
	weld.C0     = CFrame.new(0, -1.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	weld.Parent = ring
	ring.Parent = model

	model:PivotTo(getSpawnCFrame(teamId))
	model.Parent = Workspace

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid

	local bot: BotState = {
		id = botId, name = botName, model = model,
		humanoid = humanoid, root = root, team = teamId,
		alive = true, accumulated = 0, lastAttacker = nil,
		lastFireAt = 0, target = nil, targetAcquiredAt = 0,
	}
	bots[botId]      = bot
	modelToId[model] = botId

	-- Elimination handler
	humanoid.Died:Connect(function()
		if not bot.alive then return end
		bot.alive = false
		bots[botId]      = nil
		modelToId[model] = nil

		local killer = bot.lastAttacker
		if killer and Players:FindFirstChild(killer.Name) then
			local kState = Runtime.Ensure(killer)
			kState.MatchElims += 1
			kState.MatchScore += 1
			EconomyService.AddXP(killer, GameConfig.Scoring.EliminationXP)
			EconomyService.AddCoins(killer, GameConfig.Scoring.EliminationCoins)
			EconomyService.AddStat(killer, "Eliminations", 1)
			EconomyService.Push(killer)
			if BotService.OnBotEliminated then
				BotService.OnBotEliminated(killer, teamId)
			end
			Remotes.Get("KillFeed"):FireAllClients({
				killer = killer.DisplayName, killerTeam = kState.Team,
				victim = botName, victimTeam = teamId, ringout = false,
			})
		else
			Remotes.Get("KillFeed"):FireAllClients({
				killer = "—", victim = botName, victimTeam = teamId, ringout = false,
			})
		end

		-- Respawn if match still live
		task.delay(GameConfig.Character.RespawnDelay, function()
			if matchActive then spawnBot(botId, teamId, botName) end
		end)
		task.delay(2, function()
			if model.Parent then model:Destroy() end
		end)
	end)

	-- Kill floor for bots
	local floorConn: RBXScriptConnection
	floorConn = RunService.Heartbeat:Connect(function()
		if not bot.alive then floorConn:Disconnect(); return end
		if root.Position.Y < GameConfig.Character.KillFloorY then
			bot.alive = false
			floorConn:Disconnect()
			humanoid.Health = 0
		end
	end)

	task.spawn(runBot, bot)
end

-- ── public API ───────────────────────────────────────────────────────────────
function BotService.SpawnBots(realPlayerCount: number)
	local botCount = math.max(0, math.min(6, 6 - realPlayerCount))
	if botCount == 0 then return end
	matchActive = true
	for i = 1, botCount do
		local id      = nextBotId; nextBotId += 1
		local teamId  = pickTeam()
		local botName = BOT_NAMES[((i - 1) % #BOT_NAMES) + 1]
		task.delay((i - 1) * 0.3, function()
			spawnBot(id, teamId, botName)
		end)
	end
end

function BotService.DespawnAll()
	matchActive = false
	for _, bot in pairs(bots) do
		bot.alive = false
		modelToId[bot.model] = nil
		if bot.model and bot.model.Parent then
			bot.model:Destroy()
		end
	end
	bots = {}
end

function BotService.Start()
	-- Route player raycasts that hit bot models back here for damage.
	WeaponService.OnBotHit = function(shooter: Player, hitModel: Model, weapon: any, dir: Vector3)
		BotService.HandlePlayerHit(shooter, hitModel, weapon, dir)
	end
end

return BotService
