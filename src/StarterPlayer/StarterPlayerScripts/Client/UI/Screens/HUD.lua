--!strict
-- HUD: in-match heads-up display, kept deliberately minimal:
--   * Small team scores + match timer (top center); in a duel, your side's
--     knockouts, the clock and theirs
--   * Center crosshair with shot/hit kick
--   * Compact health bar, your knockback % and active power-up (bottom left)
--   * Small weapon + ammo pill (bottom center)
--   * Mobile: FIRE / JUMP / RUN / DASH / POUNCE buttons (bottom right); PC: Q dash + E pounce chips
--   * A small LOADOUT button (top left, or B) to change blasters mid-match
--   * Announcements (supply drops, streaks, events, Mayhem Mode) under the timer
--   * Transient banners: countdown, Get Ready, Eliminated, notices
--   * Kill feed (top right) and a KNOCKOUT! / RING OUT! pop with multi-KOs
-- Roblox's player list, health bar, backpack and mobile jump button are hidden
-- so they don't duplicate or clutter it.
-- Outside a match it shrinks (HUD.SetMode): the practice range keeps the
-- crosshair and weapon, the rest of the lobby only the movement buttons.

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
local CameraController = require(script.Parent.Parent.Parent.Controllers.CameraController)
local SoundController = require(script.Parent.Parent.Parent.Controllers.SoundController)

local HUD = {}
local player = Players.LocalPlayer

local gui: ScreenGui
local refs: any = {}
local hudMode = "Match" -- see HUD.SetMode
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
	center:SetAttribute("HudPart", "Aim")

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
		refs.hitTicks = refs.hitTicks or {}
		table.insert(refs.hitTicks, tick)
	end
	refs.hitmarker = marker
	-- Knockout: a red ring that bursts out from the crosshair.
	local ring = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, Visible = false,
	})
	UIUtil.corner(UDim.new(1, 0), ring)
	refs.koRingStroke = UIUtil.stroke(Color3.fromRGB(255, 70, 80), 3, ring)
	refs.koRing = ring
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

-- You knocked someone out: the hit marker goes red and bigger, and a red
-- ring bursts out of the crosshair.
local function showKoMarker()
	local m, ring = refs.hitmarker, refs.koRing
	if not m or not ring then return end
	hitmarkerToken += 1
	local token = hitmarkerToken
	for _, t in ipairs(refs.hitTicks or {}) do
		t.BackgroundColor3 = Color3.fromRGB(255, 70, 80)
	end
	m.Visible = true
	m.Size = UDim2.fromOffset(78, 78)
	UIUtil.tween(m, 0.18, { Size = UDim2.fromOffset(54, 54) })
	ring.Visible = true
	ring.Size = UDim2.fromOffset(30, 30)
	refs.koRingStroke.Transparency = 0
	UIUtil.tween(ring, 0.4, { Size = UDim2.fromOffset(110, 110) })
	UIUtil.tween(refs.koRingStroke, 0.4, { Transparency = 1 })
	task.delay(0.42, function()
		if token == hitmarkerToken then
			m.Visible = false
			ring.Visible = false
			for _, t in ipairs(refs.hitTicks or {}) do
				t.BackgroundColor3 = Color3.new(1, 1, 1)
			end
		end
	end)
end

