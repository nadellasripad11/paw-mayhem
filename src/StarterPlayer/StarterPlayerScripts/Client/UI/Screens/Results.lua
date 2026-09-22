--!strict
-- Results: victory/defeat overlay shown during the Results phase (mirrors the
-- "VICTORY 25 - 18 / Continue" screen in reference 1). On a win, confetti
-- pieces tween down from the top of the card for a real celebration beat.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)

local Results = {}
local player = Players.LocalPlayer
local gui, titleLabel, scoreLabel, subLabel, statLabel, iconSlot, confettiLayer

local CONFETTI_COLORS = {
	Color3.fromRGB(255, 205, 90), Color3.fromRGB(96, 210, 120),
	Color3.fromRGB(150, 110, 255), Color3.fromRGB(64, 156, 255), Color3.fromRGB(255, 110, 170),
}

local function myTeam(): string?
	local board = ClientState.Match.board or {}
	for _, e in ipairs(board) do
		if e.Name == player.Name then
			return e.Team
		end
	end
	return nil
end

local function burstConfetti()
	if not confettiLayer then
		return
	end
	confettiLayer:ClearAllChildren()
	for i = 1, 24 do
		local piece = Instance.new("Frame")
		local size = 6 + math.random() * 6
		piece.Size = UDim2.fromOffset(size, size * 1.6)
		piece.Position = UDim2.new(math.random(), 0, -0.08 - math.random() * 0.15, 0)
		piece.Rotation = math.random(0, 360)
		piece.BackgroundColor3 = CONFETTI_COLORS[math.random(1, #CONFETTI_COLORS)]
		piece.BorderSizePixel = 0
		piece.Parent = confettiLayer
		local dropTime = 1.4 + math.random()
		TweenService:Create(piece, TweenInfo.new(dropTime, Enum.EasingStyle.Linear), {
			Position = UDim2.new(piece.Position.X.Scale + (math.random() - 0.5) * 0.2, 0, 1.1, 0),
			Rotation = piece.Rotation + (math.random(180, 540) * (math.random() < 0.5 and -1 or 1)),
		}):Play()
		task.delay(dropTime, function()
			if piece.Parent then
				piece:Destroy()
			end
		end)
	end
end

function Results.Show(match)
	if not gui then return end
	local winner = match.winner
	local mine = myTeam()
	local won = winner and mine and (winner == mine)
	titleLabel.Text = won and "VICTORY!" or (mine and "DEFEAT" or "MATCH OVER")
	titleLabel.TextColor3 = won and Theme.Color.Coin or Theme.Color.Danger
	if iconSlot then
		iconSlot:ClearAllChildren()
		Icons.Place(won and "Trophy" or "Shield", iconSlot, 56, won and Theme.Color.Coin or Theme.Color.TextMuted)
	end
	scoreLabel.Text = string.format("%d  -  %d", match.scores.Blue or 0, match.scores.Red or 0)
	subLabel.Text = winner and ((winner == "Blue" and "Blue Paws" or "Red Claws") .. " win!") or ""
	local myStats = nil
	for _, entry in ipairs(match.board or {}) do
		if entry.Name == player.Name then
			myStats = entry
			break
		end
	end
	statLabel.Text = myStats and string.format("YOUR ROUND  •  %d ELIMS  •  %d SCORE", myStats.Elims or 0, myStats.Score or 0) or "YOUR ROUND COMPLETE"
	gui.Enabled = true
	if won then
		burstConfetti()
	elseif confettiLayer then
		confettiLayer:ClearAllChildren()
	end
end

function Results.Hide()
	if gui then gui.Enabled = false end
end

function Results.Build()
	gui = UIUtil.make("ScreenGui", {
		Name = "PawResults", Parent = player:WaitForChild("PlayerGui"),
		IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 20, Enabled = false,
	}) :: ScreenGui

	local dim = UIUtil.make("Frame", { Parent = gui, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 15, 30), BackgroundTransparency = 0.22, BorderSizePixel = 0 })
	local card = UIUtil.panel({ Parent = dim, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(456, 382), BackgroundColor3 = Theme.Color.PanelDark, ClipsDescendants = true })
	UIUtil.gradient(Color3.fromRGB(22, 74, 110), Theme.Color.PanelDark, 90, card)
	confettiLayer = UIUtil.make("Frame", { Parent = card, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5 })
	UIUtil.padding(20, card)
	iconSlot = UIUtil.make("Frame", { Parent = card, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 4), Size = UDim2.fromOffset(56, 56), BackgroundTransparency = 1, ZIndex = 6 })
	titleLabel = UIUtil.label({ Parent = card, Text = "VICTORY!", Font = Theme.Font.Title, TextSize = 46, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 60), Position = UDim2.fromOffset(0, 68), ZIndex = 6 })
	scoreLabel = UIUtil.label({ Parent = card, Text = "0 - 0", Font = Theme.Font.Number, TextSize = 42, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 138), ZIndex = 6 })
	subLabel = UIUtil.label({ Parent = card, Text = "", TextColor3 = Theme.Color.TextDim, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 194), ZIndex = 6 })
	statLabel = UIUtil.label({ Parent = card, Text = "YOUR ROUND COMPLETE", Font = Theme.Font.Bold, TextColor3 = Theme.Color.Accent, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 218), ZIndex = 6 })
	local resultTag = UIUtil.panel({ Parent = card, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 236), Size = UDim2.fromOffset(250, 34), BackgroundColor3 = Color3.fromRGB(8, 42, 76), ZIndex = 6 })
	UIUtil.label({ Parent = resultTag, Text = "MATCH COMPLETE  •  RESULTS SAVED", Font = Theme.Font.Bold, TextColor3 = Theme.Color.Accent, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 7 })
	UIUtil.label({ Parent = card, Text = "Returning to lobby…", TextColor3 = Theme.Color.TextMuted, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -38), ZIndex = 6 })

	return gui
end

return Results
