--!strict
-- lobbylook: keeps the lobby looking the way it does when you first join.
-- each arena map sets its own brighter, hazy lighting on the server (and an
-- atmosphere), which washed the lobby out yellow and white; while you're in
-- the lobby this client holds the place's own lighting instead
-- (shared/lobbylighting), turns the haze off, and keeps the settings
-- screen's post effects (bloom, grade, sun rays) off: on the light cream and
-- orange room they turned everything into a yellow glare. leaving the lobby puts the
-- map's lighting back, and if the server changes it meanwhile (a new map
-- loading), the new values are remembered and come back instead. it also
-- turns the lobby's floating displays (tagged lobbyspin) while you're there.
-- tick the lobbytuning attribute on lighting (studio, while playing) and it
-- stops holding them, so they can be tuned by eye (docs/lobby_art.md).

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLighting = require(ReplicatedStorage.Shared.LobbyLighting)

local LobbyLook = {}

local LIGHTING: { [string]: any } = LobbyLighting.Lighting
local ATMOSPHERE: { [string]: any } = LobbyLighting.Atmosphere

local active = false
local applying = false
local savedLighting: { [string]: any } = {}
local atmosphere: Atmosphere? = nil
local savedAtmosphere: { [string]: any } = {}
local function set(obj: Instance, prop: string, value: any)
	applying = true
	pcall(function()
		(obj :: any)[prop] = value
	end)
	applying = false
end

local POST = { PawBloom = true, PawGrade = true, PawSunRays = true }
local savedPost: { [Instance]: boolean } = {}
local hooked: { [Instance]: boolean } = {}

local function holdPost(e: Instance)
	if not POST[e.Name] or not (e:IsA("PostEffect")) then
		return
	end
	if savedPost[e] == nil then
		savedPost[e] = (e :: any).Enabled
	end
	set(e, "Enabled", false)
	if not hooked[e] then
		hooked[e] = true
		e:GetPropertyChangedSignal("Enabled"):Connect(function()
			if applying or not active or Lighting:GetAttribute("LobbyTuning") then
				return
			end
			savedPost[e] = (e :: any).Enabled -- settings changed it: remember, keep it off here
			set(e, "Enabled", false)
		end)
	end
end

local function takeAtmosphere(a: Atmosphere)
	atmosphere = a
	savedAtmosphere = {}
	for prop, value in pairs(ATMOSPHERE) do
		savedAtmosphere[prop] = (a :: any)[prop]
		set(a, prop, value)
		a:GetPropertyChangedSignal(prop):Connect(function()
			if applying or not active or atmosphere ~= a or Lighting:GetAttribute("LobbyTuning") then
				return
			end
			savedAtmosphere[prop] = (a :: any)[prop] -- the server's new value
			set(a, prop, value)
		end)
	end
end

function LobbyLook.Set(on: boolean)
	if on == active then
		return
	end
	active = on
	if on then
		for prop, value in pairs(LIGHTING) do
			savedLighting[prop] = (Lighting :: any)[prop]
			set(Lighting, prop, value)
		end
		local a = Lighting:FindFirstChildOfClass("Atmosphere")
		if a then
			takeAtmosphere(a)
		end
		for _, e in ipairs(Lighting:GetChildren()) do
			holdPost(e)
		end
	else
		for prop, value in pairs(savedLighting) do
			set(Lighting, prop, value)
		end
		local a = atmosphere
		if a and a.Parent then
			for prop, value in pairs(savedAtmosphere) do
				set(a, prop, value)
			end
		end
		atmosphere = nil
		for e, was in pairs(savedPost) do
			if e.Parent then
				set(e, "Enabled", was)
			end
		end
		savedPost = {}
	end
end

function LobbyLook.Start()
	for prop, value in pairs(LIGHTING) do
		Lighting:GetPropertyChangedSignal(prop):Connect(function()
			if applying or not active or Lighting:GetAttribute("LobbyTuning") then
				return
			end
			savedLighting[prop] = (Lighting :: any)[prop] -- the server's new value
			set(Lighting, prop, value)
		end)
	end
	-- a new map brings a new atmosphere: calm it too while in the lobby.
	Lighting.ChildAdded:Connect(function(c)
		if active and c:IsA("Atmosphere") then
			task.defer(takeAtmosphere, c)
		elseif active then
			task.defer(holdPost, c)
		end
	end)
	-- floating displays: a slow turn and a gentle bob round where they were built.
	RunService.RenderStepped:Connect(function()
		if not active then
			return
		end
		local t = os.clock()
		for i, m in ipairs(CollectionService:GetTagged("LobbySpin")) do
			local pivot = m:GetAttribute("SpinPivot")
			if m:IsA("Model") and typeof(pivot) == "CFrame" then
				local bob = math.sin(t * 1.6 + i) * 0.35
				m:PivotTo(CFrame.new(pivot.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, t * 0.8 + i, 0) * pivot.Rotation)
			end
		end
	end)
end

return LobbyLook
