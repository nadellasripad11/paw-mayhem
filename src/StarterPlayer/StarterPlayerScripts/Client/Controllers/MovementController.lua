--!strict
-- MovementController: everything about how your cat moves beyond Roblox's
-- default walking (which follows our camera):
--   * sprint toggle, plus the server's SpeedMult (Frost slow / Speed Boost)
--   * knockback the server sends us, whose momentum carries you through the
--     air (easing off) instead of stopping dead when the hit burst ends
--   * dash (Q / gamepad B / mobile button) and a mid-air double jump
--   * recoil: your own shots push you back a little (heavy blasters more; in
--     the air it carries you, so a big blaster can nudge you across a gap)
--   * forgiving jumps: a short grace after walking off a ledge, and a jump
--     pressed just before landing goes off as you land
--   * wall-jump: jump in the air next to a wall to kick off it (doesn't use
--     up the double jump; not the same wall twice in a row)
--   * pounce (E / gamepad X / mobile button): a cat leap forward and up
--   * jump pads (fling you along an arc to their target)
--   * map-event wind that pushes you while you keep steering
--   * rope swings (grab the knot, swing across a gap) and giant springs
--     (a JumpPad with a Bounce speed: straight up, steer in the air)
--   * wading slowly while Hidden in a ball pit
--   * climbing: in the air, push into a wall (an island's cliff, a building)
--     and hold jump to climb it; at the top you pull yourself over
--   * abilities (Z / X / C or the HUD buttons, 15 s each): Boost, Jumps, Fly
--   * swim columns (waterfalls, steam vents, bubble tubes, fan shafts): float
--     in them, SPACE / jump up, SHIFT down; 15 seconds in and you're flung
--     to a random spot on the map (a warning counts down from 8)
-- Airborne horizontal speed is held with a Plane LinearVelocity, because the
-- Humanoid otherwise drags air speed back down to walking speed.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local MovementController = {}

local player = Players.LocalPlayer
local sprinting = false
local activeLaunch: LinearVelocity? = nil
local mover: LinearVelocity? = nil -- dash / jump-pad flight
local moverKind = ""
local moverStart = 0
local dashReadyAt = 0
local doubleUsed = false
local airborneSince = 0
local padReadyAt = 0
local pads: { [BasePart]: boolean } = {}
local lastGroundAt = 0
local jumpedSinceGround = false
local jumpBufferUntil = 0
local lastWallNormal: Vector3? = nil
local pounceReadyAt = 0
local carryVel = Vector3.zero -- airborne momentum left over from a hit or dash
local carryStart = 0
local carryMover: LinearVelocity? = nil
local wind = { dir = Vector3.zero, strength = 0, untilT = 0 }
local windMover: LinearVelocity? = nil
local windFx: Part? = nil
local lastJumpRequest = 0
local multiJumpUntil = 0 -- the Jumps ability is on until then

MovementController.SprintChanged = nil :: ((boolean) -> ())?

-- A move's animation, here and on everyone else's screen.
local function moveFx(kind: string)
	require(script.Parent.CatAnimator).Trigger(player.Character, kind)
	Remotes.Get("MoveFx"):FireServer(kind)
end

local function setSprint(on: boolean)
	sprinting = on
	if MovementController.SprintChanged then
		MovementController.SprintChanged(on)
	end
end

function MovementController.ToggleSprint()
	setSprint(not sprinting)
end

function MovementController.SetSprint(on: boolean)
	setSprint(on)
end

function MovementController.IsSprinting(): boolean
	return sprinting
end

-- Seconds until the dash is ready again (0 when ready).
function MovementController.DashCooldown(): number
	return math.max(0, dashReadyAt - os.clock())
end

local function parts(): (BasePart?, Humanoid?)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not root or not hum or hum.Health <= 0 or root.Anchored then
		return nil, nil
	end
	return root, hum
end

local function attachment(root: BasePart): Attachment
	local att = root:FindFirstChild("LaunchAttachment") :: Attachment?
	if not att then
		local a = Instance.new("Attachment")
		a.Name = "LaunchAttachment"
		a.Parent = root
		att = a
	end
	return att :: Attachment
end

local function planeMover(root: BasePart, name: string, maxForce: number): LinearVelocity
	local lv = Instance.new("LinearVelocity")
	lv.Name = name
	lv.Attachment0 = attachment(root)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	lv.PrimaryTangentAxis = Vector3.xAxis
	lv.SecondaryTangentAxis = Vector3.zAxis
	lv.MaxForce = maxForce
	lv.Parent = root
	return lv
end

-- Keep some horizontal momentum while airborne; it eases off and ends on
-- landing (see carryStep).
local function startCarry(vel: Vector3)
	carryVel = Vector3.new(vel.X, 0, vel.Z)
	carryStart = os.clock()
end

local function stopCarry()
	carryVel = Vector3.zero
	if carryMover then
		carryMover:Destroy()
		carryMover = nil
	end
end

local function isAirborne(hum: Humanoid): boolean
	return hum.FloorMaterial == Enum.Material.Air
end

-- Hold a horizontal velocity for `seconds`; gravity still handles vertical.
local function holdHorizontal(root: BasePart, vel: Vector3, seconds: number, kind: string)
	if mover then
		mover:Destroy()
	end
	local lv = planeMover(root, "MoveBurst", root.AssemblyMass * 3000)
	lv.PlaneVelocity = Vector2.new(vel.X, vel.Z)
	mover, moverKind, moverStart = lv, kind, os.clock()
	task.delay(seconds, function()
		lv:Destroy()
		if mover == lv then
			mover = nil
			-- An air dash glides on instead of stopping dead.
			local _, hum = parts()
			if kind == "dash" and hum and isAirborne(hum) then
				startCarry(vel * GameConfig.Movement.DashCarry)
			end
		end
	end)
end

local function ringFx(pos: Vector3, color: Color3, size: number)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, size * 0.4, size * 0.4)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = color
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.25
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = Workspace
	local t = TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.12, size, size), Transparency = 1 })
	t.Completed:Connect(function()
		ring:Destroy()
	end)
	t:Play()
