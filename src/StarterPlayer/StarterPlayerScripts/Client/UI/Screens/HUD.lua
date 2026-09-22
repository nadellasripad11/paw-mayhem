--!strict
-- HUD: in-match heads-up display (mirrors the second reference).
--   * Team scores + match timer (top center)
--   * Kill feed (top right)
--   * Mini scoreboard (top left)
--   * Center crosshair with hit/kick feedback
--   * Health bar + active power-up (bottom left)
--   * Weapon name + unlimited ammo (bottom right)
--   * Elimination banner + "Get Ready" countdown + Victory/Defeat
--   * Mobile touch controls (fire / jump / sprint)

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Weapons = require(Shared.Config.Weapons)
local GameConfig = require(Shared.Config.GameConfig)
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

-- ── top center: scores + timer ──────────────────────────────────────────────
local function buildTopBar(parent, topInset)
	local bar = UIUtil.panel({
		Parent = parent,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, topInset + 12),
		Size = UDim2.fromOffset(320, 54),
		BackgroundColor3 = Theme.Color.PanelDark,
	})
	local blue = UIUtil.label({
		Parent = bar, Text = "0", Font = Theme.Font.Number, TextSize = 26,
		TextColor3 = Theme.Color.Blue, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 80, 1, 0), Position = UDim2.fromScale(0, 0),
	})
	local mid = UIUtil.make("Frame", {
		Parent = bar, BackgroundTransparency = 1,
		Size = UDim2.new(0, 160, 1, 0), Position = UDim2.new(0.5, -80, 0, 0),
	})
	local timer = UIUtil.label({
		Parent = mid, Text = "3:00", Font = Theme.Font.Heading, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 26), Position = UDim2.fromOffset(0, 4),
	})
	UIUtil.label({
		Parent = mid, Text = "TEAM DEATHMATCH", Font = Theme.Font.Bold, TextSize = 11,
		TextColor3 = Theme.Color.TextMuted, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 32),
	})
	local red = UIUtil.label({
		Parent = bar, Text = "0", Font = Theme.Font.Number, TextSize = 26,
		TextColor3 = Theme.Color.Red, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(0, 80, 1, 0), Position = UDim2.new(1, -80, 0, 0),
	})
	refs.blueScore, refs.redScore, refs.timer = blue, red, timer
end

-- ── kill feed (top right) ────────────────────────────────────────────────────
local function buildKillFeed(parent, topInset)
	local feed = UIUtil.make("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, topInset + 12),
		Size = UDim2.fromOffset(280, 140),
		BackgroundTransparency = 1,
	})
	local layout = UIUtil.listLayout(feed, 4)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	refs.killFeed = feed
end

local function addKillFeedEntry(data)
	if not refs.killFeed then return end
	local row = UIUtil.panel({
		Parent = refs.killFeed,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Color.PanelDark,
		BackgroundTransparency = 0.1,
	})
	UIUtil.padding(6, row)
	UIUtil.listLayout(row, 6, Enum.FillDirection.Horizontal).VerticalAlignment = Enum.VerticalAlignment.Center
	local kColor = data.killerTeam == "Red" and Theme.Color.Red or Theme.Color.Blue
	local vColor = data.victimTeam == "Red" and Theme.Color.Red or Theme.Color.Blue
	UIUtil.label({ Parent = row, Text = tostring(data.killer), TextColor3 = kColor, Font = Theme.Font.Bold, TextSize = 14, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18) })
	local weapon = data.weaponId and Weapons.Get(data.weaponId)
	local iconSlot = UIUtil.make("Frame", { Parent = row, Size = UDim2.fromOffset(20, 18), BackgroundTransparency = 1 })
	if data.ringout then
		Icons.Place("Burst", iconSlot, 16, Theme.Color.Warn)
	else
		Icons.Place("Gun", iconSlot, 16, (weapon and weapon.TrailColor) or Theme.Color.TextDim)
	end
	UIUtil.label({ Parent = row, Text = tostring(data.victim), TextColor3 = vColor, Font = Theme.Font.Bold, TextSize = 14, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18) })

	task.delay(5, function()
		if row and row.Parent then
			row:Destroy()
		end
	end)
	-- cap entries
	local kids = refs.killFeed:GetChildren()
	local count = 0
	for _, k in ipairs(kids) do
		if k:IsA("Frame") then count += 1 end
	end
	if count > 5 then
		for _, k in ipairs(kids) do
			if k:IsA("Frame") then k:Destroy() break end
		end
	end
