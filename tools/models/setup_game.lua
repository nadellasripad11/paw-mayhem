if game:GetService("RunService"):IsRunning() then
	error("Stop the game first (this runs in Edit mode, not while playing)")
end
local RS = game:GetService("ReplicatedStorage")
local NAMES = { "TreeTrunk", "TreeCanopyA", "TreeCanopyB", "PineFoliage", "PineSnow", "PineTrunk", "BushA", "RockA", "RockB", "RockC", "U_Cliff1", "U_Cliff2", "U_Cliff3", "U_Hang1", "U_Hang2", "U_RockDrum", "U_GrassLip", "CrateBody", "CrateFrame", "LampStone", "LampIron", "Balloon", "LollipopDisc", "LollipopStripe", "CrayonBody", "CrayonTip", "CrayonBands", "CandyCaneWhite", "CandyCaneRed", "DuckBody", "DuckBeak", "U_SoftBlock", "U_Dice", "ACBody", "ACFan", "TankWood", "TankMetal", "TankRoof", "Probe_O", "Probe_X", "Probe_Y", "Gun_PawBlaster_1", "Gun_PawBlaster_2", "Gun_PawBlaster_3", "Gun_PawBlaster_4", "Gun_Starfall_1", "Gun_Starfall_2", "Gun_Starfall_3", "Gun_Starfall_4", "Gun_BoomPaw_1", "Gun_BoomPaw_2", "Gun_BoomPaw_3", "Gun_BoomPaw_4", "Gun_RapidPaw_1", "Gun_RapidPaw_2", "Gun_RapidPaw_3", "Gun_RapidPaw_4", "Gun_FrostBlaster_1", "Gun_FrostBlaster_2", "Gun_FrostBlaster_3", "Gun_FrostBlaster_4", "Gun_FrostBlaster_5", "Gun_VoidCannon_1", "Gun_VoidCannon_2", "Gun_VoidCannon_3", "Gun_VoidCannon_4", "Gun_BubbleBlaster_1", "Gun_BubbleBlaster_2", "Gun_BubbleBlaster_3", "Gun_BubbleBlaster_4", "Gun_BubbleBlaster_5", "Gun_GoldenPurr_1", "Gun_GoldenPurr_2", "Gun_GoldenPurr_3", "Gun_GoldenPurr_4", "Gun_CometClaw_1", "Gun_CometClaw_2", "Gun_CometClaw_3", "Gun_CometClaw_4", "Gun_PurrfectStorm_1", "Gun_PurrfectStorm_2", "Gun_PurrfectStorm_3", "Gun_PurrfectStorm_4" }
local lib = RS:FindFirstChild("GameMeshes")
if not lib then
	lib = Instance.new("Folder")
	lib.Name = "GameMeshes"
	lib.Parent = RS
end
local meshes = lib:FindFirstChild("Meshes") or Instance.new("Folder")
meshes.Name = "Meshes"
meshes.Parent = lib
local function matches(inst, name)
	return inst:IsA("MeshPart") and (inst.Name == name or string.sub(inst.Name, 1, #name + 1) == name .. "_" or string.sub(inst.Name, 1, #name + 1) == name .. ".")
end
local pool = {}
for _, root in ipairs({ workspace, game:GetService("ServerStorage") }) do
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("MeshPart") then
			table.insert(pool, d)
		end
	end
end
local function find(name)
	local loose = nil
	for _, d in ipairs(pool) do
		if d.Parent and not d:IsDescendantOf(meshes) and matches(d, name) then
			if d.Name == name then
				return d
			end
			loose = loose or d
		end
	end
	return loose or meshes:FindFirstChild(name)
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
local found, missing, leftovers, moved = 0, {}, {}, {}
local po, px, py = find("Probe_O"), find("Probe_X"), find("Probe_Y")
local sceneTurn = CFrame.identity
if po and px and py and not po:IsDescendantOf(meshes) then
	sceneTurn = snap(CFrame.fromMatrix(Vector3.zero, (px.Position - po.Position).Unit, (py.Position - po.Position).Unit))
end
for _, name in ipairs(NAMES) do
	local p = find(name)
	if p then
		if not p:IsDescendantOf(meshes) then
			p:SetAttribute("ImportTurn", sceneTurn:Inverse() * snap(p.CFrame))
			local top = p:FindFirstAncestorOfClass("Model")
			while top and top.Parent and top.Parent ~= workspace and top.Parent:IsA("Model") do
				top = top.Parent
			end
			if top and top:IsDescendantOf(workspace) then
				leftovers[top] = true
			end
			table.insert(moved, { p, name })
		end
		found += 1
	else
		table.insert(missing, name)
	end
end
for _, m in ipairs(moved) do
	local p, name = m[1], m[2]
	local old = meshes:FindFirstChild(name)
	if old and old ~= p then
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
print("==== PAW MAYHEM game models setup ====")
print(("Models found: %d / %d"):format(found, #NAMES))
print(("Import turn: %s"):format(sceneTurn == CFrame.identity and "none" or tostring(sceneTurn.LookVector)))
if #missing > 0 then
	warn("MISSING: " .. table.concat(missing, ", ") .. "  -> wait for Import 3D of assets/GameMeshes.glb to finish, then run this again")
else
	print("DONE - save, then press Play.")
end