end

-- ── knockback ────────────────────────────────────────────────────────────────
-- A short LinearVelocity burst: long enough to read as a hit, short enough that
-- the player keeps steering. Bigger hits push a little longer.
local function launch(velocity: Vector3)
	local root, hum = parts()
	if not root or not hum then
		return
	end
	if activeLaunch then
		activeLaunch:Destroy()
	end
	-- A hit landing mid-flight adds to the flight instead of resetting it, so
	-- rapid fire pushes you along rather than pinning you in the air.
	local current = root.AssemblyLinearVelocity
	velocity += Vector3.new(current.X, math.max(current.Y, 0), current.Z) * GameConfig.Knockback.Stack
	local lv = Instance.new("LinearVelocity")
	lv.Attachment0 = attachment(root)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.VectorVelocity = velocity
	lv.MaxForce = root.AssemblyMass * 4000
	lv.Parent = root
	activeLaunch = lv
	if velocity.Y > 2 then
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	-- After the burst, the flight keeps going (see carryStep).
	startCarry(velocity * GameConfig.Movement.KnockbackCarry)
	local duration = math.clamp(0.12 + velocity.Magnitude / 900, 0.12, 0.3)
	task.delay(duration, function()
		lv:Destroy()
		if activeLaunch == lv then
			activeLaunch = nil
		end
	end)
end

-- ── recoil ─────────────────────────────────────────────────────────────────
function MovementController.Recoil(shotDir: Vector3, speed: number)
	local root, hum = parts()
	if not root or not hum or speed <= 0 then
		return
	end
	local back = Vector3.new(-shotDir.X, 0, -shotDir.Z)
	if back.Magnitude < 0.05 then
		return
	end
	back = back.Unit * speed
	if isAirborne(hum) then
		startCarry(carryVel + back)
	elseif not mover then
		-- A short shove that still leaves most of your own steering.
		holdHorizontal(root, back + hum.MoveDirection * hum.WalkSpeed * 0.5, 0.08, "recoil")
	end
end

-- ── dash + double jump ───────────────────────────────────────────────────────
function MovementController.Dash()
	local root, hum = parts()
	if not root or not hum or os.clock() < dashReadyAt then
		return
	end
	local cfg = GameConfig.Movement
	local dir = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	dir = dir.Unit
	dashReadyAt = os.clock() + cfg.DashCooldown
	holdHorizontal(root, dir * cfg.DashSpeed, cfg.DashTime, "dash")
	moveFx("Dash")
	require(script.Parent.SoundController).Play("Dash")

	-- Speed trail behind the cat.
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 0.9, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -0.9, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.25
	if player:GetAttribute("TrailPack") then
		-- Trail Pack: rainbow dash trail.
		trail.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 90)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 60)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 120)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)),
		})
		trail.Lifetime = 0.45
	else
		trail.Color = ColorSequence.new(Color3.fromRGB(150, 230, 255))
	end
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.LightEmission = 0.6
	trail.Parent = root
	task.delay(0.5, function()
		trail:Destroy()
		a0:Destroy()
		a1:Destroy()
	end)
end

local function tryDoubleJump()
	local root, hum = parts()
	local multi = os.clock() < multiJumpUntil -- the Jumps ability
	if not root or not hum or (doubleUsed and not multi) then
		return
	end
	if hum.FloorMaterial ~= Enum.Material.Air or os.clock() - airborneSince < (multi and 0.05 or 0.1) then
		return
	end
	doubleUsed = true
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, GameConfig.Movement.DoubleJumpSpeed, v.Z)
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	moveFx("Flip")
end

-- The wall you're hugging in the air (its flat outward normal), if any.
local function wallNormal(root: BasePart): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	params.RespectCanCollide = true
	local best: RaycastResult? = nil
	for k = 0, 7 do
		local a = k * math.pi / 4
		local hit = Workspace:Raycast(root.Position, Vector3.new(math.cos(a), 0, math.sin(a)) * 2.8, params)
		if hit and math.abs(hit.Normal.Y) < 0.35 and (not best or hit.Distance < best.Distance) then
			best = hit
		end
	end
	if not best then
		return nil
	end
	return Vector3.new(best.Normal.X, 0, best.Normal.Z).Unit
end

local function tryWallJump(root: BasePart, hum: Humanoid): boolean
	local n = wallNormal(root)
	if not n or (lastWallNormal and n:Dot(lastWallNormal) > 0.7) then
		return false
	end
	lastWallNormal = n
	local cfg = GameConfig.Movement
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, cfg.WallJumpUp, v.Z)
	startCarry(n * cfg.WallJumpOut)
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	require(script.Parent.SoundController).Play("Jump")
	moveFx("WallKick")
	return true
end

-- ── climbing ─────────────────────────────────────────────────────────────────
-- Jump in the air while pushing into a wall and you grab on: hold jump to
-- climb (up to CLIMB_TIME seconds before you touch the ground again). When
-- the wall ends you pull yourself up and over.
local CLIMB_SPEED, CLIMB_TIME = 16, 3.5
local jumpHeld = false -- the on-screen jump button held down
local climbing = false
local climbUsed = 0
local climbMover: LinearVelocity? = nil

local function jumpIsHeld(): boolean
	return jumpHeld or UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA)
end

-- The wall straight ahead in the way you're pushing, if any.
local function wallAhead(root: BasePart, hum: Humanoid): RaycastResult?
	local md = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
	if md.Magnitude < 0.3 then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Model }
	params.RespectCanCollide = true
	local hit = Workspace:Raycast(root.Position, md.Unit * 2.6, params)
	if hit and math.abs(hit.Normal.Y) < 0.45 then
		return hit
	end
	return nil