-- The knockout that won the match or duel: a moment for everyone in it -
-- the colour drains out and comes back, the view punches in, a deep boom,
-- FINAL KNOCKOUT! across the screen.
local function finalKnockout()
	HUD.ShowBig("FINAL KNOCKOUT!", Theme.Color.Coin, 2.2)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = -0.75
	cc.Contrast = 0.2
	cc.Brightness = 0.06
	cc.Parent = game:GetService("Lighting")
	TweenService:Create(cc, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Saturation = 0, Contrast = 0, Brightness = 0 }):Play()
	task.delay(1.9, function()
		cc:Destroy()
	end)
	CameraController.Punch(9)
	CameraController.AddShake(1.5)
	SoundController.Play("Knockout", 0.65)
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
	wrap:SetAttribute("HudPart", "Health")
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
	pill:SetAttribute("HudPart", "Weapon")
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
	b:SetAttribute("HudPart", name == "FireButton" and "Aim" or name == "JumpButton" and "Jump" or "Moves")
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
	local fire, _, firePressed = touchButton(parent, "FireButton", UDim2.new(1, -70, 1, -100), 92, Theme.Color.Danger, "Reticle", "FIRE")
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

	local jump, _, jumpPressed = touchButton(parent, "JumpButton", UDim2.new(1, -182, 1, -54), 66, Theme.Color.Accent, "JumpArrow", "JUMP")
	jump.InputBegan:Connect(function(input)
		if isPress(input) then
			jumpPressed(true)
			MovementController.SetJumpHeld(true)
			MovementController.Jump() -- second tap in the air = double jump
		end
	end)
	jump.InputEnded:Connect(function(input)
		if isPress(input) then
			jumpPressed(false)
			MovementController.SetJumpHeld(false)
		end
	end)

	local dash, dashLit, dashPressed = touchButton(parent, "DashButton", UDim2.new(1, -66, 1, -212), 58, Color3.fromRGB(120, 220, 255), "Bolt", "DASH")
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

	local pounce, pounceLit, pouncePressed = touchButton(parent, "PounceButton", UDim2.new(1, -182, 1, -166), 58, Color3.fromRGB(255, 200, 110), "JumpArrow", "POUNCE")
	pounce.InputBegan:Connect(function(input)
		if isPress(input) then
			pouncePressed(true)
			MovementController.Pounce()
		end
	end)
	pounce.InputEnded:Connect(function(input)
		if isPress(input) then pouncePressed(false) end
	end)
	local pounceTimer = UIUtil.label({
		Parent = pounce, Text = "", Font = Theme.Font.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1), TextStrokeTransparency = 0.3, ZIndex = 5,
	})
	refs.pounceButton = { lit = pounceLit, timer = pounceTimer }

	local run, runLit, runPressed = touchButton(parent, "RunButton", UDim2.new(1, -66, 1, -298), 58, Theme.Color.Warn, "Dash", "RUN")
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
	bar:SetAttribute("HudPart", "Score")
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

-- ── top center (duels): your side's KOs, the clock, theirs ───────────────────
local function buildDuelBar(parent)
	local bar = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 8),
		Size = UDim2.fromOffset(172, 30), BackgroundTransparency = 1, Visible = false,
	})
	bar:SetAttribute("HudPart", "Duel")
	local function tile(x: number, w: number, font: Enum.Font, size: number): (Frame, TextLabel)
		local t = UIUtil.make("Frame", {
			Parent = bar, Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, 30),
			BackgroundColor3 = Theme.Color.PanelDark, BackgroundTransparency = 0.1, BorderSizePixel = 0,
		}) :: Frame
		UIUtil.corner(UDim.new(0, 8), t)
		local l = UIUtil.label({
			Parent = t, Text = "0", Font = font, TextSize = size,
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
		})
		return t, l
	end
	local mineTile, mine = tile(0, 48, Theme.Font.Number, 18)
	local _, clock = tile(53, 66, Theme.Font.Heading, 16)
	local theirTile, theirs = tile(124, 48, Theme.Font.Number, 18)
	local sub = UIUtil.label({
		Parent = bar, Text = "", Font = Theme.Font.Bold, TextSize = 11, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(-90, 32), Size = UDim2.new(1, 180, 0, 14),
		TextStrokeTransparency = 0.4,
	})
	refs.duel = { mineTile = mineTile, mine = mine, clock = clock, theirTile = theirTile, theirs = theirs, sub = sub }
end

