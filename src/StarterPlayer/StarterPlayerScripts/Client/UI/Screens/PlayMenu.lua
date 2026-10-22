--!strict
-- PlayMenu: the PLAY screen. Big tiles for 1v1, 2v2, 3v3, 4v4 and 5v5
-- duels (pick one and you start searching; bots fill in if nobody else is
-- around) and the ARENA match everyone in the server plays together.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local PlayMenu = {}

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local onArena: (() -> ())? = nil

local TILES = {
	{ kind = "1v1", sub = "Just you and them", colors = { Color3.fromRGB(255, 90, 110), Color3.fromRGB(150, 30, 60) } },
	{ kind = "2v2", sub = "Bring a friend", colors = { Color3.fromRGB(255, 160, 70), Color3.fromRGB(170, 70, 30) } },
	{ kind = "3v3", sub = "Small squads", colors = { Color3.fromRGB(255, 210, 80), Color3.fromRGB(170, 120, 20) } },
	{ kind = "4v4", sub = "Team fights", colors = { Color3.fromRGB(110, 200, 255), Color3.fromRGB(30, 90, 170) } },
	{ kind = "5v5", sub = "Full chaos", colors = { Color3.fromRGB(170, 120, 255), Color3.fromRGB(80, 40, 170) } },
}

local function close()
	if gui then
		gui.Enabled = false
	end
end

function PlayMenu.IsOpen(): boolean
	return gui ~= nil and gui.Enabled
end

function PlayMenu.Open(arena: () -> ())
	onArena = arena
	if gui then
		gui.Enabled = true
	end
end

local function tile(parent: Instance, title: string, sub: string, colors: { Color3 }, order: number, onClick: () -> ())
	local b = UIUtil.make("TextButton", {
		Parent = parent, Name = title, LayoutOrder = order, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 14), b)
	UIUtil.gradient(colors[1], colors[2], 120, b)
	UIUtil.stroke(Color3.new(1, 1, 1), 2, b).Transparency = 0.6
	-- Faint "VS" behind the title.
	UIUtil.label({
		Parent = b, Text = "VS", Font = Theme.Font.Title, TextScaled = true, TextTransparency = 0.85,
		TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.fromScale(0.5, 0.9),
	})
	UIUtil.label({
		Parent = b, Text = title, Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.07, 0.18), Size = UDim2.fromScale(0.8, 0.46), TextStrokeTransparency = 0.5,
	})
	UIUtil.label({
		Parent = b, Text = sub, Font = Theme.Font.Bold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromScale(0.07, 0.66), Size = UDim2.fromScale(0.86, 0.16), TextTransparency = 0.1,
	})
	UIUtil.feedback(b, 1.03)
	b.MouseButton1Click:Connect(onClick)
	return b
end

function PlayMenu.Build()
	local g = UIUtil.make("ScreenGui", {
		Name = "PawPlayMenu", Parent = player:WaitForChild("PlayerGui"), IgnoreGuiInset = true, ResetOnSpawn = false,
		DisplayOrder = 8, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
	gui = g
	local bg = UIUtil.make("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(10, 14, 26), BackgroundTransparency = 0.12, BorderSizePixel = 0 })
	UIUtil.gradient(Color3.fromRGB(24, 40, 70), Color3.fromRGB(8, 10, 20), 90, bg)

	-- Everything sits in a 16:10 box that scales with the screen.
	local box = UIUtil.make("Frame", {
		Parent = g, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.86, 0.8),
		BackgroundTransparency = 1,
	})
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1.75
	ar.Parent = box
	UIUtil.label({
		Parent = box, Text = "PLAY", Font = Theme.Font.Title, TextScaled = true, Size = UDim2.fromScale(0.3, 0.09),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	UIUtil.label({
		Parent = box, Text = "Pick a mode. Nobody around? Bots fill in after 15 seconds.", Font = Theme.Font.Bold, TextScaled = true,
		TextColor3 = Theme.Color.TextDim, Position = UDim2.fromScale(0, 0.09), Size = UDim2.fromScale(0.7, 0.045),
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local x = UIUtil.make("TextButton", {
		Parent = box, Text = "✕", Font = Theme.Font.Bold, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.07, 0.11),
		BackgroundColor3 = Theme.Color.Red, BorderSizePixel = 0,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 10), x)
	x.MouseButton1Click:Connect(close)

	local function join(kind: string)
		close()
		Remotes.Get("DuelQueue"):FireServer({ join = kind })
	end
	-- Top row: 1v1, 2v2, 3v3. Bottom row: 4v4, 5v5 and the arena.
	local rows = { { 1, 2, 3 }, { 4, 5 } }
	for r, list in ipairs(rows) do
		local row = UIUtil.make("Frame", {
			Parent = box, Position = UDim2.fromScale(0, 0.18 + (r - 1) * 0.42), Size = UDim2.fromScale(1, 0.39), BackgroundTransparency = 1,
		})
		local layout = Instance.new("UIListLayout")
		layout.FillDirection = Enum.FillDirection.Horizontal
		layout.Padding = UDim.new(0.015, 0)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = row
		for n, i in ipairs(list) do
			local t = TILES[i]
			local b = tile(row, string.upper(t.kind), t.sub, t.colors, n, function()
				join(t.kind)
			end)
			b.Size = UDim2.fromScale(r == 1 and 0.323 or 0.323, 1)
		end
		if r == 2 then
			local arena = tile(row, "ARENA", "Everyone in the server  ·  vote the map", { Color3.fromRGB(90, 220, 140), Color3.fromRGB(20, 110, 70) }, 3, function()
				close()
				if onArena then
					onArena()
				end
			end)
			arena.Size = UDim2.fromScale(0.323, 1)
		end
	end
end

return PlayMenu
