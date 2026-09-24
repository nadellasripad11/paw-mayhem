--!strict
-- MapPreviews: at server start every map is built once and a lightweight copy
-- (its biggest visible parts, no scripts / effects / tags) is saved to
-- ReplicatedStorage.MapPreviews, so the map picker can show the REAL map in
-- 3D instead of a drawing. Runs before any service starts, so the throwaway
-- builds never trigger gameplay (drops, jump pads, lava).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local ArenaBuilder = require(script.Parent.ArenaBuilder)

local MapPreviews = {}

local MAP_IDS = { "SkyIslands", "Volcano", "Toybox" }
local MAX_PARTS = 2600
-- Scenery that would swamp the preview (sky clutter, the endless lava sea).
local SKIP_NAMES = { Cloud = true, CloudHigh = true, LavaSea = true, ArenaSky = true }

local function skipped(p: BasePart): boolean
	if SKIP_NAMES[p.Name] or string.sub(p.Name, 1, 4) == "Puff" or p.Size.Magnitude > 220 then
		return true
	end
	local parent = p.Parent
	while parent do
		if parent.Name == "Clouds" then
			return true
		end
		parent = parent.Parent
	end
	return false
end

local function snapshot(arena: Instance, id: string): Model
	-- The play area: every island floor players can stand on.
	local minV, maxV = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, f in ipairs(CollectionService:GetTagged("DropZone")) do
		if f:IsA("BasePart") and f:IsDescendantOf(arena) then
			local half = f.Size / 2
			minV = minV:Min(f.Position - half)
			maxV = maxV:Max(f.Position + half)
		end
	end
	local hasFocus = minV.X < math.huge
	local pad = Vector3.new(30, 60, 30)
	local parts = {}
	for _, d in ipairs(arena:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 and not skipped(d) then
			local p = d.Position
			local inside = not hasFocus or (p.X > minV.X - pad.X and p.X < maxV.X + pad.X and p.Z > minV.Z - pad.Z and p.Z < maxV.Z + pad.Z and p.Y > minV.Y - pad.Y and p.Y < maxV.Y + pad.Y)
			if inside then
				table.insert(parts, d)
			end
		end
	end
	-- Keep the biggest pieces: they carry the map's silhouette.
	table.sort(parts, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)

	local model = Instance.new("Model")
	model.Name = id
	if hasFocus then
		model:SetAttribute("FocusCenter", (minV + maxV) / 2)
		model:SetAttribute("FocusSize", maxV - minV)
	end
	for i = 1, math.min(#parts, MAX_PARTS) do
		local src = parts[i]
		local ok, copy = pcall(function()
			return src:Clone()
		end)
		if ok and copy then
			for _, child in ipairs(copy:GetChildren()) do
				if not child:IsA("DataModelMesh") then
					child:Destroy()
				end
			end
			for _, t in ipairs(CollectionService:GetTags(copy)) do
				CollectionService:RemoveTag(copy, t)
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.CastShadow = false
			copy.Parent = model
		end
	end
	return model
end

function MapPreviews.Build()
	local folder = Instance.new("Folder")
	folder.Name = "MapPreviews"
	for _, id in ipairs(MAP_IDS) do
		local ok, err = pcall(function()
			local arena = ArenaBuilder.BuildMap(id)
			snapshot(arena, id).Parent = folder
		end)
		if not ok then
			warn("[PAW MAYHEM] Map preview failed for " .. id .. ": " .. tostring(err))
		end
	end
	folder.Parent = ReplicatedStorage
end

return MapPreviews
