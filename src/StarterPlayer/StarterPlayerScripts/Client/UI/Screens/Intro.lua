--!strict
-- Intro: what a brand-new player sees first.
--   1. A short cinematic in the lobby: cats trading shots until one gets
--      blasted off the edge (letterboxed, skippable).
--   2. A hands-on lesson at the lobby's practice range with Mochi, a mentor
--      cat who talks you through each move and demonstrates it: walk to the
--      ring, jump, double jump, shoot a target, knock one off, dash, pounce.
--      Each step completes when you actually do it. Skippable; finishing marks
--      the tutorial done.
-- Everything here is local to the new player (the lobby itself is shared).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Controllers = script.Parent.Parent.Parent.Controllers
local CameraController = require(Controllers.CameraController)
local EffectsController = require(Controllers.EffectsController)
local SoundController = require(Controllers.SoundController)
local MovementController = require(Controllers.MovementController)

local Intro = {}
Intro.Running = false -- the lobby UI leaves the screen alone while it's on

local player = Players.LocalPlayer

local function isMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- The lobby folder and one of its staging points ("Stage" for the
-- cinematic, "Range" for the lesson), plus the ground height.
local function lobby(point: string): (Folder?, Vector3, number)
	local f = Workspace:FindFirstChild("Lobby") :: Folder?
	local c = f and f:GetAttribute(point)
	local s = f and f:GetAttribute("Surface")
	if not f or typeof(c) ~= "Vector3" or typeof(s) ~= "number" then
		return nil, Vector3.zero, 0
	end
	return f, c :: Vector3, s :: number
end

-- A local, anchored cat standing at `pos` facing `lookAt`.
local function actor(custom: any, name: string, weaponId: string?, pos: Vector3, lookAt: Vector3, parent: Instance): Model
	local m = CatBuilder.Build(custom, name, weaponId and { Id = weaponId } or nil)
	m.Name = name
	m:SetAttribute("NoOverhead", true) -- actors: no name / % tag
	for _, d in ipairs(m:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		end
	end
	local root = m.PrimaryPart :: BasePart
	root.Anchored = true
	m:PivotTo(CFrame.lookAt(pos, Vector3.new(lookAt.X, pos.Y, lookAt.Z)))
	m.Parent = parent
	return m
end

local function muzzle(m: Model): Vector3
	local tip = m:FindFirstChild("MuzzlePoint", true)
	if tip and tip:IsA("BasePart") then
		return tip.Position
	end
	return (m.PrimaryPart :: BasePart).Position + Vector3.new(0, 0.8, 0)
end

local function shoot(from: Model, at: Model, weaponId: string)
	local w = Weapons.Get(weaponId)
	local p = muzzle(from)
	EffectsController.Tracers(p, { (at.PrimaryPart :: BasePart).Position }, w and w.TrailColor or Color3.new(1, 1, 1), weaponId)
	SoundController.PlayShot(weaponId, p)
end

local function letterbox(): (ScreenGui, TextLabel, TextButton)
	local gui = Instance.new("ScreenGui")
	gui.Name = "PawIntro"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 70
	gui.Parent = player:WaitForChild("PlayerGui")
	for _, top in ipairs({ true, false }) do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.fromScale(1, 0.12)
		bar.Position = top and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 0.88)
		bar.Parent = gui
	end
	local caption = UIUtil.label({
		Parent = gui, Text = "", Font = Theme.Font.Title, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.94), Size = UDim2.new(1, 0, 0.06, 0),
		TextTransparency = 1,
	})
	local skip = UIUtil.make("TextButton", {
		Parent = gui, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -24, 0.06, 0), Size = UDim2.fromOffset(90, 30),
		Text = "SKIP  ›", Font = Theme.Font.Bold, TextSize = 14, TextColor3 = Color3.fromRGB(220, 220, 230),
		BackgroundTransparency = 1,
	}) :: TextButton
	return gui, caption, skip
end

local function say(label: TextLabel, text: string)
	label.Text = text
	label.TextTransparency = 1
	TweenService:Create(label, TweenInfo.new(0.35), { TextTransparency = 0 }):Play()
end

