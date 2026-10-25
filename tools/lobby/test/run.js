// Runs the lobby's Studio scripts against a mock Roblox (Luau CLI):
//   node tools/lobby/test/run.js
// 1. setup_lobby.lua on a simulated import (with textures, turned 180°, odd
//    names), again (re-run), and on an import with no textures;
// 2. LobbyService's model placement (spawnPiece / placeGroup) with the real
//    LobbyMeshData, checking every piece lands where the generator put it.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..', '..', '..');
const LUAU = path.join(ROOT, 'tools', 'bin', 'luau', 'luau.exe');
const mock = fs.readFileSync(path.join(__dirname, 'mock_roblox.lua'), 'utf8');
const setup = fs.readFileSync(path.join(ROOT, 'tools', 'lobby', 'setup_lobby.lua'), 'utf8');
const lobby = fs.readFileSync(path.join(ROOT, 'src', 'ServerScriptService', 'Server', 'Services', 'LobbyService.lua'), 'utf8').replace(/\r\n/g, '\n');
const meshData = fs.readFileSync(path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'LobbyMeshData.lua'), 'utf8').replace('--!strict', '');

const prelude = `
local M = (function()\n${mock}\nend)()
local Vector3, CFrame, Color3, Enum, Instance, game, workspace, typeof = M.Vector3, M.CFrame, M.Color3, M.Enum, M.Instance, M.game, M.workspace, M.typeof
local warn = function(...) print("WARN", ...) end
local failures = 0
local function check(ok, msg) if not ok then failures += 1 print("FAIL: " .. msg) end end
local NAMES = { "DaisStone", "DaisGold", "ColumnStone", "ColumnGold", "PilasterStone", "PilasterGold", "ArchNavy", "ArchGold", "ArchKeystone", "ChandelierGold", "ChandelierCandles", "TrophyGold", "PlanterStone", "PlanterGold", "CrownMould", "RailMould", "Swatch_PawStone", "Swatch_PawGrain", "Swatch_PawPlaster", "Swatch_PawMetal", "Swatch_PawMarble", "Swatch_PawFabric" }
local function fakeImport(textures, turned)
	local model = Instance.new("Model")
	model.Name = "LobbyMeshes"
	model.WorldPivot = CFrame.new(5, 0, 5)
	for i, n in ipairs(NAMES) do
		local p = Instance.new("MeshPart")
		-- the importer sometimes adds suffixes
		p.Name = (i % 5 == 0) and (n .. "_" .. i) or n
		local turn = turned and CFrame.Angles(0, math.pi, 0) or CFrame.identity
		p.CFrame = model.WorldPivot * CFrame.new(1, 2, 3) * turn
		if textures then
			local sa = Instance.new("SurfaceAppearance")
			sa.ColorMap = "rbxassetid://" .. (1000 + i)
			sa.NormalMap = "rbxassetid://" .. (2000 + i)
			sa.RoughnessMap = "rbxassetid://" .. (3000 + i)
			sa.MetalnessMap = "rbxassetid://" .. (4000 + i)
			sa.Parent = p
		end
		p.Parent = model
	end
	model.Parent = workspace
	return model
end
local function runSetup()\n${setup}\nend
`;

const setupTest = prelude + `
local RS = game:GetService("ReplicatedStorage")
local MS = game:GetService("MaterialService")
print("-- import with textures, turned 180")
local imported = fakeImport(true, true)
runSetup()
local meshes = RS.LobbyMeshes.Meshes
for _, n in ipairs(NAMES) do
	local p = meshes:FindFirstChild(n)
	check(p ~= nil, "mesh moved and renamed: " .. n)
	if p then
		local t = p:GetAttribute("ImportTurn")
		check(typeof(t) == "CFrame" and math.abs(t.XVector.X + 1) < 1e-6, "ImportTurn is the 180 turn for " .. n)
		check(p.Anchored and not p.CanCollide and p.CollisionFidelity == Enum.CollisionFidelity.Box, "flags on " .. n)
	end
end
check(imported.Parent == nil, "empty import model removed from Workspace")
for _, v in ipairs({ "PawStone", "PawGrain", "PawPlaster", "PawMetal", "PawMarble", "PawFabric" }) do
	local mv = MS:FindFirstChild(v)
	check(mv ~= nil and mv.ColorMap ~= "" and mv.NormalMap ~= "" and mv.RoughnessMap ~= "" and mv.MetalnessMap ~= "", "variant with all maps: " .. v)
	check(RS.LobbyMeshes.Materials:FindFirstChild(v) ~= nil, "variant stored in library: " .. v)
end
check(MS.PawStone.BaseMaterial == Enum.Material.Slate and MS.PawStone.StudsPerTile == 12, "PawStone settings")
check(game:GetService("Lighting").Technology == Enum.Technology.Future, "Future lighting")
print("-- run again (nothing new imported)")
runSetup()
check(#RS.LobbyMeshes.Meshes:GetChildren() == #NAMES, "re-run keeps exactly one of each mesh")
local count = 0
for _, c in ipairs(MS:GetChildren()) do if c.ClassName == "MaterialVariant" then count += 1 end end
check(count == 6, "re-run keeps exactly 6 variants (got " .. count .. ")")
print("-- re-import without textures replaces the meshes")
fakeImport(false, false)
runSetup()
check(#RS.LobbyMeshes.Meshes:GetChildren() == #NAMES, "re-import keeps one of each mesh")
check(RS.LobbyMeshes.Meshes.ColumnStone:FindFirstChildOfClass("SurfaceAppearance") == nil, "re-import took the new mesh")
local t = RS.LobbyMeshes.Meshes.ColumnStone:GetAttribute("ImportTurn")
check(math.abs(t.XVector.X - 1) < 1e-6, "unturned import has identity ImportTurn")
print(failures == 0 and "SETUP TESTS PASSED" or ("SETUP TESTS FAILED: " .. failures))
`;

