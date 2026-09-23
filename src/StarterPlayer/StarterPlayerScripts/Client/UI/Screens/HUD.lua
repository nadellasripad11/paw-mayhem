--!strict
-- HUD: in-match heads-up display, kept deliberately minimal:
--   * Small team scores + match timer (top center)
--   * Center crosshair with shot/hit kick
--   * Compact health bar, your knockback % and active power-up (bottom left)
--   * Small weapon + ammo pill (bottom center)
--   * Mobile: FIRE / JUMP / RUN / DASH buttons (bottom right); PC: a Q dash chip
--   * Announcements (supply drops, streaks, events, Mayhem Mode) under the timer
--   * Transient banners: countdown, Get Ready, Eliminated, notices
-- Roblox's player list, health bar, backpack and mobile jump button are hidden
-- so they don't duplicate or clutter it.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Weapons = require(Shared.Config.Weapons)
local Progression = require(Shared.Config.Progression)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local CombatController = require(script.Parent.Parent.Parent.Controllers.CombatController)
local MovementController = require(script.Parent.Parent.Parent.Controllers.MovementController)
local EffectsController = require(script.Parent.Parent.Parent.Controllers.EffectsController)
local CatOverheads = require(script.Parent.Parent.Parent.Controllers.CatOverheads)

local HUD = {}
local player = Players.LocalPlayer

local gui: ScreenGui
local refs: any = {}
local POWERUP_ICON = { RapidFire = "Bolt", MegaKnockback = "Burst", Shield = "Shield", SpeedBoost = "Bolt", MultiShot = "MultiShot", Overdrive = "Sparkle" }

local function isMobile()
	return UserInputService.TouchEnabled and not UserInputService.MouseEnabled
end

-- ── crosshair ──────────────────────────────────────────────────────────────
local function buildCrosshair(parent)
	local center = UIUtil.make("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
	})
	local function arm(rot)
		local a = UIUtil.make("Frame", {
			Parent = center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(3, 12),
			Rotation = rot,
			BackgroundColor3 = Color3.fromRGB(255, 255, 255),
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
		})
		UIUtil.corner(UDim.new(1, 0), a)
		return a
	end
	local arms = { arm(0), arm(90) }
	local CROSSHAIR = {
		White = Color3.fromRGB(255, 255, 255), Green = Color3.fromRGB(110, 255, 140), Cyan = Color3.fromRGB(90, 230, 255),
		Pink = Color3.fromRGB(255, 120, 200), Yellow = Color3.fromRGB(255, 230, 90),
	}
	local function paintCrosshair()
		local c = CROSSHAIR[ClientState.Settings.Crosshair] or CROSSHAIR.White
		for _, a in ipairs(arms) do
			a.BackgroundColor3 = c
		end
	end
	ClientState.SettingsChanged:Connect(paintCrosshair)
	paintCrosshair()
	local dot = UIUtil.make("Frame", {
		Parent = center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(4, 4),
		BackgroundColor3 = Theme.Color.Accent,
		BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), dot)
	refs.crosshair = center

	-- Hitmarker: four angled ticks that flash on a confirmed hit.
	local marker = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(44, 44), BackgroundTransparency = 1, Visible = false,
	})
	for _, d in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local tick = UIUtil.make("Frame", {
			Parent = marker, AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, d[1] * 12, 0.5, d[2] * 12), Size = UDim2.fromOffset(3, 11),
			Rotation = d[1] * d[2] * -45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		})
		UIUtil.corner(UDim.new(1, 0), tick)
		UIUtil.stroke(Color3.new(0, 0, 0), 1, tick).Transparency = 0.5
	end
	refs.hitmarker = marker
end

local function kickCrosshair()
	if not refs.crosshair then return end
	local c = refs.crosshair
	c.Size = UDim2.fromOffset(40, 40)
	UIUtil.tween(c, 0.15, { Size = UDim2.fromOffset(28, 28) })
end

