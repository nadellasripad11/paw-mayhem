-- LoadingScreen: replaces Roblox's default join screen with the Catto Pew Pew
-- logo over a sky gradient and a loading bar, then fades away once the client
-- has built the 3D home screen (UIManager sets the CattoLobbyReady attribute).

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local NAVY = Color3.fromRGB(28, 40, 84)

local gui = Instance.new("ScreenGui")
gui.Name = "CattoLoading"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local root = Instance.new("CanvasGroup")
root.Size = UDim2.fromScale(1, 1)
root.BackgroundColor3 = Color3.new(1, 1, 1)
root.BorderSizePixel = 0
root.Parent = gui
local sky = Instance.new("UIGradient")
sky.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(96, 176, 255)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(160, 214, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(214, 238, 255)),
})
sky.Rotation = 90
sky.Parent = root

local function roundCorner(inst: Instance, radius: UDim)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius
	c.Parent = inst
end

local function stroke(inst: Instance, color: Color3, thickness: number, contextual: boolean)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.ApplyStrokeMode = contextual and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	s.Parent = inst
end

-- soft cloud puffs
for i, spec in ipairs({ { 0.12, 0.78, 260 }, { 0.3, 0.86, 200 }, { 0.72, 0.8, 300 }, { 0.9, 0.9, 220 }, { 0.55, 0.95, 280 } }) do
	local puff = Instance.new("Frame")
	puff.AnchorPoint = Vector2.new(0.5, 0.5)
	puff.Position = UDim2.fromScale(spec[1], spec[2])
	puff.Size = UDim2.fromOffset(spec[3], spec[3] * 0.45)
	puff.BackgroundColor3 = Color3.new(1, 1, 1)
	puff.BackgroundTransparency = 0.15 + i * 0.04
	puff.BorderSizePixel = 0
	puff.Parent = root
	roundCorner(puff, UDim.new(1, 0))
end

local logo = Instance.new("Frame")
logo.AnchorPoint = Vector2.new(0.5, 0.5)
logo.Position = UDim2.fromScale(0.5, 0.42)
logo.Size = UDim2.fromOffset(360, 190)
logo.BackgroundTransparency = 1
logo.Parent = root
local scale = Instance.new("UIScale")
scale.Parent = logo

for _, ex in ipairs({ 104, 298 }) do
	local ear = Instance.new("Frame")
	ear.AnchorPoint = Vector2.new(0.5, 0.5)
	ear.Position = UDim2.fromOffset(ex, 30)
	ear.Size = UDim2.fromOffset(34, 34)
	ear.Rotation = 45
	ear.BackgroundColor3 = Color3.new(1, 1, 1)
	ear.BorderSizePixel = 0
	ear.Parent = logo
	roundCorner(ear, UDim.new(0, 7))
	stroke(ear, NAVY, 4, false)
end

local function word(text: string, font: Enum.Font, size: number, y: number, rot: number, strokeColor: Color3, gold: boolean)
	for pass = 1, 2 do
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Text = text
		l.Font = font
		l.TextSize = size
		l.TextColor3 = pass == 1 and strokeColor or Color3.new(1, 1, 1)
		l.AnchorPoint = Vector2.new(0.5, 0)
		l.Position = UDim2.new(0.5, 0, 0, y + (pass == 1 and 7 or 0))
		l.Size = UDim2.fromOffset(360, size + 10)
		l.Rotation = rot
		l.ZIndex = pass + 1
		l.Parent = logo
		stroke(l, strokeColor, size > 80 and 6 or 3.5, true)
		if pass == 2 and gold then
			local g = Instance.new("UIGradient")
			g.Color = ColorSequence.new(Color3.fromRGB(255, 236, 120), Color3.fromRGB(255, 166, 30))
			g.Rotation = 90
			g.Parent = l
		end
	end
end
word("CATTO", Enum.Font.FredokaOne, 100, 22, 0, NAVY, false)
word("PEW PEW!", Enum.Font.Bangers, 62, 112, -5, Color3.fromRGB(70, 42, 26), true)

