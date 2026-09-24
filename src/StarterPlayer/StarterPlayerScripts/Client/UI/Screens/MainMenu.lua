--!strict
-- MainMenu: the Paw Mayhem home screen. The background is the real 3D
-- LobbyScene (mascot + floating islands) seen through the menu camera; this
-- overlay adds the logo, the left nav, coins/gems top-right and the level pill
-- bottom-left. Each nav button opens its own full screen (logo, nav and level
-- pill hide) with a BACK button that returns to the home screen.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cats = require(ReplicatedStorage.Shared.Config.Cats)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Monetize = require(script.Parent.Parent.Parent.Monetize)

local Loadout = require(script.Parent.Loadout)
local Shop = require(script.Parent.Shop)
local Customize = require(script.Parent.Customize)
local Leaderboard = require(script.Parent.Leaderboard)
local Quests = require(script.Parent.Quests)
local Settings = require(script.Parent.Settings)
local MapSelect = require(script.Parent.MapSelect)
local SeasonPass = require(script.Parent.SeasonPass)
local DailyReward = require(script.Parent.DailyReward)
local Tutorial = require(script.Parent.Tutorial)

local MainMenu = {}
local player = Players.LocalPlayer

local gui, content, panels, coinLabel, gemLabel, levelLabel, levelFill, xpLabel, avatarSlot
local panelBackdrop: Frame? = nil
local homeGroups: { GuiObject } = {}
local headerTitle: TextLabel? = nil
local relayoutFn: (() -> ())? = nil

local SCREEN_TITLES = {
	Loadout = "LOADOUT", Shop = "SHOP", Customize = "CUSTOMIZE",
	Leaderboard = "LEADERBOARD", Settings = "SETTINGS", Quests = "QUESTS", Season = "SEASON PASS",
}
local navButtons = {}
local currentPanel

local NAV = {
	{ id = "Play", label = "Play", icon = "Play" },
	{ id = "Season", label = "Season Pass", icon = "Trophy" },
	{ id = "Loadout", label = "Loadout", icon = "Gun" },
	{ id = "Shop", label = "Shop", icon = "Bag" },
	{ id = "Customize", label = "Customize", icon = "CatFace" },
	{ id = "Leaderboard", label = "Leaderboard", icon = "Podium" },
	{ id = "Settings", label = "Settings", icon = "Gear" },
}

local NAV_BG = Color3.fromRGB(16, 22, 30)
local NAV_BG_T = 0.32
local LOGO_NAVY = Color3.fromRGB(28, 40, 84)

-- Open a full screen (id) or return to the home screen (nil). Opening the
-- screen that's already open goes back home.
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
	for _, g in ipairs(homeGroups) do
		g.Visible = id == nil
	end
	if headerTitle then
		headerTitle.Text = id and (SCREEN_TITLES[id] or string.upper(id)) or ""
	end
	for pid, entry in pairs(navButtons) do
		local on = pid == id
		if pid ~= "Play" then
			entry.button.BackgroundColor3 = on and Theme.Color.Accent or NAV_BG
			entry.button.BackgroundTransparency = on and 0.1 or NAV_BG_T
		end
		entry.stroke.Transparency = on and 0.05 or entry.baseStroke
	end
	if id and panels[id] and id ~= currentPanel then
		require(script.Parent.Parent.UIJuice).Enter(panels[id])
	end
	currentPanel = id
	if relayoutFn then
		relayoutFn()
	end
end

MainMenu.Open = function(id: string?)
	switchTo(id)
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

function MainMenu.SetVisible(on: boolean)
	if gui then
		gui.Enabled = on
	end
	if not on then
		MapSelect.Close()
	end
end

