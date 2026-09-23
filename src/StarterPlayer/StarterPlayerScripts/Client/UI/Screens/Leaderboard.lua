--!strict
-- Leaderboard: two tabs.
--   LEADERBOARD  Global / your country, ranked by Eliminations or Wins, with
--                real Roblox avatar headshots, medals for the top 3 and your
--                own row highlighted.
--   YOUR STATS   Your full-body avatar, level, global + country rank and a
--                detailed stat grid (K/D, win rate, damage...).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local ClientState = require(script.Parent.Parent.Parent.ClientState)

local Leaderboard = {}

local player = Players.LocalPlayer
local CARD_BG = Color3.fromRGB(22, 38, 68)
local ROW_BG = Color3.fromRGB(20, 34, 62)
local MEDAL = {
	{ Color3.fromRGB(255, 214, 90), Color3.fromRGB(214, 150, 30) },
	{ Color3.fromRGB(226, 232, 242), Color3.fromRGB(150, 160, 178) },
	{ Color3.fromRGB(236, 164, 104), Color3.fromRGB(170, 96, 50) },
}

local scope, metric = "Global", "Eliminations"
local list: ScrollingFrame
local statusLabel: TextLabel
local scopeButtons: { [string]: TextButton } = {}
local metricButtons: { [string]: TextButton } = {}
local myRanks: { [string]: number? } = {}
local refreshStats: () -> () = function() end
local requestToken = 0

local function headshot(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", math.max(userId, 1))
end

local function flag(cc: string?): string
	if typeof(cc) ~= "string" or #cc ~= 2 then
		return ""
	end
	local a, b = string.byte(string.upper(cc), 1, 2)
	return utf8.char(0x1F1E6 + a - 65, 0x1F1E6 + b - 65)
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return out:sub(1, 1) == "," and out:sub(2) or out
end

local function pill(parent: Instance, text: string, order: number, onClick: () -> ()): TextButton
	local b = UIUtil.make("TextButton", {
		Parent = parent, LayoutOrder = order, Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X,
		Text = text, Font = Theme.Font.Title, TextSize = 17, AutoButtonColor = true, BorderSizePixel = 0,
		BackgroundColor3 = CARD_BG, TextColor3 = Color3.new(1, 1, 1),
	}) :: TextButton
	UIUtil.corner(UDim.new(1, 0), b)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 20)
	pad.PaddingRight = UDim.new(0, 20)
	pad.Parent = b
	b.MouseButton1Click:Connect(onClick)
	return b
end

local function paint(buttons: { [string]: TextButton }, active: string)
	for id, b in pairs(buttons) do
		local on = id == active
		b.BackgroundColor3 = on and Color3.fromRGB(64, 200, 255) or CARD_BG
		b.TextColor3 = on and Color3.fromRGB(8, 30, 52) or Color3.new(1, 1, 1)
	end
end

