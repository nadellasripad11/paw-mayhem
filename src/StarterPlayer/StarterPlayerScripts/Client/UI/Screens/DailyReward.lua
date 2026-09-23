--!strict
-- DailyReward: the 7-day login calendar popup. Opens by itself once per
-- session when today's reward is waiting (and from the DAILY button). Days
-- already claimed this cycle show a check, today glows, Day 7 is a chest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local DailyRewards = require(ReplicatedStorage.Shared.Config.DailyRewards)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local ShopArt = require(script.Parent.Parent.ShopArt)
local ClientState = require(script.Parent.Parent.Parent.ClientState)

local DailyReward = {}

local player = Players.LocalPlayer
local gui: ScreenGui?
local dayCards: { { frame: Frame, stroke: UIStroke, check: TextLabel, label: TextLabel } } = {}
local claimButton: TextButton
local streakLabel: TextLabel
local busy = false

local function status()
	local p = ClientState.Profile
	return p and p.Daily or { CanClaim = false, Streak = 0, NextIndex = 1 }
end

local function refresh()
	if not gui then
		return
	end
	local st = status()
	streakLabel.Text = st.Streak > 0 and string.format("%d DAY STREAK  •  come back tomorrow to keep it going!", st.Streak)
		or "Log in every day for bigger rewards. Miss a day and the streak resets."
	for i, c in ipairs(dayCards) do
		local claimed = (st.CanClaim and i < st.NextIndex) or (not st.CanClaim and i <= st.NextIndex)
		local today = st.CanClaim and i == st.NextIndex
		c.check.Visible = claimed
		c.stroke.Color = today and Color3.fromRGB(255, 214, 90) or Color3.fromRGB(60, 90, 140)
		c.stroke.Thickness = today and 3 or 1.5
		c.frame.BackgroundColor3 = today and Color3.fromRGB(44, 64, 110) or Color3.fromRGB(22, 36, 64)
	end
	claimButton.Text = st.CanClaim and "CLAIM" or "COME BACK TOMORROW"
	claimButton.BackgroundColor3 = st.CanClaim and Color3.fromRGB(80, 214, 110) or Color3.fromRGB(50, 64, 90)
	claimButton.Active = st.CanClaim
end

function DailyReward.CanClaim(): boolean
	return status().CanClaim == true
end

function DailyReward.Open()
	if gui then
		refresh()
		gui.Enabled = true
	end
end

function DailyReward.Close()
	if gui then
		gui.Enabled = false
	end
end

function DailyReward.Build()
	local g = UIUtil.make("ScreenGui", {
		Name = "PawDaily", Parent = player:WaitForChild("PlayerGui"), IgnoreGuiInset = true,
		ResetOnSpawn = false, DisplayOrder = 30, Enabled = false,
	}) :: ScreenGui
	gui = g
	UIUtil.make("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 10, 24), BackgroundTransparency = 0.35, BorderSizePixel = 0 })
	local card = UIUtil.make("Frame", {
		Parent = g, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(860, 400),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(0, 24), card)
	UIUtil.gradient(Color3.fromRGB(40, 70, 130), Color3.fromRGB(12, 20, 42), 90, card)
	UIUtil.stroke(Color3.fromRGB(255, 214, 90), 2, card).Transparency = 0.4
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local camera = workspace.CurrentCamera
	local function fit()
		local vp = camera.ViewportSize
		scale.Scale = math.min(1, (vp.X - 30) / 860, (vp.Y - 60) / 400)
	end
	fit()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)

	UIUtil.label({ Parent = card, Text = "DAILY REWARDS", Font = Theme.Font.Title, TextSize = 36, TextColor3 = Color3.fromRGB(255, 214, 90), TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 40) })
	streakLabel = UIUtil.label({ Parent = card, Text = "", TextSize = 14, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 18) })
	local close = UIUtil.make("TextButton", {
		Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 14), Size = UDim2.fromOffset(36, 36),
		Text = "X", Font = Theme.Font.Title, TextSize = 18, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Theme.Color.Danger, BorderSizePixel = 0,
	}) :: TextButton
	UIUtil.corner(UDim.new(1, 0), close)
	close.MouseButton1Click:Connect(DailyReward.Close)

	local row = UIUtil.make("Frame", { Parent = card, Position = UDim2.fromOffset(24, 90), Size = UDim2.new(1, -48, 0, 210), BackgroundTransparency = 1 })
	UIUtil.listLayout(row, 10, Enum.FillDirection.Horizontal)
	for i, reward in ipairs(DailyRewards.Days) do
		local big = i == #DailyRewards.Days
		local f = UIUtil.make("Frame", { Parent = row, LayoutOrder = i, Size = UDim2.fromOffset(big and 140 or 100, 210), BackgroundColor3 = Color3.fromRGB(22, 36, 64), BorderSizePixel = 0 }) :: Frame
		UIUtil.corner(UDim.new(0, 16), f)
		local stroke = UIUtil.stroke(Color3.fromRGB(60, 90, 140), 1.5, f)
		UIUtil.label({ Parent = f, Text = "DAY " .. i, Font = Theme.Font.Title, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(1, 0, 0, 20) })
		local art = UIUtil.make("Frame", { Parent = f, Position = UDim2.fromOffset(6, 32), Size = UDim2.new(1, -12, 0, 118), BackgroundTransparency = 1 })
		if big then
			ShopArt.Prop(art, "Gift")
		elseif reward.Gems then
			ShopArt.Prop(art, "Gems", math.clamp(math.floor(reward.Gems / 10), 1, 3))
		else
			ShopArt.Prop(art, "Coins")
		end
		local text = {}
		if reward.Coins then
			table.insert(text, string.format('<font color="#FFD34A">%d</font> COINS', reward.Coins))
		end
		if reward.Gems then
			table.insert(text, string.format('<font color="#E070FF">%d</font> GEMS', reward.Gems))
		end
		local label = UIUtil.label({ Parent = f, Text = table.concat(text, "\n"), RichText = true, Font = Theme.Font.Title, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 154), Size = UDim2.new(1, 0, 0, 40), TextWrapped = true })
		local check = UIUtil.label({
			Parent = f, Text = "CLAIMED", Font = Theme.Font.Title, TextSize = 20, TextColor3 = Color3.fromRGB(110, 240, 140),
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.35,
			BackgroundColor3 = Color3.fromRGB(10, 20, 36), Visible = false, ZIndex = 5,
		})
		UIUtil.corner(UDim.new(0, 16), check)
		table.insert(dayCards, { frame = f, stroke = stroke, check = check, label = label })
	end

	claimButton = UIUtil.make("TextButton", {
		Parent = card, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -20), Size = UDim2.fromOffset(300, 56),
		Text = "CLAIM", Font = Theme.Font.Title, TextSize = 26, TextColor3 = Color3.fromRGB(10, 40, 20), AutoButtonColor = true, BorderSizePixel = 0,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 16), claimButton)
	claimButton.MouseButton1Click:Connect(function()
		if busy or not DailyReward.CanClaim() then
			return
		end
		busy = true
		local ok, res = pcall(function()
			return Remotes.Get("ClaimDaily"):InvokeServer()
		end)
		busy = false
		if ok and typeof(res) == "table" and res.ok then
			claimButton.Text = "CLAIMED!"
			task.delay(1.2, DailyReward.Close)
		end
		refresh()
	end)

	ClientState.ProfileChanged:Connect(refresh)
	refresh()
	return g
end

return DailyReward