-- Play: during a live match, join it straight away; otherwise open the map
-- picker for the next round.
local function onPlay()
	switchTo(nil)
	local m = ClientState.Match
	if m.phase == "Playing" then
		Remotes.Get("RequestJoinMatch"):FireServer({ mapId = m.mapId or "SkyIslands" })
	else
		MapSelect.Open()
		if not MapSelect.IsOpen() then
			Remotes.Get("RequestJoinMatch"):FireServer({ mapId = "SkyIslands" })
		end
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
		if item.id == "Play" then
			onPlay()
		else
			switchTo(item.id)
		end
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
	local navGroup, navScale = scaled({ Parent = gui, Name = "NavGroup", Size = UDim2.fromOffset(190, 390), ZIndex = 10 })
	UIUtil.listLayout(navGroup, 7)
	for i, item in ipairs(NAV) do
		navButton(navGroup, item, i)
	end

	-- Coins + gems (top right)
	local currGroup, currScale = scaled({ Parent = gui, Name = "CurrencyGroup", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(440, 40), ZIndex = 10 })
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

	-- DAILY rewards button (red dot when today's reward is waiting).
	local daily = Instance.new("TextButton")
	daily.Name = "Daily"
	daily.Text = "DAILY"
	daily.Font = Theme.Font.Title
	daily.TextSize = 18
	daily.TextColor3 = Color3.new(1, 1, 1)
	daily.Size = UDim2.fromOffset(84, 40)
	daily.LayoutOrder = -1
	daily.BackgroundColor3 = Color3.fromRGB(255, 110, 150)
	daily.BorderSizePixel = 0
	daily.ZIndex = 10
	daily.Parent = currGroup
	UIUtil.corner(UDim.new(0, 12), daily)
	UIUtil.stroke(Color3.fromRGB(255, 220, 235), 1.5, daily)
	local dot = UIUtil.make("Frame", { Parent = daily, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.fromRGB(255, 50, 60), BorderSizePixel = 0, ZIndex = 11 })
	UIUtil.corner(UDim.new(1, 0), dot)
	UIUtil.stroke(Color3.new(1, 1, 1), 2, dot)
	daily.MouseButton1Click:Connect(function()
		DailyReward.Open()
	end)
	ClientState.ProfileChanged:Connect(function()
		dot.Visible = DailyReward.CanClaim()
	end)
	dot.Visible = false

	-- Gold VIP button (hidden once owned).
	local vip = Instance.new("TextButton")
	vip.Name = "VIP"
	vip.Text = "VIP"
	vip.Font = Theme.Font.Title
	vip.TextSize = 20
	vip.TextColor3 = Color3.fromRGB(70, 40, 0)
	vip.AutoButtonColor = true
	vip.Size = UDim2.fromOffset(70, 40)
	vip.LayoutOrder = 0
	vip.BackgroundColor3 = Color3.new(1, 1, 1)
	vip.BorderSizePixel = 0
	vip.ZIndex = 10
	vip.Parent = currGroup
	UIUtil.corner(UDim.new(0, 12), vip)
	UIUtil.gradient(Color3.fromRGB(255, 226, 110), Color3.fromRGB(240, 160, 30), 90, vip)
	UIUtil.stroke(Color3.fromRGB(255, 245, 190), 1.5, vip)
	vip.MouseButton1Click:Connect(function()
		Monetize.PromptPass("VIP")
	end)
	local function refreshVip()
		vip.Visible = not Monetize.OwnsPass("VIP")
	end
	player:GetAttributeChangedSignal("VIP"):Connect(refreshVip)
	refreshVip()

	-- Toast (bottom centre) for purchase messages while in the menu.
	local toast = UIUtil.label({
		Parent = gui, Name = "Toast", Text = "", Font = Theme.Font.Title, TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.15, BackgroundColor3 = Color3.fromRGB(20, 26, 40), Visible = false, ZIndex = 30,
	})
	UIUtil.corner(UDim.new(0, 12), toast)
	local toastPad = Instance.new("UIPadding")
	toastPad.PaddingLeft = UDim.new(0, 18)
	toastPad.PaddingRight = UDim.new(0, 18)
	toastPad.Parent = toast
	local toastToken = 0
	local function showToast(text: string)
		toastToken += 1
		local token = toastToken
		toast.Text = text
		toast.Visible = true
		task.delay(2.5, function()
			if token == toastToken then
				toast.Visible = false
			end
		end)
	end
	Monetize.OnUnavailable = showToast
	Remotes.Get("Notify").OnClientEvent:Connect(function(data)
		if gui.Enabled and typeof(data) == "table" and data.text then
			showToast(tostring(data.text))
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

	-- Full-screen backdrop behind whichever screen is open, with a header bar:
	-- BACK button + screen title (currency stays top right).
	local backdrop = UIUtil.make("Frame", { Parent = gui, Name = "PanelBackdrop", BackgroundColor3 = Color3.fromRGB(10, 18, 36), BackgroundTransparency = 0.04, BorderSizePixel = 0, Visible = false, ZIndex = 9, Size = UDim2.fromScale(1, 1) }) :: Frame
	UIUtil.gradient(Color3.fromRGB(26, 44, 82), Color3.fromRGB(8, 14, 30), 90, backdrop)
	local header, headerScale = scaled({ Parent = backdrop, Name = "Header", Size = UDim2.fromOffset(520, 46), ZIndex = 12 })
	local back = UIUtil.make("TextButton", {
		Parent = header, Name = "Back", Text = "‹  BACK", Font = Theme.Font.Title, TextSize = 20,
		TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true, Size = UDim2.fromOffset(122, 44),
		BackgroundColor3 = Color3.fromRGB(26, 40, 68), BorderSizePixel = 0, ZIndex = 12,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 12), back)
	UIUtil.stroke(Color3.fromRGB(120, 150, 200), 1.5, back).Transparency = 0.4
	back.MouseButton1Click:Connect(function()
		switchTo(nil)
	end)
	headerTitle = UIUtil.label({
		Parent = header, Text = "", Font = Theme.Font.Title, TextSize = 34, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(140, 0), Size = UDim2.new(1, -140, 1, 0), ZIndex = 12,
	})
	panelBackdrop = backdrop
	homeGroups = { logoGroup, navGroup, lvlGroup }
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

		-- Screens fill the display under the header bar.
		local side = 24 * s
		local headerY = math.max(inset + 4, 12 * s)
		headerScale.Scale = s
		header.Position = UDim2.fromOffset(side, headerY)
		local top = headerY + 58 * s
		content.Position = UDim2.fromOffset(side, top)
		content.Size = UDim2.new(1, -side * 2, 1, -(top + 18 * s))
	end
	relayoutFn = relayout
	relayout()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)

	-- Build every panel defensively: a crash in one never blanks the others.
	panels = {}
	panels.Loadout = safeBuild("Loadout", content, Loadout.Build)
	panels.Shop = safeBuild("Shop", content, Shop.Build)
	panels.Customize = safeBuild("Customize", content, Customize.Build)
	panels.Leaderboard = safeBuild("Leaderboard", content, Leaderboard.Build)
	panels.Quests = safeBuild("Quests", content, Quests.Build)
	panels.Settings = safeBuild("Settings", content, Settings.Build)
	panels.Season = safeBuild("Season", content, SeasonPass.Build)
	for _, root in pairs(panels) do
		if root then
			root.Visible = false
		end
	end
	currentPanel = nil

	local ok, err = pcall(MapSelect.Build, gui)
	if not ok then
		warn("[PAW MAYHEM] Map select failed to build: " .. tostring(err))
	end

	ClientState.ProfileChanged:Connect(refreshCurrency)
	if ClientState.Profile then
		refreshCurrency()
	end

	-- First visit: the tutorial; after that, the daily reward popup (once per
	-- session) whenever one is waiting.
	local dailyOk = pcall(DailyReward.Build)
	local greeted = false
	local function greet()
		if greeted or not ClientState.Profile or not gui.Enabled then
			return
		end
		greeted = true
		local function daily()
			if dailyOk and DailyReward.CanClaim() then
				DailyReward.Open()
			end
		end
		if Tutorial.ShouldShow() then
			Tutorial.Open(daily)
		else
			daily()
		end
	end
	ClientState.ProfileChanged:Connect(greet)
	greet()

	return gui
end

return MainMenu
