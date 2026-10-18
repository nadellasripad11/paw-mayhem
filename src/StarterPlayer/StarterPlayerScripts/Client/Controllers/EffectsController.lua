--!strict
-- EffectsController: world + screen VFX driven by server events.
--   PlayEffect(Tracer)  -> neon bolt from muzzle to hit point
--   PlayEffect(Tracers) -> one shot's pellets (other players' shots; your own
--                          are drawn instantly by CombatController)
--   YouWereHit          -> camera shake + red screen flash
--   HitConfirm          -> hitmarker callback (HUD draws it)
--   PowerUpTaken/Spawned -> pickup sparkle
-- Purely cosmetic; no gameplay authority here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Weapons = require(Shared.Config.Weapons)
local WeaponFX = require(Shared.Config.WeaponFX)

local CameraController = require(script.Parent.CameraController)
local SoundController = require(script.Parent.SoundController)
local CatOverheads = require(script.Parent.CatOverheads)
local ClientState = require(script.Parent.Parent.ClientState)

local EffectsController = {}
local player = Players.LocalPlayer

-- Callbacks the HUD can hook.
EffectsController.OnHitConfirm = nil :: ((data: any) -> ())?
EffectsController.OnHurt = nil :: ((data: any) -> ())?

local flashGui: ScreenGui? = nil
local flashFrame: Frame? = nil

local function ensureFlash()
	if flashFrame and flashFrame.Parent then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "PawHurtFlash"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.Parent = player:WaitForChild("PlayerGui")
	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = gui
	flashGui = gui
	flashFrame = frame
end

local function flashHurt()
	ensureFlash()
	local frame = flashFrame :: Frame
	frame.BackgroundTransparency = 0.55
	task.spawn(function()
		for i = 1, 12 do
			frame.BackgroundTransparency = 0.55 + i * 0.0375
			task.wait(0.02)
		end
		frame.BackgroundTransparency = 1
	end)
end

local function fxPart(shape: Enum.PartType?, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = material or Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = workspace
	return p
end

-- The cat a shot landed on (its body is within reach of the impact), if any.
local function catAt(pos: Vector3): Model?
	for _, m in ipairs(CollectionService:GetTagged("PawCat")) do
		local r = m:IsA("Model") and m.PrimaryPart
		if r and m:IsDescendantOf(workspace) and (r.Position - pos).Magnitude < 3.6 then
			return m
		end
	end
	return nil
end

-- A burst of fur tufts in the struck cat's colour.
local function fluffPuff(pos: Vector3, cat: Model, amount: number)
	local fur = cat:FindFirstChild("HeadFur", true) or cat:FindFirstChild("Head")
	local color = fur and fur:IsA("BasePart") and fur.Color or Color3.fromRGB(255, 240, 225)
	local anchor = fxPart(nil, Vector3.one * 0.2, CFrame.new(pos), color)
	anchor.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.25), color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1.3) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(0.35, 0.6)
	e.Speed = NumberRange.new(6, 13)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Drag = 6
	e.Acceleration = Vector3.new(0, -8, 0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Enabled = false
	e.Parent = anchor
	e:Emit(amount)
	Debris:AddItem(anchor, 1)
end

-- One shot's bolt from `from` to `to`, drawn in its blaster's style.
local function drawTracer(from: Vector3, to: Vector3, color: Color3, weaponId: string?)
	local dist = (to - from).Magnitude
	if dist < 0.1 then
		return
	end
	local style = WeaponFX.Style(weaponId)
	local look = CFrame.lookAt(from, to)

	if style.bubbles then
		-- A stream of soapy bubbles drifting along the shot.
		local n = math.clamp(math.floor(dist / 6), 3, 10)
		for i = 1, n do
			local pos = from:Lerp(to, i / n)
			local d = 0.45 + math.random() * 0.45
			local b = fxPart(Enum.PartType.Ball, Vector3.one * d, CFrame.new(pos), color:Lerp(Color3.new(1, 1, 1), 0.4), Enum.Material.Glass)
			b.Transparency = 0.45
			TweenService:Create(b, TweenInfo.new(style.life + i * 0.03), {
				Position = pos + Vector3.new(math.random() - 0.5, 1 + math.random(), math.random() - 0.5),
				Size = Vector3.one * d * 1.5, Transparency = 1,
			}):Play()
			Debris:AddItem(b, style.life + i * 0.03 + 0.05)
		end
	else
		-- A soft glow around a crisp bright core.
		if style.glow > 0 then
			local glow = fxPart(nil, Vector3.new(style.glow, style.glow, dist), look * CFrame.new(0, 0, -dist / 2), color)
			glow.Transparency = 0.5
			TweenService:Create(glow, TweenInfo.new(style.life), { Transparency = 1, Size = Vector3.new(style.glow * 0.3, style.glow * 0.3, dist) }):Play()
			Debris:AddItem(glow, style.life + 0.02)
		end
		local core = fxPart(nil, Vector3.new(style.core, style.core, dist), look * CFrame.new(0, 0, -dist / 2), color:Lerp(Color3.new(1, 1, 1), 0.35))
		Debris:AddItem(core, style.life)
	end

	-- Impact: sparks, a shock ring for heavy hitters, ice shards for frost.
	for i = 1, style.sparks do
		local angle = (math.pi * 2 / style.sparks) * i
		local spark = fxPart(Enum.PartType.Ball, Vector3.one * 0.55, CFrame.new(to), color)
		local out = Vector3.new(math.cos(angle), math.sin(angle * 2) * 0.45 + 0.3, math.sin(angle)) * (1.2 + math.random())
		TweenService:Create(spark, TweenInfo.new(0.18), { Position = to + out, Size = Vector3.one * 0.1 }):Play()
		Debris:AddItem(spark, 0.2)
	end
	if style.ring then
		local ring = fxPart(Enum.PartType.Ball, Vector3.one * 1, CFrame.new(to), color)
		ring.Transparency = 0.3
		TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * style.ring, Transparency = 1 }):Play()
		Debris:AddItem(ring, 0.27)
	end
	if style.shards then
		for i = 1, 5 do
			local shard = fxPart(nil, Vector3.new(0.18, 0.18, 0.9), CFrame.lookAt(to, to + Vector3.new(math.random() - 0.5, math.random(), math.random() - 0.5)), Color3.fromRGB(210, 245, 255), Enum.Material.Ice)
			shard.Transparency = 0.2
			TweenService:Create(shard, TweenInfo.new(0.4), { Transparency = 1, Position = shard.Position + shard.CFrame.LookVector * 1.4 }):Play()
			Debris:AddItem(shard, 0.42)
		end
	end

	local cat = catAt(to)
	if cat then
		local w = weaponId and Weapons.Get(weaponId)
		fluffPuff(to, cat, math.clamp(math.floor((w and w.Damage or 14) / 2.5), 4, 16))
	end