local hitmarkerToken = 0
local function showHitmarker()
	local m = refs.hitmarker
	if not m then return end
	hitmarkerToken += 1
	local token = hitmarkerToken
	m.Visible = true
	m.Size = UDim2.fromOffset(56, 56)
	UIUtil.tween(m, 0.1, { Size = UDim2.fromOffset(44, 44) })
	task.delay(0.16, function()
		if token == hitmarkerToken then
			m.Visible = false
		end
	end)
end

-- ── bottom left: compact health + power-up ───────────────────────────────────
local function buildHealth(parent)
	local wrap = UIUtil.make("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(250, 28),
		BackgroundTransparency = 1,
	})
	local badge = UIUtil.make("Frame", {
		Parent = wrap, Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Theme.Color.PanelDark, BackgroundTransparency = 0.15, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), badge)
	UIUtil.stroke(Theme.Color.Stroke, 1.5, badge)
	Icons.Place("CatFace", badge, 22, Color3.fromRGB(245, 245, 245), Color3.fromRGB(255, 184, 198))

	local track = UIUtil.make("Frame", {
		Parent = wrap, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 34, 0.5, 0),
		Size = UDim2.fromOffset(128, 14), BackgroundColor3 = Theme.Color.PanelDark,
		BackgroundTransparency = 0.15, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), track)
	UIUtil.stroke(Theme.Color.Stroke, 1.5, track)
	local fill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.Success, BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), fill)
	UIUtil.gradient(Color3.fromRGB(120, 230, 140), Color3.fromRGB(80, 190, 110), 0, fill)
	local hpText = UIUtil.label({
		Parent = track, Text = "100", Font = Theme.Font.Number, TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 2,
		TextStrokeTransparency = 0.6,
	})

	local power = UIUtil.make("Frame", {
		Parent = wrap, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 214, 0.5, 0),
		Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Theme.Color.PanelDark, BorderSizePixel = 0, Visible = false,
	})
	UIUtil.corner(UDim.new(1, 0), power)
	local powerIconSlot = UIUtil.make("Frame", { Parent = power, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

	-- Your own knockback % (others see it above your head).
	local fluff = UIUtil.label({
		Parent = wrap, Text = "0%", Font = Theme.Font.Title, TextSize = 20,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 168, 0.5, 0), Size = UDim2.fromOffset(42, 24),
		TextStrokeTransparency = 0.4,
	})

	refs.hpFill, refs.hpText, refs.power, refs.powerIconSlot, refs.fluff = fill, hpText, power, powerIconSlot, fluff
end

-- ── bottom center: weapon + ammo ─────────────────────────────────────────────
local function buildAmmo(parent)
	local pill = UIUtil.make("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Color.PanelDark,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), pill)
	UIUtil.stroke(Theme.Color.Stroke, 1.5, pill)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = pill
	local layout = UIUtil.listLayout(pill, 6, Enum.FillDirection.Horizontal)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder

	local iconSlot = UIUtil.make("Frame", { Parent = pill, Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1, LayoutOrder = 1 })
	local name = UIUtil.label({
		Parent = pill, Text = "PAW BLASTER", Font = Theme.Font.Bold, TextSize = 12,
		TextColor3 = Theme.Color.TextDim, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 16), LayoutOrder = 2,
	})
	UIUtil.label({
		Parent = pill, Text = "∞", Font = Theme.Font.Number, TextSize = 18,
		TextColor3 = Theme.Color.Text, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, 20), LayoutOrder = 3,
	})
	refs.weaponName, refs.weaponIconSlot = name, iconSlot
end

-- ── center banners ───────────────────────────────────────────────────────────
local function buildBanners(parent)
	local elim = UIUtil.panel({
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66),
		Size = UDim2.fromOffset(320, 40), BackgroundColor3 = Theme.Color.PanelDark, Visible = false,
	})
	local elimText = UIUtil.label({ Parent = elim, Text = "", TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Font.Heading, TextSize = 18, Size = UDim2.fromScale(1, 1) })
	refs.elim, refs.elimText = elim, elimText

	local big = UIUtil.label({
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42),
		Text = "", Font = Theme.Font.Title, TextSize = 64, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromOffset(600, 80), Visible = false, TextStrokeTransparency = 0.5,
	})
	refs.bigText = big
