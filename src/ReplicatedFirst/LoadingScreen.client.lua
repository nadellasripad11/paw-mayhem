-- LoadingScreen: replaces Roblox's default join screen. A dark blue backdrop
-- with a soft glow, the PAW MAYHEM logo in the middle, our cat mascot peeking
-- up from the bottom left with a speech bubble of tips, and "Loading N%" with
-- a thin bar bottom right. It fades away once the client has built the lobby
-- screen (UIManager sets the CattoLobbyReady attribute).

local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local INK = Color3.fromRGB(20, 26, 52)
local BLUE = Color3.fromRGB(64, 156, 255)
local CREAM = Color3.fromRGB(255, 236, 222)
local PINK = Color3.fromRGB(255, 160, 180)
local WHITE = Color3.new(1, 1, 1)

local TIPS = {
	"The more hits a cat takes, the farther your next shot launches it!",
	"Knock cats off the edge of the map for a RINGOUT.",
	"Step on a duel pad in the lobby to start a 1v1 or 2v2.",
	"Warm up on the target cats in the Practice Dimension.",
	"Press V to switch between first and third person.",
	"Press B during a match to change your loadout.",
	"There's a free gift waiting in the Shop every day.",
	"Finish your daily tasks for bonus coins.",
	"Every weekend is WEEKEND MAYHEM: low gravity and bonus coins!",
}

local function make(class: string, props: { [string]: any }): any
	local inst = Instance.new(class)
	for k, v in pairs(props) do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	inst.Parent = props.Parent
	return inst
end

local function roundCorner(inst: Instance, radius: UDim)
	make("UICorner", { CornerRadius = radius, Parent = inst })
end

local function stroke(inst: Instance, color: Color3, thickness: number, contextual: boolean)
	make("UIStroke", {
		Color = color, Thickness = thickness, LineJoinMode = Enum.LineJoinMode.Round,
		ApplyStrokeMode = contextual and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border, Parent = inst,
	})
end

local gui = make("ScreenGui", {
	Name = "CattoLoading", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
})

local root = make("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = gui })
make("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 58, 120)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(20, 30, 66)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 14, 30)),
	}),
	Rotation = 60, Parent = root,
})

-- A soft glow behind the logo: stacked circles, each fainter and bigger.
local glow = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1, Parent = root,
})
for i = 1, 6 do
	local ring = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.16 * i, 0.16 * i),
		BackgroundColor3 = BLUE, BackgroundTransparency = 0.955, BorderSizePixel = 0, ZIndex = 7 - i, Parent = glow,
	})
	make("UIAspectRatioConstraint", { AspectRatio = 1, Parent = ring })
	roundCorner(ring, UDim.new(1, 0))
end

-- Faint paw prints scattered over the background.
local rng = Random.new(7)
for _ = 1, 16 do
	local s = rng:NextInteger(26, 54)
	local mark = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(rng:NextNumber(0.03, 0.97), rng:NextNumber(0.04, 0.96)),
		Size = UDim2.fromOffset(s, s), Rotation = rng:NextNumber(-40, 40), BackgroundTransparency = 1, Parent = root,
	})
	local pad = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromScale(0.56, 0.46),
		BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, BorderSizePixel = 0, Parent = mark,
	})
	roundCorner(pad, UDim.new(0.5, 0))
	for _, toe in ipairs({ { 0.2, 0.32 }, { 0.4, 0.14 }, { 0.6, 0.14 }, { 0.8, 0.32 } }) do
		local t = make("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(toe[1], toe[2]), Size = UDim2.fromScale(0.22, 0.24),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.94, BorderSizePixel = 0, Parent = mark,
		})
		roundCorner(t, UDim.new(1, 0))
	end
end

-- ── the logo ────────────────────────────────────────────────────────────────
local logo = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(420, 220),
	BackgroundTransparency = 1, Parent = root,
})
local logoScale = make("UIScale", { Parent = logo })

