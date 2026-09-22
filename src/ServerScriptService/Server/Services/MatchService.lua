--!strict
-- MatchService: the match state machine and scoring authority.
--   Intermission -> Countdown -> Playing -> Results -> (loop)
-- Owns team scores, elimination rewards, the kill feed, and match-end payouts.
-- Broadcasts MatchState/ScoreUpdate so all HUDs stay in sync.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local GameConfig = require(Shared.Config.GameConfig)
local Scoring = GameConfig.Scoring

local EconomyService = require(script.Parent.EconomyService)
local PlayerService = require(script.Parent.PlayerService)
local Runtime = require(script.Parent.Runtime)

local MatchService = {}

local PHASE = {
	Intermission = "Intermission",
	Countdown = "Countdown",
	Playing = "Playing",
	Results = "Results",
}

local state = {
	Phase = PHASE.Intermission,
	TimeLeft = GameConfig.Match.IntermissionSeconds,
	Scores = { Blue = 0, Red = 0 },
	Winner = nil :: string?,
}

-- Build the live scoreboard array sorted by match eliminations.
local function buildBoard()
	local board = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local s = Runtime.Get(player)
		table.insert(board, {
			Name = player.Name,
			Display = player.DisplayName,
			Team = s and s.Team or "Blue",
			Elims = s and s.MatchElims or 0,
			Score = s and s.MatchScore or 0,
		})
	end
	table.sort(board, function(a, b)
		return a.Elims > b.Elims
	end)
	return board
end

local function broadcastState()
	Remotes.Get("MatchState"):FireAllClients({
		phase = state.Phase,
		timeLeft = math.max(0, math.floor(state.TimeLeft)),
		scores = state.Scores,
		winner = state.Winner,
		scoreToWin = GameConfig.Match.ScoreToWin,
		matchSeconds = GameConfig.Match.MatchSeconds,
		board = buildBoard(),
	})
end

local function broadcastScore()
	Remotes.Get("ScoreUpdate"):FireAllClients({
		scores = state.Scores,
		board = buildBoard(),
	})
end

-- Elimination handler wired into PlayerService.
local function onElimination(victim: Player, killer: Player?, weaponId: string?, ringout: boolean)
	local vState = Runtime.Get(victim)
	if vState then
		EconomyService.AddStat(victim, "Deaths", 1)
	end

	if killer and killer ~= victim then
		local kState = Runtime.Ensure(killer)
		kState.MatchElims += 1
		kState.MatchScore += 1
		-- Team point.
		if kState.Team and state.Scores[kState.Team] ~= nil then
			state.Scores[kState.Team] += Scoring.EliminationTeamPoints
		end
		-- Rewards.
		EconomyService.AddXP(killer, Scoring.EliminationXP)
		EconomyService.AddCoins(killer, Scoring.EliminationCoins)
		EconomyService.AddStat(killer, "Eliminations", 1)
		if ringout then
			EconomyService.AddStat(killer, "Ringouts", 1)
		end
		EconomyService.Push(killer)
		Remotes.Get("Eliminated"):FireClient(victim, { by = killer.DisplayName, xp = 0 })
	else
		Remotes.Get("Eliminated"):FireClient(victim, { by = ringout and "the void" or "themselves", xp = 0 })
	end

	-- Kill feed to everyone.
	Remotes.Get("KillFeed"):FireAllClients({
		killer = killer and killer.DisplayName or (ringout and "☠" or "—"),
		killerTeam = killer and (Runtime.Get(killer) and Runtime.Get(killer).Team) or nil,
		victim = victim.DisplayName,
		victimTeam = vState and vState.Team or nil,
		weaponId = weaponId,
		ringout = ringout,
	})

	broadcastScore()

	-- Early match end on score cap.
	if state.Phase == PHASE.Playing then
		for teamId, sc in pairs(state.Scores) do
			if sc >= GameConfig.Match.ScoreToWin then
				MatchService.EndMatch(teamId)
				break
			end
		end
	end
end

function MatchService.EndMatch(winnerTeam: string?)
	if state.Phase ~= PHASE.Playing then
		return
	end
	state.Winner = winnerTeam
	-- Determine winner if not provided (highest score).
	if not state.Winner then
		state.Winner = (state.Scores.Blue >= state.Scores.Red) and "Blue" or "Red"
	end
	state.Phase = PHASE.Results
	state.TimeLeft = GameConfig.Match.ResultsSeconds
	PlayerService.MatchActive = false

	-- Match payouts.
	for _, player in ipairs(Players:GetPlayers()) do
		local s = Runtime.Get(player)
		EconomyService.AddStat(player, "Matches", 1)
		EconomyService.AddXP(player, Scoring.MatchPlayedXP)
		if s and s.Team == state.Winner then
			EconomyService.AddStat(player, "Wins", 1)
			EconomyService.AddXP(player, Scoring.WinBonusXP)
			EconomyService.AddCoins(player, Scoring.WinBonusCoins)
		end
		EconomyService.Push(player)
	end

	broadcastState()
	PlayerService.DespawnAll()
end

local function enterIntermission()
	state.Phase = PHASE.Intermission
	state.TimeLeft = GameConfig.Match.IntermissionSeconds
	state.Winner = nil
	state.Scores = { Blue = 0, Red = 0 }
	PlayerService.MatchActive = false
	broadcastState()
end

local function enterCountdown()
	state.Phase = PHASE.Countdown
	state.TimeLeft = GameConfig.Match.CountdownSeconds
	-- Reset per-match runtime + spawn everyone.
	for _, player in ipairs(Players:GetPlayers()) do
		Runtime.ResetMatch(player)
	end
	broadcastState()
end

local function enterPlaying()
	state.Phase = PHASE.Playing
	state.TimeLeft = GameConfig.Match.MatchSeconds
	PlayerService.MatchActive = true
	PlayerService.SpawnAll()
	broadcastState()
end

-- Main loop: tick the timer once per second and advance phases.
local function mainLoop()
	while true do
		task.wait(1)
		state.TimeLeft -= 1

		if state.Phase == PHASE.Intermission then
			if #Players:GetPlayers() >= GameConfig.Match.MinPlayersToStart and state.TimeLeft <= 0 then
				enterCountdown()
			elseif state.TimeLeft <= 0 then
				state.TimeLeft = GameConfig.Match.IntermissionSeconds
				broadcastState()
			else
				broadcastState()
			end
		elseif state.Phase == PHASE.Countdown then
			if state.TimeLeft <= 0 then
				enterPlaying()
			else
				broadcastState()
			end
		elseif state.Phase == PHASE.Playing then
			if state.TimeLeft <= 0 then
				MatchService.EndMatch(nil)
			else
				broadcastState()
			end
		elseif state.Phase == PHASE.Results then
			if state.TimeLeft <= 0 then
				enterIntermission()
			else
				broadcastState()
			end
		end
	end
end

function MatchService.Start()
	PlayerService.OnElimination = onElimination

	-- Sync new joiners to current state, and drop late joiners into a live match.
	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		broadcastState()
		if state.Phase == PHASE.Playing then
			Runtime.ResetMatch(player)
			PlayerService.AssignTeam(player)
			task.wait(1)
			PlayerService.Spawn(player)
		end
	end)

	enterIntermission()
	task.spawn(mainLoop)
end

return MatchService
