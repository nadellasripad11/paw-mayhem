--!strict
-- floorshape: where a playable floor's top is and how far it reaches, for any
-- floor shape - the islands' flat discs (a cylinder turned on its side, so its
-- thickness is size.x) and the rooftops' boxes alike.

local FloorShape = {}

-- half its extent along world x, y and z (works at any rotation).
function FloorShape.HalfExtents(p: BasePart): Vector3
	local cf, s = p.CFrame, p.Size
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		math.abs(r.X) * s.X + math.abs(u.X) * s.Y + math.abs(l.X) * s.Z,
		math.abs(r.Y) * s.X + math.abs(u.Y) * s.Y + math.abs(l.Y) * s.Z,
		math.abs(r.Z) * s.X + math.abs(u.Z) * s.Y + math.abs(l.Z) * s.Z
	) / 2
end

-- height of the walkable top.
function FloorShape.Top(p: BasePart): number
	return p.Position.Y + FloorShape.HalfExtents(p).Y
end

-- distance from the centre you can safely go in every direction.
function FloorShape.Radius(p: BasePart): number
	local h = FloorShape.HalfExtents(p)
	return math.min(h.X, h.Z)
end

return FloorShape