local barBack = Instance.new("Frame")
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.Position = UDim2.fromScale(0.5, 0.7)
barBack.Size = UDim2.fromOffset(340, 20)
barBack.BackgroundColor3 = NAVY
barBack.BackgroundTransparency = 0.35
barBack.BorderSizePixel = 0
barBack.Parent = root
roundCorner(barBack, UDim.new(1, 0))
stroke(barBack, Color3.new(1, 1, 1), 2, false)
local fill = Instance.new("Frame")
fill.Size = UDim2.fromScale(0.04, 1)
fill.BackgroundColor3 = Color3.new(1, 1, 1)
fill.BorderSizePixel = 0
fill.Parent = barBack
roundCorner(fill, UDim.new(1, 0))
local fillGrad = Instance.new("UIGradient")
fillGrad.Color = ColorSequence.new(Color3.fromRGB(150, 236, 90), Color3.fromRGB(60, 176, 56))
fillGrad.Rotation = 90
fillGrad.Parent = fill

local status = Instance.new("TextLabel")
status.AnchorPoint = Vector2.new(0.5, 0)
status.Position = UDim2.new(0.5, 0, 0.7, 20)
status.Size = UDim2.fromOffset(400, 30)
status.BackgroundTransparency = 1
status.Font = Enum.Font.FredokaOne
status.TextSize = 20
status.TextColor3 = Color3.new(1, 1, 1)
status.Text = "Loading..."
status.Parent = root
stroke(status, NAVY, 2, true)

local tip = Instance.new("TextLabel")
tip.AnchorPoint = Vector2.new(0.5, 1)
tip.Position = UDim2.new(0.5, 0, 1, -28)
tip.Size = UDim2.new(0.8, 0, 0, 24)
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.GothamBold
tip.TextSize = 15
tip.TextColor3 = NAVY
tip.Text = "Tip: the more hits a cat takes, the farther your next shot launches it!"
tip.TextWrapped = true
tip.Parent = root

gui.Parent = player:WaitForChild("PlayerGui")

local function fit()
	local cam = workspace.CurrentCamera
	if cam then
		scale.Scale = math.clamp(cam.ViewportSize.Y / 640, 0.7, 1.6)
	end
end
fit()

-- In Studio, surface the first client script error right on this screen so a
-- broken build never just hangs on "Loading...".
local isStudio = game:GetService("RunService"):IsStudio()
local firstError: string? = nil
local errorLabel = Instance.new("TextLabel")
errorLabel.AnchorPoint = Vector2.new(0.5, 1)
errorLabel.Position = UDim2.new(0.5, 0, 1, -60)
errorLabel.Size = UDim2.new(0.9, 0, 0, 90)
errorLabel.BackgroundColor3 = Color3.fromRGB(60, 12, 20)
errorLabel.BackgroundTransparency = 0.15
errorLabel.Font = Enum.Font.Code
errorLabel.TextSize = 14
errorLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
errorLabel.TextWrapped = true
errorLabel.TextXAlignment = Enum.TextXAlignment.Left
errorLabel.Visible = false
errorLabel.Parent = root
roundCorner(errorLabel, UDim.new(0, 8))
game:GetService("ScriptContext").Error:Connect(function(message, trace)
	if firstError or not isStudio then
		return
	end
	firstError = message
	errorLabel.Text = "  Client error (Studio only):\n  " .. message .. "\n  " .. (string.split(trace or "", "\n")[1] or "")
	errorLabel.Visible = true
end)

local started = os.clock()
local shown = 0.04
local dots = 0
while true do
	local ready = game:IsLoaded() and player:GetAttribute("CattoLobbyReady") == true
	local elapsed = os.clock() - started
	if ready and elapsed > 1.6 then
		break
	end
	if elapsed > 15 then
		if firstError then
			status.Text = "Home screen failed to start — error below"
			return
		end
		break
	end
	local goal = game:IsLoaded() and 0.9 or 0.6
	shown += (goal - shown) * 0.06
	fill.Size = UDim2.fromScale(shown, 1)
	dots = (dots + 1) % 24
	status.Text = "Loading" .. string.rep(".", math.floor(dots / 6) + 1)
	logo.Rotation = math.sin(elapsed * 2) * 1.5
	fit()
	task.wait(1 / 30)
end

status.Text = "Let's go!"
TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(1, 1) }):Play()
task.wait(0.35)
local fade = TweenService:Create(root, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 1 })
fade:Play()
fade.Completed:Wait()
gui:Destroy()
