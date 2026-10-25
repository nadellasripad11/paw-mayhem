-- PAW MAYHEM — run ONCE in Studio's command bar (View > Command Bar) after
-- importing assets/LobbyMeshes.glb into ReplicatedStorage.LobbyMeshes.
-- Makes the lobby's PBR materials (MaterialVariants) from the textures the
-- importer uploaded onto the swatch cubes, and stores them in
-- ReplicatedStorage.LobbyMeshes.Materials (LobbyService installs them when the
-- game starts). Only the command bar may set these properties; scripts can't.
local lib = game:GetService("ReplicatedStorage"):FindFirstChild("LobbyMeshes")
assert(lib, "Import assets/LobbyMeshes.glb into ReplicatedStorage.LobbyMeshes first")
local MAP = {
	PawStone = { Enum.Material.Slate, 12 },
	PawGrain = { Enum.Material.Slate, 8 },
	PawPlaster = { Enum.Material.Plaster, 16 },
	PawMetal = { Enum.Material.Metal, 6 },
	PawMarble = { Enum.Material.Marble, 16 },
	PawFabric = { Enum.Material.Fabric, 4 },
}
local folder = lib:FindFirstChild("Materials") or Instance.new("Folder")
folder.Name = "Materials"
folder.Parent = lib
local made = 0
for name, def in pairs(MAP) do
	local swatch = lib:FindFirstChild("Swatch_" .. name, true)
	local sa = swatch and swatch:FindFirstChildOfClass("SurfaceAppearance")
	if sa then
		local mv = folder:FindFirstChild(name) or Instance.new("MaterialVariant")
		mv.Name = name
		mv.BaseMaterial = def[1]
		mv.StudsPerTile = def[2]
		mv.ColorMap = sa.ColorMap
		mv.NormalMap = sa.NormalMap
		mv.RoughnessMap = sa.RoughnessMap
		mv.MetalnessMap = sa.MetalnessMap
		mv.Parent = folder
		made += 1
	else
		warn("no textures on Swatch_" .. name)
	end
end
print(("Lobby materials: %d of 6 made. Now right-click ReplicatedStorage.LobbyMeshes > Save to File > assets/LobbyMeshes/Lobby.rbxm"):format(made))
