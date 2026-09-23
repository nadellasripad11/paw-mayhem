--!strict
-- MatchService: the match state machine and scoring authority.
--   Intermission -> Countdown -> Playing -> Results -> (loop)
-- Owns team scores, elimination rewards, the kill feed, and match-end payouts.
-- Broadcasts MatchState/ScoreUpdate so all HUDs stay in sync.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local GameConfig = require(Shared.Config.GameConfig)
local Scoring = GameConfig.Scoring

local EconomyService = require(script.Parent.EconomyService)
local PlayerService = require(script.Parent.PlayerService)
local Runtime = require(script.Parent.Runtime)
local ArenaBuilder = require(script.Parent.Parent.World.ArenaBuilder)
local BotService = require(script.Parent.BotService)
local PodiumService = require(script.Parent.PodiumService)

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
	MapId = "SkyIslands",
}

local MAP_IDS = { SkyIslands = true, Volcano = true, Toybox = true }
local mapVotes: { [number]: string } = {}
local queuedPlayers: { [number]: boolean } = {}

local function queuedCount(): number
	local count = 0
	for userId in pairs(queuedPlayers) do
		if Players:GetPlayerByUserId(userId) then
			count += 1
		end
	end
	return count
end

local function voteTotals(): { [string]: number }
	local totals = { SkyIslands = 0, Volcano = 0, Toybox = 0 }
	for _, mapId in pairs(mapVotes) do
		if totals[mapId] ~= nil then
			totals[mapId] += 1
		end
	end
	return totals
end

local function leadingMapId(): string
	local totals = voteTotals()
	local winner, high = state.MapId, -1
	for _, mapId in ipairs({ "SkyIslands", "Volcano", "Toybox" }) do
		if totals[mapId] > high then
			winner, high = mapId, totals[mapId]
		end
	end
	return winner
end

local function buildVotedMap()
	local mapId = leadingMapId()
	if not ArenaBuilder.CurrentMap or ArenaBuilder.CurrentMap.Id ~= mapId then
		ArenaBuilder.BuildMap(mapId)
	end
	state.MapId = mapId
end

-- Build the live scoreboard array sorted by match eliminations.
local function buildBoard()
	local board = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local s = Runtime.Get(player)
		table.insert(board, {
			Name = player.Name,
			Display = player.DisplayName,
			UserId = player.UserId,
			Team = s and s.Team or "Blue",
			Elims = s and s.MatchElims or 0,
			Score = s and s.MatchScore or 0,
		})
	end
	for _, row in ipairs(BotService.Board()) do
		table.insert(board, row)
	end
	table.sort(board, function(a, b)
		if a.Elims ~= b.Elims then
			return a.Elims > b.Elims
		end
		return (a.Score or 0) > (b.Score or 0)
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
		mapId = state.MapId,
		votes = voteTotals(),
		mayhem = Runtime.Mayhem,
		board = buildBoard(),
	})
end

local function broadcastScore()
	Remotes.Get("ScoreUpdate"):FireAllClients({
		scores = state.Scores,
		board = buildBoard(),
	})
end

local function announce(title: string, sub: string?, color: Color3?)
	Remotes.Get("Announce"):FireAllClients({ title = title, sub = sub, color = color })
end

local FIRE_ORANGE = Color3.fromRGB(255, 140, 50)
local STREAK_TITLES = { [5] = "is UNSTOPPABLE!", [8] = "is LEGENDARY!", [12] = "is GODLIKE!" }

-- A kill extends the killer's streak; at the threshold they go On Fire and
-- carry a bounty.
local function addStreak(killer: Player)
	local s = Runtime.Ensure(killer)
	s.Streak += 1
	local char = killer.Character
	if char then
		char:SetAttribute("Streak", s.Streak)
	end
	local cfg = GameConfig.Streaks
	if s.Streak == cfg.OnFire then
		announce(killer.DisplayName .. " is ON FIRE!", "Take them down to claim the bounty", FIRE_ORANGE)
	elseif STREAK_TITLES[s.Streak] then
		announce(killer.DisplayName .. " " .. STREAK_TITLES[s.Streak], string.format("%d eliminations in a row", s.Streak), FIRE_ORANGE)
	end
end