end

local function stopClimb()
	climbing = false
	if climbMover then
		climbMover:Destroy()
		climbMover = nil
	end
end

-- Returns true while climbing (the rest of the movement step waits).
local function climbStep(root: BasePart, hum: Humanoid, dt: number): boolean
	if not climbing then
		return false
	end
	if not jumpIsHeld() or climbUsed >= CLIMB_TIME or activeLaunch or not isAirborne(hum) then
		stopClimb()
		return false
	end
	local hit = wallAhead(root, hum)
	if not hit then
		-- Over the top: pull up and onto it.
		stopClimb()
		local md = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
		local fwd = md.Magnitude > 0.1 and md.Unit or Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
		root.AssemblyLinearVelocity = fwd * 16 + Vector3.new(0, 30, 0)
		holdHorizontal(root, fwd * 16, 0.35, "pad")
		return false
	end
	climbUsed += dt
	if not climbMover or climbMover.Parent ~= root then
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Climb"
		lv.Attachment0 = attachment(root)
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.MaxForce = root.AssemblyMass * 3000
		lv.Parent = root
		climbMover = lv
	end
	local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z)
	;(climbMover :: LinearVelocity).VectorVelocity = Vector3.new(0, CLIMB_SPEED, 0) - (n.Magnitude > 0 and n.Unit or Vector3.zero) * 3
	return true
end

-- ── abilities ────────────────────────────────────────────────────────────────
-- Three, each recharging in 15 seconds (Z / X / C, or the HUD's buttons):
--   Boost - a long, fast dash with a little lift
--   Jumps - six seconds of unlimited air jumps
--   Fly   - four seconds of flight (steer as usual, SPACE up, SHIFT down)
MovementController.Abilities = { "Boost", "Jumps", "Fly" }
MovementController.AbilitiesEnabled = false -- set by the HUD (matches, duels, the range)
local ABILITY_COOLDOWN = 15
local JUMPS_TIME, FLY_TIME = 6, 4
local abilityReady: { [string]: number } = { Boost = 0, Jumps = 0, Fly = 0 }
local flyUntil = 0
local flyMover: LinearVelocity? = nil

function MovementController.AbilityCooldown(name: string): number
	return math.max(0, (abilityReady[name] or 0) - os.clock())
end

-- Seconds an ability still has running (Jumps / Fly), 0 when it's not on.
function MovementController.AbilityActive(name: string): number
	local untilT = name == "Jumps" and multiJumpUntil or name == "Fly" and flyUntil or 0
	return math.max(0, untilT - os.clock())
end

function MovementController.UseAbility(name: string)
	local root, hum = parts()
	if not root or not hum or hum.Health <= 0 or not MovementController.AbilitiesEnabled then
		return
	end
	local now = os.clock()
	if now < (abilityReady[name] or math.huge) then
		return
	end
	abilityReady[name] = now + ABILITY_COOLDOWN
	local sounds = require(script.Parent.SoundController)
	if name == "Boost" then
		local dir = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		end
		dir = dir.Unit
		stopCarry()
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0) + 22, v.Z)
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		holdHorizontal(root, dir * GameConfig.Movement.DashSpeed * 1.8, 0.35, "dash")
		ringFx(root.Position, Color3.fromRGB(120, 220, 255), 9)
		sounds.Play("Dash", 0.7)
		moveFx("Dash")
	elseif name == "Jumps" then
		multiJumpUntil = now + JUMPS_TIME
		doubleUsed = false
		ringFx(root.Position - Vector3.new(0, 1.4, 0), Color3.fromRGB(255, 214, 90), 8)
		sounds.Play("Pop")
	elseif name == "Fly" then
		flyUntil = now + FLY_TIME
		stopCarry()
		ringFx(root.Position, Color3.fromRGB(190, 150, 255), 10)
		sounds.Play("Whoosh", 0.8)
		moveFx("Fly")
	end
end

-- Returns true while flying (the rest of the movement step waits).
local function flyStep(root: BasePart, hum: Humanoid): boolean
	if os.clock() >= flyUntil then
		if flyMover then
			flyMover:Destroy()
			flyMover = nil
		end
		return false
	end
	if not flyMover or flyMover.Parent ~= root then
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Fly"
		lv.Attachment0 = attachment(root)
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.MaxForce = root.AssemblyMass * 3000
		lv.Parent = root
		flyMover = lv
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
	end
	local up = jumpIsHeld()
	local down = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	local vy = up and 22 or down and -22 or 0
	local walk = hum.MoveDirection * hum.WalkSpeed * 1.6
	local fm = flyMover :: LinearVelocity
	fm.Enabled = activeLaunch == nil -- a hit still knocks you about
	fm.VectorVelocity = Vector3.new(walk.X, vy, walk.Z)
	return true
end

local COYOTE = 0.14 -- seconds after leaving a ledge you can still jump normally
local BUFFER = 0.16 -- a jump pressed this long before landing still counts

-- A jump press while airborne: the normal jump if you only just walked off a
-- ledge, else the double jump, else remember it for when you land.
local function airJump()
	local root, hum = parts()
	if not root or not hum or not isAirborne(hum) then
		return
	end
	if not jumpedSinceGround and os.clock() - lastGroundAt < COYOTE then
		jumpedSinceGround = true
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, hum.JumpPower, v.Z)
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
		return
	end
	-- Pushing into a wall: grab on and climb (hold jump).
	if climbUsed < CLIMB_TIME and wallAhead(root, hum) then
		climbing = true
		return
	end
	if os.clock() - airborneSince > 0.08 and tryWallJump(root, hum) then
		return
	end
	if doubleUsed and os.clock() >= multiJumpUntil then
		jumpBufferUntil = os.clock() + BUFFER
		return
	end
	tryDoubleJump()
