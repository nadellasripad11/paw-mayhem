--!strict
-- MainMenu: the lobby shell (mirrors reference 1). Left nav switches panels in
-- the content area. Top-right shows coins/gems; bottom-left shows the cat
-- portrait + level bar. "Play" shows match status, a map preview, and a
-- power-up legend.

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Progression = require(ReplicatedStorage.Shared.Config.Progression)
local Cats = require(ReplicatedStorage.Shared.Config.Cats)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local HeroArt = require(script.Parent.Parent.HeroArt)
local ClientState = require(script.Parent.Parent.Parent.ClientState)

local Loadout = require(script.Parent.Loadout)
local Shop = require(script.Parent.Shop)
local Customize = require(script.Parent.Customize)
local Leaderboard = require(script.Parent.Leaderboard)
local Quests = require(script.Parent.Quests)
local Settings = require(script.Parent.Settings)

local MainMenu = {}
local player = Players.LocalPlayer

local gui, content, panels, coinLabel, gemLabel, levelLabel, levelFill, xpLabel, playStatus, avatarSlot
local currentPanel

local NAV = {
	{ id = "Play", label = "Play", icon = "Play", color = Theme.Color.Play },
	{ id = "Loadout", label = "Loadout", icon = "Gun" },
	{ id = "Shop", label = "Shop", icon = "Cart" },
	{ id = "Customize", label = "Customize", icon = "Paw" },
	{ id = "Leaderboard", label = "Leaderboard", icon = "Trophy" },
	{ id = "Quests", label = "Quests", icon = "Check" },
	{ id = "Settings", label = "Settings", icon = "Gear" },
}

local function switchTo(id)
	for pid, root in pairs(panels) do
		if root then
			root.Visible = (pid == id)
		end
	end
	currentPanel = id
end

-- Builds a panel with a name for error reporting, wrapped in pcall so a bug in
-- one screen can never blank out the others (each nav tab still shows SOMETHING).
local function safeBuild(name: string, parent: Instance, builder: (Instance) -> Frame): Frame
	local ok, result = pcall(builder, parent)
	if ok and typeof(result) == "Instance" then
		return result :: Frame
	end
	warn(string.format("[PAW MAYHEM] UI panel '%s' failed to build: %s", name, tostring(result)))
	local fallback = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }) :: Frame
	local card = UIUtil.panel({ Parent = fallback, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 140), BackgroundColor3 = Theme.Color.PanelDark })
	UIUtil.label({ Parent = card, Text = name .. " is temporarily unavailable.", TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), TextColor3 = Theme.Color.TextMuted, TextWrapped = true })
	return fallback
end

-- ── Play tab: match card + map preview + power-up legend + effects strip ────
local function buildMapCard(parent)
	local card = UIUtil.panel({ Parent = parent, Size = UDim2.new(0, 220, 1, 0), Position = UDim2.fromOffset(0, 0), BackgroundColor3 = Theme.Color.PanelDark })
	UIUtil.padding(12, card)
	local preview = UIUtil.make("Frame", { Parent = card, Size = UDim2.new(1, 0, 0, 110), BackgroundColor3 = Color3.fromRGB(90, 150, 220), BorderSizePixel = 0, ClipsDescendants = true })
	UIUtil.corner(Theme.CornerSmall, preview)
	UIUtil.gradient(Color3.fromRGB(130, 190, 255), Color3.fromRGB(70, 120, 190), 90, preview)
	-- Real miniature island illustration (same art as the menu background),
	-- not an abstract dot map — a small pcall-guarded HeroArt.Island scaled down.
	pcall(function()
		local mini = HeroArt.Island(preview, { width = 260, position = UDim2.fromScale(0.5, 1.15) })
		mini.ZIndex = 2
	end)
	local mapNameLabel = UIUtil.label({ Parent = card, Text = "…", Font = Theme.Font.Heading, TextSize = 15, Position = UDim2.fromOffset(0, 118), Size = UDim2.new(1, 0, 0, 20) })
	UIUtil.label({ Parent = card, Text = "Team Deathmatch  •  7 islands  •  6 spawns each  •  1 of 3 maps", TextColor3 = Theme.Color.TextDim, TextSize = 11, Position = UDim2.fromOffset(0, 138), Size = UDim2.new(1, 0, 0, 16), TextWrapped = true })

	-- The active map is chosen server-side each session (ArenaBuilder picks
	-- randomly from Sky Islands / Volcano / Toybox) and replicated as an
	-- attribute on Workspace.Arena — read it live instead of hardcoding a name.
	local function applyMapName()
		local arena = workspace:FindFirstChild("Arena")
		local name = arena and arena:GetAttribute("MapName")
		mapNameLabel.Text = (name and string.upper(name)) or "LOADING MAP…"
	end
	task.spawn(function()
		local arena = workspace:WaitForChild("Arena", 15)
		applyMapName()
		if arena then
			arena:GetAttributeChangedSignal("MapName"):Connect(applyMapName)
		end
	end)

	return card
