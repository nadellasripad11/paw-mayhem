--!strict
-- the lobby's lighting, in one place, so it can be tuned by eye in studio
-- (tools/lobby/export_lighting.lua prints this whole file back out after a
-- tuning session; see docs/lobby_art.md).
--   lighting / atmosphere: what lobbylook holds while you're in the lobby.
--   lights: the room lights lobbyservice hangs (offset = studs from the
--   lobby's centre, y = height above the floor). lamps, screens and signs keep
--   their own small lights.

return {
	-- the place's own lighting (what you see when you first join). lobbylook
	-- holds it while you're in the lobby so an arena map's brighter, hazy
	-- lighting doesn't wash the room out.
	Lighting = {
		Brightness = 2.5,
		Ambient = Color3.fromRGB(80, 90, 120),
		OutdoorAmbient = Color3.fromRGB(140, 150, 180),
		ExposureCompensation = 0,
		ClockTime = 14.5,
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.6,
		FogEnd = 4000,
	},
	-- (no haze in the lobby: the maps add an atmosphere, the place has none)
	Atmosphere = { Density = 0, Haze = 0, Glare = 0 },
	-- the room lights below are off: with the light cream room the place's
	-- own lighting already looks right, and the warm rig washed it yellow.
	-- (turn RoomLights on to try them again.) lamps, bulbs and signs keep a
	-- soft glow, scaled by DecorLightScale.
	RoomLights = false,
	DecorLightScale = 0.35,
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