end

-- Seconds until the pounce is ready again (0 when ready).
function MovementController.PounceCooldown(): number
	return math.max(0, pounceReadyAt - os.clock())
end

-- Pounce: a cat leap forward and up (ground only).
function MovementController.Pounce()
	local root, hum = parts()
	if not root or not hum or os.clock() < pounceReadyAt or isAirborne(hum) then
		return
	end
	local cfg = GameConfig.Movement
	local dir = Vector3.new(hum.MoveDirection.X, 0, hum.MoveDirection.Z)
	if dir.Magnitude < 0.1 then
		dir = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	end
	dir = dir.Unit
	pounceReadyAt = os.clock() + cfg.PounceCooldown
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, cfg.PounceUp, v.Z)
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	startCarry(dir * cfg.PounceSpeed)
	ringFx(root.Position - Vector3.new(0, 1.4, 0), Color3.fromRGB(255, 214, 120), 7)
	require(script.Parent.SoundController).Play("Dash", 0.8)
	moveFx("Pounce")
end

-- Jump from the mobile button: a normal jump on the ground, a double jump in the air.
-- (Roblox's touch controls reset Humanoid.Jump every frame, so setting it
-- from our button did nothing: the button changes state directly.)
function MovementController.Jump()
	local root, hum = parts()
	if not root or not hum then
		return
	end
	lastJumpRequest = os.clock()
	if MovementController.Swimming then
		return -- holding jump swims up (see SetJumpHeld)
	end
	if hum.FloorMaterial ~= Enum.Material.Air then
		jumpedSinceGround = true
		local v = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(v.X, hum.JumpPower, v.Z)
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	else
		airJump()
	end
end

-- The on-screen jump button held down (swims up, climbs, flies up).
function MovementController.SetJumpHeld(on: boolean)
	jumpHeld = on
end

-- A new cat can arrive before the ground under it has loaded (far-off lobby
-- and duel maps): hold it still until there's something to stand on.
-- ── rope swings ──────────────────────────────────────────────────────────────
-- Walk into a rope's knot: you hang on and swing along an arc under its
-- pivot to the far side, then let go just over the landing spot. A hit
-- knocks you off.
local swings: { [BasePart]: boolean } = {}
type Swing = { rope: BasePart, line: Part, mover: LinearVelocity, pivot: Vector3, u: Vector3, a0: number, a1: number, r0: number, r1: number, t0: number, dur: number,
	zip: boolean, start: Vector3, za: Vector3, zb: Vector3, lift: number }
local swing: Swing? = nil
local swingReadyAt = 0

local function swingPoint(s: Swing, t: number): Vector3
	if s.zip then
		-- Zipline: up to the cable, then along it (picking up speed).
		if t < s.lift then
			return s.start:Lerp(s.za, t / s.lift)
		end
		local k = (t - s.lift) / (1 - s.lift)
		return s.za:Lerp(s.zb, math.clamp(k * k * 0.35 + k * 0.65, 0, 1))
	end
	local e = (1 - math.cos(math.pi * math.clamp(t, 0, 1))) / 2 -- slow at the ends, fastest at the bottom
	local a = s.a0 + (s.a1 - s.a0) * e
	local r = s.r0 + (s.r1 - s.r0) * e
	return s.pivot + s.u * math.sin(a) * r - Vector3.yAxis * math.cos(a) * r
end

local function endSwing(letGo: boolean)
	local s = swing
	if not s then
		return
	end
	swing = nil
	s.mover:Destroy()
	s.line:Destroy()
	s.rope.LocalTransparencyModifier = 0
	swingReadyAt = os.clock() + 2
	moveFx("SwingEnd")
	local root, hum = parts()
	if letGo and root and hum then
		-- A little hop forward onto the landing.
		root.AssemblyLinearVelocity = s.u * 14 + Vector3.new(0, 12, 0)
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		holdHorizontal(root, s.u * 14, 0.4, "pad")
	end
end

local function startSwing(rope: BasePart, root: BasePart, hum: Humanoid)
	local pivot, land = rope:GetAttribute("Pivot"), rope:GetAttribute("Land")
	if typeof(pivot) ~= "Vector3" then
		pivot = rope:GetAttribute("HangA") -- (ziplines have no pivot)
	end
	if typeof(pivot) ~= "Vector3" or typeof(land) ~= "Vector3" then
		return
	end
	local start = root.Position
	local u = Vector3.new(land.X - start.X, 0, land.Z - start.Z).Unit
	local function polar(p: Vector3): (number, number)
		local d = p - pivot
		return math.atan2(d:Dot(u), -d.Y), d.Magnitude
	end
	local a0, r0 = polar(start)
	local a1, r1 = polar(land)
	stopCarry()
	if mover then
		mover:Destroy()
		mover = nil
	end
	doubleUsed = false
	local lv = Instance.new("LinearVelocity")
	lv.Name = "Swing"
	lv.Attachment0 = attachment(root)
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.MaxForce = root.AssemblyMass * 8000
	lv.Parent = root
	local line = Instance.new("Part")
	line.Name = "SwingLine"
	line.Size = Vector3.new(0.3, 0.3, 1)
	line.Color = rope.Color
	line.Material = Enum.Material.Fabric
	line.Anchored = true
	line.CanCollide = false
	line.CanQuery = false
	line.CanTouch = false
	line.CastShadow = false
	line.Parent = Workspace
	rope.LocalTransparencyModifier = 1
	local arc = math.abs(a1 - a0) * (r0 + r1) / 2
	local za, zb = rope:GetAttribute("HangA"), rope:GetAttribute("HangB")
	local zip = rope:GetAttribute("Zip") == true and typeof(za) == "Vector3" and typeof(zb) == "Vector3"
	local dur = math.clamp(arc / 34, 1.3, 2.6)
	local lift = 0
	if zip then
		local ride = ((zb :: Vector3) - (za :: Vector3)).Magnitude / 48
		dur = 0.3 + ride
		lift = 0.3 / dur
		rope.LocalTransparencyModifier = 0 -- (the handle rides with you: keep it shown)
	end
	swing = { rope = rope, line = line, mover = lv, pivot = pivot, u = u, a0 = a0, a1 = a1, r0 = r0, r1 = r1, t0 = os.clock(), dur = dur,
		zip = zip, start = start, za = zip and za :: Vector3 or start, zb = zip and zb :: Vector3 or start, lift = lift }
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	require(script.Parent.SoundController).Play("Whoosh", 0.8)
	moveFx("Swing")