-- ── 1. cinematic ─────────────────────────────────────────────────────────────
local function cinematic(done: () -> ())
	local _, c, s = lobby("Stage")
	if c == Vector3.zero then
		done()
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "IntroCast"
	folder.Parent = Workspace
	local y = s + 1.9
	local a = actor({ Fur = "Orange", Outfit = "Hoodie" }, "A", "PawBlaster", c + Vector3.new(-10, y - c.Y, 4), c + Vector3.new(8, 0, 6), folder)
	local b = actor({ Fur = "Black", Outfit = "Hoodie" }, "B", "BoomPaw", c + Vector3.new(8, y - c.Y, 6), c + Vector3.new(-10, 0, 4), folder)
	local cc = actor({ Fur = "Blue", Outfit = "Hoodie" }, "C", "RapidPaw", c + Vector3.new(-4, y - c.Y, -8), c + Vector3.new(12, 0, -6), folder)
	local d = actor({ Fur = "Purple", Outfit = "Hoodie" }, "D", "Starfall", c + Vector3.new(12, y - c.Y, -6), c + Vector3.new(-4, 0, -8), folder)
	local base = {}
	for _, m in ipairs({ a, b, cc, d }) do
		base[m] = m:GetPivot()
	end
	-- B's launch trail.
	local broot = b.PrimaryPart :: BasePart
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 1.1, 0), Vector3.new(0, -0.9, 0)
	a0.Parent, a1.Parent = broot, broot
	local trail = Instance.new("Trail")
	trail.Attachment0, trail.Attachment1 = a0, a1
	trail.Lifetime = 0.4
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Enabled = false
	trail.Parent = broot

	local gui, caption, skipButton = letterbox()
	local finished = false
	local conn: RBXScriptConnection? = nil
	local function finish()
		if finished then
			return
		end
		finished = true
		if conn then
			conn:Disconnect()
		end
		CameraController.SetOverride(nil)
		folder:Destroy()
		gui:Destroy()
		done()
	end
	skipButton.MouseButton1Click:Connect(finish)

	local t, nextShot, stage = 0, 0, 0
	local camCF: CFrame? = nil
	local launchFrom = base[b]
	conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		-- Everyone strafes a little while they fight.
		for i, m in ipairs({ a, cc, d }) do
			m:PivotTo(base[m] * CFrame.new(math.sin(t * 2 + i) * 1.2, 0, 0))
		end
		local want: CFrame
		if t < 3.2 then
			if stage == 0 then
				stage = 1
				say(caption, "PAW MAYHEM")
			end
			if t > nextShot then
				nextShot = t + 0.35
				shoot(cc, d, "RapidPaw")
				shoot(d, cc, "Starfall")
			end
			b:PivotTo(base[b] * CFrame.new(math.sin(t * 2) * 1.2, 0, 0))
			local ang = t * 0.35
			want = CFrame.lookAt(c + Vector3.new(math.cos(ang) * 38, y - c.Y + 16, math.sin(ang) * 38), c + Vector3.new(0, y - c.Y, 0))
		elseif t < 6 then
			if stage == 1 then
				stage = 2
				say(caption, "Every hit makes them fly further...")
			end
			if t > nextShot then
				nextShot = t + 0.2
				shoot(a, b, "PawBlaster")
			end
			b:PivotTo(base[b] * CFrame.new(math.sin(t * 2) * 1.2, 0, 0))
			launchFrom = b:GetPivot()
			-- Over A's right shoulder, looking at B (not through A's head).
			local ap = (a.PrimaryPart :: BasePart).Position
			local bp = (b.PrimaryPart :: BasePart).Position
			local back = ((ap - bp) * Vector3.new(1, 0, 1)).Unit
			local right = Vector3.new(-back.Z, 0, back.X)
			want = CFrame.lookAt(ap + back * 7 + right * 3.5 + Vector3.new(0, 2.2, 0), bp + Vector3.new(0, 0.5, 0))
		elseif t < 9.5 then
			if stage == 2 then
				stage = 3
				say(caption, "...right off the map!")
				trail.Enabled = true
				SoundController.Launch(broot.Position)
				shoot(a, b, "BoomPaw")
			end
			-- An arc up and away from A, off the edge.
			local u = t - 6
			local away = (launchFrom.Position - (a.PrimaryPart :: BasePart).Position) * Vector3.new(1, 0, 1)
			away = away.Magnitude > 0.1 and away.Unit or Vector3.xAxis
			local p = launchFrom.Position + away * (u * 22) + Vector3.new(0, 14 * u - 6 * u * u, 0)
			b:PivotTo(CFrame.new(p) * launchFrom.Rotation * CFrame.Angles(u * 3, 0, u * 2))
			if stage == 3 and u > 1.4 then
				stage = 4
				SoundController.PlayAt("Knockout", p, 1.3)
			end
			want = CFrame.lookAt(launchFrom.Position + Vector3.new(-away.Z, 0, away.X) * 26 + Vector3.new(0, 8, 0), p)
		else
			finish()
			return
		end
		camCF = camCF and camCF:Lerp(want, math.clamp(dt * 4, 0, 1)) or want
		CameraController.SetOverride(camCF)
	end)
