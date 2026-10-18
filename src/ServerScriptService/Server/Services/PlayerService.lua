--!strict
-- PlayerService: owns the cat character lifecycle — spawning custom cat rigs,
-- team assignment, respawns, spawn protection, and kill-floor ("ringout")
-- detection which is the payoff of the knockback mechanic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local CatBuilder = require(Shared.Character.CatBuilder)
local Remotes = require(Shared.Net.Remotes)
local Progression = require(Shared.Config.Progression)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Runtime = require(script.Parent.Runtime)
local Analytics = require(script.Parent.Analytics)

local PlayerService = {}

local spawnsFolder: Folder? = nil

-- MatchService sets this so we only ringout-eliminate during live play.
PlayerService.MatchActive = false
-- Set by DuelService: a knockout inside a duel (not a match elimination).
PlayerService.OnDuelKO = nil :: ((victim: Player, killer: Player?, ringout: boolean) -> ())?
-- Set by LobbyService: someone reset in the lobby.
PlayerService.OnLobbyDeath = nil :: ((player: Player) -> ())?
-- Set by MatchService to award team points on elimination.
PlayerService.OnElimination = nil :: ((victim: Player, killer: Player?, weaponId: string?, ringout: boolean) -> ())?

local function getSpawns(): Folder
	if spawnsFolder and spawnsFolder.Parent then
		return spawnsFolder
	end
	local arena = Workspace:FindFirstChild("Arena")
	local s = arena and arena:FindFirstChild("Spawns")
	spawnsFolder = s :: Folder
	return spawnsFolder :: Folder
end

-- Pick a spawn point for a team, biased away from other players.
-- When each spawn was last used, so teammates spread over all three.
local lastUsed: { [BasePart]: number } = setmetatable({}, { __mode = "k" }) :: any

-- Distance from `pos` to the nearest living enemy cat (players and bots).
local function enemyDistance(pos: Vector3, teamId: string?): number
	local best = 200
	for _, m in ipairs(CollectionService:GetTagged(CatBuilder.Tag)) do
		local r = m:IsA("Model") and m.PrimaryPart
		local hum = r and m:FindFirstChildOfClass("Humanoid")
		local team = m:GetAttribute("Team")
		if r and hum and hum.Health > 0 and team ~= nil and m:IsDescendantOf(Workspace) and (Runtime.Mode == "FFA" or team ~= teamId) then
			best = math.min(best, (r.Position - pos).Magnitude)
		end
	end
	return best
end

local function pickSpawn(teamId: string?): CFrame
	local spawns = getSpawns()
	if not spawns then
		return CFrame.new(0, 30, 0)
	end
	local candidates = {}
	for _, s in ipairs(spawns:GetChildren()) do
		if s:IsA("BasePart") then
			local tag = s:GetAttribute("Team")
			if tag == nil or tag == teamId then
				table.insert(candidates, s)
			end
		end
	end
	if #candidates == 0 then
		for _, s in ipairs(spawns:GetChildren()) do
			if s:IsA("BasePart") then
				table.insert(candidates, s)
			end
		end
	end
	if #candidates == 0 then
		return CFrame.new(0, 30, 0)
	end
	-- Prefer the spawn furthest from enemies that a teammate didn't just use,
	-- with a little randomness so it isn't predictable.
	local chosen, bestScore = candidates[1], -math.huge
	local now = os.clock()
	for _, s in ipairs(candidates) do
		local score = math.min(enemyDistance(s.Position, teamId), 80) + math.random() * 20
		if now - (lastUsed[s] or -100) < 4 then
			score -= 60
		end
		if score > bestScore then
			chosen, bestScore = s, score
		end
	end
	lastUsed[chosen] = now
	-- Spawn just above the marker so the root lands on the island surface
	-- instead of visibly dropping in from several studs overhead.
	return chosen.CFrame + Vector3.new(0, 1.25, 0)
end

PlayerService.PickSpawn = pickSpawn