end

local function checkSwings(root: BasePart, hum: Humanoid)
	if os.clock() < swingReadyAt then
		return
	end
	for rope in pairs(swings) do
		local grab = rope:GetAttribute("Grab")
		if rope.Parent and typeof(grab) == "Vector3" and (root.Position - grab).Magnitude < 3.5 then
			startSwing(rope, root, hum)
			return
		end
	end
end

-- Returns true while swinging (the rest of the movement step waits).
local function swingStep(root: BasePart, dt: number): boolean
	local s = swing
	if not s then
		return false
	end
	local t = (os.clock() - s.t0) / s.dur
	if t >= 1 or activeLaunch ~= nil or not s.rope.Parent then
		endSwing(t >= 1)
		return false
	end
	-- Chase the next point on the arc.
	local goal = swingPoint(s, t + dt / s.dur)
	local v = (goal - root.Position) / math.max(dt, 1 / 120)
	if v.Magnitude > 140 then
		v = v.Unit * 140
	end
	s.mover.VectorVelocity = v
	local a = s.zip and (root.Position + Vector3.new(0, 3, 0)) or s.pivot
	local b = root.Position + Vector3.new(0, 0.8, 0)
	s.line.Size = Vector3.new(0.3, 0.3, (b - a).Magnitude)
	s.line.CFrame = CFrame.lookAt((a + b) / 2, b)
	return true
end

-- ── swim columns ─────────────────────────────────────────────────────────────
local SWIM_MAX, SWIM_WARN, SWIM_GRACE = 15, 8, 1.5
local SWIM_RISE, SWIM_SINK = 24, 24
local FLING_TEXT = { Water = "THE CURRENT FLINGS YOU", Steam = "THE VENT ERUPTS", Bubbles = "THE TUBE POPS", Wind = "THE FAN BLASTS YOU" }
local zones: { [BasePart]: boolean } = {}
local swimMover: LinearVelocity? = nil
local swimSince = 0 -- when this stay in a column began (0 = not in one)
local swimLastIn = 0
local swimIgnoreUntil = 0
local touchDown = false -- the on-screen ▼ button (phones)
local swimUI: { gui: ScreenGui, warn: TextLabel, hint: TextLabel, down: TextButton }? = nil

MovementController.Swimming = false

local function getSwimUI()
	if swimUI then
		return swimUI
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PawSwim"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 6
	gui.Parent = player:WaitForChild("PlayerGui")
	local function label(y: number, size: number): TextLabel
		local l = Instance.new("TextLabel")
		l.AnchorPoint = Vector2.new(0.5, 0.5)
		l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromOffset(460, size + 12)
		l.BackgroundTransparency = 1
		l.Font = Enum.Font.FredokaOne
		l.TextSize = size
		l.TextColor3 = Color3.new(1, 1, 1)
		l.TextStrokeTransparency = 0.3
		l.Visible = false
		l.Parent = gui
		return l
	end
	local warnLabel = label(0.6, 30)
	warnLabel.TextColor3 = Color3.fromRGB(255, 196, 70)
	local hint = label(0.66, 18)
	local down = Instance.new("TextButton")
	down.AnchorPoint = Vector2.new(1, 1)
	down.Position = UDim2.new(1, -150, 1, -190)
	down.Size = UDim2.fromOffset(72, 72)
	down.BackgroundColor3 = Color3.fromRGB(17, 21, 34)
	down.BackgroundTransparency = 0.25
	down.Text = "▼"
	down.Font = Enum.Font.GothamBold
	down.TextSize = 30
	down.TextColor3 = Color3.new(1, 1, 1)
	down.Visible = false
	down.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = down
	down.MouseButton1Down:Connect(function()
		touchDown = true
	end)
	down.MouseButton1Up:Connect(function()
		touchDown = false
	end)
	down.MouseLeave:Connect(function()
		touchDown = false
	end)
	swimUI = { gui = gui, warn = warnLabel, hint = hint, down = down }
	return swimUI
end

local function showSwimUI(kind: string?, stay: number, golden: boolean?)
	local ui = swimUI
	if not kind then
		if ui then
			ui.warn.Visible = false
			ui.hint.Visible = false
			ui.down.Visible = false
		end
		touchDown = false
		return
	end
	ui = getSwimUI()
	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	ui.down.Visible = touch
	ui.hint.Visible = stay < 4 or golden == true
	ui.hint.Text = golden and "GOLDEN COLUMN  ·  +5 coins a second"
		or touch and "JUMP to go up  ·  ▼ to go down" or "SPACE to go up  ·  SHIFT to go down"
	ui.hint.TextColor3 = golden and Color3.fromRGB(255, 214, 80) or Color3.new(1, 1, 1)
	ui.warn.Visible = stay >= SWIM_WARN
	if ui.warn.Visible then
		ui.warn.Text = string.format("%s IN %d", FLING_TEXT[kind] or "FLUNG", math.ceil(SWIM_MAX - stay))
		ui.warn.Rotation = math.sin(os.clock() * 18) * 1.5
	end
end