-- Duel updates from the server: the score, the clock, and the start / end.
local function onDuelState(d: any)
	local r = refs.duel
	if not r or typeof(d) ~= "table" then return end
	local mine = d.myTeam == "Red" and "Red" or "Blue"
	local theirs = mine == "Blue" and "Red" or "Blue"
	r.mineTile.BackgroundColor3 = mine == "Blue" and Theme.Color.Blue or Theme.Color.Red
	r.theirTile.BackgroundColor3 = theirs == "Blue" and Theme.Color.Blue or Theme.Color.Red
	if typeof(d.score) == "table" then
		r.mine.Text = tostring(d.score[mine] or 0)
		r.theirs.Text = tostring(d.score[theirs] or 0)
	end
	local left = tonumber(d.timeLeft)
	if left then
		r.clock.Text = string.format("%d:%02d", left // 60, left % 60)
	end
	local foes = typeof(d.teams) == "table" and d.teams[theirs]
	if d.target and typeof(foes) == "table" then
		r.sub.Text = "FIRST TO " .. tostring(d.target) .. "  ·  VS " .. string.upper(table.concat(foes, " & ")) .. (d.withBots and "  ·  NO TROPHIES" or "")
	end
	if d.started then
		HUD.ShowBig(tostring(d.map or "DUEL"), Theme.Color.Text, 1.6)
		task.delay(1.7, function()
			HUD.ShowBig("FIGHT!", Theme.Color.Warn, 1.2)
		end)
	elseif d.over then
		local text = d.draw and "DRAW" or d.won and "VICTORY" or "DEFEAT"
		HUD.ShowBig(text, d.draw and Theme.Color.Text or d.won and Theme.Color.Coin or Theme.Color.Danger, 3.5)
		local t = tonumber(d.trophies) or 0
		if d.withBots then
			HUD.ShowElim("BOT DUEL  ·  HALF REWARDS")
		else
			HUD.ShowElim((d.forfeit and "They left  ·  " or "") .. (t >= 0 and "+" or "") .. tostring(t) .. " TROPHIES")
		end
	end
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

-- ── practice range hint (top centre) ─────────────────────────────────────────
-- Your mouse locks for aiming inside the range, so say why and how to get it back.
local function buildRangeHint(parent)
	local pill = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 10),
		Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Theme.Color.PanelDark,
		BackgroundTransparency = 0.2, BorderSizePixel = 0, Visible = false,
	})
	pill:SetAttribute("HudPart", "RangeHint")
	UIUtil.corner(UDim.new(1, 0), pill)
	UIUtil.stroke(Color3.fromRGB(255, 214, 90), 1.5, pill)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
	pad.Parent = pill
	UIUtil.label({
		Parent = pill, Text = "PRACTICE CENTRE  ·  go back through the portal to use the menu", Font = Theme.Font.Bold, TextSize = 14,
		Size = UDim2.fromScale(0, 1), AutomaticSize = Enum.AutomaticSize.X, TextColor3 = Color3.new(1, 1, 1),
	})
end

-- ── loadout button (top left, matches and duels) ─────────────────────────────
-- Set by UIManager: open the Loadout screen over the game.
HUD.OnLoadout = nil :: (() -> ())?

local function buildLoadoutButton(parent)
	local b = UIUtil.make("TextButton", {
		Parent = parent, Name = "LoadoutButton", Text = "", AutoButtonColor = false,
		Position = UDim2.fromOffset(12, UIUtil.topInset() + 8), Size = UDim2.fromOffset(isMobile() and 48 or 58, 40),
		BackgroundColor3 = Theme.Color.PanelDark, BackgroundTransparency = 0.15, BorderSizePixel = 0,
	}) :: TextButton
	b:SetAttribute("HudPart", "Loadout")
	UIUtil.corner(UDim.new(0, 10), b)
	UIUtil.stroke(Theme.Color.Stroke, 1.5, b)
	local slot = UIUtil.make("Frame", {
		Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 22, 0.5, 0),
		Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1,
	})
	Icons.Place("Gun", slot, 22, Color3.new(1, 1, 1), Color3.new(1, 1, 1))
	if not isMobile() then
		UIUtil.label({
			Parent = b, Text = "B", Font = Theme.Font.Title, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0), Size = UDim2.fromOffset(18, 18),
			BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 214, 90), TextColor3 = Color3.fromRGB(40, 30, 10),
		})
	end
	local function open()
		if HUD.OnLoadout and (hudMode == "Match" or hudMode == "Duel") then
			HUD.OnLoadout()
		end
	end
	b.MouseButton1Click:Connect(open)
	UserInputService.InputBegan:Connect(function(input, gpe)
		if not gpe and input.KeyCode == Enum.KeyCode.B then
			open()
		end
	end)
end

