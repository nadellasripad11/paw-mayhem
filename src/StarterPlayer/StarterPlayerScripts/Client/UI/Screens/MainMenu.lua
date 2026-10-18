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

local NAV_BG = Color3.fromRGB(16, 22, 30)
local NAV_BG_T = 0.32

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
		entry.button.BackgroundColor3 = on and Theme.Color.Accent or NAV_BG
		entry.button.BackgroundTransparency = on and 0.1 or NAV_BG_T
		entry.stroke.Transparency = on and 0.05 or entry.baseStroke
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
		panelBackdrop.BackgroundTransparency = inGame and 0.35 or 0.04
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
	-- Level + trophy tier, e.g. "Lv. 5 · GOLD 640".
	local trophies = p.Stats and tonumber(p.Stats.Trophies) or 0
	local tier = Ranks.For(trophies)
	levelLabel.RichText = true
	levelLabel.Text = string.format('Lv. %d  <font color="#%s" size="15">%s %d</font>', p.Level or 1, tier.Color:ToHex(), string.upper(tier.Name), trophies)
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

-- ── left icon buttons: square glass tiles, icon over a small label ───────────
local function navButton(parent: Instance, item, order: number)
	local b = Instance.new("TextButton")
	b.Name = item.id
	b.AutoButtonColor = false
	b.Text = ""
	b.Size = UDim2.fromOffset(74, 74)
	b.LayoutOrder = order
	b.BorderSizePixel = 0
	b.ZIndex = 11
	b.BackgroundColor3 = NAV_BG
	b.BackgroundTransparency = NAV_BG_T
	b.Parent = parent
	UIUtil.corner(UDim.new(0, 14), b)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Thickness = 1
	stroke.Transparency = 0.82
	stroke.Parent = b

	local slot = UIUtil.make("Frame", {
		Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 30),
		Size = UDim2.fromOffset(32, 32), BackgroundTransparency = 1, ZIndex = 12,
	})
	local white = Color3.new(1, 1, 1)
	Icons.Place(item.icon, slot, 32, white, white)
	UIUtil.label({
		Parent = b, Name = "NavLabel", Text = item.label, Font = Theme.Font.Title, TextSize = 12,
		TextColor3 = white, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 16), ZIndex = 12,
	})

	local pop = Instance.new("UIScale")
	pop.Parent = b
	b.MouseEnter:Connect(function()
		TweenService:Create(pop, TweenInfo.new(0.12), { Scale = 1.06 }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(pop, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
	b.MouseButton1Click:Connect(function()
		switchTo(item.id)
	end)
	navButtons[item.id] = { button = b, stroke = stroke, baseStroke = stroke.Transparency }
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

	-- Icon buttons down the left side
	local navGroup, navScale = scaled({ Parent = gui, Name = "NavGroup", AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(74, 4 * 74 + 3 * 10), ZIndex = 10 })
	UIUtil.listLayout(navGroup, 10)
	for i, item in ipairs(NAV) do
		navButton(navGroup, item, i)
	end

	-- PLAY (bottom centre): pick a mode and vote a map for the next match, or
	-- drop straight into one that's running. The line under it says where you are.
	local playGroup, playScale = scaled({ Parent = gui, Name = "PlayGroup", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(260, 88), ZIndex = 10 })
	local play = Instance.new("TextButton")
	play.Name = "Play"
	play.AutoButtonColor = false
	play.Text = ""
	play.Size = UDim2.fromOffset(260, 62)
	play.BackgroundColor3 = Color3.new(1, 1, 1)
	play.BorderSizePixel = 0
	play.ZIndex = 11
	play.Parent = playGroup
	UIUtil.corner(UDim.new(0, 16), play)
	UIUtil.gradient(Color3.fromRGB(132, 228, 76), Color3.fromRGB(54, 170, 50), 90, play)
	UIUtil.stroke(Color3.fromRGB(198, 255, 150), 2, play).Transparency = 0.15
	local gloss = UIUtil.make("Frame", {
		Parent = play, Position = UDim2.fromOffset(6, 4), Size = UDim2.new(1, -12, 0.42, 0),
		BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.8, BorderSizePixel = 0, ZIndex = 11,
	})
	UIUtil.corner(UDim.new(0, 12), gloss)
	local playLabel = UIUtil.label({
		Parent = play, Text = "PLAY", Font = Theme.Font.Title, TextSize = 34, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 12,
	})
	textStroke(playLabel, Color3.fromRGB(36, 112, 34), 2)
	local playSub = UIUtil.label({
		Parent = playGroup, Text = "", Font = Theme.Font.Bold, TextSize = 14, TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 0, 20),
		TextStrokeTransparency = 0.5, ZIndex = 11,
	})
	local playPop = Instance.new("UIScale")
	playPop.Parent = play
	play.MouseEnter:Connect(function()
		TweenService:Create(playPop, TweenInfo.new(0.12), { Scale = 1.04 }):Play()
	end)
	play.MouseLeave:Connect(function()
		TweenService:Create(playPop, TweenInfo.new(0.12), { Scale = 1 }):Play()
	end)
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

	-- Coins + gems (top right)
	local currGroup, currScale = scaled({ Parent = gui, Name = "CurrencyGroup", AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(640, 40), ZIndex = 10 })
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

	-- The rest of the top bar: one row of matching round buttons (Daily,
	-- Invite, VIP, Leaderboard, Settings). Each shows its name on hover.
	local function roundButton(name: string, order: number, tip: string, onClick: () -> ()): TextButton
		local b = Instance.new("TextButton")
		b.Name = name
		b.Text = ""
		b.AutoButtonColor = false
		b.Size = UDim2.fromOffset(40, 40)
		b.LayoutOrder = order
		b.BackgroundColor3 = Color3.fromRGB(20, 26, 40)
		b.BackgroundTransparency = 0.25
		b.BorderSizePixel = 0
		b.ZIndex = 10
		b.Parent = currGroup
		UIUtil.corner(UDim.new(1, 0), b)
		local ring = UIUtil.stroke(Color3.new(1, 1, 1), 1, b)
		ring.Transparency = 0.7
		local label = UIUtil.label({
			Parent = b, Text = tip, Font = Theme.Font.Bold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6), Size = UDim2.fromOffset(90, 16),
			TextStrokeTransparency = 0.4, Visible = false, ZIndex = 12,
		})
		local pop = Instance.new("UIScale")
		pop.Parent = b
		b.MouseEnter:Connect(function()
			label.Visible = true
			ring.Transparency = 0.2
			TweenService:Create(pop, TweenInfo.new(0.12), { Scale = 1.08 }):Play()
		end)
		b.MouseLeave:Connect(function()
			label.Visible = false
			ring.Transparency = 0.7
			TweenService:Create(pop, TweenInfo.new(0.12), { Scale = 1 }):Play()
		end)
		b.MouseButton1Click:Connect(onClick)
		return b
	end
	local function glyph(parent: Instance, icon: string, size: number, color: Color3)
		local slot = UIUtil.make("Frame", {
			Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1, ZIndex = 11,
		})
		Icons.Place(icon, slot, size, color, color)
	end

	-- DAILY reward (red dot when today's reward is waiting).
	local daily = roundButton("Daily", 3, "DAILY", function()
		DailyReward.Open()
	end)
	glyph(daily, "Sparkle", 22, Color3.fromRGB(255, 150, 190))
	local dot = UIUtil.make("Frame", { Parent = daily, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -5, 0, 5), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = Color3.fromRGB(255, 50, 60), BorderSizePixel = 0, ZIndex = 12 })
	UIUtil.corner(UDim.new(1, 0), dot)
	UIUtil.stroke(Color3.new(1, 1, 1), 2, dot)
	ClientState.ProfileChanged:Connect(function()
		dot.Visible = DailyReward.CanClaim()
	end)
	dot.Visible = false

	-- INVITE: Roblox's friend-invite prompt (hidden where invites aren't allowed).
	local invite = roundButton("Invite", 4, "INVITE", function()
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	end)
	glyph(invite, "Plus", 18, Color3.fromRGB(120, 210, 255))
	invite.Visible = false
	task.spawn(function()
		local ok, can = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		invite.Visible = ok and can == true
	end)

	-- VIP (gold, hidden once owned).
	local vip = roundButton("VIP", 5, "GET VIP", function()
		Monetize.PromptPass("VIP")
	end)
	vip.BackgroundTransparency = 0
	vip.BackgroundColor3 = Color3.new(1, 1, 1)
	UIUtil.gradient(Color3.fromRGB(255, 226, 110), Color3.fromRGB(240, 160, 30), 90, vip)
	UIUtil.label({
		Parent = vip, Text = "VIP", Font = Theme.Font.Title, TextSize = 14, TextColor3 = Color3.fromRGB(80, 46, 0),
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 11,
	})
	local function refreshVip()
		vip.Visible = not Monetize.OwnsPass("VIP")
	end
	player:GetAttributeChangedSignal("VIP"):Connect(refreshVip)
	refreshVip()

	-- Leaderboard + Settings at the far right.
	for i, spec in ipairs({ { "Leaderboard", "Podium", "LEADERBOARD" }, { "Settings", "Gear", "SETTINGS" } }) do
		local b = roundButton(spec[1] .. "Icon", 10 + i, spec[3], function()
			switchTo(spec[1])
		end)
		smallIcon(spec[2], b)
	end

	-- Toast (top centre) for notices and purchase messages in the lobby.
	local toast = UIUtil.label({
		Parent = gui, Name = "Toast", Text = "", Font = Theme.Font.Title, TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 16), Size = UDim2.fromOffset(0, 40), AutomaticSize = Enum.AutomaticSize.X,
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

	-- Level pill (top left)
	local lvlGroup, lvlScale = scaled({ Parent = gui, Name = "LevelGroup", Size = UDim2.fromOffset(232, 58), ZIndex = 10 })
	local pill = glassPill({ Parent = lvlGroup, Size = UDim2.fromScale(1, 1), ZIndex = 10 })
	local avatarRing = UIUtil.make("Frame", { Parent = pill, Position = UDim2.fromOffset(7, 6), Size = UDim2.fromOffset(46, 46), BackgroundColor3 = Color3.fromRGB(255, 244, 236), BorderSizePixel = 0, ZIndex = 11 })
	UIUtil.corner(UDim.new(0.5, 0), avatarRing)
	UIUtil.stroke(Color3.new(1, 1, 1), 2, avatarRing)
	avatarSlot = UIUtil.make("Frame", { Parent = avatarRing, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 12 })
	Icons.Place("CatFace", avatarSlot, 40, Color3.fromRGB(255, 236, 222), Color3.fromRGB(255, 248, 242))
	levelLabel = UIUtil.label({ Parent = pill, Text = "Lv. 1", Font = Theme.Font.Title, TextSize = 19, Position = UDim2.fromOffset(62, 7), Size = UDim2.fromOffset(165, 20), ZIndex = 11 })
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

	-- First visit: the tutorial; after that, the daily reward popup (once per
	-- session) whenever one is waiting.
	local dailyOk = pcall(DailyReward.Build)
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
		local function daily()
			if dailyOk and DailyReward.CanClaim() then
				DailyReward.Open()
			end
		end
		-- Point new players at PLAY.
		local function pointAtPlay()
			local play = gui:FindFirstChild("Play", true)
			if play and play:IsA("GuiObject") then
				local arrow = UIUtil.label({
					Parent = play, Name = "StartHere", Text = "▼ START HERE", Font = Theme.Font.Title, TextSize = 18,
					TextColor3 = Color3.fromRGB(255, 226, 90), TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -8),
					Size = UDim2.fromOffset(150, 30), ZIndex = 20, TextStrokeTransparency = 0.3,
				})
				TweenService:Create(arrow, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.new(0.5, 0, 0, -18) }):Play()
				task.spawn(function()
					while arrow.Parent and not player:GetAttribute("Queued") and player:GetAttribute("Context") ~= "Match" do
						task.wait(0.5)
					end
					arrow:Destroy()
				end)
			end
		end
		-- Brand-new players get the intro: a short cinematic, then a hands-on
		-- lesson with Mochi in the lobby. Then PLAY is pointed out.
		if Tutorial.ShouldShow() then
			gui.Enabled = false
			Intro.Run(function()
				gui.Enabled = player:GetAttribute("Context") == "Lobby"
				pointAtPlay()
				daily()
			end)
		else
			daily()
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
