--!strict
-- ArenaKit: shared building blocks used by every map (SkyIslands, Volcano,
-- Toybox). Each map supplies its own palette + decoration functions; the
-- island/bridge/spawn/power-pad geometry — and, critically, the safety
-- guarantees around spawn placement — live here ONCE so every map gets them
-- identically instead of being re-derived (and possibly re-broken) per map.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MeshLib = require(ReplicatedStorage.Shared.MeshLib)

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
	meshes: boolean?, -- sculpted rock cliffs, underside and grass lip (MeshLib)
	softBlocks: boolean?, -- cliffs as soft rounded toy blocks (MeshLib)
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
	local rocky = st.meshes == true and MeshLib.Has("U_Cliff1")
	local soft = st.softBlocks == true and MeshLib.Has("U_SoftBlock")
	local rng = Random.new(math.floor(center.X * 7 + center.Y * 3 + center.Z * 13 + radius * 31))
	local surf = center.Y + ArenaKit.SURFACE
	local function shade(): Color3
		return palette.Stone:Lerp(palette.StoneDark, rng:NextNumber())
	end

	ArenaKit.NewDisc("Floor", radius * 2, 3, Vector3.new(center.X, surf - 1.5, center.Z), palette.Top, topMat, folder)
	if rocky then
		MeshLib.Fill("U_GrassLip", CFrame.new(center.X, surf - 1.0, center.Z), Vector3.new(radius * 2 + 1.6, 1.6, radius * 2 + 1.6), palette.TopDark, topMat, folder)
	else
		ArenaKit.NewDisc("Lip", radius * 2 + 1.6, 1.6, Vector3.new(center.X, surf - 1.0, center.Z), palette.TopDark, topMat, folder).CanCollide = false
	end

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
		local cliffCF, cliffSize, cliffColor = CFrame.lookAt(pos, pos + out), Vector3.new(colW, h, colD), shade()
		if rocky then
			MeshLib.Fill("U_Cliff" .. (i % 3 + 1), cliffCF, cliffSize, cliffColor, cliffMat, folder)
		elseif soft then
			MeshLib.Fill("U_SoftBlock", cliffCF, cliffSize, cliffColor, cliffMat, folder)
		else
			ArenaKit.NewPart("Cliff" .. i, cliffSize, cliffCF, cliffColor, cliffMat, folder).CanCollide = false
		end
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
	if rocky then
		MeshLib.Fill("U_RockDrum", CFrame.new(center.X, colTop - colH * 0.45, center.Z), Vector3.new(coreR * 2, colH * 0.9, coreR * 2), palette.StoneDark, cliffMat, folder)
	else
		ArenaKit.NewDisc("Core", coreR * 2, colH * 0.9, Vector3.new(center.X, colTop - colH * 0.45, center.Z), palette.StoneDark, cliffMat, folder).CanCollide = false
	end

	local y = colTop - colH * 0.9
	local r = ringR
	for k = 1, 2 do
		r *= 0.66
		local h = 3 + radius * 0.14
		if rocky then
			MeshLib.Fill("U_RockDrum", CFrame.new(center.X, y - h / 2, center.Z) * CFrame.Angles(0, k * 1.3, 0), Vector3.new(r * 2, h, r * 2), shade(), cliffMat, folder)
		else
			ArenaKit.NewDisc("Taper" .. k, r * 2, h, Vector3.new(center.X, y - h / 2, center.Z), shade(), cliffMat, folder).CanCollide = false
		end
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
		local hangSize = Vector3.new(w, h, w * rng:NextNumber(0.8, 1.2))
		if rocky then
			MeshLib.Fill("U_Hang" .. (i % 2 + 1), CFrame.new(pos) * CFrame.Angles(0, a, 0), hangSize, shade(), cliffMat, folder)
		else
			ArenaKit.NewPart("Hang" .. i, hangSize, CFrame.new(pos) * CFrame.Angles(0, a, 0), shade(), cliffMat, folder).CanCollide = false
		end
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
	-- (solid: it can end up standing on the lower island, where you walked into it)
	ArenaKit.NewPart("Support", Vector3.new(7.6, 3, runV.Magnitude * 0.7), CFrame.new(under) * rot, st.under, st.material, f)
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

