--!strict
-- The lobby's lighting, in one place, so it can be tuned by eye in Studio
-- (tools/lobby/export_lighting.lua prints this whole file back out after a
-- tuning session; see docs/LOBBY_ART.md).
--   Lighting / Bloom / Grade: what LobbyLook sets while you're in the lobby.
--   Lights: the room lights LobbyService hangs (Offset = studs from the
--   lobby's centre, Y = height above the floor). Lamps, screens and signs keep
--   their own small lights.

return {
	Lighting = {
		Brightness = 2,
		Ambient = Color3.fromRGB(50, 50, 62),
		OutdoorAmbient = Color3.fromRGB(78, 78, 92),
		ExposureCompensation = -0.1,
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
	},
	Bloom = { Intensity = 0.05, Threshold = 3 },
	Grade = { Contrast = 0.14, Saturation = 0.04, Brightness = 0.01 },
	Lights = {
		-- ceiling lights over the plaza and the side rooms
		{ Kind = "PointLight", Offset = Vector3.new(0, 19, 0), Color = Color3.fromRGB(235, 240, 255), Range = 36, Brightness = 0.7, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(-24, 19, -24), Color = Color3.fromRGB(235, 240, 255), Range = 36, Brightness = 0.7, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(24, 19, -24), Color = Color3.fromRGB(235, 240, 255), Range = 36, Brightness = 0.7, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(-24, 19, 18), Color = Color3.fromRGB(235, 240, 255), Range = 36, Brightness = 0.7, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(24, 19, 18), Color = Color3.fromRGB(235, 240, 255), Range = 36, Brightness = 0.7, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(65, 19, 0), Color = Color3.fromRGB(235, 240, 255), Range = 36, Brightness = 0.7, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(-65, 19, 0), Color = Color3.fromRGB(235, 240, 255), Range = 36, Brightness = 0.7, Shadows = false },
		-- down the matchmaking hall
		{ Kind = "PointLight", Offset = Vector3.new(0, 13, 40), Color = Color3.fromRGB(190, 210, 255), Range = 26, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(0, 13, 56), Color = Color3.fromRGB(190, 210, 255), Range = 26, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(0, 13, 72), Color = Color3.fromRGB(190, 210, 255), Range = 26, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(0, 13, 88), Color = Color3.fromRGB(190, 210, 255), Range = 26, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(0, 13, 104), Color = Color3.fromRGB(190, 210, 255), Range = 26, Brightness = 0.9, Shadows = false },
		-- warm pools: the spawn, the DUELS arch, the two room doors, the range
		{ Kind = "SpotLight", Offset = Vector3.new(0, 18, 0), Color = Color3.fromRGB(255, 222, 170), Range = 34, Brightness = 1.6, Angle = 70, Face = "Bottom", Shadows = true },
		{ Kind = "SpotLight", Offset = Vector3.new(0, 18, 26), Color = Color3.fromRGB(255, 222, 170), Range = 24, Brightness = 1.2, Angle = 70, Face = "Bottom", Shadows = true },
		{ Kind = "SpotLight", Offset = Vector3.new(38, 18, 0), Color = Color3.fromRGB(255, 222, 170), Range = 22, Brightness = 1, Angle = 70, Face = "Bottom", Shadows = true },
		{ Kind = "SpotLight", Offset = Vector3.new(-38, 18, 0), Color = Color3.fromRGB(255, 222, 170), Range = 22, Brightness = 1, Angle = 70, Face = "Bottom", Shadows = true },
		{ Kind = "SpotLight", Offset = Vector3.new(0, 18, -36), Color = Color3.fromRGB(255, 222, 170), Range = 20, Brightness = 1, Angle = 70, Face = "Bottom", Shadows = true },
	},
}
