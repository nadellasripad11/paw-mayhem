--!strict
-- BotService: fills matches with CPU-controlled bots so every match has
-- TARGET_CATS cats. Each bot rolls its own skill and blaster, keeps to that
-- blaster's range, only shoots what it can see (flanking round cover
-- otherwise), faces its target while strafing, dodges after being hit, goes
-- for fish snacks when hurt, and gets itself unstuck.

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
local SeasonService   = require(script.Parent.SeasonService)
local DropService     = require(script.Parent.DropService)
local PlayerService   = require(script.Parent.PlayerService)
local FlagService     = require(script.Parent.FlagService)

local BotService = {}

-- ── difficulty knobs ────────────────────────────────────────────────────────
-- Every bot rolls a skill (0 = rookie, 1 = sharp) that sets its aim scatter,
-- reaction time and trigger speed, so a lobby has a mix of easy and tougher
-- bots. Still beatable: no bot ever aims perfectly.
local SKILL_MIN, SKILL_MAX = 0.3, 0.85
local AIM_ERROR_DEG    = { 9.5, 3.5 }  -- scatter at skill 0 / 1 (degrees)
local REACTION_SECS    = { 0.85, 0.3 } -- delay before firing at a new target
local FIRE_DELAY       = { 0.95, 0.4 } -- minimum seconds between shots (weapon may be slower)
local CHASE_SPEED      = 20
local PATROL_SPEED     = 14
local ENGAGE_RANGE     = 150