end

-- ── mini scoreboard (top left) ───────────────────────────────────────────────
local function buildScoreboard(parent, topInset)
	local sb = UIUtil.panel({
		Parent = parent,
		Position = UDim2.fromOffset(12, topInset + 12),
		Size = UDim2.fromOffset(190, 176),
		BackgroundColor3 = Theme.Color.PanelDark,
		BackgroundTransparency = 0.1,
	})
	UIUtil.padding(8, sb)
	local list = UIUtil.make("Frame", { Parent = sb, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) })
	UIUtil.listLayout(list, 3)
	refs.scoreboard = list
end

local function updateScoreboard(board)
	if not refs.scoreboard then return end
	refs.scoreboard:ClearAllChildren()
	UIUtil.listLayout(refs.scoreboard, 3)
	for i, entry in ipairs(board) do
		if i > 8 then break end
		local row = UIUtil.make("Frame", { Parent = refs.scoreboard, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = i })
		local color = entry.Team == "Red" and Theme.Color.Red or Theme.Color.Blue
		UIUtil.label({ Parent = row, Text = tostring(i), TextColor3 = Theme.Color.TextMuted, TextSize = 12, Size = UDim2.fromOffset(16, 18) })
		UIUtil.label({ Parent = row, Text = entry.Display or entry.Name, TextColor3 = color, TextSize = 13, Font = Theme.Font.Bold, Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -60, 1, 0) })
		UIUtil.label({ Parent = row, Text = tostring(entry.Elims), TextColor3 = Theme.Color.Text, TextSize = 13, Font = Theme.Font.Number, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -40, 0, 0), Size = UDim2.fromOffset(40, 18) })
	end
end