end

local function pickupSparkle(pos: Vector3, color: Color3)
	local burst = Instance.new("Part")
	burst.Shape = Enum.PartType.Ball
	burst.Anchored = true
	burst.CanCollide = false
	burst.CanQuery = false
	burst.Material = Enum.Material.Neon
	burst.Color = color
	burst.Size = Vector3.new(3, 3, 3)
	burst.Position = pos
	burst.Transparency = 0.2
	burst.Parent = workspace
	task.spawn(function()
		for i = 1, 10 do
			burst.Size = burst.Size + Vector3.new(1, 1, 1)
			burst.Transparency = 0.2 + i * 0.08
			task.wait(0.02)
		end
		burst:Destroy()
	end)
	for i = 1, 6 do
		local shard = Instance.new("Part")
		shard.Shape = Enum.PartType.Ball
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanQuery = false
		shard.Material = Enum.Material.Neon
		shard.Color = color
		shard.Size = Vector3.new(0.45, 0.45, 0.45)
		shard.Position = pos
		shard.Parent = workspace
		local angle = (math.pi * 2 / 6) * i
		task.spawn(function()
			for step = 1, 7 do
				shard.Position += Vector3.new(math.cos(angle) * 0.32, 0.22, math.sin(angle) * 0.32)
				shard.Transparency = step / 8
				task.wait(0.025)
			end
			shard:Destroy()
		end)
	end
end

-- Floating "+X%" that pops up over the cat you hit, coloured like its
-- knockback % (white -> yellow -> orange -> red). Hits on the same cat in
-- quick succession add into one number instead of flooding the screen.
type Stack = { anchor: Part, label: TextLabel, scale: UIScale, total: number, at: number, fade: Tween? }
local stacks: { [string]: Stack } = {}