end

function HUD.ShowElim(text: string)
	if not refs.elim then return end
	refs.elimText.Text = text
	refs.elim.Visible = true
	refs.elim.Size = UDim2.fromOffset(280, 40)
	UIUtil.tween(refs.elim, 0.2, { Size = UDim2.fromOffset(340, 44) })
	task.delay(2.2, function()
		if refs.elim then refs.elim.Visible = false end
	end)
end

function HUD.ShowBig(text: string, color: Color3?, seconds: number?)
	if not refs.bigText then return end
	refs.bigText.Text = text
	refs.bigText.TextColor3 = color or Theme.Color.Text
	refs.bigText.Visible = true
	refs.bigText.TextTransparency = 0
	if seconds then
		task.delay(seconds, function()
			if refs.bigText then refs.bigText.Visible = false end
		end)
	end
end

function HUD.HideBig()
	if refs.bigText then refs.bigText.Visible = false end
end

-- ── mobile controls ──────────────────────────────────────────────────────────
local function touchButton(parent, name: string, pos: UDim2, d: number, color: Color3, iconName: string, label: string)
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = ""
	b.AutoButtonColor = false
	b.AnchorPoint = Vector2.new(0.5, 0.5)
	b.Position = pos
	b.Size = UDim2.fromOffset(d, d)
	b.BackgroundColor3 = Color3.fromRGB(16, 22, 40)
	b.BackgroundTransparency = 0.3
	b.BorderSizePixel = 0
	b.Parent = parent
	UIUtil.corner(UDim.new(1, 0), b)
	local ring = UIUtil.stroke(color, 3, b)
	local tint = UIUtil.make("Frame", {
		Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8), BackgroundColor3 = color, BackgroundTransparency = 0.72, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), tint)
	Icons.Place(iconName, b, math.floor(d * 0.46), Color3.new(1, 1, 1), nil, UDim2.fromScale(0.5, 0.43))
	UIUtil.label({
		Parent = b, Text = label, Font = Theme.Font.Bold, TextSize = d >= 80 and 11 or 9,
		TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.8),
		Size = UDim2.new(1, 0, 0, 12), TextStrokeTransparency = 0.6,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = b
	local function setLit(on: boolean)
		tint.BackgroundTransparency = on and 0.35 or 0.72
		ring.Thickness = on and 4 or 3
	end
	local function setPressed(on: boolean)
		scale.Scale = on and 0.92 or 1
	end
	return b, setLit, setPressed
end

-- Hides Roblox's built-in mobile jump button; ours replaces it.
local function hideDefaultJumpButton()
	local pg = player:WaitForChild("PlayerGui")
	local function hook(inst: Instance)
		if inst.Name == "JumpButton" and inst:IsA("GuiObject") and inst:FindFirstAncestor("TouchGui") then
			local g = inst :: GuiObject
			g.Visible = false
			g:GetPropertyChangedSignal("Visible"):Connect(function()
				if g.Visible then
					g.Visible = false
				end
			end)
		end
	end
	for _, d in ipairs(pg:GetDescendants()) do
		hook(d)
	end
	pg.DescendantAdded:Connect(hook)
end

local function buildMobile(parent)
	if not isMobile() then return end
	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end

	-- FIRE tracks the exact touch, so sliding a finger off the button still
	-- stops firing when it lifts.
	local fire, _, firePressed = touchButton(parent, "FireButton", UDim2.new(1, -78, 1, -104), 92, Theme.Color.Danger, "Reticle", "FIRE")
	local fireInput: InputObject? = nil
	fire.InputBegan:Connect(function(input)
		if isPress(input) and not fireInput then
			fireInput = input
			CombatController.SetFiring(true)
			firePressed(true)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input == fireInput then
			fireInput = nil
			CombatController.SetFiring(false)
			firePressed(false)
		end
	end)

	local jump, _, jumpPressed = touchButton(parent, "JumpButton", UDim2.new(1, -180, 1, -58), 66, Theme.Color.Accent, "JumpArrow", "JUMP")
	jump.InputBegan:Connect(function(input)
		if isPress(input) then
			jumpPressed(true)
			MovementController.Jump() -- second tap in the air = double jump
		end
	end)
	jump.InputEnded:Connect(function(input)
		if isPress(input) then jumpPressed(false) end
	end)

	local dash, dashLit, dashPressed = touchButton(parent, "DashButton", UDim2.new(1, -92, 1, -205), 58, Color3.fromRGB(120, 220, 255), "Bolt", "DASH")
	dash.InputBegan:Connect(function(input)
		if isPress(input) then
			dashPressed(true)
			MovementController.Dash()
		end
	end)
	dash.InputEnded:Connect(function(input)
		if isPress(input) then dashPressed(false) end
	end)
	local dashTimer = UIUtil.label({
		Parent = dash, Text = "", Font = Theme.Font.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.3, ZIndex = 5,
	})
	refs.dashButton = { lit = dashLit, timer = dashTimer, button = dash }

	local run, runLit, runPressed = touchButton(parent, "RunButton", UDim2.new(1, -170, 1, -160), 58, Theme.Color.Warn, "Dash", "RUN")
	run.InputBegan:Connect(function(input)
		if isPress(input) then
			runPressed(true)
			MovementController.ToggleSprint()
		end
	end)
	run.InputEnded:Connect(function(input)
		if isPress(input) then runPressed(false) end
	end)
	MovementController.SprintChanged = runLit
	runLit(MovementController.IsSprinting())

	task.spawn(hideDefaultJumpButton)
end

-- Roblox's own player list / health bar / backpack would clutter the HUD.
local function hideCoreGui()
	for _ = 1, 20 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok then return end
		task.wait(0.5)
	end
end

-- ── top center: small scores + timer ─────────────────────────────────────────
local function buildScoreBar(parent)
	local bar = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 8),
		Size = UDim2.fromOffset(172, 30), BackgroundTransparency = 1,
	})
	local function tile(x: number, w: number, color: Color3, font: Enum.Font, size: number): (TextLabel, UIStroke)
		local t = UIUtil.make("Frame", {
			Parent = bar, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, 30),
			BackgroundColor3 = color, BackgroundTransparency = 0.1, BorderSizePixel = 0,
		})
		UIUtil.corner(UDim.new(0, 8), t)
		local s = UIUtil.stroke(Color3.new(1, 1, 1), 2, t)
		s.Enabled = false
		local l = UIUtil.label({
			Parent = t, Text = "0", Font = font, TextSize = size,
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
		})
		return l, s
	end
	refs.blueScore, refs.blueStroke = tile(0, 48, Theme.Color.Blue, Theme.Font.Number, 18)
	refs.timer = tile(53, 66, Theme.Color.PanelDark, Theme.Font.Heading, 16)
	refs.timer.Text = "3:00"
	refs.redScore, refs.redStroke = tile(124, 48, Theme.Color.Red, Theme.Font.Number, 18)
	-- Mode name under the bar (FFA: left = your KOs, right = the leader's).
	refs.modeLabel = UIUtil.label({
		Parent = bar, Text = "", Font = Theme.Font.Bold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(-40, 32), Size = UDim2.new(1, 80, 0, 14),
		TextStrokeTransparency = 0.4,
	})
end

-- ── announcements (below the timer) ──────────────────────────────────────────
local function buildAnnouncer(parent)
	local holder = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 46),
		Size = UDim2.fromOffset(620, 70), BackgroundTransparency = 1,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local title = UIUtil.label({
		Parent = holder, Text = "", Font = Theme.Font.Title, TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 36), TextTransparency = 1,
	})
	local titleStroke = UIUtil.stroke(Color3.fromRGB(20, 16, 30), 2.5, title)
	titleStroke.Transparency = 1
	local sub = UIUtil.label({
		Parent = holder, Text = "", Font = Theme.Font.Bold, TextSize = 15, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 38), Size = UDim2.new(1, 0, 0, 20),
		TextStrokeTransparency = 1, TextTransparency = 1,
	})
	refs.announce = { holder = holder, scale = scale, title = title, stroke = titleStroke, sub = sub, token = 0 }
