--!strict
-- paw mayhem — client bootstrap.
-- wires the clientstate to server state pushes, starts the controllers, and
-- builds the ui. runs once per local player.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local ClientState = require(script.ClientState)

local Controllers = script.Controllers
local CameraController = require(Controllers.CameraController)
local MovementController = require(Controllers.MovementController)
local CombatController = require(Controllers.CombatController)
local EffectsController = require(Controllers.EffectsController)
local EmoteController = require(Controllers.EmoteController)
local CatAnimator = require(Controllers.CatAnimator)
local LavaFX = require(Controllers.LavaFX)
local CatOverheads = require(Controllers.CatOverheads)
local SoundController = require(Controllers.SoundController)
local ReplayController = require(Controllers.ReplayController)
local LobbyLook = require(Controllers.LobbyLook)
local MapLife = require(Controllers.MapLife)

local UIManager = require(script.UI.UIManager)

local function main()
	-- subscribe to server state pushes.
	local settingsLoaded = false
	Remotes.Get("ProfileUpdate").OnClientEvent:Connect(function(profile)
		-- saved settings are applied once, the first time the profile arrives.
		if not settingsLoaded and typeof(profile) == "table" then
			settingsLoaded = true
			if typeof(profile.Settings) == "table" then
				ClientState.UpdateSettings(profile.Settings)
			end
		end
		ClientState.SetProfile(profile)
	end)
	Remotes.Get("MatchState").OnClientEvent:Connect(function(m)
		ClientState.SetMatch(m)
	end)
	Remotes.Get("ScoreUpdate").OnClientEvent:Connect(function(data)
		local m = ClientState.Match
		m.scores = data.scores or m.scores
		m.board = data.board or m.board
		ClientState.SetMatch(m)
	end)

	-- start controllers.
	CameraController.Start()
	MovementController.Start()
	CombatController.Start()
	EffectsController.Start()
	EmoteController.Start()
	CatAnimator.Start()
	LavaFX.Start()
	CatOverheads.Start()
	SoundController.Start()
	MapLife.Start()
	ReplayController.Start()
	LobbyLook.Start()

	-- build ui (also coordinates gameplay enable/disable).
	UIManager.Start()

	print("[PAW MAYHEM] Client started.")
end

main()
