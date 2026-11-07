--!strict
-- lobbypalette: the lobby's colours in one place (a light, warm, retro 70s
-- room: cream walls, orange and peach stripes, walnut wood, patterned
-- carpet, warm globe bulbs). no gold, no blue / purple / cyan glow.
--   lobbypalette.<token>          the colours lobbyservice builds with
--   lobbypalette.remap(c, mat)    maps an old navy / blue / gold shade onto
--                                 the palette (nil = leave it alone)

local C = Color3.fromRGB

local P = {
	Wall = C(244, 235, 221), -- cream walls (#F4EBDD)
	Board = C(78, 54, 40), -- walnut sign boards (#4E3628)
	BoardLight = C(122, 86, 64), -- lighter walnut (#7A5640)
	Frame = C(92, 63, 46), -- walnut frames, posts, door edges (#5C3F2E)
	Ceiling = C(239, 227, 208), -- warm cream ceiling (#EFE3D0)
	CeilingBeam = C(176, 125, 82), -- light wood beams (#B07D52)
	Trim = C(217, 98, 43), -- burnt orange, matte (#D9622B)
	Orange = C(242, 147, 58), -- the main orange (#F2933A)
	Peach = C(248, 192, 138), -- soft peach (#F8C08A)
	Pillar = C(239, 224, 202), -- cream pillars (#EFE0CA)
	Carpet = C(170, 84, 44), -- carpet base when the pattern isn't loaded (its average colour)
	Ink = C(62, 45, 37), -- darkest brown (#3E2D25)
	Cream = C(255, 246, 234), -- warm white: sign text, lamp glass (#FFF6EA)
	Bulb = C(255, 233, 200), -- globe bulbs (#FFE9C8)
	Glass = C(246, 238, 226), -- warm clear glass
	Metal = C(110, 85, 70), -- the few real metal bits (rails, posts)
	Lamp = C(255, 232, 200), -- the colour of every light in the room
}

-- palette colours are never remapped again.
local own: { [string]: boolean } = {}
for _, c in pairs(P) do
	own[tostring(c)] = true
end

local function key(c: Color3): string
	return tostring(c)
end

-- old shade -> palette (or nil to keep it: wood browns, reds, greens, pinks,
-- warm whites and the bulbs stay as they are).
local function remap(c: Color3): Color3?
	if own[key(c)] then
		return nil
	end
	local h, s, v = c:ToHSV()
	if s < 0.2 then
		-- greys: dark steel to walnut, mid to light walnut, stone to cream
		if v < 0.22 then
			return P.Board
		elseif v < 0.5 then
			return P.Frame
		elseif v < 0.62 then
			return P.BoardLight
		elseif v < 0.9 then
			return P.Pillar
		elseif h > 0.45 and h < 0.8 then
			return P.Cream -- cool white to warm white
		end
		return nil
	end
	if h >= 0.45 and h <= 0.86 then
		-- navy, blue, cyan, purple
		if v < 0.22 then
			return P.Board
		elseif v < 0.4 then
			return P.Frame
		elseif s < 0.3 then
			return P.Glass -- pale blue glass and tints
		elseif h < 0.56 then
			return P.Peach -- cyan
		elseif h < 0.7 then
			return P.Orange -- blue
		end
		return P.Trim -- purple
	end
	if h > 0.08 and h < 0.18 and s >= 0.35 then
		-- gold and yellow
		if v < 0.75 then
			return P.Trim
		end
		return P.Orange
	end
	return nil
end

-- for a whole part: the new colour, and whether a glowing / shiny old trim
-- should become matte paint.
function P.Remap(c: Color3, material: Enum.Material?): (Color3?, Enum.Material?)
	local new = remap(c)
	if not new then
		return nil, nil
	end
	if material == Enum.Material.Neon or material == Enum.Material.Metal or material == Enum.Material.DiamondPlate then
		return new, Enum.Material.SmoothPlastic
	end
	return new, nil
end

-- a light's colour: anything cool turns into the room's warm lamp colour.
function P.LightColor(c: Color3): Color3
	if c.B > c.R then
		return P.Lamp
	end
	return c
end

-- text and gui colours on signs (no material).
function P.RemapColor(c: Color3): Color3
	return remap(c) or c
end

return P
