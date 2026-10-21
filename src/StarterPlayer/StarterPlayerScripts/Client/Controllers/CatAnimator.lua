--!strict
-- CatAnimator: every cat's animation (players, bots and the 3D menu
-- previews), posed locally each frame with CatBuilder.Pose. On top of the
-- walk / idle / mid-air pose it works out what each cat is doing and layers
-- that in:
--   * movement: a gallop when sprinting, a stretch on take-off, a squash and
--     a dust puff on landing (harder for bigger falls), leaning into turns,
--     legs paddling on the way down
--   * moves (Trigger, also sent to everyone else through MoveFx): the
--     double-jump front flip, the low dash dart, the pounce leap, the wall
--     kick and hanging on to a rope swing
--   * swimming in a swim column (paddling in water and bubble tubes, spread
--     out riding steam and fans) and wading through a ball pit
--   * combat: recoil on every shot (bigger for heavy blasters), a flinch when
--     hit, a cartoon tumble and dizzy stars when launched hard, a nervous
--     puffed-up tail at high %, a shake-off when you spawn
--   * life: random blinks and ear twitches, idle moves after standing still
--     (look around, stretch, scratch, lick a paw), and in the lobby sitting
--     down after a while, then sleeping if you're away
--   * props for some emotes (Purr's hearts, Box Sit's box)
-- A cat flying from a big hit streaks a speed trail; one blasted off the map
-- goes out with a star twinkle and a ding.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local SoundController = require(script.Parent.SoundController)

local CatAnimator = {}

local player = Players.LocalPlayer
local lastHurtAt = 0

local MAX_DIST = 180
local TRAIL_ON, TRAIL_OFF = 48, 30 -- studs/s: a launch, not a sprint
local OFF_MAP = 175 -- studs from the middle: past every island
local HEAVY = { BoomPaw = true, VoidCannon = true, Starfall = true, GoldenPurr = true }

local trails: { [Model]: Trail } = setmetatable({}, { __mode = "k" }) :: any
local twinkled: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

-- What each cat is up to (only what the pose needs).
type Motion = {
	wasAir: boolean, minVy: number, landAt: number, landAmt: number, takeoffAt: number,
	moves: { [string]: number }, recoilAt: number, recoilAmt: number,
	fluff: number, flinchAt: number, tumble: number, tumbling: boolean, tumbleAxis: Vector3,
	yaw: number, lean: number, spawnAt: number,
	stillSince: number, act: string?, actAt: number, nextAct: number,
	blinkAt: number, nextBlink: number, earAt: number, nextEar: number, earSide: number,
	props: { [string]: Instance },
}
local motions: { [Model]: Motion } = setmetatable({}, { __mode = "k" }) :: any

local function motionOf(model: Model): Motion
	local m = motions[model]
	if m then
		return m
	end
	local now = os.clock()
	local fluff = model:GetAttribute("Fluff")
	m = {
		wasAir = false, minVy = 0, landAt = -10, landAmt = 0, takeoffAt = -10,
		moves = {}, recoilAt = -10, recoilAmt = 0,
		fluff = typeof(fluff) == "number" and fluff or 0, flinchAt = -10, tumble = 0, tumbling = false, tumbleAxis = Vector3.xAxis,
		yaw = 0, lean = 0, spawnAt = now,
		stillSince = now, act = nil, actAt = 0, nextAct = now + math.random() * 4 + 4,
		blinkAt = -10, nextBlink = now + math.random() * 3 + 1, earAt = -10, nextEar = now + math.random() * 4 + 2, earSide = 1,
		props = {},
	}
	motions[model] = m
	return m
end

-- ── one-off effects ──────────────────────────────────────────────────────────
local function puff(pos: Vector3, color: Color3, count: number, speed: number)
	local a = Instance.new("Attachment")
	a.WorldPosition = pos
	a.Parent = Workspace.Terrain
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new(0.8, 2)
	e.Transparency = NumberSequence.new(0.35, 1)
	e.Speed = NumberRange.new(speed * 0.5, speed)
	e.SpreadAngle = Vector2.new(80, 80)
	e.EmissionDirection = Enum.NormalId.Top
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Rate = 0
	e.Parent = a
	e:Emit(count)
	Debris:AddItem(a, 1)
end