-- ── abilities: three buttons in the middle above the weapon ─────────────────
-- Boost / Jumps / Fly, each recharging in 15 s: the dark shade drains away
-- as it recharges, a glow while it's running. Click or tap (or Z / X / C).
local ABILITY_LOOK = {
	Boost = { icon = "Bolt", key = "Z", color = Color3.fromRGB(120, 220, 255) },
	Jumps = { icon = "JumpArrow", key = "X", color = Color3.fromRGB(255, 214, 90) },
	Fly = { icon = "Sparkle", key = "C", color = Color3.fromRGB(190, 150, 255) },
}
local function buildAbilities(parent)
	-- Cards like the reference: a round picture, "ABILITY", the name, a
	-- READY / countdown line, and a bar along the bottom that fills as it
	-- recharges. Click or tap one (or Z / X / C).
	local NAMES = { Boost = "BOOST", Jumps = "MULTI JUMP", Fly = "FLY" }
	local CARD_W, CARD_H, GAP = 196, 66, 14
	local row = UIUtil.make("Frame", {
		Parent = parent, Name = "Abilities", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -48),
		Size = UDim2.fromOffset(3 * CARD_W + 2 * GAP, CARD_H), BackgroundTransparency = 1,
	})
	row:SetAttribute("HudPart", "Abilities")
	local rs = Instance.new("UIScale")
	rs.Scale = isMobile() and 0.7 or 1
	rs.Parent = row
	UIUtil.listLayout(row, GAP, Enum.FillDirection.Horizontal)
	local slots = {}
	for i, name in ipairs(MovementController.Abilities) do
		local look = ABILITY_LOOK[name]
		local card = UIUtil.make("TextButton", {
			Parent = row, Name = name, LayoutOrder = i, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(CARD_W, CARD_H),
			BackgroundColor3 = Color3.fromRGB(14, 18, 30), BackgroundTransparency = 0.1, BorderSizePixel = 0, ClipsDescendants = true,
		}) :: TextButton
		UIUtil.corner(UDim.new(0, 10), card)
		local edge = UIUtil.stroke(Color3.fromRGB(10, 10, 14), 2, card)
		UIUtil.gradient(look.color:Lerp(Color3.fromRGB(14, 18, 30), 0.65), Color3.fromRGB(14, 18, 30), 0, card)
		local pic = UIUtil.make("Frame", {
			Parent = card, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 8, 0.5, -2), Size = UDim2.fromOffset(50, 50),
			BackgroundColor3 = look.color:Lerp(Color3.new(0, 0, 0), 0.35), BorderSizePixel = 0,
		})
		UIUtil.corner(UDim.new(1, 0), pic)
		UIUtil.stroke(look.color, 2, pic)
		Icons.Place(look.icon, pic, 30, Color3.new(1, 1, 1))
		UIUtil.label({ Parent = card, Text = "ABILITY", Font = Theme.Font.Bold, TextSize = 10, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(66, 6), Size = UDim2.fromOffset(100, 12) })
		UIUtil.label({ Parent = card, Text = NAMES[name] or name, Font = Theme.Font.Title, TextSize = 17, Position = UDim2.fromOffset(66, 18), Size = UDim2.new(1, -72, 0, 20) })
		local status = UIUtil.label({ Parent = card, Text = "", Font = Theme.Font.Bold, TextSize = 12, TextColor3 = look.color, Position = UDim2.fromOffset(66, 39), Size = UDim2.new(1, -72, 0, 14) })
		local track = UIUtil.make("Frame", { Parent = card, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 8, 1, -4), Size = UDim2.new(1, -16, 0, 4), BackgroundColor3 = Color3.fromRGB(40, 44, 56), BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(1, 0), track)
		local fill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(1, 1), BackgroundColor3 = look.color, BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(1, 0), fill)
		card.MouseButton1Click:Connect(function()
			MovementController.UseAbility(name)
		end)
		slots[name] = { status = status, fill = fill, edge = edge, key = look.key, color = look.color }
	end
	task.spawn(function()
		while row.Parent do
			if row.Visible and gui and gui.Enabled then
				for name, s in pairs(slots) do
					local cd = MovementController.AbilityCooldown(name)
					local active = MovementController.AbilityActive(name)
					s.fill.Size = UDim2.fromScale(1 - math.clamp(cd / 15, 0, 1), 1)
					local key = isMobile() and "" or ("  ·  " .. s.key)
					s.status.Text = active > 0 and ("ACTIVE " .. math.ceil(active) .. "s") or cd > 0 and (math.ceil(cd) .. "s") or ("READY" .. key)
					s.status.TextColor3 = cd > 0 and active <= 0 and Theme.Color.TextDim or s.color
					s.edge.Color = active > 0 and s.color or Color3.fromRGB(10, 10, 14)
				end
			end
			task.wait(0.1)
		end
	end)
