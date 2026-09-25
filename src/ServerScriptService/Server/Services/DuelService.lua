--!strict
-- DuelService: 1v1 and 2v2 duels from the lobby's duel pads (straight ahead
-- of spawn). Stand on a glowing slot; once every slot on a pad is taken a
-- short countdown starts (step off to cancel) and everyone on it is sent to
-- their own duel on a random duel map (DuelMaps). First side to 5 knockouts
-- wins, or whoever leads when the clock runs out. Trophies, coins and XP like
-- a match, then everyone's back in the lobby. Duels run side by side, each on
-- its own copy of a map far from the lobby and the arena.

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

local TEAM_COLOR = { Blue = Color3.fromRGB(70, 150, 255), Red = Color3.fromRGB(255, 80, 90) }

type Slot = { team: string, pos: Vector3, part: BasePart, player: Player? }
type Pad = { kind: string, slots: { Slot }, title: TextLabel, sub: TextLabel, startAt: number? }
type Duel = {
	id: number,
	place: number,
	kind: string,
	map: DuelMaps.Layout,
	folder: Folder,
	teams: { [string]: { Player } },
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
	local center = at(def.x, def.z)
	local is2v2 = def.kind == "2v2"
	local d = is2v2 and 15 or 12
	local base = ArenaKit.NewDisc("DuelPad", d, 0.5, center + Vector3.new(0, 0.2, 0), Color3.fromRGB(226, 220, 208), Enum.Material.Marble, parent)
	base.CanCollide = false
	local rim = ArenaKit.NewDisc("DuelPadRim", d + 0.8, 0.3, center + Vector3.new(0, 0.12, 0), Color3.fromRGB(60, 58, 70), Enum.Material.Slate, parent)
	rim.CanCollide = false

	local pad: Pad = { kind = def.kind, slots = {}, title = nil :: any, sub = nil :: any, startAt = nil }
	local offsets = is2v2 and { { "Blue", -3.6, -2.5 }, { "Blue", -3.6, 2.5 }, { "Red", 3.6, -2.5 }, { "Red", 3.6, 2.5 } }
		or { { "Blue", -3, 0 }, { "Red", 3, 0 } }
	for _, o in ipairs(offsets) do
		local pos = center + Vector3.new(o[2], 0, o[3])
		local slot = ArenaKit.NewDisc("Slot", 4.2, 0.2, pos + Vector3.new(0, 0.5, 0), TEAM_COLOR[o[1]], Enum.Material.Neon, parent)
		slot.CanCollide = false
		slot.CanQuery = false
		slot.Transparency = 0.55
		table.insert(pad.slots, { team = o[1], pos = pos, part = slot, player = nil })
	end

	-- Floating label: "1V1" and what the pad is waiting for.
	local anchor = ArenaKit.NewPart("PadLabel", Vector3.new(0.2, 0.2, 0.2), CFrame.new(center + Vector3.new(0, 6, 0)), Color3.new(1, 1, 1), nil, parent)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(220, 80)
	bb.MaxDistance = 90
	bb.LightInfluence = 0
	bb.Parent = anchor
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 46)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 42
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Text = string.upper(def.kind)
	title.Parent = bb
	local sub = Instance.new("TextLabel")
	sub.BackgroundTransparency = 1
	sub.Position = UDim2.fromOffset(0, 46)
	sub.Size = UDim2.new(1, 0, 0, 26)
	sub.Font = Enum.Font.GothamBold
	sub.TextSize = 18
	sub.TextColor3 = Color3.fromRGB(255, 226, 120)
	sub.TextStrokeTransparency = 0.4
	sub.Text = "Step on a pad"
	sub.Parent = bb
	pad.title, pad.sub = title, sub
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
	end
	for p, team in pairs(duel.members) do
		if p.Parent then
			local data: { [string]: any } = {
				id = duel.id, kind = duel.kind, map = duel.map.name, teams = names, score = duel.score,
				target = TARGET, timeLeft = math.max(0, math.floor(duel.endsAt - os.clock())), myTeam = team,
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
	for p, team in pairs(duel.members) do
		if p.Parent and inThisDuel(p, duel) then
			local won = winner == team
			local delta = 0
			local profile = DataService.Get(p)
			local stats = profile and profile.Stats
			-- A draw leaves trophies alone.
			if stats and winner then
				local before = stats.Trophies or 0
				stats.Trophies = math.max(0, before + Ranks.Delta(won, duel.kos[p] or 0))
				delta = stats.Trophies - before
			end
			EconomyService.AddXP(p, won and WIN_XP or LOSS_XP)
			EconomyService.AddCoins(p, won and WIN_COINS or LOSS_COINS)
			SeasonService.AddXP(p, "MatchPlayed")
			EconomyService.Push(p)
			Remotes.Get("DuelState"):FireClient(p, {
				id = duel.id, over = true, winner = winner, won = won, draw = winner == nil,
				forfeit = forfeit == true, trophies = delta, score = duel.score, myTeam = team,
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

local function startDuel(pad: Pad)
	local teams: { [string]: { Player } } = { Blue = {}, Red = {} }
	local members: { [Player]: string } = {}
	for _, slot in ipairs(pad.slots) do
		local p = slot.player
		if p then
			table.insert(teams[slot.team], p)
			members[p] = slot.team
		end
		slot.player = nil
	end
	pad.startAt = nil

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
		id = id, place = place, kind = pad.kind, map = map, folder = folder,
		teams = teams, members = members, score = { Blue = 0, Red = 0 }, kos = {},
		endsAt = os.clock() + DUEL_SECONDS, over = false,
	}
	duels[id] = duel
	for p in pairs(members) do
		task.spawn(spawnIn, duel, p)
	end
	send(duel, { started = true })
end

-- A cat in a duel was knocked out (HP or off the map): the other side scores.
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
	local scorer = other(team)
	duel.score[scorer] += 1
	if killer and duel.members[killer] and duel.members[killer] ~= team then
		duel.kos[killer] = (duel.kos[killer] or 0) + 1
		EconomyService.AddStat(killer, "Eliminations", 1)
	end
	for p in pairs(duel.members) do
		if p.Parent then
			Remotes.Get("KillFeed"):FireClient(p, {
				killer = killer and killer.DisplayName or "☠", killerTeam = scorer,
				victim = victim.DisplayName, victimTeam = team, ringout = ringout,
			})
		end
	end
	if duel.score[scorer] >= TARGET then
		send(duel)
		finish(duel, scorer)
		return
	end
	send(duel, { ko = victim.DisplayName })
	task.delay(GameConfig.Character.RespawnDelay, function()
		if inThisDuel(victim, duel) then
			spawnIn(duel, victim)
		end
	end)
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
		if need > 0 then
			pad.startAt = nil
			pad.sub.Text = filled == 0 and "Step on a pad" or ("Waiting for " .. need .. " more")
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
