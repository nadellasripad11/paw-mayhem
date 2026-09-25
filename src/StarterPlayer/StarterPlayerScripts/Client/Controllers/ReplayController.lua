--!strict
-- ReplayController: a replay of your last knockout, shown at the end of the
-- match before the podium. Keeps the last few seconds of every cat's position
-- (20 samples a second); when you knock someone out it saves that window.
-- Playback puts stand-in copies of the cats back along their paths in slow
-- motion, with the camera over the victim's shoulder looking back at you.
-- Letterboxed, music muffled, click to skip.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)
local CameraController = require(script.Parent.CameraController)
local SoundController = require(script.Parent.SoundController)

local ReplayController = {}

local player = Players.LocalPlayer
local SAMPLE = 0.05 -- seconds between samples
local WINDOW = 3.2 -- seconds kept (and replayed)
local SPEED = 0.6 -- playback speed
local NEARBY = 60 -- other cats within this of the victim appear too

type Frame = { t: number, cf: CFrame }
type Track = { model: Model, name: string, frames: { Frame } }
type Clip = { tracks: { { stand: Model, frames: { Frame } } }, victim: number, killer: number, start: number }

local tracks: { [Model]: Track } = setmetatable({}, { __mode = "k" }) :: any
local stands: { [Model]: Model } = setmetatable({}, { __mode = "k" }) :: any -- stand-in copies
local clip: Clip? = nil

local function displayName(m: Model): string
	local p = Players:GetPlayerFromCharacter(m)
	return p and p.DisplayName or m.Name
end