-- The victim's streak ends; whoever ended a hot streak collects the bounty.
local function endStreak(victim: Player, killer: Player?)
	local s = Runtime.Get(victim)
	if not s then
		return
	end
	local streak = s.Streak
	s.Streak = 0
	local cfg = GameConfig.Streaks
	if streak < cfg.OnFire then
		return
	end
	if killer then
		local bounty = cfg.BountyCoinsPerKill * (streak - cfg.OnFire + 1)
		EconomyService.AddCoins(killer, bounty)
		EconomyService.AddXP(killer, cfg.BountyXP)
		EconomyService.Push(killer)
		announce(killer.DisplayName .. " ended " .. victim.DisplayName .. "'s streak!", string.format("%d-kill streak  •  +%d coin bounty", streak, bounty), Color3.fromRGB(255, 214, 90))
	else
		announce(victim.DisplayName .. "'s streak is over!", string.format("%d-kill streak ended", streak), Color3.fromRGB(255, 214, 90))
	end
end

local function setMayhem(on: boolean)
	Runtime.Mayhem = on
	if on then
		announce("MAYHEM MODE!", "Double knockback — supply drops are raining down!", Color3.fromRGB(255, 70, 90))
	end
end

-- Elimination handler wired into PlayerService.
local function onElimination(victim: Player, killer: Player?, weaponId: string?, ringout: boolean)
	local vState = Runtime.Get(victim)
	if vState then
		EconomyService.AddStat(victim, "Deaths", 1)
	end
	endStreak(victim, killer ~= victim and killer or nil)

	if killer and killer ~= victim then
		addStreak(killer)
		local vRoot = victim.Character and victim.Character.PrimaryPart
		if killer:GetAttribute("TrailPack") and vRoot then
			Remotes.Get("PlayEffect"):FireAllClients({ kind = "Confetti", position = vRoot.Position })
		end
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
	elseif vState and vState.LastBot and os.clock() - (vState.LastBotAt or 0) < 8 then
		local kb = vState.LastBot
		vState.LastBot = nil
		BotService.CreditKill(kb.name, kb.team)
		if state.Scores[kb.team] ~= nil then
			state.Scores[kb.team] += Scoring.EliminationTeamPoints
		end
		Remotes.Get("Eliminated"):FireClient(victim, { by = kb.name, xp = 0 })
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
	BotService.DespawnAll()
	state.Winner = winnerTeam
	-- Determine winner if not provided (highest score).
	if not state.Winner then
		state.Winner = (state.Scores.Blue >= state.Scores.Red) and "Blue" or "Red"
	end
	setMayhem(false)
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

	-- Top 3 of the match stand on the winners' podium beside the arena.
	local board = buildBoard()
	local top = {}
	for i = 1, math.min(3, #board) do
		top[i] = board[i]
	end
	task.spawn(PodiumService.Show, top)
end

local function enterIntermission()
	BotService.DespawnAll()
	PodiumService.Clear()
	setMayhem(false)
	state.Phase = PHASE.Intermission
	state.TimeLeft = GameConfig.Match.IntermissionSeconds
	state.Winner = nil
	state.Scores = { Blue = 0, Red = 0 }
	mapVotes = {}
	queuedPlayers = {}
	PlayerService.MatchActive = false
	broadcastState()
end

local function enterCountdown()
	-- Lock the vote and rebuild while players are still in the lobby, before
	-- characters and power-up pickups exist for the next match.
	buildVotedMap()
	state.Phase = PHASE.Countdown
	state.TimeLeft = GameConfig.Match.CountdownSeconds
	-- Reset per-match runtime + spawn everyone.
	for _, player in ipairs(Players:GetPlayers()) do
		Runtime.ResetMatch(player)
	end
	broadcastState()
end

local function enterPlaying()
	setMayhem(false)
	state.Phase = PHASE.Playing
	state.TimeLeft = GameConfig.Match.MatchSeconds
	PlayerService.MatchActive = true
	PlayerService.SpawnAll()
	-- Bots fill the teams up to the target size around the players who queued.
	BotService.SpawnBots(queuedCount())
	broadcastState()
end

-- Main loop: tick the timer once per second and advance phases.
local function mainLoop()
	while true do
		task.wait(1)
		state.TimeLeft -= 1

		if state.Phase == PHASE.Intermission then
			if queuedCount() >= GameConfig.Match.MinPlayersToStart and state.TimeLeft <= 0 then
				enterCountdown()
			elseif state.TimeLeft <= 0 then
				state.TimeLeft = GameConfig.Match.IntermissionSeconds
				broadcastState()
			else
				broadcastState()
			end
		elseif state.Phase == PHASE.Countdown then
			if queuedCount() < GameConfig.Match.MinPlayersToStart then
				-- Everyone who queued left before the drop; cancel cleanly and
				-- return the remaining clients to the landing screen.
				enterIntermission()
			elseif state.TimeLeft <= 0 then
				enterPlaying()
			else
				broadcastState()
			end
		elseif state.Phase == PHASE.Playing then
			if #Players:GetPlayers() == 0 then
				enterIntermission()
			elseif state.TimeLeft <= 0 then
				MatchService.EndMatch(nil)
			else
				if not Runtime.Mayhem and state.TimeLeft <= GameConfig.Mayhem.Seconds then
					setMayhem(true)
				end
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

	-- Award a team point when a bot is eliminated (mirrors onElimination for players).
	BotService.OnBotEliminated = function(killer: Player, botTeam: string)
		addStreak(killer)
		local kState = Runtime.Get(killer)
		local kTeam = kState and kState.Team
		if kTeam and state.Scores[kTeam] ~= nil then
			state.Scores[kTeam] += 1
		end
		broadcastScore()
		if state.Phase == PHASE.Playing then
			for teamId, sc in pairs(state.Scores) do
				if sc >= GameConfig.Match.ScoreToWin then
					MatchService.EndMatch(teamId)
					break
				end
			end
		end
	end

	-- A bot knocked out an enemy bot: its team scores.
	BotService.OnTeamPoint = function(teamId: string)
		if state.Phase ~= PHASE.Playing or state.Scores[teamId] == nil then
			return
		end
		state.Scores[teamId] += 1
		broadcastScore()
		if state.Scores[teamId] >= GameConfig.Match.ScoreToWin then
			MatchService.EndMatch(teamId)
		end
	end

	BotService.Start()
	Remotes.Get("RequestJoinMatch").OnServerEvent:Connect(function(player, payload)
		local mapId = typeof(payload) == "table" and payload.mapId or nil
		if typeof(mapId) ~= "string" or not MAP_IDS[mapId] then
			return
		end
		-- A late joiner must still opt in from the landing screen. Once they
		-- press Play, put them into the current round without forcing every
		-- existing player through a new countdown.
		if state.Phase == PHASE.Playing then
			local rs = Runtime.Get(player)
			if rs and rs.Alive then
				return
			end
			queuedPlayers[player.UserId] = true
			mapVotes[player.UserId] = state.MapId
			Runtime.ResetMatch(player)
			PlayerService.AssignTeam(player)
			PlayerService.Spawn(player)
			BotService.Rebalance(queuedCount())
			Remotes.Get("Notify"):FireClient(player, { text = "Dropping into the current match!", kind = "success" })
			broadcastState()
			return
		end
		-- The map is already locked in; everyone is spawned when the round starts.
		if state.Phase == PHASE.Countdown then
			queuedPlayers[player.UserId] = true
			return
		end
		if state.Phase ~= PHASE.Intermission then
			Remotes.Get("Notify"):FireClient(player, { text = "The next round starts in a moment.", kind = "info" })
			return
		end
		mapVotes[player.UserId] = mapId
		queuedPlayers[player.UserId] = true
		state.MapId = leadingMapId()
		Remotes.Get("Notify"):FireAllClients({ text = player.DisplayName .. " voted for " .. mapId, kind = "info" })
		broadcastState()
	end)

	-- Sync new joiners to current state, and drop late joiners into a live match.
	Players.PlayerAdded:Connect(function(player)
		task.wait(1)
		broadcastState()
		-- Do not auto-spawn late joiners. They must use the same landing-screen
		-- Play action as everyone else so the launch flow is never skipped.
	end)
	Players.PlayerRemoving:Connect(function(player)
		queuedPlayers[player.UserId] = nil
		if state.Phase == PHASE.Playing then
			BotService.Rebalance(queuedCount())
		end
	end)

	enterIntermission()
	task.spawn(mainLoop)
end

return MatchService
