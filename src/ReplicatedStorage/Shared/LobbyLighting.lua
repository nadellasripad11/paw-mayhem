--!strict
-- the lobby's lighting, in one place, so it can be tuned by eye in studio
-- (tools/lobby/export_lighting.lua prints this whole file back out after a
-- tuning session; see docs/lobby_art.md).
--   lighting / bloom / grade: not applied any more (the lobby keeps the place's own
--   lighting, see lobbylook); kept for tuning notes.
--   lights: the room lights lobbyservice hangs (offset = studs from the
--   lobby's centre, y = height above the floor). lamps, screens and signs keep
--   their own small lights.

return {
	Lighting = {
		Brightness = 1.6,
		Ambient = Color3.fromRGB(72, 64, 58),
		OutdoorAmbient = Color3.fromRGB(96, 86, 78),
		ExposureCompensation = -0.35,
		EnvironmentDiffuseScale = 1,
		EnvironmentSpecularScale = 1,
	},
	Bloom = { Intensity = 0.05, Threshold = 3 },
	Grade = { Contrast = 0.1, Saturation = 0.02, Brightness = 0 },
	Lights = {
		-- ceiling lights over the plaza and the side rooms
		{ Kind = "PointLight", Offset = Vector3.new(0, 19, 0), Color = Color3.fromRGB(255, 232, 200), Range = 40, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(-24, 19, -24), Color = Color3.fromRGB(255, 232, 200), Range = 40, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(24, 19, -24), Color = Color3.fromRGB(255, 232, 200), Range = 40, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(-24, 19, 18), Color = Color3.fromRGB(255, 232, 200), Range = 40, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(24, 19, 18), Color = Color3.fromRGB(255, 232, 200), Range = 40, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(65, 19, 0), Color = Color3.fromRGB(255, 232, 200), Range = 40, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(-65, 19, 0), Color = Color3.fromRGB(255, 232, 200), Range = 40, Brightness = 0.9, Shadows = false },
		-- down the matchmaking hall
		{ Kind = "PointLight", Offset = Vector3.new(0, 13, 40), Color = Color3.fromRGB(255, 226, 190), Range = 28, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(0, 13, 56), Color = Color3.fromRGB(255, 226, 190), Range = 28, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(0, 13, 72), Color = Color3.fromRGB(255, 226, 190), Range = 28, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(0, 13, 88), Color = Color3.fromRGB(255, 226, 190), Range = 28, Brightness = 0.9, Shadows = false },
		{ Kind = "PointLight", Offset = Vector3.new(0, 13, 104), Color = Color3.fromRGB(255, 226, 190), Range = 28, Brightness = 0.9, Shadows = false },
		-- warm pools: the spawn, the duels arch, the two room doors, the range
		{ Kind = "SpotLight", Offset = Vector3.new(0, 18, 0), Color = Color3.fromRGB(255, 226, 180), Range = 34, Brightness = 0.6, Angle = 70, Face = "Bottom", Shadows = true },
		{ Kind = "SpotLight", Offset = Vector3.new(0, 18, 26), Color = Color3.fromRGB(255, 226, 180), Range = 24, Brightness = 0.6, Angle = 70, Face = "Bottom", Shadows = true },
		{ Kind = "SpotLight", Offset = Vector3.new(38, 18, 0), Color = Color3.fromRGB(255, 226, 180), Range = 22, Brightness = 0.9, Angle = 70, Face = "Bottom", Shadows = true },
		{ Kind = "SpotLight", Offset = Vector3.new(-38, 18, 0), Color = Color3.fromRGB(255, 226, 180), Range = 22, Brightness = 0.9, Angle = 70, Face = "Bottom", Shadows = true },
		{ Kind = "SpotLight", Offset = Vector3.new(0, 18, -36), Color = Color3.fromRGB(255, 226, 180), Range = 20, Brightness = 0.9, Angle = 70, Face = "Bottom", Shadows = true },
	},
}