for _, ex in ipairs({ 120, 300 }) do
	local ear = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(ex, 30), Size = UDim2.fromOffset(40, 40), Rotation = 45,
		BackgroundColor3 = WHITE, BorderSizePixel = 0, Parent = logo,
	})
	roundCorner(ear, UDim.new(0, 8))
	stroke(ear, INK, 5, false)
end

local function word(text: string, font: Enum.Font, size: number, y: number, rot: number, strokeColor: Color3, gold: boolean)
	for pass = 1, 2 do
		local l = make("TextLabel", {
			BackgroundTransparency = 1, Text = text, Font = font, TextSize = size,
			TextColor3 = pass == 1 and strokeColor or WHITE, AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, y + (pass == 1 and 8 or 0)), Size = UDim2.fromOffset(420, size + 10),
			Rotation = rot, ZIndex = pass + 1, Parent = logo,
		})
		stroke(l, strokeColor, size > 80 and 7 or 4, true)
		if pass == 2 and gold then
			make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 236, 120), Color3.fromRGB(255, 166, 30)), Rotation = 90, Parent = l })
		end
	end
end
word("PAW", Enum.Font.FredokaOne, 100, 26, 0, INK, false)
word("MAYHEM", Enum.Font.Bangers, 74, 124, -5, Color3.fromRGB(70, 42, 26), true)

-- ── the mascot (bottom left): a cat peeking up, with a tip bubble ──────────
local corner = make("Frame", {
	AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromOffset(560, 260),
	BackgroundTransparency = 1, Parent = root,
})
local cornerScale = make("UIScale", { Parent = corner })

local cat = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0, 120, 1, 40), Size = UDim2.fromOffset(190, 230),
	BackgroundTransparency = 1, Parent = corner,
})
local function blob(x: number, y: number, w: number, h: number, color: Color3, z: number, rot: number?, radius: UDim?): Frame
	local f = make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h),
		BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z, Rotation = rot or 0, Parent = cat,
	})
	roundCorner(f, radius or UDim.new(1, 0))
	return f
end
-- body, then ears behind the head, then the face on top
stroke(blob(95, 200, 170, 120, CREAM, 2, 0, UDim.new(0.45, 0)), INK, 4, false)
for _, side in ipairs({ -1, 1 }) do
	stroke(blob(95 + side * 50, 34, 52, 52, CREAM, 2, 45, UDim.new(0, 10)), INK, 4, false)
	blob(95 + side * 50, 38, 26, 26, PINK, 3, 45, UDim.new(0, 6))
end
stroke(blob(95, 100, 180, 140, CREAM, 4, 0, UDim.new(0.46, 0)), INK, 4, false)
for _, side in ipairs({ -1, 1 }) do
	blob(95 + side * 40, 94, 26, 32, INK, 5)
	blob(95 + side * 40 + 5, 86, 9, 9, WHITE, 6)
	blob(95 + side * 62, 120, 26, 14, PINK, 5).BackgroundTransparency = 0.35
end
blob(95, 114, 14, 9, PINK, 5)
make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(95, 112), Size = UDim2.fromOffset(40, 26),
	BackgroundTransparency = 1, Text = "w", Font = Enum.Font.FredokaOne, TextSize = 26, TextColor3 = INK, ZIndex = 5, Parent = cat,
})
-- a paw raised to wave
local paw = blob(190, 128, 46, 46, CREAM, 6)
stroke(paw, INK, 4, false)

