--!strict
-- UIManager: builds the screens and switches between lobby / HUD / results based
-- on the match phase, and enables the camera + combat controllers only while the
-- local cat is alive in a live match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local ClientState = require(script.Parent.Parent.ClientState)

local MainMenu = require(script.Parent.Screens.MainMenu)
local HUD = require(script.Parent.Screens.HUD)
local Results = require(script.Parent.Screens.Results)

local CameraController = require(script.Parent.Parent.Controllers.CameraController)
local CombatController = require(script.Parent.Parent.Controllers.CombatController)

local UIManager = {}
local player = Players.LocalPlayer
local lastPhase = nil
local alive = false

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

	if phase == "Intermission" then
		MainMenu.SetVisible(true)
		HUD.SetVisible(false)
		Results.Hide()
		enableGameplay(false)
	elseif phase == "Countdown" then
		MainMenu.SetVisible(false)
		HUD.SetVisible(true)
		Results.Hide()
		HUD.ShowBig("GET READY", Theme.Color.Warn)
		enableGameplay(false)
	elseif phase == "Playing" then
		MainMenu.SetVisible(false)
		HUD.SetVisible(true)
		Results.Hide()
		HUD.HideBig()
		if alive then
			enableGameplay(true)
		end
	elseif phase == "Results" then
		HUD.SetVisible(false)
		enableGameplay(false)
		Results.Show(m)
	end
end

function UIManager.Start()
	MainMenu.Build()
	HUD.Build()
	Results.Build()

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