end

-- ── top bar in a match: QUESTS on the left, EMOTES and SETTINGS on the right ─
local function buildTopBar(parent)
	local inset = UIUtil.topInset()
	local function pill(name: string, text: string, icon: string, pos: UDim2, anchor: Vector2, onClick: () -> ())
		local b = UIUtil.make("TextButton", {
			Parent = parent, Name = name, Text = "", AutoButtonColor = true, AnchorPoint = anchor, Position = pos,
			Size = UDim2.fromOffset(140, 44), BackgroundColor3 = Color3.fromRGB(14, 18, 30), BackgroundTransparency = 0.15, BorderSizePixel = 0,
		}) :: TextButton
		b:SetAttribute("HudPart", "TopBar")
		UIUtil.corner(UDim.new(0, 10), b)
		UIUtil.stroke(Color3.fromRGB(60, 70, 96), 1.5, b)
		local slot = UIUtil.make("Frame", { Parent = b, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(22, 22), BackgroundTransparency = 1 })
		Icons.Place(icon, slot, 22, Color3.new(1, 1, 1))
		UIUtil.label({ Parent = b, Text = text, Font = Theme.Font.Title, TextSize = 16, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -48, 1, 0) })
		b.MouseButton1Click:Connect(onClick)
	end
	local y = math.max(inset - 40, 10)
	pill("QuestsButton", "QUESTS", "Check", UDim2.new(0, 240, 0, y), Vector2.new(0, 0), function()
		require(script.Parent.MainMenu).OpenInGame("Quests")
	end)
	pill("SettingsButton", "SETTINGS", "Gear", UDim2.new(1, -12, 0, y), Vector2.new(1, 0), function()
		require(script.Parent.MainMenu).OpenInGame("Settings")
	end)
	pill("EmotesButton", "EMOTES", "Smiley", UDim2.new(1, -166, 0, y), Vector2.new(1, 0), function()
		require(script.Parent.EmotePicker).Toggle()
	end)
end

-- ── PC dash chip (mobile has its own button) ─────────────────────────────────
local function buildDashChip(parent)
	if isMobile() then return end
	local chip = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(0.5, -110, 1, -10),
		Size = UDim2.fromOffset(62, 28), BackgroundColor3 = Theme.Color.PanelDark, BackgroundTransparency = 0.15, BorderSizePixel = 0,
	})
	chip:SetAttribute("HudPart", "Keys") -- (the clones below keep it)
	UIUtil.corner(UDim.new(1, 0), chip)
	UIUtil.stroke(Theme.Color.Stroke, 1.5, chip)
	local key = UIUtil.label({
		Parent = chip, Name = "Key", Text = "Q", Font = Theme.Font.Title, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(5, 4), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 0,
		BackgroundColor3 = Color3.fromRGB(120, 220, 255), TextColor3 = Color3.fromRGB(10, 30, 50),
	})
	UIUtil.corner(UDim.new(0, 6), key)
	local label = UIUtil.label({
		Parent = chip, Name = "Label", Text = "DASH", Font = Theme.Font.Bold, TextSize = 11, TextColor3 = Theme.Color.TextDim,
		Position = UDim2.fromOffset(29, 0), Size = UDim2.new(1, -32, 1, 0),
	})
	refs.dashChip = { key = key, label = label }

	-- E: pounce, just left of the dash chip.
	local pchip = chip:Clone()
	pchip.Position = UDim2.new(0.5, -178, 1, -10)
	pchip.Size = UDim2.fromOffset(76, 28)
	pchip.Parent = parent
	local pkey = pchip:FindFirstChild("Key") :: TextLabel
	local pl = pchip:FindFirstChild("Label") :: TextLabel
	pkey.Text = "E"

	-- V: switch first / third person, right of the weapon pill.
	local vchip = chip:Clone()
	vchip.AnchorPoint = Vector2.new(0, 1)
	vchip.Position = UDim2.new(0.5, 110, 1, -10)
	vchip.Size = UDim2.fromOffset(70, 28)
	vchip.Parent = parent
	local vkey = vchip:FindFirstChild("Key") :: TextLabel
	local vl = vchip:FindFirstChild("Label") :: TextLabel
	vkey.Text = "V"
	vkey.BackgroundColor3 = Color3.fromRGB(190, 160, 255)
	vl.Text = "VIEW"
	pkey.BackgroundColor3 = Color3.fromRGB(255, 200, 110)
	pl.Text = "POUNCE"
	refs.pounceChip = { key = pkey, label = pl }
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

