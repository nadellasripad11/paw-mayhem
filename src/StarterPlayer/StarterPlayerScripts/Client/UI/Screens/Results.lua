--!strict
-- Results: shown during the Results phase while the camera looks at the
-- winners' podium. A VICTORY / DEFEAT banner with the final score sits on top,
-- the full match scoreboard (real avatar headshots, team colours, bots
-- included) runs down the left, and your round summary + the countdown back
-- to the lobby sit at the bottom. Confetti on a win.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local ClientState = require(script.Parent.Parent.Parent.ClientState)

local Results = {}
local player = Players.LocalPlayer
local gui: ScreenGui?
local titleLabel: TextLabel, scoreLabel: TextLabel, subLabel: TextLabel, statLabel: TextLabel, returnLabel: TextLabel
local banner: Frame, boardList: ScrollingFrame, confettiLayer: Frame

local BLUE = Color3.fromRGB(70, 150, 255)
local RED = Color3.fromRGB(255, 86, 96)
local CONFETTI_COLORS = {
	Color3.fromRGB(255, 205, 90), Color3.fromRGB(96, 210, 120),
	Color3.fromRGB(150, 110, 255), Color3.fromRGB(64, 156, 255), Color3.fromRGB(255, 110, 170),
}

local function myTeam(): string?
	for _, e in ipairs(ClientState.Match.board or {}) do
		if e.Name == player.Name then
			return e.Team
		end
	end
	return nil
end

local function burstConfetti()
	confettiLayer:ClearAllChildren()
	for _ = 1, 40 do
		local piece = Instance.new("Frame")
		local size = 7 + math.random() * 7
		piece.Size = UDim2.fromOffset(size, size * 1.6)
		piece.Position = UDim2.new(math.random(), 0, -0.05 - math.random() * 0.15, 0)
		piece.Rotation = math.random(0, 360)
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
		piece.BorderSizePixel = 0
		piece.Parent = confettiLayer
		local dropTime = 2 + math.random() * 1.5
		TweenService:Create(piece, TweenInfo.new(dropTime, Enum.EasingStyle.Linear), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.1, 0),
			Rotation = piece.Rotation + (math.random(180, 540) * (math.random() < 0.5 and -1 or 1)),
		}):Play()
		task.delay(dropTime, function()
			piece:Destroy()
		end)
	end
end