-- "Blasted off!" twinkle where a launched cat leaves the arena.
local function blastOff(pos: Vector3)
	local star = Instance.new("Part")
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.one * 2
	star.Material = Enum.Material.Neon
	star.Color = Color3.fromRGB(255, 240, 170)
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false
	star.CastShadow = false
	star.Position = pos
	star.Parent = Workspace
	local light = Instance.new("PointLight")
	light.Color = star.Color
	light.Range = 40
	light.Brightness = 6
	light.Parent = star
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(255, 250, 210))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.5, 0.9)
	e.Speed = NumberRange.new(10, 26)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Enabled = false
	e.Parent = star
	e:Emit(40)
	TweenService:Create(star, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = Vector3.one * 7 }):Play()
	task.delay(0.5, function()
		TweenService:Create(star, TweenInfo.new(0.4), { Size = Vector3.one * 0.2, Transparency = 1 }):Play()
		TweenService:Create(light, TweenInfo.new(0.4), { Brightness = 0 }):Play()
	end)
	Debris:AddItem(star, 1.2)
	SoundController.PlayAt("Knockout", pos, 1.3)
end

local function trailFor(model: Model, root: BasePart): Trail
	local t = trails[model]
	if t and t.Parent then
		return t
	end
	local a0 = Instance.new("Attachment")
	a0.Name = "LaunchTrailTop"
	a0.Position = Vector3.new(0, 1.1, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Name = "LaunchTrailBottom"
	a1.Position = Vector3.new(0, -0.9, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Name = "LaunchTrail"
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.FaceCamera = true
	trail.LightEmission = 0.4
	trail.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 220, 150))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new(1, 0.2)
	trail.Enabled = false
	trail.Parent = root
	trails[model] = trail
	return trail
end

-- Little stars circling a dazed cat's head.
local function dizzyStars(model: Model)
	local head = model:FindFirstChild("Head", true)
	if not head or not head:IsA("BasePart") then
		return
	end
	local stars = {}
	for i = 1, 3 do
		local s = Instance.new("Part")
		s.Name = "DizzyStar"
		s.Size = Vector3.one * 0.35
		s.Material = Enum.Material.Neon
		s.Color = Color3.fromRGB(255, 230, 90)
		s.Anchored = true
		s.CanCollide = false
		s.CanQuery = false
		s.CanTouch = false
		s.CastShadow = false
		s.Parent = Workspace
		stars[i] = s
	end
	local t0 = os.clock()
	local conn: RBXScriptConnection? = nil
	conn = RunService.RenderStepped:Connect(function()
		local k = os.clock() - t0
		if k > 1.4 or not head.Parent then
			for _, s in ipairs(stars) do
				s:Destroy()
			end
			if conn then
				conn:Disconnect()
			end
			return
		end
		for i, s in ipairs(stars) do
			local a = k * 9 + i * math.pi * 2 / 3
			s.CFrame = CFrame.new(head.Position + Vector3.new(math.cos(a) * 1.4, 1.3 + math.sin(k * 6 + i) * 0.15, math.sin(a) * 1.4)) * CFrame.Angles(0, a, math.rad(45))
		end
	end)
end