// Pull LobbyService's placement code out verbatim.
const start = lobby.indexOf('local FALLBACK');
const end = lobby.indexOf('-- A part the model replaces');
if (start < 0 || end < 0) throw new Error('placement code not found in LobbyService');
const placement = lobby.slice(start, end);

const placeTest = prelude + `
local BEAM, STONE, NAVY = Color3.fromRGB(168, 126, 54), Color3.fromRGB(184, 174, 156), Color3.fromRGB(20, 25, 46)
local LobbyMeshData = (function()\n${meshData}\nend)()
${placement}
for _, turned in ipairs({ false, true }) do
	print("-- placing every group, import " .. (turned and "turned 180" or "unturned"))
	local lib = Instance.new("Folder")
	for group, data in pairs(LobbyMeshData) do
		for _, piece in ipairs(data.Pieces) do
			local p = Instance.new("MeshPart")
			p.Name = piece.Name
			if turned then p:SetAttribute("ImportTurn", CFrame.Angles(0, math.pi, 0)) end
			if piece.Name == "ColumnStone" then Instance.new("SurfaceAppearance").Parent = p end
			p.Parent = lib
		end
	end
	local out = Instance.new("Folder")
	local base = CFrame.new(10, 150, 2600)
	for group, data in pairs(LobbyMeshData) do
		local scale = data.Box and Vector3.new(0.75, 1, 0.75) or Vector3.one
		placeGroup(lib, group, base, scale, out)
		for _, piece in ipairs(data.Pieces) do
			local m = out:FindFirstChild(piece.Name)
			check(m ~= nil, "placed " .. piece.Name)
			if m then
				local want = base.Position + piece.Center * scale
				check((m.CFrame.Position - want).Magnitude < 1e-4, "position of " .. piece.Name)
				-- the part's box, turned back into the lobby's axes, must be the piece's size
				local s = m.CFrame:VectorToWorldSpace(m.Size)
				local w = piece.Size * scale
				check(math.abs(math.abs(s.X) - w.X) < 1e-4 and math.abs(math.abs(s.Y) - w.Y) < 1e-4 and math.abs(math.abs(s.Z) - w.Z) < 1e-4, "size of " .. piece.Name)
				check(m.Anchored and not m.CanCollide and not m.CanQuery, "flags on " .. piece.Name)
				if piece.Name == "ColumnStone" then
					check(m.Material == Enum.Material.Plastic, "textured piece keeps its own look")
				elseif piece.Mat == "Gold" then
					check(m.Material == Enum.Material.Metal and m.Color == BEAM, "untextured gold falls back to gold metal: " .. piece.Name)
				end
			end
		end
	end
end
print(failures == 0 and "PLACEMENT TESTS PASSED" or ("PLACEMENT TESTS FAILED: " .. failures))
`;

let failed = false;
for (const [name, src] of [['setup', setupTest], ['placement', placeTest]]) {
  const f = path.join(__dirname, `_${name}.luau`);
  fs.writeFileSync(f, src);
  try {
    const out = execFileSync(LUAU, [f], { encoding: 'utf8' });
    process.stdout.write(out);
    if (/FAILED|FAIL:/.test(out)) failed = true;
  } catch (e) {
    process.stdout.write((e.stdout || '') + (e.stderr || ''));
    failed = true;
  }
  fs.unlinkSync(f);
}
process.exit(failed ? 1 : 0);
