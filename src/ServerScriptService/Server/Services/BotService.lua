--!strict
-- BotService: fills matches with CPU-controlled bots when player count is low.
-- Bot count = max(0, 6 - realPlayers), so solo/small sessions stay fun.
-- Difficulty is "decent but beatable": reaction delay + aim scatter.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local CollectionService = game:GetService("CollectionService")

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
	"Biscuit-BOT",  "Pickle-BOT",
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
	target:          Model?,
	targetAcquiredAt: number,
	lastBot:         any?,
	path:            any,
	waypoints:       { PathWaypoint }?,
	wpIndex:         number,
	goal:            Vector3,
	pathAt:          number,
	strafeSign:      number,
	strafeFlipAt:    number,
}

-- ── module-level state ───────────────────────────────────────────────────────
local bots:          { [number]: BotState } = {}
local modelToId:     { [Model]: number   } = {}
local nextBotId      = 1
-- Bots reserved but not yet in the world (staggered spawn or respawning).
local pending:       { [number]: { team: string, name: string } } = {}
-- Total cats per match; bots fill whatever real players don't.
local TARGET_CATS    = 8
-- Eliminations each bot has this match (by name, so respawns keep them).
local botElims:      { [string]: { elims: number, team: string } } = {}
local matchActive    = false

-- Set by MatchService.Start so bot kills update the live scoreboard.
BotService.OnBotEliminated = nil :: ((killer: Player, botTeam: string) -> ())?
-- Set by MatchService: a bot eliminated an enemy bot, so its team scores.
BotService.OnTeamPoint = nil :: ((teamId: string) -> ())?

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
	for _, p in pairs(pending) do
		counts[p.team] = (counts[p.team] or 0) + 1
	end
	return counts.Blue <= counts.Red and "Blue" or "Red"
end

-- Nearest living enemy cat — a real player or an enemy bot — within range.
local ENGAGE_RANGE = 150
local function findNearestEnemy(bot: BotState): (Model?, number)
	local best: Model? = nil
	local bestDist = ENGAGE_RANGE
	for _, p in ipairs(Players:GetPlayers()) do
		local s    = Runtime.Get(p)
		local char = p.Character
		local root = char and (char.PrimaryPart :: BasePart?)
		if s and s.Alive and s.Team ~= bot.team and root and char then
			local d = (root.Position - bot.root.Position).Magnitude
			if d < bestDist then
				bestDist = d
				best = char
			end
		end
	end
	for _, other in pairs(bots) do
		if other.alive and other.team ~= bot.team then
			local d = (other.root.Position - bot.root.Position).Magnitude
			if d < bestDist then
				bestDist = d
				best = other.model
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

-- A bot's shot landing on another (enemy) bot.
local function botHitBot(shooter: BotState, victim: BotState, weapon: any, dir: Vector3)
	if not victim.alive or victim.team == shooter.team then return end
	victim.accumulated += weapon.Damage
	victim.humanoid:TakeDamage(weapon.Damage * 0.5)
	victim.lastAttacker = nil
	victim.lastBot = shooter
	victim.model:SetAttribute("Fluff", math.floor(victim.accumulated))
	local mayhem = Runtime.Mayhem and GameConfig.Mayhem.KnockbackMult or 1
	local dV = Knockback.ComputeDeltaV(dir, victim.accumulated, weapon.Knockback, 0.6 * mayhem)
	victim.root:ApplyImpulse(dV * victim.root.AssemblyMass)
end

