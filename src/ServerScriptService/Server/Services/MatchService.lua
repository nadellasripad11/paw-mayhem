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
local SeasonService = require(script.Parent.SeasonService)
local Modes = require(game:GetService("ReplicatedStorage").Shared.Config.Modes)
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")

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
	Mode = Modes.Default,
}

local MAP_IDS = { SkyIslands = true, Volcano = true, Toybox = true }
local mapVotes: { [number]: string } = {}
local modeVotes: { [number]: string } = {}

local function currentMode(): any
	return Modes.Get(state.Mode)
end

local function scoreToWin(): number
	return currentMode().ScoreToWin
end

local function isFFA(): boolean
	return state.Mode == "FFA"
end

local function modeTotals(): { [string]: number }
	local totals = {}
	for _, m in ipairs(Modes.List) do
		totals[m.Id] = 0
	end
	for _, id in pairs(modeVotes) do
		if totals[id] ~= nil then
			totals[id] += 1
		end
	end
	return totals
end

local function leadingModeId(): string
	local totals = modeTotals()
	local winner, high = Modes.Default, 0
	for _, m in ipairs(Modes.List) do
		if totals[m.Id] > high then
			winner, high = m.Id, totals[m.Id]
		end
	end
	return winner
end
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
		scoreToWin = scoreToWin(),
		mode = state.Mode,
		modeVotes = modeTotals(),
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
		if not isFFA() and kState.Team and state.Scores[kState.Team] ~= nil then
			state.Scores[kState.Team] += Scoring.EliminationTeamPoints * currentMode().KillPoints
		end
		-- Rewards.
		EconomyService.AddXP(killer, Scoring.EliminationXP)
		EconomyService.AddCoins(killer, Scoring.EliminationCoins)
		EconomyService.AddStat(killer, "Eliminations", 1)
		SeasonService.AddXP(killer, "Elimination")
		if ringout then
			EconomyService.AddStat(killer, "Ringouts", 1)
			SeasonService.AddXP(killer, "Ringout")
		end
		EconomyService.Push(killer)
		Remotes.Get("Eliminated"):FireClient(victim, { by = killer.DisplayName, xp = 0 })
	elseif vState and vState.LastBot and os.clock() - (vState.LastBotAt or 0) < 8 then
		local kb = vState.LastBot
		vState.LastBot = nil
		BotService.CreditKill(kb.name, kb.team)
		if not isFFA() and state.Scores[kb.team] ~= nil then
			state.Scores[kb.team] += Scoring.EliminationTeamPoints * currentMode().KillPoints
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

	MatchService.CheckWin()
end

-- End the match as soon as a team (or, in Free For All, a cat) hits the target.
function MatchService.CheckWin()
	if state.Phase ~= PHASE.Playing then
		return
	end
	if isFFA() then
		local top = buildBoard()[1]
		if top and (top.Elims or 0) >= scoreToWin() then
			MatchService.EndMatch(top.Name)
		end
		return
	end
	for teamId, sc in pairs(state.Scores) do
		if sc >= scoreToWin() then
			MatchService.EndMatch(teamId)
			return
		end
	end
end

-- ── King of the Hill ─────────────────────────────────────────────────────────
local HILL_RADIUS = 14
local hillParts: { BasePart } = {}
local hillPos: Vector3? = nil

local function stopHill()
	for _, p in ipairs(hillParts) do
		p:Destroy()
	end
	hillParts = {}
	hillPos = nil
	Runtime.HillPos = nil
end

local function startHill()
	stopHill()
	-- The playable floor nearest the middle of the map becomes the hill.
	local floors = CollectionService:GetTagged("DropZone")
	if #floors == 0 then
		return
	end
	local mid = Vector3.zero
	for _, f in ipairs(floors) do
		mid += (f :: BasePart).Position
	end
	mid /= #floors
	local best, bestD = nil, math.huge
	for _, f in ipairs(floors) do
		local p = (f :: BasePart).Position
		local d = Vector3.new(p.X - mid.X, 0, p.Z - mid.Z).Magnitude
		if d < bestD then
			best, bestD = f :: BasePart, d
		end
	end
	if not best then
		return
	end
	local pos = best.Position + Vector3.new(0, best.Size.Y / 2, 0)
	local function piece(size: Vector3, cf: CFrame, transparency: number): BasePart
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.CFrame = cf
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 230, 140)
		p.Transparency = transparency
		p.CastShadow = false
		p.Parent = Workspace
		table.insert(hillParts, p)
		return p
	end
	local up = CFrame.Angles(0, 0, math.rad(90))
	piece(Vector3.new(0.3, HILL_RADIUS * 2, HILL_RADIUS * 2), CFrame.new(pos + Vector3.new(0, 0.2, 0)) * up, 0.55)
	piece(Vector3.new(26, HILL_RADIUS * 2, HILL_RADIUS * 2), CFrame.new(pos + Vector3.new(0, 13, 0)) * up, 0.9)
	hillPos = pos
	Runtime.HillPos = pos
	announce("KING OF THE HILL", "Stand in the glowing hill to score for your team!", Color3.fromRGB(255, 214, 90))