end

local EFFECTS_CATALOG = {
	{ id = "Shoot", icon = "Gun", color = Theme.Color.Accent2, desc = "Tracer bolt on every shot" },
	{ id = "HitEffect", label = "Hit Effect", icon = "Burst", color = Theme.Color.Danger, desc = "Impact spark + screen flash" },
	{ id = "Knockback", icon = "Bolt", color = Theme.Color.Warn, desc = "Physics launch impulse" },
	{ id = "Elimination", icon = "Trophy", color = Theme.Color.Coin, desc = "Kill feed + banner" },
	{ id = "PowerUp", label = "Power-Up", icon = "Sparkle", color = Theme.Color.Gem, desc = "Pickup sparkle burst" },
	{ id = "Victory", icon = "Trophy", color = Theme.Color.Play, desc = "Match-end celebration" },
}

local function buildEffectsStrip(parent)
	local card = UIUtil.panel({ Parent = parent, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.PanelDark })
	UIUtil.padding(12, card)
	UIUtil.label({ Parent = card, Text = "ANIMATIONS & EFFECTS", Font = Theme.Font.Heading, TextSize = 13, TextColor3 = Theme.Color.TextDim, Size = UDim2.new(1, 0, 0, 18) })
	local row = UIUtil.make("Frame", { Parent = card, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26), BackgroundTransparency = 1 })
	UIUtil.listLayout(row, 10, Enum.FillDirection.Horizontal).VerticalAlignment = Enum.VerticalAlignment.Top
	for _, e in ipairs(EFFECTS_CATALOG) do
		local chip = UIUtil.make("Frame", { Parent = row, Size = UDim2.fromOffset(72, 84), BackgroundTransparency = 1 })
		local swatch = UIUtil.make("Frame", { Parent = chip, Size = UDim2.fromOffset(56, 56), BackgroundColor3 = e.color, BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(0.3, 0), swatch)
		Icons.Place(e.icon, swatch, 30, Color3.new(1, 1, 1))
		UIUtil.label({ Parent = chip, Text = e.label or e.id, TextXAlignment = Enum.TextXAlignment.Center, TextSize = 10, Font = Theme.Font.Bold, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 24), TextWrapped = true })
	end
	return card
end

-- A human-readable effect line built from the power-up's REAL config values
-- (GameConfig.PowerUps.Duration + whichever multiplier field it defines) —
-- not decorative text, the actual numbers the server applies.
local function powerUpEffectText(p)
	local bits = {}
	if p.FireRateMult then table.insert(bits, string.format("%.1fx Fire Rate", p.FireRateMult)) end
	if p.KnockbackMult then table.insert(bits, string.format("%.1fx Knockback", p.KnockbackMult)) end
	if p.DamageResist then table.insert(bits, string.format("-%d%% Damage Taken", p.DamageResist * 100)) end
	if p.SpeedMult then table.insert(bits, string.format("%.1fx Speed", p.SpeedMult)) end
	if p.ExtraPellets then table.insert(bits, string.format("+%d Pellets", p.ExtraPellets)) end
	table.insert(bits, GameConfig.PowerUps.Duration .. "s")
	return table.concat(bits, " · ")
end