-- ── combat ───────────────────────────────────────────────────────────────────
local function botFireAt(bot: BotState, target: Model)
	local now = os.clock()
	if now - bot.lastFireAt < BOT_FIRE_INTERVAL then return end
	local tRoot = target.PrimaryPart
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
		elseif hitModel and modelToId[hitModel] then
			local other = bots[modelToId[hitModel]]
			if other then
				botHitBot(bot, other, weapon, dir)
			end
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
	vState.LastBot = { name = bot.name, team = bot.team }
	vState.LastBotAt = os.clock()
	vState.Accumulated += dmg
	vHum:TakeDamage(dmg * 0.5)
	vState.LastAttackAt = os.clock()

	local mayhem = Runtime.Mayhem and GameConfig.Mayhem.KnockbackMult or 1
	local dV     = Knockback.ComputeDeltaV(dir, vState.Accumulated, weapon.Knockback, 0.6 * mayhem)
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
	bot.lastBot = nil
	bot.model:SetAttribute("Fluff", math.floor(bot.accumulated))

	local mayhem = Runtime.Mayhem and GameConfig.Mayhem.KnockbackMult or 1
	local dV = Knockback.ComputeDeltaV(dir, bot.accumulated, weapon.Knockback, mayhem)
	bot.root:ApplyImpulse(dV * bot.root.AssemblyMass)

	Remotes.Get("HitConfirm"):FireClient(shooter, {
		victim      = bot.name,
		damage      = weapon.Damage,
		accumulated = bot.accumulated,
		position    = bot.root.Position,
	})
end

-- Hazards (meteors, stampede balls, burning ground) hitting a bot.
function BotService.EnvironmentHit(model: Model, damage: number, dV: Vector3): boolean
	local botId = modelToId[model]
	local bot = botId and bots[botId]
	if not bot or not bot.alive then return false end
	bot.accumulated += damage
	bot.humanoid:TakeDamage(damage * 0.5)
	bot.model:SetAttribute("Fluff", math.floor(bot.accumulated))
	if dV.Magnitude > 0 then
		bot.root:ApplyImpulse(dV * bot.root.AssemblyMass)
	end
	return true
end

-- ── AI loop ──────────────────────────────────────────────────────────────────
-- Bots path-find across the islands (walkways included) instead of walking in
-- straight lines, which used to march them off the edge within seconds.
local function groundParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = CollectionService:GetTagged(CatBuilder.Tag)
	return params
end

-- Is there solid ground a few studs ahead in `dir`?
local function groundAhead(bot: BotState, dir: Vector3): boolean
	local probe = bot.root.Position + dir * 4 + Vector3.new(0, 3, 0)
	return Workspace:Raycast(probe, Vector3.new(0, -30, 0), groundParams()) ~= nil
end

-- Step toward `goal`, but never off a ledge.
local function safeStep(bot: BotState, goal: Vector3)
	local flat = Vector3.new(goal.X - bot.root.Position.X, 0, goal.Z - bot.root.Position.Z)
	if flat.Magnitude < 1 then
		bot.humanoid:MoveTo(bot.root.Position)
		return
	end
	local dir = flat.Unit
	if groundAhead(bot, dir) then
		bot.humanoid:MoveTo(bot.root.Position + dir * math.min(flat.Magnitude, 8))
	else
		bot.humanoid:MoveTo(bot.root.Position)
	end
end

local function computePath(bot: BotState, goal: Vector3)
	bot.pathAt = os.clock()
	bot.goal = goal
	local path = bot.path
	local ok = pcall(function()
		path:ComputeAsync(bot.root.Position, goal)
	end)
	if ok and path.Status == Enum.PathStatus.Success then
		bot.waypoints = path:GetWaypoints()
		bot.wpIndex = 2
	else
		bot.waypoints = nil
	end
end

-- Walk the current path; false once it's finished or missing.
local function followPath(bot: BotState): boolean
	local wps = bot.waypoints
	if not wps then return false end
	local wp = wps[bot.wpIndex]
	if not wp then
		bot.waypoints = nil
		return false
	end
	local off = wp.Position - bot.root.Position
	if Vector3.new(off.X, 0, off.Z).Magnitude < 2.5 then
		bot.wpIndex += 1
		wp = wps[bot.wpIndex]
		if not wp then
			bot.waypoints = nil
			return false
		end
	end
	if wp.Action == Enum.PathWaypointAction.Jump then
		bot.humanoid.Jump = true
	end
	bot.humanoid:MoveTo(wp.Position)
	return true
end

