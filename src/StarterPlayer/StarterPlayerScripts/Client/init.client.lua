--!strict
-- PAW MAYHEM — client bootstrap.
-- Wires the ClientState to server state pushes, starts the controllers, and
-- builds the UI. Runs once per local player.

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

local UIManager = require(script.UI.UIManager)

local function main()
	-- Subscribe to server state pushes.
	Remotes.Get("ProfileUpdate").OnClientEvent:Connect(function(profile)
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

	-- Start controllers.
	CameraController.Start()
	MovementController.Start()
	CombatController.Start()
	EffectsController.Start()
	EmoteController.Start()
	CatAnimator.Start()

	-- Build UI (also coordinates gameplay enable/disable).
	UIManager.Start()

	print("[PAW MAYHEM] Client started.")
end

main()
