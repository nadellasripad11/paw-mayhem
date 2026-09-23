--!strict
-- WeaponService: server-authoritative combat.
--   * Validates every shot (ownership, alive, fire-rate, rate limit).
--   * Performs raycast hit detection on the server (hitscan + client tracer).
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

-- Per-player: last fire time per weapon, for server-side fire-rate gating.
local lastFire: { [Player]: number } = {}
-- Global spam guard: generous cap independent of weapon fire rate.
local limiter = RateLimiter.new(20, 25)

local MAX_ORIGIN_DRIFT = 14 -- studs the claimed origin may differ from the cat

local function getEquippedWeapon(player: Player)
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

-- Fire a single pellet: raycast, and if it hits an enemy cat, resolve it.
local function firePellet(player: Player, weapon, origin: Vector3, dir: Vector3, knockMult: number)
	local char = player.Character
	if not char then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	params.IgnoreWater = true

	local result = Workspace:Raycast(origin, dir * weapon.Range, params)
	local hitPos = origin + dir * weapon.Range
	if result then
		hitPos = result.Position
		local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
		local victim = hitModel and Players:GetPlayerFromCharacter(hitModel)
		if victim and victim ~= player then
			WeaponService.ResolveHit(player, victim, weapon, dir, knockMult)
		elseif hitModel and hitModel:GetAttribute("IsBot") and WeaponService.OnBotHit then
			WeaponService.OnBotHit(player, hitModel, weapon, dir)
		end
	end

	-- Tell everyone to draw a tracer bolt (visual only).
	Remotes.Get("PlayEffect"):FireAllClients({
		kind = "Tracer",
		from = origin,
		to = hitPos,
		color = weapon.TrailColor,
	})
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
	-- Friendly fire off + spawn protection.
	local sState = Runtime.Get(shooter)
	if sState and vState.Team and sState.Team == vState.Team then
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
	vHum:TakeDamage(dmg * 0.5) -- HP also ticks so pure damage can eliminate too
	vState.LastAttacker = shooter
	vState.LastAttackAt = os.clock()

	-- Knockback impulse (mass-correct), applied by the victim's own client.
	local dV = Knockback.ComputeDeltaV(dir, vState.Accumulated, weapon.Knockback, knockMult * (1 - knockResist))
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

	local pellets = weapon.Pellets + extraPellets
	for _ = 1, pellets do
		local dir = directionWithSpread(baseDir, weapon.Spread + spreadAdd)
		firePellet(player, weapon, origin, dir, knockbackMult)
	end
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