-- A random spot on one of the playable island floors.
local function randomFloorPoint(): Vector3?
	local floors = CollectionService:GetTagged("DropZone")
	if #floors == 0 then return nil end
	local f = floors[math.random(1, #floors)] :: BasePart
	local r = math.min(f.Size.X, f.Size.Z) * 0.3
	local a = math.random() * math.pi * 2
	return f.Position + Vector3.new(math.cos(a) * r * math.random(), f.Size.Y / 2 + 2, math.sin(a) * r * math.random())
end

local function runBot(bot: BotState)
	bot.path = PathfindingService:CreatePath({ AgentRadius = 1.6, AgentHeight = 3.6, AgentCanJump = true, WaypointSpacing = 5 })
	bot.strafeSign = math.random() < 0.5 and -1 or 1
	bot.strafeFlipAt = 0
	while bot.alive and matchActive do
		local now = os.clock()
		local target, dist = findNearestEnemy(bot)
		local tRoot = target and target.PrimaryPart
		if target and tRoot then
			if target ~= bot.target then
				bot.target = target
				bot.targetAcquiredAt = now
			end
			if dist > 24 then
				-- Chase along a path, refreshed as the target moves.
				bot.humanoid.WalkSpeed = CHASE_SPEED
				if not bot.waypoints or now - bot.pathAt > 1.2 or (bot.goal - tRoot.Position).Magnitude > 10 then
					computePath(bot, tRoot.Position)
				end
				if not followPath(bot) then
					safeStep(bot, tRoot.Position)
				end
			else
				-- In range: strafe side to side instead of standing still.
				bot.waypoints = nil
				bot.humanoid.WalkSpeed = PATROL_SPEED
				if now > bot.strafeFlipAt then
					bot.strafeSign = -bot.strafeSign
					bot.strafeFlipAt = now + 1 + math.random() * 1.5
				end
				local to = Vector3.new(tRoot.Position.X - bot.root.Position.X, 0, tRoot.Position.Z - bot.root.Position.Z)
				local side = to.Magnitude > 0.1 and Vector3.new(-to.Z, 0, to.X).Unit * bot.strafeSign or Vector3.zero
				safeStep(bot, bot.root.Position + side * 6)
			end
			if dist <= ATTACK_RANGE and now - bot.targetAcquiredAt >= REACTION_SECS then
				botFireAt(bot, target)
			end
			task.wait(0.2 + math.random() * 0.1)
		else
			bot.target = nil
			bot.humanoid.WalkSpeed = PATROL_SPEED
			if not bot.waypoints then
				local p = randomFloorPoint()
				if p then
					computePath(bot, p)
				end
			end
			if not followPath(bot) then
				task.wait(0.8)
			end
			task.wait(0.25)
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
	-- The server simulates bots (ownership can only be set once parented).
	pcall(function() root:SetNetworkOwner(nil) end)

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid

	local bot: BotState = {
		id = botId, name = botName, model = model,
		humanoid = humanoid, root = root, team = teamId,
		alive = true, accumulated = 0, lastAttacker = nil,
		lastFireAt = 0, target = nil, targetAcquiredAt = 0,
		lastBot = nil, path = nil, waypoints = nil, wpIndex = 1,
		goal = root.Position, pathAt = 0, strafeSign = 1, strafeFlipAt = 0,
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
			if killer:GetAttribute("TrailPack") then
				Remotes.Get("PlayEffect"):FireAllClients({ kind = "Confetti", position = root.Position })
			end
			if BotService.OnBotEliminated then
				BotService.OnBotEliminated(killer, teamId)
			end
			Remotes.Get("KillFeed"):FireAllClients({
				killer = killer.DisplayName, killerTeam = kState.Team,
				victim = botName, victimTeam = teamId, ringout = false,
			})
		elseif bot.lastBot and bot.lastBot.team ~= teamId then
			local kb = bot.lastBot
			BotService.CreditKill(kb.name, kb.team)
			if BotService.OnTeamPoint then
				BotService.OnTeamPoint(kb.team)
			end
			Remotes.Get("KillFeed"):FireAllClients({
				killer = kb.name, killerTeam = kb.team,
				victim = botName, victimTeam = teamId, ringout = false,
			})
		else
			Remotes.Get("KillFeed"):FireAllClients({
				killer = "—", victim = botName, victimTeam = teamId, ringout = false,
			})
		end

		-- Respawn if match still live
		pending[botId] = { team = teamId, name = botName }
		task.delay(GameConfig.Character.RespawnDelay, function()
			if matchActive and pending[botId] then
				pending[botId] = nil
				spawnBot(botId, teamId, botName)
			end
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
			-- Let the Died handler run normally so the bot respawns.
			floorConn:Disconnect()
			humanoid.Health = 0
		end
	end)

	task.spawn(runBot, bot)
end

-- ── public API ───────────────────────────────────────────────────────────────
local function usedNames(): { [string]: boolean }
	local used = {}
	for _, b in pairs(bots) do used[b.name] = true end
	for _, p in pairs(pending) do used[p.name] = true end
	return used
end

-- Keep (real players + bots) at TARGET_CATS: add bots to the smaller team
-- when players leave, remove them from the bigger team when players join.
function BotService.Rebalance(realPlayerCount: number)
	if not matchActive then return end
	local want = math.max(0, TARGET_CATS - realPlayerCount)
	local have = 0
	for _ in pairs(bots) do have += 1 end
	for _ in pairs(pending) do have += 1 end

	local stagger = 0
	while have < want do
		local used = usedNames()
		local name = "Kitty-BOT"
		for _, n in ipairs(BOT_NAMES) do
			if not used[n] then name = n; break end
		end
		local id = nextBotId; nextBotId += 1
		local teamId = pickTeam()
		pending[id] = { team = teamId, name = name }
		task.delay(stagger, function()
			if matchActive and pending[id] then
				pending[id] = nil
				spawnBot(id, teamId, name)
			end
		end)
		stagger += 0.3
		have += 1
	end

	while have > want do
		-- Drop one from whichever team is bigger (a respawning bot first).
		local counts = { Blue = 0, Red = 0 }
		for _, p in ipairs(Players:GetPlayers()) do
			local st = Runtime.Get(p)
			if st and st.Team then counts[st.Team] = (counts[st.Team] or 0) + 1 end
		end
		for _, b in pairs(bots) do counts[b.team] += 1 end
		for _, p in pairs(pending) do counts[p.team] += 1 end
		local big = counts.Blue >= counts.Red and "Blue" or "Red"
		local removed = false
		for id, p in pairs(pending) do
			if p.team == big then pending[id] = nil; removed = true; break end
		end
		if not removed then
			for id, b in pairs(bots) do
				if b.team == big then
					b.alive = false
					bots[id] = nil
					modelToId[b.model] = nil
					if b.model.Parent then b.model:Destroy() end
					removed = true
					break
				end
			end
		end
		if not removed then break end
		have -= 1
	end
end

-- A bot eliminated someone: count it for the scoreboard / podium.
function BotService.CreditKill(name: string, team: string)
	local e = botElims[name]
	if not e then
		e = { elims = 0, team = team }
		botElims[name] = e
	end
	e.elims += 1
	e.team = team
end

-- Scoreboard rows for every bot that played this match.
function BotService.Board(): { any }
	local rows = {}
	local seen = {}
	for _, b in pairs(bots) do
		seen[b.name] = b.team
	end
	for _, p in pairs(pending) do
		seen[p.name] = p.team
	end
	for name, e in pairs(botElims) do
		seen[name] = seen[name] or e.team
	end
	for name, team in pairs(seen) do
		local e = botElims[name]
		table.insert(rows, { Name = name, Display = name, Team = team, Elims = e and e.elims or 0, Score = e and e.elims or 0, IsBot = true })
	end
	return rows
end

function BotService.SpawnBots(realPlayerCount: number)
	botElims = {}
	matchActive = true
	BotService.Rebalance(realPlayerCount)
end

function BotService.DespawnAll()
	matchActive = false
	pending = {}
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