local function zoneAt(pos: Vector3): BasePart?
	for z in pairs(zones) do
		if z.Parent then
			local lp = z.CFrame:PointToObjectSpace(pos)
			local half = z.Size / 2
			if math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y and math.abs(lp.Z) <= half.Z then
				return z
			end
		end
	end
	return nil
end

local function endSwim()
	if swimMover then
		swimMover:Destroy()
		swimMover = nil
	end
	MovementController.Swimming = false
	showSwimUI(nil, 0)
end

-- 15 seconds up: launched along an arc to a random spawn spot on the map.
local function swimFling(root: BasePart, hum: Humanoid)
	endSwim()
	swimSince = 0
	swimIgnoreUntil = os.clock() + 3
	local spots = {}
	local arena = Workspace:FindFirstChild("Arena")
	local spawns = arena and arena:FindFirstChild("Spawns")
	if spawns then
		for _, s in ipairs(spawns:GetChildren()) do
			if s:IsA("BasePart") then
				table.insert(spots, s.Position)
			end
		end
	end
	local p0 = root.Position
	ringFx(p0, Color3.fromRGB(120, 220, 255), 14)
	require(script.Parent.SoundController).Play("Spring")
	if #spots == 0 then
		root.AssemblyLinearVelocity = Vector3.new(0, 110, 0)
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		return
	end
	local goal = spots[math.random(1, #spots)]
	local flat = Vector3.new(goal.X - p0.X, 0, goal.Z - p0.Z)
	local t = math.clamp(flat.Magnitude / 60, 1.4, 3)
	local vy = (goal.Y - p0.Y + 0.5 * Workspace.Gravity * t * t) / t
	doubleUsed = false
	root.AssemblyLinearVelocity = flat / t + Vector3.new(0, vy, 0)
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	holdHorizontal(root, flat / t, t, "pad")
end

-- Returns true while swimming (the rest of the movement step waits).
local function swimStep(root: BasePart, hum: Humanoid): boolean
	local now = os.clock()
	local zone = now >= swimIgnoreUntil and zoneAt(root.Position) or nil
	if not zone then
		if MovementController.Swimming then
			endSwim()
		end
		if swimSince > 0 and now - swimLastIn > SWIM_GRACE then
			swimSince = 0 -- left it for good: the clock starts again next time
		end
		return false
	end
	local kind = tostring(zone:GetAttribute("Kind"))
	if swimSince == 0 then
		print("[PAW MAYHEM] swimming in a " .. kind .. " column")
		swimSince = now
		if kind == "Water" then
			require(script.Parent.SoundController).PlayAt("Splash", root.Position)
		end
	end
	swimLastIn = now
	MovementController.Swimming = true
	stopCarry()
	if mover then
		mover:Destroy() -- a dash or pad flight ends in the column
		mover = nil
	end
	local stay = now - swimSince
	if stay >= SWIM_MAX then
		swimFling(root, hum)
		return true
	end
	showSwimUI(kind, stay, zone:GetAttribute("Golden") == true)

	local lp = zone.CFrame:PointToObjectSpace(root.Position)
	local half = zone.Size / 2
	local up = UserInputService:IsKeyDown(Enum.KeyCode.Space) or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonA) or now - lastJumpRequest < 0.25 or jumpHeld
	local down = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
		or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.DPadDown) or touchDown
	if up and lp.Y > half.Y - 2.5 then
		-- Up at the top hops you out onto the island (the column's back faces it).
		endSwim()
		local inward = -zone.CFrame.LookVector
		inward = Vector3.new(inward.X, 0, inward.Z).Unit
		root.AssemblyLinearVelocity = inward * 18 + Vector3.new(0, hum.JumpPower * 1.15, 0)
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		holdHorizontal(root, inward * 18, 0.6, "pad")
		swimIgnoreUntil = now + 0.9
		swimSince = 0
		return true
	end
	local vy = up and SWIM_RISE or down and -SWIM_SINK or (tonumber(zone:GetAttribute("Drift")) or 0)
	if vy < 0 and lp.Y < -half.Y + 2 then
		vy = 0 -- the bottom holds you
	elseif vy > 0 and lp.Y > half.Y - 1 then
		vy = 0 -- drifting up stops at the top
	end
	if not swimMover or swimMover.Parent ~= root then
		local lv = Instance.new("LinearVelocity")
		lv.Name = "Swim"
		lv.Attachment0 = attachment(root)
		lv.RelativeTo = Enum.ActuatorRelativeTo.World
		lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
		lv.MaxForce = root.AssemblyMass * 2500
		lv.Parent = root
		swimMover = lv
	end
	local sm = swimMover :: LinearVelocity
	sm.Enabled = activeLaunch == nil -- a hit can still knock you out of it
	local walk = hum.MoveDirection * hum.WalkSpeed * 0.75
	sm.VectorVelocity = Vector3.new(walk.X, vy, walk.Z)
	return true
end

local function holdUntilGround(char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
	if not root then
		return
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local function ground(): boolean
		return Workspace:Raycast(root.Position, Vector3.new(0, -40, 0), params) ~= nil
	end
	if ground() then
		return
	end
	root.Anchored = true
	local t0 = os.clock()
	while char.Parent and not ground() and os.clock() - t0 < 10 do
		task.wait(0.1)
	end
	if root.Parent then
		root.Anchored = false
	end
end

local function hookCharacter(char: Model)
	task.spawn(holdUntilGround, char)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	doubleUsed = false
	jumpedSinceGround = false
	carryVel = Vector3.zero
	swimMover = nil
	swimSince = 0
	MovementController.Swimming = false
	showSwimUI(nil, 0)
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall then
			if airborneSince == 0 then
				airborneSince = os.clock()
			end
			if new == Enum.HumanoidStateType.Jumping then
				jumpedSinceGround = true
			end
		elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
			airborneSince = 0
			doubleUsed = false
			jumpedSinceGround = false
			lastWallNormal = nil
			if os.clock() < jumpBufferUntil then
				jumpBufferUntil = 0
				task.defer(function()
					hum.Jump = true
				end)
			end
		end
	end)
end

-- ── jump pads ────────────────────────────────────────────────────────────────
local function padLaunch(pad: BasePart, root: BasePart, hum: Humanoid)
	local bounce = pad:GetAttribute("Bounce")
	if typeof(bounce) == "number" then
		-- A spring: straight up, keeping (and steering) your run-up.
		local v = root.AssemblyLinearVelocity
		padReadyAt = os.clock() + 0.6
		doubleUsed = false
		root.AssemblyLinearVelocity = Vector3.new(v.X, bounce, v.Z)
		hum:ChangeState(Enum.HumanoidStateType.Freefall)
		startCarry(Vector3.new(v.X, 0, v.Z) + hum.MoveDirection * hum.WalkSpeed)
		require(script.Parent.SoundController).Play("Spring", 0.8)
		ringFx(pad.Position + Vector3.new(0, 0.3, 0), Color3.fromRGB(255, 210, 70), 10)
		local down = TweenService:Create(pad, TweenInfo.new(0.08), { CFrame = pad.CFrame - Vector3.new(0, 0.7, 0) })
		down.Completed:Once(function()
			TweenService:Create(pad, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), { CFrame = pad.CFrame + Vector3.new(0, 0.7, 0) }):Play()
		end)
		down:Play()
		return
	end
	local target = pad:GetAttribute("Target")
	if typeof(target) ~= "Vector3" then
		return
	end
	stopCarry()
	local goal = target + Vector3.new(0, 1.6, 0) -- root rides ~1.4 above the ground
	local p0 = root.Position
	local flat = Vector3.new(goal.X - p0.X, 0, goal.Z - p0.Z)
	local t = math.clamp(flat.Magnitude / 48, 1.0, 2.4)
	local g = Workspace.Gravity
	local vy = (goal.Y - p0.Y + 0.5 * g * t * t) / t
	padReadyAt = os.clock() + 1
	doubleUsed = false
	root.AssemblyLinearVelocity = flat / t + Vector3.new(0, vy, 0)
	hum:ChangeState(Enum.HumanoidStateType.Freefall)
	holdHorizontal(root, flat / t, t, "pad")
	require(script.Parent.SoundController).Play("Spring")
	ringFx(pad.Position + Vector3.new(0, 0.3, 0), Color3.fromRGB(90, 230, 255), 9)
