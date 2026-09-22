--!strict
-- UIManager: builds the screens and switches between lobby / HUD / results based
-- on the match phase, and enables the camera + combat controllers only while the
-- local cat is alive in a live match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local UIUtil = require(script.Parent.UIUtil)
local ClientState = require(script.Parent.Parent.ClientState)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local MainMenu = require(script.Parent.Screens.MainMenu)
local HUD = require(script.Parent.Screens.HUD)
local Results = require(script.Parent.Screens.Results)

local CameraController = require(script.Parent.Parent.Controllers.CameraController)
local CombatController = require(script.Parent.Parent.Controllers.CombatController)

local UIManager = {}
local player = Players.LocalPlayer
local lastPhase = nil
local alive = false
local transitionFrame: Frame? = nil
local fallbackGui: ScreenGui? = nil

-- A real, clickable launch surface kept outside the large decorative menu.
-- If a future art/card change ever fails during startup, players still get
-- the intended landing -> map choice -> countdown flow instead of a blank UI.
local function buildFallbackLanding()
	if fallbackGui then
		fallbackGui.Enabled = true
		return
	end

	fallbackGui = UIUtil.make("ScreenGui", {
		Name = "PawFallbackLanding",
		Parent = player:WaitForChild("PlayerGui"),
		IgnoreGuiInset = true,
		ResetOnSpawn = false,
		DisplayOrder = 90,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui

	local backdrop = UIUtil.make("Frame", {
		Parent = fallbackGui,
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(74, 164, 224),
		BorderSizePixel = 0,
	}) :: Frame
	UIUtil.gradient(Color3.fromRGB(143, 218, 255), Color3.fromRGB(36, 91, 166), 90, backdrop)

	local card = UIUtil.panel({
		Parent = backdrop,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(650, 430),
		BackgroundColor3 = Theme.Color.PanelDark,
	})
	UIUtil.padding(28, card)
	UIUtil.label({ Parent = card, Text = "CATTO", Font = Theme.Font.Title, TextSize = 68, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 82), TextStrokeTransparency = 0.55 })
	UIUtil.label({ Parent = card, Text = "PEW PEW!", Font = Theme.Font.Title, TextSize = 34, TextColor3 = Theme.Color.Coin, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 42) })
	UIUtil.label({ Parent = card, Text = "Choose an arena to start the match", TextColor3 = Theme.Color.TextDim, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 126), Size = UDim2.new(1, 0, 0, 24) })

	local status = UIUtil.label({ Parent = card, Text = "MAP SELECT", Font = Theme.Font.Bold, TextColor3 = Theme.Color.Accent, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 160), Size = UDim2.new(1, 0, 0, 20) })
	local maps = {
		{ id = "SkyIslands", name = "SKY ISLANDS", color = Color3.fromRGB(45, 160, 239) },
		{ id = "Volcano", name = "VOLCANO", color = Color3.fromRGB(221, 84, 64) },
		{ id = "Toybox", name = "TOYBOX", color = Color3.fromRGB(216, 99, 176) },
	}
	local row = UIUtil.make("Frame", { Parent = card, Position = UDim2.fromOffset(0, 196), Size = UDim2.new(1, 0, 0, 74), BackgroundTransparency = 1 }) :: Frame
	UIUtil.listLayout(row, 12, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Center
	for _, map in ipairs(maps) do
		local chosen = map
		local button = UIUtil.button({ Parent = row, Size = UDim2.fromOffset(174, 68), BackgroundColor3 = chosen.color, Text = chosen.name, Font = Theme.Font.Title, TextSize = 15, CornerRadius = Theme.CornerSmall }, function()
			status.Text = "LOADING " .. chosen.name .. "..."
			Remotes.Get("RequestJoinMatch"):FireServer({ mapId = chosen.id })
		end)
		button.TextWrapped = true
	end
	UIUtil.label({ Parent = card, Text = "Team Deathmatch  •  3 maps  •  Pick a map, then drop in", TextColor3 = Theme.Color.TextMuted, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 292), Size = UDim2.new(1, 0, 0, 22) })
end

local function playTransition()
	if not transitionFrame then return end
	transitionFrame.BackgroundTransparency = 0.02
	TweenService:Create(transitionFrame, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
end

local function buildTransitionLayer()
	local fadeGui = Instance.new("ScreenGui")
	fadeGui.Name = "PawTransition"
	fadeGui.IgnoreGuiInset = true
	fadeGui.ResetOnSpawn = false
	fadeGui.DisplayOrder = 100
	fadeGui.Parent = player:WaitForChild("PlayerGui")
	transitionFrame = Instance.new("Frame")
	transitionFrame.Size = UDim2.fromScale(1, 1)
	transitionFrame.BackgroundColor3 = Theme.Color.Bg
	transitionFrame.BackgroundTransparency = 1
	transitionFrame.BorderSizePixel = 0
	transitionFrame.Parent = fadeGui
end

local function enableGameplay(on: boolean)
	CameraController.SetEnabled(on)
	CombatController.SetEnabled(on)
end

local function onCharacter(char)
	alive = true
	-- wait a beat for parts to settle
	task.wait(0.2)
	if ClientState.Match.phase == "Playing" then
		enableGameplay(true)
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			alive = false
			enableGameplay(false)
		end)
	end
end

local function onPhase(m)
	local phase = m.phase
	if phase == lastPhase then
		-- still update sub-states (e.g. countdown numbers handled by screens)
		if phase == "Countdown" then
			HUD.ShowBig(tostring(m.timeLeft or 0), Theme.Color.Text)
		end
		return
	end
	lastPhase = phase
	playTransition()

	if phase == "Intermission" then
		MainMenu.SetVisible(true)
		if fallbackGui then fallbackGui.Enabled = true end
		HUD.SetVisible(false)
		Results.Hide()
		enableGameplay(false)
	elseif phase == "Countdown" then
		MainMenu.SetVisible(false)
		if fallbackGui then fallbackGui.Enabled = false end
		HUD.SetVisible(true)
		Results.Hide()
		HUD.ShowBig("GET READY", Theme.Color.Warn)
		enableGameplay(false)
	elseif phase == "Playing" then
		MainMenu.SetVisible(false)
		if fallbackGui then fallbackGui.Enabled = false end
		HUD.SetVisible(true)
		Results.Hide()
		HUD.HideBig()
		if alive then
			enableGameplay(true)
		end
	elseif phase == "Results" then
		if fallbackGui then fallbackGui.Enabled = false end
		HUD.SetVisible(false)
		enableGameplay(false)
		Results.Show(m)
	end
end

function UIManager.Start()
	local menuOk, menuErr = pcall(MainMenu.Build)
	if not menuOk then
		warn("[PAW MAYHEM] Main menu failed to build; using launch fallback: " .. tostring(menuErr))
		buildFallbackLanding()
	end
	local hudOk, hudErr = pcall(HUD.Build)
	if not hudOk then
		warn("[PAW MAYHEM] HUD failed to build: " .. tostring(hudErr))
	end
	local resultsOk, resultsErr = pcall(Results.Build)
	if not resultsOk then
		warn("[PAW MAYHEM] Results screen failed to build: " .. tostring(resultsErr))
	end
	buildTransitionLayer()

	ClientState.MatchChanged:Connect(onPhase)

	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		task.spawn(onCharacter, char)
	end)
	player.CharacterRemoving:Connect(function()
		alive = false
		enableGameplay(false)
	end)

	-- apply current state on start
	onPhase(ClientState.Match)
end

return UIManager
