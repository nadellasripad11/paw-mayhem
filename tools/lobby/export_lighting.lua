-- PAW MAYHEM — run in Studio's command bar WHILE PLAYING, on the Server view
-- (Home > Test > "Current: Client" button switches to Server), after tuning
-- the lobby lights by eye. Prints the whole of
-- src/ReplicatedStorage/Shared/LobbyLighting.lua to the Output window: copy it
-- all and send it over (or paste it over that file).
--   * Lights: every light under Workspace.Lobby.Plaza.LightRig (move, copy,
--     add or delete holders and lights there freely).
--   * Lighting (Brightness, Ambient, ...): read from Lighting. Tick the
--     LobbyTuning attribute on Lighting first (on the Server view) so the game
--     stops putting its own values back; your changes then show on the Client.
local Lighting = game:GetService("Lighting")
local lobby = workspace:FindFirstChild("Lobby")
assert(lobby, "Press Play first (the lobby is built when the game runs)")
local center = lobby:GetAttribute("Center")
local surface = lobby:GetAttribute("Surface")
local rig = lobby:FindFirstChild("LightRig", true)
assert(rig, "No LightRig in the lobby")

local function n(x)
	return (string.format("%.2f", x):gsub("%.?0+$", ""))
end
local function c3(c)
	return ("Color3.fromRGB(%d, %d, %d)"):format(math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
end
local function v3(v)
	return ("Vector3.new(%s, %s, %s)"):format(n(v.X), n(v.Y), n(v.Z))
end

local out = {}
local function w(s)
	table.insert(out, s)
end
w("--!strict")
w("-- The lobby's lighting, in one place, so it can be tuned by eye in Studio")
w("-- (tools/lobby/export_lighting.lua prints this whole file back out after a")
w("-- tuning session; see docs/LOBBY_ART.md).")
w("--   Lighting / Bloom / Grade: what LobbyLook sets while you're in the lobby.")
w("--   Lights: the room lights LobbyService hangs (Offset = studs from the")
w("--   lobby's centre, Y = height above the floor). Lamps, screens and signs keep")
w("--   their own small lights.")
w("")
w("return {")
w("\tLighting = {")
for _, prop in ipairs({ "Brightness", "Ambient", "OutdoorAmbient", "ExposureCompensation", "EnvironmentDiffuseScale", "EnvironmentSpecularScale" }) do
	local v = Lighting[prop]
	w(("\t\t%s = %s,"):format(prop, typeof(v) == "Color3" and c3(v) or n(v)))
end
w("\t},")
local bloom = Lighting:FindFirstChild("PawBloom")
w(("\tBloom = { Intensity = %s, Threshold = %s },"):format(n(bloom and bloom.Intensity or 0.05), n(bloom and bloom.Threshold or 3)))
local grade = Lighting:FindFirstChild("PawLobbyGrade")
w(("\tGrade = { Contrast = %s, Saturation = %s, Brightness = %s },"):format(n(grade and grade.Contrast or 0.14), n(grade and grade.Saturation or 0.04), n(grade and grade.Brightness or 0.01)))
w("\tLights = {")
local count = 0
for _, holder in ipairs(rig:GetDescendants()) do
	if holder:IsA("BasePart") then
		for _, l in ipairs(holder:GetChildren()) do
			if l:IsA("PointLight") or l:IsA("SpotLight") or l:IsA("SurfaceLight") then
				local off = holder.Position - Vector3.new(center.X, surface, center.Z)
				local line = ("\t\t{ Kind = %q, Offset = %s, Color = %s, Range = %s, Brightness = %s"):format(l.ClassName, v3(Vector3.new(off.X, off.Y, off.Z)), c3(l.Color), n(l.Range), n(l.Brightness))
				if not l:IsA("PointLight") then
					line ..= (", Angle = %s, Face = %q"):format(n(l.Angle), l.Face.Name)
				end
				line ..= (", Shadows = %s },"):format(tostring(l.Shadows))
				w(line)
				count += 1
			end
		end
	end
end
w("\t},")
w("}")
print(table.concat(out, "\n"))
print(("-- %d lights exported"):format(count))
