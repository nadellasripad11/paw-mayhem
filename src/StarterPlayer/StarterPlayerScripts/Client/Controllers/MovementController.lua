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

MovementController.SprintChanged = nil :: ((boolean) -> ())?

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
	if not root or not hum or doubleUsed then
		return
	end
	if hum.FloorMaterial ~= Enum.Material.Air or os.clock() - airborneSince < 0.1 then
		return
	end
	doubleUsed = true
	local v = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(v.X, GameConfig.Movement.DoubleJumpSpeed, v.Z)
	hum:ChangeState(Enum.HumanoidStateType.Jumping)
	ringFx(root.Position - Vector3.new(0, 1.4, 0), Color3.new(1, 1, 1), 5)
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
	ringFx(root.Position - n * 1.2, Color3.new(1, 1, 1), 4)
	require(script.Parent.SoundController).Play("Jump")
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
	if os.clock() - airborneSince > 0.08 and tryWallJump(root, hum) then
		return
	end
	if doubleUsed then
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
end

-- Jump from the mobile button: a normal jump on the ground, a double jump in the air.
function MovementController.Jump()
	local _, hum = parts()
	if not hum then
		return
	end
	if hum.FloorMaterial ~= Enum.Material.Air then
		hum.Jump = true
	else
		airJump()
	end
end

-- A new cat can arrive before the ground under it has loaded (far-off lobby
-- and duel maps): hold it still until there's something to stand on.
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
	hum.WalkSpeed = base * mult
	if hum.Health <= 0 then
		stopCarry()
		return
	end
	if not isAirborne(hum) then
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
			airJump()
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

	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)
	RunService.Heartbeat:Connect(step)
end

return MovementController
