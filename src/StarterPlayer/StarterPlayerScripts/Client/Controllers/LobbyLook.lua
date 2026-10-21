--!strict
-- LobbyLook: calmer lighting while you're in the lobby. Each arena map sets
-- bright, hazy lighting (which turns the lobby's stone white and glowing), so
-- in the lobby this client uses its own: less ambient light, a touch less
-- exposure, no haze or glare, softer bloom. Leaving the lobby puts the map's
-- lighting back. If the server changes the lighting meanwhile (a new map
-- loading), the new values are remembered and come back instead.

local Lighting = game:GetService("Lighting")

local LobbyLook = {}

local LIGHTING = {
	Brightness = 2,
	Ambient = Color3.fromRGB(92, 90, 98),
	OutdoorAmbient = Color3.fromRGB(128, 126, 134),
	ExposureCompensation = -0.2,
}
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
			if applying or not active or atmosphere ~= a then
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
		b.Intensity = on and 0.15 or 0.55
		b.Threshold = on and 2.4 or 1.6
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
			if applying or not active then
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
end

return LobbyLook