-- One team spawn point with its glowing pad, at pos (an island-centre-height
-- point well inside a playable island). Maps give each team three of these
-- on different islands so a whole team never piles out of one spot.
function ArenaKit.AddTeamSpawnPoint(pos: Vector3, teamId: string, spawns: Folder, parent: Instance)
	ArenaKit.AddSpawn(pos + Vector3.new(0, 2.25, 0), teamId, spawns)
	local color = teamId == "Red" and Color3.fromRGB(255, 92, 102) or Color3.fromRGB(72, 174, 255)
	local pad = ArenaKit.NewDisc("TeamSpawnPad", 5.2, 0.16, pos + Vector3.new(0, 1.78, 0), color, Enum.Material.Neon, parent)
	pad.Transparency = 0.48
	pad.CanCollide = false
	local core = ArenaKit.NewDisc("TeamSpawnCore", 2.4, 0.08, pos + Vector3.new(0, 1.89, 0), color, Enum.Material.Glass, parent)
	core.Transparency = 0.22
	core.CanCollide = false
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
	atmosphere.Glare = math.min(opts.Glare or 0.25, 0.08) -- (glare and haze were blinding with Future lighting)
	atmosphere.Haze = math.min(opts.Haze or 1.4, 1)
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

-- ── swim columns ─────────────────────────────────────────────────────────────
-- A column off an island's edge you can swim in (MovementController): SPACE /
-- jump goes up, SHIFT goes down, and after 15 seconds in it you're flung to a
-- random spot on the map. Each map has its own kind:
--   Water   - a waterfall pouring off the edge (you drift down)
--   Steam   - a volcanic vent's updraft (you drift up)
--   Bubbles - a clear toy tube full of rising bubbles
--   Wind    - an industrial fan blowing up past a roof
-- `above` / `below` are how far the column reaches over and under the
-- island's surface. Each plays its own loop (Config.Sounds).
ArenaKit.SwimKinds = {
	Water = { above = 0.6, below = 55, width = 10, depth = 7, drift = -4, sound = "Waterfall", color = Color3.fromRGB(118, 204, 242) },
	Steam = { above = 22, below = 40, width = 9, depth = 9, drift = 6, sound = "SteamVent", color = Color3.fromRGB(236, 236, 242) },
	Bubbles = { above = 16, below = 40, width = 9, depth = 9, drift = 3, sound = "Bubbles", color = Color3.fromRGB(150, 220, 255) },
	Wind = { above = 22, below = 32, width = 10, depth = 10, drift = 7, sound = "FanWind", color = Color3.fromRGB(200, 230, 255) },
}

local function swimDeco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

local function swimParticles(parent: BasePart, texture: string, color: ColorSequence, dir: Enum.NormalId, speed: NumberRange, size: NumberSequence, rate: number, lifetime: NumberRange): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = color
	e.EmissionDirection = dir
	e.Speed = speed
	e.Size = size
	e.Rate = rate
	e.Lifetime = lifetime
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.45), NumberSequenceKeypoint.new(1, 1) })
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.LightEmission = 0.2
	e.Parent = parent
	return e
end