end

-- Once a second: a team holding the hill alone scores a point.
local function tickHill()
	if not hillPos then
		return
	end
	local present: { [string]: number } = {}
	local function inHill(pos: Vector3): boolean
		local off = pos - (hillPos :: Vector3)
		return Vector3.new(off.X, 0, off.Z).Magnitude <= HILL_RADIUS and math.abs(off.Y) < 12
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local s = Runtime.Get(p)
		local root = p.Character and p.Character.PrimaryPart
		if s and s.Alive and s.Team and root and inHill(root.Position) then
			present[s.Team] = (present[s.Team] or 0) + 1
		end
	end
	for _, b in ipairs(BotService.Positions()) do
		if inHill(b.pos) then
			present[b.team] = (present[b.team] or 0) + 1
		end
	end
	local teams = {}
	for t in pairs(present) do
		table.insert(teams, t)
	end
	local color = Color3.fromRGB(255, 230, 140)
	if #teams == 1 then
		local t = teams[1]
		if state.Scores[t] ~= nil then
			state.Scores[t] += 1
		end
		color = t == "Blue" and Color3.fromRGB(70, 150, 255) or Color3.fromRGB(255, 80, 90)
		broadcastScore()
		MatchService.CheckWin()
	elseif #teams > 1 then
		color = Color3.fromRGB(190, 110, 255) -- contested
	end
	for _, p in ipairs(hillParts) do
		p.Color = color
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
		if isFFA() then
			local top = buildBoard()[1]
			state.Winner = top and top.Name or nil
		else
			state.Winner = (state.Scores.Blue >= state.Scores.Red) and "Blue" or "Red"
		end
	end
	stopHill()
	setMayhem(false)
	state.Phase = PHASE.Results
	state.TimeLeft = GameConfig.Match.ResultsSeconds
	PlayerService.MatchActive = false

	-- Match payouts.
	for _, player in ipairs(Players:GetPlayers()) do
		local s = Runtime.Get(player)
		EconomyService.AddStat(player, "Matches", 1)
		SeasonService.AddXP(player, "MatchPlayed")
		EconomyService.AddXP(player, Scoring.MatchPlayedXP)
		local won = (isFFA() and player.Name == state.Winner) or (not isFFA() and s ~= nil and s.Team == state.Winner)
		if won then
			EconomyService.AddStat(player, "Wins", 1)
			SeasonService.AddXP(player, "Win")
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
	stopHill()
	modeVotes = {}
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
	state.Mode = leadingModeId()
	Runtime.Mode = state.Mode
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
	if state.Mode == "KOTH" then
		startHill()
	elseif state.Mode == "Ringout" then
		announce("RINGOUT", "Blasters do no damage — knock cats off the map!", Color3.fromRGB(190, 120, 255))
	elseif state.Mode == "FFA" then
		announce("FREE FOR ALL", "Everyone is an enemy. First to " .. scoreToWin() .. " KOs wins!", Color3.fromRGB(255, 120, 90))
	end
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
				if state.Mode == "KOTH" then
					tickHill()
				end
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
		if not isFFA() and kTeam and state.Scores[kTeam] ~= nil then
			state.Scores[kTeam] += currentMode().KillPoints
		end
		broadcastScore()
		MatchService.CheckWin()
	end

	-- A bot knocked out an enemy bot: its team scores.
	BotService.OnTeamPoint = function(teamId: string)
		if state.Phase ~= PHASE.Playing or state.Scores[teamId] == nil then
			return
		end
		if not isFFA() then
			state.Scores[teamId] += currentMode().KillPoints
		end
		broadcastScore()
		MatchService.CheckWin()
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
		local modeId = typeof(payload) == "table" and payload.modeId or nil
		if typeof(modeId) == "string" and Modes.ById[modeId] then
			modeVotes[player.UserId] = modeId
		end
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
