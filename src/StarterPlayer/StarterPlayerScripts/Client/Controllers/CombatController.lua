--!strict
-- combatcontroller: turns fire input (mouse / touch button / gamepad r2) into
-- rate-limited fireweapon requests. each pellet is traced here first, so your
-- own shot (flash, bolt, sound) shows instantly and the server hears which cat
-- you actually hit on your screen; the server validates that claim and stays
-- the authority on damage. ammo is unlimited.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Weapons = require(Shared.Config.Weapons)
local Progression = require(Shared.Config.Progression)

local CameraController = require(script.Parent.CameraController)
local MovementController = require(script.Parent.MovementController)
local EffectsController = require(script.Parent.EffectsController)
local SoundController = require(script.Parent.SoundController)
local ClientState = require(script.Parent.Parent.ClientState)

local CombatController = {}

local player = Players.LocalPlayer
local firing = false
local lastShot = 0
local enabled = false
local powerUp = { id = "", untilT = 0 } -- mirrors the server's active power-up for fire rate

-- fires whenever a local shot goes out, so the hud can kick the crosshair.
CombatController.OnLocalShot = nil :: ((weaponId: string) -> ())?

function CombatController.IsFiring(): boolean
	return firing and enabled
end

-- the cat (player or bot) an instance belongs to, if any.
local function catModel(inst: Instance?): Model?
	local m = inst and inst:FindFirstAncestorOfClass("Model")
	while m and not m:FindFirstChildOfClass("Humanoid") do
		m = m:FindFirstAncestorOfClass("Model")
	end
	return m
end

-- true for a living cat on the other team (anyone in free for all).
function CombatController.IsEnemy(model: Model): boolean
	local char = player.Character
	if model == char then
		return false
	end
	local hum = model:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return false
	end
	-- (ffa is the match mode; duels and the lobby always go by team.)
	if ClientState.Match and ClientState.Match.mode == "FFA" and player:GetAttribute("Context") == "Match" then
		return true
	end
	local mine = char and char:GetAttribute("Team")
	return mine == nil or model:GetAttribute("Team") ~= mine
end

local function withSpread(dir: Vector3, spreadDeg: number): Vector3
	if spreadDeg <= 0 then
		return dir.Unit
	end
	local spread = math.rad(spreadDeg)
	local up = math.abs(dir.Unit.Y) > 0.99 and Vector3.xAxis or Vector3.yAxis
	local right = dir.Unit:Cross(up).Unit
	local realUp = right:Cross(dir.Unit).Unit
	local a = (math.random() - 0.5) * 2 * spread
	local b = (math.random() - 0.5) * 2 * spread
	return (dir.Unit + right * math.tan(a) + realUp * math.tan(b)).Unit
end

local function currentWeapon()
	-- a supply-drop blaster (set by the server on the character) wins.
	local override = player.Character and player.Character:GetAttribute("WeaponOverride")
	if typeof(override) == "string" and Weapons.Get(override) then
		return Weapons.Get(override)
	end
	-- then the blaster this life spawned with (a loadout change can wait for
	-- the next respawn), then the saved loadout.
	local life = player.Character and player.Character:GetAttribute("Weapon")
	if typeof(life) == "string" and Weapons.Get(life) then
		return Weapons.Get(life)
	end
	local profile = ClientState.Profile
	local id = profile and profile.Loadout.Weapon or Weapons.DefaultLoadout
	return Weapons.Get(id) or Weapons.Get(Weapons.DefaultLoadout)
end

local function muzzlePosition(): Vector3
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return Vector3.new()
	end
	-- (not the blaster's own barrel: it moves with the cat's animations -
	-- recoil, leaning, bobbing - which threw every shot off the crosshair.)
	-- the custom camera can look independently from the humanoid's current
	-- facing direction. place the visual muzzle on the camera's horizontal aim
	-- so the local flash, server origin validation, and crosshair all agree.
	local _, aim = CameraController.GetAimRay()
	local flatAim = Vector3.new(aim.X, 0, aim.Z)
	local facing = flatAim.Magnitude > 0.01 and flatAim.Unit or root.CFrame.LookVector
	return root.Position + facing * 1.5 + Vector3.new(0, 0.8, 0)
end