local function percentNumber(key: string, pos: Vector3, amount: number, accumulated: number)
	local now = os.clock()
	local st = stacks[key]
	if not (st and now - st.at < 0.5 and st.anchor.Parent) then
		local anchor = Instance.new("Part")
		anchor.Size = Vector3.one * 0.1
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CFrame = CFrame.new(pos + Vector3.new((math.random() - 0.5) * 1.5, 3, (math.random() - 0.5) * 1.5))
		anchor.Parent = workspace
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromOffset(110, 44)
		gui.AlwaysOnTop = true
		gui.LightInfluence = 0
		gui.Parent = anchor
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextStrokeTransparency = 0.15
		label.Parent = gui
		local scale = Instance.new("UIScale")
		scale.Parent = label
		TweenService:Create(anchor, TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = anchor.CFrame + Vector3.new(0, 2.5, 0) }):Play()
		st = { anchor = anchor, label = label, scale = scale, total = 0, at = now, fade = nil }
		stacks[key] = st
	end
	local s = st :: Stack
	s.total += amount
	s.at = now
	s.label.Text = "+" .. tostring(math.floor(s.total + 0.5)) .. "%"
	s.label.TextColor3 = CatOverheads.FluffColor(accumulated)
	s.label.TextTransparency = 0
	s.label.TextStrokeTransparency = 0.15
	s.scale.Scale = 1.45
	TweenService:Create(s.scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 + math.min(s.total / 120, 0.5) }):Play()
	if s.fade then
		s.fade:Cancel()
	end
	local fade = TweenService:Create(s.label, TweenInfo.new(0.35, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.55), { TextTransparency = 1, TextStrokeTransparency = 1 })
	s.fade = fade
	fade.Completed:Connect(function(state)
		if state == Enum.PlaybackState.Completed then
			s.anchor:Destroy()
			if stacks[key] == s then
				stacks[key] = nil
			end
		end
	end)
	fade:Play()
end

-- The knockout burst where a cat went off the map (or dropped): a white
-- flash, a shock ring in its team colour, a column of light and sparks,
-- with a boom and a shake if you're close.
local function ringout(pos: Vector3, color: Color3)
	local flash = fxPart(Enum.PartType.Ball, Vector3.one * 4, CFrame.new(pos), Color3.new(1, 1, 1))
	TweenService:Create(flash, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 22, Transparency = 1 }):Play()
	local ring = fxPart(Enum.PartType.Cylinder, Vector3.new(0.4, 6, 6), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color)
	TweenService:Create(ring, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.2, 48, 48), Transparency = 1 }):Play()
	local beam = fxPart(Enum.PartType.Cylinder, Vector3.new(90, 3.2, 3.2), CFrame.new(pos + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90)), color)
	beam.Transparency = 0.15
	TweenService:Create(beam, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = Vector3.new(90, 0.2, 0.2), Transparency = 1 }):Play()
	local holder = fxPart(nil, Vector3.one * 0.2, CFrame.new(pos), color)
	holder.Transparency = 1
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	sparks.Size = NumberSequence.new(1.2, 0)
	sparks.Lifetime = NumberRange.new(0.5, 0.9)
	sparks.Speed = NumberRange.new(30, 60)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Drag = 3
	sparks.LightEmission = 1
	sparks.Rate = 0
	sparks.Parent = holder
	sparks:Emit(45)
	local glow = Instance.new("PointLight")
	glow.Color = color
	glow.Range = 45
	glow.Brightness = 6
	glow.Parent = holder
	TweenService:Create(glow, TweenInfo.new(0.7), { Brightness = 0 }):Play()
	for _, p in ipairs({ flash, ring, beam, holder }) do
		Debris:AddItem(p, 1.2)
	end
	SoundController.PlayAt("Knockout", pos, 0.75)
	local dist = (workspace.CurrentCamera.CFrame.Position - pos).Magnitude
	if dist < 90 then
		CameraController.AddShake(1.4 * (1 - dist / 90))
	end
end

-- Expanding flash for big pickups (supply crates).
local function burst(pos: Vector3, color: Color3)
	local ball = Instance.new("Part")
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 2
	ball.CFrame = CFrame.new(pos)
	ball.Color = color
	ball.Material = Enum.Material.Neon
	ball.Anchored = true
	ball.CanCollide = false
	ball.CanQuery = false
	ball.CanTouch = false
	ball.CastShadow = false
	ball.Parent = workspace
	local t = TweenService:Create(ball, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * 14, Transparency = 1 })
	t.Completed:Connect(function()
		ball:Destroy()
	end)
	t:Play()
	pickupSparkle(pos, color)
end

-- Gold coins tumbling down around the camera (Coin Rain purchase).
local function coinRain()
	local cam = workspace.CurrentCamera.CFrame.Position
	for i = 1, 45 do
		task.delay(i * 0.05, function()
			local coin = Instance.new("Part")
			coin.Shape = Enum.PartType.Cylinder
			coin.Size = Vector3.new(0.25, 1.4, 1.4)
			coin.Color = Color3.fromRGB(255, 206, 60)
			coin.Material = Enum.Material.Neon
			coin.Anchored = true
			coin.CanCollide = false
			coin.CanQuery = false
			coin.CanTouch = false
			coin.CastShadow = false
			local start = cam + Vector3.new((math.random() - 0.5) * 50, 18 + math.random() * 10, (math.random() - 0.5) * 50)
			coin.CFrame = CFrame.new(start)
			coin.Parent = workspace
			local t = TweenService:Create(coin, TweenInfo.new(1.6, Enum.EasingStyle.Linear), {
				CFrame = CFrame.new(start - Vector3.new(0, 34, 0)) * CFrame.Angles(math.random() * 12, math.random() * 12, 0),
			})
			t.Completed:Connect(function()
				coin:Destroy()
			end)
			t:Play()
		end)
	end
