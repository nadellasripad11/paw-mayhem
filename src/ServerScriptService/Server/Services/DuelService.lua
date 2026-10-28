--!strict
-- duelservice: 1v1 and 2v2 duels from the lobby's duel pads (straight ahead
-- of spawn). stand on a glowing slot; once every slot on a pad is taken a
-- short countdown starts (step off to cancel) and everyone on it is sent to
-- their own duel on a random duel map (duelmaps). first side to 5 knockouts
-- wins, or whoever leads when the clock runs out. trophies, coins and xp like
-- a match, then everyone's back in the lobby. duels run side by side, each on
-- its own copy of a map far from the lobby and the arena.
-- nobody coming? after 15 seconds on a pad, bots fill the empty slots. bot
-- duels pay half and never move your trophies (no farming bots for rank).

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local GameConfig = require(Shared.Config.GameConfig)
local Ranks = require(Shared.Config.Ranks)

local Runtime = require(script.Parent.Runtime)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local SeasonService = require(script.Parent.SeasonService)
local BotService = require(script.Parent.BotService)
local PlayerService = require(script.Parent.PlayerService)
local LobbyService = require(script.Parent.LobbyService)
local ArenaKit = require(script.Parent.Parent.World.ArenaKit)
local DuelMaps = require(script.Parent.Parent.World.DuelMaps)

local DuelService = {}

local TARGET = 5 -- knockouts to win
local DUEL_SECONDS = 240
local COUNTDOWN = 3
local SLOT_RADIUS = 2.2
local WIN_COINS, LOSS_COINS = 40, 10
local WIN_XP, LOSS_XP = 120, 40
local BOT_WAIT = 15 -- seconds alone on a pad before bots fill it

local TEAM_COLOR = { Blue = Color3.fromRGB(70, 150, 255), Red = Color3.fromRGB(255, 80, 90) }

type Slot = { team: string, pos: Vector3, part: BasePart, player: Player? }
type Pad = { kind: string, slots: { Slot }, counts: { [string]: TextLabel }, sub: TextLabel, big: TextLabel, startAt: number?, waitingSince: number?, center: Vector3, w: number, d: number }
type Duel = {
	id: number,
	place: number,
	kind: string,
	map: DuelMaps.Layout,
	folder: Folder,
	center: Vector3,
	teams: { [string]: { Player } },
	bots: { [string]: { string } }, -- bot names on each side
	withBots: boolean,
	members: { [Player]: string },
	score: { [string]: number },
	kos: { [Player]: number },
	endsAt: number,
	over: boolean,
	target: number, -- knockouts to win
	ringoutOnly: boolean, -- only knock-offs score
}

local pads: { Pad } = {}
local duels: { [number]: Duel } = {}
local places: { [number]: boolean } = {} -- which far-away build spots are in use
local nextId = 1

local function other(team: string): string
	return team == "Blue" and "Red" or "Blue"
end

