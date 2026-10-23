--!strict
-- Quests: the DAILY TASKS screen. One clean card per task: its name, a thick
-- progress bar with the count, and on the right the coin reward over a
-- button (CLAIM when it's done, a tick once claimed, the progress while it
-- isn't). The time until they reset sits at the top.

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local ClientActions = require(script.Parent.Parent.Parent.ClientActions)

local Quests = {}
local list: ScrollingFrame? = nil
local claiming = false

local GREEN = Color3.fromRGB(90, 210, 100)
local CARD = Color3.fromRGB(22, 28, 44)

local function rebuild()
	local l = list
	if not l then
		return
	end
	for _, c in ipairs(l:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local profile = ClientState.Profile
	if not profile then
		return
	end
	for i, q in ipairs(profile.Quests.Active or {}) do
		local progress, target = tonumber(q.Progress) or 0, math.max(tonumber(q.Target) or 1, 1)
		local done = progress >= target
		local card = UIUtil.make("Frame", {
			Parent = l, LayoutOrder = i, Size = UDim2.new(1, -8, 0, 84), BackgroundColor3 = CARD, BorderSizePixel = 0,
		})
		UIUtil.corner(UDim.new(0, 12), card)
		UIUtil.stroke(done and not q.Claimed and GREEN or Color3.fromRGB(50, 60, 84), done and not q.Claimed and 2 or 1, card)
		UIUtil.label({
			Parent = card, Text = tostring(q.Text), Font = Theme.Font.Title, TextSize = 20, Position = UDim2.fromOffset(18, 12),
			Size = UDim2.new(1, -200, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = q.Claimed and Theme.Color.TextDim or Color3.new(1, 1, 1),
		})
		local track = UIUtil.make("Frame", {
			Parent = card, Position = UDim2.fromOffset(18, 48), Size = UDim2.new(1, -270, 0, 14),
			BackgroundColor3 = Color3.fromRGB(36, 44, 64), BorderSizePixel = 0,
		})
		UIUtil.corner(UDim.new(1, 0), track)
		local fill = UIUtil.make("Frame", {
			Parent = track, Size = UDim2.fromScale(math.clamp(progress / target, 0.02, 1), 1),
			BackgroundColor3 = done and GREEN or Theme.Color.Blue, BorderSizePixel = 0,
		})
		UIUtil.corner(UDim.new(1, 0), fill)
		UIUtil.label({
			Parent = card, Text = string.format("%d / %d", math.min(progress, target), target), Font = Theme.Font.Title, TextSize = 16,
			TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.new(1, -244, 0, 45), Size = UDim2.fromOffset(70, 20),
		})
		-- Right: the reward and the button.
		local reward = UIUtil.make("Frame", {
			Parent = card, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 10), Size = UDim2.fromOffset(150, 24), BackgroundTransparency = 1,
		})
		local rl = UIUtil.listLayout(reward, 6, Enum.FillDirection.Horizontal)
		rl.HorizontalAlignment = Enum.HorizontalAlignment.Right
		rl.VerticalAlignment = Enum.VerticalAlignment.Center
		local coin = UIUtil.make("Frame", { Parent = reward, Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1, LayoutOrder = 1 })
		Icons.Place("Coin", coin, 20, Theme.Color.Coin)
		UIUtil.label({
			Parent = reward, Text = tostring(q.Coins or 0), Font = Theme.Font.Title, TextSize = 18, TextColor3 = Theme.Color.Coin,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), LayoutOrder = 2,
		})
		local btn = UIUtil.make("TextButton", {
			Parent = card, AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -10), Size = UDim2.fromOffset(150, 34),
			Font = Theme.Font.Title, TextSize = 16, TextColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, AutoButtonColor = true,
		}) :: TextButton
		UIUtil.corner(UDim.new(0, 8), btn)
		if q.Claimed then
			btn.Text = "CLAIMED"
			btn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
			btn.TextColor3 = GREEN
			btn.AutoButtonColor = false
		elseif done then
			btn.Text = "CLAIM"
			btn.BackgroundColor3 = GREEN
			btn.MouseButton1Click:Connect(function()
				if claiming then
					return
				end
				claiming = true
				ClientActions.ClaimQuest(q.Id)
				claiming = false
				rebuild()
			end)
		else
			btn.Text = "IN PROGRESS"
			btn.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
			btn.TextColor3 = Theme.Color.TextDim
			btn.AutoButtonColor = false
		end
	end
end

function Quests.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	local reset = UIUtil.label({
		Parent = root, Text = "", Font = Theme.Font.Bold, TextSize = 15, TextColor3 = Theme.Color.TextDim,
		Size = UDim2.new(1, 0, 0, 22),
	})
	task.spawn(function()
		while root.Parent do
			local left = 86400 - os.time() % 86400
			reset.Text = string.format("Complete them in any match to earn coins  ·  new tasks in %dh %02dm", left // 3600, (left % 3600) // 60)
			task.wait(30)
		end
	end)
	local l = UIUtil.make("ScrollingFrame", {
		Parent = root, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 1, -34), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}) :: ScrollingFrame
	UIUtil.listLayout(l, 12)
	list = l
	rebuild()
	ClientState.ProfileChanged:Connect(rebuild)
	Quests.Root = root
	return root
end

return Quests
