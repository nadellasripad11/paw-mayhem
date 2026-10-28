--!strict
-- remotes: single source of truth for every remoteevent / remotefunction.
-- on the server, calling remotes.get() creates the instances under a folder in
-- replicatedstorage. on the client it waits for them. this avoids scattering
-- instance.new remotes across the codebase and prevents name typos.

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

-- declare remotes: name -> "event" | "function".
Remotes.Definitions = {
	-- client -> server (requests, server-authoritative)
	FireWeapon = "Event", -- {origin, direction, weaponid, clienttime}
	SwitchWeapon = "Event", -- weaponid
	UseEmote = "Event", -- emoteid
	MoveFx = "Event", -- client -> server: a move's kind ("flip", "dash"...); server -> everyone else: {char, kind} (animation only)
	RequestRespawn = "Event",
	SetLoadout = "Event", -- {weaponid, skinid, cat = {...}}
	PurchaseItem = "Function", -- {kind, id} -> {ok, reason}
	EquipItem = "Function", -- {kind, id} -> {ok}
	SetEmoteSlot = "Function", -- {slot = 1..6, id} -> {ok} (id "" empties the slot)
	ClaimQuest = "Function", -- questid -> {ok, coins}
	ClaimDaily = "Function", -- -> {ok, streak, coins, gems}
	ClaimSeason = "Function", -- {tier, track} -> {ok, reason}
	TutorialDone = "Event",
	SaveSettings = "Event", -- {key = value} validated + stored in the profile
	GetLeaderboard = "Function", -- {scope = "global"|"country", metric} -> {entries, country}
	RequestJoinMatch = "Event",
	RedeemCode = "Function", -- code -> {ok, text}
	LobbyTravel = "Event", -- "duels": move to the duel pads (lobby only)

	-- server -> client (state + feedback)
	MatchState = "Event", -- {phase, timeleft, scores, ...}
	KillFeed = "Event", -- {killer, victim, weaponid}
	HitConfirm = "Event", -- {victim, damage, knockback} to shooter for feedback
	YouWereHit = "Event", -- {from, direction} to victim for shake/blood
	Launch = "Event", -- {velocity} to victim; its client applies the knockback
	Eliminated = "Event", -- {by, xp} to victim
	ScoreUpdate = "Event", -- {blue, red, board = {...}}
	ProfileUpdate = "Event", -- full/partial player profile (coins, xp, unlocks...)
	PowerUpSpawned = "Event", -- {id, powerid, position}
	PowerUpTaken = "Event", -- {id, playername, powerid}
	PowerUpActive = "Event", -- {powerid, duration} to the owner
	Notify = "Event", -- {text, kind} toast
	PlayEffect = "Event", -- {kind, cframe, color} broadcast vfx
	Announce = "Event", -- {title, sub, color} big centre banner for everyone
	MapEvent = "Event", -- {kind, dir, duration, strength} client-side event effects
	Podium = "Event", -- {top = {{userid?, name, elims, isbot}}} end-of-match winners stage
	FinalKO = "Event", -- {position?} the knockout that won the match / duel, to everyone in it
	StreakLost = "Event", -- {streak} to a player whose win streak (3+) just ended; streak saver can bring it back
	DuelQueue = "Event", -- client -> server: {join = "1v1".."5v5"} or {leave = true}
	QueueState = "Event", -- server -> client: {kind, since} while searching, {} when not
	DuelVote = "Event", -- server -> client: {stage, options, endsat, votes, myvote} ({} closes); client -> server: {choice}
	DuelState = "Event", -- {teams, score, target, timeleft, myteam, started?, ko?, over?, won?, trophies?} to duelists
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

-- get a remote by name. safe to call from either context.
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

-- server bootstrap: create all remotes up front.
function Remotes.InitServer()
	assert(RunService:IsServer(), "InitServer must run on server")
	ensureFolderServer()
end

return Remotes