-- Assign the player to the smaller team.
function PlayerService.AssignTeam(player: Player)
	local state = Runtime.Ensure(player)
	if state.Team then
		return state.Team
	end
	local counts = {}
	for _, t in ipairs(GameConfig.Match.Teams) do
		counts[t.Id] = 0
	end
	for _, other in ipairs(Players:GetPlayers()) do
		local os_ = Runtime.Get(other)
		if os_ and os_.Team and counts[os_.Team] then
			counts[os_.Team] += 1
		end
	end
	local best, bestCount = GameConfig.Match.Teams[1].Id, math.huge
	for _, t in ipairs(GameConfig.Match.Teams) do
		if counts[t.Id] < bestCount then
			best, bestCount = t.Id, counts[t.Id]
		end
	end
	state.Team = best
	return best
end

local function teamColor(teamId: string?): Color3
	for _, t in ipairs(GameConfig.Match.Teams) do
		if t.Id == teamId then
			return t.Color
		end
	end
	return Color3.fromRGB(200, 200, 200)
end

-- Build + spawn a cat for the player using their saved loadout.
--   opts.context: "Match" (default: the arena, on their team), "Lobby" or
--   "Duel"; opts.team / opts.cframe place lobby and duel cats.
function PlayerService.Spawn(player: Player, opts: any?)
	local context = (opts and opts.context) or "Match"
	if context == "Match" and PlayerService.MatchActive then
		Analytics.Step(player, "FirstMatchStarted")
	end
	local profile = DataService.Get(player)
	local cat = profile and profile.Loadout.Cat or nil
	local teamId = (opts and opts.team) or (context == "Match" and PlayerService.AssignTeam(player)) or "Lobby"
	local spawnAt: CFrame = (opts and opts.cframe) or PlayerService.PickSpawn(teamId)
	-- If streaming is on, send the player the ground there before the cat
	-- lands on it (the lobby and duels are far from where they joined).
	pcall(function()
		player:RequestStreamAroundAsync(spawnAt.Position, 5)
	end)
	if not player.Parent then
		return nil
	end

	-- Clean up previous character.
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end

	local loadout = profile and profile.Loadout
	local weapon = { Id = loadout and loadout.Weapon or "PawBlaster", Skin = loadout and loadout.Skin or nil }
	local model = CatBuilder.Build(cat, player.DisplayName, weapon)
	model.Name = player.Name

	-- Team accent ring under the cat for readability (not in the lobby).
	local root = model.PrimaryPart :: BasePart
	local ring = Instance.new("Part")
	ring.Name = "TeamRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 3.2, 3.2)
	ring.Color = teamColor(teamId)
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.4
	ring.CanCollide = false
	ring.CanQuery = false
	ring.Massless = true
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = ring
	weld.C0 = CFrame.new(0, -1.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	weld.Parent = ring
	ring.Parent = context ~= "Lobby" and model or nil

	model:SetAttribute("Team", teamId)
	model:PivotTo(spawnAt)
	print(string.format("[PAW MAYHEM] %s spawned (%s) at %s", player.Name, context, tostring(spawnAt.Position)))
	model.Parent = Workspace

	player.Character = model

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	Runtime.ResetLife(player)
	Runtime.SetContext(player, context, opts and opts.duelId, opts and opts.team)
	local state = Runtime.Ensure(player)
	state.Alive = true
	state.SpawnProtectUntil = os.clock() + 2.0
	state.SpawnedAt = os.clock()
	state.LifeWeapon = weapon.Id
	model:SetAttribute("Weapon", weapon.Id)

	-- Death (from HP reaching 0) -> elimination by last attacker.
	humanoid.Died:Connect(function()
		PlayerService.HandleElimination(player, false)
	end)

	Remotes.Get("ProfileUpdate") -- ensure remote exists
	return model
end

-- The player changed their loadout. In the lobby, or in the first few seconds
-- of a life, their cat gets it straight away (a new blaster in its paws; a
-- new look rebuilds the cat on the spot in the lobby). Otherwise it's theirs
-- from the next respawn.
local LOADOUT_GRACE = 5
local rebuildToken: { [Player]: number } = {}
function PlayerService.ApplyLoadout(player: Player, kind: string)
	local s = Runtime.Get(player)
	local char = player.Character
	local profile = DataService.Get(player)
	if not (s and s.Alive and char and profile) then
		return
	end
	local lobby = s.Context == "Lobby"
	local now = lobby or os.clock() - (s.SpawnedAt or 0) <= LOADOUT_GRACE
	if kind == "Weapon" or kind == "Skin" then
		if not now or s.WeaponOverride then
			Remotes.Get("Notify"):FireClient(player, { text = "Equipped - yours from your next respawn.", kind = "info" })
			return
		end
		local loadout = profile.Loadout
		s.LifeWeapon = loadout.Weapon
		char:SetAttribute("Weapon", loadout.Weapon)
		CatBuilder.SetBlaster(char, { Id = loadout.Weapon, Skin = loadout.Skin })
	elseif lobby and (kind == "Fur" or kind == "Outfit" or kind == "Hat" or kind == "Accessory") then
		-- Rebuild once the clicking settles.
		local token = (rebuildToken[player] or 0) + 1
		rebuildToken[player] = token
		task.delay(0.6, function()
			local st = Runtime.Get(player)
			local c = player.Character
			if rebuildToken[player] == token and st and st.Alive and st.Context == "Lobby" and c then
				PlayerService.Spawn(player, { context = "Lobby", team = "Lobby", cframe = c:GetPivot() })
			end
		end)
	end
end

-- Where each cat left the ground last: updated while it's standing (or still
-- about level with where it stood), so when it falls off the map the ringout
-- burst goes off where it actually went over the edge.
local edge: { [Player]: { pos: Vector3, groundY: number } } = {}
function PlayerService.EdgeOf(player: Player): Vector3?
	local e = edge[player]
	return e and e.pos
