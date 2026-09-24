--!strict
-- Settings: one full screen, three cards (Gameplay, Controls, Graphics).
-- Every option is live (camera, movement, crosshair, lobby effects, FPS
-- counter) and saved to your profile so it sticks between sessions.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local LobbyScene = require(script.Parent.Parent.Parent.Lobby.LobbyScene)

local Settings = {}

local player = Players.LocalPlayer
local CARD_BG = Color3.fromRGB(22, 38, 68)
local TRACK = Color3.fromRGB(12, 22, 42)
local ON = Color3.fromRGB(96, 214, 120)
local ACCENT = Color3.fromRGB(64, 200, 255)

-- ── saving (debounced) ───────────────────────────────────────────────────────
local pending: { [string]: any } = {}
local saveQueued = false
local function set(key: string, value: any)
	ClientState.UpdateSettings({ [key] = value })
	pending[key] = value
	if not saveQueued then
		saveQueued = true
		task.delay(1, function()
			saveQueued = false
			local patch = pending
			pending = {}
			Remotes.Get("SaveSettings"):FireServer(patch)
		end)
	end
end

-- ── applying settings that aren't read elsewhere ─────────────────────────────
local fpsLabel: TextLabel? = nil
local function applyGlobal()
	local s = ClientState.Settings
	Lighting.GlobalShadows = s.GraphicsQuality ~= "Low"
	pcall(LobbyScene.ApplyQuality, s.GraphicsQuality or "High")
	if fpsLabel then
		fpsLabel.Visible = s.ShowFPS == true
	end
end

local function buildFPS()
	local gui = Instance.new("ScreenGui")
	gui.Name = "PawFPS"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 50
	gui.IgnoreGuiInset = true
	gui.Parent = player:WaitForChild("PlayerGui")
	local label = UIUtil.label({
		Parent = gui, Text = "", Font = Theme.Font.Bold, TextSize = 13, TextColor3 = Color3.fromRGB(150, 255, 170),
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -6), Size = UDim2.fromOffset(80, 18),
		TextXAlignment = Enum.TextXAlignment.Right, TextStrokeTransparency = 0.4, Visible = false,
	})
	fpsLabel = label
	local frames, t0 = 0, os.clock()
	RunService.RenderStepped:Connect(function()
		frames += 1
		local now = os.clock()
		if now - t0 >= 0.5 then
			label.Text = string.format("%d FPS", math.floor(frames / (now - t0) + 0.5))
			frames, t0 = 0, now
		end
	end)
end

