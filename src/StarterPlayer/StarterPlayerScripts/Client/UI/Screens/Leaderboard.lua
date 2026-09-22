--!strict
-- Leaderboard: your lifetime stats + a live in-server ranking by eliminations.
-- (A true cross-server global board would use OrderedDataStore; documented in
-- CONFIG.md. This shows the current server's players, which is accurate + safe.
-- Every visible tab is backed by real local data: live ranking, this-match
-- ranking, or the player's saved lifetime statistics.

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local HeroArt = require(script.Parent.Parent.HeroArt)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)

local Leaderboard = {}
local boardList, statsHolder, tabButtons
local activeTab = "Global"

local RANK_COLOR = {
	Color3.fromRGB(255, 205, 90), -- gold
	Color3.fromRGB(200, 210, 225), -- silver
	Color3.fromRGB(205, 140, 90), -- bronze
}

local STAT_META = {
	{ key = "Eliminations", label = "Eliminations", icon = "Gun", color = Theme.Color.Danger },
	{ key = "Ringouts", label = "Ringouts", icon = "Burst", color = Theme.Color.Warn },
	{ key = "Wins", label = "Wins", icon = "Trophy", color = Theme.Color.Coin },
	{ key = "Matches", label = "Matches", icon = "Check", color = Theme.Color.Accent },
	{ key = "Deaths", label = "Deaths", icon = "Shield", color = Theme.Color.TextMuted },
	{ key = "DamageDealt", label = "Damage", icon = "Bolt", color = Theme.Color.Accent2 },
}

local function rebuildStats()
	if not statsHolder then return end
	statsHolder:ClearAllChildren()
	UIUtil.gridLayout(statsHolder, UDim2.fromOffset(140, 68), UDim2.fromOffset(10, 10))
	local p = ClientState.Profile
	if not p then return end
	for _, meta in ipairs(STAT_META) do
		local card = UIUtil.panel({ Parent = statsHolder, BackgroundColor3 = Theme.Color.PanelLight })
		local iconSlot = UIUtil.make("Frame", { Parent = card, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = meta.color, BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(0.3, 0), iconSlot)
		Icons.Place(meta.icon, iconSlot, 18, Color3.new(1, 1, 1))
		UIUtil.label({ Parent = card, Text = tostring(p.Stats[meta.key] or 0), Font = Theme.Font.Number, TextSize = 22, Position = UDim2.fromOffset(46, 6), Size = UDim2.new(1, -56, 0, 28) })
		UIUtil.label({ Parent = card, Text = meta.label, TextColor3 = Theme.Color.TextDim, TextSize = 11, Position = UDim2.fromOffset(46, 34), Size = UDim2.new(1, -56, 0, 16) })
	end
end

local function rebuildBoard()
	if not boardList then return end
	boardList.Visible = true
	boardList:ClearAllChildren()
	UIUtil.listLayout(boardList, 6)
	if activeTab == "My Stats" then
		local p = ClientState.Profile
		if not p then
			UIUtil.label({ Parent = boardList, Text = "Profile loading…", TextColor3 = Theme.Color.TextMuted, TextSize = 13, Size = UDim2.new(1, 0, 0, 22) })
			return
		end
		for _, meta in ipairs(STAT_META) do
			local row = UIUtil.panel({ Parent = boardList, Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = Theme.Color.PanelLight })
			UIUtil.padding(8, row)
			local iconSlot = UIUtil.make("Frame", { Parent = row, Size = UDim2.fromOffset(24, 24), BackgroundColor3 = meta.color, BorderSizePixel = 0 })
			UIUtil.corner(UDim.new(0.3, 0), iconSlot)
			Icons.Place(meta.icon, iconSlot, 15, Color3.new(1, 1, 1))
			UIUtil.label({ Parent = row, Text = meta.label, Font = Theme.Font.Bold, TextSize = 13, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -110, 1, 0) })
			UIUtil.label({ Parent = row, Text = tostring(p.Stats[meta.key] or 0), Font = Theme.Font.Number, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -68, 0, 0), Size = UDim2.fromOffset(60, 24) })
		end
		return
	end
	local board = ClientState.Match.board or {}
	if #board == 0 then
		UIUtil.label({ Parent = boardList, Text = "No live match ranking yet — play a match!", TextColor3 = Theme.Color.TextMuted, TextSize = 13, Size = UDim2.new(1, 0, 0, 20) })
		return
	end
	for i, entry in ipairs(board) do
		local row = UIUtil.panel({ Parent = boardList, Size = UDim2.new(1, 0, 0, 36), BackgroundColor3 = Theme.Color.PanelLight })
		UIUtil.padding(6, row)
		local rankChip = UIUtil.make("Frame", { Parent = row, Size = UDim2.fromOffset(24, 24), BackgroundColor3 = RANK_COLOR[i] or Theme.Color.PanelDark, BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(0.5, 0), rankChip)
		UIUtil.label({ Parent = rankChip, Text = tostring(i), Font = Theme.Font.Number, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = i <= 3 and Color3.fromRGB(30, 24, 10) or Theme.Color.Text, Size = UDim2.fromScale(1, 1) })
		local color = entry.Team == "Red" and Theme.Color.Red or Theme.Color.Blue
		UIUtil.label({ Parent = row, Text = entry.Display or entry.Name, TextColor3 = color, Font = Theme.Font.Bold, TextSize = 15, Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -136, 1, 0) })
		UIUtil.label({ Parent = row, Text = tostring(entry.Elims) .. " elims", TextColor3 = Theme.Color.Text, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -96, 0, 0), Size = UDim2.fromOffset(90, 24) })
	end
