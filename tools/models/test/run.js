// Runs tools/models/setup_game.lua and MeshLib against a mock Roblox (Luau CLI):
//   node tools/models/test/run.js
// The importer might turn the scene round either by turning each part
// (geometry untouched) or by baking the turn into the mesh data (parts not
// turned). Both, plus no turn at all: after setup, every model placed by
// MeshLib must show exactly as it was modelled, at the right spot and size.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..', '..', '..');
const LUAU = path.join(ROOT, 'tools', 'bin', 'luau', 'luau.exe');
const mock = fs.readFileSync(path.join(ROOT, 'tools', 'lobby', 'test', 'mock_roblox.lua'), 'utf8');
const setup = fs.readFileSync(path.join(ROOT, 'tools', 'models', 'setup_game.lua'), 'utf8');
const meshLib = fs.readFileSync(path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'MeshLib.lua'), 'utf8').replace('--!strict', '');
const data = fs.readFileSync(path.join(ROOT, 'src', 'ReplicatedStorage', 'Shared', 'GameMeshData.lua'), 'utf8').replace('--!strict', '');

const src = `
local M = (function()\n${mock}\nend)()
local Vector3, CFrame, Color3, Enum, Instance, game, workspace, typeof = M.Vector3, M.CFrame, M.Color3, M.Enum, M.Instance, M.game, M.workspace, M.typeof
local warn = function(...) print("WARN", ...) end
local failures, checks = 0, 0
local function check(ok, msg) checks += 1 if not ok then failures += 1 print("FAIL: " .. msg) end end
local GameMeshData = (function()\n${data}\nend)()
local RS = game:GetService("ReplicatedStorage")
-- a fake Shared folder so MeshLib's require of GameMeshData works
local function loadMeshLib()
	local script = { Parent = { GameMeshData = "GameMeshData" } }
	local require = function() return GameMeshData end
	return (function()\n${meshLib}\nend)()
end
local function runSetup()\n${setup}\nend
local R180 = CFrame.Angles(0, math.pi, 0)
local function close(a, b) return (a - b).Magnitude < 1e-3 end
for _, case in ipairs({ "none", "partTurn", "baked" }) do
	print("-- import: " .. case)
	for _, c in ipairs(RS:GetChildren()) do c:Destroy() end
	local R = case == "none" and CFrame.identity or R180
	local model = Instance.new("Model")
	model.Name = "GameMeshes"
	local origin = CFrame.new(40, 10, -30)
	model.WorldPivot = origin
	for name, info in pairs(GameMeshData.Meshes) do
		local p = Instance.new("MeshPart")
		p.Name = name .. "_Node"
		local node = Instance.new("Model")
		node.Name = name .. "_Node"
		p.Name = name
		-- where the importer puts it: the whole scene turned by R round origin
		local pos = origin * (R * info.Center)
		if case == "partTurn" then
			p.CFrame = CFrame.new(pos) * R -- geometry as modelled, the part turned
			p:SetAttribute("_geom", CFrame.identity)
		else
			p.CFrame = CFrame.new(pos) -- geometry itself turned (or not at all)
			p:SetAttribute("_geom", R)
		end
		-- the part's box, in its own axes
		local s = (p.CFrame.Rotation * p:GetAttribute("_geom")):Inverse():VectorToWorldSpace(R:VectorToWorldSpace(info.Size))
		p.Size = Vector3.new(math.abs(s.X), math.abs(s.Y), math.abs(s.Z))
		p.Parent = node
		node.Parent = model
	end
	model.Parent = workspace
	runSetup()
	local meshes = RS.GameMeshes.Meshes
	local n = 0
	for _ in pairs(GameMeshData.Meshes) do n += 1 end
	check(#meshes:GetChildren() == n, "all " .. n .. " meshes moved in")
	check(model.Parent == nil, "import leftovers removed")
	local MeshLib = loadMeshLib()
	local out = Instance.new("Folder")
	local base = CFrame.new(5, 6, 7) * CFrame.Angles(0, 0.7, 0)
	for name, info in pairs(GameMeshData.Meshes) do
		local m = MeshLib.Place(name, base, 1.5, nil, nil, out)
		check(m ~= nil, "placed " .. name)
		if m then
			-- what you see: the part's turn times the turn baked into its mesh
			local shown = m.CFrame.Rotation * m:GetAttribute("_geom")
			check(close(shown.XVector, base.XVector) and close(shown.YVector, base.YVector), name .. " faces the way it was modelled (" .. case .. ")")
			check(close(m.CFrame.Position, base * (info.Center * 1.5)), name .. " in the right place")
			local seen = shown:VectorToObjectSpace(m.CFrame:VectorToWorldSpace(m.Size))
			local want = info.Size * 1.5
			check(math.abs(math.abs(seen.X) - want.X) < 1e-3 and math.abs(math.abs(seen.Y) - want.Y) < 1e-3 and math.abs(math.abs(seen.Z) - want.Z) < 1e-3, name .. " the right size")
		end
	end
	-- Fill: a unit mesh stretched over a box
	local f = MeshLib.Fill("U_Cliff1", CFrame.new(1, 2, 3), Vector3.new(4, 9, 3), nil, nil, out)
	local shown = f.CFrame.Rotation * f:GetAttribute("_geom")
	local seen = shown:VectorToObjectSpace(f.CFrame:VectorToWorldSpace(f.Size))
	check(math.abs(math.abs(seen.X) - 4) < 1e-3 and math.abs(math.abs(seen.Y) - 9) < 1e-3 and math.abs(math.abs(seen.Z) - 3) < 1e-3, "Fill stretches to the box (" .. case .. ")")
end
print(("%d checks"):format(checks))
print(failures == 0 and "GAME MESH TESTS PASSED" or ("GAME MESH TESTS FAILED: " .. failures))
`;
const f = path.join(__dirname, '_test.luau');
fs.writeFileSync(f, src);
let failed = false;
try {
  const out = execFileSync(LUAU, [f], { encoding: 'utf8' });
  process.stdout.write(out.split('\n').filter((l) => !/^====|^Models found|^Import turn|^DONE/.test(l)).join('\n'));
  failed = /FAILED|FAIL:/.test(out);
} catch (e) {
  process.stdout.write((e.stdout || '') + (e.stderr || ''));
  failed = true;
}
fs.unlinkSync(f);
process.exit(failed ? 1 : 0);