-- ── kill feed (top right) ────────────────────────────────────────────────────
local TEAM_TEXT = { Blue = Color3.fromRGB(110, 185, 255), Red = Color3.fromRGB(255, 120, 130) }

local function buildKillFeed(parent)
	local list = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, UIUtil.topInset() + 8),
		Size = UDim2.fromOffset(300, 160), BackgroundTransparency = 1,
	})
	list:SetAttribute("HudPart", "Feed")
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	refs.killFeed = { list = list, order = 0 }
end

local function addKillRow(data: any)
	local kf = refs.killFeed
	if not kf then return end
	kf.order -= 1 -- newest on top
	local mine = data.killer == player.DisplayName or data.victim == player.DisplayName
	local row = UIUtil.make("Frame", {
		Parent = kf.list, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Color.PanelDark, BackgroundTransparency = 0.2, BorderSizePixel = 0, LayoutOrder = kf.order,
	})
	UIUtil.corner(UDim.new(0, 8), row)
	if mine then
		UIUtil.stroke(Color3.fromRGB(255, 214, 90), 2, row)
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = row
	local h = Instance.new("UIListLayout")
	h.FillDirection = Enum.FillDirection.Horizontal
	h.VerticalAlignment = Enum.VerticalAlignment.Center
	h.SortOrder = Enum.SortOrder.LayoutOrder
	h.Padding = UDim.new(0, 6)
	h.Parent = row
	local function name(text: string, team: any, order: number)
		UIUtil.label({
			Parent = row, Text = text, Font = Theme.Font.Bold, TextSize = 14, LayoutOrder = order,
			TextColor3 = TEAM_TEXT[team] or Color3.new(1, 1, 1), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
			TextStrokeTransparency = 0.6,
		})
	end
	name(tostring(data.killer or "—"), data.killerTeam, 1)
	if data.ringout then
		local tag = UIUtil.label({
			Parent = row, Text = " RING OUT ", Font = Theme.Font.Heading, TextSize = 11, LayoutOrder = 2,
			TextColor3 = Color3.fromRGB(40, 20, 10), BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 170, 70),
			Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, TextXAlignment = Enum.TextXAlignment.Center,
		})
		UIUtil.corner(UDim.new(0, 4), tag)
	else
		local slot = UIUtil.make("Frame", { Parent = row, Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, LayoutOrder = 2 })
		local w = typeof(data.weaponId) == "string" and Weapons.Get(data.weaponId)
		Icons.Place(w and w.Icon or "Gun", slot, 18, w and w.TrailColor or Color3.new(1, 1, 1), w and w.MuzzleColor or nil)
	end
	name(tostring(data.victim or "?"), data.victimTeam, 3)
	-- Keep the feed short: oldest rows drop off.
	local rows = {}
	for _, c in ipairs(kf.list:GetChildren()) do
		if c:IsA("Frame") then
			table.insert(rows, c)
		end
	end
	table.sort(rows, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	for i = 6, #rows do
		rows[i]:Destroy()
	end
	task.delay(6, function()
		if row.Parent then
			UIUtil.tween(row, 0.3, { BackgroundTransparency = 1 })
			for _, d in ipairs(row:GetDescendants()) do
				if d:IsA("TextLabel") then
					UIUtil.tween(d, 0.3, { TextTransparency = 1, TextStrokeTransparency = 1 })
				end
			end
			task.delay(0.32, function()
				row:Destroy()
			end)
		end
	end)
end

-- ── your knockouts: KNOCKOUT! / RING OUT! with multi-KO chains ───────────────
local KO_CHAIN = { "", "DOUBLE KO!", "TRIPLE KO!", "QUAD KO!" }
local koChain, koLastAt = 0, 0

local function buildKoPop(parent)
	local holder = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.33),
		Size = UDim2.fromOffset(520, 90), BackgroundTransparency = 1, Visible = false,
	})
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local title = UIUtil.label({
		Parent = holder, Text = "", Font = Theme.Font.Title, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 54),
	})
	UIUtil.stroke(Color3.fromRGB(30, 16, 10), 3, title)
	local sub = UIUtil.label({
		Parent = holder, Text = "", Font = Theme.Font.Heading, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 54), Size = UDim2.new(1, 0, 0, 26), TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.4,
	})
	refs.koPop = { holder = holder, scale = scale, title = title, sub = sub, token = 0 }