end

-- Multi-coloured confetti burst (Trail Pack eliminations).
local function confetti(pos: Vector3)
	local anchor = Instance.new("Part")
	anchor.Size = Vector3.one * 0.2
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0))
	anchor.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 120)),
		ColorSequenceKeypoint.new(0.33, Color3.fromRGB(255, 220, 80)),
		ColorSequenceKeypoint.new(0.66, Color3.fromRGB(90, 220, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 110, 255)),
	})
	e.LightEmission = 0.7
	e.Size = NumberSequence.new(0.6, 0.2)
	e.Lifetime = NumberRange.new(0.9, 1.6)
	e.Speed = NumberRange.new(14, 26)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Acceleration = Vector3.new(0, -25, 0)
	e.RotSpeed = NumberRange.new(-300, 300)
	e.Rate = 0
	e.Parent = anchor
	e:Emit(70)
	task.delay(2, function()
		anchor:Destroy()
	end)
end

-- Draw one shot's bolts (all its pellets) from the muzzle.
function EffectsController.Tracers(from: Vector3, tos: { Vector3 }, color: Color3, weaponId: string?)
	for _, to in ipairs(tos) do
		drawTracer(from, to, color, weaponId)
	end
end

function EffectsController.Start()
	Remotes.Get("PlayEffect").OnClientEvent:Connect(function(data)
		if type(data) ~= "table" then
			return
		end
		if data.kind == "Tracer" then
			drawTracer(data.from, data.to, data.color or Color3.fromRGB(180, 120, 255))
		elseif data.kind == "Tracers" and typeof(data.from) == "Vector3" and type(data.tos) == "table" then
			local tos = {}
			for _, to in ipairs(data.tos) do
				if typeof(to) == "Vector3" then
					table.insert(tos, to)
				end
			end
			EffectsController.Tracers(data.from, tos, data.color or Color3.fromRGB(180, 120, 255), typeof(data.weapon) == "string" and data.weapon or nil)
		elseif data.kind == "Burst" and typeof(data.position) == "Vector3" then
			burst(data.position, data.color or Color3.fromRGB(255, 204, 64))
		elseif data.kind == "CoinRain" then
			coinRain()
		elseif data.kind == "Confetti" and typeof(data.position) == "Vector3" then
			confetti(data.position)
		elseif data.kind == "Ringout" and typeof(data.position) == "Vector3" then
			ringout(data.position, typeof(data.color) == "Color3" and data.color or Color3.fromRGB(255, 200, 90))
		end
	end)

	Remotes.Get("YouWereHit").OnClientEvent:Connect(function(data)
		-- The more fluff you carry, the harder each hit rocks the screen.
		local acc = type(data) == "table" and tonumber(data.accumulated) or 0
		CameraController.AddShake(0.3 + math.min((acc or 0) / 150, 1) * 0.7)
		if ClientState.Settings.ShowDamage then
			flashHurt()
		end
		if EffectsController.OnHurt then
			EffectsController.OnHurt(data)
		end
	end)

	Remotes.Get("HitConfirm").OnClientEvent:Connect(function(data)
		if type(data) == "table" and typeof(data.position) == "Vector3" and type(data.damage) == "number" then
			percentNumber(tostring(data.victim or "?"), data.position, data.damage, tonumber(data.accumulated) or 0)
		end
		-- Landing a hit on a cat that's about to fly: punch the view in.
		local acc = type(data) == "table" and tonumber(data.accumulated) or 0
		if acc and acc >= 90 then
			CameraController.Punch(3 + math.min((acc - 90) / 30, 1) * 4)
		end
		if EffectsController.OnHitConfirm then
			EffectsController.OnHitConfirm(data)
		end
	end)

	Remotes.Get("PowerUpTaken").OnClientEvent:Connect(function(data)
		if data and data.position then
			pickupSparkle(data.position, data.color or Color3.fromRGB(255, 255, 255))
		end
	end)

	Remotes.Get("PowerUpSpawned").OnClientEvent:Connect(function(data)
		if data and data.position then
			pickupSparkle(data.position, data.color or Color3.fromRGB(255, 255, 255))
		end
	end)
end

return EffectsController
