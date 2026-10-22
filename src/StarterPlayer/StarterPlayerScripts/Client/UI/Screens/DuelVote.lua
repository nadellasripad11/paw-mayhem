--!strict
-- DuelVote: once a duel is found, everyone in it votes - first the map, then
-- the gamemode. A timer at the top, a big card per option with its votes;
-- click one to vote (you can change your mind until the time's up).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local DuelVote = {}

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local endsAt = 0

local COLORS = {
	Color3.fromRGB(90, 200, 120), Color3.fromRGB(110, 170, 255), Color3.fromRGB(255, 160, 80),
	Color3.fromRGB(190, 130, 255), Color3.fromRGB(255, 110, 130),
}

function DuelVote.IsOpen(): boolean
	return gui ~= nil and gui.Enabled
end

function DuelVote.Build()
	local g = UIUtil.make("ScreenGui", {
		Name = "PawDuelVote", Parent = player:WaitForChild("PlayerGui"), IgnoreGuiInset = true, ResetOnSpawn = false,
		DisplayOrder = 9, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
	gui = g
	local bg = UIUtil.make("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 14, 26), BackgroundTransparency = 0.1, BorderSizePixel = 0 })
	UIUtil.gradient(Color3.fromRGB(20, 60, 40), Color3.fromRGB(8, 14, 12), 90, bg)
	local box = UIUtil.make("Frame", {
		Parent = g, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromScale(0.86, 0.78),
		BackgroundTransparency = 1,
	})
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1.8
	ar.Parent = box

	local timerPill = UIUtil.label({
		Parent = g, Text = "", Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 10), Size = UDim2.fromScale(0.14, 0.07),
		BackgroundTransparency = 0.1, BackgroundColor3 = Color3.fromRGB(12, 14, 20),
	})
	UIUtil.corner(UDim.new(0, 10), timerPill)
	local title = UIUtil.label({
		Parent = box, Text = "", Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 0.1),
	})
	local sub = UIUtil.label({
		Parent = box, Text = "", Font = Theme.Font.Bold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = Theme.Color.TextDim, Position = UDim2.fromScale(0, 0.11), Size = UDim2.fromScale(1, 0.05),
	})
	local grid = UIUtil.make("Frame", { Parent = box, Position = UDim2.fromScale(0, 0.22), Size = UDim2.fromScale(1, 0.78), BackgroundTransparency = 1 })

	local function paint(data: any)
		for _, c in ipairs(grid:GetChildren()) do
			c:Destroy()
		end
		local stage = data.stage
		title.Text = stage == "Map" and "PICK A MAP" or "PICK A GAMEMODE"
		sub.Text = string.upper(tostring(data.kind or "")) .. "  ·  match found!"
		local options = data.options or {}
		local n = #options
		local cols = n <= 3 and n or math.ceil(n / 2)
		local rows = math.ceil(n / cols)
		for i, o in ipairs(options) do
			local col = (i - 1) % cols
			local row = (i - 1) // cols
			local mine = data.myVote == o.id
			local color = COLORS[(i - 1) % #COLORS + 1]
			local b = UIUtil.make("TextButton", {
				Parent = grid, Text = "", AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1),
				Position = UDim2.fromScale(col / cols + 0.005, row / rows + 0.01), Size = UDim2.fromScale(1 / cols - 0.01, 1 / rows - 0.02),
			}) :: TextButton
			UIUtil.corner(UDim.new(0, 12), b)
			UIUtil.gradient(color:Lerp(Color3.new(1, 1, 1), 0.1), color:Lerp(Color3.new(0, 0, 0), 0.55), 90, b)
			local st = UIUtil.stroke(mine and Color3.fromRGB(120, 255, 140) or Color3.new(1, 1, 1), mine and 4 or 1.5, b)
			st.Transparency = mine and 0 or 0.6
			-- Diagonal stripes along the bottom (like a hazard band).
			local band = UIUtil.make("Frame", {
				Parent = b, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.28),
				BackgroundColor3 = Color3.fromRGB(10, 12, 16), BackgroundTransparency = 0.25, BorderSizePixel = 0,
			})
			UIUtil.corner(UDim.new(0, 12), band)
			UIUtil.label({
				Parent = band, Text = tostring(o.name), Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
				Position = UDim2.fromScale(0.05, 0.08), Size = UDim2.fromScale(0.9, 0.6),
			})
			if o.desc then
				UIUtil.label({
					Parent = b, Text = tostring(o.desc), Font = Theme.Font.Bold, TextScaled = true, TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromScale(0.08, 0.28), Size = UDim2.fromScale(0.84, 0.3),
				})
			end
			local count = data.votes and data.votes[o.id] or 0
			if count > 0 then
				local badge = UIUtil.label({
					Parent = b, Text = tostring(count), Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
					AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(34, 34),
					BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(70, 200, 100),
				})
				UIUtil.corner(UDim.new(1, 0), badge)
			end
			if mine then
				UIUtil.label({
					Parent = b, Text = "✔", Font = Theme.Font.Title, TextScaled = true, TextColor3 = Color3.fromRGB(120, 255, 140),
					Position = UDim2.new(0, 8, 0, 6), Size = UDim2.fromOffset(34, 34),
				})
			end
			UIUtil.feedback(b, 1.03)
			b.MouseButton1Click:Connect(function()
				Remotes.Get("DuelVote"):FireServer({ choice = o.id })
			end)
		end
	end

	Remotes.Get("DuelVote").OnClientEvent:Connect(function(data)
		if typeof(data) ~= "table" or type(data.stage) ~= "string" then
			g.Enabled = false
			return
		end
		endsAt = tonumber(data.endsAt) or 0
		paint(data)
		g.Enabled = true
	end)
	task.spawn(function()
		while g.Parent do
			if g.Enabled then
				timerPill.Text = string.format("⌛ %.1f", math.max(0, endsAt - Workspace:GetServerTimeNow()))
			end
			task.wait(0.1)
		end
	end)
end

return DuelVote