-- ── emote props (local, while the emote plays) ───────────────────────────────
local function emoteProps(model: Model, mo: Motion, emote: string?, root: BasePart)
	local want = emote == "Purr" and "Hearts" or emote == "BoxSit" and "Box" or emote == "Sleep" and "Zzz" or nil
	for name, inst in pairs(mo.props) do
		if name ~= want and name ~= "Lazy" then
			inst:Destroy()
			mo.props[name] = nil
		end
	end
	if not want or mo.props[want] then
		return
	end
	if want == "Hearts" then
		local head = model:FindFirstChild("Head", true)
		if head and head:IsA("BasePart") then
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.fromRGB(255, 120, 170))
			e.Size = NumberSequence.new(0.9, 0.2)
			e.Speed = NumberRange.new(2, 4)
			e.EmissionDirection = Enum.NormalId.Top
			e.Lifetime = NumberRange.new(0.8, 1.2)
			e.Rate = 10
			e.LightEmission = 0.5
			e.Parent = head
			mo.props.Hearts = e
		end
	elseif want == "Box" then
		local box = Instance.new("Model")
		box.Name = "EmoteBox"
		local brown, dark = Color3.fromRGB(196, 150, 96), Color3.fromRGB(150, 110, 66)
		local base = root.CFrame * CFrame.new(0, -1.3, 0)
		local function side(size: Vector3, off: Vector3, color: Color3)
			local p = Instance.new("Part")
			p.Size = size
			p.CFrame = base * CFrame.new(off)
			p.Color = color
			p.Material = Enum.Material.Cardboard
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Parent = box
		end
		side(Vector3.new(3, 0.15, 3), Vector3.new(0, -0.6, 0), dark)
		side(Vector3.new(3, 1.4, 0.15), Vector3.new(0, 0, 1.5), brown)
		side(Vector3.new(3, 1.4, 0.15), Vector3.new(0, 0, -1.5), brown)
		side(Vector3.new(0.15, 1.4, 3), Vector3.new(1.5, 0, 0), brown)
		side(Vector3.new(0.15, 1.4, 3), Vector3.new(-1.5, 0, 0), brown)
		box.Parent = Workspace
		mo.props.Box = box
	elseif want == "Zzz" then
		local head = model:FindFirstChild("Head", true)
		if head and head:IsA("BasePart") then
			local gui = Instance.new("BillboardGui")
			gui.Name = "Zzz"
			gui.Size = UDim2.fromOffset(60, 40)
			gui.StudsOffset = Vector3.new(1.2, 2.2, 0)
			gui.LightInfluence = 0
			gui.MaxDistance = 60
			gui.Parent = head
			local l = Instance.new("TextLabel")
			l.BackgroundTransparency = 1
			l.Size = UDim2.fromScale(1, 1)
			l.Font = Enum.Font.FredokaOne
			l.Text = "z Z"
			l.TextScaled = true
			l.TextColor3 = Color3.fromRGB(200, 220, 255)
			l.TextStrokeTransparency = 0.4
			l.Parent = gui
			mo.props.Zzz = gui
		end
	end
end

-- ── public ───────────────────────────────────────────────────────────────────
-- A move just happened on `model`: "Flip" (double jump), "Dash", "Pounce",
-- "WallKick", "Swing" / "SwingEnd" (rope swing), "Recoil" (amount = 1 normal,
-- more for heavy blasters).
function CatAnimator.Trigger(model: Model?, kind: string, amount: number?)
	if not model then
		return
	end
	local mo = motionOf(model)
	local now = os.clock()
	if kind == "Recoil" then
		mo.recoilAt = now
		mo.recoilAmt = amount or 1
	elseif kind == "SwingEnd" then
		mo.moves.Swing = nil
	else
		mo.moves[kind] = now
		if kind == "Dash" then
			local root = model.PrimaryPart
			if root and model ~= player.Character then
				local tr = trailFor(model, root)
				tr.Enabled = true
				task.delay(0.35, function()
					tr.Enabled = false
				end)
			end
		end
	end
end

-- ── working out the pose ─────────────────────────────────────────────────────
local zones: { BasePart } = {}
local function refreshZones()
	table.clear(zones)
	for _, z in ipairs(CollectionService:GetTagged("SwimZone")) do
		if z:IsA("BasePart") then
			table.insert(zones, z)
		end
	end
end

local function zoneKind(pos: Vector3): string?
	for _, z in ipairs(zones) do
		if z.Parent then
			local lp = z.CFrame:PointToObjectSpace(pos)
			local h = z.Size / 2
			if math.abs(lp.X) <= h.X and math.abs(lp.Y) <= h.Y and math.abs(lp.Z) <= h.Z then
				local k = z:GetAttribute("Kind")
				return typeof(k) == "string" and k or "Water"
			end
		end
	end
	return nil
end

local IDLE_ACTS = { "Look", "Stretch", "Scratch", "Lick" }
local ACT_TIME = { Look = 2.2, Stretch = 1.8, Scratch = 1.6, Lick = 2.0 }

local function ease(k: number): number
	return math.sin(math.pi * math.clamp(k, 0, 1))
end