end

-- ── 2. the lesson ────────────────────────────────────────────────────────────
type Step = { text: string, done: () -> boolean, demo: (() -> ())? }

local function lesson(done: (finished: boolean) -> ())
	local isl, c, s = lobby("Range")
	if not isl then
		done(false)
		return
	end
	-- Wait for our cat in the lobby.
	local function inLobby(): boolean
		return player:GetAttribute("Context") == "Lobby" and player.Character ~= nil and player.Character.PrimaryPart ~= nil
	end
	local t0 = os.clock()
	while not inLobby() do
		if os.clock() - t0 > 15 then
			done(false)
			return
		end
		task.wait(0.1)
	end
	task.wait(0.5)

	local folder = Instance.new("Folder")
	folder.Name = "Lesson"
	folder.Parent = Workspace
	local y = s + 1.9
	local mentorPos = c + Vector3.new(5, y - c.Y, 6)
	local mentor = actor({ Fur = "White", Outfit = "Hoodie", Hat = "Cap" }, "Mochi", "PawBlaster", mentorPos, c + Vector3.new(-6, 0, 14), folder)
	local mentorBase = mentor:GetPivot()

	-- Dialogue panel (bottom): name + text, typed out.
	local gui = Instance.new("ScreenGui")
	gui.Name = "PawLesson"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local panel = UIUtil.make("Frame", {
		Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -130), Size = UDim2.fromOffset(560, 86),
		BackgroundColor3 = Theme.Color.PanelDark, BackgroundTransparency = 0.12, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(0, 14), panel)
	UIUtil.stroke(Color3.fromRGB(255, 214, 90), 2, panel)
	UIUtil.label({ Parent = panel, Text = "MOCHI", Font = Theme.Font.Title, TextSize = 16, TextColor3 = Color3.fromRGB(255, 214, 90), Position = UDim2.fromOffset(18, 10), Size = UDim2.new(1, -36, 0, 20) })
	local text = UIUtil.label({ Parent = panel, Text = "", Font = Theme.Font.Bold, TextSize = 18, TextWrapped = true, Position = UDim2.fromOffset(18, 32), Size = UDim2.new(1, -36, 0, 46), TextYAlignment = Enum.TextYAlignment.Top })
	local progress = UIUtil.label({ Parent = panel, Text = "", TextSize = 12, TextColor3 = Theme.Color.TextDim, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 12), Size = UDim2.fromOffset(80, 16), TextXAlignment = Enum.TextXAlignment.Right })
	local skip = UIUtil.make("TextButton", {
		Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -100), Size = UDim2.fromOffset(160, 24),
		Text = "skip tutorial", Font = Theme.Font.Bold, TextSize = 13, TextColor3 = Theme.Color.TextDim, BackgroundTransparency = 1,
	}) :: TextButton

	local typing = 0
	local function speak(line: string)
		typing += 1
		local token = typing
		task.spawn(function()
			for i = 1, #line do
				if token ~= typing then
					return
				end
				text.Text = string.sub(line, 1, i)
				task.wait(0.018)
			end
		end)
	end

	-- Mochi demonstrates: a hop, or a few shots at a target.
	local function hop()
		task.spawn(function()
			for k = 0, 10 do
				mentor:PivotTo(mentorBase * CFrame.new(0, math.sin(k / 10 * math.pi) * 3, 0))
				task.wait(0.03)
			end
			mentor:PivotTo(mentorBase)
		end)
	end
	local function target(): Model?
		for _, m in ipairs(isl:GetDescendants()) do
			if m:IsA("Model") and m:GetAttribute("IsDummy") then
				return m
			end
		end
		return nil
	end
	local function demoShots()
		local tg = target()
		if not tg or not tg.PrimaryPart then
			return
		end
		mentor:PivotTo(CFrame.lookAt(mentorBase.Position, Vector3.new(tg.PrimaryPart.Position.X, mentorBase.Y, tg.PrimaryPart.Position.Z)))
		task.spawn(function()
			for _ = 1, 3 do
				shoot(mentor, tg, "PawBlaster")
				task.wait(0.25)
			end
			task.wait(0.4)
			mentor:PivotTo(mentorBase)
		end)
	end

	-- What each step waits for.
	local ring = Instance.new("Part")
	ring.Name = "LessonRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 6, 6)
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 214, 90)
	ring.Transparency = 0.35
	ring.CFrame = CFrame.new(c.X - 5, s + 0.1, c.Z + 6) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder

	local jumps, airJumps, hit, knocked = 0, 0, false, false
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local conns: { RBXScriptConnection } = {}
	if hum then
		local air = false
		table.insert(conns, hum.StateChanged:Connect(function(_, new)
			if new == Enum.HumanoidStateType.Jumping then
				jumps += 1
				if air then
					airJumps += 1
				end
				air = true
			elseif new == Enum.HumanoidStateType.Landed or new == Enum.HumanoidStateType.Running then
				air = false
			end
		end))
	end
	table.insert(conns, Remotes.Get("HitConfirm").OnClientEvent:Connect(function()
		hit = true
	end))
	for _, m in ipairs(isl:GetDescendants()) do
		if m:IsA("Model") and m:GetAttribute("IsDummy") then
			local last = 0
			table.insert(conns, m:GetAttributeChangedSignal("Fluff"):Connect(function()
				local f = m:GetAttribute("Fluff")
				if typeof(f) == "number" then
					if f == 0 and last > 0 then
						knocked = true -- fell off and reset
					end
					last = f
				end
			end))
		end
	end
	local function nearRing(): boolean
		local root = player.Character and player.Character.PrimaryPart
		return root ~= nil and (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(ring.Position.X, 0, ring.Position.Z)).Magnitude < 4
	end

	local m = isMobile()
	local steps: { Step } = {
		{ text = "Hey, I'm Mochi! Turn around and walk through the purple portal to the Practice Centre, then into the gold ring.", done = nearRing },
		{ text = "Nice! Now jump" .. (m and " (JUMP)." or " (SPACE)."), done = function() return jumps > 0 end, demo = hop },
		{ text = "Jump again while you're in the air - that's a double jump.", done = function() return airJumps > 0 end, demo = hop },
		{ text = (m and "Tap FIRE" or "Click") .. " to blast one of the target cats over there.", done = function() return hit end, demo = demoShots },
		{ text = "Every hit raises their %. The higher it gets, the further they fly. Knock one off the island!", done = function() return knocked end },
		{ text = "Getting launched yourself? " .. (m and "Tap DASH" or "Press Q") .. " to dash out of trouble.", done = function() return MovementController.DashCooldown() > 0 end },
		{ text = "Last one: " .. (m and "tap POUNCE" or "press E") .. " to pounce forward like a cat.", done = function() return MovementController.PounceCooldown() > 0 end, demo = hop },
	}

	local skipped = false
	skip.MouseButton1Click:Connect(function()
		skipped = true
	end)
	local function cleanup()
		for _, cn in ipairs(conns) do
			cn:Disconnect()
		end
		folder:Destroy()
		gui:Destroy()
	end

	task.spawn(function()
		for i, step in ipairs(steps) do
			progress.Text = string.format("%d / %d", i, #steps)
			speak(step.text)
			if step.demo then
				task.delay(0.8, step.demo)
			end
			ring.Transparency = i == 1 and 0.35 or 1
			while not step.done() do
				if skipped or not inLobby() then
					cleanup()
					done(false)
					return
				end
				task.wait(0.1)
			end
			SoundController.Play("Pop")
			task.wait(0.6)
		end
		speak("That's everything! Take the portal back, then hit PLAY or try the duel pads.")
		progress.Text = ""
		task.wait(3.5)
		cleanup()
		done(true)
	end)
end

-- Run the whole intro; `after` runs once it's over (or skipped).
function Intro.Run(after: () -> ())
	Intro.Running = true
	cinematic(function()
		lesson(function(finished)
			if finished then
				Remotes.Get("TutorialDone"):FireServer()
			end
			Intro.Running = false
			after()
		end)
	end)
end

return Intro
