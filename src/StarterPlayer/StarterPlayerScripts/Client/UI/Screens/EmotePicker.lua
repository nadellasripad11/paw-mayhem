--!strict
-- EmotePicker: a small window of the emotes you own (tap one to play it).
-- Opened by the EMOTES button in the lobby's top right and by the emote
-- button in the phone controls during a match; X or picking one closes it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cats = require(ReplicatedStorage.Shared.Config.Cats)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)

local EmotePicker = {}

local ICON = {
	Happy = "Smiley", Sit = "SitDown", Wave = "Wave", Laugh = "Laugh", Celebrate = "Burst", Sleep = "Sleep", Spin = "Spin", Fall = "Fall",
	Loaf = "CatBody", Knead = "Paw", Purr = "Smiley", Hiss = "Burst", Taunt = "Laugh", Zoomies = "Dash", BoxSit = "SitDown",
	Dance = "Sparkle", Flex = "Bolt",
}

local gui: ScreenGui? = nil
local grid: Frame? = nil

local function close()
	if gui then
		gui.Enabled = false
	end
end

local function fill()
	local g = grid
	if not g then
		return
	end
	for _, c in ipairs(g:GetChildren()) do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	local order = 0
	for _, e in ipairs(Cats.Emotes) do
		if ClientState.Owns("Emote", e.Id) then
			order += 1
			local b = UIUtil.make("TextButton", {
				Parent = g, LayoutOrder = order, Text = "", AutoButtonColor = true, BorderSizePixel = 0,
				BackgroundColor3 = Color3.fromRGB(30, 38, 58),
			}) :: TextButton
			UIUtil.corner(UDim.new(0, 10), b)
			local slot = UIUtil.make("Frame", { Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(34, 34), BackgroundTransparency = 1 })
			Icons.Place(ICON[e.Id] or "Smiley", slot, 34, Color3.new(1, 1, 1))
			UIUtil.label({
				Parent = b, Text = e.Name, Font = Theme.Font.Bold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -6, 0, 14),
			})
			b.MouseButton1Click:Connect(function()
				close()
				require(script.Parent.Parent.Parent.Controllers.EmoteController).Play(e.Id)
			end)
		end
	end
end

function EmotePicker.Toggle()
	if not gui then
		return
	end
	if gui.Enabled then
		close()
	else
		fill()
		gui.Enabled = true
	end
end

function EmotePicker.Build()
	local g = UIUtil.make("ScreenGui", {
		Name = "PawEmotes", Parent = Players.LocalPlayer:WaitForChild("PlayerGui"), IgnoreGuiInset = true, ResetOnSpawn = false,
		DisplayOrder = 12, Enabled = false,
	}) :: ScreenGui
	gui = g
	local panel = UIUtil.make("Frame", {
		Parent = g, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(420, 300),
		BackgroundColor3 = Color3.fromRGB(16, 20, 32), BackgroundTransparency = 0.05, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(0, 14), panel)
	UIUtil.stroke(Color3.fromRGB(70, 90, 130), 1.5, panel)
	local sc = Instance.new("UIScale")
	sc.Parent = panel
	local cam = workspace.CurrentCamera
	local function fit()
		sc.Scale = math.clamp(cam.ViewportSize.Y / 640, 0.7, 1.4)
	end
	fit()
	cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	UIUtil.label({ Parent = panel, Text = "EMOTES", Font = Theme.Font.Title, TextSize = 22, Position = UDim2.fromOffset(16, 10), Size = UDim2.fromOffset(200, 28) })
	local x = UIUtil.make("TextButton", {
		Parent = panel, Text = "X", Font = Theme.Font.Title, TextSize = 22, TextColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(34, 34),
		BackgroundTransparency = 1, BorderSizePixel = 0,
	}) :: TextButton
	x.MouseButton1Click:Connect(close)
	local gr = UIUtil.make("ScrollingFrame", {
		Parent = panel, Position = UDim2.fromOffset(12, 48), Size = UDim2.new(1, -24, 1, -60), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}) :: ScrollingFrame
	UIUtil.gridLayout(gr, UDim2.fromOffset(88, 74), UDim2.fromOffset(8, 8))
	grid = gr
end

return EmotePicker
