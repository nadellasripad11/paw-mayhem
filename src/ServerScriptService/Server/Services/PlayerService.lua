--!strict
-- PlayerService: owns the cat character lifecycle — spawning custom cat rigs,
-- team assignment, respawns, spawn protection, and kill-floor ("ringout")
-- detection which is the payoff of the knockback mechanic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local CatBuilder = require(Shared.Character.CatBuilder)
local Remotes = require(Shared.Net.Remotes)
local Progression = require(Shared.Config.Progression)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Runtime = require(script.Parent.Runtime)

local PlayerService = {}

local spawnsFolder: Folder? = nil

-- MatchService sets this so we only ringout-eliminate during live play.
PlayerService.MatchActive = false
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
	local chosen = candidates[math.random(1, #candidates)]
	return chosen.CFrame + Vector3.new(0, 4, 0)
end

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
function PlayerService.Spawn(player: Player)
	local profile = DataService.Get(player)
	local cat = profile and profile.Loadout.Cat or nil
	local teamId = PlayerService.AssignTeam(player)

	-- Clean up previous character.
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end

	local model = CatBuilder.Build(cat, player.DisplayName)
	model.Name = player.Name

	-- Team accent ring under the cat for readability.
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
	ring.Parent = model

	model:SetAttribute("Team", teamId)
	model:PivotTo(pickSpawn(teamId))
	model.Parent = Workspace

	player.Character = model

	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	Runtime.ResetLife(player)
	local state = Runtime.Ensure(player)
	state.Alive = true
	state.SpawnProtectUntil = os.clock() + 2.0

	-- Death (from HP reaching 0) -> elimination by last attacker.
	humanoid.Died:Connect(function()
		PlayerService.HandleElimination(player, false)
	end)

	Remotes.Get("ProfileUpdate") -- ensure remote exists
	return model
end

-- Central elimination handler (HP death or ringout).
function PlayerService.HandleElimination(victim: Player, ringout: boolean)
	local state = Runtime.Get(victim)
	if not state or not state.Alive then
		return
	end
	state.Alive = false

	local killer = state.LastAttacker
	-- Ringout with no recent attacker = self-elimination.
	local weaponId = nil
	if killer == victim then
		killer = nil
	end

	if PlayerService.OnElimination then
		PlayerService.OnElimination(victim, killer, weaponId, ringout)
	end

	-- Respawn after delay if match still active.
	task.delay(GameConfig.Character.RespawnDelay, function()
		if Players:FindFirstChild(victim.Name) and PlayerService.MatchActive then
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
		for _, player in ipairs(Players:GetPlayers()) do
			local state = Runtime.Get(player)
			local char = player.Character
			if state and state.Alive and char and char.PrimaryPart then
				if char.PrimaryPart.Position.Y < GameConfig.Character.KillFloorY then
					PlayerService.HandleElimination(player, true)
				end
			end
		end
	end)
end

-- Status loop: publishes a SpeedMult attribute on each character (read by the
-- client MovementController) so Frost slow + Speed Boost feel responsive while
-- staying server-decided. Also expires power-ups.
local function startStatusLoop()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local state = Runtime.Get(player)
			local char = player.Character
			if state and char then
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
	for _, player in ipairs(Players:GetPlayers()) do
		local state = Runtime.Get(player)
		if state then
			state.Alive = false
		end
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
		if PlayerService.MatchActive and state and not state.Alive then
			-- allow manual respawn only after death, throttled by delay handled elsewhere
			PlayerService.Spawn(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		Runtime.Remove(player)
	end)

	startKillFloorLoop()
	startStatusLoop()
end

return PlayerService
