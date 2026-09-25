--!strict
-- PracticeService: a floating practice island away from the arena, open
-- between matches. PRACTICE in the menu drops you there with your loadout;
-- three target cats stand on pads - blast them and watch their knockback %
-- climb until they fly off the edge (they reset themselves). Fall off and
-- you're put back. When a match starts, everyone practising is pulled out.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local CatBuilder = require(Shared.Character.CatBuilder)
local Knockback = require(Shared.Character.Knockback)

local PlayerService = require(script.Parent.PlayerService)
local WeaponService = require(script.Parent.WeaponService)
local ArenaKit = require(script.Parent.Parent.World.ArenaKit)

local PracticeService = {}

local CENTER = Vector3.new(0, 120, 2600)
local RADIUS = 36
local SURFACE_Y = CENTER.Y + ArenaKit.SURFACE
local FALL_Y = CENTER.Y - 45
local PALETTE: ArenaKit.Palette = {
	Top = Color3.fromRGB(122, 200, 108), TopDark = Color3.fromRGB(96, 170, 86),
	Stone = Color3.fromRGB(150, 144, 136), StoneDark = Color3.fromRGB(118, 112, 110),
	Wood = Color3.fromRGB(176, 124, 72), WoodDark = Color3.fromRGB(120, 82, 50),
}

type Dummy = { model: Model, root: BasePart, stand: CFrame, fluff: number }
local dummies: { Dummy } = {}

local function standAt(angle: number, dist: number): CFrame
	local p = Vector3.new(CENTER.X + math.cos(angle) * dist, SURFACE_Y + 1.9, CENTER.Z + math.sin(angle) * dist)
	return CFrame.lookAt(p, Vector3.new(CENTER.X, p.Y, CENTER.Z))
end

local function resetDummy(d: Dummy)
	d.fluff = 0
	d.model:SetAttribute("Fluff", 0)
	d.root.AssemblyLinearVelocity = Vector3.zero
	d.root.AssemblyAngularVelocity = Vector3.zero
	d.model:PivotTo(d.stand)
end

local function buildIsland()
	local folder = Instance.new("Folder")
	folder.Name = "PracticeIsland"
	-- The intro cinematic and the mentor lesson (client) stage themselves here.
	folder:SetAttribute("Center", CENTER)
	folder:SetAttribute("Surface", SURFACE_Y)
	folder.Parent = Workspace
	ArenaKit.MakeIslandBase(CENTER, RADIUS, "Island", PALETTE, Enum.Material.Grass, folder)
	-- Three target cats on glowing pads, spread round the far side.
	for k = 0, 2 do
		local angle = math.rad(60 + k * 30)
		local stand = standAt(angle, RADIUS * 0.62)
		local pad = ArenaKit.NewDisc("TargetPad", 5, 0.2, Vector3.new(stand.X, SURFACE_Y + 0.1, stand.Z), Color3.fromRGB(255, 120, 120), Enum.Material.Neon, folder)
		pad.Transparency = 0.4
		pad.CanCollide = false
		local model = CatBuilder.Build(nil, "TARGET", nil)
		model.Name = "TARGET"
		model:SetAttribute("IsDummy", true)
		model:SetAttribute("Team", "Dummy")
		model:SetAttribute("Fluff", 0)
		local hum = model:FindFirstChildOfClass("Humanoid") :: Humanoid
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.MaxHealth = 1e9
		hum.Health = 1e9
		model:PivotTo(stand)
		model.Parent = folder
		local root = model.PrimaryPart :: BasePart
		pcall(function()
			root:SetNetworkOwner(nil)
		end)
		table.insert(dummies, { model = model, root = root, stand = stand, fluff = 0 })
	end
end

-- A player's shot hit a target cat: same knockback maths as a real hit.
local function hitDummy(shooter: Player, model: Model, weapon: any, dir: Vector3)
	for _, d in ipairs(dummies) do
		if d.model == model then
			d.fluff += weapon.Damage
			model:SetAttribute("Fluff", math.floor(d.fluff))
			local dV = Knockback.ComputeDeltaV(dir, d.fluff, weapon.Knockback, 1)
			if dV.Y > 2 then
				(model:FindFirstChildOfClass("Humanoid") :: Humanoid):ChangeState(Enum.HumanoidStateType.Freefall)
			end
			d.root:ApplyImpulse(dV * d.root.AssemblyMass)
			Remotes.Get("HitConfirm"):FireClient(shooter, {
				victim = "TARGET", damage = weapon.Damage, accumulated = d.fluff, position = d.root.Position,
			})
			return
		end
	end
end

local function spawnAt(player: Player)
	PlayerService.Spawn(player)
	local char = player.Character
	if char then
		local a = math.random() * math.pi * 2
		local p = Vector3.new(CENTER.X + math.cos(a) * 6, SURFACE_Y + 3, CENTER.Z - 12 + math.sin(a) * 4)
		char:PivotTo(CFrame.lookAt(p, Vector3.new(CENTER.X, p.Y, CENTER.Z + 20)))
	end
end

function PracticeService.Leave(player: Player)
	if not player:GetAttribute("Practicing") then
		return
	end
	player:SetAttribute("Practicing", nil)
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end
end

-- A match is starting: everyone practising goes back to the lobby.
function PracticeService.EndAll()
	for _, p in ipairs(Players:GetPlayers()) do
		PracticeService.Leave(p)
	end
end

function PracticeService.Start()
	buildIsland()
	WeaponService.OnDummyHit = hitDummy

	Remotes.Get("Practice").OnServerEvent:Connect(function(player, on)
		if on == true then
			if PlayerService.MatchActive or player:GetAttribute("Practicing") then
				return
			end
			player:SetAttribute("Practicing", true)
			spawnAt(player)
		else
			PracticeService.Leave(player)
		end
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		-- Targets knocked off the island come back fresh.
		for _, d in ipairs(dummies) do
			if d.root.Position.Y < FALL_Y or (d.root.Position - CENTER).Magnitude > 400 then
				resetDummy(d)
			end
		end
		-- Players who fall off are put back on.
		for _, p in ipairs(Players:GetPlayers()) do
			local root = p:GetAttribute("Practicing") and p.Character and p.Character.PrimaryPart
			if root and root.Position.Y < FALL_Y then
				spawnAt(p)
			end
		end
	end)
end

return PracticeService
