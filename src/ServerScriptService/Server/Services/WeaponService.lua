--!strict
-- WeaponService: server-authoritative combat.
--   * Validates every shot (ownership, alive, fire-rate, rate limit).
--   * Hit detection favours the shooter: the client says which cat each pellet
--     hit on its screen, and the server accepts it when that cat is within a
--     lag-sized distance of the shot line with no wall in between (otherwise
--     it falls back to its own raycast).
--   * Applies damage accumulation + physics knockback (the core mechanic).
--   * Applies weapon status effects (Frost slow) and power-up modifiers.
-- The client only sends origin/direction; it can never deal damage directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Weapons = require(Shared.Config.Weapons)
local GameConfig = require(Shared.Config.GameConfig)
local Knockback = require(Shared.Character.Knockback)
local Progression = require(Shared.Config.Progression)
local RateLimiter = require(Shared.Util.RateLimiter)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Runtime = require(script.Parent.Runtime)

local WeaponService = {}

-- Set by BotService so raycasts that hit bot models route damage there.
WeaponService.OnBotHit = nil :: ((shooter: Player, hitModel: Model, weapon: any, dir: Vector3) -> ())?
-- Set by LobbyService: shots on the practice range's target cats.
WeaponService.OnDummyHit = nil :: ((shooter: Player, hitModel: Model, weapon: any, dir: Vector3) -> ())?

-- Per-player: last fire time per weapon, for server-side fire-rate gating.
local lastFire: { [Player]: number } = {}
-- Global spam guard: generous cap independent of weapon fire rate.
local limiter = RateLimiter.new(20, 25)

local MAX_ORIGIN_DRIFT = 14 -- studs the claimed origin may differ from the cat
local HIT_TOLERANCE = 4.5 -- studs a claimed hit may sit off the shot line (network lag)
local HIT_LEAD = 0.3 -- plus this many seconds of the target's speed
local SPREAD_SLACK = 2.5 -- degrees a claimed pellet may stray beyond the weapon's cone

local function getEquippedWeapon(player: Player)
	-- A supply-drop weapon overrides the loadout for the rest of that life.
	local state = Runtime.Get(player)
	if state and state.WeaponOverride then
		local w = Weapons.Get(state.WeaponOverride)
		if w then
			return w
		end
	end
	local profile = DataService.Get(player)
	if not profile then
		return nil
	end
	local id = profile.Loadout.Weapon
	-- Must own it.
	if not profile.Unlocks.Weapons[id] then
		return nil
	end
	return Weapons.Get(id)
end

local function assemblyMass(model: Model): number
	local root = model.PrimaryPart
	if not root then
		return GameConfig.Knockback.MassReference
	end
	return root.AssemblyMass
end

-- Resolve active power-up modifiers for a shooter.
local function shooterMods(state)
	local fireRateMult, knockbackMult, extraPellets, spreadAdd = 1, 1, 0, 0
	if state and state.PowerUp and os.clock() < state.PowerUp.Expires then
		local p = Progression.PowerUpById[state.PowerUp.Id]
		if p then
			fireRateMult *= p.FireRateMult or 1
			knockbackMult *= p.KnockbackMult or 1
			extraPellets += p.ExtraPellets or 0
			spreadAdd += p.SpreadAdd or 0
		end
	end
	return fireRateMult, knockbackMult, extraPellets, spreadAdd
end

-- Resolve victim defensive modifiers (Shield power-up).
local function victimMods(state)
	local dmgResist, knockResist = 0, 0
	if state and state.PowerUp and os.clock() < state.PowerUp.Expires then
		local p = Progression.PowerUpById[state.PowerUp.Id]
		if p and p.Id == "Shield" then
			dmgResist = p.DamageResist or 0
			knockResist = p.KnockbackResist or 0
		end
	end
	return dmgResist, knockResist
end

local function directionWithSpread(dir: Vector3, spreadDeg: number): Vector3
	if spreadDeg <= 0 then
		return dir.Unit
	end
	local spread = math.rad(spreadDeg)
	-- random small rotation around two perpendicular axes
	local up = math.abs(dir.Unit.Y) > 0.99 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local right = dir.Unit:Cross(up).Unit
	local realUp = right:Cross(dir.Unit).Unit
	local a = (math.random() - 0.5) * 2 * spread
	local b = (math.random() - 0.5) * 2 * spread
	return (dir.Unit + right * math.tan(a) + realUp * math.tan(b)).Unit
end

