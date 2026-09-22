--!strict
-- Settings: audio, camera shake, damage flashes, graphics quality, mobile
-- sensitivity. Stored client-side in ClientState (per-session).

local SoundService = game:GetService("SoundService")

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local HeroArt = require(script.Parent.Parent.HeroArt)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)

local Settings = {}

local function sliderRow(parent, label, value, onChange)
	local row = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) })
	UIUtil.label({ Parent = row, Text = label, TextSize = 15, Size = UDim2.new(0, 200, 1, 0) })
	local track = UIUtil.make("Frame", { Parent = row, Position = UDim2.new(0, 210, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.new(1, -220, 0, 8), BackgroundColor3 = Theme.Color.PanelDark, BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), track)
	local fill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(value, 1), BackgroundColor3 = Theme.Color.Accent, BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), fill)
	local knob = UIUtil.button({ Parent = track, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(value, 0.5), Size = UDim2.fromOffset(16, 16), BackgroundColor3 = Color3.fromRGB(255, 255, 255), CornerRadius = UDim.new(1, 0), Text = "" })

	local dragging = false
	local UserInputService = game:GetService("UserInputService")
	knob.MouseButton1Down:Connect(function() dragging = true end)
	UserInputService.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	UserInputService.InputChanged:Connect(function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local rel = math.clamp((i.Position.X - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
			fill.Size = UDim2.fromScale(rel, 1)
			knob.Position = UDim2.fromScale(rel, 0.5)
			onChange(rel)
		end
	end)
end

local function toggleRow(parent, label, value, onChange)
	local row = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) })
	UIUtil.label({ Parent = row, Text = label, TextSize = 15, Size = UDim2.new(0, 200, 1, 0) })
	local sw = UIUtil.button({ Parent = row, Position = UDim2.new(0, 210, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(52, 26), BackgroundColor3 = value and Theme.Color.Success or Theme.Color.PanelDark, CornerRadius = UDim.new(1, 0), Text = "" })
	local knob = UIUtil.make("Frame", { Parent = sw, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(value and 0.75 or 0.25, 0.5), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Color3.fromRGB(255, 255, 255), BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), knob)
	local state = value
	sw.MouseButton1Click:Connect(function()
		state = not state
		sw.BackgroundColor3 = state and Theme.Color.Success or Theme.Color.PanelDark
		UIUtil.tween(knob, 0.12, { Position = UDim2.fromScale(state and 0.75 or 0.25, 0.5) })
		onChange(state)
	end)
end

function Settings.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	HeroArt.Watermark(root)
	local panel = UIUtil.panel({ Parent = root, Size = UDim2.new(0, 520, 1, 0), BackgroundColor3 = Theme.Color.PanelDark })
	UIUtil.padding(16, panel)
	UIUtil.listLayout(panel, 6)
	local header = UIUtil.make("Frame", { Parent = panel, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 28) })
	local gearSlot = UIUtil.make("Frame", { Parent = header, Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1 })
	Icons.Place("Gear", gearSlot, 20, Theme.Color.TextDim)
	UIUtil.label({ Parent = header, Text = "SETTINGS", Font = Theme.Font.Heading, TextSize = 18, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 1, 0) })

	local s = ClientState.Settings
	sliderRow(panel, "Music Volume", s.MusicVolume, function(v) ClientState.UpdateSettings({ MusicVolume = v }) end)
	sliderRow(panel, "SFX Volume", s.SFXVolume, function(v) ClientState.UpdateSettings({ SFXVolume = v }) end)
	toggleRow(panel, "Camera Shake", s.CameraShake, function(v) ClientState.UpdateSettings({ CameraShake = v }) end)
	toggleRow(panel, "Show Damage Effects", s.ShowDamage, function(v) ClientState.UpdateSettings({ ShowDamage = v }) end)
	sliderRow(panel, "Mobile Sensitivity", s.MobileSensitivity, function(v) ClientState.UpdateSettings({ MobileSensitivity = v }) end)

	-- graphics quality selector
	local gq = UIUtil.make("Frame", { Parent = panel, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40) })
	UIUtil.label({ Parent = gq, Text = "Graphics Quality", TextSize = 15, Size = UDim2.new(0, 200, 1, 0) })
	local options = { "Low", "Medium", "High" }
	local idx = 3
	local qlabel = UIUtil.label({ Parent = gq, Text = "High", TextXAlignment = Enum.TextXAlignment.Center, Font = Theme.Font.Bold, TextSize = 15, Position = UDim2.new(0, 250, 0, 0), Size = UDim2.fromOffset(120, 40) })
	UIUtil.button({ Parent = gq, Position = UDim2.new(0, 210, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(34, 30), BackgroundColor3 = Theme.Color.PanelLight, Text = "‹" }, function()
		idx = math.max(1, idx - 1); qlabel.Text = options[idx]; ClientState.UpdateSettings({ GraphicsQuality = options[idx] })
	end)
	UIUtil.button({ Parent = gq, Position = UDim2.new(0, 376, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Size = UDim2.fromOffset(34, 30), BackgroundColor3 = Theme.Color.PanelLight, Text = "›" }, function()
		idx = math.min(#options, idx + 1); qlabel.Text = options[idx]; ClientState.UpdateSettings({ GraphicsQuality = options[idx] })
	end)

	Settings.Root = root
	return root
end

return Settings
