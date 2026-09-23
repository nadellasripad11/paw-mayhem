--!strict
-- HUD: in-match heads-up display, kept deliberately minimal:
--   * Center crosshair with shot/hit kick
--   * Compact health bar + active power-up (bottom left)
--   * Small weapon + ammo pill (bottom center)
--   * Mobile only: FIRE / JUMP / RUN buttons (bottom right)
--   * Transient banners: countdown, Get Ready, Eliminated, notices
-- Roblox's player list, health bar, backpack and mobile jump button are hidden
-- so they don't duplicate or clutter it.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")

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

local HUD = {}
local player = Players.LocalPlayer

local gui: ScreenGui
local refs: any = {}
local POWERUP_ICON = { RapidFire = "Bolt", MegaKnockback = "Burst", Shield = "Shield", SpeedBoost = "Bolt", MultiShot = "MultiShot" }

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
	arm(0); arm(90)
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
end

local function kickCrosshair()
	if not refs.crosshair then return end
	local c = refs.crosshair
	c.Size = UDim2.fromOffset(40, 40)
	UIUtil.tween(c, 0.15, { Size = UDim2.fromOffset(28, 28) })
end

-- ── bottom left: compact health + power-up ───────────────────────────────────
local function buildHealth(parent)
	local wrap = UIUtil.make("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -14),
		Size = UDim2.fromOffset(200, 28),
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
		Parent = wrap, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 168, 0.5, 0),
		Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Theme.Color.PanelDark, BorderSizePixel = 0, Visible = false,
	})
	UIUtil.corner(UDim.new(1, 0), power)
	local powerIconSlot = UIUtil.make("Frame", { Parent = power, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

	refs.hpFill, refs.hpText, refs.power, refs.powerIconSlot = fill, hpText, power, powerIconSlot
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
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then hum.Jump = true end
		end
	end)
	jump.InputEnded:Connect(function(input)
		if isPress(input) then jumpPressed(false) end
	end)

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

-- ── updates ──────────────────────────────────────────────────────────────────
local function updateHealth()
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and refs.hpFill then
		local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
		refs.hpFill.Size = UDim2.fromScale(frac, 1)
		refs.hpText.Text = tostring(math.ceil(hum.Health))
	end
end

local function updateWeapon()
	local profile = ClientState.Profile
	if profile and refs.weaponName then
		local w = Weapons.Get(profile.Loadout.Weapon)
		if w then
			refs.weaponName.Text = string.upper(w.Name)
			refs.weaponIconSlot:ClearAllChildren()
			Icons.Place(w.Icon or "Gun", refs.weaponIconSlot, 20, w.TrailColor, w.MuzzleColor)
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

	buildCrosshair(gui)
	buildHealth(gui)
	buildAmmo(gui)
	buildBanners(gui)
	buildMobile(gui)

	ClientState.ProfileChanged:Connect(updateWeapon)

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
	end
	CombatController.OnLocalShot = function()
		kickCrosshair()
	end

	task.spawn(function()
		while gui.Parent do
			updateHealth()
			task.wait(0.1)
		end
	end)
	updateWeapon()
end

return HUD