-- Blasters bots carry (weight) and the distance each likes to fight from.
local BOT_WEAPONS = {
	{ id = "PawBlaster",    weight = 4,   range = { 22, 45 } },
	{ id = "RapidPaw",      weight = 2,   range = { 16, 34 } },
	{ id = "BoomPaw",       weight = 2,   range = { 12, 26 } },
	{ id = "Starfall",      weight = 1.5, range = { 40, 70 } },
	{ id = "FrostBlaster",  weight = 1.5, range = { 20, 40 } },
	{ id = "BubbleBlaster", weight = 1,   range = { 10, 22 } },
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

local function rollWeapon(): (any, number, number)
	local total = 0
	for _, w in ipairs(BOT_WEAPONS) do total += w.weight end
	local pick = math.random() * total
	for _, w in ipairs(BOT_WEAPONS) do
		pick -= w.weight
		local def = Weapons.Get(w.id)
		if pick <= 0 and def then
			return def, w.range[1], w.range[2]
		end
	end
	return Weapons.Get("PawBlaster"), 22, 45
end

local BOT_NAMES = {
	"Whiskers-BOT", "Mittens-BOT", "Pounce-BOT",
	"Scratch-BOT",  "Nyan-BOT",    "Fuzz-BOT",
	"Biscuit-BOT",  "Pickle-BOT",  "Mochi-BOT",
	"Tofu-BOT",     "Noodle-BOT",  "Pepper-BOT",
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
	skill:           number,
	weapon:          any,
	rangeMin:        number,
	rangeMax:        number,
	aimError:        number,
	reaction:        number,
	fireDelay:       number,
	hitAt:           number,
	dodgeAt:         number,
	flyUntil:        number,
	align:           AlignOrientation,
}

-- ── module-level state ───────────────────────────────────────────────────────
local bots:          { [number]: BotState } = {}
local modelToId:     { [Model]: number   } = {}
local nextBotId      = 1
-- Bots reserved but not yet in the world (staggered spawn or respawning).
local pending:       { [number]: { team: string, name: string } } = {}
-- Total cats per match; bots fill whatever real players don't.
local TARGET_CATS    = 12
-- Eliminations each bot has this match (by name, so respawns keep them).
local botElims:      { [string]: { elims: number, team: string } } = {}
local matchActive    = false

-- Set by MatchService.Start so bot kills update the live scoreboard.
BotService.OnBotEliminated = nil :: ((killer: Player, botTeam: string) -> ())?
-- Set by MatchService: a bot eliminated an enemy bot, so its team scores.
BotService.OnTeamPoint = nil :: ((teamId: string) -> ())?

-- ── helpers ──────────────────────────────────────────────────────────────────
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

-- The cat (player or bot) an instance belongs to, if any.
local function catModel(inst: Instance?): Model?
	local m = inst and inst:FindFirstAncestorOfClass("Model")
	while m and not m:FindFirstChildOfClass("Humanoid") do
		m = m:FindFirstAncestorOfClass("Model")
	end
	return m
end

-- Where the bot's shots leave from: its blaster's barrel.
local function muzzle(bot: BotState): Vector3
	local tip = bot.model:FindFirstChild("MuzzlePoint", true)
	if tip and tip:IsA("BasePart") then
		return tip.Position
	end
	return bot.root.Position + bot.root.CFrame.LookVector * 1.5 + Vector3.new(0, 0.8, 0)
end

-- Clear shot from `from` to the target (another cat in the way still counts;
-- a wall doesn't).
local function canSee(bot: BotState, target: Model, from: Vector3, at: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { bot.model }
	params.IgnoreWater = true
	local hit = Workspace:Raycast(from, at - from, params)
	return hit == nil or hit.Instance:IsDescendantOf(target) or catModel(hit.Instance) ~= nil
end

-- Best enemy to fight: close, visible, already softened up (high fluff), and
-- a bit of loyalty to the current target so bots don't flip-flop.
local function pickTarget(bot: BotState): (Model?, number, boolean)
	local eye = bot.root.Position + Vector3.new(0, 1.2, 0)
	local reach = Runtime.HillPos and 45 or ENGAGE_RANGE
	local best: Model?, bestScore, bestDist, bestVisible = nil, math.huge, 0, false
	local function consider(model: Model, root: BasePart, fluff: number)
		local d = (root.Position - bot.root.Position).Magnitude
		if d > reach then return end
		local visible = canSee(bot, model, eye, root.Position)
		local score = d - (visible and 35 or 0) - math.min(fluff, 150) * 0.12 - (model == bot.target and 15 or 0)
		if score < bestScore then
			best, bestScore, bestDist, bestVisible = model, score, d, visible
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local s    = Runtime.Get(p)
		local char = p.Character
		local root = char and (char.PrimaryPart :: BasePart?)
		if s and s.Alive and (Runtime.Mode == "FFA" or s.Team ~= bot.team) and root and char then
			consider(char, root, s.Accumulated or 0)
		end
	end
	for _, other in pairs(bots) do
		if other.alive and other ~= bot and (Runtime.Mode == "FFA" or other.team ~= bot.team) then
			consider(other.model, other.root, other.accumulated)
		end
	end
	return best, bestDist, bestVisible
end

local function addAimError(dir: Vector3, degrees: number): Vector3
	local spread = math.rad(degrees)
	local up     = math.abs(dir.Unit.Y) > 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local right  = dir.Unit:Cross(up).Unit
	local realUp = right:Cross(dir.Unit).Unit
	local a = (math.random() - 0.5) * 2 * spread
	local b = (math.random() - 0.5) * 2 * spread
	return (dir.Unit + right * math.tan(a) + realUp * math.tan(b)).Unit
end

-- Knock a bot away. Its AI lets go of the controls for the flight, so the
-- launch carries instead of being braked by it walking to its next goal.
local function launchBot(bot: BotState, dV: Vector3)
	bot.root:ApplyImpulse(dV * bot.root.AssemblyMass)
	if dV.Y > 2 then
		bot.humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	bot.flyUntil = os.clock() + 0.25 + dV.Magnitude / 200
	bot.waypoints = nil
	bot.humanoid:MoveTo(bot.root.Position)
end

-- A bot's shot landing on another (enemy) bot.
local function botHitBot(shooter: BotState, victim: BotState, weapon: any, dir: Vector3)
	if not victim.alive or victim == shooter or (Runtime.Mode ~= "FFA" and victim.team == shooter.team) then return end
	victim.accumulated += weapon.Damage
	if Runtime.Mode ~= "Ringout" then
		victim.humanoid:TakeDamage(weapon.Damage * GameConfig.Character.HealthDamageScale)
	end
	victim.lastAttacker = nil
	victim.lastBot = shooter
	victim.hitAt = os.clock()
	victim.model:SetAttribute("Fluff", math.floor(victim.accumulated))
	local mayhem = Runtime.Mayhem and GameConfig.Mayhem.KnockbackMult or 1
	local dV = Knockback.ComputeDeltaV(dir, victim.accumulated, weapon.Knockback, 0.6 * mayhem)
	launchBot(victim, dV)
end

-- ── combat ───────────────────────────────────────────────────────────────────
local function botFireAt(bot: BotState, target: Model, tRoot: BasePart)
	local now = os.clock()
	local weapon = bot.weapon
	if now - bot.lastFireAt < math.max(1 / weapon.FireRate, bot.fireDelay) then return end
	local from = muzzle(bot)
	if not canSee(bot, target, from, tRoot.Position) then return end
	bot.lastFireAt = now

	-- Fast-moving targets are harder to hit.
	local speed = tRoot.AssemblyLinearVelocity.Magnitude
	local scatter = bot.aimError * (1 + math.min(speed / 28, 1) * 0.5) + weapon.Spread * 0.5
	local base = (tRoot.Position - from).Unit

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { bot.model }
	params.IgnoreWater = true
	local tos = {}
	for _ = 1, math.max(1, weapon.Pellets) do
		local dir = addAimError(base, scatter)
		local result = Workspace:Raycast(from, dir * weapon.Range, params)
		table.insert(tos, result and result.Position or from + dir * weapon.Range)
		local hitModel = result and catModel(result.Instance)
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
		kind  = "Tracers",
		from  = from,
		tos   = tos,
		color = weapon.TrailColor,
		weapon = weapon.Id,
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
	if Runtime.Mode ~= "Ringout" then
		vHum:TakeDamage(dmg * GameConfig.Character.HealthDamageScale)
	end
	vState.LastAttackAt = os.clock()

	local mayhem = Runtime.Mayhem and GameConfig.Mayhem.KnockbackMult or 1
	local dV     = Knockback.ComputeDeltaV(dir, vState.Accumulated, weapon.Knockback, 0.6 * mayhem)
	local impulse = dV * vRoot.AssemblyMass
	WeaponService.ApplyLaunch(victim, vHum, vRoot, impulse)
	vState.StunUntil = os.clock() + GameConfig.Character.LaunchStunSeconds
	if weapon.SlowFactor and weapon.SlowSeconds then
		vState.SlowUntil = math.max(vState.SlowUntil or 0, os.clock() + weapon.SlowSeconds)
	end

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
	-- No friendly fire on your own team's bots (except Free For All).
	local sState = Runtime.Get(shooter)
	if Runtime.Mode ~= "FFA" and sState and sState.Team and sState.Team == bot.team then return end

	bot.accumulated += weapon.Damage
	if Runtime.Mode ~= "Ringout" then
		bot.humanoid:TakeDamage(weapon.Damage * GameConfig.Character.HealthDamageScale)
	end
	bot.lastAttacker = shooter
	bot.lastBot = nil
	bot.hitAt = os.clock()
	bot.model:SetAttribute("Fluff", math.floor(bot.accumulated))

	local mayhem = Runtime.Mayhem and GameConfig.Mayhem.KnockbackMult or 1
	local dV = Knockback.ComputeDeltaV(dir, bot.accumulated, weapon.Knockback, mayhem)
	launchBot(bot, dV)

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
	bot.hitAt = os.clock()
	bot.humanoid:TakeDamage(damage * GameConfig.Character.HealthDamageScale)
	bot.model:SetAttribute("Fluff", math.floor(bot.accumulated))
	if dV.Magnitude > 0 then
		launchBot(bot, dV)
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

-- Path toward `goal`, re-planning when it's stale or the goal has moved.
local function travel(bot: BotState, goal: Vector3, now: number)
	if not bot.waypoints or now - bot.pathAt > 1.2 or (bot.goal - goal).Magnitude > 10 then
		computePath(bot, goal)
	end
	if not followPath(bot) then
		safeStep(bot, goal)
	end
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

-- Face the target while strafing (so the blaster points at it), or hand
-- turning back to the Humanoid when just walking.
local function faceToward(bot: BotState, pos: Vector3?)
	if pos then
		local flat = Vector3.new(pos.X, bot.root.Position.Y, pos.Z)
		bot.humanoid.AutoRotate = false
		bot.align.Enabled = true
		if (flat - bot.root.Position).Magnitude > 0.5 then
			bot.align.CFrame = CFrame.lookAt(bot.root.Position, flat)
		end
	else
		bot.align.Enabled = false
		bot.humanoid.AutoRotate = true
	end
end

-- Nearest fish snack, if any.
local function nearestSnack(bot: BotState): Vector3?
	local best, bestD = nil, 120
	for _, spot in ipairs(DropService.SnackSpots()) do
		local d = (spot - bot.root.Position).Magnitude
		if d < bestD then
			best, bestD = spot, d
		end
	end
	return best
end

-- Dodge after taking a hit: a hop, or a quick side-step dash.
local function dodge(bot: BotState, tRoot: BasePart?, now: number)
	bot.dodgeAt = now + 2.2 + math.random() * 1.5
	if math.random() > 0.35 + 0.45 * bot.skill then
		return
	end
	if math.random() < 0.5 then
		bot.humanoid.Jump = true
		return
	end
	local to = tRoot and Vector3.new(tRoot.Position.X - bot.root.Position.X, 0, tRoot.Position.Z - bot.root.Position.Z) or bot.root.CFrame.LookVector
	if to.Magnitude < 0.1 then return end
	local side = Vector3.new(-to.Z, 0, to.X).Unit * (math.random() < 0.5 and -1 or 1)
	if groundAhead(bot, side) and groundAhead(bot, side * 2) then
		bot.root:ApplyImpulse(side * 38 * bot.root.AssemblyMass)
	end
end

local function runBot(bot: BotState)
	bot.path = PathfindingService:CreatePath({ AgentRadius = 1.6, AgentHeight = 3.6, AgentCanJump = true, WaypointSpacing = 5 })
	bot.strafeSign = math.random() < 0.5 and -1 or 1
	bot.strafeFlipAt = 0
	local lastPos, stuckSince = bot.root.Position, os.clock()
	while bot.alive and matchActive do
		local now = os.clock()

		-- Mid-flight from a hit: hands off the controls until it lands.
		if now < bot.flyUntil or (now < bot.flyUntil + 1.5 and bot.humanoid.FloorMaterial == Enum.Material.Air and bot.flyUntil > 0) then
			task.wait(0.1)
			continue
		end

		-- Unstick: trying to move but going nowhere for a while -> hop and re-plan.
		if (bot.root.Position - lastPos).Magnitude > 2 then
			lastPos, stuckSince = bot.root.Position, now
		elseif now - stuckSince > 1.6 and bot.humanoid.MoveDirection.Magnitude > 0.1 then
			bot.humanoid.Jump = true
			bot.waypoints = nil
			lastPos, stuckSince = bot.root.Position, now
		end

		local hurt = bot.accumulated > 100 or bot.humanoid.Health < bot.humanoid.MaxHealth * 0.4
		local snack = hurt and nearestSnack(bot) or nil
		local target, dist, visible = pickTarget(bot)
		local tRoot = target and target.PrimaryPart

		-- Capture the Flag: carriers run home; odd bots attack the enemy flag;
		-- everyone goes for the flag when there's nobody to fight.
		local objective = Runtime.Mode == "CTF" and FlagService.Objective(bot.team, bot.model) or nil
		local carrying = objective ~= nil and FlagService.IsCarrier(bot.model)
		local goFlag = objective ~= nil and (carrying or not target or (bot.id % 2 == 1 and dist > 30))

		if snack and not carrying and (not target or dist > 25) then
			-- Badly hurt: go eat a fish snack (heals, cuts fluff).
			bot.humanoid.WalkSpeed = CHASE_SPEED
			faceToward(bot, nil)
			travel(bot, snack, now)
			task.wait(0.2)
		elseif goFlag and objective then
			bot.humanoid.WalkSpeed = CHASE_SPEED
			if target ~= bot.target then
				bot.target = target
				bot.targetAcquiredAt = now
			end
			faceToward(bot, (target and tRoot and visible) and tRoot.Position or nil)
			travel(bot, objective, now)
			if target and tRoot and visible and dist <= bot.weapon.Range and now - bot.targetAcquiredAt >= bot.reaction then
				botFireAt(bot, target, tRoot)
			end
			task.wait(0.15)
		elseif target and tRoot then
			if target ~= bot.target then
				bot.target = target
				bot.targetAcquiredAt = now
			end
			faceToward(bot, tRoot.Position)
			if dist > bot.rangeMax or not visible then
				-- Close in (or flank round cover) along a path.
				bot.humanoid.WalkSpeed = CHASE_SPEED
				travel(bot, tRoot.Position, now)
			elseif dist < bot.rangeMin then
				-- Too close for this weapon: back off.
				bot.waypoints = nil
				bot.humanoid.WalkSpeed = PATROL_SPEED
				local away = Vector3.new(bot.root.Position.X - tRoot.Position.X, 0, bot.root.Position.Z - tRoot.Position.Z)
				safeStep(bot, bot.root.Position + (away.Magnitude > 0.1 and away.Unit or Vector3.zero) * 6)
			else
				-- In range: strafe side to side instead of standing still.
				bot.waypoints = nil
				bot.humanoid.WalkSpeed = PATROL_SPEED
				if now > bot.strafeFlipAt then
					bot.strafeSign = -bot.strafeSign
					bot.strafeFlipAt = now + lerp(1.6, 0.7, bot.skill) + math.random() * 1.2
				end
				local to = Vector3.new(tRoot.Position.X - bot.root.Position.X, 0, tRoot.Position.Z - bot.root.Position.Z)
				local side = to.Magnitude > 0.1 and Vector3.new(-to.Z, 0, to.X).Unit * bot.strafeSign or Vector3.zero
				safeStep(bot, bot.root.Position + side * 6)
			end
			if now - bot.hitAt < 0.6 and now > bot.dodgeAt then
				dodge(bot, tRoot, now)
			end
			if visible and dist <= bot.weapon.Range and now - bot.targetAcquiredAt >= bot.reaction then
				botFireAt(bot, target, tRoot)
			end
			task.wait(0.1 + math.random() * 0.06)
		else
			bot.target = nil
			faceToward(bot, nil)
			bot.humanoid.WalkSpeed = PATROL_SPEED
			if not bot.waypoints then
				local hill = Runtime.HillPos
				local p = hill and (hill + Vector3.new(math.random(-8, 8), 2, math.random(-8, 8))) or nearestSnack(bot) or randomFloorPoint()
				if p then
					computePath(bot, p)
				end
			end
			if not followPath(bot) then
				task.wait(0.6)
			end
			task.wait(0.25)
		end
	end
end

-- ── spawning ─────────────────────────────────────────────────────────────────
local function spawnBot(botId: number, teamId: string, botName: string)
	local weapon, rangeMin, rangeMax = rollWeapon()
	local skill = lerp(SKILL_MIN, SKILL_MAX, math.random())
	local model = CatBuilder.Build(nil, botName, { Id = weapon.Id })
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

	model:PivotTo(PlayerService.PickSpawn(teamId))
	model.Parent = Workspace
	-- The server simulates bots (ownership can only be set once parented).
	pcall(function() root:SetNetworkOwner(nil) end)

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid

	-- Turns the bot to face its target while it strafes.
	local alignAt = Instance.new("Attachment")
	alignAt.Name = "BotAim"
	alignAt.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = alignAt
	align.Responsiveness = 30
	align.MaxTorque = math.huge
	align.Enabled = false
	align.Parent = root

	local bot: BotState = {
		id = botId, name = botName, model = model,
		humanoid = humanoid, root = root, team = teamId,
		alive = true, accumulated = 0, lastAttacker = nil,
		lastFireAt = 0, target = nil, targetAcquiredAt = 0,
		lastBot = nil, path = nil, waypoints = nil, wpIndex = 1,
		goal = root.Position, pathAt = 0, strafeSign = 1, strafeFlipAt = 0,
		skill = skill, weapon = weapon, rangeMin = rangeMin, rangeMax = rangeMax,
		aimError = lerp(AIM_ERROR_DEG[1], AIM_ERROR_DEG[2], skill),
		reaction = lerp(REACTION_SECS[1], REACTION_SECS[2], skill),
		fireDelay = lerp(FIRE_DELAY[1], FIRE_DELAY[2], skill),
		hitAt = 0, dodgeAt = 0, flyUntil = 0, align = align,
	}
	bots[botId]      = bot
	modelToId[model] = botId

	-- Elimination handler
	humanoid.Died:Connect(function()
		if not bot.alive then return end
		bot.alive = false
		bots[botId]      = nil
		modelToId[model] = nil
		local raisedFloor = Workspace:GetAttribute("KillFloorY")
		local ringout = root.Position.Y < math.max(GameConfig.Character.KillFloorY, typeof(raisedFloor) == "number" and raisedFloor or -math.huge) + 20

		local killer = bot.lastAttacker
		if killer and Players:FindFirstChild(killer.Name) then
			local kState = Runtime.Ensure(killer)
			kState.MatchElims += 1
			kState.MatchScore += 1
			EconomyService.AddXP(killer, GameConfig.Scoring.EliminationXP)
			EconomyService.AddCoins(killer, GameConfig.Scoring.EliminationCoins)
			EconomyService.AddStat(killer, "Eliminations", 1)
			SeasonService.AddXP(killer, "Elimination")
			EconomyService.Push(killer)
			if killer:GetAttribute("TrailPack") then
				Remotes.Get("PlayEffect"):FireAllClients({ kind = "Confetti", position = root.Position })
			end
			if BotService.OnBotEliminated then
				BotService.OnBotEliminated(killer, teamId)
			end
			Remotes.Get("KillFeed"):FireAllClients({
				killer = killer.DisplayName, killerTeam = kState.Team,
				victim = botName, victimTeam = teamId, ringout = ringout,
			})
		elseif bot.lastBot and bot.lastBot ~= bot and (Runtime.Mode == "FFA" or bot.lastBot.team ~= teamId) then
			local kb = bot.lastBot
			BotService.CreditKill(kb.name, kb.team)
			if BotService.OnTeamPoint then
				BotService.OnTeamPoint(kb.team)
			end
			Remotes.Get("KillFeed"):FireAllClients({
				killer = kb.name, killerTeam = kb.team,
				victim = botName, victimTeam = teamId, ringout = ringout,
			})
		else
			Remotes.Get("KillFeed"):FireAllClients({
				killer = ringout and "☠" or "—", victim = botName, victimTeam = teamId, ringout = ringout,
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
		local raised = Workspace:GetAttribute("KillFloorY")
		if root.Position.Y < math.max(GameConfig.Character.KillFloorY, typeof(raised) == "number" and raised or -math.huge) then
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

-- Where every living bot is (King of the Hill scoring).
function BotService.Positions(): { { team: string, pos: Vector3 } }
	local out = {}
	for _, b in pairs(bots) do
		if b.alive then
			table.insert(out, { team = b.team, pos = b.root.Position })
		end
	end
	return out
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
	-- A bot standing on a fish snack eats it (heals, cuts its fluff).
	DropService.BotEat = function(pos: Vector3, radius: number, heal: number, fluffCut: number): boolean
		for _, bot in pairs(bots) do
			local off = bot.root.Position - pos
			if bot.alive and Vector3.new(off.X, 0, off.Z).Magnitude <= radius and math.abs(off.Y) < 6 then
				bot.humanoid.Health = math.min(bot.humanoid.MaxHealth, bot.humanoid.Health + heal)
				bot.accumulated = math.max(0, bot.accumulated - fluffCut)
				bot.model:SetAttribute("Fluff", math.floor(bot.accumulated))
				return true
			end
		end
		return false
	end
end

return BotService