-- The cat (player or bot) an instance belongs to, if any.
local function catModel(inst: Instance?): Model?
	local m = inst and inst:FindFirstAncestorOfClass("Model")
	while m and not m:FindFirstChildOfClass("Humanoid") do
		m = m:FindFirstAncestorOfClass("Model")
	end
	return m
end

local function hitTarget(player: Player, model: Model, weapon, dir: Vector3, knockMult: number)
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		if victim ~= player then
			WeaponService.ResolveHit(player, victim, weapon, dir, knockMult)
		end
	elseif model:GetAttribute("IsBot") and WeaponService.OnBotHit then
		WeaponService.OnBotHit(player, model, weapon, dir)
	elseif model:GetAttribute("IsDummy") and WeaponService.OnDummyHit then
		WeaponService.OnDummyHit(player, model, weapon, dir)
	end
end

-- Favour the shooter: accept the cat their client saw this pellet hit when,
-- as the server sees it, that cat is within a lag-sized distance of the shot
-- line, in range, and not behind a wall. Returns where the bolt should end.
local function checkClaim(player: Player, claimed: Model, origin: Vector3, dir: Vector3, range: number, serverHit: RaycastResult?): Vector3?
	if claimed == player.Character or not claimed:IsDescendantOf(Workspace) then
		return nil
	end
	local hum = claimed:FindFirstChildOfClass("Humanoid")
	local root = claimed.PrimaryPart
	if not hum or hum.Health <= 0 or not root then
		return nil
	end
	local rel = root.Position - origin
	local along = rel:Dot(dir)
	if along < 0 or along > range + 6 then
		return nil
	end
	local off = (rel - dir * along).Magnitude
	if off > HIT_TOLERANCE + root.AssemblyLinearVelocity.Magnitude * HIT_LEAD then
		return nil
	end
	if serverHit and serverHit.Distance < along - 3 and not catModel(serverHit.Instance) then
		return nil -- a wall is in the way
	end
	return origin + dir * along
end

-- Fire a single pellet and resolve whatever it hits. Returns the bolt's end.
local function firePellet(player: Player, weapon, origin: Vector3, dir: Vector3, knockMult: number, claimed: Model?): Vector3
	local char = player.Character
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char :: Model }
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, dir * weapon.Range, params)
	local serverModel = result and catModel(result.Instance)
	if claimed and claimed ~= serverModel then
		local at = checkClaim(player, claimed, origin, dir, weapon.Range, result)
		if at then
			hitTarget(player, claimed, weapon, dir, knockMult)
			return at
		end
	end
	if serverModel then
		hitTarget(player, serverModel, weapon, dir, knockMult)
	end
	return result and result.Position or origin + dir * weapon.Range
end

-- Everyone but the shooter draws the bolts (the shooter already drew them).
local function broadcastTracers(shooter: Player, origin: Vector3, tos: { Vector3 }, weapon)
	local data = { kind = "Tracers", from = origin, tos = tos, color = weapon.TrailColor, weapon = weapon.Id }
	local remote = Remotes.Get("PlayEffect")
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= shooter then
			remote:FireClient(other, data)
		end
	end
end

-- The victim's client owns its character's physics, so the launch is sent to
-- that client to apply. Taking server ownership instead froze the player's
-- controls and rubber-banded their cat on every hit.
function WeaponService.ApplyLaunch(victim: Player, _hum: Humanoid, root: BasePart, impulse: Vector3)
	local mass = root.AssemblyMass
	if mass > 0 then
		Remotes.Get("Launch"):FireClient(victim, { velocity = impulse / mass })
	end
end

