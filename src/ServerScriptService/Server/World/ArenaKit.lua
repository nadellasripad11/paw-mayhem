--!strict
-- ArenaKit: shared building blocks used by every map (SkyIslands, Volcano,
-- Toybox). Each map supplies its own palette + decoration functions; the
-- island/bridge/spawn/power-pad geometry — and, critically, the safety
-- guarantees around spawn placement — live here ONCE so every map gets them
-- identically instead of being re-derived (and possibly re-broken) per map.

local CollectionService = game:GetService("CollectionService")

local ArenaKit = {}

export type Palette = {
	Top: Color3, TopDark: Color3, -- island top surface (grass/rock/foam...)
	Stone: Color3, StoneDark: Color3, -- tapered underside tiers
	Wood: Color3, WoodDark: Color3, -- bridges/structures
}

function ArenaKit.NewPart(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Faceted cliff faces break up the round underside without relying on mesh
-- assets. The wedge points down/out from the island, giving every arena the
-- chunky hand-built silhouette in the reference art.
function ArenaKit.NewWedge(name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, parent: Instance): WedgePart
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Walkable island top sits this far above an island's center Y.
ArenaKit.SURFACE = 1.6

-- Flat round disc. Roblox cylinders run along the part's X axis (length =
-- Size.X, diameter = min(Size.Y, Size.Z)), so X holds the thickness and the
-- 90° roll stands that axis upright.
function ArenaKit.NewDisc(name: string, diameter: number, thickness: number, pos: Vector3, color: Color3, material: Enum.Material?, parent: Instance): BasePart
	local p = ArenaKit.NewPart(name, Vector3.new(thickness, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- Straight beam from a to b (braces, rails, ropes).
function ArenaKit.Beam(name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material?, parent: Instance): BasePart
	local p = ArenaKit.NewPart(name, Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material, parent)
	p.CanCollide = false
	return p
end

export type IslandStyle = {
	cliffMaterial: Enum.Material?,
	seam: Color3?, -- glowing cracks between cliff columns + under the rim
	drip: Color3?, -- grass tufts hanging over the lip
	depth: number?,
}

-- Floating island: one solid round walkable top (the only collider), an
-- overhanging lip, a ring of columnar cliff blocks and a tapered rocky base.
function ArenaKit.MakeIslandBase(center: Vector3, radius: number, name: string, palette: Palette, topMaterial: Enum.Material?, parent: Instance, style: IslandStyle?): Folder
	local st: IslandStyle = style or {}
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent

	local topMat = topMaterial or Enum.Material.Grass
	local cliffMat = st.cliffMaterial or Enum.Material.Slate
	local rng = Random.new(math.floor(center.X * 7 + center.Y * 3 + center.Z * 13 + radius * 31))
	local surf = center.Y + ArenaKit.SURFACE
	local function shade(): Color3
		return palette.Stone:Lerp(palette.StoneDark, rng:NextNumber())
	end

	ArenaKit.NewDisc("Floor", radius * 2, 3, Vector3.new(center.X, surf - 1.5, center.Z), palette.Top, topMat, folder)
	ArenaKit.NewDisc("Lip", radius * 2 + 1.6, 1.6, Vector3.new(center.X, surf - 1.0, center.Z), palette.TopDark, topMat, folder).CanCollide = false

	local depth = st.depth or 1
	local colH = (7 + radius * 0.32) * depth
	local colD = math.max(4, radius * 0.32)
	local n = math.max(9, math.floor(2 * math.pi * radius / 5))
	local ringR = radius - 0.4 - colD / 2
	local colW = 2 * math.pi * (radius - 0.4) / n * 1.12
	local colTop = surf - 1.2
	for i = 1, n do
		local a = (i - 1) / n * math.pi * 2 + rng:NextNumber(-0.04, 0.04)
		local h = colH * rng:NextNumber(0.7, 1.15)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local pos = Vector3.new(center.X, colTop - h / 2, center.Z) + out * (ringR + rng:NextNumber(-0.3, 0.5))
		ArenaKit.NewPart("Cliff" .. i, Vector3.new(colW, h, colD), CFrame.lookAt(pos, pos + out), shade(), cliffMat, folder).CanCollide = false
		if st.seam and i % 3 == 0 then
			local sa = a + math.pi / n
			local sOut = Vector3.new(math.cos(sa), 0, math.sin(sa))
			local sh = h * rng:NextNumber(0.35, 0.75)
			local sp = Vector3.new(center.X, colTop - 0.6 - sh / 2, center.Z) + sOut * (radius - 0.1)
			local seam = ArenaKit.NewPart("Seam" .. i, Vector3.new(0.4, sh, 0.7), CFrame.lookAt(sp, sp + sOut), st.seam, Enum.Material.Neon, folder)
			seam.CanCollide = false
			seam.CastShadow = false
		end
		if st.drip and rng:NextNumber() < 0.45 then
			local dh = rng:NextNumber(1.2, 3.2)
			local dp = Vector3.new(center.X, surf - 1.4 - dh / 2, center.Z) + out * (radius + 0.55)
			ArenaKit.NewPart("Drip" .. i, Vector3.new(rng:NextNumber(1.6, 3.6), dh, 0.7), CFrame.lookAt(dp, dp + out), st.drip, topMat, folder).CanCollide = false
		end
	end

	local coreR = ringR - colD / 2 + 1
	ArenaKit.NewDisc("Core", coreR * 2, colH * 0.9, Vector3.new(center.X, colTop - colH * 0.45, center.Z), palette.StoneDark, cliffMat, folder).CanCollide = false

	local y = colTop - colH * 0.9
	local r = ringR
	for k = 1, 2 do
		r *= 0.66
		local h = 3 + radius * 0.14
		ArenaKit.NewDisc("Taper" .. k, r * 2, h, Vector3.new(center.X, y - h / 2, center.Z), shade(), cliffMat, folder).CanCollide = false
		y -= h
	end

	-- Hanging rock columns give the underside a jagged, hand-built silhouette.
	local hangTop = colTop - colH * 0.8
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local dist = ringR * rng:NextNumber(0.15, 0.7)
		local h = rng:NextNumber(0.5, 1.3) * (colH * 0.6 + radius * 0.25)
		local w = math.max(2.5, radius * rng:NextNumber(0.16, 0.3))
		local pos = Vector3.new(center.X + math.cos(a) * dist, hangTop - h / 2, center.Z + math.sin(a) * dist)
		ArenaKit.NewPart("Hang" .. i, Vector3.new(w, h, w * rng:NextNumber(0.8, 1.2)), CFrame.new(pos) * CFrame.Angles(0, a, 0), shade(), cliffMat, folder).CanCollide = false
	end

	if st.seam then
		local glow = ArenaKit.NewDisc("RimGlow", radius * 2 + 0.9, 0.35, Vector3.new(center.X, surf - 2.0, center.Z), st.seam, Enum.Material.Neon, folder)
		glow.CanCollide = false
		glow.CastShadow = false
	end

	return folder
end

-- ── Layout helpers ───────────────────────────────────────────────────────────
-- An "isle" is a built island plus bookkeeping: link angles (bridges/stairs),
-- reserved angles (big features, streams) and placed prop footprints, so
-- decoration never lands on a walkway or on top of another prop.

function ArenaKit.NewIsle(pos: Vector3, r: number, folder: Folder): any
	return { pos = pos, r = r, surf = pos.Y + ArenaKit.SURFACE, folder = folder, links = {}, reserved = {}, placed = {} }
end

function ArenaKit.AngleTo(from: Vector3, to: Vector3): number
	return math.atan2(to.Z - from.Z, to.X - from.X)
end

function ArenaKit.AngDist(a: number, b: number): number
	return math.abs((a - b + math.pi) % (2 * math.pi) - math.pi)
end

function ArenaKit.Polar(isle: any, angle: number, dist: number, lift: number?): Vector3
	return Vector3.new(isle.pos.X + math.cos(angle) * dist, isle.surf + (lift or 0), isle.pos.Z + math.sin(angle) * dist)
end

-- Surface-level points on the facing edges of two isles, `inset` studs in.
function ArenaKit.EdgePoints(A: any, B: any, inset: number): (Vector3, Vector3)
	local ang = ArenaKit.AngleTo(A.pos, B.pos)
	return ArenaKit.Polar(A, ang, A.r - inset), ArenaKit.Polar(B, ang + math.pi, B.r - inset)
end

function ArenaKit.Link(A: any, B: any)
	table.insert(A.links, ArenaKit.AngleTo(A.pos, B.pos))
	table.insert(B.links, ArenaKit.AngleTo(B.pos, A.pos))
end

-- True if a point at (angle, dist) sits inside a walkway corridor running
-- from the isle's centre out through any link or reserved angle.
function ArenaKit.Blocked(isle: any, angle: number, dist: number, halfWidth: number): boolean
	for _, list in ipairs({ isle.links, isle.reserved }) do
		for _, a in ipairs(list) do
			local d = angle - a
			if dist * math.cos(d) > -2 and math.abs(dist * math.sin(d)) < halfWidth then
				return true
			end
		end
	end
	return false
end

-- Angles furthest from every link/reserved angle (and from each other).
function ArenaKit.OpenAngles(isle: any, count: number): { number }
	local picks = {}
	for _ = 1, count do
		local best, bestScore = 0, -math.huge
		for deg = 0, 355, 5 do
			local a = math.rad(deg)
			local score = math.huge
			for _, list in ipairs({ isle.links, isle.reserved }) do
				for _, l in ipairs(list) do
					score = math.min(score, ArenaKit.AngDist(a, l))
				end
			end
			local spread = math.pi
			for _, p in ipairs(picks) do
				score = math.min(score, ArenaKit.AngDist(a, p) * 0.6)
				spread = math.min(spread, ArenaKit.AngDist(a, p))
			end
			score += spread * 0.001
			if score > bestScore then
				best, bestScore = a, score
			end
		end
		table.insert(picks, best)
	end
	return picks
end

function ArenaKit.Reserve(isle: any, pos: Vector3, rad: number)
	table.insert(isle.placed, { x = pos.X, z = pos.Z, rad = rad })
end

-- Random free spot on the isle top (outside corridors and other props).
function ArenaKit.TryPlace(isle: any, rng: Random, minD: number, maxD: number, rad: number, halfWidth: number): Vector3?
	for _ = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(minD, maxD)
		if not ArenaKit.Blocked(isle, a, d, halfWidth + rad) then
			local p = ArenaKit.Polar(isle, a, d)
			local ok = true
			for _, q in ipairs(isle.placed) do
				if (Vector2.new(p.X - q.x, p.Z - q.z)).Magnitude < rad + q.rad then
					ok = false
					break
				end
			end
			if ok then
				ArenaKit.Reserve(isle, p, rad)
				return p
			end
		end
	end
	return nil
end

-- ── Gameplay markers ─────────────────────────────────────────────────────────
-- Playable islands' floors are tagged so supply drops, snacks and map events
-- only ever land where players can walk.
function ArenaKit.MarkPlayable(folder: Instance)
	local floor = folder:FindFirstChild("Floor")
	if floor then
		CollectionService:AddTag(floor, "DropZone")
	end
end

-- A point on `toIsle`'s surface `dist` from its centre, on the side facing
-- `fromPos`, turned by `turn` radians (for landing spots).
function ArenaKit.FacingPoint(toIsle: any, fromPos: Vector3, dist: number, turn: number): Vector3
	return ArenaKit.Polar(toIsle, ArenaKit.AngleTo(toIsle.pos, fromPos) + turn, dist)
end

local JUMP_GLOW = Color3.fromRGB(90, 230, 255)

-- Jump pad on `isle` that flings players to `target` (the client computes the
-- arc). Placed as close to `angle` as the walkways allow, and its lane is
-- reserved so decoration keeps clear. Flush with the ground: no step to trip on.
function ArenaKit.AddJumpPad(isle: any, angle: number, dist: number, target: Vector3, parent: Instance): BasePart?
	local chosen: number? = nil
	for _, off in ipairs({ 0, 0.25, -0.25, 0.5, -0.5, 0.75, -0.75, 1, -1 }) do
		local a = angle + off
		local p = ArenaKit.Polar(isle, a, dist)
		local free = not ArenaKit.Blocked(isle, a, dist, 3.5)
		if free then
			for _, q in ipairs(isle.placed) do
				if Vector2.new(p.X - q.x, p.Z - q.z).Magnitude < 3.5 + q.rad then
					free = false
					break
				end
			end
		end
		if free then
			chosen = a
			break
		end
	end
	if not chosen then
		return nil
	end
	local pos = ArenaKit.Polar(isle, chosen, dist)
	ArenaKit.Reserve(isle, pos, 3.5)
	table.insert(isle.reserved, chosen)

	local model = Instance.new("Model")
	model.Name = "JumpPad"
	model.Parent = parent
	local function flat(name: string, d: number, h: number, color: Color3, mat: Enum.Material): BasePart
		local p = ArenaKit.NewDisc(name, d, h, pos + Vector3.new(0, h / 2, 0), color, mat, model)
		p.CanCollide = false
		return p
	end
	flat("PadBase", 5.8, 0.2, Color3.fromRGB(46, 50, 64), Enum.Material.Metal)
	local ring = flat("PadRing", 4.8, 0.24, JUMP_GLOW, Enum.Material.Neon)
	ring.CastShadow = false
	flat("PadCore", 3.3, 0.28, Color3.fromRGB(28, 58, 82), Enum.Material.Metal)
	local toward = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z).Unit
	for k = 0, 2 do
		local c = pos + toward * (-0.75 + k * 0.75) + Vector3.new(0, 0.34, 0)
		local cf = CFrame.lookAt(c, c + toward)
		for s = -1, 1, 2 do
			local bar = ArenaKit.NewPart("Chevron", Vector3.new(0.9, 0.08, 0.22), cf * CFrame.new(s * 0.3, 0, 0) * CFrame.Angles(0, math.rad(-35 * s), 0), JUMP_GLOW, Enum.Material.Neon, model)
			bar.CanCollide = false
			bar.CastShadow = false
		end
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(JUMP_GLOW)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparks.Lifetime = NumberRange.new(0.6, 1.1)
	sparks.Speed = NumberRange.new(4, 9)
	sparks.SpreadAngle = Vector2.new(12, 12)
	sparks.Rate = 10
	sparks.EmissionDirection = Enum.NormalId.Right -- the disc's X axis points up
	sparks.Parent = ring
	local light = Instance.new("PointLight")
	light.Color = JUMP_GLOW
	light.Range = 10
	light.Brightness = 1
	light.Parent = ring
	CollectionService:AddTag(ring, "JumpPad")
	ring:SetAttribute("Target", target)
	return ring
end

-- Invisible walking surface between two rim points `ea` (on island A, at A's
-- ground height) and `eb`: a smooth ramp plus a flat landing reaching 4 studs
-- into each island, and side guards over the gap. The ramp must end exactly at
-- each island's ground height at its rim; ending it further in left it under
-- the higher island's floor, a hidden ledge players couldn't step up.
local function rampCollision(ea: Vector3, eb: Vector3, width: number, parent: Instance)
	local flat = Vector3.new(eb.X - ea.X, 0, eb.Z - ea.Z).Unit
	local function slab(name: string, p: Vector3, q: Vector3)
		local s = ArenaKit.NewPart(name, Vector3.new(width, 1, (q - p).Magnitude + 0.3), CFrame.lookAt((p + q) / 2, q) * CFrame.new(0, -0.5, 0), Color3.new(0.5, 0.5, 0.5), Enum.Material.SmoothPlastic, parent)
		s.Transparency = 1
	end
	slab("Deck", ea, eb)
	slab("Landing", ea - flat * 4, ea)
	slab("Landing", eb, eb + flat * 4)
	local spanCF = CFrame.lookAt((ea + eb) / 2, eb)
	for _, x in ipairs({ -(width / 2 + 0.2), width / 2 + 0.2 }) do
		local guard = ArenaKit.NewPart("Guard", Vector3.new(0.3, 2.6, (eb - ea).Magnitude), spanCF * CFrame.new(x, 1.3, 0), Color3.new(0.5, 0.5, 0.5), Enum.Material.SmoothPlastic, parent)
		guard.Transparency = 1
		guard.CanQuery = false
	end
end

-- Walkway collision between two isles. Returns the inset span endpoints (for
-- visuals) and the rim endpoints the ramp runs between.
function ArenaKit.WalkwayCollision(A: any, B: any, parent: Instance, width: number, inset: number): (Vector3, Vector3, Vector3, Vector3)
	local a, b = ArenaKit.EdgePoints(A, B, inset)
	local ea, eb = ArenaKit.EdgePoints(A, B, -0.3)
	rampCollision(ea, eb, width, parent)
	return a, b, ea, eb
end

export type StairStyle = { step: Color3, stepAlt: Color3, wall: Color3, under: Color3, material: Enum.Material }

-- Stone staircase between two tiers: invisible ramp for smooth walking,
-- visual steps, a support block underneath and parapet walls with newels.
function ArenaKit.MakeStairs(A: any, B: any, parent: Instance, st: StairStyle)
	local f = Instance.new("Folder")
	f.Name = "Stairs"
	f.Parent = parent
	local _, _, a, b = ArenaKit.WalkwayCollision(A, B, f, 8.4, 1.5)
	local lo, hi = a, b
	if b.Y > a.Y then
		lo, hi = b, a
	end
	local rise = hi.Y - lo.Y
	local runV = Vector3.new(hi.X - lo.X, 0, hi.Z - lo.Z)
	local n = math.max(5, math.floor(rise / 0.7 + 0.5))
	local rot = CFrame.lookAt(lo, lo + runV).Rotation
	for k = 1, n do
		local top = lo.Y + (k - 0.5) * rise / n
		local p = lo + runV * ((k - 0.5) / n)
		ArenaKit.NewPart("Step", Vector3.new(8.4, 1.4, runV.Magnitude / n + 0.1), CFrame.new(p.X, top - 0.7, p.Z) * rot, k % 2 == 0 and st.step or st.stepAlt, st.material, f).CanCollide = false
	end
	local under = (lo + hi) / 2 - Vector3.new(0, rise * 0.5 + 2.2, 0)
	ArenaKit.NewPart("Support", Vector3.new(7.6, 3, runV.Magnitude * 0.7), CFrame.new(under) * rot, st.under, st.material, f).CanCollide = false
	local right = rot.RightVector
	for _, x in ipairs({ -4.6, 4.6 }) do
		local p0, p1 = lo + right * x, hi + right * x
		ArenaKit.NewPart("Parapet", Vector3.new(0.9, 1.3, (p1 - p0).Magnitude + 1), CFrame.lookAt((p0 + p1) / 2 + Vector3.new(0, 0.65, 0), p1 + Vector3.new(0, 0.65, 0)), st.wall, st.material, f)
		for _, p in ipairs({ p0, p1 }) do
			ArenaKit.NewPart("Newel", Vector3.new(1.3, 2.2, 1.3), CFrame.new(p + Vector3.new(0, 1.1, 0)), st.wall, st.material, f)
			ArenaKit.NewPart("NewelCap", Vector3.new(1.6, 0.4, 1.6), CFrame.new(p + Vector3.new(0, 2.4, 0)), st.stepAlt, st.material, f).CanCollide = false
		end
	end
end

-- Plain wooden bridge: one smooth collision deck (no plank seams to snag on)
-- with visual planks and rails on top.
function ArenaKit.MakeBridge(a: Vector3, b: Vector3, parent: Instance, palette: Palette)
	local folder = Instance.new("Folder")
	folder.Name = "Bridge"
	folder.Parent = parent
	local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
	local a2, b2 = a - flat * 2, b + flat * 2
	local dist = (b2 - a2).Magnitude
	local cf = CFrame.lookAt((a2 + b2) / 2, b2)
	ArenaKit.NewPart("Deck", Vector3.new(5.2, 0.6, dist), cf * CFrame.new(0, -0.3, 0), palette.Wood, Enum.Material.WoodPlanks, folder).CanCollide = false
	-- a and b sit 2 studs inside each rim; walk on a rim-to-rim ramp instead.
	rampCollision(a + flat * 2.3, b - flat * 2.3, 5.2, folder)
	for _, side in ipairs({ -2.6, 2.6 }) do
		ArenaKit.NewPart("Rail", Vector3.new(0.3, 0.3, dist), cf * CFrame.new(side, 1.5, 0), palette.WoodDark, Enum.Material.Wood, folder).CanCollide = false
	end
end

-- A single spawn marker. teamId may be nil for a universal/neutral spawn.
function ArenaKit.AddSpawn(pos: Vector3, teamId: string?, spawns: Folder)
	local pad = Instance.new("Part")
	pad.Name = "Spawn_" .. (teamId or "Neutral") .. "_" .. tostring(#spawns:GetChildren() + 1)
	pad.Size = Vector3.new(4, 1, 4)
	pad.Position = pos
	pad.Anchored = true
	pad.CanCollide = false
	pad.Transparency = 1
	pad:SetAttribute("Team", teamId)
	pad.Parent = spawns
end

-- Exactly 6 spawns per island, hexagon-arranged at half the island's radius —
-- always well inside the solid top, always a safe short drop above the
-- collidable Floor, never near an edge. Used identically by every map.
function ArenaKit.AddHexSpawns(center: Vector3, radius: number, teamId: string?, spawns: Folder)
	local r = radius * 0.5
	for k = 0, 5 do
		local ang = math.rad(k * 60)
		local offset = Vector3.new(math.cos(ang) * r, 3, math.sin(ang) * r)
		ArenaKit.AddSpawn(center + offset, teamId, spawns)
	end
end

-- Competitive team layout: three grounded points on each team island. The
-- marker is only a fraction above the transparent Floor's top surface, so
-- the character root settles onto the island instead of spawning in midair.
function ArenaKit.AddTeamTriangleSpawns(center: Vector3, radius: number, teamId: string, spawns: Folder)
	local ring = radius * 0.35
	for k = 0, 2 do
		local ang = math.rad(30 + k * 120)
		ArenaKit.AddSpawn(center + Vector3.new(math.cos(ang) * ring, 2.25, math.sin(ang) * ring), teamId, spawns)
	end
end

-- Readable in-world markers for the same three authoritative spawn positions.
-- They sit on the island top, so the team start is visually part of the map
-- instead of looking like an invisible floating respawn volume.
function ArenaKit.AddTeamSpawnBeacons(center: Vector3, radius: number, teamId: string, parent: Instance)
	local color = teamId == "Red" and Color3.fromRGB(255, 92, 102) or Color3.fromRGB(72, 174, 255)
	local ring = radius * 0.35
	for k = 0, 2 do
		local ang = math.rad(30 + k * 120)
		local pos = center + Vector3.new(math.cos(ang) * ring, 1.78, math.sin(ang) * ring)
		local pad = ArenaKit.NewDisc("TeamSpawnPad", 5.2, 0.16, pos, color, Enum.Material.Neon, parent)
		pad.Transparency = 0.48
		pad.CanCollide = false
		local core = ArenaKit.NewDisc("TeamSpawnCore", 2.4, 0.08, pos + Vector3.new(0, 0.11, 0), color, Enum.Material.Glass, parent)
		core.Transparency = 0.22
		core.CanCollide = false
	end
end

function ArenaKit.AddPowerPad(pos: Vector3, pads: Folder)
	local pad = ArenaKit.NewDisc("PowerPad", 4, 0.4, pos + Vector3.new(0, 1.8, 0), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, pads)
	pad.Transparency = 0.5
	pad.CanCollide = false
end

-- Small floating debris scattered through open air between islands.
function ArenaKit.MakeDebris(pos: Vector3, size: number, parent: Instance, palette: Palette, topAccent: boolean?)
	local folder = Instance.new("Folder")
	folder.Name = "FloatingChunk"
	folder.Parent = parent
	local yaw = math.rad(math.random(0, 359))
	local top = ArenaKit.NewPart(
		"ChunkTop",
		Vector3.new(size * 1.45, size * 0.26, size * 1.15),
		CFrame.new(pos + Vector3.new(0, size * 0.18, 0)) * CFrame.Angles(0, yaw, math.rad(math.random(-5, 5))),
		(topAccent ~= false) and palette.Top or palette.Stone,
		(topAccent ~= false) and Enum.Material.Grass or Enum.Material.Slate,
		folder
	)
	top.CanCollide = false
	local core = ArenaKit.NewPart(
		"ChunkCore",
		Vector3.new(size * 1.28, size * 0.9, size),
		CFrame.new(pos - Vector3.new(0, size * 0.25, 0)) * CFrame.Angles(math.rad(math.random(-10, 10)), yaw, math.rad(math.random(-8, 8))),
		palette.Stone,
		Enum.Material.Slate,
		folder
	)
	core.CanCollide = false
	for i = 1, 3 do
		local a = yaw + math.rad(i * 115)
		local shard = ArenaKit.NewWedge(
			"ChunkFacet" .. i,
			Vector3.new(size * 0.42, size * 0.82, size * 0.36),
			CFrame.new(pos + Vector3.new(math.cos(a) * size * 0.34, -size * 0.38, math.sin(a) * size * 0.34)) * CFrame.Angles(0, a, 0),
			(i % 2 == 0) and palette.StoneDark or palette.Stone,
			Enum.Material.Slate,
			folder
		)
		shard.CanCollide = false
	end
	if topAccent ~= false and math.random() > 0.45 then
		local tuft = ArenaKit.NewPart(
			"ChunkTuft",
			Vector3.new(size * 0.42, size * 0.18, size * 0.34),
			CFrame.new(pos + Vector3.new(0, size * 0.42, 0)) * CFrame.Angles(0, yaw + math.rad(18), 0),
			palette.TopDark,
			Enum.Material.Grass,
			folder
		)
		tuft.CanCollide = false
	end
end

function ArenaKit.ScatterDebris(arena: Instance, count: number, palette: Palette, topAccent: boolean?)
	for i = 1, count do
		local angle = math.random() * math.pi * 2
		local dist = 20 + math.random() * 75
		local height = -10 + math.random() * 40
		local pos = Vector3.new(math.cos(angle) * dist, height, math.sin(angle) * dist)
		ArenaKit.MakeDebris(pos, 2 + math.random() * 3, arena, palette, topAccent)
	end
end

function ArenaKit.MakeClouds(arena: Instance, color: Color3, lowTransparency: number?)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local cloud = ArenaKit.NewPart("Cloud", Vector3.new(30, 6, 30), CFrame.new(math.cos(a) * 90, -40, math.sin(a) * 90), color, Enum.Material.SmoothPlastic, arena)
		cloud.Shape = Enum.PartType.Ball
		cloud.Transparency = lowTransparency or 0.3
		cloud.CanCollide = false
	end
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.4
		local cloud = ArenaKit.NewPart("CloudHigh", Vector3.new(24, 5, 24), CFrame.new(math.cos(a) * 60, 55 + math.random() * 20, math.sin(a) * 60), color, Enum.Material.SmoothPlastic, arena)
		cloud.Shape = Enum.PartType.Ball
		cloud.Transparency = (lowTransparency or 0.3) + 0.15
		cloud.CanCollide = false
	end
end

-- Fresh Arena/Spawns/PowerUpPads folder structure — identical shape every map
-- must produce so PlayerService/PowerUpService work unchanged regardless of
-- which map is active.
function ArenaKit.SetupFolders(workspaceService: Workspace, mapName: string): (Folder, Folder, Folder)
	local existing = workspaceService:FindFirstChild("Arena")
	if existing then
		existing:Destroy()
	end
	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena:SetAttribute("MapName", mapName)
	arena.Parent = workspaceService

	local spawns = Instance.new("Folder")
	spawns.Name = "Spawns"
	spawns.Parent = arena

	local powerPads = Instance.new("Folder")
	powerPads.Name = "PowerUpPads"
	powerPads.Parent = arena

	return arena, spawns, powerPads
end

-- Shared island layout used by every map — positions/radii are the same ones
-- whose spawn-safety math (hex spawns at half-radius, always above a solid
-- collidable Floor) was already verified. Reusing it means every new map
-- inherits that same safety guarantee and the same tested team balance,
-- instead of re-deriving island placement (and re-risking a bad one) per map.
ArenaKit.StandardLayout = {
	-- Reference-inspired vertical arena: a broad center island, elevated side
	-- islands, and two team ledges that create the same layered skyline.
	Center = { pos = Vector3.new(0, 0, 0), r = 32 },
	Outer = {
		{ pos = Vector3.new(0, 8, -76), r = 24, team = "Blue" },
		{ pos = Vector3.new(0, 8, 76), r = 24, team = "Red" },
		{ pos = Vector3.new(-72, 10, -12), r = 23, team = nil },
		{ pos = Vector3.new(72, 14, 12), r = 23, team = nil },
		{ pos = Vector3.new(-56, 22, -58), r = 18, team = nil },
		{ pos = Vector3.new(56, 26, 58), r = 18, team = nil },
	},
	Satellites = {
		{ pos = Vector3.new(30, 30, 34), r = 9 },
		{ pos = Vector3.new(-30, 34, -34), r = 8 },
		{ pos = Vector3.new(0, 38, 0), r = 7 },
	},
}

function ArenaKit.ApplyAtmosphere(opts: any)
	local Lighting = game:GetService("Lighting")
	local existing = Lighting:FindFirstChildOfClass("Atmosphere")
	if existing then
		existing:Destroy()
	end
	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = opts.Density or 0.28
	atmosphere.Offset = opts.Offset or 0.15
	atmosphere.Color = opts.Color or Color3.fromRGB(200, 220, 255)
	atmosphere.Decay = opts.Decay or Color3.fromRGB(95, 140, 200)
	atmosphere.Glare = opts.Glare or 0.25
	atmosphere.Haze = opts.Haze or 1.4
	atmosphere.Parent = Lighting

	if opts.Ambient then
		Lighting.Ambient = opts.Ambient
	end
	if opts.OutdoorAmbient then
		Lighting.OutdoorAmbient = opts.OutdoorAmbient
	end
	if opts.ClockTime then
		Lighting.ClockTime = opts.ClockTime
	end
	if opts.FogColor then
		Lighting.FogColor = opts.FogColor
	end
	if opts.FogEnd then
		Lighting.FogEnd = opts.FogEnd
	end
	Lighting.Brightness = opts.Brightness or 2

	-- A Sky created here keeps Roblox's built-in skybox textures but can hide
	-- the sun and moon (the Volcano's smoky dusk shouldn't show a moon).
	local sky = Lighting:FindFirstChild("ArenaSky")
	if opts.HideCelestial then
		if not sky then
			sky = Instance.new("Sky")
			sky.Name = "ArenaSky"
			sky.Parent = Lighting
		end
		local s = sky :: Sky
		s.CelestialBodiesShown = false
		s.StarCount = 0
	elseif sky then
		sky:Destroy()
	end
end

-- Puffy cloud clusters in a band around the arena (sea of clouds / smoke).
function ArenaKit.MakeCloudBank(arena: Instance, color: Color3, count: number, yMin: number, yMax: number, rMin: number, rMax: number, transparency: number)
	local folder = Instance.new("Folder")
	folder.Name = "Clouds"
	folder.Parent = arena
	local rng = Random.new(count * 17 + math.floor(yMin))
	for i = 1, count do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(rMin, rMax)
		local base = Vector3.new(math.cos(a) * d, rng:NextNumber(yMin, yMax), math.sin(a) * d)
		local size = rng:NextNumber(14, 30)
		for k = 1, rng:NextInteger(3, 6) do
			local s = size * rng:NextNumber(0.55, 1)
			local off = Vector3.new(rng:NextNumber(-1, 1) * size * 0.8, rng:NextNumber(-0.15, 0.3) * size, rng:NextNumber(-1, 1) * size * 0.8)
			local puff = ArenaKit.NewPart("Puff" .. i .. "_" .. k, Vector3.new(s, s, s), CFrame.new(base + off), color, Enum.Material.SmoothPlastic, folder)
			puff.Shape = Enum.PartType.Ball
			puff.Transparency = transparency
			puff.CanCollide = false
			puff.CastShadow = false
		end
	end
end

return ArenaKit
