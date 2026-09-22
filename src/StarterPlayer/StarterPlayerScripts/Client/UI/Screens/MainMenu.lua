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
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

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
local navButtons = {}
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
	for pid, button in pairs(navButtons) do
		local active = pid == id
		button.BackgroundColor3 = active and Theme.Color.Accent or Theme.Color.PanelLight
		local label = button:FindFirstChild("NavLabel")
		if label then
			label.TextColor3 = active and Color3.fromRGB(7, 35, 58) or Theme.Color.Text
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
	UIUtil.label({ Parent = card, Text = name .. " needs a fresh lobby load.\nChoose Play to continue.", TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), TextColor3 = Theme.Color.TextMuted, TextWrapped = true })
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
	-- The pre-match surface is a real three-card map vote, matching the
	-- reference flow: choose an arena first, then load into the round.
	local MAPS = {
		{ id = "SkyIslands", name = "Sky Islands", subtitle = "Floating Village", accent = Color3.fromRGB(95, 205, 255), kind = "sky" },
		{ id = "Volcano", name = "Volcano", subtitle = "Lava Foundry", accent = Color3.fromRGB(255, 120, 54), kind = "volcano" },
		{ id = "Toybox", name = "Toybox", subtitle = "Candy Playground", accent = Color3.fromRGB(255, 133, 190), kind = "toy" },
	}
	local selectedMapId = "SkyIslands"
	local cards = {}

	local shell = UIUtil.panel({ Parent = root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(7, 35, 61), BackgroundTransparency = 0.06, ZIndex = 10 })
	UIUtil.padding(18, shell)
	UIUtil.label({ Parent = shell, Text = "MAPS", Font = Theme.Font.Title, TextSize = 26, Size = UDim2.new(1, -260, 0, 32), ZIndex = 11 })
	UIUtil.label({ Parent = shell, Text = "Choose your arena before dropping into Team Deathmatch.", TextColor3 = Theme.Color.TextDim, TextSize = 12, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, -260, 0, 18), ZIndex = 11 })
	local teamPill = UIUtil.panel({ Parent = shell, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(230, 48), BackgroundColor3 = Theme.Color.PanelDark, ZIndex = 11 })
	UIUtil.label({ Parent = teamPill, Text = "BLUE PAWS     3  v  3     RED CLAWS", Font = Theme.Font.Bold, TextSize = 10, TextColor3 = Theme.Color.Accent, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 12 })

	local row = UIUtil.make("Frame", { Parent = shell, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 270), BackgroundTransparency = 1, ZIndex = 11 })
	UIUtil.listLayout(row, 10, Enum.FillDirection.Vertical).HorizontalAlignment = Enum.HorizontalAlignment.Center

	local function addToyShapes(parent, map)
		if map.kind == "volcano" then
			for i = 1, 5 do
				local rock = UIUtil.make("Frame", { Parent = parent, Size = UDim2.fromOffset(48 + (i % 2) * 14, 34 + (i % 3) * 9), Position = UDim2.fromScale(0.08 + i * 0.17, 0.42 - (i % 2) * 0.08), BackgroundColor3 = Color3.fromRGB(58, 38, 55), BorderSizePixel = 0, ZIndex = 12 })
				UIUtil.corner(UDim.new(0, 7), rock)
				local lava = UIUtil.make("Frame", { Parent = rock, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0.42, 0, 0.72, 0), BackgroundColor3 = Color3.fromRGB(255, 118 + i * 12, 42), BorderSizePixel = 0, ZIndex = 13 })
				UIUtil.corner(UDim.new(0, 5), lava)
			end
		elseif map.kind == "toy" then
			for i = 1, 7 do
				local block = UIUtil.make("Frame", { Parent = parent, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromScale(0.08 + (i % 4) * 0.23, 0.34 + math.floor(i / 4) * 0.14), BackgroundColor3 = ({ Color3.fromRGB(255, 117, 156), Color3.fromRGB(113, 204, 255), Color3.fromRGB(255, 218, 93), Color3.fromRGB(180, 142, 255) })[(i % 4) + 1], BorderSizePixel = 0, ZIndex = 12 })
				UIUtil.corner(UDim.new(0, 5), block)
			end
		end
	end

	local function selectMap(map)
		selectedMapId = map.id
		for _, entry in ipairs(cards) do
			local active = entry.map.id == selectedMapId
			entry.card.BackgroundColor3 = active and Color3.fromRGB(24, 75, 88) or Theme.Color.Panel
			entry.stroke.Color = active and entry.map.accent or Theme.Color.Stroke
			entry.stroke.Thickness = active and 2.5 or 1.5
			entry.check.Visible = active
		end
	end

	for _, map in ipairs(MAPS) do
		local card = UIUtil.panel({ Parent = row, Size = UDim2.new(1, 0, 0, 82), BackgroundColor3 = Theme.Color.Panel, ClipsDescendants = true, ZIndex = 11 })
		local stroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
		local preview = UIUtil.make("Frame", { Parent = card, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 66), BackgroundColor3 = map.accent, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 12 })
		UIUtil.corner(Theme.CornerSmall, preview)
		if map.kind == "sky" then
			pcall(function()
				HeroArt.Sky(preview)
				HeroArt.Island(preview, { width = 170, position = UDim2.fromScale(0.26, 1.12) })
				HeroArt.Island(preview, { width = 230, position = UDim2.fromScale(0.70, 1.13) })
			end)
		elseif map.kind == "volcano" then
			UIUtil.gradient(Color3.fromRGB(110, 43, 43), Color3.fromRGB(24, 17, 30), 90, preview)
			addToyShapes(preview, map)
		else
			UIUtil.gradient(Color3.fromRGB(113, 206, 255), Color3.fromRGB(236, 137, 202), 90, preview)
			addToyShapes(preview, map)
		end
		local tag = UIUtil.panel({ Parent = preview, Position = UDim2.fromOffset(10, 34), Size = UDim2.fromOffset(170, 26), BackgroundColor3 = Theme.Color.PanelDark, BackgroundTransparency = 0.08, ZIndex = 14 })
		local title = UIUtil.label({ Parent = tag, Text = map.name, Font = Theme.Font.Heading, TextSize = 15, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0), ZIndex = 15 })
		UIUtil.label({ Parent = card, Text = map.subtitle, Font = Theme.Font.Bold, TextSize = 11, TextColor3 = map.accent, Position = UDim2.fromOffset(200, 16), Size = UDim2.new(0.45, 0, 0, 16), ZIndex = 13 })
		UIUtil.label({ Parent = card, Text = "TEAM DEATHMATCH  •  6 GROUNDED SPAWNS", TextSize = 9, TextColor3 = Theme.Color.TextMuted, Position = UDim2.fromOffset(200, 39), Size = UDim2.new(0.58, 0, 0, 14), ZIndex = 13 })
		local check = UIUtil.label({ Parent = card, Text = "✓ SELECTED", Font = Theme.Font.Bold, TextSize = 10, TextColor3 = Color3.fromRGB(182, 241, 112), TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -132, 0, 14), Size = UDim2.fromOffset(116, 18), Visible = false, ZIndex = 13 })
		local hit = UIUtil.button({ Parent = card, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 20 }, function() selectMap(map) end)
		table.insert(cards, { map = map, card = card, stroke = stroke, check = check, title = title, hit = hit })
	end

	local selected = UIUtil.panel({ Parent = shell, Position = UDim2.fromOffset(0, 352), Size = UDim2.new(1, -190, 0, 66), BackgroundColor3 = Theme.Color.PanelDark, ZIndex = 11 })
	UIUtil.label({ Parent = selected, Text = "SELECTED ARENA", Font = Theme.Font.Bold, TextSize = 10, TextColor3 = Theme.Color.TextMuted, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 14), ZIndex = 12 })
	local selectedName = UIUtil.label({ Parent = selected, Text = "SKY ISLANDS  •  FLOATING VILLAGE", Font = Theme.Font.Heading, TextSize = 16, Position = UDim2.fromOffset(14, 27), Size = UDim2.new(1, -28, 0, 22), ZIndex = 12 })
	playStatus = UIUtil.label({ Parent = selected, Text = "Vote locked when you join the queue.", TextColor3 = Theme.Color.TextDim, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, 0, 0, 11), Size = UDim2.new(0.5, -14, 0, 16), ZIndex = 12 })
	local join = UIUtil.button({ Parent = shell, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, 0, 1, 0), Size = UDim2.fromOffset(172, 52), BackgroundColor3 = Theme.Color.Play, Text = "PLAY THIS MAP", TextColor3 = Color3.fromRGB(8, 46, 52), Font = Theme.Font.Title, TextSize = 16, CornerRadius = Theme.CornerSmall, ZIndex = 12 }, function()
		Remotes.Get("RequestJoinMatch"):FireServer({ mapId = selectedMapId })
		playStatus.Text = "MAP VOTE LOCKED  •  QUEUED"
	end)

	local function updateSelectedName()
		for _, map in ipairs(MAPS) do
			if map.id == selectedMapId then
				selectedName.Text = string.upper(map.name) .. "  •  " .. string.upper(map.subtitle)
			end
		end
	end
	for _, map in ipairs(MAPS) do
		if map.id == selectedMapId then selectMap(map) end
	end
	local originalSelect = selectMap
	selectMap = function(map)
		originalSelect(map)
		updateSelectedName()
	end
	updateSelectedName()
	return root

	local hero = UIUtil.panel({ Parent = root, Size = UDim2.new(1, 0, 0, 198), BackgroundColor3 = Theme.Color.PanelDark, ClipsDescendants = true })
	UIUtil.gradient(Color3.fromRGB(19, 74, 116), Theme.Color.PanelDark, 0, hero)
	UIUtil.label({ Parent = hero, Text = "WELCOME TO THE ARENA", Font = Theme.Font.Bold, TextSize = 12, TextColor3 = Theme.Color.Accent, Position = UDim2.fromOffset(22, 18), Size = UDim2.new(1, -44, 0, 18) })
	UIUtil.label({ Parent = hero, Text = "TEAM DEATHMATCH", Font = Theme.Font.Title, TextSize = 30, Position = UDim2.fromOffset(20, 38), Size = UDim2.new(1, -250, 0, 42) })
	UIUtil.label({ Parent = hero, Text = "Blast cats off the floating islands. First team to " .. GameConfig.Match.ScoreToWin .. " wins.", TextColor3 = Theme.Color.TextDim, TextSize = 13, TextWrapped = true, Position = UDim2.fromOffset(22, 82), Size = UDim2.new(0.58, 0, 0, 36) })
	local modeBadge = UIUtil.panel({ Parent = hero, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -22, 0, 18), Size = UDim2.fromOffset(174, 68), BackgroundColor3 = Color3.fromRGB(8, 42, 76) })
	UIUtil.label({ Parent = modeBadge, Text = "LIVE MODE", Font = Theme.Font.Bold, TextSize = 11, TextColor3 = Theme.Color.Accent, Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -28, 0, 16) })
	playStatus = UIUtil.label({ Parent = modeBadge, Text = "WAITING…", Font = Theme.Font.Number, TextSize = 16, Position = UDim2.fromOffset(14, 28), Size = UDim2.new(1, -28, 0, 24) })
	local playBtn = UIUtil.button({ Parent = hero, Position = UDim2.fromOffset(22, 134), Size = UDim2.fromOffset(218, 46), BackgroundColor3 = Theme.Color.Play, Text = "", TextSize = 20, Font = Theme.Font.Title, CornerRadius = Theme.CornerSmall })
	Icons.Place("Play", playBtn, 16, Color3.new(1, 1, 1), nil, UDim2.new(0, 20, 0.5, 0))
	UIUtil.label({ Parent = playBtn, Text = "PLAY NOW", Font = Theme.Font.Title, TextSize = 20, TextColor3 = Color3.fromRGB(8, 46, 52), TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -28, 1, 0), Position = UDim2.fromOffset(20, 0) })
	playBtn.MouseButton1Click:Connect(function()
		playStatus.Text = "YOU’RE IN QUEUE"
	end)

	local lowerRow = UIUtil.make("Frame", { Parent = root, Position = UDim2.fromOffset(0, 212), Size = UDim2.new(1, 0, 0, 188), BackgroundTransparency = 1 })
	local mapCard = UIUtil.panel({ Parent = lowerRow, Size = UDim2.fromOffset(226, 188), BackgroundColor3 = Theme.Color.PanelDark, ClipsDescendants = true })
	local preview = UIUtil.make("Frame", { Parent = mapCard, Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 112), BackgroundColor3 = Color3.fromRGB(88, 168, 235), BorderSizePixel = 0, ClipsDescendants = true })
	UIUtil.corner(Theme.CornerSmall, preview)
	UIUtil.gradient(Color3.fromRGB(155, 225, 255), Color3.fromRGB(44, 110, 185), 90, preview)
	pcall(function() HeroArt.Island(preview, { width = 250, position = UDim2.fromScale(0.5, 1.16) }) end)
	UIUtil.label({ Parent = mapCard, Text = "CURRENT MAP", Font = Theme.Font.Bold, TextSize = 10, TextColor3 = Theme.Color.Accent, Position = UDim2.fromOffset(12, 130), Size = UDim2.new(1, -24, 0, 15) })
	local mapNameLabel = UIUtil.label({ Parent = mapCard, Text = "LOADING MAP…", Font = Theme.Font.Heading, TextSize = 15, Position = UDim2.fromOffset(12, 147), Size = UDim2.new(1, -24, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
	local function applyMapName()
		local arena = workspace:FindFirstChild("Arena")
		local name = arena and arena:GetAttribute("MapName")
		mapNameLabel.Text = name and string.upper(name) or "SKY ISLANDS"
	end
	task.spawn(function()
		local arena = workspace:WaitForChild("Arena", 15)
		applyMapName()
		if arena then arena:GetAttributeChangedSignal("MapName"):Connect(applyMapName) end
	end)

	local detail = UIUtil.panel({ Parent = lowerRow, Position = UDim2.fromOffset(238, 0), Size = UDim2.new(1, -238, 0, 188), BackgroundColor3 = Theme.Color.PanelDark })
	UIUtil.label({ Parent = detail, Text = "MATCH BRIEF", Font = Theme.Font.Heading, TextSize = 13, Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 18) })
	local stats = UIUtil.make("Frame", { Parent = detail, Position = UDim2.fromOffset(16, 44), Size = UDim2.new(1, -32, 0, 54), BackgroundTransparency = 1 })
	UIUtil.listLayout(stats, 10, Enum.FillDirection.Horizontal)
	local function statChip(label, value, color)
		local c = UIUtil.panel({ Parent = stats, Size = UDim2.fromOffset(106, 54), BackgroundColor3 = Theme.Color.Panel })
		UIUtil.label({ Parent = c, Text = label, Font = Theme.Font.Bold, TextSize = 10, TextColor3 = Theme.Color.TextMuted, Position = UDim2.fromOffset(10, 7), Size = UDim2.new(1, -20, 0, 14) })
		UIUtil.label({ Parent = c, Text = value, Font = Theme.Font.Number, TextSize = 18, TextColor3 = color, Position = UDim2.fromOffset(10, 22), Size = UDim2.new(1, -20, 0, 24) })
	end
	statChip("ROUND TIME", string.format("%d:%02d", math.floor(GameConfig.Match.MatchSeconds / 60), GameConfig.Match.MatchSeconds % 60), Theme.Color.Accent)
	statChip("TEAMS", "2", Theme.Color.Gem)
	statChip("TO WIN", tostring(GameConfig.Match.ScoreToWin), Theme.Color.Coin)
	UIUtil.label({ Parent = detail, Text = "POWER-UPS", Font = Theme.Font.Bold, TextSize = 10, TextColor3 = Theme.Color.TextMuted, Position = UDim2.fromOffset(16, 111), Size = UDim2.new(1, -32, 0, 14) })
	local powerRow = UIUtil.make("Frame", { Parent = detail, Position = UDim2.fromOffset(16, 130), Size = UDim2.new(1, -32, 0, 40), BackgroundTransparency = 1 })
	UIUtil.listLayout(powerRow, 8, Enum.FillDirection.Horizontal)
	local iconFor = { RapidFire = "Bolt", MegaKnockback = "Burst", Shield = "Shield", SpeedBoost = "Bolt", MultiShot = "MultiShot" }
	for _, power in ipairs(Progression.PowerUps) do
		local chip = UIUtil.panel({ Parent = powerRow, Size = UDim2.fromOffset(108, 34), BackgroundColor3 = power.Color })
		Icons.Place(iconFor[power.Id] or "Sparkle", chip, 18, Color3.new(1, 1, 1), nil, UDim2.new(0, 8, 0.5, 0))
		UIUtil.label({ Parent = chip, Text = power.Name, Font = Theme.Font.Bold, TextSize = 10, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -36, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	end

	local effectsRow = UIUtil.make("Frame", { Parent = root, Position = UDim2.fromOffset(0, 412), Size = UDim2.new(1, 0, 0, 90), BackgroundTransparency = 1 })
	local effectsCard = UIUtil.panel({ Parent = effectsRow, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.PanelDark })
	UIUtil.label({ Parent = effectsCard, Text = "YOUR LOADOUT IS READY", Font = Theme.Font.Heading, TextSize = 13, Position = UDim2.fromOffset(16, 14), Size = UDim2.new(0.5, 0, 0, 18) })
	UIUtil.label({ Parent = effectsCard, Text = "Tune your cat, blaster and cosmetics before the next drop.", TextColor3 = Theme.Color.TextDim, TextSize = 12, Position = UDim2.fromOffset(16, 38), Size = UDim2.new(0.62, 0, 0, 20) })
	local quick = UIUtil.button({ Parent = effectsCard, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -16, 0.5, 0), Size = UDim2.fromOffset(154, 38), BackgroundColor3 = Theme.Color.PanelLight, Text = "OPEN LOADOUT", TextSize = 12, Font = Theme.Font.Bold, CornerRadius = Theme.CornerSmall })
	quick.MouseButton1Click:Connect(function() switchTo("Loadout") end)

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
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	local topInset = UIUtil.topInset()

	-- Hero background scene: sky, a big floating island with a windmill/trees/
	-- waterfall, and a fully-posed cat holding a blaster (reference 1's
	-- composition, built entirely from Frames — see HeroArt.lua). A dim overlay
	-- keeps foreground text readable on top of it.
	-- Every HeroArt call is pcall-guarded: if the decorative scene ever throws,
	-- the menu must still render (nav/title/panels are what actually matter).
	local sceneLayer = UIUtil.make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 })
	local sceneOk, sceneErr = pcall(function()
		HeroArt.Sky(sceneLayer)
		HeroArt.Island(sceneLayer, { width = 980, position = UDim2.fromScale(0.5, 1.04) })
		HeroArt.HeroCat(sceneLayer, {
			size = 360,
			fur = Color3.fromRGB(255, 232, 211),
			accent = Color3.fromRGB(255, 194, 191),
			gunColor = Color3.fromRGB(140, 90, 255),
			gunAccent = Color3.fromRGB(95, 210, 255),
			position = UDim2.fromScale(0.72, 1.0),
		})
	end)
	if not sceneOk then
		warn("[PAW MAYHEM] Hero scene failed (non-fatal, skipped): " .. tostring(sceneErr))
		-- Fall back to a flat gradient so the menu still looks intentional.
		UIUtil.gradient(Color3.fromRGB(30, 40, 70), Color3.fromRGB(14, 18, 32), 90, sceneLayer)
		sceneLayer.BackgroundTransparency = 0
		sceneLayer.BackgroundColor3 = Theme.Color.Bg
	end
	local dim = UIUtil.make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 20), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 1 })

	-- Title (top left) — offset below Roblox's own topbar so nothing overlaps.
	local title = UIUtil.label({ Parent = gui, Text = "CATTO", Font = Theme.Font.Title, TextSize = 70, Position = UDim2.fromOffset(46, topInset + 22), Size = UDim2.fromOffset(360, 78), ZIndex = 10, TextStrokeTransparency = 0.45 })
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	UIUtil.label({ Parent = gui, Text = "PEW PEW!", Font = Theme.Font.Title, TextColor3 = Theme.Color.Coin, TextSize = 32, Position = UDim2.fromOffset(84, topInset + 92), Size = UDim2.fromOffset(270, 42), ZIndex = 10, TextStrokeTransparency = 0.5 })

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
	local nav = UIUtil.make("Frame", { Parent = gui, Position = UDim2.fromOffset(44, topInset + 190), Size = UDim2.fromOffset(200, 380), BackgroundTransparency = 1, ZIndex = 10 })
	UIUtil.listLayout(nav, 8)
	for i, item in ipairs(NAV) do
		local btn = UIUtil.button({
			Parent = nav, Size = UDim2.new(1, 0, 0, 42), LayoutOrder = i,
			BackgroundColor3 = Theme.Color.PanelLight,
			Text = "", TextSize = 16, Font = Theme.Font.Bold, ZIndex = 11,
		}, function()
			switchTo(item.id)
		end)
		navButtons[item.id] = btn
		local iconSlot = UIUtil.make("Frame", { Parent = btn, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(12, 21), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, ZIndex = 12 })
		Icons.Place(item.icon, iconSlot, 20, Theme.Color.Text)
		local navLabel = UIUtil.label({ Parent = btn, Name = "NavLabel", Text = item.label, Font = Theme.Font.Bold, TextSize = 16, TextColor3 = Theme.Color.Text, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -50, 1, 0), ZIndex = 12 })
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
	content = UIUtil.make("Frame", { Parent = gui, Position = UDim2.fromOffset(260, topInset + 96), Size = UDim2.new(1, -284, 1, -(topInset + 156)), BackgroundTransparency = 1, ZIndex = 10 })

	-- Build every panel defensively: a crash in one never blanks the others.
	panels = {}
	panels.Play = safeBuild("Play", content, buildPlayPanel)
	panels.Loadout = safeBuild("Loadout", content, Loadout.Build)
	panels.Shop = safeBuild("Shop", content, Shop.Build)
	panels.Customize = safeBuild("Customize", content, Customize.Build)
	panels.Leaderboard = safeBuild("Leaderboard", content, Leaderboard.Build)
	panels.Quests = safeBuild("Quests", content, Quests.Build)
	panels.Settings = safeBuild("Settings", content, Settings.Build)
	-- Start on the finished Catto landing/loading screen. The arena vote panel
	-- stays hidden until the player explicitly presses Play, so launch never
	-- feels like it skipped straight into a match setup screen.
	for _, root in pairs(panels) do
		if root then
			root.Visible = false
		end
	end
	for pid, button in pairs(navButtons) do
		local isPlay = pid == "Play"
		button.BackgroundColor3 = isPlay and Theme.Color.Play or Theme.Color.PanelLight
		local label = button:FindFirstChild("NavLabel")
		if label then
			label.TextColor3 = isPlay and Color3.fromRGB(7, 35, 58) or Theme.Color.Text
		end
	end
	currentPanel = nil

	ClientState.ProfileChanged:Connect(refreshCurrency)
	ClientState.MatchChanged:Connect(refreshPlayStatus)
	if ClientState.Profile then
		refreshCurrency()
	end

	return gui
end

return MainMenu