function ArenaKit.AddSwimColumn(kind: string, isle: any, angle: number, parent: Instance): BasePart
	local spec = ArenaKit.SwimKinds[kind]
	table.insert(isle.reserved, angle)
	local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local h = spec.above + spec.below
	-- The column overlaps the island's rim a little, so stepping off the
	-- edge drops you straight in.
	local base = ArenaKit.Polar(isle, angle, isle.r + spec.depth / 2 - 1)
	local mid = base + Vector3.new(0, (spec.above - spec.below) / 2, 0)
	local face = CFrame.lookAt(mid, mid + out) -- -Z faces away from the island
	local top = base + Vector3.new(0, spec.above, 0)
	local bottom = base - Vector3.new(0, spec.below, 0)
	local folder = Instance.new("Folder")
	folder.Name = kind .. "Column"
	folder.Parent = parent

	local zone = Instance.new("Part")
	zone.Name = "SwimZone"
	zone.Size = Vector3.new(spec.width, h, spec.depth)
	zone.CFrame = face
	zone.Anchored = true
	zone.CanCollide = false
	zone.CanQuery = false
	zone.CanTouch = false
	zone.Transparency = 1
	zone:SetAttribute("Kind", kind)
	zone:SetAttribute("Drift", spec.drift)
	zone:SetAttribute("Sound", spec.sound)
	zone.Parent = folder
	CollectionService:AddTag(zone, "SwimZone")
	local white = Color3.new(1, 1, 1)
	local NP = ArenaKit.NewPart

	if kind == "Water" then
		-- A stream across the top, the falling water, foam where it spills and
		-- mist at the bottom.
		local from = ArenaKit.Polar(isle, angle, isle.r * 0.55)
		local lip = ArenaKit.Polar(isle, angle, isle.r - 0.5)
		local len = (lip - from).Magnitude
		swimDeco(NP("StreamBank", Vector3.new(6.4, 0.22, len), CFrame.lookAt((from + lip) / 2 + Vector3.new(0, 0.08, 0), lip + Vector3.new(0, 0.08, 0)), Color3.fromRGB(142, 136, 126), Enum.Material.Slate, folder))
		swimDeco(NP("Stream", Vector3.new(5, 0.25, len), CFrame.lookAt((from + lip) / 2 + Vector3.new(0, 0.14, 0), lip + Vector3.new(0, 0.14, 0)), spec.color, Enum.Material.Glass, folder)).Transparency = 0.12
		swimDeco(NP("WaterColumn", Vector3.new(spec.width - 0.6, h, spec.depth - 0.6), face, spec.color, Enum.Material.Glass, folder)).Transparency = 0.45
		swimDeco(NP("WaterSheet", Vector3.new(spec.width - 1.6, h, 0.6), face * CFrame.new(0, 0, -(spec.depth / 2 - 0.8)), spec.color:Lerp(white, 0.2), Enum.Material.Glass, folder)).Transparency = 0.2
		swimDeco(NP("WaterFoam", Vector3.new(spec.width + 0.4, 1.1, spec.depth), CFrame.new(top - Vector3.new(0, 0.3, 0)) * face.Rotation, white, Enum.Material.SmoothPlastic, folder)).Transparency = 0.15
		swimDeco(NP("WaterMist", Vector3.new(spec.width + 3, 10, spec.depth + 3), CFrame.new(bottom + Vector3.new(0, 4, 0)) * face.Rotation, white, Enum.Material.SmoothPlastic, folder)).Transparency = 0.7
		swimParticles(zone, "rbxasset://textures/particles/smoke_main.dds", ColorSequence.new(white), Enum.NormalId.Bottom,
			NumberRange.new(28, 40), NumberSequence.new(1.4, 3), 30, NumberRange.new(1.2, 1.6))
	elseif kind == "Steam" then
		-- A glowing vent at the bottom and steam rising all the way up.
		local glow = swimDeco(NP("VentGlow", Vector3.new(spec.width, 1, spec.depth), CFrame.new(bottom + Vector3.new(0, 0.5, 0)) * face.Rotation, Color3.fromRGB(255, 120, 40), Enum.Material.Neon, folder))
		glow.Transparency = 0.25
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 140, 60)
		l.Range = 24
		l.Brightness = 2
		l.Parent = glow
		swimDeco(NP("SteamHaze", zone.Size - Vector3.new(1, 0, 1), face, spec.color, Enum.Material.SmoothPlastic, folder)).Transparency = 0.86
		swimParticles(zone, "rbxasset://textures/particles/smoke_main.dds", ColorSequence.new(spec.color), Enum.NormalId.Top,
			NumberRange.new(22, 32), NumberSequence.new(3, 8), 40, NumberRange.new(1.6, 2.2))
	elseif kind == "Bubbles" then
		-- A clear tube with candy-coloured rings and bubbles rising in it.
		local tube = NP("BubbleTube", Vector3.new(h, spec.width, spec.width), CFrame.new(mid) * CFrame.Angles(0, 0, math.rad(90)), spec.color, Enum.Material.Glass, folder) :: Part
		tube.Shape = Enum.PartType.Cylinder
		swimDeco(tube).Transparency = 0.72
		local rings = { Color3.fromRGB(255, 110, 150), Color3.fromRGB(255, 210, 70), Color3.fromRGB(110, 210, 255), Color3.fromRGB(140, 230, 120) }
		local k = 0
		for y = -spec.below + 4, spec.above - 1, 8 do
			k += 1
			swimDeco(ArenaKit.NewDisc("TubeRing", spec.width + 0.8, 0.7, base + Vector3.new(0, y, 0), rings[(k - 1) % #rings + 1], Enum.Material.SmoothPlastic, folder))
		end
		swimParticles(zone, "rbxasset://textures/particles/sparkles_main.dds", ColorSequence.new(Color3.fromRGB(200, 240, 255), Color3.fromRGB(255, 200, 240)), Enum.NormalId.Top,
			NumberRange.new(10, 18), NumberSequence.new(0.8, 1.6), 26, NumberRange.new(2.5, 3.5))
	elseif kind == "Wind" then
		-- A fan in a steel frame at the bottom, girders up the side, a lit
		-- ring at roof level and wind streaks rushing up.
		local metal = Color3.fromRGB(60, 64, 76)
		swimDeco(ArenaKit.NewDisc("FanHousing", spec.width + 1, 1.2, bottom + Vector3.new(0, 0.6, 0), metal, Enum.Material.Metal, folder))
		for b = 0, 3 do
			swimDeco(NP("FanBlade", Vector3.new(spec.width * 0.42, 0.2, 1.6), CFrame.new(bottom + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, b * math.pi / 2, math.rad(18)) * CFrame.new(spec.width * 0.22, 0, 0), Color3.fromRGB(180, 186, 198), Enum.Material.Metal, folder))
		end
		for _, c in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
			local p = face * CFrame.new(c[1] * spec.width / 2, 0, c[2] * spec.depth / 2)
			swimDeco(NP("ShaftGirder", Vector3.new(0.6, h, 0.6), p, metal, Enum.Material.Metal, folder))
		end
		swimDeco(NP("ShaftRing", Vector3.new(spec.width + 0.6, 0.3, spec.depth + 0.6), CFrame.new(base + Vector3.new(0, 0.2, 0)) * face.Rotation, Color3.fromRGB(80, 220, 255), Enum.Material.Neon, folder)).Transparency = 0.3
		local e = swimParticles(zone, "rbxasset://textures/particles/smoke_main.dds", ColorSequence.new(spec.color), Enum.NormalId.Top,
			NumberRange.new(45, 60), NumberSequence.new(0.5), 60, NumberRange.new(0.8, 1.1))
		e.Orientation = Enum.ParticleOrientation.VelocityParallel
		e.Squash = NumberSequence.new(-2.5)
	end
	return zone
end

-- A ladder (a climbable truss) standing at `base`, `height` tall, its back to
-- the wall it's on (`outward` points away from that wall).
function ArenaKit.AddLadder(base: Vector3, height: number, outward: Vector3, parent: Instance): TrussPart
	local h = math.max(2, math.ceil(height / 2) * 2)
	local flat = Vector3.new(outward.X, 0, outward.Z).Unit
	local c = base + Vector3.new(0, h / 2, 0)
	local t = Instance.new("TrussPart")
	t.Name = "Ladder"
	t.Size = Vector3.new(2, h, 2)
	t.Style = Enum.Style.AlternatingSupports
	t.CFrame = CFrame.lookAt(c, c + flat)
	t.Color = Color3.fromRGB(122, 84, 54)
	t.Material = Enum.Material.Wood
	t.Anchored = true
	t.Parent = parent
	return t
end

-- ── map features ─────────────────────────────────────────────────────────────
-- Built here, run by MapFeatureService (server), MovementController and
-- MapLife (client).

-- A zipline across the gap between two islands: a steel gantry at each edge
-- and two cables (one each way), each running from high on its start
-- gantry down to the far one. Walk into the handle at the start to grab it
-- and slide across (MovementController). Reserves both edges.
function ArenaKit.AddRopeSwing(A: any, B: any, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Zipline"
	folder.Parent = parent
	local aAng, bAng = ArenaKit.AngleTo(A.pos, B.pos), ArenaKit.AngleTo(B.pos, A.pos)
	table.insert(A.reserved, aAng)
	table.insert(B.reserved, bAng)
	local ea, eb = ArenaKit.Polar(A, aAng, A.r - 2.5), ArenaKit.Polar(B, bAng, B.r - 2.5)
	local u = Vector3.new(eb.X - ea.X, 0, eb.Z - ea.Z).Unit
	local side = Vector3.new(-u.Z, 0, u.X)
	local steel, dark, yellow = Color3.fromRGB(150, 156, 168), Color3.fromRGB(60, 62, 70), Color3.fromRGB(255, 200, 40)
	local HIGH, LOW = 12, 7 -- cable height over the start / the end
	for _, e in ipairs({ ea, eb }) do
		for _, s in ipairs({ -1, 1 }) do
			local p = e + side * s * 3.6
			ArenaKit.NewPart("ZipPost", Vector3.new(1, HIGH + 1.5, 1), CFrame.new(Vector3.new(p.X, e.Y + (HIGH + 1.5) / 2 - 0.5, p.Z)), steel, Enum.Material.Metal, folder)
		end
		ArenaKit.Beam("ZipBar", Vector3.new(e.X, e.Y + HIGH + 0.6, e.Z) - side * 4, Vector3.new(e.X, e.Y + HIGH + 0.6, e.Z) + side * 4, 0.8, dark, Enum.Material.Metal, folder)
		ArenaKit.Beam("ZipBarLow", Vector3.new(e.X, e.Y + LOW + 0.4, e.Z) - side * 4, Vector3.new(e.X, e.Y + LOW + 0.4, e.Z) + side * 4, 0.6, dark, Enum.Material.Metal, folder)
	end
	for _, d in ipairs({ { ea, eb, 1 }, { eb, ea, -1 } }) do
		local from, to, s = d[1], d[2], d[3]
		local off = side * s * 2
		local top = Vector3.new(from.X, from.Y + HIGH, from.Z) + off
		local bottom = Vector3.new(to.X, to.Y + LOW, to.Z) + off
		ArenaKit.Beam("ZipCable", top, bottom, 0.22, Color3.fromRGB(30, 30, 34), Enum.Material.Metal, folder)
		-- The handle hanging at the start: yellow, easy to spot.
		local grab = from + off + Vector3.new(0, 2.6, 0)
		local handle = swimDeco(ArenaKit.NewPart("ZipHandle", Vector3.new(2.4, 0.4, 0.4), CFrame.lookAt(grab + Vector3.new(0, 1.6, 0), grab + Vector3.new(0, 1.6, 0) + side), yellow, Enum.Material.SmoothPlastic, folder))
		swimDeco(ArenaKit.Beam("ZipStrap", top, handle.Position, 0.12, yellow, Enum.Material.Fabric, folder))
		handle:SetAttribute("Zip", true)
		handle:SetAttribute("Grab", grab)
		handle:SetAttribute("HangA", top - Vector3.new(0, 3, 0))
		handle:SetAttribute("HangB", bottom - Vector3.new(0, 3, 0))
		handle:SetAttribute("Land", to + u * s * 3.5 + off + Vector3.new(0, 2.6, 0))
		CollectionService:AddTag(handle, "RopeSwing")
	end
end

-- Spots where a few birds peck about (MapLife scares them off).
function ArenaKit.AddBirdSpots(isle: any, rng: Random, count: number, parent: Instance)
	for _ = 1, count do
		local p = ArenaKit.TryPlace(isle, rng, 4, isle.r - 4, 2.5, 3)
		if p then
			ArenaKit.Reserve(isle, p, 2.5)
			local s = swimDeco(ArenaKit.NewPart("BirdSpot", Vector3.one * 0.2, CFrame.new(p), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, parent))
			s.Transparency = 1
			CollectionService:AddTag(s, "BirdSpot")
		end
	end
end

-- A lava geyser in the ground: a basalt rim, glowing cracks and the vent.
-- MapFeatureService makes it rumble, then blast whoever's on it.
function ArenaKit.AddGeyser(pos: Vector3, parent: Instance): BasePart
	local folder = Instance.new("Folder")
	folder.Name = "Geyser"
	folder.Parent = parent
	local lava = Color3.fromRGB(255, 120, 40)
	swimDeco(ArenaKit.NewDisc("GeyserRim", 6.6, 0.5, pos + Vector3.new(0, 0.25, 0), Color3.fromRGB(44, 38, 40), Enum.Material.Basalt, folder))
	for k = 0, 3 do
		local a = k * math.pi / 2 + 0.4
		local d = Vector3.new(math.cos(a), 0, math.sin(a))
		local c = pos + d * 4.6 + Vector3.new(0, 0.04, 0)
		swimDeco(ArenaKit.NewPart("GeyserCrack", Vector3.new(0.35, 0.06, 3.2), CFrame.lookAt(c, c + d), lava, Enum.Material.Neon, folder))
	end
	local vent = swimDeco(ArenaKit.NewDisc("Geyser", 4.4, 0.2, pos + Vector3.new(0, 0.55, 0), lava, Enum.Material.Neon, folder))
	vent.Transparency = 0.35
	local glow = Instance.new("PointLight")
	glow.Color = lava
	glow.Range = 14
	glow.Brightness = 1
	glow.Parent = vent
	-- (Emitters on an upright attachment: the disc itself lies on its side.)
	local spout = Instance.new("Attachment")
	spout.Name = "Spout"
	spout.Parent = vent
	spout.WorldCFrame = CFrame.new(pos + Vector3.new(0, 0.7, 0))
	local smoke = Instance.new("ParticleEmitter")
	smoke.Name = "Smoke"
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(80, 70, 66))
	smoke.Size = NumberSequence.new(1.5, 4)
	smoke.Transparency = NumberSequence.new(0.3, 1)
	smoke.Speed = NumberRange.new(8, 14)
	smoke.SpreadAngle = Vector2.new(20, 20)
	smoke.Lifetime = NumberRange.new(1.2, 1.8)
	smoke.Rate = 25
	smoke.Enabled = false
	smoke.Parent = spout
	local burst = Instance.new("ParticleEmitter")
	burst.Name = "Burst"
	burst.Texture = "rbxasset://textures/particles/fire_main.dds"
	burst.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 30))
	burst.Size = NumberSequence.new(2.2, 0.4)
	burst.Speed = NumberRange.new(60, 90)
	burst.SpreadAngle = Vector2.new(12, 12)
	burst.Acceleration = Vector3.new(0, -60, 0)
	burst.Lifetime = NumberRange.new(0.8, 1.2)
	burst.LightEmission = 1
	burst.Rate = 0
	burst.Parent = spout
	for _, s in ipairs({ { "Rumble", "rbxasset://sounds/action_falling.mp3", 0.8, 0.35 }, { "Blast", "rbxasset://sounds/impact_explosion_03.mp3", 0.7, 1.1 } }) do
		local snd = Instance.new("Sound")
		snd.Name = s[1]
		snd.SoundId = s[2]
		snd.Volume = s[3]
		snd.PlaybackSpeed = s[4]
		snd.RollOffMaxDistance = 90
		snd.Parent = vent
	end
	CollectionService:AddTag(vent, "Geyser")
	return vent
end

-- A giant toy spring: jump on the top and it bounces you straight up
-- (MovementController; it's a JumpPad with a Bounce speed).
function ArenaKit.AddSpring(pos: Vector3, bounce: number, parent: Instance): BasePart
	local folder = Instance.new("Folder")
	folder.Name = "Spring"
	folder.Parent = parent
	swimDeco(ArenaKit.NewDisc("SpringBase", 5.8, 0.5, pos + Vector3.new(0, 0.25, 0), Color3.fromRGB(70, 80, 120), Enum.Material.SmoothPlastic, folder))
	for i = 0, 5 do
		swimDeco(ArenaKit.NewDisc("SpringCoil", 4.2, 0.32, pos + Vector3.new(0, 0.75 + i * 0.42, 0), i % 2 == 0 and Color3.fromRGB(255, 90, 110) or Color3.fromRGB(255, 210, 70), Enum.Material.SmoothPlastic, folder))
	end
	local top = ArenaKit.NewDisc("SpringTop", 5, 0.5, pos + Vector3.new(0, 3.3, 0), Color3.fromRGB(80, 200, 255), Enum.Material.SmoothPlastic, folder)
	top:SetAttribute("Bounce", bounce)
	CollectionService:AddTag(top, "JumpPad")
	return top
end

-- A ball pit: a soft rim, two layers of plastic balls and the region
-- MapFeatureService checks (cats inside are Hidden and wade slowly).
function ArenaKit.AddBallPit(center: Vector3, sx: number, sz: number, rng: Random, parent: Instance): BasePart
	local folder = Instance.new("Folder")
	folder.Name = "BallPit"
	folder.Parent = parent
	swimDeco(ArenaKit.NewPart("PitFloor", Vector3.new(sx, 0.1, sz), CFrame.new(center + Vector3.new(0, 0.05, 0)), Color3.fromRGB(60, 140, 220), Enum.Material.SmoothPlastic, folder))
	local rim = Color3.fromRGB(255, 120, 170)
	for _, e in ipairs({ { 0, sz / 2, sx + 0.8, 0.8 }, { 0, -sz / 2, sx + 0.8, 0.8 }, { sx / 2, 0, 0.8, sz }, { -sx / 2, 0, 0.8, sz } }) do
		swimDeco(ArenaKit.NewPart("RailPit", Vector3.new(e[3], 1.4, e[4]), CFrame.new(center + Vector3.new(e[1], 0.7, e[2])), rim, Enum.Material.Fabric, folder))
	end
	local colors = { Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 210, 70), Color3.fromRGB(90, 200, 255), Color3.fromRGB(130, 230, 120), Color3.fromRGB(190, 130, 255) }
	for layer = 0, 1 do
		for x = -sx / 2 + 0.7, sx / 2 - 0.6, 1.3 do
			for z = -sz / 2 + 0.7, sz / 2 - 0.6, 1.3 do
				local p = center + Vector3.new(x + rng:NextNumber(-0.25, 0.25), 0.65 + layer * 1.05, z + rng:NextNumber(-0.25, 0.25))
				local b = ArenaKit.NewPart("BallPitBall", Vector3.one * 1.3, CFrame.new(p), colors[rng:NextInteger(1, #colors)], Enum.Material.SmoothPlastic, folder) :: Part
				b.Shape = Enum.PartType.Ball
				swimDeco(b)
			end
		end
	end
	local zone = swimDeco(ArenaKit.NewPart("BallPit", Vector3.new(sx, 4, sz), CFrame.new(center + Vector3.new(0, 2, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, folder))
	zone.Transparency = 1
	CollectionService:AddTag(zone, "BallPit")
	return zone
end

-- A neon billboard on two legs over `pos` (a roof), facing `toward`.
-- MapFeatureService makes it flicker, then surge and knock back cats near
-- it.
function ArenaKit.AddBillboard(pos: Vector3, toward: Vector3, color: Color3, text: string, parent: Instance): BasePart
	local folder = Instance.new("Folder")
	folder.Name = "Billboard"
	folder.Parent = parent
	local face = CFrame.lookAt(pos, Vector3.new(toward.X, pos.Y, toward.Z))
	local metal = Color3.fromRGB(46, 50, 60)
	for _, s in ipairs({ -1, 1 }) do
		swimDeco(ArenaKit.NewPart("PostBillboard", Vector3.new(0.6, 9, 0.6), face * CFrame.new(s * 4.5, 4.5, 0.6), metal, Enum.Material.Metal, folder))
	end
	swimDeco(ArenaKit.NewPart("BillboardFrame", Vector3.new(12, 5.4, 0.5), face * CFrame.new(0, 7, 0.35), metal, Enum.Material.Metal, folder))
	local panel = swimDeco(ArenaKit.NewPart("Billboard", Vector3.new(11.4, 4.8, 0.3), face * CFrame.new(0, 7, 0), color, Enum.Material.Neon, folder))
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.LightInfluence = 0
	gui.PixelsPerStud = 30
	gui.Parent = panel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.4
	label.Parent = gui
	panel:SetAttribute("BlastAt", pos + Vector3.new(0, 1, 0))
	for _, s in ipairs({ { "Buzz", "rbxasset://sounds/action_falling.mp3", 0.5, 2.2 }, { "Zap", "rbxasset://sounds/impact_explosion_03.mp3", 0.6, 1.6 } }) do
		local snd = Instance.new("Sound")
		snd.Name = s[1]
		snd.SoundId = s[2]
		snd.Volume = s[3]
		snd.PlaybackSpeed = s[4]
		snd.RollOffMaxDistance = 90
		snd.Parent = panel
	end
	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	sparks.Size = NumberSequence.new(0.8, 0)
	sparks.Speed = NumberRange.new(20, 40)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Lifetime = NumberRange.new(0.4, 0.8)
	sparks.LightEmission = 1
	sparks.Rate = 0
	sparks.Parent = panel
	local flash = Instance.new("PointLight")
	flash.Color = color
	flash.Range = 30
	flash.Brightness = 0
	flash.Parent = panel
	CollectionService:AddTag(panel, "Billboard")
	return panel
end

return ArenaKit