-- Apply damage + knockback to a victim (server authority).
function WeaponService.ResolveHit(shooter: Player, victim: Player, weapon, dir: Vector3, knockMult: number)
	local vState = Runtime.Get(victim)
	if not vState or not vState.Alive then
		return
	end
	-- Only cats that can hurt each other (same match / opposite duel sides),
	-- friendly fire off, spawn protection.
	if not Runtime.CanHit(shooter, victim) then
		return
	end
	local inMatch = vState.Context == "Match"
	local sState = Runtime.Get(shooter)
	if inMatch and Runtime.Mode ~= "FFA" and sState and vState.Team and sState.Team == vState.Team then
		return
	end
	if os.clock() < (vState.SpawnProtectUntil or 0) then
		return
	end

	local vChar = victim.Character
	local vHum = vChar and vChar:FindFirstChildOfClass("Humanoid")
	local vRoot = vChar and vChar.PrimaryPart
	if not vHum or not vRoot then
		return
	end

	local dmgResist, knockResist = victimMods(vState)

	-- Damage (fluff) accumulation drives future knockback.
	local dmg = weapon.Damage * (1 - dmgResist)
	vState.Accumulated += dmg
	if not (inMatch and Runtime.Mode == "Ringout") then
		vHum:TakeDamage(dmg * GameConfig.Character.HealthDamageScale) -- HP ticks a little too
	end
	vState.LastAttacker = shooter
	vState.LastBot = nil
	vState.LastAttackAt = os.clock()

	-- Knockback impulse (mass-correct), applied by the victim's own client.
	local mayhem = (inMatch and Runtime.Mayhem) and GameConfig.Mayhem.KnockbackMult or 1
	local ringout = (inMatch and Runtime.Mode == "Ringout") and 1.3 or 1
	local dV = Knockback.ComputeDeltaV(dir, vState.Accumulated, weapon.Knockback, knockMult * mayhem * ringout * (1 - knockResist))
	local impulse = dV * vRoot.AssemblyMass
	WeaponService.ApplyLaunch(victim, vHum, vRoot, impulse)
	-- brief stun so victims can't instantly cancel the launch
	vState.StunUntil = os.clock() + GameConfig.Character.LaunchStunSeconds

	-- Frost weapon slow.
	if weapon.SlowFactor and weapon.SlowSeconds then
		vState.SlowUntil = math.max(vState.SlowUntil, os.clock() + weapon.SlowSeconds)
	end

	-- Track damage stat for shooter (quests).
	EconomyService.AddStat(shooter, "DamageDealt", math.floor(dmg))

	-- Feedback remotes.
	Remotes.Get("HitConfirm"):FireClient(shooter, {
		victim = victim.Name,
		position = vRoot.Position,
		damage = dmg,
		accumulated = vState.Accumulated,
	})
	Remotes.Get("YouWereHit"):FireClient(victim, {
		from = shooter.Name,
		direction = dir,
		accumulated = vState.Accumulated,
	})
end

-- Main fire handler.
function WeaponService.HandleFire(player: Player, payload)
	if type(payload) ~= "table" then
		return
	end
	if not limiter:Check(player) then
		return
	end
	local state = Runtime.Get(player)
	if not state or not state.Alive then
		return
	end
	if os.clock() < (state.StunUntil or 0) then
		return -- stunned mid-launch, can't shoot
	end

	local weapon = getEquippedWeapon(player)
	if not weapon then
		return
	end

	local char = player.Character
	local root = char and char.PrimaryPart
	if not root then
		return
	end

	-- Fire-rate gate (server truth), with power-up fire-rate.
	local fireRateMult, knockbackMult, extraPellets, spreadAdd = shooterMods(state)
	local minInterval = 1 / (weapon.FireRate * fireRateMult)
	local now = os.clock()
	local last = lastFire[player] or 0
	if now - last < minInterval * 0.9 then
		return
	end
	lastFire[player] = now

	-- Validate claimed origin is near the cat (anti-teleport-aim).
	local origin = payload.origin
	if typeof(origin) ~= "Vector3" then
		origin = root.Position
	elseif (origin - root.Position).Magnitude > MAX_ORIGIN_DRIFT then
		origin = root.Position
	end
	local baseDir = payload.direction
	if typeof(baseDir) ~= "Vector3" or baseDir.Magnitude < 0.01 then
		baseDir = root.CFrame.LookVector
	end
	baseDir = baseDir.Unit

	-- Each pellet: the client's direction and hit claim when it's inside the
	-- weapon's cone, else a server-rolled direction.
	local claims = type(payload.pellets) == "table" and payload.pellets or nil
	local maxAngle = math.rad(weapon.Spread + spreadAdd + SPREAD_SLACK)
	local tos = {}
	for i = 1, weapon.Pellets + extraPellets do
		local dir, claimed = nil, nil
		local c = claims and claims[i]
		if type(c) == "table" and typeof(c.dir) == "Vector3" and c.dir.Magnitude > 0.01 then
			local d = c.dir.Unit
			if math.acos(math.clamp(d:Dot(baseDir), -1, 1)) <= maxAngle then
				dir = d
				if typeof(c.hit) == "Instance" and c.hit:IsA("Model") then
					claimed = c.hit
				end
			end
		end
		dir = dir or directionWithSpread(baseDir, weapon.Spread + spreadAdd)
		table.insert(tos, firePellet(player, weapon, origin, dir, knockbackMult, claimed))
	end
	broadcastTracers(player, origin, tos, weapon)
end

function WeaponService.Start()
	Remotes.Get("FireWeapon").OnServerEvent:Connect(function(player, payload)
		WeaponService.HandleFire(player, payload)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastFire[player] = nil
		limiter:Clear(player)
	end)
end

return WeaponService