-- ── ranking rows ─────────────────────────────────────────────────────────────
local function row(entry: any)
	local rank = entry.rank
	local me = entry.userId == player.UserId
	local top3 = rank <= 3
	local r = UIUtil.make("Frame", {
		Parent = list, LayoutOrder = rank, Size = UDim2.new(1, -8, 0, top3 and 70 or 58),
		BackgroundColor3 = me and Color3.fromRGB(30, 74, 110) or ROW_BG, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(0, 14), r)
	local stroke = UIUtil.stroke(me and Color3.fromRGB(90, 210, 255) or (top3 and MEDAL[rank][1] or Color3.fromRGB(44, 68, 110)), top3 and 2 or 1.2, r)
	stroke.Transparency = top3 and 0.2 or 0.4
	if top3 then
		UIUtil.gradient(MEDAL[rank][2]:Lerp(ROW_BG, 0.72), ROW_BG, 0, r)
	end

	-- Rank medal / number
	local medal = UIUtil.make("Frame", {
		Parent = r, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(top3 and 40 or 34, top3 and 40 or 34), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), medal)
	if top3 then
		UIUtil.gradient(MEDAL[rank][1], MEDAL[rank][2], 90, medal)
		UIUtil.stroke(Color3.new(1, 1, 1), 2, medal).Transparency = 0.3
	else
		medal.BackgroundColor3 = Color3.fromRGB(36, 56, 92)
	end
	UIUtil.label({
		Parent = medal, Text = tostring(rank), Font = Theme.Font.Title, TextSize = top3 and 20 or 16,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
		TextColor3 = top3 and Color3.fromRGB(60, 36, 0) or Color3.new(1, 1, 1),
	})

	-- Real avatar headshot
	local avatarSize = top3 and 54 or 44
	local ring = UIUtil.make("Frame", {
		Parent = r, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 66, 0.5, 0),
		Size = UDim2.fromOffset(avatarSize, avatarSize), BackgroundColor3 = Color3.fromRGB(60, 90, 140), BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), ring)
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = headshot(entry.userId)
	img.Parent = ring
	UIUtil.corner(UDim.new(1, 0), img)

	UIUtil.label({
		Parent = r, Text = entry.name .. (me and "  (YOU)" or ""), Font = Theme.Font.Title, TextSize = top3 and 22 or 19,
		Position = UDim2.new(0, 66 + avatarSize + 14, 0, 0), Size = UDim2.new(1, -(66 + avatarSize + 200), 1, 0),
		TextTruncate = Enum.TextTruncate.AtEnd, TextColor3 = me and Color3.fromRGB(150, 230, 255) or Color3.new(1, 1, 1),
	})
	UIUtil.label({
		Parent = r, Text = commas(entry.value or 0), Font = Theme.Font.Title, TextSize = top3 and 26 or 22,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -90, 0, 0), Size = UDim2.new(0, 110, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = top3 and MEDAL[rank][1] or Color3.new(1, 1, 1),
	})
	UIUtil.label({
		Parent = r, Text = metric == "Wins" and "WINS" or "ELIMS", Font = Theme.Font.Bold, TextSize = 12,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 0), Size = UDim2.new(0, 64, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Color.TextDim,
	})
end