local function buildPowerUpStrip(parent)
	local card = UIUtil.panel({ Parent = parent, Size = UDim2.new(1, -236, 1, 0), Position = UDim2.fromOffset(236, 0), BackgroundColor3 = Theme.Color.PanelDark })
	UIUtil.padding(12, card)
	UIUtil.label({ Parent = card, Text = "POWER-UPS ON THE MAP", Font = Theme.Font.Heading, TextSize = 13, TextColor3 = Theme.Color.TextDim, Size = UDim2.new(1, 0, 0, 18) })
	local row = UIUtil.make("ScrollingFrame", {
		Parent = card, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 1, -26),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollingDirection = Enum.ScrollingDirection.X,
	})
	UIUtil.listLayout(row, 10, Enum.FillDirection.Horizontal).VerticalAlignment = Enum.VerticalAlignment.Top
	local iconFor = { RapidFire = "Bolt", MegaKnockback = "Burst", Shield = "Shield", SpeedBoost = "Bolt", MultiShot = "MultiShot" }
	for _, p in ipairs(Progression.PowerUps) do
		local chip = UIUtil.make("Frame", { Parent = row, Size = UDim2.fromOffset(112, 128), BackgroundTransparency = 1 })
		local swatch = UIUtil.make("Frame", { Parent = chip, Size = UDim2.fromOffset(56, 56), Position = UDim2.fromOffset(28, 0), BackgroundColor3 = p.Color, BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(0.3, 0), swatch)
		Icons.Place(iconFor[p.Id] or "Sparkle", swatch, 30, Color3.new(1, 1, 1))
		UIUtil.label({ Parent = chip, Text = p.Name, TextXAlignment = Enum.TextXAlignment.Center, TextSize = 12, Font = Theme.Font.Bold, Position = UDim2.fromOffset(0, 60), Size = UDim2.new(1, 0, 0, 18), TextWrapped = true })
		UIUtil.label({ Parent = chip, Text = powerUpEffectText(p), TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center, TextSize = 9, Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 40), TextWrapped = true })
	end
	return card
end

local function buildPlayPanel(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = true }) :: Frame

	local card = UIUtil.panel({ Parent = root, Size = UDim2.new(1, 0, 0, 220), BackgroundColor3 = Theme.Color.PanelDark })
	UIUtil.padding(20, card)
	UIUtil.label({ Parent = card, Text = "TEAM DEATHMATCH", Font = Theme.Font.Title, TextSize = 28, Size = UDim2.new(1, 0, 0, 36) })
	UIUtil.label({ Parent = card, Text = "Blast cats off the floating islands. First team to " .. GameConfig.Match.ScoreToWin .. " wins.", TextColor3 = Theme.Color.TextDim, TextSize = 13, TextWrapped = true, Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 38) })
	playStatus = UIUtil.label({ Parent = card, Text = "Waiting for match…", TextColor3 = Theme.Color.Accent, Font = Theme.Font.Bold, TextSize = 15, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 76) })
	local playBtn = UIUtil.button({ Parent = card, Position = UDim2.fromOffset(0, 108), Size = UDim2.fromOffset(230, 52), BackgroundColor3 = Theme.Color.Play, Text = "", TextSize = 22, Font = Theme.Font.Title })
	Icons.Place("Play", playBtn, 18, Color3.new(1, 1, 1), nil, UDim2.new(0, 22, 0.5, 0))
	local playLbl = UIUtil.label({ Parent = playBtn, Text = "PLAY", Font = Theme.Font.Title, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(10, 0) })
	playBtn.MouseButton1Click:Connect(function()
		playStatus.Text = "You'll spawn when the next match begins!"
	end)

	local lowerRow = UIUtil.make("Frame", { Parent = root, Position = UDim2.fromOffset(0, 236), Size = UDim2.new(1, 0, 0, 176), BackgroundTransparency = 1 })
	buildMapCard(lowerRow)
	buildPowerUpStrip(lowerRow)

	local effectsRow = UIUtil.make("Frame", { Parent = root, Position = UDim2.fromOffset(0, 422), Size = UDim2.new(1, 0, 0, 110), BackgroundTransparency = 1 })
	buildEffectsStrip(effectsRow)

	return root
end

-- ── currency chips + portrait ────────────────────────────────────────────────
local function refreshCurrency()
	local p = ClientState.Profile
	if not p then
		return
	end
	coinLabel.Text = tostring(p.Coins)
	gemLabel.Text = tostring(p.Gems)
	levelLabel.Text = "Lv. " .. tostring(p.Level or 1)
	local frac = (p.LevelNeed and p.LevelNeed > 0) and (p.LevelXP / p.LevelNeed) or 0
	levelFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
	if xpLabel then
		xpLabel.Text = string.format("%d / %d XP", p.LevelXP or 0, p.LevelNeed or 0)
	end

	if avatarSlot then
		avatarSlot:ClearAllChildren()
		local fur = Cats.FurById[p.Loadout.Cat.Fur] or Cats.FurById[Cats.Default.Fur]
		Icons.Place("CatFace", avatarSlot, 40, fur.Body, fur.Accent)
	end