local function boardRow(rank: number, e: any)
	local me = e.Name == player.Name
	local teamColor = e.Team == "Red" and RED or BLUE
	local r = UIUtil.make("Frame", {
		Parent = boardList, LayoutOrder = rank, Size = UDim2.new(1, -6, 0, 44),
		BackgroundColor3 = me and Color3.fromRGB(34, 70, 110) or Color3.fromRGB(16, 26, 48), BackgroundTransparency = 0.1, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(0, 10), r)
	local bar = UIUtil.make("Frame", { Parent = r, Size = UDim2.new(0, 5, 1, -12), Position = UDim2.fromOffset(0, 6), BackgroundColor3 = teamColor, BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), bar)
	UIUtil.label({ Parent = r, Text = tostring(rank), Font = Theme.Font.Title, TextSize = 18, TextColor3 = rank <= 3 and Color3.fromRGB(255, 214, 90) or Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 24, 1, 0) })
	local ring = UIUtil.make("Frame", { Parent = r, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 40, 0.5, 0), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = teamColor:Lerp(Color3.new(0, 0, 0), 0.4), BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), ring)
	if e.IsBot or not e.UserId or e.UserId <= 0 then
		UIUtil.label({ Parent = ring, Text = "BOT", Font = Theme.Font.Title, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
	else
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", e.UserId)
		img.Parent = ring
		UIUtil.corner(UDim.new(1, 0), img)
	end
	UIUtil.label({ Parent = r, Text = (e.Display or e.Name or "?") .. (me and " (YOU)" or ""), Font = Theme.Font.Title, TextSize = 16, Position = UDim2.fromOffset(80, 0), Size = UDim2.new(1, -150, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	UIUtil.label({ Parent = r, Text = tostring(e.Elims or 0), Font = Theme.Font.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -38, 0, 0), Size = UDim2.fromOffset(50, 44) })
	UIUtil.label({ Parent = r, Text = "KO", Font = Theme.Font.Bold, TextSize = 11, TextColor3 = Theme.Color.TextDim, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.fromOffset(24, 44) })
end

function Results.Show(match)
	if not gui then return end
	local winner = match.winner
	local mine = myTeam()
	local won = winner ~= nil and mine ~= nil and winner == mine
	local ffa = match.mode == "FFA"
	if ffa then
		won = winner == player.Name
		mine = "FFA"
	end
	titleLabel.Text = won and "VICTORY!" or (mine and "DEFEAT" or "MATCH OVER")
	titleLabel.TextColor3 = won and Color3.fromRGB(255, 214, 90) or (mine and RED or Color3.new(1, 1, 1))
	local old = banner:FindFirstChildOfClass("UIGradient")
	if old then
		old:Destroy()
	end
	UIUtil.gradient((won and Color3.fromRGB(120, 90, 20) or Color3.fromRGB(70, 24, 40)), Color3.fromRGB(12, 20, 40), 90, banner)
	scoreLabel.Text = string.format('<font color="#5AA0FF">%d</font>   -   <font color="#FF6070">%d</font>', match.scores.Blue or 0, match.scores.Red or 0)
	subLabel.Text = winner and ((winner == "Blue" and "BLUE PAWS" or "RED CLAWS") .. " WIN THE MATCH") or ""
	if ffa then
		local name = winner or "?"
		for _, e in ipairs(match.board or {}) do
			if e.Name == winner then
				name = e.Display or e.Name
			end
		end
		subLabel.Text = string.upper(name) .. " WINS THE FREE FOR ALL"
	end

	for _, c in ipairs(boardList:GetChildren()) do
		if c:IsA("Frame") then
			c:Destroy()
		end
	end
	local myStats = nil
	for i, e in ipairs(match.board or {}) do
		boardRow(i, e)
		if e.Name == player.Name then
			myStats = e
		end
	end
	statLabel.Text = myStats and string.format("YOUR ROUND:  %d ELIMINATIONS  •  %d SCORE", myStats.Elims or 0, myStats.Score or 0) or "MATCH COMPLETE"
	Results.Update(match)
	gui.Enabled = true
	if won then
		burstConfetti()
	else
		confettiLayer:ClearAllChildren()
	end
end

function Results.Update(match)
	if returnLabel then
		returnLabel.Text = string.format("Back to the lobby in %ds", math.max(0, match.timeLeft or 0))
	end
end

function Results.Hide()
	if gui then gui.Enabled = false end
end

function Results.Build()
	local g = UIUtil.make("ScreenGui", {
		Name = "PawResults", Parent = player:WaitForChild("PlayerGui"),
		IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 20, Enabled = false,
	}) :: ScreenGui
	gui = g

	-- Soft vignette only at the edges so the podium stays visible.
	local shade = UIUtil.make("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 10, 24), BorderSizePixel = 0 })
	local grad = Instance.new("UIGradient")
	grad.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.3, 0.85),
		NumberSequenceKeypoint.new(0.7, 0.85), NumberSequenceKeypoint.new(1, 0.35),
	})
	grad.Parent = shade
	confettiLayer = UIUtil.make("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 }) :: Frame

	-- Top banner
	banner = UIUtil.make("Frame", {
		Parent = g, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 8),
		Size = UDim2.fromOffset(520, 124), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	}) :: Frame
	UIUtil.corner(UDim.new(0, 22), banner)
	UIUtil.stroke(Color3.fromRGB(255, 255, 255), 2, banner).Transparency = 0.7
	titleLabel = UIUtil.label({ Parent = banner, Text = "VICTORY!", Font = Theme.Font.Title, TextSize = 52, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 58) })
	UIUtil.stroke(Color3.fromRGB(20, 12, 30), 3, titleLabel)
	scoreLabel = UIUtil.label({ Parent = banner, Text = "", RichText = true, Font = Theme.Font.Title, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 34) })
	subLabel = UIUtil.label({ Parent = banner, Text = "", Font = Theme.Font.Bold, TextSize = 13, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 18) })

	-- Match scoreboard (left)
	local panel = UIUtil.make("Frame", {
		Parent = g, AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 20, 0.55, 0), Size = UDim2.new(0, 330, 0.62, 0),
		BackgroundColor3 = Color3.fromRGB(10, 18, 36), BackgroundTransparency = 0.15, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(0, 18), panel)
	UIUtil.label({ Parent = panel, Text = "MATCH LEADERBOARD", Font = Theme.Font.Title, TextSize = 20, TextColor3 = Color3.fromRGB(150, 220, 255), Position = UDim2.fromOffset(16, 10), Size = UDim2.new(1, -32, 0, 26) })
	boardList = UIUtil.make("ScrollingFrame", {
		Parent = panel, Position = UDim2.fromOffset(10, 44), Size = UDim2.new(1, -20, 1, -54), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}) :: ScrollingFrame
	UIUtil.listLayout(boardList, 6)

	-- Bottom: your round + countdown
	statLabel = UIUtil.label({
		Parent = g, Text = "", Font = Theme.Font.Title, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -44), Size = UDim2.fromOffset(700, 30),
		TextColor3 = Color3.fromRGB(255, 226, 120), TextStrokeTransparency = 0.3,
	})
	returnLabel = UIUtil.label({
		Parent = g, Text = "", TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(400, 22), TextStrokeTransparency = 0.4,
	})
	return g
end

return Results
