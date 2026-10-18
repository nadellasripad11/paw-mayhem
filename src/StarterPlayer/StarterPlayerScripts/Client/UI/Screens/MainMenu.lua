--!strict
-- MainMenu: the overlay while you walk round the lobby (like Rivals): square
-- icon buttons on the left (Shop, Customize, Loadout, Season Pass), a big PLAY
-- button at the bottom (pick a mode and vote a map; it shows when you're
-- queued), your level top-left, and coins/gems plus the Leaderboard and
-- Settings icons top-right. Each icon opens its own full screen with a BACK
-- button. The lobby's showcases open screens too (their prompts carry an
-- OpenPanel attribute).

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local SocialService = game:GetService("SocialService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cats = require(ReplicatedStorage.Shared.Config.Cats)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Ranks = require(ReplicatedStorage.Shared.Config.Ranks)
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
local Intro = require(script.Parent.Intro)

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
local inGame = false -- a screen opened over a match or duel (only it shows)

local NAV = {
	{ id = "Shop", label = "SHOP", icon = "Bag" },
	{ id = "Customize", label = "CUSTOMIZE", icon = "CatFace" },
	{ id = "Loadout", label = "LOADOUT", icon = "Gun" },
	{ id = "Season", label = "SEASON", icon = "Trophy" },
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
		g.Visible = id == nil
	end
	if headerTitle then
		headerTitle.Text = id and (SCREEN_TITLES[id] or string.upper(id)) or ""
	end
	for pid, entry in pairs(navButtons) do
		local on = pid == id
		entry.button.BackgroundColor3 = on and Theme.Color.Blue or Theme.Color.Surface2
		entry.stroke.Transparency = on and 1 or Theme.LineAlpha
		entry.label.TextColor3 = on and Color3.new(1, 1, 1) or Theme.Color.TextDim
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
	return currentPanel ~= nil or MapSelect.IsOpen()
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
	local trophies = p.Stats and tonumber(p.Stats.Trophies) or 0
	local tier = Ranks.For(trophies)
	levelLabel.RichText = true
	levelLabel.Text = string.format('LEVEL %d   ·   <font color="#%s">%s  %d</font>', p.Level or 1, tier.Color:ToHex(), string.upper(tier.Name), trophies)
	local frac = (p.LevelNeed and p.LevelNeed > 0) and (p.LevelXP / p.LevelNeed) or 0
	levelFill.Size = UDim2.fromScale(math.clamp(frac, 0.04, 1), 1)
	if xpLabel then
		xpLabel.Text = string.format("%d / %d XP", p.LevelXP or 0, p.LevelNeed or 0)
	end

	if avatarSlot then
		avatarSlot:ClearAllChildren()
		local fur = Cats.FurById[p.Loadout.Cat.Fur] or Cats.FurById[Cats.Default.Fur]
		Icons.Place("CatFace", avatarSlot, 34, fur.Body, fur.Accent)
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

-- ── left icon buttons: flat square tiles, icon over a small label ────────────
local function navButton(parent: Instance, item, order: number)
	local b = UIUtil.make("TextButton", {
		Parent = parent, Name = item.id, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(66, 66), LayoutOrder = order,
		BorderSizePixel = 0, ZIndex = 11, BackgroundColor3 = Theme.Color.Surface2, BackgroundTransparency = 0.08,
	}) :: TextButton
	UIUtil.corner(Theme.Corner, b)
	local stroke = UIUtil.hairline(b)
	local slot = UIUtil.make("Frame", {
		Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1, ZIndex = 12,
	})
	local white = Color3.new(1, 1, 1)
	Icons.Place(item.icon, slot, 28, white, white)
	local label = UIUtil.label({
		Parent = b, Name = "NavLabel", Text = item.label, Font = Theme.Font.Bold, TextSize = 11,
		TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 1, -19), Size = UDim2.new(1, 0, 0, 14), ZIndex = 12,
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

	-- Icon buttons down the left side
	local navGroup, navScale = scaled({ Parent = gui, Name = "NavGroup", AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(66, 4 * 66 + 3 * 8), ZIndex = 10 })
	UIUtil.listLayout(navGroup, 8)
	for i, item in ipairs(NAV) do
		navButton(navGroup, item, i)
	end

	-- PLAY (bottom centre): pick a mode and vote a map for the next match, or
	-- drop straight into one that's running. The line under it says where you are.
	local playGroup, playScale = scaled({ Parent = gui, Name = "PlayGroup", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(240, 86), ZIndex = 10 })
	local play, playLabel = UIUtil.primaryButton({
		Parent = playGroup, Name = "Play", Size = UDim2.fromOffset(240, 58), ZIndex = 11, TextSize = 30, CornerRadius = UDim.new(0, 14),
	}, "PLAY")
	local playSub = UIUtil.label({
		Parent = playGroup, Text = "", Font = Theme.Font.Bold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 18),
		TextStrokeTransparency = 0.55, ZIndex = 11,
	})
	play.MouseButton1Click:Connect(onPlay)
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
				playLabel.Text = "PLAY"
				playSub.Text = m.phase == "Playing" and "Match in progress  ·  jump in"
					or m.phase == "Results" and "Next match soon"
					or ""
			end
			task.wait(0.5)
		end
	end)

	-- Top right: coins, gems (+ opens the gem shop), then round icon buttons.
	local currGroup, currScale = scaled({ Parent = gui, Name = "CurrencyGroup", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(600, 40), ZIndex = 10 })
	UIUtil.listLayout(currGroup, 8, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Right
	local _, coins = UIUtil.currencyPill({ Parent = currGroup, Size = UDim2.fromOffset(118, 40), LayoutOrder = 1, ZIndex = 10 }, "Coin", Theme.Color.Coin)
	coinLabel = coins
	local _, gems, gemPlus = UIUtil.currencyPill({ Parent = currGroup, Size = UDim2.fromOffset(124, 40), LayoutOrder = 2, ZIndex = 10 }, "Gem", Theme.Color.Gem, true)
	gemLabel = gems
	if gemPlus then
		gemPlus.MouseButton1Click:Connect(function()
			if currentPanel ~= "Shop" then
				switchTo("Shop")
			end
			if Shop.Show then
				Shop.Show("Gems")
			end
		end)
	end
	local function roundButton(name: string, order: number, tip: string, draw: (Frame) -> (), onClick: () -> ()): TextButton
		return UIUtil.iconButton({ Parent = currGroup, Name = name, LayoutOrder = order, ZIndex = 10 }, draw, tip, onClick)
	end
	local function glyph(icon: string, color: Color3): (Frame) -> ()
		return function(slot: Frame)
			Icons.Place(icon, slot, 20, color, color)
		end
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

	-- INVITE: Roblox's friend-invite prompt (hidden where invites aren't allowed).
	local invite = roundButton("Invite", 4, "Invite friends", glyph("Wave", Color3.new(1, 1, 1)), function()
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
		Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 16), Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X,
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

	-- Player card (top left): your cat, your name, level + rank, XP bar.
	local lvlGroup, lvlScale = scaled({ Parent = gui, Name = "LevelGroup", Size = UDim2.fromOffset(236, 56), ZIndex = 10 })
	local card = UIUtil.surface({ Parent = lvlGroup, Size = UDim2.fromScale(1, 1), ZIndex = 10, BackgroundTransparency = 0.1 }, 1)
	local avatarRing = UIUtil.make("Frame", { Parent = card, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Color3.fromRGB(255, 244, 236), BorderSizePixel = 0, ZIndex = 11 })
	UIUtil.corner(UDim.new(1, 0), avatarRing)
	avatarSlot = UIUtil.make("Frame", { Parent = avatarRing, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12 })
	Icons.Place("CatFace", avatarSlot, 34, Color3.fromRGB(255, 236, 222), Color3.fromRGB(255, 248, 242))
	UIUtil.label({
		Parent = card, Text = player.DisplayName, Font = Theme.Font.Bold, TextSize = 15, Position = UDim2.fromOffset(58, 7),
		Size = UDim2.new(1, -66, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 11,
	})
	levelLabel = UIUtil.label({ Parent = card, Text = "Lv. 1", Font = Theme.Font.Bold, TextSize = 12, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(58, 25), Size = UDim2.new(1, -66, 0, 14), ZIndex = 11 })
	local track = UIUtil.make("Frame", { Parent = card, Position = UDim2.fromOffset(58, 42), Size = UDim2.new(1, -70, 0, 5), BackgroundColor3 = Theme.Color.Surface3, BorderSizePixel = 0, ZIndex = 11 })
	UIUtil.corner(UDim.new(1, 0), track)
	levelFill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(0.04, 1), BackgroundColor3 = Theme.Color.Blue, BorderSizePixel = 0, ZIndex = 12 })
	UIUtil.corner(UDim.new(1, 0), levelFill)
	xpLabel = nil

	-- Full-screen backdrop behind whichever screen is open, with a header bar:
	-- BACK button + screen title (currency stays top right).
	local backdrop = UIUtil.make("Frame", { Parent = gui, Name = "PanelBackdrop", BackgroundColor3 = Theme.Color.Bg, BackgroundTransparency = 0.03, BorderSizePixel = 0, Visible = false, ZIndex = 9, Size = UDim2.fromScale(1, 1) }) :: Frame
	local header, headerScale = scaled({ Parent = backdrop, Name = "Header", Size = UDim2.fromOffset(520, 44), ZIndex = 12 })
	local close = UIUtil.iconButton({ Parent = header, Name = "Close", Size = UDim2.fromOffset(44, 44), ZIndex = 12 }, function(slot: Frame)
		UIUtil.label({
			Parent = slot, Text = "✕", Font = Theme.Font.Bold, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center,
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
	homeGroups = { navGroup, lvlGroup, playGroup }
	content = UIUtil.make("Frame", { Parent = gui, Name = "Content", BackgroundTransparency = 1, ZIndex = 10 })

	local camera = Workspace.CurrentCamera
	local function relayout()
		local vp = camera.ViewportSize
		local s = math.clamp(vp.Y / 640, 0.72, 1.75)
		local inset = UIUtil.topInset()
		navScale.Scale = s
		navGroup.Position = UDim2.new(0, 16 * s, 0.5, 0)
		currScale.Scale = s
		currGroup.Position = UDim2.new(1, -16 * s, 0, 12 * s)
		lvlScale.Scale = s
		lvlGroup.Position = UDim2.fromOffset(16 * s, math.max(inset, 12 * s))
		playScale.Scale = s
		playGroup.Position = UDim2.new(0.5, 0, 1, -46 * s)

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