end

local function setTab(name)
	activeTab = name
	for k, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = (k == name) and Theme.Color.Accent or Theme.Color.PanelDark
	end
	rebuildBoard()
end

function Leaderboard.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }) :: Frame
	HeroArt.Watermark(root)

	local header = UIUtil.make("Frame", { Parent = root, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 })
	local trophySlot = UIUtil.make("Frame", { Parent = header, Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1 })
	Icons.Place("Trophy", trophySlot, 20, Theme.Color.Coin)
	UIUtil.label({ Parent = header, Text = "YOUR STATS", Font = Theme.Font.Heading, TextSize = 16, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 1, 0) })

	statsHolder = UIUtil.make("Frame", { Parent = root, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 140) })
	rebuildStats()

	UIUtil.label({ Parent = root, Text = "LIVE RANKING", Font = Theme.Font.Heading, TextSize = 16, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(0, 180), Size = UDim2.new(0, 200, 0, 20) })

	local tabs = UIUtil.make("Frame", { Parent = root, Position = UDim2.new(1, -260, 0, 176), Size = UDim2.fromOffset(260, 28), BackgroundTransparency = 1 })
	UIUtil.listLayout(tabs, 6, Enum.FillDirection.Horizontal)
	tabButtons = {}
	for _, name in ipairs({ "Global", "This Match", "My Stats" }) do
		tabButtons[name] = UIUtil.button({
			Parent = tabs, Size = UDim2.fromOffset(82, 28), BackgroundColor3 = Theme.Color.PanelDark,
			Text = name, TextSize = 12, CornerRadius = Theme.CornerSmall,
		}, function()
			setTab(name)
		end)
	end
	tabButtons.Global.BackgroundColor3 = Theme.Color.Accent

	local listWrap = UIUtil.make("Frame", { Parent = root, Position = UDim2.fromOffset(0, 210), Size = UDim2.new(1, 0, 1, -210), BackgroundTransparency = 1 })
	boardList = UIUtil.make("ScrollingFrame", {
		Parent = listWrap, Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	rebuildBoard()

	ClientState.ProfileChanged:Connect(rebuildStats)
	ClientState.MatchChanged:Connect(rebuildBoard)
	Leaderboard.Root = root
	return root
end

return Leaderboard
