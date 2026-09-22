--!strict
-- MainMenu: the Paw Mayhem home screen. The background is the real 3D
-- LobbyScene (mascot + floating islands) seen through the menu camera; this
-- overlay adds the logo, the left nav, coins/gems top-right and the level pill
-- bottom-left. Nav buttons open panels in the content area; clicking the open
-- one again returns to the clean home screen.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

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
local panelBackdrop: Frame? = nil
local navButtons = {}
local currentPanel

local NAV = {
	{ id = "Play", label = "Play", icon = "Play" },
	{ id = "Loadout", label = "Loadout", icon = "Gun" },
	{ id = "Shop", label = "Shop", icon = "Bag" },
	{ id = "Customize", label = "Customize", icon = "CatFace" },
	{ id = "Leaderboard", label = "Leaderboard", icon = "Podium" },
	{ id = "Settings", label = "Settings", icon = "Gear" },
}

local NAV_BG = Color3.fromRGB(16, 22, 30)
local NAV_BG_T = 0.32
local LOGO_NAVY = Color3.fromRGB(28, 40, 84)

-- Opening the tab that's already open closes it (back to the home screen).
local function switchTo(id: string?)
	if id ~= nil and id == currentPanel then
		id = nil
	end
	for pid, root in pairs(panels) do
		if root then
			root.Visible = (pid == id)
		end
	end
	if panelBackdrop then
		panelBackdrop.Visible = id ~= nil
	end
	for pid, entry in pairs(navButtons) do
		local on = pid == id
		if pid ~= "Play" then
			entry.button.BackgroundColor3 = on and Theme.Color.Accent or NAV_BG
			entry.button.BackgroundTransparency = on and 0.1 or NAV_BG_T
		end
		entry.stroke.Transparency = on and 0.05 or entry.baseStroke
	end
	currentPanel = id
end

local function textStroke(label: Instance, color: Color3, thickness: number): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Parent = label
	return s
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end

-- Builds a panel with a name for error reporting, wrapped in pcall so a bug in
-- one screen can never blank out the others (each nav tab still shows SOMETHING).
local function safeBuild(name: string, parent: Instance, builder: (Instance) -> Frame): Frame
	local ok, result = pcall(builder, parent)
	if ok and typeof(result) == "Instance" then
		return result :: Frame
	end
	warn(string.format("[PAW MAYHEM] UI panel '%s' failed to build: %s", name, tostring(result)))
	-- Hide any orphaned frames the failed builder may have parented before crashing.
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("GuiObject") then
			(child :: GuiObject).Visible = false
		end
	end
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
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }) :: Frame
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
end

-- ── currency chips + level pill ──────────────────────────────────────────────
local function refreshCurrency()
	local p = ClientState.Profile
	if not p then
		return
	end
	coinLabel.Text = commas(p.Coins or 0)
	gemLabel.Text = commas(p.Gems or 0)
	levelLabel.Text = "Lv. " .. tostring(p.Level or 1)
	local frac = (p.LevelNeed and p.LevelNeed > 0) and (p.LevelXP / p.LevelNeed) or 0
	levelFill.Size = UDim2.fromScale(math.clamp(frac, 0.04, 1), 1)
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
		playStatus.Text = "Match in progress — press Play to join!"
	elseif m.phase == "Results" then
		playStatus.Text = "Match over — results…"
	end
end

function MainMenu.SetVisible(on: boolean)
	if gui then
		gui.Enabled = on
	end
end