end

local function trackEdges()
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		local root = char and char.PrimaryPart
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if root and hum then
			local e = edge[player]
			if hum.FloorMaterial ~= Enum.Material.Air or not e then
				edge[player] = { pos = root.Position, groundY = root.Position.Y }
			elseif root.Position.Y >= e.groundY - 10 then
				e.pos = root.Position
			end
		end
	end
end

-- Everyone near enough sees a big burst where a cat flew off the map.
function PlayerService.RingoutBurst(position: Vector3, color: Color3?)
	Remotes.Get("PlayEffect"):FireAllClients({ kind = "Ringout", position = position, color = color })
end

-- Central elimination handler (HP death or ringout).
function PlayerService.HandleElimination(victim: Player, ringout: boolean)
	local state = Runtime.Get(victim)
	if not state or not state.Alive then
		return
	end
	state.Alive = false

	-- The knockout burst: where it went over the edge (ringout) or where it
	-- dropped (HP).
	local char = victim.Character
	local root = char and char.PrimaryPart
	local at = ringout and PlayerService.EdgeOf(victim) or (root and root.Position)
	if at and state.Context ~= "Lobby" then -- (a reset in the lobby is no knockout)
		PlayerService.RingoutBurst(at, teamColor(char and char:GetAttribute("Team") or "Lobby"))
		if state.Context == "Match" then
			Runtime.LastKO = { t = os.clock(), position = at }
		end
	end

	local killer = state.LastAttacker
	-- Ringout with no recent attacker = self-elimination.
	local weaponId = nil
	if killer == victim then
		killer = nil
	end

	-- Duels score their own knockouts; the lobby has none (a reset there
	-- just puts you back).
	if state.Context == "Duel" then
		if PlayerService.OnDuelKO then
			PlayerService.OnDuelKO(victim, killer, ringout)
		end
		return
	elseif state.Context ~= "Match" then
		if PlayerService.OnLobbyDeath then
			PlayerService.OnLobbyDeath(victim)
		end
		return
	end

	if PlayerService.OnElimination then
		PlayerService.OnElimination(victim, killer, weaponId, ringout)
	end

	-- Respawn after delay if match still active (and they're still in it).
	task.delay(GameConfig.Character.RespawnDelay, function()
		local s = Runtime.Get(victim)
		if Players:FindFirstChild(victim.Name) and PlayerService.MatchActive and s and s.Context == "Match" then
			PlayerService.Spawn(victim)
		end
	end)
end

-- Kill-floor watcher: launched cats that fall below the arena are eliminated.
local function startKillFloorLoop()
	RunService.Heartbeat:Connect(function()
		if not PlayerService.MatchActive then
			return
		end
		-- Map events (Volcano's rising lava) can raise the floor.
		local raised = Workspace:GetAttribute("KillFloorY")
		local arena = Workspace:FindFirstChild("Arena")
		local mapFloor = arena and arena:GetAttribute("KillFloorY")
		local floorY = math.max(GameConfig.Character.KillFloorY, typeof(raised) == "number" and raised or -math.huge, typeof(mapFloor) == "number" and mapFloor or -math.huge)
		for _, player in ipairs(Players:GetPlayers()) do
			local state = Runtime.Get(player)
			local char = player.Character
			if state and state.Alive and state.Context == "Match" and char and char.PrimaryPart then
				if char.PrimaryPart.Position.Y < floorY then
					PlayerService.HandleElimination(player, true)
				end
			end
		end
	end)
end

-- Status loop: publishes SpeedMult (read by the client MovementController) and
-- Fluff (the knockback % shown above each cat) on each character, regenerates
-- health once a cat stops taking hits, and expires power-ups.
local function startStatusLoop()
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local state = Runtime.Get(player)
			local char = player.Character
			if state and char then
				local fluff = math.floor(state.Accumulated)
				if char:GetAttribute("Fluff") ~= fluff then
					char:SetAttribute("Fluff", fluff)
				end
				local hum = char:FindFirstChildOfClass("Humanoid")
				if state.Alive and hum and hum.Health > 0 and hum.Health < hum.MaxHealth
					and now - (state.LastAttackAt or 0) > GameConfig.Regen.Delay then
					hum.Health = math.min(hum.MaxHealth, hum.Health + GameConfig.Regen.PerSecond * dt)
				end
				local mult = 1.0
				if now < (state.SlowUntil or 0) then
					mult *= 0.6
				end
				if state.PowerUp then
					if now < state.PowerUp.Expires then
						local p = Progression.PowerUpById[state.PowerUp.Id]
						if p and p.SpeedMult then
							mult *= p.SpeedMult
						end
					else
						state.PowerUp = nil
					end
				end
				if char:GetAttribute("SpeedMult") ~= mult then
					char:SetAttribute("SpeedMult", mult)
				end
			end
		end
	end)
end

function PlayerService.DespawnAll()
	-- Only the match's cats: people in the lobby or a duel stay put.
	for _, player in ipairs(Players:GetPlayers()) do
		local state = Runtime.Get(player)
		if not state or state.Context ~= "Match" then
			continue
		end
		state.Alive = false
		if player.Character then
			player.Character:Destroy()
			player.Character = nil
		end
	end
end

function PlayerService.SpawnAll()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(PlayerService.Spawn, player)
	end
end

function PlayerService.Start()
	Players.CharacterAutoLoads = false

	Remotes.Get("RequestRespawn").OnServerEvent:Connect(function(player)
		local state = Runtime.Get(player)
		if PlayerService.MatchActive and state and not state.Alive and state.Context == "Match" then
			-- allow manual respawn only after death, throttled by delay handled elsewhere
			PlayerService.Spawn(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		Runtime.Remove(player)
		rebuildToken[player] = nil
	end)
	EconomyService.OnEquipped = PlayerService.ApplyLoadout

	startKillFloorLoop()
	local edgeAcc = 0
	RunService.Heartbeat:Connect(function(dt)
		edgeAcc += dt
		if edgeAcc >= 0.05 then
			edgeAcc = 0
			trackEdges()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		edge[player] = nil
	end)
	startStatusLoop()
end

return PlayerService