local function tryFire()
	if not enabled then
		return
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return
	end
	local weapon = currentWeapon()
	if not weapon then
		return
	end
	local rateMult, extraPellets, spreadAdd = 1, 0, 0
	if os.clock() < powerUp.untilT then
		local p = Progression.PowerUpById[powerUp.id]
		rateMult = p and p.FireRateMult or 1
		extraPellets = p and p.ExtraPellets or 0
		spreadAdd = p and p.SpreadAdd or 0
	end
	local interval = 1 / (weapon.FireRate * rateMult)
	local now = os.clock()
	if now - lastShot < interval then
		return
	end
	-- single-shot blasters go exactly where the crosshair is, every shot, no
	-- matter how long you hold the trigger (spray weapons with several pellets
	-- still spread).
	lastShot = now
	local spreadScale = (weapon.Pellets + extraPellets) > 1 and 1 or 0

	local muzzle = muzzlePosition()
	local dir = CameraController.GetShootDirection(muzzle)

	-- trace every pellet now: draw it straight away and tell the server which
	-- enemy it hit on this screen (it checks the claim against its own view).
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char :: Model }
	params.IgnoreWater = true
	local pellets, tos = {}, {}
	for _ = 1, weapon.Pellets + extraPellets do
		local d = withSpread(dir, (weapon.Spread + spreadAdd) * spreadScale)
		local result = Workspace:Raycast(muzzle, d * weapon.Range, params)
		if result and result.Instance.Name == "RangeTarget" then
			require(script.Parent.MapLife).HitTarget(result.Instance)
		end
		local hitModel = result and catModel(result.Instance)
		table.insert(pellets, { dir = d, hit = (hitModel and CombatController.IsEnemy(hitModel)) and hitModel or nil })
		table.insert(tos, result and result.Position or muzzle + d * weapon.Range)
	end
	Remotes.Get("FireWeapon"):FireServer({
		origin = muzzle,
		direction = dir,
		pellets = pellets,
	})

	-- local muzzle flash, bolts and sound (no waiting on the server)
	CombatController.MuzzleFlash(muzzle, weapon)
	EffectsController.Tracers(muzzle, tos, weapon.TrailColor, weapon.Id)
	SoundController.PlayShot(weapon.Id, muzzle)
	-- recoil: heavier-hitting blasters shove you back and kick the view more
	-- (and the arms, catanimator).
	MovementController.Recoil(dir, math.max(0, weapon.Knockback - 0.8) * 10)
	require(script.Parent.CatAnimator).Trigger(game:GetService("Players").LocalPlayer.Character, "Recoil", math.clamp(0.7 + weapon.Knockback * 0.4, 0.8, 1.8))
	CameraController.OnShot(0.25 + weapon.Knockback * 0.45)
	if CombatController.OnLocalShot then
		CombatController.OnLocalShot(weapon.Id)
	end
end

function CombatController.MuzzleFlash(pos: Vector3, weapon)
	local flash = Instance.new("Part")
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.new(0.8, 0.8, 0.8)
	flash.Position = pos
	flash.Color = weapon.MuzzleColor
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.Transparency = 0.35
	flash.Parent = workspace
	task.spawn(function()
		for i = 1, 4 do
			flash.Size = flash.Size + Vector3.new(0.15, 0.15, 0.15)
			flash.Transparency = 0.35 + i * 0.16
			task.wait()
		end
		flash:Destroy()
	end)
end

-- touch auto-fire: the crosshair (camera ray) rests on an enemy in range.
local function autoFireTarget(): boolean
	if not ClientState.Settings.AutoFire or UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch then
		return false
	end
	local char = player.Character
	local weapon = currentWeapon()
	if not char or not weapon then
		return false
	end
	local origin, dir = CameraController.GetAimRay()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local hit = Workspace:Raycast(origin, dir * (weapon.Range + 15), params)
	local m = hit and catModel(hit.Instance)
	return m ~= nil and CombatController.IsEnemy(m)
end

function CombatController.SetFiring(on: boolean)
	firing = on
end

function CombatController.SetEnabled(on: boolean)
	enabled = on
	if not on then
		firing = false
	end
end

function CombatController.Start()
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = true
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			firing = true
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			firing = false
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			firing = false
		end
	end)

	Remotes.Get("PowerUpActive").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and typeof(data.powerId) == "string" then
			powerUp.id = data.powerId
			powerUp.untilT = os.clock() + (tonumber(data.duration) or 10)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if firing or (enabled and autoFireTarget()) then
			tryFire()
		end
	end)
end

return CombatController
