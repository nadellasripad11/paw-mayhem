--!strict
-- SoundController: all game audio.
--   * Music: calm lobby loop, energetic match loop (faster in Mayhem Mode).
--   * SFX: shots (3D, from every blaster), hits, getting hit, knockouts,
--     eliminations, jump / land, dash, jump pads, pickups, rewards, the round
--     countdown, victory / defeat, announcements and a click on every button.
-- Volumes come from Settings (MusicVolume / SFXVolume) via two SoundGroups.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sounds = require(ReplicatedStorage.Shared.Config.Sounds)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local ClientState = require(script.Parent.Parent.ClientState)

local SoundController = {}

local player = Players.LocalPlayer

local function group(name: string): SoundGroup
	local g = SoundService:FindFirstChild(name)
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = SoundService
	end
	return g :: SoundGroup
end

local sfxGroup = group("PawSFX")
local musicGroup = group("PawMusic")

-- One pre-made Sound per 2D effect, cloned when it's already playing.
local templates: { [string]: Sound } = {}
local function template(name: string): Sound?
	local def = Sounds.SFX[name]
	if not def then
		return nil
	end
	local s = templates[name]
	if not s then
		s = Instance.new("Sound")
		s.Name = "Paw_" .. name
		s.SoundId = def.id
		s.Volume = def.volume
		s.PlaybackSpeed = def.pitch
		s.SoundGroup = sfxGroup
		s.Parent = SoundService
		templates[name] = s
	end
	return s
end

-- Play a 2D sound effect. `pitch` optionally varies it (e.g. per blaster).
function SoundController.Play(name: string, pitch: number?)
	local t = template(name)
	if not t then
		return
	end
	local s = t.IsPlaying and t:Clone() or t
	if s ~= t then
		s.Parent = SoundService
		s.Ended:Once(function()
			s:Destroy()
		end)
	end
	s.PlaybackSpeed = (Sounds.SFX[name].pitch or 1) * (pitch or 1)
	s:Play()
end

-- Play a sound in the world at a position (falls off with distance).
function SoundController.PlayAt(name: string, position: Vector3, pitch: number?)
	local def = Sounds.SFX[name]
	if not def then
		return
	end
	local anchor = Instance.new("Attachment")
	anchor.WorldPosition = position
	anchor.Parent = Workspace.Terrain
	local s = Instance.new("Sound")
	s.SoundId = def.id
	s.Volume = def.volume
	s.PlaybackSpeed = def.pitch * (pitch or 1)
	s.RollOffMinDistance = 12
	s.RollOffMaxDistance = 160
	s.SoundGroup = sfxGroup
	s.Parent = anchor
	s:Play()
	task.delay(4, function()
		anchor:Destroy()
	end)
end

-- ── music ────────────────────────────────────────────────────────────────────
local tracks: { [string]: Sound } = {}
local currentTrack: string? = nil

local function track(name: string): Sound
	local s = tracks[name]
	if not s then
		local def = Sounds.Music[name]
		s = Instance.new("Sound")
		s.Name = "PawMusic_" .. name
		s.SoundId = def.id
		s.Volume = 0
		s.Looped = true
		s.SoundGroup = musicGroup
		s.Parent = SoundService
		tracks[name] = s
	end
	return s
end

local function playMusic(name: string)
	if currentTrack == name then
		return
	end
	currentTrack = name
	for id, s in pairs(tracks) do
		if id ~= name then
			s:Stop()
		end
	end
	local s = track(name)
	s.Volume = Sounds.Music[name].volume
	s.TimePosition = 0
	s:Play()
end

local function applyVolumes()
	local st = ClientState.Settings
	sfxGroup.Volume = tonumber(st.SFXVolume) or 0.8
	musicGroup.Volume = tonumber(st.MusicVolume) or 0.6
end

-- ── hooks ────────────────────────────────────────────────────────────────────
local function hookCharacter(char: Model)
	local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	local airborneAt = 0
	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping then
			SoundController.Play("Jump")
		elseif new == Enum.HumanoidStateType.Freefall then
			airborneAt = os.clock()
		elseif new == Enum.HumanoidStateType.Landed and os.clock() - airborneAt > 0.35 then
			SoundController.Play("Land")
		end
	end)
end

local function hookButton(inst: Instance)
	if inst:IsA("GuiButton") then
		inst.Activated:Connect(function()
			SoundController.Play("Click")
		end)
	end
end

local function myTeam(m: any): string?
	for _, e in ipairs(m.board or {}) do
		if e.Name == player.Name then
			return e.Team
		end
	end
	return nil
end

function SoundController.Start()
	applyVolumes()
	ClientState.SettingsChanged:Connect(applyVolumes)

	-- Every blaster shot, 3D at the muzzle (bots included).
	Remotes.Get("PlayEffect").OnClientEvent:Connect(function(data)
		if typeof(data) ~= "table" then
			return
		end
		if data.kind == "Tracer" and typeof(data.from) == "Vector3" then
			SoundController.PlayAt("Shoot", data.from, 0.9 + math.random() * 0.2)
		elseif data.kind == "Burst" and typeof(data.position) == "Vector3" then
			SoundController.PlayAt("Explosion", data.position)
		elseif data.kind == "CoinRain" then
			SoundController.Play("Coin")
		elseif data.kind == "Confetti" and typeof(data.position) == "Vector3" then
			SoundController.PlayAt("Pop", data.position)
		end
	end)
	Remotes.Get("HitConfirm").OnClientEvent:Connect(function()
		SoundController.Play("Hit", 0.95 + math.random() * 0.1)
	end)
	Remotes.Get("YouWereHit").OnClientEvent:Connect(function()
		SoundController.Play("Hurt")
	end)
	Remotes.Get("Eliminated").OnClientEvent:Connect(function()
		SoundController.Play("Eliminated")
	end)
	Remotes.Get("KillFeed").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and data.killer == player.DisplayName then
			SoundController.Play("Knockout")
		end
	end)
	Remotes.Get("Announce").OnClientEvent:Connect(function()
		SoundController.Play("Alert")
	end)
	Remotes.Get("PowerUpActive").OnClientEvent:Connect(function()
		SoundController.Play("Pop")
	end)
	Remotes.Get("Notify").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and data.kind == "success" then
			SoundController.Play("Coin")
		end
	end)

	-- Round flow + music.
	local lastPhase, lastTime = nil, -1
	ClientState.MatchChanged:Connect(function(m)
		local phase = m.phase
		if phase == "Countdown" and m.timeLeft ~= lastTime and (m.timeLeft or 0) > 0 then
			SoundController.Play("Tick")
		end
		if phase ~= lastPhase then
			if phase == "Playing" and lastPhase == "Countdown" then
				SoundController.Play("Go")
			elseif phase == "Results" then
				local won
				if m.mode == "FFA" then
					won = m.winner == player.Name
				else
					won = m.winner ~= nil and m.winner == myTeam(m)
				end
				SoundController.Play(won and "Victory" or "Defeat")
			end
		end
		lastPhase, lastTime = phase, m.timeLeft
		playMusic((phase == "Playing" or phase == "Countdown") and "Match" or "Lobby")
		local match = tracks.Match
		if match then
			match.PlaybackSpeed = (m.mayhem and phase == "Playing") and 1.12 or 1
		end
	end)
	playMusic("Lobby")

	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
	player.CharacterAdded:Connect(hookCharacter)

	local gui = player:WaitForChild("PlayerGui")
	for _, d in ipairs(gui:GetDescendants()) do
		hookButton(d)
	end
	gui.DescendantAdded:Connect(hookButton)
end

return SoundController