-- ── logo: chunky white PAW with cat ears + gold "MAYHEM" ────────────────────
local function buildLogo(parent: Instance): Frame
	local g = UIUtil.make("Frame", { Parent = parent, Name = "Logo", BackgroundTransparency = 1, Size = UDim2.fromOffset(340, 176), ZIndex = 10 }) :: Frame

	for _, ex in ipairs({ 92, 286 }) do
		local ear = UIUtil.make("Frame", {
			Parent = g, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(ex, 30),
			Size = UDim2.fromOffset(34, 34), Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 10,
		})
		UIUtil.corner(UDim.new(0, 7), ear)
		UIUtil.stroke(LOGO_NAVY, 4, ear)
		local inner = UIUtil.make("Frame", {
			Parent = ear, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.4, 0.4),
			Size = UDim2.fromScale(0.44, 0.44), BackgroundColor3 = Color3.fromRGB(255, 176, 192), BorderSizePixel = 0, ZIndex = 10,
		})
		UIUtil.corner(UDim.new(0, 4), inner)
	end
	-- little sparkle dashes beside the right ear
	for i, spec in ipairs({ { 318, 16, 30 }, { 330, 34, 70 }, { 304, 4, -10 } }) do
		local dash = UIUtil.make("Frame", {
			Parent = g, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(spec[1], spec[2]),
			Size = UDim2.fromOffset(4, i == 2 and 9 or 11), Rotation = spec[3], BackgroundColor3 = LOGO_NAVY, BorderSizePixel = 0, ZIndex = 10,
		})
		UIUtil.corner(UDim.new(1, 0), dash)
	end

	local function word(text: string, font: Enum.Font, size: number, x: number, y: number, rot: number, strokeColor: Color3, strokeT: number, gold: boolean)
		local shadow = UIUtil.label({
			Parent = g, Text = text, Font = font, TextSize = size, TextColor3 = strokeColor,
			Position = UDim2.fromOffset(x, y + 7), Size = UDim2.fromOffset(336, size + 10), Rotation = rot, ZIndex = 11,
		})
		textStroke(shadow, strokeColor, strokeT)
		local main = UIUtil.label({
			Parent = g, Text = text, Font = font, TextSize = size, TextColor3 = Color3.new(1, 1, 1),
			Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(336, size + 10), Rotation = rot, ZIndex = 12,
		})
		textStroke(main, strokeColor, strokeT)
		if gold then
			local grad = Instance.new("UIGradient")
			grad.Color = ColorSequence.new(Color3.fromRGB(255, 236, 120), Color3.fromRGB(255, 166, 30))
			grad.Rotation = 90
			grad.Parent = main
		end
	end
	word("PAW", Enum.Font.FredokaOne, 100, 0, 22, 0, LOGO_NAVY, 6, false)
	word("MAYHEM", Enum.Font.Bangers, 62, 52, 112, -5, Color3.fromRGB(70, 42, 26), 3.5, true)
	return g
end