-- ── bottom left: health + power-up ───────────────────────────────────────────
local function buildBottomLeft(parent)
	local wrap = UIUtil.make("Frame", {
		Parent = parent,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(260, 60),
		BackgroundTransparency = 1,
	})
	local track = UIUtil.make("Frame", {
		Parent = wrap, Position = UDim2.fromOffset(0, 28), Size = UDim2.fromOffset(200, 20),
		BackgroundColor3 = Theme.Color.PanelDark, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), track)
	UIUtil.stroke(Theme.Color.Stroke, 1.5, track)
	local fill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.Success, BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), fill)
	UIUtil.gradient(Color3.fromRGB(120, 230, 140), Color3.fromRGB(80, 190, 110), 0, fill)
	local hpText = UIUtil.label({ Parent = track, Text = "100", Font = Theme.Font.Number, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 2 })

	local power = UIUtil.panel({
		Parent = wrap, Position = UDim2.fromOffset(210, 20), Size = UDim2.fromOffset(40, 40),
		BackgroundColor3 = Theme.Color.PanelDark, Visible = false,
	})
	local powerIconSlot = UIUtil.make("Frame", { Parent = power, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

	refs.hpFill, refs.hpText, refs.power, refs.powerIconSlot = fill, hpText, power, powerIconSlot
end

-- ── bottom right: weapon + ammo ──────────────────────────────────────────────
local function buildBottomRight(parent)
	local wrap = UIUtil.panel({
		Parent = parent,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -12),
		Size = UDim2.fromOffset(200, 56),
		BackgroundColor3 = Theme.Color.PanelDark,
	})
	UIUtil.padding(8, wrap)
	local name = UIUtil.label({ Parent = wrap, Text = "Paw Blaster", Font = Theme.Font.Heading, TextSize = 16, Size = UDim2.new(1, -40, 0, 20) })
	UIUtil.label({ Parent = wrap, Text = "UNLIMITED AMMO", Font = Theme.Font.Bold, TextSize = 11, TextColor3 = Theme.Color.TextDim, Size = UDim2.new(1, -40, 0, 16), Position = UDim2.fromOffset(0, 22) })
	local icon = UIUtil.make("Frame", { Parent = wrap, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Theme.Color.Accent, BorderSizePixel = 0 })
	UIUtil.corner(Theme.CornerSmall, icon)
	local iconSlot = UIUtil.make("Frame", { Parent = icon, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	refs.weaponName, refs.weaponIcon, refs.weaponIconSlot = name, icon, iconSlot
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
local function buildMobile(parent)
	if not isMobile() then return end
	local function touchButton(pos, size, text, color)
		local b = UIUtil.button({
			Parent = parent, AnchorPoint = Vector2.new(1, 1), Position = pos, Size = size,
			BackgroundColor3 = color, Text = text, TextSize = 22, CornerRadius = UDim.new(1, 0),
			BackgroundTransparency = 0.15,
		})
		UIUtil.stroke(Color3.fromRGB(255, 255, 255), 2, b).Transparency = 0.5
		return b
	end
	local fire = touchButton(UDim2.new(1, -30, 1, -90), UDim2.fromOffset(96, 96), "FIRE", Theme.Color.Danger)
	fire.MouseButton1Down:Connect(function() CombatController.SetFiring(true) end)
	fire.MouseButton1Up:Connect(function() CombatController.SetFiring(false) end)

	local jump = touchButton(UDim2.new(1, -140, 1, -60), UDim2.fromOffset(74, 74), "JUMP", Theme.Color.Accent)
	jump.MouseButton1Down:Connect(function()
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if hum then hum.Jump = true end
	end)

	local sprint = touchButton(UDim2.new(1, -140, 1, -150), UDim2.fromOffset(74, 74), "RUN", Theme.Color.Accent2)
	sprint.MouseButton1Click:Connect(function() MovementController.ToggleSprint() end)
end

-- ── updates ──────────────────────────────────────────────────────────────────
local function onMatch(m)
	if refs.blueScore then
		refs.blueScore.Text = tostring(m.scores.Blue or 0)
		refs.redScore.Text = tostring(m.scores.Red or 0)
		local mins = math.floor((m.timeLeft or 0) / 60)
		local secs = (m.timeLeft or 0) % 60
		refs.timer.Text = string.format("%d:%02d", mins, secs)
	end
	if m.board then updateScoreboard(m.board) end
end

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
			refs.weaponName.Text = w.Name
			local skin = Weapons.GetSkin(profile.Loadout.Skin)
			refs.weaponIcon.BackgroundColor3 = skin.Tint
			if refs.weaponIconSlot then
				refs.weaponIconSlot:ClearAllChildren()
				Icons.Place("Gun", refs.weaponIconSlot, 22, w.TrailColor, w.MuzzleColor)
			end
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

	local topInset = UIUtil.topInset()

	buildCrosshair(gui)
	buildTopBar(gui, topInset)
	buildKillFeed(gui, topInset)
	buildScoreboard(gui, topInset)
	buildBottomLeft(gui)
	buildBottomRight(gui)
	buildBanners(gui)
	buildMobile(gui)

	-- Hooks
	ClientState.MatchChanged:Connect(onMatch)
	ClientState.ProfileChanged:Connect(updateWeapon)

	Remotes.Get("KillFeed").OnClientEvent:Connect(addKillFeedEntry)
	Remotes.Get("Eliminated").OnClientEvent:Connect(function(data)
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
			if refs.powerIconSlot then
				refs.powerIconSlot:ClearAllChildren()
				Icons.Place(POWERUP_ICON[data.powerId] or "Sparkle", refs.powerIconSlot, 24, Color3.new(1, 1, 1))
			end
			task.delay(data.duration or 10, function()
				if refs.power then refs.power.Visible = false end
			end)
		end
	end)

	EffectsController.OnHitConfirm = function(data)
		kickCrosshair()
		HUD.ShowElim(string.format("HIT  •  %d fluff", math.floor(data.accumulated or 0)))
	end
	CombatController.OnLocalShot = function()
		kickCrosshair()
	end

	-- health + weapon refresh loop
	task.spawn(function()
		while gui.Parent do
			updateHealth()
			task.wait(0.1)
		end
	end)
	updateWeapon()
end

return HUD
