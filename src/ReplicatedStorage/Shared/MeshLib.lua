--!strict
-- meshlib: the game's sculpted models (assets/gamemeshes.glb, imported into
-- replicatedstorage.gamemeshes by tools/models/setup_game.lua). until they're
-- imported has() is false and every caller keeps building its block version.
--   place(name, origin, scale, ...)  - a model where it was modelled relative
--                                       to \`origin\` (props, gun parts)
--   fill(name, cf, size, ...)        - a model stretched to fill a box (the
--                                       u_* "unit" meshes replacing a part)
-- the importer may have turned meshes round; setup_game.lua stores that turn
-- as each mesh's importturn attribute and it's undone here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameMeshData = require(script.Parent.GameMeshData) :: any

local MeshLib = {}

local cache: { [string]: MeshPart | false } = {}

function MeshLib.Template(name: string): MeshPart?
	local hit = cache[name]
	if hit ~= nil then
		return hit or nil
	end
	local lib = ReplicatedStorage:FindFirstChild("GameMeshes")
	local found = lib and lib:FindFirstChild(name, true)
	if found and found:IsA("MeshPart") then
		cache[name] = found
		return found
	end
	-- not cached as missing while the library is still loading in
	if lib then
		cache[name] = false
	end
	return nil
end

function MeshLib.Has(name: string): boolean
	return MeshLib.Template(name) ~= nil
end

local function spawn(src: MeshPart, size: Vector3, cf: CFrame, color: Color3?, material: Enum.Material?, parent: Instance?): MeshPart
	local m = src:Clone()
	for _, c in ipairs(m:GetChildren()) do
		c:Destroy()
	end
	local turn = src:GetAttribute("ImportTurn")
	local t: CFrame = if typeof(turn) == "CFrame" then turn else CFrame.identity
	local s = t:Inverse():VectorToWorldSpace(size)
	m.Anchored = true
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.CastShadow = true
	m.Size = Vector3.new(math.max(0.01, math.abs(s.X)), math.max(0.01, math.abs(s.Y)), math.max(0.01, math.abs(s.Z)))
	m.CFrame = cf * t
	if color then
		m.Color = color
	end
	if material then
		m.Material = material
	end
	m.Parent = parent
	return m
end

function MeshLib.Place(name: string, origin: CFrame, scale: Vector3 | number, color: Color3?, material: Enum.Material?, parent: Instance?): MeshPart?
	local src = MeshLib.Template(name)
	local info = GameMeshData.Meshes[name]
	if not src or not info then
		return nil
	end
	local s: Vector3 = if typeof(scale) == "number" then Vector3.one * scale else scale :: Vector3
	return spawn(src, info.Size * s, origin * CFrame.new(info.Center * s), color, material, parent)
end

function MeshLib.Fill(name: string, cf: CFrame, size: Vector3, color: Color3?, material: Enum.Material?, parent: Instance?): MeshPart?
	local src = MeshLib.Template(name)
	if not src then
		return nil
	end
	return spawn(src, size, cf, color, material, parent)
end

-- a part a model now stands in for: it stays (invisible) only if it's solid.
function MeshLib.Hide(p: BasePart)
	if p.CanCollide then
		p.Transparency = 1
		p:SetAttribute("MeshProxy", true) -- stays solid (arenabuilder)
	else
		p:Destroy()
	end
end

return MeshLib
