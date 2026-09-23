--!strict
-- Remotes: single source of truth for every RemoteEvent / RemoteFunction.
-- On the server, calling Remotes.Get() creates the instances under a folder in
-- ReplicatedStorage. On the client it waits for them. This avoids scattering
-- Instance.new remotes across the codebase and prevents name typos.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

-- Declare remotes: name -> "Event" | "Function".
Remotes.Definitions = {
	-- Client -> Server (requests, server-authoritative)
	FireWeapon = "Event", -- {origin, direction, weaponId, clientTime}
	SwitchWeapon = "Event", -- weaponId
	UseEmote = "Event", -- emoteId
	RequestRespawn = "Event",
	SetLoadout = "Event", -- {weaponId, skinId, cat = {...}}
	PurchaseItem = "Function", -- {kind, id} -> {ok, reason}
	EquipItem = "Function", -- {kind, id} -> {ok}
	ClaimQuest = "Function", -- questId -> {ok, coins}
	ClaimDaily = "Function", -- -> {ok, streak, coins, gems}
	ClaimSeason = "Function", -- {tier, track} -> {ok, reason}
	TutorialDone = "Event",
	SaveSettings = "Event", -- {key = value} validated + stored in the profile
	GetLeaderboard = "Function", -- {scope = "Global"|"Country", metric} -> {entries, country}
	RequestJoinMatch = "Event",

	-- Server -> Client (state + feedback)
	MatchState = "Event", -- {phase, timeLeft, scores, ...}
	KillFeed = "Event", -- {killer, victim, weaponId}
	HitConfirm = "Event", -- {victim, damage, knockback} to shooter for feedback
	YouWereHit = "Event", -- {from, direction} to victim for shake/blood
	Launch = "Event", -- {velocity} to victim; its client applies the knockback
	Eliminated = "Event", -- {by, xp} to victim
	ScoreUpdate = "Event", -- {blue, red, board = {...}}
	ProfileUpdate = "Event", -- full/partial player profile (coins, xp, unlocks...)
	PowerUpSpawned = "Event", -- {id, powerId, position}
	PowerUpTaken = "Event", -- {id, playerName, powerId}
	PowerUpActive = "Event", -- {powerId, duration} to the owner
	Notify = "Event", -- {text, kind} toast
	PlayEffect = "Event", -- {kind, cframe, color} broadcast VFX
	Announce = "Event", -- {title, sub, color} big centre banner for everyone
	MapEvent = "Event", -- {kind, dir, duration, strength} client-side event effects
	Podium = "Event", -- {top = {{userId?, name, elims, isBot}}} end-of-match winners stage
}

local FOLDER_NAME = "PawMayhemRemotes"

local cache: { [string]: Instance } = {}
local folder: Folder? = nil

local function ensureFolderServer(): Folder
	if folder then
		return folder
	end
	local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if existing then
		folder = existing :: Folder
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = FOLDER_NAME
	for name, kind in pairs(Remotes.Definitions) do
		local inst
		if kind == "Function" then
			inst = Instance.new("RemoteFunction")
		else
			inst = Instance.new("RemoteEvent")
		end
		inst.Name = name
		inst.Parent = f
		cache[name] = inst
	end
	f.Parent = ReplicatedStorage
	folder = f
	return f
end

local function ensureFolderClient(): Folder
	if folder then
		return folder
	end
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME, 30) :: Folder
	return folder :: Folder
end

-- Get a remote by name. Safe to call from either context.
function Remotes.Get(name: string): any
	if cache[name] then
		return cache[name]
	end
	local f
	if RunService:IsServer() then
		f = ensureFolderServer()
	else
		f = ensureFolderClient()
	end
	local inst = f:WaitForChild(name, 30)
	cache[name] = inst
	return inst
end

-- Server bootstrap: create all remotes up front.
function Remotes.InitServer()
	assert(RunService:IsServer(), "InitServer must run on server")
	ensureFolderServer()
end

return Remotes
