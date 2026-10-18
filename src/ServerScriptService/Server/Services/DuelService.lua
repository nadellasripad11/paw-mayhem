--!strict
-- DuelService: 1v1 and 2v2 duels from the lobby's duel pads (straight ahead
-- of spawn). Stand on a glowing slot; once every slot on a pad is taken a
-- short countdown starts (step off to cancel) and everyone on it is sent to
-- their own duel on a random duel map (DuelMaps). First side to 5 knockouts
-- wins, or whoever leads when the clock runs out. Trophies, coins and XP like
-- a match, then everyone's back in the lobby. Duels run side by side, each on
-- its own copy of a map far from the lobby and the arena.
-- Nobody coming? After 15 seconds on a pad, bots fill the empty slots. Bot
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
type Pad = { kind: string, slots: { Slot }, count: TextLabel, sub: TextLabel, startAt: number?, waitingSince: number? }
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
}

local pads: { Pad } = {}
local duels: { [number]: Duel } = {}
local places: { [number]: boolean } = {} -- which far-away build spots are in use
local nextId = 1

local function other(team: string): string
	return team == "Blue" and "Red" or "Blue"
end

-- ── the pads in the lobby ────────────────────────────────────────────────────
local function buildPad(def: any, parent: Instance)
	local at = LobbyService.At
	local is2v2 = def.kind == "2v2"
	local w, d = is2v2 and 12.5 or 12, is2v2 and 11 or 8.5
	local center = at(def.x, def.z)
	local function deco(p: BasePart): BasePart
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end

	-- The pad: a dark plate, blue half and red half, glowing border, and a
	-- round slot for each player.
	deco(ArenaKit.NewPart("DuelPad", Vector3.new(w, 0.3, d), CFrame.new(center + Vector3.new(0, 0.15, 0)), Color3.fromRGB(26, 30, 48), Enum.Material.SmoothPlastic, parent))
	for _, half in ipairs({ { "Blue", -1 }, { "Red", 1 } }) do
		local tint = deco(ArenaKit.NewPart("PadHalf", Vector3.new(w / 2 - 0.6, 0.05, d - 0.6), CFrame.new(center + Vector3.new(half[2] * w / 4, 0.32, 0)), TEAM_COLOR[half[1]], Enum.Material.SmoothPlastic, parent))
		tint.Transparency = 0.6
	end
	for _, e in ipairs({ { 0, d / 2, w, 0.25 }, { 0, -d / 2, w, 0.25 }, { w / 2, 0, 0.25, d }, { -w / 2, 0, 0.25, d } }) do
		deco(ArenaKit.NewPart("PadEdge", Vector3.new(e[3], 0.12, e[4]), CFrame.new(center + Vector3.new(e[1], 0.34, e[2])), Color3.fromRGB(200, 206, 222), Enum.Material.SmoothPlastic, parent))
	end
	deco(ArenaKit.NewPart("PadSplit", Vector3.new(0.2, 0.1, d - 1), CFrame.new(center + Vector3.new(0, 0.34, 0)), Color3.fromRGB(200, 206, 222), Enum.Material.SmoothPlastic, parent)).Transparency = 0.4

	local pad: Pad = { kind = def.kind, slots = {}, count = nil :: any, sub = nil :: any, startAt = nil }
	local offsets = is2v2 and { { "Blue", -3.2, -2.6 }, { "Blue", -3.2, 2.6 }, { "Red", 3.2, -2.6 }, { "Red", 3.2, 2.6 } }
		or { { "Blue", -3, 0 }, { "Red", 3, 0 } }
	for _, o in ipairs(offsets) do
		local pos = center + Vector3.new(o[2], 0, o[3])
		local slot = deco(ArenaKit.NewDisc("Slot", 4, 0.2, pos + Vector3.new(0, 0.4, 0), TEAM_COLOR[o[1]], Enum.Material.SmoothPlastic, parent))
		slot.Transparency = 0.55
		table.insert(pad.slots, { team = o[1], pos = pos, part = slot, player = nil })
	end

	-- A screen on the side wall: the mode, how many are on it, and what it's
	-- waiting for.
	local wallX = def.screenX or def.wall * 16.75
	local screenPos = at(wallX, def.z, 7)
	local face = CFrame.lookAt(screenPos, screenPos + Vector3.new(-def.wall, 0, 0))
	deco(ArenaKit.NewPart("ScreenEdge", Vector3.new(8.6, 5.6, 0.15), face * CFrame.new(0, 0, 0.2), is2v2 and Color3.fromRGB(170, 110, 255) or Color3.fromRGB(60, 210, 255), Enum.Material.SmoothPlastic, parent))
	local screen = deco(ArenaKit.NewPart("PadScreen", Vector3.new(8, 5, 0.3), face, Color3.fromRGB(14, 18, 30), Enum.Material.SmoothPlastic, parent))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 40
	gui.Parent = screen
	local function label(text: string, y: number, h: number, font: Enum.Font, color: Color3): TextLabel
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Position = UDim2.fromScale(0, y)
		t.Size = UDim2.fromScale(1, h)
		t.Font = font
		t.TextScaled = true
		t.TextColor3 = color
		t.Text = text
		t.Parent = gui
		return t
	end
	label(string.upper(def.kind), 0.05, 0.22, Enum.Font.FredokaOne, is2v2 and Color3.fromRGB(200, 160, 255) or Color3.fromRGB(120, 220, 255))
	pad.count = label("0/" .. #pad.slots, 0.27, 0.45, Enum.Font.GothamBlack, Color3.new(1, 1, 1))
	pad.sub = label("Step on a pad", 0.76, 0.17, Enum.Font.GothamBold, Color3.fromRGB(255, 226, 120))
	table.insert(pads, pad)
end

-- Can this player take a pad slot right now?
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
				target = TARGET, timeLeft = math.max(0, math.floor(duel.endsAt - os.clock())), myTeam = team,
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
	PlayerService.Spawn(p, { context = "Duel", team = team, duelId = duel.id, cframe = spots[(index - 1) % #spots + 1] })
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
	for p, team in pairs(duel.members) do
		if p.Parent and inThisDuel(p, duel) then
			local won = winner == team
			local delta = 0
			local profile = DataService.Get(p)
			local stats = profile and profile.Stats
			-- A draw (or a duel with bots) leaves trophies alone.
			if stats and winner and not duel.withBots then
				local before = stats.Trophies or 0
				stats.Trophies = math.max(0, before + Ranks.Delta(won, duel.kos[p] or 0))
				delta = stats.Trophies - before
			end
			EconomyService.AddXP(p, math.floor((won and WIN_XP or LOSS_XP) * pay))
			EconomyService.AddCoins(p, math.floor((won and WIN_COINS or LOSS_COINS) * pay))
			SeasonService.AddXP(p, "MatchPlayed")
			EconomyService.Push(p)
			Remotes.Get("DuelState"):FireClient(p, {
				id = duel.id, over = true, winner = winner, won = won, draw = winner == nil,
				forfeit = forfeit == true, trophies = delta, score = duel.score, myTeam = team, withBots = duel.withBots,
			})
		end
	end
	-- A moment to celebrate, then everyone's back in the lobby.
	task.delay(4, function()
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

-- Someone on `team` was knocked out (HP or off the map): the other side
-- scores. Returns true while the duel goes on (so they respawn).
local function scoreKO(duel: Duel, team: string, victimName: string, killer: Player?, ringout: boolean): boolean
	local scorer = other(team)
	duel.score[scorer] += 1
	if killer and duel.members[killer] and duel.members[killer] ~= team then
		duel.kos[killer] = (duel.kos[killer] or 0) + 1
		EconomyService.AddStat(killer, "Eliminations", 1)
	end
	local botKiller = #duel.bots[scorer] > 0 and #duel.teams[scorer] == 0 and duel.bots[scorer][1] or nil
	for p in pairs(duel.members) do
		if p.Parent then
			Remotes.Get("KillFeed"):FireClient(p, {
				killer = killer and killer.DisplayName or botKiller or "☠", killerTeam = scorer,
				victim = victimName, victimTeam = team, ringout = ringout,
			})
		end
	end
	if duel.score[scorer] >= TARGET then
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

-- Bring a duel's bot (back) in on its side.
local function spawnBot(duel: Duel, team: string, index: number, name: string?)
	if duel.over then
		return
	end
	local spots = duel.map.spawns[team]
	local info: BotService.DuelInfo
	info = {
		id = duel.id,
		spawn = spots[(index - 1) % #spots + 1],
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

local function startDuel(pad: Pad)
	local teams: { [string]: { Player } } = { Blue = {}, Red = {} }
	local members: { [Player]: string } = {}
	local botSlots: { string } = {} -- empty slots bots take
	for _, slot in ipairs(pad.slots) do
		local p = slot.player
		if p then
			table.insert(teams[slot.team], p)
			members[p] = slot.team
		else
			table.insert(botSlots, slot.team)
		end
		slot.player = nil
	end
	pad.startAt = nil
	pad.waitingSince = nil

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
	local map = DuelMaps.BuildRandom(origin, folder)

	local duel: Duel = {
		id = id, place = place, kind = pad.kind, map = map, folder = folder, center = origin,
		teams = teams, bots = { Blue = {}, Red = {} }, withBots = #botSlots > 0,
		members = members, score = { Blue = 0, Red = 0 }, kos = {},
		endsAt = os.clock() + DUEL_SECONDS, over = false,
	}
	duels[id] = duel
	for p in pairs(members) do
		task.spawn(spawnIn, duel, p)
	end
	for _, team in ipairs(botSlots) do
		spawnBot(duel, team, #teams[team] + #duel.bots[team] + 1)
	end
	send(duel, { started = true })
end

-- ── loop ─────────────────────────────────────────────────────────────────────
local function tickPads()
	local now = os.clock()
	local taken: { [Player]: boolean } = {}
	for _, pad in ipairs(pads) do
		for _, slot in ipairs(pad.slots) do
			local p = slot.player
			if p and (not p.Parent or not eligible(p) or not onSlot(p, slot)) then
				slot.player = nil
			elseif p then
				taken[p] = true
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if not taken[p] and eligible(p) then
			for _, pad in ipairs(pads) do
				for _, slot in ipairs(pad.slots) do
					if not taken[p] and not slot.player and onSlot(p, slot) then
						slot.player = p
						taken[p] = true
					end
				end
			end
		end
	end
	for _, pad in ipairs(pads) do
		local filled = 0
		for _, slot in ipairs(pad.slots) do
			slot.part.Transparency = slot.player and 0.05 or 0.55
			if slot.player then
				filled += 1
			end
		end
		local need = #pad.slots - filled
		pad.count.Text = filled .. "/" .. #pad.slots
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
			pad.sub.Text = "Starting in " .. math.max(left, 1)
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
			-- Off the map = knocked out.
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

function DuelService.Start()
	local folder = Instance.new("Folder")
	folder.Name = "DuelPads"
	folder.Parent = Workspace:WaitForChild("Lobby")
	for _, def in ipairs(LobbyService.DuelPads) do
		buildPad(def, folder)
	end
	PlayerService.OnDuelKO = onDuelKO
	Players.PlayerRemoving:Connect(leave)

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
		end
	end)
	-- The clock for everyone in a duel, once a second.
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