end

local function checkPads(root: BasePart, hum: Humanoid)
	if os.clock() < padReadyAt then
		return
	end
	for pad in pairs(pads) do
		local off = root.Position - pad.Position
		if Vector3.new(off.X, 0, off.Z).Magnitude < 2.5 and off.Y > -0.5 and off.Y < 4.5 then
			padLaunch(pad, root, hum)
			return
		end
	end
end

-- ── wind (map event) ─────────────────────────────────────────────────────────
local function windStep(root: BasePart, hum: Humanoid)
	local now = os.clock()
	if now >= wind.untilT then
		if windMover then
			windMover:Destroy()
			windMover = nil
		end
		if windFx then
			windFx:Destroy()
			windFx = nil
		end
		return
	end
	if not windMover or windMover.Parent ~= root then
		windMover = planeMover(root, "WindPush", root.AssemblyMass * 350)
	end
	local wm = windMover :: LinearVelocity
	-- Knockback, dashes and pad flights take priority over the wind.
	wm.Enabled = activeLaunch == nil and mover == nil and carryMover == nil
	local walk = hum.MoveDirection * hum.WalkSpeed
	local push = walk + wind.dir * wind.strength
	wm.PlaneVelocity = Vector2.new(push.X, push.Z)

	-- Streaks of wind flying past the camera.
	if not windFx then
		local p = Instance.new("Part")
		p.Name = "WindFX"
		p.Size = Vector3.new(90, 40, 90)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Parent = Workspace
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.EmissionDirection = Enum.NormalId.Front
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(-2.5)
		e.Size = NumberSequence.new(0.5)
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.55), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(0.6, 0.9)
		e.Speed = NumberRange.new(70, 95)
		e.Rate = 90
		e.Parent = p
		windFx = p
	end
	local cam = Workspace.CurrentCamera.CFrame.Position
	;(windFx :: Part).CFrame = CFrame.lookAt(cam, cam + wind.dir)
end

-- ── airborne momentum ────────────────────────────────────────────────────────
local function carryStep(root: BasePart, hum: Humanoid, dt: number)
	local age = os.clock() - carryStart
	if carryVel.Magnitude < 3 or age > 3 or (age > 0.2 and not isAirborne(hum)) then
		stopCarry()
		return
	end
	carryVel *= math.exp(-GameConfig.Movement.AirDrag * dt)
	if activeLaunch or mover then
		if carryMover then
			carryMover.Enabled = false
		end
		return -- the hit burst / dash / pad flight is in charge right now
	end
	if not carryMover or carryMover.Parent ~= root then
		carryMover = planeMover(root, "AirCarry", root.AssemblyMass * 900)
	end
	local cm = carryMover :: LinearVelocity
	cm.Enabled = true
	-- You can still steer a little against the flight.
	local v = carryVel + hum.MoveDirection * hum.WalkSpeed * 0.6
	cm.PlaneVelocity = Vector2.new(v.X, v.Z)
end