end

local function refreshPlayStatus(m)
	if not playStatus then
		return
	end
	if m.phase == "Intermission" then
		playStatus.Text = "Next match in " .. (m.timeLeft or 0) .. "s"
	elseif m.phase == "Countdown" then
		playStatus.Text = "Get ready! " .. (m.timeLeft or 0)
	elseif m.phase == "Playing" then
		playStatus.Text = "Match in progress — jump in!"
	elseif m.phase == "Results" then
		playStatus.Text = "Match over — results…"
	end
end

function MainMenu.SetVisible(on: boolean)
	if gui then
		gui.Enabled = on
	end
end

function MainMenu.Build()
	gui = UIUtil.make("ScreenGui", {
		Name = "PawMainMenu", Parent = player:WaitForChild("PlayerGui"),
		IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 3, Enabled = true,
	}) :: ScreenGui

	local topInset = UIUtil.topInset()

	-- Hero background scene: sky, a big floating island with a windmill/trees/
	-- waterfall, and a fully-posed cat holding a blaster (reference 1's
	-- composition, built entirely from Frames — see HeroArt.lua). A dim overlay
	-- keeps foreground text readable on top of it.
	-- Every HeroArt call is pcall-guarded: if the decorative scene ever throws,
	-- the menu must still render (nav/title/panels are what actually matter).
	local sceneLayer = UIUtil.make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 1 })
	local sceneOk, sceneErr = pcall(function()
		HeroArt.Sky(sceneLayer)
		HeroArt.Island(sceneLayer, { width = 1100, position = UDim2.fromScale(0.5, 1.08) })
		HeroArt.HeroCat(sceneLayer, {
			size = 420,
			fur = Color3.fromRGB(245, 245, 245),
			accent = Color3.fromRGB(210, 215, 230),
			gunColor = Color3.fromRGB(140, 90, 255),
			gunAccent = Color3.fromRGB(95, 210, 255),
			position = UDim2.fromScale(0.82, 1.0),
		})
	end)
	if not sceneOk then
		warn("[PAW MAYHEM] Hero scene failed (non-fatal, skipped): " .. tostring(sceneErr))
		-- Fall back to a flat gradient so the menu still looks intentional.
		UIUtil.gradient(Color3.fromRGB(30, 40, 70), Color3.fromRGB(14, 18, 32), 90, sceneLayer)
		sceneLayer.BackgroundTransparency = 0
		sceneLayer.BackgroundColor3 = Theme.Color.Bg
	end
	local dim = UIUtil.make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 20), BackgroundTransparency = 0.4, BorderSizePixel = 0, ZIndex = 8 })
	UIUtil.gradient(Color3.fromRGB(8, 10, 20), Color3.fromRGB(8, 10, 20), 0, dim).Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.15),
		NumberSequenceKeypoint.new(0.4, 0.55),
		NumberSequenceKeypoint.new(1, 0.75),
	})

	-- Title (top left) — offset below Roblox's own topbar so nothing overlaps.
	local title = UIUtil.label({ Parent = gui, Text = "PAW MAYHEM", Font = Theme.Font.Title, TextSize = 38, Position = UDim2.fromOffset(24, topInset + 10), Size = UDim2.fromOffset(360, 46), ZIndex = 10, TextStrokeTransparency = 0.5 })
	title.TextColor3 = Theme.Color.Coin
	UIUtil.label({ Parent = gui, Text = "Small cats. Big knockback. Endless fun.", TextColor3 = Theme.Color.TextDim, TextSize = 14, Position = UDim2.fromOffset(26, topInset + 52), Size = UDim2.fromOffset(360, 20) })

	-- Currency (top right)
	local curr = UIUtil.make("Frame", { Parent = gui, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, topInset + 12), Size = UDim2.fromOffset(260, 40), BackgroundTransparency = 1, ZIndex = 10 })
	UIUtil.listLayout(curr, 10, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Right
	local function chip(iconName, color)
		local c = UIUtil.panel({ Parent = curr, Size = UDim2.fromOffset(120, 40), BackgroundColor3 = Theme.Color.PanelDark })
		local iconSlot = UIUtil.make("Frame", { Parent = c, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1 })
		Icons.Place(iconName, iconSlot, 24, color)
		local l = UIUtil.label({ Parent = c, Text = "0", Font = Theme.Font.Number, TextSize = 18, Position = UDim2.fromOffset(40, 0), Size = UDim2.new(1, -48, 1, 0) })
		return l
	end
	coinLabel = chip("Coin", Theme.Color.Coin)
	gemLabel = chip("Gem", Theme.Color.Gem)

	-- Left nav
	local nav = UIUtil.panel({ Parent = gui, Position = UDim2.fromOffset(24, topInset + 88), Size = UDim2.fromOffset(200, 372), BackgroundColor3 = Theme.Color.Panel, ZIndex = 10, BackgroundTransparency = 0.05 })
	UIUtil.padding(10, nav)
	UIUtil.listLayout(nav, 8)
	for i, item in ipairs(NAV) do
		local btn = UIUtil.button({
			Parent = nav, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = i,
			BackgroundColor3 = item.color or Theme.Color.PanelLight,
			Text = "", TextSize = 16, Font = Theme.Font.Bold,
		}, function()
			switchTo(item.id)
		end)
		local iconSlot = UIUtil.make("Frame", { Parent = btn, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(12, 21), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1 })
		Icons.Place(item.icon, iconSlot, 20, Theme.Color.Text)
		UIUtil.label({ Parent = btn, Text = item.label, Font = Theme.Font.Bold, TextSize = 16, TextColor3 = Theme.Color.Text, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -50, 1, 0) })
	end

	-- Cat portrait + level (bottom left)
	local portrait = UIUtil.panel({ Parent = gui, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 24, 1, -20), Size = UDim2.fromOffset(240, 78), BackgroundColor3 = Theme.Color.PanelDark, ZIndex = 10 })
	UIUtil.padding(8, portrait)
	avatarSlot = UIUtil.make("Frame", { Parent = portrait, Size = UDim2.fromOffset(44, 44), BackgroundColor3 = Theme.Color.PanelLight, BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(0.5, 0), avatarSlot)
	Icons.Place("CatFace", avatarSlot, 40, Theme.Color.Coin)
	levelLabel = UIUtil.label({ Parent = portrait, Text = "Lv. 1", Font = Theme.Font.Bold, TextSize = 14, Position = UDim2.fromOffset(52, 4), Size = UDim2.new(1, -56, 0, 18) })
	local lvTrack = UIUtil.make("Frame", { Parent = portrait, Position = UDim2.fromOffset(52, 26), Size = UDim2.new(1, -60, 0, 12), BackgroundColor3 = Theme.Color.PanelLight, BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), lvTrack)
	levelFill = UIUtil.make("Frame", { Parent = lvTrack, Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Color.Accent, BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), levelFill)
	xpLabel = UIUtil.label({ Parent = portrait, Text = "0 / 0 XP", TextColor3 = Theme.Color.TextMuted, TextSize = 10, Position = UDim2.fromOffset(52, 42), Size = UDim2.new(1, -60, 0, 14) })

	-- Content area (right of nav)
	content = UIUtil.make("Frame", { Parent = gui, Position = UDim2.fromOffset(240, topInset + 88), Size = UDim2.new(1, -264, 1, -(topInset + 162)), BackgroundTransparency = 1, ZIndex = 10 })

	-- Build every panel defensively: a crash in one never blanks the others.
	panels = {}
	panels.Play = safeBuild("Play", content, buildPlayPanel)
	panels.Loadout = safeBuild("Loadout", content, Loadout.Build)
	panels.Shop = safeBuild("Shop", content, Shop.Build)
	panels.Customize = safeBuild("Customize", content, Customize.Build)
	panels.Leaderboard = safeBuild("Leaderboard", content, Leaderboard.Build)
	panels.Quests = safeBuild("Quests", content, Quests.Build)
	panels.Settings = safeBuild("Settings", content, Settings.Build)
	switchTo("Play")

	ClientState.ProfileChanged:Connect(refreshCurrency)
	ClientState.MatchChanged:Connect(refreshPlayStatus)
	if ClientState.Profile then
		refreshCurrency()
	end

	return gui
end

return MainMenu