-- The speech bubble, to the right of the cat's head.
local bubble = make("Frame", {
	AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromOffset(240, 110), Size = UDim2.fromOffset(300, 0),
	AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 7, Parent = corner,
})
roundCorner(bubble, UDim.new(0, 16))
make("UIPadding", {
	PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 16), PaddingTop = UDim.new(0, 12), PaddingBottom = UDim.new(0, 12),
	Parent = bubble,
})
local tail = make("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, -16, 0.5, 0), Size = UDim2.fromOffset(20, 20), Rotation = 45,
	BackgroundColor3 = WHITE, BorderSizePixel = 0, ZIndex = 7, Parent = bubble,
})
roundCorner(tail, UDim.new(0, 3))
local tipLabel = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, RichText = true,
	Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = INK, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 8, Parent = bubble,
})
local tipIndex = math.random(1, #TIPS)
local function showTip()
	tipLabel.Text = '<font color="#409CFF">TIP</font>   ' .. TIPS[tipIndex]
end
showTip()

-- ── bottom right: "Loading 42%" over a thin bar ─────────────────────────────
local loadGroup = make("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -36, 1, -30), Size = UDim2.fromOffset(300, 64),
	BackgroundTransparency = 1, Parent = root,
})
local loadScale = make("UIScale", { Parent = loadGroup })
local status = make("TextLabel", {
	Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Font = Enum.Font.FredokaOne, TextSize = 40,
	TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Right, Text = "Loading 0%", Parent = loadGroup,
})
local barBack = make("Frame", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.new(1, 0, 0, 8),
	BackgroundColor3 = WHITE, BackgroundTransparency = 0.82, BorderSizePixel = 0, Parent = loadGroup,
})
roundCorner(barBack, UDim.new(1, 0))
local fill = make("Frame", { Size = UDim2.fromScale(0.02, 1), BackgroundColor3 = BLUE, BorderSizePixel = 0, Parent = barBack })
roundCorner(fill, UDim.new(1, 0))

gui.Parent = player:WaitForChild("PlayerGui")

local function fit()
	local cam = workspace.CurrentCamera
	if cam then
		local s = math.clamp(cam.ViewportSize.Y / 720, 0.6, 1.6)
		logoScale.Scale = s * 1.1
		cornerScale.Scale = s
		loadScale.Scale = s
	end
end
fit()

-- In Studio, surface the first client script error right on this screen so a
-- broken build never just hangs on "Loading".
local isStudio = game:GetService("RunService"):IsStudio()
local firstError: string? = nil
local errorLabel = make("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 40), Size = UDim2.new(0.9, 0, 0, 90),
	BackgroundColor3 = Color3.fromRGB(60, 12, 20), BackgroundTransparency = 0.15, Font = Enum.Font.Code, TextSize = 14,
	TextColor3 = Color3.fromRGB(255, 200, 200), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
	Visible = false, ZIndex = 20, Parent = root,
})
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
local nextTip = started + 4.5
local shown = 0.02
while true do
	local ready = game:IsLoaded() and player:GetAttribute("CattoLobbyReady") == true
	local now = os.clock()
	local elapsed = now - started
	if ready and elapsed > 1.6 then
		break
	end
	if elapsed > 15 then
		if firstError then
			status.Text = "Failed to start"
			return
		end
		break
	end
	local goal = game:IsLoaded() and 0.92 or 0.6
	shown += (goal - shown) * 0.05
	fill.Size = UDim2.fromScale(shown, 1)
	status.Text = string.format("Loading %d%%", math.floor(shown * 100))
	if now >= nextTip then
		nextTip = now + 4.5
		tipIndex = tipIndex % #TIPS + 1
		showTip()
	end
	logo.Rotation = math.sin(elapsed * 2) * 1.2
	cat.Position = UDim2.new(0, 120, 1, 40 + math.sin(elapsed * 3) * 4)
	paw.Rotation = math.sin(elapsed * 6) * 18
	glow.Size = UDim2.fromScale(1 + math.sin(elapsed * 1.5) * 0.04, 1 + math.sin(elapsed * 1.5) * 0.04)
	fit()
	task.wait(1 / 30)
end

status.Text = "Loading 100%"
TweenService:Create(fill, TweenInfo.new(0.25), { Size = UDim2.fromScale(1, 1) }):Play()
task.wait(0.35)
local fade = TweenService:Create(root, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 1 })
fade:Play()
fade.Completed:Wait()
gui:Destroy()
