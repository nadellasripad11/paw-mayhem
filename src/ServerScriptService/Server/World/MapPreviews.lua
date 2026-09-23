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
local MAX_PARTS = 900

local function snapshot(arena: Instance, id: string): Model
	local parts = {}
	for _, d in ipairs(arena:GetDescendants()) do
		if d:IsA("BasePart") and d.Transparency < 0.9 and d.Size.Magnitude > 1.5 then
			table.insert(parts, d)
		end
	end
	-- Keep the biggest pieces: they carry the map's silhouette.
	table.sort(parts, function(a, b)
		return a.Size.X * a.Size.Y * a.Size.Z > b.Size.X * b.Size.Y * b.Size.Z
	end)

	local model = Instance.new("Model")
	model.Name = id
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