-- ── left nav buttons (green Play + dark glass buttons) ───────────────────────
local function navButton(parent: Instance, item, order: number)
	local isPlay = item.id == "Play"
	local b = Instance.new("TextButton")
	b.Name = item.id
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = UDim2.new(1, 0, 0, isPlay and 50 or 44)
	b.LayoutOrder = order
	b.BorderSizePixel = 0
	b.ZIndex = 11
	b.BackgroundColor3 = isPlay and Color3.new(1, 1, 1) or NAV_BG
	b.BackgroundTransparency = isPlay and 0 or NAV_BG_T
	b.Parent = parent
	UIUtil.corner(UDim.new(0, 10), b)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = isPlay and Color3.fromRGB(198, 255, 150) or Color3.new(1, 1, 1)
	stroke.Thickness = isPlay and 2 or 1
	stroke.Transparency = isPlay and 0.15 or 0.82
	stroke.Parent = b
	if isPlay then
		UIUtil.gradient(Color3.fromRGB(132, 228, 76), Color3.fromRGB(54, 170, 50), 90, b)
		local gloss = UIUtil.make("Frame", {
			Parent = b, Position = UDim2.fromOffset(5, 3), Size = UDim2.new(1, -10, 0.42, 0),
			BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 11,
		})
		UIUtil.corner(UDim.new(0, 8), gloss)
	end

	local slot = UIUtil.make("Frame", {
		Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 30, 0.5, 0),
		Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1, ZIndex = 12,
	})
	local white = Color3.new(1, 1, 1)
	if item.icon == "Gear" then
		Icons.Place("Gear", slot, 24, white, NAV_BG)
	else
		Icons.Place(item.icon, slot, isPlay and 24 or 26, white, white)
	end

	local label = UIUtil.label({
		Parent = b, Name = "NavLabel", Text = item.label, Font = Theme.Font.Title, TextSize = isPlay and 25 or 19,
		TextColor3 = white, Position = UDim2.fromOffset(isPlay and 60 or 58, 0), Size = UDim2.new(1, -64, 1, 0), ZIndex = 12,
	})
	if isPlay then
		textStroke(label, Color3.fromRGB(36, 112, 34), 1.5)
	end

	local pop = Instance.new("UIScale")
	pop.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(pop, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(pop, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.MouseButton1Click:Connect(function()
		switchTo(item.id)
	end)
	navButtons[item.id] = { button = b, stroke = stroke, baseStroke = stroke.Transparency }
end

local function glassPill(props): Frame
	local f = UIUtil.make("Frame", props) :: Frame
	f.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
	f.BackgroundTransparency = 0.25
	f.BorderSizePixel = 0
	UIUtil.corner(UDim.new(0, 12), f)
	local s = UIUtil.stroke(Color3.new(1, 1, 1), 1, f)
	s.Transparency = 0.84
	return f
end

function MainMenu.Build()
	gui = UIUtil.make("ScreenGui", {
		Name = "PawMainMenu", Parent = player:WaitForChild("PlayerGui"),
		IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 3, Enabled = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	-- Every corner group is designed at 1x and scaled with the screen height.
	local function scaled(props): (Frame, UIScale)
		local f = UIUtil.make("Frame", props) :: Frame
		f.BackgroundTransparency = 1
		local sc = Instance.new("UIScale")
		sc.Parent = f
		return f, sc
	end

	-- Logo (top left)
	local logoGroup, logoScale = scaled({ Parent = gui, Name = "LogoGroup", Size = UDim2.fromOffset(340, 176), ZIndex = 10 })
	buildLogo(logoGroup)

	-- Left nav
	local navGroup, navScale = scaled({ Parent = gui, Name = "NavGroup", Size = UDim2.fromOffset(190, 330), ZIndex = 10 })
	UIUtil.listLayout(navGroup, 7)
	for i, item in ipairs(NAV) do
		navButton(navGroup, item, i)
	end

	-- Coins + gems (top right)
	local currGroup, currScale = scaled({ Parent = gui, Name = "CurrencyGroup", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(250, 40), ZIndex = 10 })
	UIUtil.listLayout(currGroup, 8, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Right
	local coinChip = glassPill({ Parent = currGroup, Size = UDim2.fromOffset(114, 40), LayoutOrder = 1, ZIndex = 10 })
	local coinSlot = UIUtil.make("Frame", { Parent = coinChip, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 21, 0.5, 0), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1, ZIndex = 11 })
	Icons.Place("Coin", coinSlot, 30, Color3.fromRGB(255, 196, 46))
	coinLabel = UIUtil.label({ Parent = coinChip, Text = "0", Font = Theme.Font.Title, TextSize = 21, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -48, 1, 0), ZIndex = 11 })
	local gemChip = glassPill({ Parent = currGroup, Size = UDim2.fromOffset(126, 40), LayoutOrder = 2, ZIndex = 10 })
	local gemSlot = UIUtil.make("Frame", { Parent = gemChip, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 21, 0.5, 0), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, ZIndex = 11 })
	Icons.Place("Gem", gemSlot, 30, Color3.fromRGB(206, 92, 255))
	gemLabel = UIUtil.label({ Parent = gemChip, Text = "0", Font = Theme.Font.Title, TextSize = 21, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -84, 1, 0), ZIndex = 11 })
	local plus = Instance.new("TextButton")
	plus.Text = ""
	plus.AutoButtonColor = false
	plus.AnchorPoint = Vector2.new(1, 0.5)
	plus.Position = UDim2.new(1, -4, 0.5, 0)
	plus.Size = UDim2.fromOffset(32, 32)
	plus.BackgroundColor3 = Color3.new(1, 1, 1)
	plus.BackgroundTransparency = 0.82
	plus.BorderSizePixel = 0
	plus.ZIndex = 11
	plus.Parent = gemChip
	UIUtil.corner(UDim.new(0, 9), plus)
	Icons.Place("Plus", plus, 18, Color3.new(1, 1, 1))
	plus.MouseButton1Click:Connect(function()
		if currentPanel ~= "Shop" then
			switchTo("Shop")
		end
	end)

	-- Level pill (bottom left)
	local lvlGroup, lvlScale = scaled({ Parent = gui, Name = "LevelGroup", AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(232, 58), ZIndex = 10 })
	local pill = glassPill({ Parent = lvlGroup, Size = UDim2.fromScale(1, 1), ZIndex = 10 })
	local avatarRing = UIUtil.make("Frame", { Parent = pill, Position = UDim2.fromOffset(7, 6), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.fromRGB(255, 244, 236), BorderSizePixel = 0, ZIndex = 11 })
	UIUtil.corner(UDim.new(0.5, 0), avatarRing)
	UIUtil.stroke(Color3.new(1, 1, 1), 2, avatarRing)
	avatarSlot = UIUtil.make("Frame", { Parent = avatarRing, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12 })
	Icons.Place("CatFace", avatarSlot, 40, Color3.fromRGB(255, 236, 222), Color3.fromRGB(255, 248, 242))
	levelLabel = UIUtil.label({ Parent = pill, Text = "Lv. 1", Font = Theme.Font.Title, TextSize = 19, Position = UDim2.fromOffset(62, 7), Size = UDim2.fromOffset(150, 20), ZIndex = 11 })
	local track = UIUtil.make("Frame", { Parent = pill, Position = UDim2.fromOffset(62, 33), Size = UDim2.fromOffset(158, 13), BackgroundColor3 = Color3.fromRGB(8, 12, 20), BackgroundTransparency = 0.15, BorderSizePixel = 0, ZIndex = 11 })
	UIUtil.corner(UDim.new(1, 0), track)
	levelFill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(0.04, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 12 })
	UIUtil.corner(UDim.new(1, 0), levelFill)
	UIUtil.gradient(Color3.fromRGB(110, 222, 255), Color3.fromRGB(46, 140, 255), 0, levelFill)
	xpLabel = nil

	-- Content area (opens to the right of the nav) with a dark glass backdrop.
	local backdrop = UIUtil.make("Frame", { Parent = gui, Name = "PanelBackdrop", BackgroundColor3 = Theme.Color.Bg, BackgroundTransparency = 0.08, BorderSizePixel = 0, Visible = false, ZIndex = 9 }) :: Frame
	UIUtil.corner(UDim.new(0, 18), backdrop)
	local bs = UIUtil.stroke(Theme.Color.Stroke, 1.5, backdrop)
	bs.Transparency = 0.3
	local close = Instance.new("TextButton")
	close.Name = "Close"
	close.Text = "X"
	close.Font = Theme.Font.Title
	close.TextSize = 18
	close.TextColor3 = Color3.new(1, 1, 1)
	close.AutoButtonColor = true
	close.AnchorPoint = Vector2.new(0.5, 0.5)
	close.Position = UDim2.new(1, -4, 0, 4)
	close.Size = UDim2.fromOffset(34, 34)
	close.BackgroundColor3 = Theme.Color.Danger
	close.BorderSizePixel = 0
	close.ZIndex = 20
	close.Parent = backdrop
	UIUtil.corner(UDim.new(0.5, 0), close)
	close.MouseButton1Click:Connect(function()
		switchTo(nil)
	end)
	panelBackdrop = backdrop
	content = UIUtil.make("Frame", { Parent = gui, Name = "Content", BackgroundTransparency = 1, ZIndex = 10 })

	local camera = Workspace.CurrentCamera
	local function relayout()
		local vp = camera.ViewportSize
		local s = math.clamp(vp.Y / 640, 0.72, 1.75)
		local inset = UIUtil.topInset()
		local logoY = math.max(inset - 10 * s, 4)
		logoScale.Scale = s
		logoGroup.Position = UDim2.fromOffset(22 * s, logoY)
		navScale.Scale = s
		navGroup.Position = UDim2.fromOffset(42 * s, logoY + 168 * s)
		currScale.Scale = s
		currGroup.Position = UDim2.new(1, -16 * s, 0, 12 * s)
		lvlScale.Scale = s
		lvlGroup.Position = UDim2.new(0, 22 * s, 1, -16 * s)

		local left = (42 + 190) * s + 30
		local top = math.max(inset, 58 * s) + 18
		content.Position = UDim2.fromOffset(left, top)
		content.Size = UDim2.new(1, -(left + 30), 1, -(top + 24))
		backdrop.Position = UDim2.fromOffset(left - 14, top - 14)
		backdrop.Size = UDim2.new(1, -(left + 30) + 28, 1, -(top + 24) + 28)
	end
	relayout()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)

	-- Build every panel defensively: a crash in one never blanks the others.
	panels = {}
	panels.Play = safeBuild("Play", content, buildPlayPanel)
	panels.Loadout = safeBuild("Loadout", content, Loadout.Build)
	panels.Shop = safeBuild("Shop", content, Shop.Build)
	panels.Customize = safeBuild("Customize", content, Customize.Build)
	panels.Leaderboard = safeBuild("Leaderboard", content, Leaderboard.Build)
	panels.Quests = safeBuild("Quests", content, Quests.Build)
	panels.Settings = safeBuild("Settings", content, Settings.Build)
	for _, root in pairs(panels) do
		if root then
			root.Visible = false
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
