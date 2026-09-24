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
local LobbyScene = require(script.Parent.Parent.Lobby.LobbyScene)

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
	UIUtil.label({ Parent = card, Text = "PAW", Font = Theme.Font.Title, TextSize = 68, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 82), TextStrokeTransparency = 0.55 })
	UIUtil.label({ Parent = card, Text = "MAYHEM", Font = Theme.Font.Title, TextSize = 34, TextColor3 = Theme.Color.Coin, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 42) })
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
	CameraController.SetLobbyView(not on)
	CameraController.SetEnabled(on)
	CombatController.SetEnabled(on)
end

local function onCharacter(char)
	alive = true
	CameraController.SetSpectate(nil)
	-- wait a beat for parts to settle
	task.wait(0.2)
	if ClientState.Match.phase == "Playing" then
		MainMenu.SetVisible(false)
		HUD.SetVisible(true)
		Results.Hide()
		enableGameplay(true)
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Died:Connect(function()
			alive = false
			-- Stay in the arena for the kill-cam (no lobby view while dead).
			CameraController.SetEnabled(false)
			CombatController.SetEnabled(false)
		end)
	end
end

-- Camera shot of the winners' podium, sent by the server at match end.
local podiumShot: CFrame? = nil

local function onPhase(m)
	local phase = m.phase
	if phase == lastPhase then
		-- still update sub-states (e.g. countdown numbers handled by screens)
		if phase == "Countdown" then
			HUD.ShowBig(tostring(m.timeLeft or 0), Theme.Color.Text)
		elseif phase == "Results" then
			Results.Update(m)
		end
		return
	end
	lastPhase = phase
	playTransition()
	if phase ~= "Results" then
		podiumShot = nil
		CameraController.SetShowcase(nil)
	end
	if phase ~= "Playing" then
		CameraController.SetSpectate(nil)
	end

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
		if alive then
			MainMenu.SetVisible(false)
			if fallbackGui then fallbackGui.Enabled = false end
			HUD.SetVisible(true)
			Results.Hide()
			HUD.HideBig()
			enableGameplay(true)
		else
			-- The server intentionally waits for the player's Play click when
			-- they join a live round. Keep the landing/map picker visible.
			MainMenu.SetVisible(true)
			if fallbackGui then fallbackGui.Enabled = true end
			HUD.SetVisible(false)
			Results.Hide()
			enableGameplay(false)
		end
	elseif phase == "Results" then
		if fallbackGui then fallbackGui.Enabled = false end
		HUD.SetVisible(false)
		enableGameplay(false)
		if podiumShot then
			CameraController.SetLobbyView(false)
			CameraController.SetShowcase(podiumShot)
		end
		Results.Show(m)
	end
end

function UIManager.Start()
	task.spawn(require(script.Parent.UIJuice).Start)
	-- Kill-cam: watch whoever eliminated you.
	Remotes.Get("Eliminated").OnClientEvent:Connect(function(data)
		local by = typeof(data) == "table" and data.by or nil
		local target: Model? = nil
		for _, p in ipairs(Players:GetPlayers()) do
			if p.DisplayName == by and p.Character then
				target = p.Character
			end
		end
		if not target and typeof(by) == "string" then
			local m = workspace:FindFirstChild(by)
			target = m and m:IsA("Model") and m or nil
		end
		CameraController.SetSpectate(target)
		if target then
			HUD.Announce({ title = "KNOCKED OUT BY " .. string.upper(tostring(by)), sub = "Spectating until you respawn", small = true, color = Color3.fromRGB(255, 120, 120) })
		end
	end)
	Remotes.Get("Podium").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and typeof(data.camera) == "CFrame" then
			podiumShot = data.camera
			if ClientState.Match.phase == "Results" then
				CameraController.SetLobbyView(false)
				CameraController.SetShowcase(podiumShot)
			end
		end
	end)
	local sceneOk, sceneErr = pcall(LobbyScene.Build)
	if not sceneOk then
		warn("[PAW MAYHEM] Lobby scene failed to build: " .. tostring(sceneErr))
	end
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
	CameraController.SetLobbyView(true)

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

	-- Tells the ReplicatedFirst loading screen the home screen is ready.
	player:SetAttribute("CattoLobbyReady", true)
end

return UIManager