-- ── the pads in the lobby ────────────────────────────────────────────────────
-- pad look (rivals-style, our colours): a flat dark plate with a light rim,
-- split across the middle into two sides (blue towards the spawn, red
-- towards the far end, matching the screen above); each player spot is a round emblem
-- that fills with its team colour when someone stands on it.
local PAD_PLATE = Color3.fromRGB(26, 34, 70) -- navy (the lobby's colours)
local PAD_RIM = Color3.fromRGB(206, 164, 72) -- gold
local SPOT_RING = Color3.fromRGB(236, 206, 130)
local SPOT_EMPTY = Color3.fromRGB(40, 50, 92)

local SPOT_DARK = Color3.fromRGB(16, 18, 26)
local SCREEN_BLUE = Color3.fromRGB(90, 170, 255)

-- a pad like rivals': a dark plate, a glowing target emblem for each spot
-- (it lights up in the team colour when someone's on it), bright team lines
-- along the edges; above it on the wall a big angled screen with a glowing
-- blue frame showing each side's count, and the countdown when it's full.
local function buildPad(def: any, parent: Instance)
	local at = LobbyService.At
	local is2v2 = def.kind == "2v2"
	local w, d = is2v2 and 11 or 9, is2v2 and 12.5 or 12
	local center = at(def.x, def.z)
	local function flat(name: string, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): BasePart
		local p = ArenaKit.NewPart(name, size, CFrame.new(center + offset), color, material or Enum.Material.Metal, parent)
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end
	local function ring(name: string, diameter: number, y: number, x: number, z: number, color: Color3, material: Enum.Material): BasePart
		local p = ArenaKit.NewDisc(name, diameter, 0.04, center + Vector3.new(x, y, z), color, material, parent)
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end

	-- the plate.
	flat("PadSkirt", Vector3.new(w + 0.6, 0.16, d + 0.6), Vector3.new(0, 0.08, 0), Color3.fromRGB(12, 13, 18))
	flat("PadPlate", Vector3.new(w, 0.3, d), Vector3.new(0, 0.15, 0), Color3.fromRGB(24, 26, 36), Enum.Material.DiamondPlate)
	flat("PadSplit", Vector3.new(w - 0.6, 0.32, 0.14), Vector3.new(0, 0.16, 0), Color3.fromRGB(70, 74, 92))
	-- team lines along the two long edges, each half in its colour.
	for _, side in ipairs({ { "Blue", -1 }, { "Red", 1 } }) do
		for _, x in ipairs({ -w / 2 + 0.25, w / 2 - 0.25 }) do
			flat("PadEdge", Vector3.new(0.28, 0.33, d / 2 - 0.4), Vector3.new(x, 0.165, side[2] * d / 4), TEAM_COLOR[side[1]], Enum.Material.Neon)
		end
		flat("PadEnd", Vector3.new(w - 0.5, 0.33, 0.28), Vector3.new(0, 0.165, side[2] * (d / 2 - 0.25)), TEAM_COLOR[side[1]], Enum.Material.Neon)
	end

	local pad: Pad = { kind = def.kind, slots = {}, counts = {}, sub = nil :: any, big = nil :: any, startAt = nil, center = center, w = w, d = d }
	local offsets = is2v2 and { { "Blue", -2.6, -3.1 }, { "Blue", 2.6, -3.1 }, { "Red", -2.6, 3.1 }, { "Red", 2.6, 3.1 } }
		or { { "Blue", 0, -3 }, { "Red", 0, 3 } }
	for _, o in ipairs(offsets) do
		-- a target: glowing outer ring, dark, glowing inner ring, dark, and a
		-- centre that lights up when someone's in this spot.
		local col = TEAM_COLOR[o[1]]
		ring("SpotOuter", 4, 0.32, o[2], o[3], col, Enum.Material.Neon)
		ring("SpotGap", 3.4, 0.34, o[2], o[3], SPOT_DARK, Enum.Material.Metal)
		ring("SpotInner", 2.5, 0.36, o[2], o[3], col, Enum.Material.Neon)
		ring("SpotGap2", 2, 0.38, o[2], o[3], SPOT_DARK, Enum.Material.Metal)
		local fill = ring("SpotFill", 1.3, 0.4, o[2], o[3], SPOT_EMPTY, Enum.Material.Neon)
		table.insert(pad.slots, { team = o[1], pos = center + Vector3.new(o[2], 0, o[3]), part = fill, player = nil })
	end

	-- the screen: big, high on the wall, turned toward you as you walk in.
	local wallX = def.screenX or def.wall * 16.75
	local screenPos = at(wallX - def.wall * 0.6, def.z, 8.6)
	local face = CFrame.lookAt(screenPos, screenPos + Vector3.new(-def.wall, 0, -0.45)) * CFrame.Angles(math.rad(-10), 0, 0)
	local back = ArenaKit.NewPart("ScreenBack", Vector3.new(10.6, 7, 0.8), face * CFrame.new(0, 0, 0.5), Color3.fromRGB(14, 16, 24), Enum.Material.Metal, parent)
	back.CanCollide = false
	back.CanQuery = false
	for _, e in ipairs({ { 0, 3.35, 10.4, 0.22 }, { 0, -3.35, 10.4, 0.22 }, { 5.1, 0, 0.22, 6.9 }, { -5.1, 0, 0.22, 6.9 } }) do
		local glow = ArenaKit.NewPart("ScreenGlow", Vector3.new(e[3], e[4], 0.2), face * CFrame.new(e[1], e[2], -0.02), SCREEN_BLUE, Enum.Material.Neon, parent)
		glow.CanCollide = false
		glow.CanQuery = false
		glow.CastShadow = false
	end
	local screen = ArenaKit.NewPart("PadScreen", Vector3.new(10, 6.4, 0.2), face, Color3.fromRGB(10, 16, 30), Enum.Material.SmoothPlastic, parent)
	screen.CanCollide = false
	screen.CanQuery = false
	local light = Instance.new("SurfaceLight")
	light.Face = Enum.NormalId.Front
	light.Color = SCREEN_BLUE
	light.Range = 12
	light.Brightness = 0.6
	light.Parent = screen
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.Parent = screen
	local function label(text: string, x: number, y: number, wScale: number, h: number, font: Enum.Font, color: Color3): TextLabel
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(x, y)
		t.Size = UDim2.fromScale(wScale, h)
		t.Font = font
		t.TextScaled = true
		t.TextColor3 = color
		t.TextStrokeColor3 = Color3.fromRGB(10, 30, 70)
		t.TextStrokeTransparency = 0.2
		t.Text = text
		t.Parent = gui
		return t
	end
	local need = #pad.slots // 2
	label(string.upper(def.kind), 0, 0.05, 1, 0.16, Enum.Font.FredokaOne, Color3.fromRGB(200, 225, 255))
	-- (facing a left-wall screen the spawn end is on your left; facing a
	-- right-wall one it's on your right. each count sits over its own half.)
	local blueLeft = def.wall > 0
	pad.counts.Blue = label("0/" .. need, blueLeft and 0.04 or 0.52, 0.24, 0.44, 0.5, Enum.Font.FredokaOne, Color3.fromRGB(150, 205, 255))
	pad.counts.Red = label("0/" .. need, blueLeft and 0.52 or 0.04, 0.24, 0.44, 0.5, Enum.Font.FredokaOne, Color3.fromRGB(255, 160, 170))
	local bar = Instance.new("Frame")
	bar.BackgroundColor3 = SCREEN_BLUE
	bar.BorderSizePixel = 0
	bar.Position = UDim2.fromScale(0.495, 0.28)
	bar.Size = UDim2.fromScale(0.01, 0.42)
	bar.Parent = gui
	-- the countdown: one huge number over everything when the pad is full.
	pad.big = label("", 0, 0.12, 1, 0.66, Enum.Font.FredokaOne, Color3.fromRGB(255, 220, 90))
	pad.big.Visible = false
	pad.sub = label("Step on a pad", 0, 0.8, 1, 0.14, Enum.Font.GothamBold, Color3.fromRGB(190, 210, 240))
	table.insert(pads, pad)
end

-- can this player take a pad slot right now?
local function eligible(p: Player): boolean
	local s = Runtime.Get(p)
	return s ~= nil and s.Alive and s.Context == "Lobby" and p:GetAttribute("Queued") ~= true
end

local function onSlot(p: Player, slot: Slot): boolean
	local root = p.Character and p.Character.PrimaryPart
	if not root then
		return false
	end
	local off = root.Position - slot.pos
	return Vector3.new(off.X, 0, off.Z).Magnitude < SLOT_RADIUS and math.abs(off.Y) < 5
end

-- ── a duel ───────────────────────────────────────────────────────────────────
local function send(duel: Duel, extra: { [string]: any }?)
	local names = {}
	for team, list in pairs(duel.teams) do
		names[team] = {}
		for _, p in ipairs(list) do
			table.insert(names[team], p.DisplayName)
		end
		for _, b in ipairs(duel.bots[team]) do
			table.insert(names[team], b)
		end
	end
	for p, team in pairs(duel.members) do
		if p.Parent then
			local data: { [string]: any } = {
				id = duel.id, kind = duel.kind, map = duel.map.name, teams = names, score = duel.score,
				target = duel.target, timeLeft = math.max(0, math.floor(duel.endsAt - os.clock())), myTeam = team,
				withBots = duel.withBots,
			}
			for k, v in pairs(extra or {}) do
				data[k] = v
			end
			Remotes.Get("DuelState"):FireClient(p, data)
		end
	end
end

local function spawnIn(duel: Duel, p: Player)
	local team = duel.members[p]
	if not team or duel.over or not p.Parent then
		return
	end
	local list = duel.teams[team]
	local index = table.find(list, p) or 1
	local spots = duel.map.spawns[team]
	-- bigger teams than spawn spots: spread out sideways.
	local spot = spots[(index - 1) % #spots + 1] * CFrame.new(((index - 1) // #spots) * 3, 0, 0)
	PlayerService.Spawn(p, { context = "Duel", team = team, duelId = duel.id, cframe = spot })
end

local function inThisDuel(p: Player, duel: Duel): boolean
	local s = Runtime.Get(p)
	return p.Parent ~= nil and s ~= nil and s.Context == "Duel" and s.DuelId == duel.id
end

local function finish(duel: Duel, winner: string?, forfeit: boolean?)
	if duel.over then
		return
	end
	duel.over = true
	BotService.RemoveDuelBots(duel.id)
	local pay = duel.withBots and 0.5 or 1
	-- (who won, for everyone's end screen)
	local winners = {}
	for p, team in pairs(duel.members) do
		if winner and team == winner and p.Parent then
			table.insert(winners, { name = p.DisplayName, userId = p.UserId })
		end
	end
	for p, team in pairs(duel.members) do
		if p.Parent and inThisDuel(p, duel) then
			local won = winner == team
			local delta = 0
			local profile = DataService.Get(p)
			local stats = profile and profile.Stats
			-- a draw (or a duel with bots) leaves trophies alone.
			if stats and winner and not duel.withBots then
				local before = stats.Trophies or 0
				stats.Trophies = math.max(0, before + Ranks.Delta(won, duel.kos[p] or 0))
				delta = stats.Trophies - before
				if won then
					stats.WinStreak = (stats.WinStreak or 0) + 1
					stats.BestWinStreak = math.max(stats.BestWinStreak or 0, stats.WinStreak)
				else
					EconomyService.EndStreak(p)
				end
			end
			EconomyService.AddXP(p, math.floor((won and WIN_XP or LOSS_XP) * pay))
			EconomyService.AddCoins(p, math.floor((won and WIN_COINS or LOSS_COINS) * pay))
			SeasonService.AddXP(p, "MatchPlayed")
			EconomyService.Push(p)
			Remotes.Get("DuelState"):FireClient(p, {
				id = duel.id, over = true, winner = winner, won = won, draw = winner == nil,
				forfeit = forfeit == true, trophies = delta, score = duel.score, myTeam = team, withBots = duel.withBots, winners = winners,
			})
		end
	end
	-- time for the final score and the winner (endscreen), then everyone's
	-- back in the lobby.
	task.delay(7.5, function()
		for p in pairs(duel.members) do
			if inThisDuel(p, duel) then
				LobbyService.Spawn(p)
			end
		end
		duel.folder:Destroy()
		duels[duel.id] = nil
		places[duel.place] = nil
	end)
end

-- someone on `team` was knocked out (hp or off the map): the other side
-- scores. returns true while the duel goes on (so they respawn).
local function scoreKO(duel: Duel, team: string, victimName: string, killer: Player?, ringout: boolean): boolean
	local scorer = other(team)
	if duel.ringoutOnly and not ringout then
		-- (ringout mode: only knock-offs count; they still respawn.)
		send(duel, { ko = victimName })
		return true
	end
	duel.score[scorer] += 1
	if killer and duel.members[killer] and duel.members[killer] ~= team then
		duel.kos[killer] = (duel.kos[killer] or 0) + 1
		EconomyService.AddStat(killer, "Eliminations", 1)
	end
	local botKiller = #duel.bots[scorer] > 0 and #duel.teams[scorer] == 0 and duel.bots[scorer][1] or nil
	for p in pairs(duel.members) do
		if p.Parent then
			Remotes.Get("KillFeed"):FireClient(p, {
				killer = killer and killer.DisplayName or botKiller or "the void", killerTeam = scorer,
				victim = victimName, victimTeam = team, ringout = ringout,
			})
		end
	end
	if duel.score[scorer] >= duel.target then
		for p in pairs(duel.members) do
			if p.Parent then
				Remotes.Get("FinalKO"):FireClient(p, {})
			end
		end
		send(duel)
		finish(duel, scorer)
		return false
	end
	send(duel, { ko = victimName })
	return true
end

local function onDuelKO(victim: Player, killer: Player?, ringout: boolean)
	local s = Runtime.Get(victim)
	local duel = s and s.DuelId and duels[s.DuelId]
	if not duel or duel.over then
		return
	end
	local team = duel.members[victim]
	if not team then
		return
	end
	if scoreKO(duel, team, victim.DisplayName, killer, ringout) then
		task.delay(GameConfig.Character.RespawnDelay, function()
			if inThisDuel(victim, duel) then
				spawnIn(duel, victim)
			end
		end)
	end
end

-- bring a duel's bot (back) in on its side.
local function spawnBot(duel: Duel, team: string, index: number, name: string?)
	if duel.over then
		return
	end
	local spots = duel.map.spawns[team]
	local info: BotService.DuelInfo
	info = {
		id = duel.id,
		spawn = spots[(index - 1) % #spots + 1] * CFrame.new(((index - 1) // #spots) * 3, 0, 0),
		center = duel.center,
		killY = duel.map.killY,
		onKO = function(botName: string, botTeam: string, killer: Player?, ringout: boolean)
			if duel.over then
				return
			end
			if scoreKO(duel, botTeam, botName, killer, ringout) then
				task.delay(GameConfig.Character.RespawnDelay, function()
					spawnBot(duel, botTeam, index, botName)
				end)
			end
		end,
	}
	local botName = BotService.SpawnDuelBot(team, info, name)
	if not name then
		table.insert(duel.bots[team], botName)
	end
end

local function leave(p: Player)
	for _, pad in ipairs(pads) do
		for _, slot in ipairs(pad.slots) do
			if slot.player == p then
				slot.player = nil
			end
		end
	end
	for _, duel in pairs(duels) do
		local team = duel.members[p]
		if team and not duel.over then
			local list = duel.teams[team]
			local i = table.find(list, p)
			if i then
				table.remove(list, i)
			end
			duel.members[p] = nil
			if #list == 0 then
				finish(duel, other(team), true) -- the other side wins by forfeit
			end
		end
	end
end

-- gamemodes you can vote for after a queue match is found.
local MODES = {
	{ id = "Classic", name = "CLASSIC", desc = "First to 5 knockouts", target = 5 },
	{ id = "Quick", name = "QUICK", desc = "First to 3 - fast and furious", target = 3 },
	{ id = "Ringout", name = "RINGOUT", desc = "Only knock-offs count - first to 3", target = 3, ringoutOnly = true },
	{ id = "Marathon", name = "MARATHON", desc = "First to 10 - the long haul", target = 10 },
}
local function modeById(id: string?): any
	for _, m in ipairs(MODES) do
		if m.id == id then
			return m
		end
	end
	return MODES[1]
end

-- set up and start a duel. `teams` holds the players on each side; empty
-- places up to `perteam` are filled with bots.
local function createDuel(kind: string, teams: { [string]: { Player } }, perTeam: number, mapId: string?, modeId: string?)
	local members: { [Player]: string } = {}
	for team, list in pairs(teams) do
		for _, p in ipairs(list) do
			members[p] = team
		end
	end
	local place = 1
	while places[place] do
		place += 1
	end
	places[place] = true
	local id = nextId
	nextId += 1
	local folder = Instance.new("Folder")
	folder.Name = "Duel" .. id
	folder.Parent = Workspace
	local origin = Vector3.new(4000 + place * 500, 150, -4000)
	local map = DuelMaps.Build(mapId, origin, folder)
	local mode = modeById(modeId)
	local botsNeeded = (perTeam - #teams.Blue) + (perTeam - #teams.Red)

	local duel: Duel = {
		id = id, place = place, kind = kind, map = map, folder = folder, center = origin,
		teams = teams, bots = { Blue = {}, Red = {} }, withBots = botsNeeded > 0,
		members = members, score = { Blue = 0, Red = 0 }, kos = {},
		endsAt = os.clock() + DUEL_SECONDS, over = false,
		target = mode.target, ringoutOnly = mode.ringoutOnly == true,
	}
	duels[id] = duel
	for p in pairs(members) do
		task.spawn(spawnIn, duel, p)
	end
	for _, team in ipairs({ "Blue", "Red" }) do
		for _ = #teams[team] + 1, perTeam do
			spawnBot(duel, team, #teams[team] + #duel.bots[team] + 1)
		end
	end
	send(duel, { started = true, mode = mode.name })
end

local function startDuel(pad: Pad)
	local teams: { [string]: { Player } } = { Blue = {}, Red = {} }
	for _, slot in ipairs(pad.slots) do
		local p = slot.player
		if p then
			table.insert(teams[slot.team], p)
		end
		slot.player = nil
	end
	pad.startAt = nil
	pad.waitingSince = nil
	createDuel(pad.kind, teams, #pad.slots // 2, nil, "Classic")
end

-- ── the play queue: 1v1 to 5v5 from the menu ─────────────────────────────────
-- search for a kind; once enough players are searching (or the first has
-- waited queue_bot_wait seconds) a match is found and bots fill the gaps.
-- everyone in it then votes a map, then a gamemode (vote_time each), and
-- the duel starts.
local QUEUE_KINDS = { ["1v1"] = 1, ["2v2"] = 2, ["3v3"] = 3, ["4v4"] = 4, ["5v5"] = 5 }
local QUEUE_BOT_WAIT = 15
local VOTE_TIME = 8
type Waiting = { player: Player, since: number }
local queues: { [string]: { Waiting } } = {}
type VoteLobby = { kind: string, players: { Player }, stage: string, options: { any }, endsAt: number, votes: { [Player]: string }, map: string? }
local voteLobbies: { VoteLobby } = {}

local function inVote(p: Player): VoteLobby?
	for _, l in ipairs(voteLobbies) do
		if table.find(l.players, p) then
			return l
		end
	end
	return nil
end

local function unqueue(p: Player)
	for _, q in pairs(queues) do
		for i = #q, 1, -1 do
			if q[i].player == p then
				table.remove(q, i)
			end
		end
	end
	if p.Parent then
		p:SetAttribute("DuelQueue", nil)
		Remotes.Get("QueueState"):FireClient(p, {})
	end
end

local function sendVote(l: VoteLobby)
	local counts: { [string]: number } = {}
	for _, choice in pairs(l.votes) do
		counts[choice] = (counts[choice] or 0) + 1
	end
	for _, p in ipairs(l.players) do
		if p.Parent then
			Remotes.Get("DuelVote"):FireClient(p, {
				stage = l.stage, kind = l.kind, options = l.options, endsAt = l.endsAt, votes = counts, myVote = l.votes[p],
			})
		end
	end
end

local function mapOptions(): { any }
	local opts = {}
	for _, def in ipairs(DuelMaps.List) do
		table.insert(opts, { id = def.Id, name = def.Name or def.Id })
	end
	table.insert(opts, { id = "Random", name = "RANDOM", desc = "Surprise me" })
	return opts
end

local function modeOptions(): { any }
	local opts = {}
	for _, m in ipairs(MODES) do
		table.insert(opts, { id = m.id, name = m.name, desc = m.desc })
	end
	table.insert(opts, { id = "Random", name = "RANDOM" })
	return opts
end

-- the most-voted option (a random one on a tie, or when nobody voted).
local function winner(l: VoteLobby): string
	local counts: { [string]: number } = {}
	local best, bestN = {}, 0
	for _, choice in pairs(l.votes) do
		counts[choice] = (counts[choice] or 0) + 1
	end
	for id, n in pairs(counts) do
		if n > bestN then
			best, bestN = { id }, n
		elseif n == bestN then
			table.insert(best, id)
		end
	end
	if #best == 0 then
		for _, o in ipairs(l.options) do
			table.insert(best, o.id)
		end
	end
	return best[math.random(1, #best)]
end

local function startVote(kind: string, players: { Player })
	local l: VoteLobby = { kind = kind, players = players, stage = "Map", options = mapOptions(), endsAt = workspace:GetServerTimeNow() + VOTE_TIME, votes = {} }
	table.insert(voteLobbies, l)
	sendVote(l)
end

local function closeVote(l: VoteLobby)
	for _, p in ipairs(l.players) do
		if p.Parent then
			Remotes.Get("DuelVote"):FireClient(p, {})
		end
	end
	local i = table.find(voteLobbies, l)
	if i then
		table.remove(voteLobbies, i)
	end
end

local function tickVotes()
	local now = workspace:GetServerTimeNow()
	for i = #voteLobbies, 1, -1 do
		local l = voteLobbies[i]
		for k = #l.players, 1, -1 do
			if not l.players[k].Parent or not eligible(l.players[k]) then
				table.remove(l.players, k)
			end
		end
		local voted = 0
		for _ in pairs(l.votes) do
			voted += 1
		end
		if #l.players == 0 then
			table.remove(voteLobbies, i)
		elseif now >= l.endsAt or voted >= #l.players then
			local pick = winner(l)
			if l.stage == "Map" then
				l.map = pick ~= "Random" and pick or nil
				l.stage = "Mode"
				l.options = modeOptions()
				l.votes = {}
				l.endsAt = now + VOTE_TIME
				sendVote(l)
			else
				closeVote(l)
				-- split the players into two teams (bots fill the rest).
				local per = QUEUE_KINDS[l.kind] or 1
				local teams: { [string]: { Player } } = { Blue = {}, Red = {} }
				for n, p in ipairs(l.players) do
					table.insert(teams[n % 2 == 1 and "Blue" or "Red"], p)
				end
				createDuel(l.kind, teams, per, l.map, pick == "Random" and MODES[math.random(1, #MODES)].id or pick)
			end
		end
	end
end

local function tickQueue()
	local now = os.clock()
	for kind, q in pairs(queues) do
		for i = #q, 1, -1 do
			local p = q[i].player
			if not p.Parent or not eligible(p) then
				table.remove(q, i)
				if p.Parent then
					unqueue(p)
				end
			end
		end
		local per = QUEUE_KINDS[kind]
		if #q > 0 and (#q >= per * 2 or now - q[1].since >= QUEUE_BOT_WAIT) then
			local players = {}
			while #players < per * 2 and #q > 0 do
				table.insert(players, table.remove(q, 1).player)
			end
			for _, p in ipairs(players) do
				p:SetAttribute("DuelQueue", nil)
				Remotes.Get("QueueState"):FireClient(p, {})
			end
			startVote(kind, players)
		end
	end
end

local function onQueue(p: Player, data: any)
	if typeof(data) ~= "table" then
		return
	end
	if data.leave then
		unqueue(p)
		return
	end
	local kind = data.join
	if type(kind) ~= "string" or not QUEUE_KINDS[kind] or not eligible(p) or inVote(p) then
		return
	end
	unqueue(p)
	queues[kind] = queues[kind] or {}
	table.insert(queues[kind], { player = p, since = os.clock() })
	p:SetAttribute("DuelQueue", kind)
	Remotes.Get("QueueState"):FireClient(p, { kind = kind, since = workspace:GetServerTimeNow() })
end

local function onVote(p: Player, data: any)
	local l = inVote(p)
	if not l or typeof(data) ~= "table" or type(data.choice) ~= "string" then
		return
	end
	for _, o in ipairs(l.options) do
		if o.id == data.choice then
			l.votes[p] = o.id
			sendVote(l)
			return
		end
	end
end

-- ── loop ─────────────────────────────────────────────────────────────────────
local function tickPads()
	local now = os.clock()
	local taken: { [Player]: boolean } = {}
	-- standing anywhere on a pad counts (not just the exact circle): which
	-- half you're on, or nil if you're off it.
	local function onPad(p: Player, pad: Pad): number?
		local root = p.Character and p.Character.PrimaryPart
		if not root then
			return nil
		end
		local off = root.Position - pad.center
		if math.abs(off.X) <= pad.w / 2 + 0.8 and math.abs(off.Z) <= pad.d / 2 + 0.8 and math.abs(off.Y) < 6 then
			return off.Z < 0 and -1 or 1
		end
		return nil
	end
	for _, pad in ipairs(pads) do
		for _, slot in ipairs(pad.slots) do
			local p = slot.player
			if p and (not p.Parent or not eligible(p) or not onPad(p, pad)) then
				slot.player = nil
			elseif p then
				taken[p] = true
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if not taken[p] and eligible(p) then
			for _, pad in ipairs(pads) do
				local side = not taken[p] and onPad(p, pad)
				if side then
					-- a free spot on the half you're on, else any free spot.
					local want = side < 0 and "Blue" or "Red"
					local pick: Slot? = nil
					for _, slot in ipairs(pad.slots) do
						if not slot.player and slot.team == want then
							pick = slot
							break
						end
					end
					if not pick then
						for _, slot in ipairs(pad.slots) do
							if not slot.player then
								pick = slot
								break
							end
						end
					end
					if pick then
						pick.player = p
						taken[p] = true
					end
				end
			end
		end
	end
	for _, pad in ipairs(pads) do
		local filled = 0
		for _, slot in ipairs(pad.slots) do
			slot.part.Color = slot.player and Color3.new(1, 1, 1):Lerp(TEAM_COLOR[slot.team], 0.4) or SPOT_EMPTY
			if slot.player then
				filled += 1
			end
		end
		local need = #pad.slots - filled
		local per = #pad.slots // 2
		for _, team in ipairs({ "Blue", "Red" }) do
			local n = 0
			for _, slot in ipairs(pad.slots) do
				if slot.team == team and slot.player then
					n += 1
				end
			end
			pad.counts[team].Text = n .. "/" .. per
		end
		pad.big.Visible = need == 0
		pad.counts.Blue.Visible = need > 0
		pad.counts.Red.Visible = need > 0
		if need > 0 then
			pad.startAt = nil
			if filled == 0 then
				pad.waitingSince = nil
				pad.sub.Text = "Step on a pad"
			else
				pad.waitingSince = pad.waitingSince or now
				local botIn = math.ceil(BOT_WAIT - (now - (pad.waitingSince :: number)))
				pad.sub.Text = "Waiting for " .. need .. " more  ·  vs BOT in " .. math.max(botIn, 0)
				if botIn <= 0 then
					startDuel(pad)
					pad.sub.Text = "Step on a pad"
				end
			end
		else
			pad.startAt = pad.startAt or (now + COUNTDOWN)
			local left = math.ceil((pad.startAt :: number) - now)
			pad.sub.Text = "Get ready!"
			pad.big.Text = tostring(math.max(left, 1))
			if now >= (pad.startAt :: number) then
				startDuel(pad)
				pad.sub.Text = "Step on a pad"
			end
		end
	end
end

local function tickDuels()
	local now = os.clock()
	for _, duel in pairs(duels) do
		if not duel.over then
			-- off the map = knocked out.
			for p in pairs(duel.members) do
				local s = Runtime.Get(p)
				local root = p.Character and p.Character.PrimaryPart
				if s and s.Alive and s.Context == "Duel" and s.DuelId == duel.id and root and root.Position.Y < duel.map.killY then
					PlayerService.HandleElimination(p, true)
				end
			end
			if now >= duel.endsAt then
				local b, r = duel.score.Blue, duel.score.Red
				finish(duel, b > r and "Blue" or r > b and "Red" or nil)
			end
		end
	end
end

-- the duels being played right now, for the lobby's duels live board:
-- "mochi  3 - 1  bob" (2v2: "a & b  2 - 2  c & d").
function DuelService.Live(): { string }
	local out = {}
	for _, d in pairs(duels) do
		if not d.over then
			local function side(team: string): string
				local names = {}
				for _, p in ipairs(d.teams[team] or {}) do
					table.insert(names, p.DisplayName)
				end
				for _, n in ipairs(d.bots[team] or {}) do
					table.insert(names, n)
				end
				return #names > 0 and table.concat(names, " & ") or "?"
			end
			table.insert(out, string.format("%s  %d - %d  %s", side("Blue"), d.score.Blue or 0, d.score.Red or 0, side("Red")))
		end
	end
	return out
end

function DuelService.Start()
	LobbyService.LiveDuels = DuelService.Live
	local folder = Instance.new("Folder")
	folder.Name = "DuelPads"
	folder.Parent = Workspace:WaitForChild("Lobby")
	for _, def in ipairs(LobbyService.DuelPads) do
		buildPad(def, folder)
	end
	PlayerService.OnDuelKO = onDuelKO
	Players.PlayerRemoving:Connect(leave)
	Players.PlayerRemoving:Connect(unqueue)
	Remotes.Get("DuelQueue").OnServerEvent:Connect(onQueue)
	Remotes.Get("DuelVote").OnServerEvent:Connect(onVote)

	local padAcc, duelAcc = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		padAcc += dt
		duelAcc += dt
		if duelAcc >= 0.1 then
			duelAcc = 0
			tickDuels()
		end
		if padAcc >= 0.2 then
			padAcc = 0
			tickPads()
			tickQueue()
			tickVotes()
		end
	end)
	-- the clock for everyone in a duel, once a second.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, duel in pairs(duels) do
				if not duel.over then
					send(duel)
				end
			end
		end
	end)
end

return DuelService