-- ── row widgets ──────────────────────────────────────────────────────────────
local function rowFrame(parent: Instance, order: number, label: string, hint: string?): Frame
	local row = UIUtil.make("Frame", { Parent = parent, LayoutOrder = order, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, hint and 58 or 48) }) :: Frame
	UIUtil.label({ Parent = row, Text = label, Font = Theme.Font.Title, TextSize = 18, Size = UDim2.new(0.5, 0, 0, 28), Position = UDim2.fromOffset(0, hint and 4 or 10) })
	if hint then
		UIUtil.label({ Parent = row, Text = hint, TextSize = 12, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(0, 32), Size = UDim2.new(0.55, 0, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
	end
	return row
end

local function toggle(parent: Instance, order: number, label: string, key: string, hint: string?)
	local row = rowFrame(parent, order, label, hint)
	local sw = UIUtil.make("TextButton", {
		Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(64, 32),
		Text = "", AutoButtonColor = false, BorderSizePixel = 0,
	}) :: TextButton
	UIUtil.corner(UDim.new(1, 0), sw)
	local knob = UIUtil.make("Frame", { Parent = sw, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), knob)
	local function paint()
		local on = ClientState.Settings[key] == true
		sw.BackgroundColor3 = on and ON or TRACK
		UIUtil.tween(knob, 0.12, { Position = UDim2.fromScale(on and 0.72 or 0.28, 0.5) })
	end
	sw.MouseButton1Click:Connect(function()
		set(key, not (ClientState.Settings[key] == true))
		paint()
	end)
	paint()
end

local function slider(parent: Instance, order: number, label: string, key: string, lo: number, hi: number, fmt: (number) -> string, hint: string?)
	local row = rowFrame(parent, order, label, hint)
	local valueLabel = UIUtil.label({
		Parent = row, Text = "", Font = Theme.Font.Title, TextSize = 16, TextColor3 = ACCENT, TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(56, 24),
	})
	local track = UIUtil.make("TextButton", {
		Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -66, 0.5, 0), Size = UDim2.new(0.42, 0, 0, 10),
		BackgroundColor3 = TRACK, BorderSizePixel = 0, Text = "", AutoButtonColor = false,
	}) :: TextButton
	UIUtil.corner(UDim.new(1, 0), track)
	local fill = UIUtil.make("Frame", { Parent = track, BackgroundColor3 = ACCENT, BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), fill)
	local knob = UIUtil.make("Frame", { Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(22, 22), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), knob)
	local function paint()
		local v = tonumber(ClientState.Settings[key]) or lo
		local f = math.clamp((v - lo) / (hi - lo), 0, 1)
		fill.Size = UDim2.fromScale(f, 1)
		knob.Position = UDim2.fromScale(f, 0.5)
		valueLabel.Text = fmt(v)
	end
	local dragging = false
	local function setFromX(x: number)
		local f = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
		set(key, lo + (hi - lo) * f)
		paint()
	end
	track.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			setFromX(i.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			setFromX(i.Position.X)
		end
	end)
	paint()
end

local function choice(parent: Instance, order: number, label: string, key: string, options: { string }, colors: { [string]: Color3 }?, hint: string?)
	local row = rowFrame(parent, order, label, hint)
	local holder = UIUtil.make("Frame", {
		Parent = row, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.new(0.5, 0, 0, 34), BackgroundTransparency = 1,
	})
	UIUtil.listLayout(holder, 6, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Right
	local buttons: { [string]: TextButton } = {}
	local function paint()
		for id, b in pairs(buttons) do
			local on = ClientState.Settings[key] == id
			local base = colors and colors[id]
			b.BackgroundColor3 = base or (on and ACCENT or TRACK)
			b.TextColor3 = (on and not base) and Color3.fromRGB(8, 30, 52) or Color3.new(1, 1, 1)
			local st = b:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = on and 0 or 1
			end
		end
	end
	for i, id in ipairs(options) do
		local b = UIUtil.make("TextButton", {
			Parent = holder, LayoutOrder = i, Text = colors and "" or string.upper(id), Font = Theme.Font.Title, TextSize = 14,
			Size = colors and UDim2.fromOffset(34, 34) or UDim2.fromOffset(0, 34), AutomaticSize = colors and Enum.AutomaticSize.None or Enum.AutomaticSize.X,
			AutoButtonColor = true, BorderSizePixel = 0,
		}) :: TextButton
		UIUtil.corner(UDim.new(1, 0), b)
		UIUtil.stroke(Color3.new(1, 1, 1), 2.5, b)
		if not colors then
			local pad = Instance.new("UIPadding")
			pad.PaddingLeft = UDim.new(0, 14)
			pad.PaddingRight = UDim.new(0, 14)
			pad.Parent = b
		end
		b.MouseButton1Click:Connect(function()
			set(key, id)
			paint()
		end)
		buttons[id] = b
	end
	paint()
end

local function cardFn(parent: Instance, order: number, title: string, color: Color3): Frame
	local c = UIUtil.make("Frame", { Parent = parent, LayoutOrder = order, BackgroundColor3 = CARD_BG, BorderSizePixel = 0, Size = UDim2.new(1 / 3, -12, 1, 0) }) :: Frame
	UIUtil.corner(UDim.new(0, 18), c)
	UIUtil.gradient(color:Lerp(CARD_BG, 0.82), CARD_BG, 90, c)
	UIUtil.stroke(color, 1.5, c).Transparency = 0.55
	UIUtil.label({ Parent = c, Text = title, Font = Theme.Font.Title, TextSize = 24, TextColor3 = color, Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 30) })
	local body = UIUtil.make("ScrollingFrame", {
		Parent = c, Position = UDim2.fromOffset(20, 56), Size = UDim2.new(1, -40, 1, -70), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}) :: ScrollingFrame
	UIUtil.listLayout(body, 6)
	return body :: any
end

local function pct(v: number): string
	return string.format("%d%%", math.floor(v * 100 + 0.5))
end

function Settings.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }) :: Frame
	buildFPS()
	ClientState.SettingsChanged:Connect(applyGlobal)
	applyGlobal()

	-- Rows are built the first time the screen opens, so saved values from
	-- the profile are already in place.
	local built = false
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if not root.Visible or built then
			return
		end
		built = true
		-- Wide screens: three cards side by side. Phones: stacked and scrollable.
		local narrow = root.AbsoluteSize.X < 860
		local holder: Instance = root
		if narrow then
			holder = UIUtil.make("ScrollingFrame", {
				Parent = root, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
				ScrollBarThickness = 4, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
			})
			UIUtil.listLayout(holder, 14)
		else
			UIUtil.listLayout(root, 16, Enum.FillDirection.Horizontal)
		end
		local function card(parentIgnored: Instance, order: number, title: string, color: Color3): Frame
			local body = cardFn(holder, order, title, color)
			if narrow then
				(body.Parent :: Frame).Size = UDim2.new(1, -6, 0, 400)
			end
			return body
		end

		local gameplay = card(root, 1, "GAMEPLAY", Color3.fromRGB(255, 170, 70))
		slider(gameplay, -2, "Music", "MusicVolume", 0, 1, pct)
		slider(gameplay, -1, "Sound Effects", "SFXVolume", 0, 1, pct)
		toggle(gameplay, 1, "Auto Sprint", "AutoSprint", "Always run, no button needed")
		toggle(gameplay, 2, "Camera Shake", "CameraShake", "Shake when you're hit or launched")
		toggle(gameplay, 3, "Damage Effects", "ShowDamage", "Red flash when you take damage")
		toggle(gameplay, 4, "Show FPS", "ShowFPS", "Frame rate in the corner")

		local controls = card(root, 2, "CONTROLS", Color3.fromRGB(64, 200, 255))
		slider(controls, 1, "Mouse Sensitivity", "MouseSensitivity", 0, 1, pct)
		slider(controls, 2, "Touch Sensitivity", "MobileSensitivity", 0, 1, pct)
		slider(controls, 3, "Field of View", "FieldOfView", 60, 95, function(v) return tostring(math.floor(v + 0.5)) end)
		toggle(controls, 4, "Invert Camera", "InvertY", "Flip up / down look")

		local graphics = card(root, 3, "GRAPHICS", Color3.fromRGB(190, 120, 255))
		choice(graphics, 1, "Quality", "GraphicsQuality", { "Low", "Medium", "High" }, nil, "Low turns off shadows + effects")
		choice(graphics, 2, "Crosshair", "Crosshair", { "White", "Green", "Cyan", "Pink", "Yellow" }, {
			White = Color3.fromRGB(255, 255, 255), Green = Color3.fromRGB(110, 255, 140), Cyan = Color3.fromRGB(90, 230, 255),
			Pink = Color3.fromRGB(255, 120, 200), Yellow = Color3.fromRGB(255, 230, 90),
		})
	end)

	Settings.Root = root
	return root
end

return Settings
