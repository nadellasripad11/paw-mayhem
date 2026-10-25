if game:GetService("RunService"):IsRunning() then
	error("Stop the game first (this runs in Edit mode, not while playing)")
end
local RS = game:GetService("ReplicatedStorage")
local MS = game:GetService("MaterialService")
local NAMES = { "DaisStone", "DaisGold", "ColumnStone", "ColumnGold", "PilasterStone", "PilasterGold", "ArchNavy", "ArchGold", "ArchKeystone", "ChandelierGold", "ChandelierCandles", "TrophyGold", "PlanterStone", "PlanterGold", "CrownMould", "RailMould", "Swatch_PawStone", "Swatch_PawGrain", "Swatch_PawPlaster", "Swatch_PawMetal", "Swatch_PawMarble", "Swatch_PawFabric" }
local VARIANTS = { PawStone = { Enum.Material.Slate, 12 }, PawGrain = { Enum.Material.Slate, 8 }, PawPlaster = { Enum.Material.Plaster, 16 }, PawMetal = { Enum.Material.Metal, 6 }, PawMarble = { Enum.Material.Marble, 16 }, PawFabric = { Enum.Material.Fabric, 4 } }
local lib = RS:FindFirstChild("LobbyMeshes")
if not lib then
	lib = Instance.new("Folder")
	lib.Name = "LobbyMeshes"
	lib.Parent = RS
end
local meshes = lib:FindFirstChild("Meshes") or Instance.new("Folder")
meshes.Name = "Meshes"
meshes.Parent = lib
local function matches(inst, name)
	return inst:IsA("MeshPart") and (inst.Name == name or string.sub(inst.Name, 1, #name + 1) == name .. "_" or string.sub(inst.Name, 1, #name + 1) == name .. ".")
end
local function find(name)
	for _, root in ipairs({ workspace, game:GetService("ServerStorage") }) do
		local exact, loose = nil, nil
		for _, d in ipairs(root:GetDescendants()) do
			if matches(d, name) then
				if d.Name == name then
					exact = exact or d
				else
					loose = loose or d
				end
			end
		end
		if exact or loose then
			return exact or loose
		end
	end
	return meshes:FindFirstChild(name)
end
local function snap(cf)
	local function r(v)
		return Vector3.new(math.round(v.X), math.round(v.Y), math.round(v.Z))
	end
	local x, y = r(cf.XVector), r(cf.YVector)
	if x.Magnitude ~= 1 or y.Magnitude ~= 1 or math.abs(x:Dot(y)) > 0.01 then
		return CFrame.identity
	end
	return CFrame.fromMatrix(Vector3.zero, x, y)
end
local found, textured, colourOnly, missing, leftovers = 0, 0, 0, {}, {}
for _, name in ipairs(NAMES) do
	local p = find(name)
	if p then
		if not p:IsDescendantOf(meshes) then
			local holder = p:FindFirstAncestorOfClass("Model")
			local rel = holder and holder:GetPivot():ToObjectSpace(p.CFrame) or p.CFrame
			p:SetAttribute("ImportTurn", snap(rel))
			if holder and holder:IsDescendantOf(workspace) then
				leftovers[holder] = true
			end
			local old = meshes:FindFirstChild(name)
			if old then
				old:Destroy()
			end
			p.Name = name
			p.Anchored = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			pcall(function()
				p.CollisionFidelity = Enum.CollisionFidelity.Box
			end)
			pcall(function()
				p.RenderFidelity = Enum.RenderFidelity.Precise
			end)
			p.Parent = meshes
		end
		found += 1
		if p:FindFirstChildOfClass("SurfaceAppearance") then
			textured += 1
		elseif p.TextureID ~= "" then
			colourOnly += 1
		end
	else
		table.insert(missing, name)
	end
end
for holder in pairs(leftovers) do
	local left = false
	for _, d in ipairs(holder:GetDescendants()) do
		if d:IsA("BasePart") then
			left = true
		end
	end
	if not left then
		holder:Destroy()
	end
end
local function copyMap(dst, sa, map)
	local ok, id = pcall(function()
		return sa[map]
	end)
	if ok and type(id) == "string" and id ~= "" then
		dst[map] = id
		return true
	end
	return (pcall(function()
		local c = sa[map .. "Content"]
		assert(c and c.SourceType ~= Enum.ContentSourceType.None)
		dst[map .. "Content"] = c
	end))
end
local store = lib:FindFirstChild("Materials") or Instance.new("Folder")
store.Name = "Materials"
store.Parent = lib
local made = 0
for name, def in pairs(VARIANTS) do
	local sw = meshes:FindFirstChild("Swatch_" .. name)
	if sw then
		local sa = sw:FindFirstChildOfClass("SurfaceAppearance")
		local mv = Instance.new("MaterialVariant")
		mv.Name = name
		mv.BaseMaterial = def[1]
		mv.StudsPerTile = def[2]
		local ok = false
		if sa then
			ok = copyMap(mv, sa, "ColorMap")
			copyMap(mv, sa, "NormalMap")
			copyMap(mv, sa, "RoughnessMap")
			copyMap(mv, sa, "MetalnessMap")
		elseif sw.TextureID ~= "" then
			mv.ColorMap = sw.TextureID
			ok = true
		end
		if ok then
			for _, parent in ipairs({ MS, store }) do
				local old = parent:FindFirstChild(name)
				if old then
					old:Destroy()
				end
				mv:Clone().Parent = parent
			end
			made += 1
		end
		mv:Destroy()
	end
end
pcall(function()
	game:GetService("Lighting").Technology = Enum.Technology.Future
end)
print("==== PAW MAYHEM lobby setup ====")
print(("Models found: %d / %d"):format(found, #NAMES))
print(("With full PBR textures: %d   colour texture only: %d   no texture (uses built-in materials): %d"):format(textured, colourOnly, found - textured - colourOnly))
print(("Lobby materials made: %d / 6"):format(made))
print("Lighting.Technology: " .. game:GetService("Lighting").Technology.Name)
if #missing > 0 then
	warn("MISSING: " .. table.concat(missing, ", ") .. "  -> import assets/LobbyMeshes.glb (Home > Import 3D) and run this again")
elseif made < 6 then
	print("Models are in. The importer brought no textures for the materials, so floors and walls keep Roblox's built-in ones. That still works.")
	print("DONE - press Play.")
else
	print("DONE - press Play.")
end