end

function HUD.Announce(data: any)
	local a = refs.announce
	if not a or typeof(data) ~= "table" then
		return
	end
	a.token += 1
	local token = a.token
	local small = data.small == true
	a.title.Text = tostring(data.title or "")
	a.title.TextSize = small and 20 or 30
	a.title.TextColor3 = typeof(data.color) == "Color3" and data.color or Theme.Color.Warn
	a.sub.Text = tostring(data.sub or "")
	a.sub.Position = UDim2.fromOffset(0, small and 26 or 38)
	a.scale.Scale = 0.7
	TweenService:Create(a.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	a.title.TextTransparency, a.stroke.Transparency = 0, 0
	a.sub.TextTransparency, a.sub.TextStrokeTransparency = 0, 0.5
	task.delay(small and 2.6 or 3.6, function()
		if token ~= a.token then
			return
		end
		local info = TweenInfo.new(0.4)
		TweenService:Create(a.title, info, { TextTransparency = 1 }):Play()
		TweenService:Create(a.stroke, info, { Transparency = 1 }):Play()
		TweenService:Create(a.sub, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end)
end

-- ── PC dash chip (mobile has its own button) ─────────────────────────────────
local function buildDashChip(parent)
	if isMobile() then return end
	local chip = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -110, 1, -10),
		Size = UDim2.fromOffset(62, 28), BackgroundColor3 = Theme.Color.PanelDark, BackgroundTransparency = 0.15, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), chip)
	UIUtil.stroke(Theme.Color.Stroke, 1.5, chip)
	local key = UIUtil.label({
		Parent = chip, Text = "Q", Font = Theme.Font.Title, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(5, 4), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(120, 220, 255), TextColor3 = Color3.fromRGB(10, 30, 50),
	})
	UIUtil.corner(UDim.new(0, 6), key)
	local label = UIUtil.label({
		Parent = chip, Text = "DASH", Font = Theme.Font.Bold, TextSize = 11, TextColor3 = Theme.Color.TextDim,
		Position = UDim2.fromOffset(29, 0), Size = UDim2.new(1, -32, 1, 0),
	})
	refs.dashChip = { key = key, label = label }
