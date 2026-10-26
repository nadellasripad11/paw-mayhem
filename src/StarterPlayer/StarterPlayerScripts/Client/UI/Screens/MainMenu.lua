--!strict
-- MainMenu: the overlay while you walk round the lobby (laid out like Rivals):
-- a dark bar of square tiles at the bottom (Loadout, Customize, Tasks, Shop,
-- Pass), a big PLAY button above it (pick a mode and vote a map; it shows
-- when you're queued) with your cat on its left and invite on its right,
-- today's tasks and a TO DUELS button middle-left, coins/gems top centre, and
-- the VIP / Leaderboard / Settings icons top right. Each tile opens its own
-- full screen with a close button. The lobby's showcases open screens too
-- (their prompts carry an OpenPanel attribute).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cats = require(ReplicatedStorage.Shared.Config.Cats)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Ranks = require(ReplicatedStorage.Shared.Config.Ranks)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local GunView = require(script.Parent.Parent.GunView)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Monetize = require(script.Parent.Parent.Parent.Monetize)
local ClientActions = require(script.Parent.Parent.Parent.ClientActions)

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
local Intro = require(script.Parent.Intro)
local PlayMenu = require(script.Parent.PlayMenu)
local DuelVote = require(script.Parent.DuelVote)
local EmotePicker = require(script.Parent.EmotePicker)

local Icon3D = require(script.Parent.Parent.Icon3D)

local MainMenu = {}
local player = Players.LocalPlayer

local gui, content, panels, coinLabel, gemLabel, levelLabel, levelFill, xpLabel, avatarSlot
local panelBackdrop: Frame? = nil
local homeGroups: { GuiObject } = {}
local headerTitle: TextLabel? = nil
local relayoutFn: (() -> ())? = nil

local SCREEN_TITLES = {
	Loadout = "LOADOUT", Shop = "SHOP", Customize = "CUSTOMIZE",
	Leaderboard = "LEADERBOARD", Settings = "SETTINGS", Quests = "DAILY TASKS", Season = "SEASON PASS",
}
local navButtons = {}
local currentPanel
local inGame = false -- a screen opened over a match or duel (only it shows)
local rangeMode = false -- in the practice range (see SetRangeMode)
local rangeHidden: { GuiObject } = {}

local NAV = {
	{ id = "Loadout", label = "Weapons", icon3d = "Gun" },
	{ id = "Customize", label = "Customize", icon3d = "CatHead" },
	{ id = "Quests", label = "Tasks", icon3d = "Clipboard" },
	{ id = "Shop", label = "Shop", icon3d = "Basket" },
	{ id = "Season", label = "Pass", icon3d = "WingShield" },
}


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
		g.Visible = id == nil and not (rangeMode and table.find(rangeHidden, g) ~= nil)
	end
	if headerTitle then
		headerTitle.Text = id and (SCREEN_TITLES[id] or string.upper(id)) or ""
	end
	for pid, entry in pairs(navButtons) do
		local on = pid == id
		entry.button.BackgroundColor3 = Theme.Color.Blue
		entry.button.BackgroundTransparency = on and 0.35 or 1
		entry.label.TextColor3 = Color3.new(1, 1, 1)
	end
	if id and panels[id] and id ~= currentPanel then
		require(script.Parent.Parent.UIJuice).Enter(panels[id])
	end
	currentPanel = id
	if relayoutFn then
		relayoutFn()
	end
	if panelBackdrop then
		-- Over a match the game stays visible behind the screen.
		panelBackdrop.BackgroundTransparency = inGame and 0.3 or 0.03
	end
	-- Closing a screen opened over a match hides the menu again.
	if id == nil and inGame then
		inGame = false
		if gui then
			gui.Enabled = false
		end
	end
end

MainMenu.Open = function(id: string?)
	switchTo(id)
end

-- A screen or the map picker is up (the mouse is freed and aiming stops).
function MainMenu.Busy(): boolean
	return currentPanel ~= nil or MapSelect.IsOpen() or PlayMenu.IsOpen() or DuelVote.IsOpen()
end

-- Open one screen over a match or duel (Loadout); again to close it.
function MainMenu.OpenInGame(id: string)
	if not gui or not panels or not panels[id] then
		return
	end
	if inGame and currentPanel == id then
		switchTo(nil)
		return
	end
	inGame = true
	gui.Enabled = true
	switchTo(id)
end

-- In the practice range only the daily tasks and TO DUELS stay up (the
-- HUD shows your blaster); everything else comes back when you leave.
function MainMenu.SetRangeMode(on: boolean)
	if on == rangeMode then
		return
	end
	rangeMode = on
	for _, g in ipairs(rangeHidden) do
		g.Visible = not on
	end
end

function MainMenu.InGameOpen(): boolean
	return inGame
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
	-- Level + trophy tier, e.g. "Lv. 5 · GOLD 640".
	levelLabel.Text = string.format("LV %d", p.Level or 1)
	local frac = (p.LevelNeed and p.LevelNeed > 0) and (p.LevelXP / p.LevelNeed) or 0
	levelFill.Size = UDim2.fromScale(math.clamp(frac, 0.04, 1), 1)
	if xpLabel then
		xpLabel.Text = string.format("%d / %d XP", p.LevelXP or 0, p.LevelNeed or 0)
	end

	if avatarSlot then
		avatarSlot:ClearAllChildren()
		local fur = Cats.FurById[p.Loadout.Cat.Fur] or Cats.FurById[Cats.Default.Fur]
		Icons.Place("CatFace", avatarSlot, 42, fur.Body, fur.Accent)
	end
end

function MainMenu.SetVisible(on: boolean)
	if on then
		inGame = false -- back in the lobby: the full menu again
	end
	if gui then
		gui.Enabled = on
	end
	if not on and panels then
		MapSelect.Close()
		switchTo(nil)
	end
end

-- Play: during a live match, join it straight away; otherwise open the map
-- picker for the next round.
-- The big shared arena match (the old PLAY): join it if it's running,
-- else open the map vote for the next one.
local function onArena()
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

-- PLAY: the mode picker (1v1 - 5v5 duels, or the arena match).
local function onPlay()
	switchTo(nil)
	PlayMenu.Open(onArena)
end

-- ── bottom bar tiles: a big 3D icon standing up out of the bar, its name
-- under it (Rivals-style) ────────────────────────────────────────────────────
local function catColors(): (Color3?, Color3?)
	local p = ClientState.Profile
	local fur = p and p.Loadout and Cats.FurById[p.Loadout.Cat.Fur]
	if fur then
		return fur.Body, fur.Accent
	end
	return nil, nil
end

local function navButton(parent: Instance, item, order: number)
	local b = UIUtil.make("TextButton", {
		Parent = parent, Name = item.id, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(84, 72), LayoutOrder = order,
		BorderSizePixel = 0, ZIndex = 11, BackgroundColor3 = Theme.Color.Surface3, BackgroundTransparency = 1,
	}) :: TextButton
	UIUtil.corner(Theme.Corner, b)
	local stroke = UIUtil.hairline(b)
	stroke.Transparency = 1
	local white = Color3.new(1, 1, 1)
	-- The icon pokes up above the bar.
	local iconSize, iconPos = UDim2.fromOffset(78, 66), UDim2.fromOffset(3, -24)
	if item.icon3d == "Gun" then
		local vf = GunView.Create(b, ClientState.Equipped("Weapon") or "PawBlaster", ClientState.Equipped("Skin"), UDim2.fromOffset(84, 56), UDim2.fromOffset(0, -16))
		vf.ZIndex = 12
		ClientState.ProfileChanged:Connect(function()
			GunView.Set(vf, ClientState.Equipped("Weapon") or "PawBlaster", ClientState.Equipped("Skin"))
		end)
	elseif item.icon3d == "CatHead" then
		local fur, accent = catColors()
		local vf = Icon3D.Create("CatHead", b, iconSize, iconPos, { fur = fur, accent = accent, fill = 0.9 })
		vf.ZIndex = 12
		ClientState.ProfileChanged:Connect(function()
			local f, a = catColors()
			Icon3D.Set(vf, "CatHead", { fur = f, accent = a, fill = 0.9 })
		end)
	else
		Icon3D.Create(item.icon3d, b, iconSize, iconPos, { fill = 0.92 }).ZIndex = 12
	end
	local label = UIUtil.label({
		Parent = b, Name = "NavLabel", Text = item.label, Font = Theme.Font.Title, TextSize = 17,
		TextColor3 = white, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2,
		TextStrokeColor3 = Color3.fromRGB(10, 12, 20),
		Position = UDim2.new(0, 0, 1, -24), Size = UDim2.new(1, 0, 0, 20), ZIndex = 13,
	})
	UIUtil.feedback(b)
	b.MouseButton1Click:Connect(function()
		switchTo(item.id)
	end)
	navButtons[item.id] = { button = b, stroke = stroke, label = label }
end

-- Tiny white glyphs for the round top-bar buttons: a podium (three bars)
-- and a gear (a ring with eight teeth).
local function smallIcon(kind: string, parent: Instance)
	local holder = UIUtil.make("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, ZIndex = 11 })
	local white = Color3.new(1, 1, 1)
	if kind == "Podium" then
		for i, h in ipairs({ 9, 16, 12 }) do
			local bar = UIUtil.make("Frame", {
				Parent = holder, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, (i - 1) * 7, 1, 0), Size = UDim2.fromOffset(6, h),
				BackgroundColor3 = white, BorderSizePixel = 0, ZIndex = 11,
			})
			UIUtil.corner(UDim.new(0, 2), bar)
		end
	else
		local ring = UIUtil.make("Frame", {
			Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(12, 12),
			BackgroundTransparency = 1, ZIndex = 12,
		})
		UIUtil.corner(UDim.new(1, 0), ring)
		UIUtil.stroke(white, 3, ring)
		for k = 0, 7 do
			local a = k * math.pi / 4
			local tooth = UIUtil.make("Frame", {
				Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, math.cos(a) * 8.5, 0.5, math.sin(a) * 8.5),
				Size = UDim2.fromOffset(4, 4), Rotation = math.deg(a), BackgroundColor3 = white, BorderSizePixel = 0, ZIndex = 11,
			})
			UIUtil.corner(UDim.new(0, 1), tooth)
		end
	end