local function load()
	requestToken += 1
	local token = requestToken
	paint(scopeButtons, scope)
	paint(metricButtons, metric)
	for _, c in ipairs(list:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	statusLabel.Text = "Loading..."
	task.spawn(function()
		local ok, res = pcall(function()
			return Remotes.Get("GetLeaderboard"):InvokeServer({ scope = scope, metric = metric })
		end)
		if token ~= requestToken then
			return
		end
		if not ok or typeof(res) ~= "table" then
			statusLabel.Text = "Couldn't load the leaderboard. Try again in a moment."
			return
		end
		local cc = res.country
		if scopeButtons.Country then
			scopeButtons.Country.Text = flag(cc) .. "  " .. (cc or "COUNTRY")
		end
		local entries = res.entries or {}
		statusLabel.Text = #entries == 0 and "No one's on the board yet. Get some eliminations!"
			or (res.live and "Showing players in this server" or "")
		for _, e in ipairs(entries) do
			row(e)
			if e.userId == player.UserId then
				myRanks[scope .. metric] = e.rank
			end
		end
		refreshStats()
	end)
end

-- ── your stats ───────────────────────────────────────────────────────────────
local function buildStats(parent: Frame)
	-- Left: full-body avatar card
	local card = UIUtil.make("Frame", {
		Parent = parent, Size = UDim2.new(0.32, -8, 1, 0), BackgroundColor3 = CARD_BG, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(0, 18), card)
	UIUtil.gradient(Color3.fromRGB(40, 80, 140), Color3.fromRGB(14, 24, 46), 90, card)
	local avatar = Instance.new("ImageLabel")
	avatar.BackgroundTransparency = 1
	avatar.AnchorPoint = Vector2.new(0.5, 0)
	avatar.Position = UDim2.new(0.5, 0, 0, 12)
	avatar.Size = UDim2.new(1, -24, 1, -150)
	avatar.ScaleType = Enum.ScaleType.Fit
	avatar.Image = string.format("rbxthumb://type=Avatar&id=%d&w=420&h=420", math.max(player.UserId, 1))
	avatar.Parent = card
	UIUtil.label({
		Parent = card, Text = player.DisplayName, Font = Theme.Font.Title, TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104), Size = UDim2.new(1, -20, 0, 30), TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local levelLabel = UIUtil.label({
		Parent = card, Text = "", Font = Theme.Font.Bold, TextSize = 15, TextColor3 = Color3.fromRGB(150, 220, 255),
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -82), Size = UDim2.new(1, -20, 0, 20),
	})
	local ranks = UIUtil.make("Frame", {
		Parent = card, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14),
		Size = UDim2.new(1, -24, 0, 58), BackgroundTransparency = 1,
	})
	UIUtil.listLayout(ranks, 10, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Center
	local function rankBox(title: string): TextLabel
		local b = UIUtil.make("Frame", { Parent = ranks, Size = UDim2.new(0.5, -5, 1, 0), BackgroundColor3 = Color3.fromRGB(12, 22, 42), BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(0, 12), b)
		UIUtil.label({ Parent = b, Text = title, Font = Theme.Font.Bold, TextSize = 11, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 14) })
		return UIUtil.label({ Parent = b, Text = "--", Font = Theme.Font.Title, TextSize = 22, TextColor3 = Color3.fromRGB(255, 214, 90), TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 28) })
	end
	local globalRank = rankBox("GLOBAL RANK")
	local countryRank = rankBox("COUNTRY RANK")

	-- Right: stat grid
	local grid = UIUtil.make("ScrollingFrame", {
		Parent = parent, Position = UDim2.new(0.32, 8, 0, 0), Size = UDim2.new(0.68, -8, 1, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	UIUtil.gridLayout(grid, UDim2.new(1 / 3, -10, 0, 104), UDim2.fromOffset(12, 12))

	local STATS = {
		{ label = "ELIMINATIONS", color = Color3.fromRGB(255, 96, 110), get = function(s) return commas(s.Eliminations or 0) end },
		{ label = "WINS", color = Color3.fromRGB(255, 206, 70), get = function(s) return commas(s.Wins or 0) end },
		{ label = "MATCHES", color = Color3.fromRGB(90, 190, 255), get = function(s) return commas(s.Matches or 0) end },
		{ label = "WIN RATE", color = Color3.fromRGB(120, 230, 150), get = function(s)
			local m = s.Matches or 0
			return m > 0 and string.format("%d%%", math.floor((s.Wins or 0) / m * 100 + 0.5)) or "0%"
		end },
		{ label = "K / D", color = Color3.fromRGB(200, 130, 255), get = function(s)
			return string.format("%.2f", (s.Eliminations or 0) / math.max(1, s.Deaths or 0))
		end },
		{ label = "RINGOUTS", color = Color3.fromRGB(255, 150, 70), get = function(s) return commas(s.Ringouts or 0) end },
		{ label = "DEATHS", color = Color3.fromRGB(170, 180, 200), get = function(s) return commas(s.Deaths or 0) end },
		{ label = "DAMAGE DEALT", color = Color3.fromRGB(255, 120, 180), get = function(s) return commas(s.DamageDealt or 0) end },
		{ label = "POWER-UPS", color = Color3.fromRGB(110, 240, 220), get = function(s) return commas(s.PowerupsGrabbed or 0) end },
	}
	local valueLabels = {}
	for order, st in ipairs(STATS) do
		local c = UIUtil.make("Frame", { Parent = grid, LayoutOrder = order, BackgroundColor3 = CARD_BG, BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(0, 16), c)
		UIUtil.gradient(st.color:Lerp(CARD_BG, 0.78), CARD_BG, 0, c)
		local bar = UIUtil.make("Frame", { Parent = c, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(0, 5, 1, -32), BackgroundColor3 = st.color, BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(1, 0), bar)
		valueLabels[order] = UIUtil.label({ Parent = c, Text = "0", Font = Theme.Font.Title, TextSize = 38, Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -28, 0, 46) })
		UIUtil.label({ Parent = c, Text = st.label, Font = Theme.Font.Bold, TextSize = 13, TextColor3 = st.color, Position = UDim2.fromOffset(20, 64), Size = UDim2.new(1, -28, 0, 18) })
	end

	refreshStats = function()
		local p = ClientState.Profile
		if not p then
			return
		end
		local s = p.Stats or {}
		for i, st in ipairs(STATS) do
			valueLabels[i].Text = st.get(s)
		end
		levelLabel.Text = string.format("LEVEL %d  •  %s XP", p.Level or 1, commas(p.XP or 0))
		local g, c = myRanks["Global" .. metric], myRanks["Country" .. metric]
		globalRank.Text = g and ("#" .. g) or "50+"
		countryRank.Text = c and ("#" .. c) or "50+"
	end
	ClientState.ProfileChanged:Connect(refreshStats)
	refreshStats()
end

function Leaderboard.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }) :: Frame

	-- Main tabs
	local tabs = UIUtil.make("Frame", { Parent = root, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1 })
	UIUtil.listLayout(tabs, 10, Enum.FillDirection.Horizontal)
	local boardPage = UIUtil.make("Frame", { Parent = root, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56), BackgroundTransparency = 1 }) :: Frame
	local statsPage = UIUtil.make("Frame", { Parent = root, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 1, -56), BackgroundTransparency = 1, Visible = false }) :: Frame
	local mainButtons: { [string]: TextButton } = {}
	local function showMain(id: string)
		paint(mainButtons, id)
		boardPage.Visible = id == "Board"
		statsPage.Visible = id == "Stats"
		if id == "Stats" then
			refreshStats()
		end
	end
	mainButtons.Board = pill(tabs, "LEADERBOARD", 1, function() showMain("Board") end)
	mainButtons.Stats = pill(tabs, "YOUR STATS", 2, function() showMain("Stats") end)
	for _, b in pairs(mainButtons) do
		b.TextSize = 20
		b.Size = UDim2.fromOffset(0, 44)
	end

	-- Leaderboard: scope + metric toggles, then the list
	local controls = UIUtil.make("Frame", { Parent = boardPage, Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 })
	local left = UIUtil.make("Frame", { Parent = controls, Size = UDim2.new(0.6, 0, 1, 0), BackgroundTransparency = 1 })
	UIUtil.listLayout(left, 8, Enum.FillDirection.Horizontal)
	scopeButtons.Global = pill(left, "GLOBAL", 1, function() scope = "Global"; load() end)
	scopeButtons.Country = pill(left, "YOUR COUNTRY", 2, function() scope = "Country"; load() end)
	local right = UIUtil.make("Frame", { Parent = controls, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.4, 0, 1, 0), BackgroundTransparency = 1 })
	UIUtil.listLayout(right, 8, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Right
	metricButtons.Eliminations = pill(right, "ELIMINATIONS", 1, function() metric = "Eliminations"; load() end)
	metricButtons.Wins = pill(right, "WINS", 2, function() metric = "Wins"; load() end)

	statusLabel = UIUtil.label({
		Parent = boardPage, Text = "", TextSize = 13, TextColor3 = Theme.Color.TextDim,
		Position = UDim2.fromOffset(4, 44), Size = UDim2.new(1, -8, 0, 18),
	})
	list = UIUtil.make("ScrollingFrame", {
		Parent = boardPage, Position = UDim2.fromOffset(0, 66), Size = UDim2.new(1, 0, 1, -66),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}) :: ScrollingFrame
	UIUtil.listLayout(list, 8)

	buildStats(statsPage)
	showMain("Board")

	-- Reload whenever the screen is opened.
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible then
			load()
		end
	end)
	Leaderboard.Root = root
	return root
end

return Leaderboard