-- A lifeless copy of a cat to act out the replay.
local function standFor(m: Model): Model?
	local s = stands[m]
	if s then
		return s
	end
	local ok, copy = pcall(function()
		local old = m.Archivable
		m.Archivable = true
		local c = m:Clone()
		m.Archivable = old
		return c
	end)
	if not ok or not copy then
		return nil
	end
	local c = copy :: Model
	CollectionService:RemoveTag(c, CatBuilder.Tag)
	c:SetAttribute("Replay", true)
	for _, d in ipairs(c:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		elseif d:IsA("Humanoid") then
			d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		elseif d:IsA("BillboardGui") or d:IsA("Highlight") then
			d:Destroy()
		end
	end
	stands[m] = c
	return c
end

local function record(now: number)
	for _, m in ipairs(CollectionService:GetTagged(CatBuilder.Tag)) do
		local root = m:IsA("Model") and m.PrimaryPart
		if root and m:IsDescendantOf(Workspace) then
			local model = m :: Model
			local tr = tracks[model]
			if not tr then
				tr = { model = model, name = displayName(model), frames = {} }
				tracks[model] = tr
				task.spawn(standFor, model)
			end
			local frames = (tr :: Track).frames
			table.insert(frames, { t = now, cf = root.CFrame })
			while #frames > 0 and now - frames[1].t > WINDOW + 0.5 do
				table.remove(frames, 1)
			end
		end
	end
end

-- You knocked someone out: keep the last few seconds around them.
local function capture(victimName: string)
	local now = os.clock()
	local victimTrack: Track? = nil
	for _, tr in pairs(tracks) do
		if tr.name == victimName and #tr.frames > 0 and now - tr.frames[#tr.frames].t < 1.5 then
			victimTrack = tr
		end
	end
	local mine = player.Character and tracks[player.Character]
	if not victimTrack or not mine then
		return
	end
	local start = now - WINDOW
	local function window(tr: Track): { Frame }
		local out = {}
		for _, f in ipairs(tr.frames) do
			if f.t >= start then
				table.insert(out, f)
			end
		end
		return out
	end
	local c: Clip = { tracks = {}, victim = 0, killer = 0, start = start }
	for _, tr in pairs(tracks) do
		local frames = window(tr)
		local near = tr == victimTrack or tr == mine
		if not near and #frames > 0 and #victimTrack.frames > 0 then
			near = (frames[#frames].cf.Position - victimTrack.frames[#victimTrack.frames].cf.Position).Magnitude < NEARBY
		end
		local stand = near and #frames > 1 and standFor(tr.model)
		if stand then
			table.insert(c.tracks, { stand = stand, frames = frames })
			if tr == victimTrack then
				c.victim = #c.tracks
			elseif tr == mine then
				c.killer = #c.tracks
			end
		end
	end
	if c.victim > 0 and c.killer > 0 then
		clip = c
	end
end

local function sample(frames: { Frame }, t: number): CFrame
	if t <= frames[1].t then
		return frames[1].cf
	end
	for i = 2, #frames do
		local b = frames[i]
		if b.t >= t then
			local a = frames[i - 1]
			return a.cf:Lerp(b.cf, (t - a.t) / math.max(b.t - a.t, 1e-3))
		end
	end
	return frames[#frames].cf
end

function ReplayController.HasClip(): boolean
	return clip ~= nil
end

function ReplayController.Clear()
	clip = nil
end

-- Play the saved knockout, then call `done` (straight away if there isn't one).
function ReplayController.Play(done: () -> ())
	local c = clip
	clip = nil
	if not c then
		done()
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "KnockoutReplay"
	folder.Parent = Workspace
	local actors = {}
	for _, tr in ipairs(c.tracks) do
		local a = tr.stand:Clone()
		a.Parent = folder
		table.insert(actors, a)
	end

	-- Letterbox + a small label.
	local gui = Instance.new("ScreenGui")
	gui.Name = "PawReplay"
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 60
	gui.Parent = player:WaitForChild("PlayerGui")
	for _, top in ipairs({ true, false }) do
		local bar = Instance.new("Frame")
		bar.BackgroundColor3 = Color3.new(0, 0, 0)
		bar.BorderSizePixel = 0
		bar.Size = UDim2.fromScale(1, 0.11)
		bar.Position = top and UDim2.fromScale(0, 0) or UDim2.fromScale(0, 0.89)
		bar.Parent = gui
	end
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Text = "REPLAY  ·  click to skip"
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.fromRGB(220, 220, 230)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Position = UDim2.new(0, 24, 0.89, 12)
	label.Size = UDim2.fromOffset(300, 20)
	label.Parent = gui
	SoundController.Muffle(true)

	local finished = false
	local conn: RBXScriptConnection? = nil
	local skip: RBXScriptConnection? = nil
	local function finish()
		if finished then
			return
		end
		finished = true
		if conn then
			conn:Disconnect()
		end
		if skip then
			skip:Disconnect()
		end
		CameraController.SetOverride(nil)
		SoundController.Muffle(false)
		folder:Destroy()
		gui:Destroy()
		done()
	end
	skip = UserInputService.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			finish()
		end
	end)

	local t = 0
	local camCF: CFrame? = nil
	conn = RunService.RenderStepped:Connect(function(dt)
		t += dt * SPEED
		if t >= WINDOW then
			finish()
			return
		end
		local at = c.start + t
		for i, tr in ipairs(c.tracks) do
			actors[i]:PivotTo(sample(tr.frames, at))
		end
		-- Over the victim's shoulder, looking back at you.
		local vp = sample(c.tracks[c.victim].frames, at).Position
		local kp = sample(c.tracks[c.killer].frames, at).Position
		local away = Vector3.new(vp.X - kp.X, 0, vp.Z - kp.Z)
		away = away.Magnitude > 0.1 and away.Unit or Vector3.zAxis
		local want = CFrame.lookAt(vp + away * 7 + Vector3.new(0, 3, 0), kp:Lerp(vp, 0.3) + Vector3.new(0, 1, 0))
		camCF = camCF and camCF:Lerp(want, math.clamp(dt * 5, 0, 1)) or want
		CameraController.SetOverride(camCF)
	end)
end

function ReplayController.Start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= SAMPLE then
			acc = 0
			record(os.clock())
		end
	end)
	Remotes.Get("KillFeed").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and data.killer == player.DisplayName and typeof(data.victim) == "string" and data.victim ~= player.DisplayName then
			capture(data.victim)
		end
	end)
end

return ReplayController