local function buildFx(model: Model, root: BasePart, mo: Motion, now: number, dt: number, move: number, emoting: boolean, armed: boolean): CatBuilder.PoseFx
	local v = root.AssemblyLinearVelocity
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = v.Magnitude
	local isAir = math.abs(v.Y) > 8
	local add: { [string]: CFrame } = {}
	local replace: { [string]: CFrame } = {}
	local body = CFrame.identity
	local ears = { flat = 0, twitch = 0, side = mo.earSide }
	local blink = false
	local function addJ(name: string, cf: CFrame)
		add[name] = (add[name] or CFrame.identity) * cf
	end

	-- Landing / take-off.
	if isAir then
		mo.minVy = math.min(mo.minVy, v.Y)
		if not mo.wasAir and v.Y > 15 then
			mo.takeoffAt = now
		end
	elseif mo.wasAir then
		if mo.minVy < -28 then
			mo.landAt = now
			mo.landAmt = math.clamp((-mo.minVy - 20) / 80, 0.25, 1)
			puff(root.Position - Vector3.new(0, 2.1, 0), Color3.fromRGB(235, 230, 220), math.floor(6 + mo.landAmt * 10), 6 + mo.landAmt * 8)
			if model == player.Character and mo.landAmt > 0.5 then
				SoundController.Play("Land", 0.85)
			end
		end
		mo.minVy = 0
		mo.tumbling = false
		mo.moves.Flip = nil
		if mo.moves.Swing and now - mo.moves.Swing > 0.4 then
			mo.moves.Swing = nil
		end
	end
	mo.wasAir = isAir

	-- Getting hit (the server raises Fluff on every hit).
	local fluffAttr = model:GetAttribute("Fluff")
	local fluff = typeof(fluffAttr) == "number" and fluffAttr or 0
	if fluff > mo.fluff + 0.5 then
		mo.flinchAt = now
	end
	mo.fluff = fluff
	if isAir and speed > 55 and now - mo.flinchAt < 1 and not mo.tumbling then
		mo.tumbling = true
		mo.tumble = 0
		local f = flat.Magnitude > 1 and flat.Unit or Vector3.zAxis
		mo.tumbleAxis = root.CFrame:VectorToObjectSpace(f:Cross(Vector3.yAxis))
		if fluff >= 100 then
			dizzyStars(model)
		end
	end

	-- Leaning into turns.
	local look = root.CFrame.LookVector
	local yaw = math.atan2(-look.X, -look.Z)
	local dyaw = yaw - mo.yaw
	if dyaw > math.pi then
		dyaw -= math.pi * 2
	elseif dyaw < -math.pi then
		dyaw += math.pi * 2
	end
	mo.yaw = yaw
	local leanTarget = math.clamp(-dyaw / math.max(dt, 1 / 240) * 0.04, -0.3, 0.3) * math.clamp(move, 0, 1.4)
	mo.lean += (leanTarget - mo.lean) * math.min(1, dt * 10)

	-- Standing still (idle moves, lobby sit / sleep).
	if move > 0.15 or isAir or emoting then
		mo.stillSince = now
		mo.act = nil
		mo.nextAct = now + math.random() * 4 + 4
	end
	local still = now - mo.stillSince
	local owner = Players:GetPlayerFromCharacter(model)
	local inLobby = owner ~= nil and owner:GetAttribute("Context") == "Lobby"

	-- Blinks (sometimes twice) and ear twitches.
	if now >= mo.nextBlink then
		mo.blinkAt = now
		mo.nextBlink = now + (math.random() < 0.2 and 0.25 or math.random() * 3 + 1.6)
	end
	blink = now - mo.blinkAt < 0.12
	if now >= mo.nextEar then
		mo.earAt = now
		mo.earSide = math.random() < 0.5 and -1 or 1
		mo.nextEar = now + math.random() * 5 + 2
	end
	ears.side = mo.earSide
	ears.twitch = ease((now - mo.earAt) / 0.18)

	local zone = zoneKind(root.Position)
	local wading = model:GetAttribute("Hidden") == true
	local swing = mo.moves.Swing and now - mo.moves.Swing < 3

	if emoting then
		-- The emote has the pose (CatBuilder.Pose layers it); keep it simple.
		mo.tumbling = false
	elseif swing then
		-- Hanging on to the rope: both paws up, legs dangling, swinging.
		replace.PawShoulderL = CFrame.Angles(0, 0, -2.9)
		replace.PawShoulderR = CFrame.Angles(0, 0, 2.9)
		local fwd = root.CFrame:VectorToObjectSpace(flat)
		replace.PawHipL = CFrame.Angles(math.clamp(-fwd.Z * 0.01, -0.5, 0.5) + 0.15, 0, 0)
		replace.PawHipR = CFrame.Angles(math.clamp(-fwd.Z * 0.01, -0.5, 0.5) + 0.1, 0, 0)
		body = CFrame.Angles(math.clamp(fwd.Z * 0.006, -0.4, 0.4), 0, 0)
	elseif zone then
		local p = now * 10
		if zone == "Water" or zone == "Bubbles" then
			-- Kitty-paddle: tipped forward, paws and legs going.
			body = CFrame.Angles(-1.1, 0, 0) * CFrame.new(0, 0, 0.2)
			replace.PawShoulderL = CFrame.Angles(-1.4 + math.sin(p) * 0.7, 0, -0.2)
			replace.PawShoulderR = CFrame.Angles(-1.4 - math.sin(p) * 0.7, 0, 0.2)
			replace.PawHipL = CFrame.Angles(math.sin(p + 1) * 0.5, 0, 0)
			replace.PawHipR = CFrame.Angles(-math.sin(p + 1) * 0.5, 0, 0)
		else
			-- Riding the updraft: spread out, drifting round.
			body = CFrame.Angles(0, 0, math.sin(now * 2) * 0.15)
			replace.PawShoulderL = CFrame.Angles(0, 0, -1.9 + math.sin(now * 3) * 0.1)
			replace.PawShoulderR = CFrame.Angles(0, 0, 1.9 - math.sin(now * 3) * 0.1)
			replace.PawHipL = CFrame.Angles(0.2, 0, -0.45)
			replace.PawHipR = CFrame.Angles(0.2, 0, 0.45)
			ears.flat = 0.5
		end
		mo.tumbling = false
	elseif mo.tumbling then
		-- Launched: a cartoon tumble until it lands.
		mo.tumble += dt * 13
		body = CFrame.fromAxisAngle(mo.tumbleAxis.Magnitude > 0.1 and mo.tumbleAxis.Unit or Vector3.xAxis, mo.tumble)
		replace.PawShoulderL = CFrame.Angles(math.sin(now * 20) * 0.6, 0, -1.8)
		replace.PawShoulderR = CFrame.Angles(-math.sin(now * 20) * 0.6, 0, 1.8)
		replace.PawHipL = CFrame.Angles(math.sin(now * 18) * 0.7, 0, -0.2)
		replace.PawHipR = CFrame.Angles(-math.sin(now * 18) * 0.7, 0, 0.2)
		blink = true
	else
		-- Moves.
		local flipK = mo.moves.Flip and (now - mo.moves.Flip) / 0.45
		local dashK = mo.moves.Dash and (now - mo.moves.Dash) / 0.32
		local pounceK = mo.moves.Pounce and (now - mo.moves.Pounce) / 0.7
		local wallK = mo.moves.WallKick and (now - mo.moves.WallKick) / 0.35
		if flipK and flipK < 1 then
			local e = 1 - (1 - flipK) * (1 - flipK)
			body = CFrame.Angles(-math.pi * 2 * e, 0, 0)
			replace.PawHipL = CFrame.Angles(1.3, 0, 0)
			replace.PawHipR = CFrame.Angles(1.3, 0, 0)
			if not armed then
				replace.PawShoulderL = CFrame.Angles(-0.8, 0, -0.3)
				replace.PawShoulderR = CFrame.Angles(-0.8, 0, 0.3)
			end
		elseif dashK and dashK < 1 then
			-- A low, flat dart, ears pinned back.
			local e = ease(dashK * 0.5 + 0.25)
			body = CFrame.new(0, -0.25 * e, 0) * CFrame.Angles(-0.5 * e, 0, 0)
			replace.PawHipL = CFrame.Angles(-1.0 * e, 0, 0)
			replace.PawHipR = CFrame.Angles(-1.2 * e, 0, 0)
			if not armed then
				replace.PawShoulderL = CFrame.Angles(1.1 * e, 0, -0.2)
				replace.PawShoulderR = CFrame.Angles(1.1 * e, 0, 0.2)
			end
			ears.flat = 1
		elseif pounceK and pounceK < 1 then
			-- A cat leap: front paws reaching, back legs kicking.
			local e = ease(pounceK)
			body = CFrame.Angles(0.35 * (1 - pounceK) - 0.45 * pounceK, 0, 0)
			replace.PawHipL = CFrame.Angles(-1.1 * e, 0, 0)
			replace.PawHipR = CFrame.Angles(-1.1 * e, 0, 0)
			if not armed then
				replace.PawShoulderL = CFrame.Angles(-2.4 * e, 0, -0.15)
				replace.PawShoulderR = CFrame.Angles(-2.4 * e, 0, 0.15)
			end
			addJ("PawTail", CFrame.Angles(0.6 * e, 0, 0))
			ears.flat = 0.6
		elseif wallK and wallK < 1 then
			local e = ease(wallK)
			body = CFrame.Angles(0.25 * e, 0, -0.5 * e)
			replace.PawHipL = CFrame.Angles(0.9 * e, 0, -0.5 * e)
			replace.PawHipR = CFrame.Angles(0.6 * e, 0, 0.3 * e)
		elseif wading then
			-- Wading through a ball pit: sunk in to the shoulders, bobbing.
			body = CFrame.new(0, -0.7 + math.sin(now * 3) * 0.08, 0)
			if not armed then
				replace.PawShoulderL = CFrame.Angles(-0.4, 0, -0.7)
				replace.PawShoulderR = CFrame.Angles(-0.4, 0, 0.7)
			end
		else
			-- Ordinary movement: gallop, take-off stretch, landing squash,
			-- leaning, paddling legs on the way down.
			local gallop = math.clamp((move - 1.1) / 0.4, 0, 1) * (isAir and 0 or 1)
			if gallop > 0 then
				local g = now * 15
				body = body * CFrame.new(0, math.abs(math.sin(g)) * 0.12 * gallop, 0) * CFrame.Angles(-0.12 * gallop, 0, 0)
				addJ("PawHipL", CFrame.Angles(math.sin(g) * 0.35 * gallop, 0, 0))
				addJ("PawHipR", CFrame.Angles(math.sin(g) * 0.35 * gallop, 0, 0))
				addJ("PawTail", CFrame.Angles(-0.5 * gallop, 0, 0))
				ears.flat = math.max(ears.flat, 0.4 * gallop)
			end
			local takeK = (now - mo.takeoffAt) / 0.25
			if takeK < 1 then
				local e = ease(takeK)
				body = body * CFrame.new(0, 0.15 * e, 0)
				addJ("PawHipL", CFrame.Angles(-0.3 * e, 0, 0))
				addJ("PawHipR", CFrame.Angles(-0.3 * e, 0, 0))
			end
			local landK = (now - mo.landAt) / (0.25 + mo.landAmt * 0.15)
			if landK < 1 then
				local e = ease(landK) * mo.landAmt
				body = body * CFrame.new(0, -0.3 * e, 0) * CFrame.Angles(-0.12 * e, 0, 0)
				addJ("PawHipL", CFrame.Angles(0.6 * e, 0, -0.15 * e))
				addJ("PawHipR", CFrame.Angles(0.6 * e, 0, 0.15 * e))
				if not armed then
					addJ("PawShoulderL", CFrame.Angles(0, 0, -0.5 * e))
					addJ("PawShoulderR", CFrame.Angles(0, 0, 0.5 * e))
				end
			end
			if isAir and v.Y < -10 then
				local p = now * 14
				addJ("PawHipL", CFrame.Angles(math.sin(p) * 0.35, 0, 0))
				addJ("PawHipR", CFrame.Angles(-math.sin(p) * 0.35, 0, 0))
			end
			body = body * CFrame.Angles(0, 0, mo.lean)

			-- Idle life.
			if not isAir and move < 0.15 then
				if inLobby and still > 45 then
					-- Away: curled up asleep (with a Zzz).
					body = body * CFrame.new(0, -0.55, 0)
					replace.PawHipL = CFrame.Angles(1.5, 0, -0.1)
					replace.PawHipR = CFrame.Angles(1.5, 0, 0.1)
					replace.PawNeck = CFrame.Angles(0.4, 0, 0.3 + math.sin(now * 1.5) * 0.04)
					if not armed then
						replace.PawShoulderL = CFrame.Angles(0.6, 0, -0.1)
						replace.PawShoulderR = CFrame.Angles(0.6, 0, 0.1)
					end
					blink = true
					if not mo.props.Lazy then
						mo.props.Lazy = Instance.new("Folder") -- (marks "sleeping"; the Zzz goes up below)
					end
				elseif inLobby and still > 12 then
					-- Been standing a while in the lobby: sit down.
					body = body * CFrame.new(0, -0.45, 0)
					replace.PawHipL = CFrame.Angles(1.4, 0, -0.1)
					replace.PawHipR = CFrame.Angles(1.4, 0, 0.1)
					replace.PawTail = CFrame.Angles(0, math.sin(now * 2) * 0.4, 0)
				elseif still > 3.5 then
					if not mo.act and now >= mo.nextAct then
						local pick = IDLE_ACTS[math.random(1, armed and 3 or 4)]
						mo.act, mo.actAt = pick, now
					end
					local act = mo.act
					if act then
						local k = (now - mo.actAt) / ACT_TIME[act]
						if k >= 1 then
							mo.act = nil
							mo.nextAct = now + math.random() * 4 + 5
						else
							local e = ease(k)
							if act == "Look" then
								addJ("PawNeck", CFrame.Angles(0, math.sin(k * math.pi * 2) * 0.7, 0))
							elseif act == "Stretch" then
								body = body * CFrame.new(0, -0.25 * e, 0) * CFrame.Angles(-0.35 * e, 0, 0)
								addJ("PawTail", CFrame.Angles(0.7 * e, 0, 0))
								if not armed then
									replace.PawShoulderL = CFrame.Angles(-1.6 * e, 0, -0.1)
									replace.PawShoulderR = CFrame.Angles(-1.6 * e, 0, 0.1)
								end
								blink = blink or e > 0.6
							elseif act == "Scratch" then
								replace.PawHipR = CFrame.Angles(1.8 * e + math.sin(now * 30) * 0.15 * e, 0, -0.3 * e)
								addJ("PawNeck", CFrame.Angles(0, 0, 0.3 * e))
								blink = blink or e > 0.5
							elseif act == "Lick" then
								replace.PawShoulderR = CFrame.Angles(-2.0 * e, 0, 0.4 * e)
								addJ("PawNeck", CFrame.Angles(0.3 * e + math.sin(now * 14) * 0.05 * e, 0, 0.15 * e))
								blink = blink or e > 0.5
							end
						end
					end
				end
			end
		end

		-- Combat on top of whatever it's doing.
		local recK = (now - mo.recoilAt) / 0.18
		if recK < 1 then
			local e = (1 - recK) * mo.recoilAmt
			addJ("PawShoulderL", CFrame.Angles(0.45 * e, 0, 0))
			addJ("PawShoulderR", CFrame.Angles(0.45 * e, 0, 0))
			body = body * CFrame.Angles(0.07 * e, 0, 0)
			addJ("PawTail", CFrame.Angles(0, 0.5 * e, 0))
		end
		local flinchK = (now - mo.flinchAt) / 0.3
		if flinchK < 1 then
			local e = ease(flinchK)
			addJ("PawNeck", CFrame.Angles(-0.35 * e, 0, 0))
			body = body * CFrame.new(0, 0, 0.2 * e) * CFrame.Angles(0.12 * e, 0, 0)
			blink = true
			ears.flat = math.max(ears.flat, e)
		end
		if fluff >= 100 and not isAir and move < 0.5 then
			-- Nervous at high %: puffed-up tail, ears back, a little shiver.
			replace.PawTail = CFrame.Angles(0.8, math.sin(now * 30) * 0.06, 0)
			body = body * CFrame.Angles(0, 0, math.sin(now * 38) * 0.012)
			ears.flat = math.max(ears.flat, 0.7)
		end
	end

	-- Spawning in: a quick shake-off.
	local spawnK = (now - mo.spawnAt) / 0.9
	if spawnK < 1 and not emoting then
		body = body * CFrame.Angles(0, 0, math.sin(spawnK * 30) * 0.25 * (1 - spawnK))
	end

	-- Sleep-in-the-lobby Zzz (and clear it on waking).
	if mo.props.Lazy and not (inLobby and still > 45 and not emoting) then
		mo.props.Lazy:Destroy()
		mo.props.Lazy = nil
	end

	return { body = body, add = add, replace = replace, blink = blink, ears = ears }
