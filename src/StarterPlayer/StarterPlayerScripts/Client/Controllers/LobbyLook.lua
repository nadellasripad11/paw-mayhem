--!strict
-- LobbyLook: calmer lighting while you're in the lobby. Each arena map sets
-- bright, hazy lighting (which turns the lobby's stone white and glowing), so
-- in the lobby this client uses its own: less ambient light, a touch less
-- exposure, no haze or glare, softer bloom. Leaving the lobby puts the map's
-- lighting back. If the server changes the lighting meanwhile (a new map
-- loading), the new values are remembered and come back instead. It also
-- turns the lobby's floating displays (tagged LobbySpin) while you're there.

-- The values themselves live in Shared/LobbyLighting. Tick the LobbyTuning
-- attribute on Lighting (Studio, while playing) and this stops holding them,
-- so they can be tuned by eye (docs/LOBBY_ART.md).

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LobbyLighting = require(ReplicatedStorage.Shared.LobbyLighting)

local LobbyLook = {}

local LIGHTING: { [string]: any } = LobbyLighting.Lighting
local ATMOSPHERE = { Density = 0.15, Haze = 0, Glare = 0 }

local active = false
local applying = false
local savedLighting: { [string]: any } = {}
local atmosphere: Atmosphere? = nil
local savedAtmosphere: { [string]: any } = {}

local function set(obj: Instance, prop: string, value: any)
	applying = true
	(obj :: any)[prop] = value
	applying = false
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

local function bloom(on: boolean)
	local b = Lighting:FindFirstChild("PawBloom")
	if b and b:IsA("BloomEffect") then
		b.Intensity = on and LobbyLighting.Bloom.Intensity or 0.55
		b.Threshold = on and LobbyLighting.Bloom.Threshold or 1.6
	end
	-- A touch more contrast in the lobby so it reads in 3D.
	local cc = Lighting:FindFirstChild("PawLobbyGrade")
	if on and not cc then
		local c = Instance.new("ColorCorrectionEffect")
		c.Name = "PawLobbyGrade"
		c.Contrast = LobbyLighting.Grade.Contrast
		c.Saturation = LobbyLighting.Grade.Saturation
		c.Brightness = LobbyLighting.Grade.Brightness
		c.Parent = Lighting
	elseif not on and cc then
		cc:Destroy()
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
	end
	bloom(on)
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
	-- A new map brings a new Atmosphere: tame it too while in the lobby.
	Lighting.ChildAdded:Connect(function(c)
		if active and c:IsA("Atmosphere") then
			task.defer(takeAtmosphere, c)
		end
	end)
	-- Floating displays: a slow turn and a gentle bob round where they were built.
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