-- ── per-frame ────────────────────────────────────────────────────────────────
local function step(dt: number)
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or not root then
		return
	end
	local autoSprint = require(script.Parent.Parent.ClientState).Settings.AutoSprint
	local base = (sprinting or autoSprint) and GameConfig.Character.SprintSpeed or GameConfig.Character.WalkSpeed
	local mult = char:GetAttribute("SpeedMult")
	if typeof(mult) ~= "number" then
		mult = 1
	end
	if char:GetAttribute("Hidden") == true then
		mult *= 0.55 -- wading through a ball pit
	end
	hum.WalkSpeed = base * mult
	if hum.Health <= 0 then
		stopCarry()
		if MovementController.Swimming then
			endSwim()
		end
		endSwing(false)
		return
	end
	if swingStep(root, dt) then
		return
	end
	if swimStep(root, hum) then
		return
	end
	if flyStep(root, hum) then
		return
	end
	if climbStep(root, hum, dt) then
		return
	end
	checkSwings(root, hum)
	if not isAirborne(hum) then
		climbUsed = 0
		if climbing then
			stopClimb()
		end
		lastGroundAt = os.clock()
	end
	carryStep(root, hum, dt)
	-- A pad flight ends early once you touch down.
	if mover and moverKind == "pad" and os.clock() - moverStart > 0.25 and hum.FloorMaterial ~= Enum.Material.Air then
		mover:Destroy()
		mover = nil
	end
	checkPads(root, hum)
	windStep(root, hum)
end

function MovementController.Start()
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.LeftShift or key == Enum.KeyCode.RightShift then
			setSprint(true)
		elseif key == Enum.KeyCode.ButtonL3 then
			MovementController.ToggleSprint()
		elseif key == Enum.KeyCode.Q or key == Enum.KeyCode.ButtonB then
			MovementController.Dash()
		elseif key == Enum.KeyCode.E or key == Enum.KeyCode.ButtonX then
			MovementController.Pounce()
		elseif key == Enum.KeyCode.Space or key == Enum.KeyCode.ButtonA then
			if not MovementController.Swimming then
				airJump()
			end
		elseif key == Enum.KeyCode.Z or key == Enum.KeyCode.DPadLeft then
			MovementController.UseAbility("Boost")
		elseif key == Enum.KeyCode.X or key == Enum.KeyCode.DPadUp then
			MovementController.UseAbility("Jumps")
		elseif key == Enum.KeyCode.C or key == Enum.KeyCode.DPadRight then
			MovementController.UseAbility("Fly")
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift then
			setSprint(false)
		end
	end)
	Remotes.Get("Launch").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and typeof(data.velocity) == "Vector3" then
			launch(data.velocity)
		end
	end)
	Remotes.Get("MapEvent").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and data.kind == "Wind" and typeof(data.dir) == "Vector3" then
			wind.dir = data.dir.Unit
			wind.strength = tonumber(data.strength) or 16
			wind.untilT = os.clock() + (tonumber(data.duration) or 8)
		end
	end)

	for _, inst in ipairs(CollectionService:GetTagged("JumpPad")) do
		if inst:IsA("BasePart") then
			pads[inst] = true
		end
	end
	CollectionService:GetInstanceAddedSignal("JumpPad"):Connect(function(inst)
		if inst:IsA("BasePart") then
			pads[inst] = true
		end
	end)
	CollectionService:GetInstanceRemovedSignal("JumpPad"):Connect(function(inst)
		pads[inst :: BasePart] = nil
	end)

	-- Swim columns, each with its looping sound.
	local function addZone(inst: Instance)
		if inst:IsA("BasePart") and not zones[inst] then
			zones[inst] = true
			local sound = inst:GetAttribute("Sound")
			if typeof(sound) == "string" then
				local spot = Instance.new("Attachment")
				spot.Position = Vector3.new(0, inst.Size.Y / 2 - 3, 0)
				spot.Parent = inst
				require(script.Parent.SoundController).Loop(sound, spot)
			end
			-- The golden column (Mayhem Mode): a gold glow and sparkles.
			local function paintGolden()
				local old = inst:FindFirstChild("GoldenGlow")
				if inst:GetAttribute("Golden") == true then
					if not old then
						local g = Instance.new("Part")
						g.Name = "GoldenGlow"
						g.Size = inst.Size + Vector3.new(0.4, 0, 0.4)
						g.CFrame = inst.CFrame
						g.Color = Color3.fromRGB(255, 206, 60)
						g.Material = Enum.Material.Neon
						g.Transparency = 0.8
						g.Anchored = true
						g.CanCollide = false
						g.CanQuery = false
						g.CanTouch = false
						g.CastShadow = false
						g.Parent = inst
						local e = Instance.new("ParticleEmitter")
						e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
						e.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
						e.Size = NumberSequence.new(1, 0)
						e.Speed = NumberRange.new(4, 8)
						e.Lifetime = NumberRange.new(1, 1.6)
						e.Rate = 40
						e.LightEmission = 1
						e.Parent = g
					end
				elseif old then
					old:Destroy()
				end
			end
			inst:GetAttributeChangedSignal("Golden"):Connect(paintGolden)
			paintGolden()
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged("SwimZone")) do
		addZone(inst)
	end
	CollectionService:GetInstanceAddedSignal("SwimZone"):Connect(addZone)
	CollectionService:GetInstanceRemovedSignal("SwimZone"):Connect(function(inst)
		zones[inst :: BasePart] = nil
	end)
	for _, inst in ipairs(CollectionService:GetTagged("RopeSwing")) do
		if inst:IsA("BasePart") then
			swings[inst] = true
		end
	end
	CollectionService:GetInstanceAddedSignal("RopeSwing"):Connect(function(inst)
		if inst:IsA("BasePart") then
			swings[inst] = true
		end
	end)
	CollectionService:GetInstanceRemovedSignal("RopeSwing"):Connect(function(inst)
		swings[inst :: BasePart] = nil
	end)
	UserInputService.JumpRequest:Connect(function()
		lastJumpRequest = os.clock()
	end)

	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)
	RunService.Heartbeat:Connect(step)
end

return MovementController