end

-- A glossy finish on a big button: lighter at the top, a soft shine across
-- the upper half, a dark outline and an outlined label - it reads as a
-- raised, pressable button rather than a flat box.
local function gloss(b: GuiObject, color: Color3, label: TextLabel?)
	local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	UIUtil.gradient(color:Lerp(white, 0.3), color:Lerp(black, 0.06), 90, b)
	local shine = UIUtil.make("Frame", {
		Parent = b, Name = "Shine", Position = UDim2.new(0, 5, 0, 4), Size = UDim2.new(1, -10, 0.42, 0),
		BackgroundColor3 = white, BackgroundTransparency = 0.72, BorderSizePixel = 0, ZIndex = b.ZIndex,
	})
	UIUtil.corner(UDim.new(0, 10), shine)
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(0.1, 1)
	fade.Parent = shine
	UIUtil.stroke(color:Lerp(black, 0.45), 2, b)
	if label then
		label.TextStrokeColor3 = color:Lerp(black, 0.55)
		label.TextStrokeTransparency = 0.15
		label.ZIndex = b.ZIndex + 2
	end
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

	-- Bottom bar (centre): a dark strip of square tiles. Each opens its screen.
	local TILE, GAP, PAD = 84, 8, 6
	local barW = #NAV * TILE + (#NAV - 1) * GAP + PAD * 2
	local barGroup, barScale = scaled({ Parent = gui, Name = "NavBar", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(barW, 72 + PAD * 2), ZIndex = 10 })
	local bar = UIUtil.surface({ Parent = barGroup, Size = UDim2.fromScale(1, 1), ZIndex = 10, BackgroundColor3 = Theme.Color.Surface }, 1, UDim.new(0, 16))
	bar.BackgroundTransparency = 0.25
	UIUtil.gradient(Color3.fromRGB(46, 52, 74), Color3.fromRGB(14, 16, 26), 90, bar)
	local tiles = UIUtil.make("Frame", { Parent = bar, Position = UDim2.fromOffset(PAD, PAD), Size = UDim2.new(1, -PAD * 2, 1, -PAD * 2), BackgroundTransparency = 1, ZIndex = 10 })
	UIUtil.listLayout(tiles, GAP, Enum.FillDirection.Horizontal)
	for i, item in ipairs(NAV) do
		navButton(tiles, item, i)
	end

	-- PLAY (above the bar): pick a mode and vote a map for the next match, or
	-- drop straight into one that's running. Your cat on the left (opens
	-- Customize, shows your level), invite friends on the right. The line
	-- under it says where you are.
	local playGroup, playScale = scaled({ Parent = gui, Name = "PlayGroup", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(392, 90), ZIndex = 10 })
	local avatarBtn = UIUtil.make("TextButton", {
		Parent = playGroup, Name = "Avatar", Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(62, 62),
		BackgroundColor3 = Theme.Color.Surface2, BackgroundTransparency = 0.08, BorderSizePixel = 0, ZIndex = 11,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 14), avatarBtn)
	UIUtil.hairline(avatarBtn)
	UIUtil.feedback(avatarBtn)
	UIUtil.tooltip(avatarBtn, "Customize your cat")
	avatarBtn.MouseButton1Click:Connect(function()
		switchTo("Customize")
	end)
	avatarSlot = UIUtil.make("Frame", {
		Parent = avatarBtn, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -2),
		Size = UDim2.fromOffset(42, 42), BackgroundTransparency = 1, ZIndex = 12,
	})
	Icons.Place("CatFace", avatarSlot, 42, Color3.fromRGB(255, 236, 222), Color3.fromRGB(255, 248, 242))
	levelLabel = UIUtil.label({
		Parent = avatarBtn, Text = "LV 1", Font = Theme.Font.Bold, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(-6, -6), Size = UDim2.fromOffset(40, 16), BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Color.Blue, ZIndex = 14,
	})
	UIUtil.corner(UDim.new(1, 0), levelLabel)
	local track = UIUtil.make("Frame", {
		Parent = avatarBtn, Position = UDim2.new(0, 8, 1, -9), Size = UDim2.new(1, -16, 0, 4),
		BackgroundColor3 = Theme.Color.Surface3, BorderSizePixel = 0, ZIndex = 12,
	})
	UIUtil.corner(UDim.new(1, 0), track)
	levelFill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(0.04, 1), BackgroundColor3 = Theme.Color.Blue, BorderSizePixel = 0, ZIndex = 13 })
	UIUtil.corner(UDim.new(1, 0), levelFill)
	xpLabel = nil

	local play, playLabel = UIUtil.primaryButton({
		Parent = playGroup, Name = "Play", Position = UDim2.fromOffset(76, 0), Size = UDim2.fromOffset(240, 62), ZIndex = 11, TextSize = 34, CornerRadius = UDim.new(0, 14),
	}, "Play")
	gloss(play, Theme.Color.PlayGreen, playLabel)
	local playSub = UIUtil.label({
		Parent = playGroup, Text = "", Font = Theme.Font.Bold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(46, 70), Size = UDim2.fromOffset(300, 18),
		TextStrokeTransparency = 0.55, ZIndex = 11,
	})
	play.MouseButton1Click:Connect(onPlay)

	-- Searching for a duel: a pill over PLAY with the mode, the time and a
	-- cancel button.
	-- (A green box at the top of the screen, like Rivals.)
	local search = UIUtil.make("Frame", {
		Parent = gui, Name = "Search", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 58),
		Size = UDim2.fromOffset(300, 54), ZIndex = 30, Visible = false, BackgroundColor3 = Theme.Color.PlayGreen, BorderSizePixel = 0,
	}) :: Frame
	UIUtil.corner(UDim.new(0, 12), search)
	UIUtil.stroke(Color3.fromRGB(30, 110, 40), 3, search)
	UIUtil.gradient(Color3.fromRGB(110, 230, 110), Color3.fromRGB(50, 160, 60), 90, search)
	local searchText = UIUtil.label({
		Parent = search, Text = "", Font = Theme.Font.Title, TextSize = 22, Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -66, 1, 0), ZIndex = 31, TextStrokeTransparency = 0.5,
	})
	local cancel = UIUtil.make("TextButton", {
		Parent = search, Text = "X", Font = Theme.Font.Title, TextSize = 20, TextColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(38, 38),
		BackgroundColor3 = Color3.fromRGB(20, 70, 26), BackgroundTransparency = 0.2, AutoButtonColor = true, BorderSizePixel = 0, ZIndex = 31,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 10), cancel)
	cancel.MouseButton1Click:Connect(function()
		Remotes.Get("DuelQueue"):FireServer({ leave = true })
	end)
	local searchKind: string? = nil
	local searchSince = 0
	Remotes.Get("QueueState").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and type(data.kind) == "string" then
			searchKind = data.kind
			searchSince = tonumber(data.since) or Workspace:GetServerTimeNow()
		else
			searchKind = nil
		end
		search.Visible = searchKind ~= nil
	end)
	task.spawn(function()
		while gui.Parent do
			if searchKind then
				local t = math.max(0, Workspace:GetServerTimeNow() - searchSince)
				searchText.Text = string.format("%s  ·  SEARCHING  %d:%02d", string.upper(searchKind), t // 60, math.floor(t % 60))
			end
			task.wait(0.25)
		end
	end)

	-- INVITE: Roblox's friend-invite prompt (hidden where invites aren't allowed).
	local invite = UIUtil.iconButton({
		Parent = playGroup, Name = "Invite", Position = UDim2.fromOffset(330, 0), Size = UDim2.fromOffset(62, 62), ZIndex = 11, CornerRadius = UDim.new(0, 14),
	}, function(slot: Frame)
		Icons.Place("Plus", slot, 24, Color3.new(1, 1, 1))
	end, "Invite friends", function()
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	end)
	invite.Visible = false
	task.spawn(function()
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		invite.Visible = ok and can == true
	end)
	local function clock(sec: number): string
		sec = math.max(0, math.floor(sec))
		return string.format("%d:%02d", sec // 60, sec % 60)
	end
	task.spawn(function()
		while gui.Parent do
			local m = ClientState.Match
			if player:GetAttribute("Queued") == true then
				playLabel.Text = "QUEUED"
				local left = (m.timeLeft or 0) + (m.phase == "Intermission" and GameConfig.Match.CountdownSeconds or 0)
				playSub.Text = m.phase == "Countdown" and "Dropping in..." or ("Match starts in " .. clock(left) .. "  ·  click to change vote")
			else
				playLabel.Text = "Play"
				playSub.Text = m.phase == "Playing" and "Match in progress  ·  jump in"
					or m.phase == "Results" and "Next match soon"
					or ""
			end
			task.wait(0.5)
		end
	end)

	-- Top centre: coins and gems (+ opens the gem shop).
	local currGroup, currScale = scaled({ Parent = gui, Name = "CurrencyGroup", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(250, 40), ZIndex = 10 })
	UIUtil.listLayout(currGroup, 8, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local coinPill, coins = UIUtil.currencyPill({ Parent = currGroup, Size = UDim2.fromOffset(118, 40), LayoutOrder = 1, ZIndex = 10 }, "Coin", Theme.Color.Coin)
	coinLabel = coins
	local gemPill, gems, gemPlus = UIUtil.currencyPill({ Parent = currGroup, Size = UDim2.fromOffset(124, 40), LayoutOrder = 2, ZIndex = 10 }, "Gem", Theme.Color.Gem, true)
	gemLabel = gems
	-- 3D coin and gem in place of the flat icons, a bit bigger than the pill.
	for _, spec in ipairs({ { coinPill, "Coin" }, { gemPill, "Gem" } }) do
		local slot = spec[1]:FindFirstChildOfClass("Frame")
		if slot then
			slot:ClearAllChildren()
			Icon3D.Create(spec[2], slot, UDim2.fromOffset(38, 38), UDim2.fromOffset(-7, -7)).ZIndex = slot.ZIndex + 1
		end
	end
	if gemPlus then
		gemPlus.BackgroundColor3 = Color3.fromRGB(110, 210, 70)
		gemPlus.BackgroundTransparency = 0
		gloss(gemPlus, Color3.fromRGB(110, 210, 70))
		gemPlus.MouseButton1Click:Connect(function()
			if currentPanel ~= "Shop" then
				switchTo("Shop")
			end
			if Shop.Show then
				Shop.Show("Gems")
			end
		end)
	end
	-- Top right: small round buttons (VIP, Leaderboard, Settings).
	local iconGroup, iconScale = scaled({ Parent = gui, Name = "IconGroup", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(260, 40), ZIndex = 10 })
	UIUtil.listLayout(iconGroup, 8, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Right
	local function roundButton(name: string, order: number, tip: string, draw: (Frame) -> (), onClick: () -> ()): TextButton
		return UIUtil.iconButton({ Parent = iconGroup, Name = name, LayoutOrder = order, ZIndex = 10 }, draw, tip, onClick)
	end

	-- Today's free gift lives in the Shop: a red dot on the SHOP icon while
	-- it's waiting.
	local shopEntry = navButtons.Shop
	if shopEntry then
		local dot = UIUtil.make("Frame", { Parent = shopEntry.button, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(14, 14), BackgroundColor3 = Color3.fromRGB(255, 50, 60), BorderSizePixel = 0, ZIndex = 13 })
		UIUtil.corner(UDim.new(1, 0), dot)
		UIUtil.stroke(Color3.new(1, 1, 1), 2, dot)
		local function paintDot()
			dot.Visible = DailyReward.CanClaim()
		end
		ClientState.ProfileChanged:Connect(paintDot)
		paintDot()
	end

	-- VIP (gold, hidden once owned).
	local vip = roundButton("VIP", 5, "Get VIP", function(slot: Frame)
		UIUtil.label({
			Parent = slot, Text = "VIP", Font = Theme.Font.Title, TextSize = 15, TextColor3 = Color3.fromRGB(70, 44, 0),
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 12,
		})
	end, function()
		Monetize.PromptPass("VIP")
	end)
	vip.BackgroundColor3 = Theme.Color.Coin
	vip.BackgroundTransparency = 0
	local function refreshVip()
		vip.Visible = not Monetize.OwnsPass("VIP")
	end
	player:GetAttributeChangedSignal("VIP"):Connect(refreshVip)
	refreshVip()

	-- Emotes: a picker of the ones you own (easy on phones too).
	pcall(EmotePicker.Build)
	roundButton("EmotesIcon", 10, "Emotes", function(slot: Frame)
		Icons.Place("Smiley", slot, 22, Color3.new(1, 1, 1))
	end, function()
		EmotePicker.Toggle()
	end)

	-- Leaderboard + Settings at the far right.
	for i, spec in ipairs({ { "Leaderboard", "Podium", "Leaderboard" }, { "Settings", "Gear", "Settings" } }) do
		roundButton(spec[1] .. "Icon", 10 + i, spec[3], function(slot: Frame)
			smallIcon(spec[2], slot)
		end, function()
			switchTo(spec[1])
		end)
	end

	-- Toast (top centre) for notices and purchase messages in the lobby.
	local toast = UIUtil.label({
		Parent = gui, Name = "Toast", Text = "", Font = Theme.Font.Bold, TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 64), Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0.04, BackgroundColor3 = Theme.Color.Surface, Visible = false, ZIndex = 30,
	})
	UIUtil.corner(Theme.Corner, toast)
	UIUtil.hairline(toast)
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

	-- Middle left: today's tasks (progress, coin reward, CLAIM when done) and
	-- TO DUELS, which takes you straight to the duel pads.
	local TASKS_W, ROW_H, HEAD_H = 290, 46, 50
	local tasksGroup, tasksScale = scaled({ Parent = gui, Name = "TasksGroup", AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(TASKS_W, 300), ZIndex = 10 })
	local tasksCard = UIUtil.surface({ Parent = tasksGroup, Size = UDim2.new(1, 0, 0, HEAD_H), ZIndex = 10, BackgroundColor3 = Theme.Color.Surface }, 1, UDim.new(0, 14))
	tasksCard.BackgroundTransparency = 0.3
	UIUtil.gradient(Color3.fromRGB(34, 40, 60), Color3.fromRGB(12, 14, 22), 90, tasksCard)
	-- Open on every screen (tap the header to fold it).
	local phone = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
	local collapsed = false
	Icon3D.Create("Clipboard", tasksCard, UDim2.fromOffset(46, 52), UDim2.fromOffset(4, -6)).ZIndex = 12
	local tasksTitle = UIUtil.label({
		Parent = tasksCard, Text = "Daily Tasks", Font = Theme.Font.Title, TextSize = 24, Position = UDim2.fromOffset(52, 0),
		Size = UDim2.new(0.6, 0, 0, HEAD_H), ZIndex = 11, TextStrokeTransparency = 0.5,
	})
	local fold = UIUtil.make("TextButton", {
		Parent = tasksCard, Name = "Fold", Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, HEAD_H), ZIndex = 13,
	}) :: TextButton
	local resetLabel = UIUtil.label({
		Parent = tasksCard, Text = "", Font = Theme.Font.Bold, TextSize = 11, TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -12, 0, HEAD_H), ZIndex = 11,
	})
	-- Tasks reset at midnight UTC.
	task.spawn(function()
		while gui.Parent do
			local left = 86400 - os.time() % 86400
			resetLabel.Text = string.format("%dh %02dm", left // 3600, (left % 3600) // 60)
			task.wait(30)
		end
	end)
	-- NEW TASKS (R$): swap the ones you haven't finished.
	local reroll = UIUtil.secondaryButton({
		Parent = tasksGroup, Name = "Reroll", Size = UDim2.fromOffset(TASKS_W, 30), ZIndex = 11, TextSize = 13, Visible = false,
	}, "NEW TASKS   R$ " .. tostring(Monetization.Products.RerollTasks.Price), function()
		Monetize.PromptProduct("RerollTasks")
	end)
	local duelsHolder = UIUtil.make("Frame", { Parent = tasksGroup, Size = UDim2.fromOffset(TASKS_W, 48), BackgroundTransparency = 1, ZIndex = 10 })
	local DUELS_W = 210
	local toDuels, toDuelsLabel = UIUtil.primaryButton({
		Parent = duelsHolder, Name = "ToDuels", Position = UDim2.fromOffset(18, 0), Size = UDim2.fromOffset(DUELS_W, 44), ZIndex = 11, TextSize = 22, CornerRadius = UDim.new(0, 12),
	}, "To Duels", function()
		Remotes.Get("LobbyTravel"):FireServer("Duels")
	end, Theme.Color.Blue, Color3.fromRGB(38, 100, 186))
	gloss(toDuels, Theme.Color.Blue, toDuelsLabel)
	for _, x in ipairs({ 0.1, 0.9 }) do
		local spark = UIUtil.make("Frame", {
			Parent = toDuels, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.5), Size = UDim2.fromOffset(22, 22),
			BackgroundTransparency = 1, ZIndex = 14,
		})
		Icons.Place("Sparkle", spark, 22, Color3.new(1, 1, 1))
	end

	-- The TASKS tile shows how many are ready to claim.
	local questBadge: TextLabel? = nil
	local questEntry = navButtons.Quests
	if questEntry then
		local badge = UIUtil.label({
			Parent = questEntry.button, Text = "", Font = Theme.Font.Bold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(20, 20),
			BackgroundTransparency = 0, BackgroundColor3 = Theme.Color.Red, Visible = false, ZIndex = 14,
		})
		UIUtil.corner(UDim.new(1, 0), badge)
		UIUtil.stroke(Color3.new(1, 1, 1), 2, badge)
		questBadge = badge
	end

	local claiming = false
	local rebuildTasks: () -> ()
	fold.MouseButton1Click:Connect(function()
		collapsed = not collapsed
		rebuildTasks()
	end)
	-- A white icon for each kind of task.
	local function taskIcon(text: string): string
		local t = string.lower(text)
		if string.find(t, "elim") or string.find(t, "knock") then
			return "Burst"
		elseif string.find(t, "win") then
			return "Trophy"
		elseif string.find(t, "launch") or string.find(t, "off the map") then
			return "Fall"
		elseif string.find(t, "power") then
			return "Bolt"
		elseif string.find(t, "play") or string.find(t, "match") or string.find(t, "duel") then
			return "Play"
		end
		return "Check"
	end
	local function taskRow(q: any, y: number)
		local row = UIUtil.make("Frame", {
			Parent = tasksCard, Name = "TaskRow", Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, ROW_H - 4),
			BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 11,
		})
		local progress, target = tonumber(q.Progress) or 0, math.max(tonumber(q.Target) or 1, 1)
		local done = progress >= target
		local dim = q.Claimed and Theme.Color.TextDim or Color3.new(1, 1, 1)
		local icon = UIUtil.make("Frame", { Parent = row, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, -3), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, ZIndex = 12 })
		Icons.Place(taskIcon(tostring(q.Text)), icon, 24, dim)
		UIUtil.label({
			Parent = row, Text = tostring(q.Text), Font = Theme.Font.Title, TextSize = 16, Position = UDim2.fromOffset(34, 2),
			Size = UDim2.new(1, -150, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 12,
			TextColor3 = dim, TextStrokeTransparency = 0.6,
		})
		-- a thin progress line under the name
		local bar = UIUtil.make("Frame", {
			Parent = row, Position = UDim2.fromOffset(34, 30), Size = UDim2.new(1, -150, 0, 4),
			BackgroundColor3 = Color3.fromRGB(255, 255, 255), BackgroundTransparency = 0.85, BorderSizePixel = 0, ZIndex = 12,
		})
		UIUtil.corner(UDim.new(1, 0), bar)
		local fill = UIUtil.make("Frame", {
			Parent = bar, Size = UDim2.fromScale(math.clamp(progress / target, 0, 1), 1),
			BackgroundColor3 = done and Theme.Color.PlayGreen or Theme.Color.Blue, BorderSizePixel = 0, ZIndex = 13,
		})
		UIUtil.corner(UDim.new(1, 0), fill)
		UIUtil.label({
			Parent = row, Text = string.format("%d / %d", math.min(progress, target), target), Font = Theme.Font.Title, TextSize = 16,
			TextColor3 = dim, TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.6,
			Position = UDim2.new(1, -140, 0, 6), Size = UDim2.fromOffset(56, 22), ZIndex = 12,
		})
		-- Right side: the reward, a CLAIM button once done, a tick once claimed.
		local right = UIUtil.make("Frame", {
			Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(74, 32),
			BackgroundTransparency = 1, ZIndex = 12,
		})
		if q.Claimed then
			Icons.Place("Check", right, 20, Theme.Color.PlayGreen)
		elseif done then
			local claim = UIUtil.make("TextButton", {
				Parent = right, Text = "CLAIM", Font = Theme.Font.Title, TextSize = 15, TextColor3 = Color3.new(1, 1, 1),
				Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.PlayGreen, AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 13,
			}) :: TextButton
			UIUtil.corner(Theme.CornerSmall, claim)
			UIUtil.feedback(claim, 1.06)
			claim.MouseButton1Click:Connect(function()
				if claiming then
					return
				end
				claiming = true
				local res = ClientActions.ClaimQuest(q.Id)
				claiming = false
				if type(res) == "table" and res.ok then
					showToast(string.format("+%d coins", tonumber(res.coins) or tonumber(q.Coins) or 0))
				end
				rebuildTasks()
			end)
		else
			local reward = UIUtil.make("Frame", { Parent = right, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12 })
			local l = UIUtil.listLayout(reward, 4, Enum.FillDirection.Horizontal)
			l.HorizontalAlignment = Enum.HorizontalAlignment.Right
			l.VerticalAlignment = Enum.VerticalAlignment.Center
			local coin = UIUtil.make("Frame", { Parent = reward, Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1, LayoutOrder = 1, ZIndex = 12 })
			Icon3D.Create("Coin", coin, UDim2.fromOffset(26, 26), UDim2.fromOffset(-1, -1)).ZIndex = 13
			UIUtil.label({
				Parent = reward, Text = tostring(q.Coins or 0), Font = Theme.Font.Title, TextSize = 15, TextColor3 = Theme.Color.Coin,
				AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), LayoutOrder = 2, ZIndex = 12,
			})
		end
	end
	rebuildTasks = function()
		for _, c in ipairs(tasksCard:GetChildren()) do
			if c.Name == "TaskRow" then
				c:Destroy()
			end
		end
		local p = ClientState.Profile
		local list = (p and p.Quests and p.Quests.Active) or {}
		local ready, open, finished = 0, 0, 0
		for i, q in ipairs(list) do
			if not collapsed then
				taskRow(q, HEAD_H + (i - 1) * ROW_H)
			end
			local done = (tonumber(q.Progress) or 0) >= (tonumber(q.Target) or 1)
			if done then
				finished += 1
			end
			if not q.Claimed and done then
				ready += 1
			elseif not done then
				open += 1
			end
		end
		tasksTitle.Text = collapsed and string.format("Daily Tasks  %d/%d", finished, #list) or "Daily Tasks"
		local h = HEAD_H + (collapsed and 0 or #list * ROW_H) + 4
		tasksCard.Size = UDim2.new(1, 0, 0, h)
		-- (NEW TASKS only while there's something left to swap.)
		reroll.Visible = open > 0 and not collapsed
		local y = h + 8
		if reroll.Visible then
			reroll.Position = UDim2.fromOffset(0, y)
			y += 38
		else
			y += 4
		end
		duelsHolder.Position = UDim2.fromOffset(0, y)
		tasksGroup.Size = UDim2.fromOffset(TASKS_W, y + 48)
		if questBadge then
			questBadge.Text = tostring(ready)
			questBadge.Visible = ready > 0
		end
	end
	ClientState.ProfileChanged:Connect(rebuildTasks)
	rebuildTasks()

	-- Your win streak (3+) just ended: offer to buy it back for a few minutes
	-- (shows once you're back in the lobby).
	local saver = UIUtil.surface({
		Parent = gui, Name = "StreakSaver", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 64),
		Size = UDim2.fromOffset(360, 104), ZIndex = 35, Visible = false, BackgroundColor3 = Theme.Color.Surface,
	}, 1, UDim.new(0, 14))
	UIUtil.stroke(Theme.Color.Coin, 2, saver)
	local saverTitle = UIUtil.label({
		Parent = saver, Text = "", Font = Theme.Font.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 24), ZIndex = 36,
	})
	UIUtil.primaryButton({
		Parent = saver, Name = "SaveStreak", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -20, 0, 46),
		Size = UDim2.fromOffset(240, 42), ZIndex = 37, TextSize = 18, CornerRadius = UDim.new(0, 10),
	}, "SAVE IT   R$ " .. tostring(Monetization.Products.StreakSaver.Price), function()
		Monetize.PromptProduct("StreakSaver")
		saver.Visible = false
	end, Theme.Color.Coin, Color3.fromRGB(196, 150, 30))
	UIUtil.iconButton({
		Parent = saver, Name = "Dismiss", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 48),
		Size = UDim2.fromOffset(38, 38), ZIndex = 37,
	}, function(slot: Frame)
		UIUtil.label({ Parent = slot, Text = "X", Font = Theme.Font.Title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 38 })
	end, nil, function()
		saver.Visible = false
	end)
	local saverToken = 0
	Remotes.Get("StreakLost").OnClientEvent:Connect(function(data)
		local n = typeof(data) == "table" and tonumber(data.streak) or 0
		if not n or n <= 0 then
			return
		end
		saverToken += 1
		local token = saverToken
		saverTitle.Text = string.format("Your %d-win streak ended!", n)
		saver.Visible = true
		-- The server keeps it for 5 minutes; the offer goes a bit before that.
		task.delay(Monetization.StreakSaver.Window - 30, function()
			if token == saverToken then
				saver.Visible = false
			end
		end)
	end)

	-- Full-screen backdrop behind whichever screen is open, with a header bar:
	-- BACK button + screen title (currency stays top right).
	local backdrop = UIUtil.make("Frame", { Parent = gui, Name = "PanelBackdrop", BackgroundColor3 = Theme.Color.Bg, BackgroundTransparency = 0.03, BorderSizePixel = 0, Visible = false, ZIndex = 9, Size = UDim2.fromScale(1, 1) }) :: Frame
	local header, headerScale = scaled({ Parent = backdrop, Name = "Header", Size = UDim2.fromOffset(520, 44), ZIndex = 12 })
	local close = UIUtil.iconButton({ Parent = header, Name = "Close", Size = UDim2.fromOffset(44, 44), ZIndex = 12 }, function(slot: Frame)
		UIUtil.label({
			Parent = slot, Text = "X", Font = Theme.Font.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1), ZIndex = 13,
		})
	end, nil, function()
		switchTo(nil)
	end)
	close.Name = "Back"
	headerTitle = UIUtil.label({
		Parent = header, Text = "", Font = Theme.Font.Title, TextSize = 30, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(60, 0), Size = UDim2.new(1, -60, 1, 0), ZIndex = 12,
	})
	panelBackdrop = backdrop
	homeGroups = { barGroup, playGroup, tasksGroup }
	rangeHidden = { barGroup, playGroup, currGroup, iconGroup }
	content = UIUtil.make("Frame", { Parent = gui, Name = "Content", BackgroundTransparency = 1, ZIndex = 10 })

	local camera = Workspace.CurrentCamera
	local function relayout()
		local vp = camera.ViewportSize
		-- Phones get a bigger minimum so every button stays easy to tap.
		local touch = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
		local s = math.clamp(vp.Y / 640, touch and 0.62 or 0.72, 1.75)
		local inset = UIUtil.topInset()
		-- Phones: the move buttons take the bottom-right corner, so the bar and
		-- PLAY centre in the space left of them.
		local cx = touch and math.max((vp.X - 210) / 2, barW * s / 2 + 8) or vp.X / 2
		barScale.Scale = s
		barGroup.Position = UDim2.new(0, cx, 1, -12 * s)
		playScale.Scale = s
		playGroup.Position = UDim2.new(0, cx, 1, -(12 + 80 + 12) * s)
		currScale.Scale = s
		currGroup.Position = UDim2.new(0.5, 0, 0, 12 * s)
		iconScale.Scale = s
		iconGroup.Position = UDim2.new(1, -16 * s, 0, 12 * s)
		tasksScale.Scale = s
		tasksGroup.Position = UDim2.new(0, 16 * s, 0.5, 0)

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

	pcall(PlayMenu.Build)
	pcall(DuelVote.Build)
	local ok, err = pcall(MapSelect.Build, gui)
	if not ok then
		warn("[PAW MAYHEM] Map select failed to build: " .. tostring(err))
	end
	-- Every screen (and the map picker) onto the clean look.
	UIUtil.restyle(gui)

	ClientState.ProfileChanged:Connect(refreshCurrency)
	if ClientState.Profile then
		refreshCurrency()
	end

	-- Lobby showcases: the armory opens Loadout, the boutique the Shop.
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local id = prompt:GetAttribute("OpenPanel")
		if typeof(id) == "string" and panels[id] and gui.Enabled and currentPanel ~= id then
			switchTo(id)
		end
	end)

	-- New players are offered the tutorial (it goes away by itself if ignored).
	-- The daily gift is claimed in the Shop; its 7-day calendar is still here
	-- for the Shop to open.
	pcall(DailyReward.Build)
	-- Settings -> Intro -> REPLAY runs the intro again (not while a match is on).
	Settings.OnReplayIntro = function()
		if player:GetAttribute("Context") ~= "Lobby" then
			showToast("You can replay the intro from the lobby.")
			return
		end
		switchTo(nil)
		gui.Enabled = false
		Intro.Run(function()
			gui.Enabled = player:GetAttribute("Context") == "Lobby"
		end)
	end
	local greeted = false
	local function greet()
		if greeted or not ClientState.Profile or not gui.Enabled then
			return
		end
		greeted = true
		-- Point new players at PLAY.
		local function pointAtPlay()
			local play = gui:FindFirstChild("Play", true)
			if play and play:IsA("GuiObject") then
				local arrow = UIUtil.label({
					Parent = play, Name = "StartHere", Text = "START HERE  ▼", Font = Theme.Font.Bold, TextSize = 13,
					TextColor3 = Color3.fromRGB(40, 30, 6), TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8),
					Size = UDim2.fromOffset(120, 26), ZIndex = 20, BackgroundTransparency = 0, BackgroundColor3 = Theme.Color.Coin,
				})
				UIUtil.corner(UDim.new(1, 0), arrow)
				TweenService:Create(arrow, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0.5, 0, 0, -18) }):Play()
				task.spawn(function()
					while arrow.Parent and not player:GetAttribute("Queued") and player:GetAttribute("Context") ~= "Match" do
						task.wait(0.5)
					end
					arrow:Destroy()
				end)
			end
		end
		-- New players get asked whether they want the tutorial (a short
		-- cinematic, then a hands-on lesson with Mochi). Ignore it for 7 seconds
		-- and it slides away (and asks again next time); NO THANKS stops asking.
		if Tutorial.ShouldShow() then
			local ask = UIUtil.make("Frame", {
				Parent = gui, Name = "TutorialAsk", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 70),
				Size = UDim2.fromOffset(380, 132), BackgroundColor3 = Color3.fromRGB(18, 26, 48), BackgroundTransparency = 0.05, BorderSizePixel = 0, ZIndex = 40,
			}) :: Frame
			UIUtil.corner(UDim.new(0, 16), ask)
			UIUtil.stroke(Color3.fromRGB(90, 200, 255), 2, ask)
			UIUtil.label({
				Parent = ask, Text = "NEW HERE?", Font = Theme.Font.Title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 28), ZIndex = 41,
			})
			UIUtil.label({
				Parent = ask, Text = "Play the 1-minute tutorial with Mochi?", Font = Theme.Font.Bold, TextSize = 15, TextColor3 = Theme.Color.TextDim,
				TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 20), ZIndex = 41,
			})
			local timer = UIUtil.make("Frame", {
				Parent = ask, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -8), Size = UDim2.new(1, -32, 0, 4),
				BackgroundColor3 = Color3.fromRGB(90, 200, 255), BorderSizePixel = 0, ZIndex = 41,
			}) :: Frame
			UIUtil.corner(UDim.new(1, 0), timer)
			local answered = false
			local function close()
				answered = true
				TweenService:Create(ask, TweenInfo.new(0.3), { Position = UDim2.new(0.5, 0, 0, -160) }):Play()
				task.delay(0.35, function()
					ask:Destroy()
				end)
			end
			local function choice(text: string, x: number, color: Color3, onClick: () -> ())
				local b = UIUtil.make("TextButton", {
					Parent = ask, Text = text, Font = Theme.Font.Title, TextSize = 17, TextColor3 = Color3.new(1, 1, 1),
					AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, x, 0, 70), Size = UDim2.fromOffset(160, 40),
					BackgroundColor3 = color, BorderSizePixel = 0, AutoButtonColor = true, ZIndex = 41,
				}) :: TextButton
				UIUtil.corner(UDim.new(0, 12), b)
				b.MouseButton1Click:Connect(function()
					if not answered then
						close()
						onClick()
					end
				end)
			end
			choice("PLAY TUTORIAL", -86, Color3.fromRGB(70, 190, 90), function()
				switchTo(nil)
				gui.Enabled = false
				Intro.Run(function()
					gui.Enabled = player:GetAttribute("Context") == "Lobby"
					pointAtPlay()
				end)
			end)
			choice("NO THANKS", 86, Color3.fromRGB(60, 72, 104), function()
				Remotes.Get("TutorialDone"):FireServer()
				pointAtPlay()
			end)
			TweenService:Create(timer, TweenInfo.new(7, Enum.EasingStyle.Linear), { Size = UDim2.new(0, 0, 0, 4) }):Play()
			task.delay(7, function()
				if not answered then
					close()
					pointAtPlay()
				end
			end)
		end
		-- Weekend event banner (Sat/Sun UTC): low gravity + bonus coins.
		local wday = os.date("!*t").wday
		if wday == 1 or wday == 7 then
			task.delay(2, function()
				showToast("WEEKEND MAYHEM: low gravity + 25% more coins!")
			end)
		end
	end
	ClientState.ProfileChanged:Connect(greet)
	greet()

	return gui
end

return MainMenu