end

-- ── Mayhem Mode: pulsing red glow around the screen edge ─────────────────────
local function buildMayhemEdge(parent)
	local edge = UIUtil.make("Frame", {
		Parent = parent, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false,
	})
	local stroke = UIUtil.stroke(Color3.fromRGB(255, 50, 70), 10, edge)
	stroke.Transparency = 0.5
	TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.85 }):Play()
	refs.mayhemEdge = edge
end

-- ── updates ──────────────────────────────────────────────────────────────────
local function updateScoreBar(m)
	if not refs.timer then return end
	local scores = m.scores or {}
	refs.blueScore.Text = tostring(scores.Blue or 0)
	refs.redScore.Text = tostring(scores.Red or 0)
	local MODE_TEXT = { TDM = "TEAM DEATHMATCH", FFA = "FREE FOR ALL  •  YOU vs LEADER", KOTH = "KING OF THE HILL  •  HOLD THE HILL", Ringout = "RINGOUT  •  KNOCK THEM OFF" }
	if refs.modeLabel then
		refs.modeLabel.Text = MODE_TEXT[m.mode or "TDM"] or ""
	end
	if m.mode == "FFA" then
		local mine, top = 0, 0
		for _, e in ipairs(m.board or {}) do
			top = math.max(top, e.Elims or 0)
			if e.Name == player.Name then
				mine = e.Elims or 0
			end
		end
		refs.blueScore.Text = tostring(mine)
		refs.redScore.Text = tostring(top)
	end
	local t = math.max(0, m.timeLeft or 0)
	refs.timer.Text = string.format("%d:%02d", t // 60, t % 60)
	local mayhem = m.mayhem == true and m.phase == "Playing"
	refs.timer.TextColor3 = mayhem and Color3.fromRGB(255, 90, 100) or Theme.Color.Text
	if refs.mayhemEdge then
		refs.mayhemEdge.Visible = mayhem
	end
	local char = player.Character
	local team = char and char:GetAttribute("Team")
	refs.blueStroke.Enabled = team == "Blue"
	refs.redStroke.Enabled = team == "Red"
end

local function updateHealth()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and refs.hpFill then
		local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		refs.hpFill.Size = UDim2.fromScale(frac, 1)
		refs.hpText.Text = tostring(math.ceil(hum.Health))
	end
	if char and refs.fluff then
		local fluff = char:GetAttribute("Fluff")
		local f = typeof(fluff) == "number" and fluff or 0
		refs.fluff.Text = tostring(math.floor(f)) .. "%"
		refs.fluff.TextColor3 = CatOverheads.FluffColor(f)
	end
end

local function updateDash()
	local cd = MovementController.DashCooldown()
	local ready = cd <= 0
	if refs.dashButton then
		refs.dashButton.lit(ready)
		refs.dashButton.timer.Text = ready and "" or string.format("%.1f", cd)
	end
	if refs.dashChip then
		refs.dashChip.key.BackgroundTransparency = ready and 0 or 0.7
		refs.dashChip.label.Text = ready and "DASH" or string.format("%.1f", cd)
	end
end

local function updateWeapon()
	local profile = ClientState.Profile
	if not refs.weaponName then return end
	-- A supply-drop blaster (on the character) shows instead of the loadout.
	local override = player.Character and player.Character:GetAttribute("WeaponOverride")
	local id = typeof(override) == "string" and override or (profile and profile.Loadout.Weapon)
	local w = id and Weapons.Get(id)
	if w then
		refs.weaponName.Text = string.upper(w.Name)
		refs.weaponIconSlot:ClearAllChildren()
		Icons.Place(w.Icon or "Gun", refs.weaponIconSlot, 20, w.TrailColor, w.MuzzleColor)
	end
end

function HUD.SetVisible(on: boolean)
	if gui then gui.Enabled = on end
end

function HUD.Build()
	gui = UIUtil.make("ScreenGui", {
		Name = "PawHUD", Parent = player:WaitForChild("PlayerGui"),
		IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 5, Enabled = false,
	}) :: ScreenGui

	task.spawn(hideCoreGui)

	buildMayhemEdge(gui)
	buildScoreBar(gui)
	buildAnnouncer(gui)
	buildCrosshair(gui)
	buildHealth(gui)
	buildAmmo(gui)
	buildDashChip(gui)
	buildBanners(gui)
	buildMobile(gui)

	ClientState.ProfileChanged:Connect(updateWeapon)
	ClientState.MatchChanged:Connect(updateScoreBar)
	updateScoreBar(ClientState.Match)
	local function watchCharacter(char: Model)
		char:GetAttributeChangedSignal("WeaponOverride"):Connect(updateWeapon)
		updateWeapon()
	end
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	Remotes.Get("Announce").OnClientEvent:Connect(HUD.Announce)
	Remotes.Get("Eliminated").OnClientEvent:Connect(function()
		HUD.ShowBig("ELIMINATED", Theme.Color.Danger, 2)
	end)
	Remotes.Get("Notify").OnClientEvent:Connect(function(data)
		HUD.ShowElim(data.text or "")
	end)
	Remotes.Get("PowerUpActive").OnClientEvent:Connect(function(data)
		local p = Progression.PowerUpById[data.powerId]
		if p and refs.power then
			refs.power.Visible = true
			refs.power.BackgroundColor3 = p.Color
			refs.powerIconSlot:ClearAllChildren()
			Icons.Place(POWERUP_ICON[data.powerId] or "Sparkle", refs.powerIconSlot, 18, Color3.new(1, 1, 1))
			task.delay(data.duration or 10, function()
				if refs.power then refs.power.Visible = false end
			end)
		end
	end)

	EffectsController.OnHitConfirm = function()
		kickCrosshair()
		showHitmarker()
	end
	CombatController.OnLocalShot = function()
		kickCrosshair()
	end

	task.spawn(function()
		while gui.Parent do
			updateHealth()
			updateDash()
			task.wait(0.1)
		end
	end)
	updateWeapon()
end

return HUD