end

local function showKo(data: any)
	local k = refs.koPop
	if not k then return end
	local now = os.clock()
	koChain = (now - koLastAt < 4) and koChain + 1 or 1
	koLastAt = now
	k.token += 1
	local token = k.token
	k.title.Text = data.ringout and "RING OUT!" or "KNOCKOUT!"
	k.title.TextColor3 = data.ringout and Color3.fromRGB(255, 170, 70) or Color3.fromRGB(255, 220, 90)
	k.sub.Text = koChain >= 2 and (KO_CHAIN[math.min(koChain, #KO_CHAIN)] ~= "" and KO_CHAIN[math.min(koChain, #KO_CHAIN)] or "MAYHEM!") or ("you got " .. tostring(data.victim or "them"))
	if koChain > #KO_CHAIN then
		k.sub.Text = "UNSTOPPABLE x" .. koChain
	end
	k.holder.Visible = true
	k.scale.Scale = 1.6
	TweenService:Create(k.scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(1.4, function()
		if token == k.token then
			k.holder.Visible = false
		end
	end)
end

-- ── first-match tips (new players learn while playing) ────────────────────────
local tipsShown = false

local function tipList(): { string }
	if isMobile() then
		return {
			"Left stick to move  •  JUMP twice to double jump",
			"Tap FIRE to blast  •  every hit raises their knockback %",
			"Knock cats OFF the map to score!",
			"DASH to dodge  •  POUNCE to leap  •  jump off walls",
			"Grab fish snacks to heal  •  supply drops give big rewards",
		}
	end
	return {
		"WASD to move  •  SPACE twice to double jump",
		"Click to blast  •  every hit raises their knockback %",
		"Knock cats OFF the map to score!",
		"Q to dash  •  E to pounce  •  jump off walls",
		"Grab fish snacks to heal  •  supply drops give big rewards",
	}
end

-- Shows the basics one at a time during a new player's first match, then
-- marks the tutorial done.
function HUD.StartTips()
	local p = ClientState.Profile
	if tipsShown or not gui or not p or p.TutorialDone == true then
		return
	end
	tipsShown = true
	local tip = UIUtil.label({
		Parent = gui, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -76),
		Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X, Text = "", Font = Theme.Font.Heading, TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center, BackgroundTransparency = 0.2, BackgroundColor3 = Theme.Color.PanelDark,
	})
	UIUtil.corner(UDim.new(0, 12), tip)
	UIUtil.stroke(Color3.fromRGB(255, 214, 90), 2, tip)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
	pad.Parent = tip
	task.spawn(function()
		task.wait(1.5)
		for _, text in ipairs(tipList()) do
			if not tip.Parent then
				return
			end
			tip.Text = text
			tip.Visible = true
			task.wait(6)
		end
		tip:Destroy()
		Remotes.Get("TutorialDone"):FireServer()
	end)
end

-- ── updates ──────────────────────────────────────────────────────────────────
local function updateScoreBar(m)
	if not refs.timer then return end
	local scores = m.scores or {}
	refs.blueScore.Text = tostring(scores.Blue or 0)
	refs.redScore.Text = tostring(scores.Red or 0)
	local MODE_TEXT = { TDM = "TEAM DEATHMATCH", FFA = "FREE FOR ALL  •  YOU vs LEADER", KOTH = "KING OF THE HILL  •  HOLD THE HILL", Ringout = "RINGOUT  •  KNOCK THEM OFF", CTF = "CAPTURE THE FLAG  •  FIRST TO 3" }
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
		refs.mayhemEdge.Visible = mayhem and hudMode == "Match"
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
	local pcd = MovementController.PounceCooldown()
	local pready = pcd <= 0
	if refs.pounceButton then
		refs.pounceButton.lit(pready)
		refs.pounceButton.timer.Text = pready and "" or string.format("%.1f", pcd)
	end
	if refs.pounceChip then
		refs.pounceChip.key.BackgroundTransparency = pready and 0 or 0.7
		refs.pounceChip.label.Text = pready and "POUNCE" or string.format("%.1f", pcd)
	end
end

local function updateWeapon()
	local profile = ClientState.Profile
	if not refs.weaponName then return end
	-- A supply-drop blaster (on the character) shows instead of the loadout.
	local char = player.Character
	local override = char and char:GetAttribute("WeaponOverride")
	local life = char and char:GetAttribute("Weapon")
	local id = typeof(override) == "string" and override or typeof(life) == "string" and life or (profile and profile.Loadout.Weapon)
	local w = id and Weapons.Get(id)
	if w then
		refs.weaponName.Text = string.upper(w.Name)
		refs.weaponIconSlot:ClearAllChildren()
		Icons.Place(w.Icon or "Gun", refs.weaponIconSlot, 20, w.TrailColor, w.MuzzleColor)
	end
end

-- Which parts each place shows: the whole HUD in a match, the crosshair and
-- weapon at the practice range, only the movement buttons elsewhere in the lobby.
local PARTS = {
	Match = { Score = true, Aim = true, Health = true, Weapon = true, Moves = true, Jump = true, Keys = true, Feed = true, Loadout = true, Abilities = true, TopBar = true },
	Duel = { Duel = true, Aim = true, Health = true, Weapon = true, Moves = true, Jump = true, Keys = true, Feed = true, Loadout = true, Abilities = true, TopBar = true },
	Range = { Aim = true, Weapon = true, Moves = true, Jump = true, Abilities = true },
	-- In the lobby menu only JUMP stays (run / dash / pounce come back in a
	-- match, a duel and the range).
	Lobby = { Jump = true },
}
function HUD.SetMode(mode: string)
	hudMode = mode
	if not gui then return end
	local show = PARTS[mode] or PARTS.Match
	MovementController.AbilitiesEnabled = show.Abilities == true
	for _, c in ipairs(gui:GetChildren()) do
		local part = c:GetAttribute("HudPart")
		if part and c:IsA("GuiObject") then
			c.Visible = show[part] == true
		end
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
	buildDuelBar(gui)
	buildAnnouncer(gui)
	buildCrosshair(gui)
	buildHealth(gui)
	buildAmmo(gui)
	buildDashChip(gui)
	buildAbilities(gui)
	buildTopBar(gui)
	buildLoadoutButton(gui)
	buildRangeHint(gui)
	buildBanners(gui)
	buildMobile(gui)
	buildKillFeed(gui)
	buildKoPop(gui)

	ClientState.ProfileChanged:Connect(updateWeapon)
	ClientState.MatchChanged:Connect(updateScoreBar)
	updateScoreBar(ClientState.Match)
	local function watchCharacter(char: Model)
		char:GetAttributeChangedSignal("WeaponOverride"):Connect(updateWeapon)
		char:GetAttributeChangedSignal("Weapon"):Connect(updateWeapon)
		updateWeapon()
	end
	if player.Character then
		watchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)

	Remotes.Get("Announce").OnClientEvent:Connect(function(data)
		if hudMode == "Match" or hudMode == "Duel" then
			HUD.Announce(data)
		end
	end)
	Remotes.Get("KillFeed").OnClientEvent:Connect(function(data)
		if typeof(data) ~= "table" then return end
		addKillRow(data)
		if data.killer == player.DisplayName and data.victim ~= player.DisplayName then
			showKo(data)
			showKoMarker()
		end
	end)
	Remotes.Get("DuelState").OnClientEvent:Connect(onDuelState)
	Remotes.Get("FinalKO").OnClientEvent:Connect(finalKnockout)
	Remotes.Get("Eliminated").OnClientEvent:Connect(function()
		HUD.ShowBig("ELIMINATED", Theme.Color.Danger, 2)
	end)
	Remotes.Get("Notify").OnClientEvent:Connect(function(data)
		-- (In the lobby the menu's toast shows notices.)
		if hudMode == "Match" or hudMode == "Duel" then
			HUD.ShowElim(data.text or "")
		end
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