end

function CatAnimator.Start()
	Remotes.Get("YouWereHit").OnClientEvent:Connect(function()
		lastHurtAt = os.clock()
	end)
	-- Other players' moves.
	Remotes.Get("MoveFx").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and typeof(data.char) == "Instance" and data.char:IsA("Model") and type(data.kind) == "string" then
			CatAnimator.Trigger(data.char, data.kind)
		end
	end)
	-- Other cats' shots kick their arms (the shot starts at their muzzle).
	Remotes.Get("PlayEffect").OnClientEvent:Connect(function(data)
		if typeof(data) ~= "table" or data.kind ~= "Tracers" or typeof(data.from) ~= "Vector3" then
			return
		end
		local best: Model?, bestD = nil, 5
		for _, inst in ipairs(CollectionService:GetTagged(CatBuilder.Tag)) do
			if inst:IsA("Model") and inst.PrimaryPart and inst ~= player.Character then
				local d = ((inst.PrimaryPart :: BasePart).Position - data.from).Magnitude
				if d < bestD then
					best, bestD = inst, d
				end
			end
		end
		if best then
			CatAnimator.Trigger(best, "Recoil", HEAVY[data.weapon] and 1.6 or 1)
		end
	end)
	-- A new cat appearing (spawn): a puff of sparkle dust.
	CollectionService:GetInstanceAddedSignal(CatBuilder.Tag):Connect(function(inst)
		task.defer(function()
			if inst:IsA("Model") and inst.PrimaryPart and inst:IsDescendantOf(Workspace) and inst:GetAttribute("Replay") == nil then
				motionOf(inst).spawnAt = os.clock()
				puff((inst.PrimaryPart :: BasePart).Position - Vector3.new(0, 1.6, 0), Color3.fromRGB(255, 250, 230), 14, 10)
			end
		end)
	end)
	refreshZones()
	CollectionService:GetInstanceAddedSignal("SwimZone"):Connect(refreshZones)
	CollectionService:GetInstanceRemovedSignal("SwimZone"):Connect(refreshZones)

	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		t += dt
		local now = os.clock()
		local camPos = Workspace.CurrentCamera.CFrame.Position
		for _, inst in ipairs(CollectionService:GetTagged(CatBuilder.Tag)) do
			local root = inst:IsA("Model") and inst.PrimaryPart
			if root then
				local model = inst :: Model
				local move, air = 0, 0
				local inWorld = model:IsDescendantOf(Workspace)
				if not inWorld or (root.Position - camPos).Magnitude <= MAX_DIST then
					local fx: CatBuilder.PoseFx? = nil
					if inWorld then
						local v = root.AssemblyLinearVelocity
						move = Vector3.new(v.X, 0, v.Z).Magnitude / GameConfig.Character.WalkSpeed
						air = math.clamp((math.abs(v.Y) - 6) / 14, 0, 1)
						local speed = v.Magnitude
						local p = root.Position
						if speed > 40 and (Vector3.new(p.X, 0, p.Z).Magnitude > OFF_MAP or p.Y < -40) and os.clock() - (twinkled[model] or 0) > 4 then
							twinkled[model] = os.clock()
							blastOff(p)
						end
						local trail = trails[model]
						if speed > TRAIL_ON then
							local tr = trailFor(model, root)
							-- Only real launches thump: going up fast, and for your own cat only
							-- right after a hit (not your own dash / pounce).
							local mine = model == player.Character
							if not tr.Enabled and v.Y > 12 and model:GetAttribute("Replay") == nil and (not mine or os.clock() - lastHurtAt < 0.5) then
								SoundController.Launch(root.Position)
							end
							tr.Enabled = true
						elseif trail and speed < TRAIL_OFF then
							trail.Enabled = false
						end
						if model:GetAttribute("Replay") == nil then
							local emote = model:GetAttribute("Emote")
							local emoteAt = model:GetAttribute("EmoteAt")
							local k = (typeof(emote) == "string" and typeof(emoteAt) == "number") and (Workspace:GetServerTimeNow() - emoteAt) or math.huge
							local emoting = k >= 0 and k < CatBuilder.EmoteSeconds
							local mo = motionOf(model)
							fx = buildFx(model, root, mo, now, dt, move, emoting, model:GetAttribute("Armed") == true)
							emoteProps(model, mo, emoting and emote :: string or (mo.props.Lazy and "Sleep" or nil), root)
						end
					end
					local seed = model:GetAttribute("PoseSeed")
					CatBuilder.Pose(model, t + (typeof(seed) == "number" and seed or 0), move, air, fx)
				end
			end
		end
	end)
end

return CatAnimator
