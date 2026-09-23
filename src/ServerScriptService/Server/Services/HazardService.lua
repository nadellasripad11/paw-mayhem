--!strict
-- HazardService: damage + knockback from the environment (meteors, stampede
-- balls, burning ground) for players and bots alike. Honours spawn
-- protection and the Mayhem Mode knockback multiplier.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local GameConfig = require(Shared.Config.GameConfig)
local CatBuilder = require(Shared.Character.CatBuilder)

local Runtime = require(script.Parent.Runtime)
local WeaponService = require(script.Parent.WeaponService)
local BotService = require(script.Parent.BotService)

local HazardService = {}

-- Every live cat model (players + bots) in the world.
function HazardService.Cats(): { Model }
	local out = {}
	for _, m in ipairs(CollectionService:GetTagged(CatBuilder.Tag)) do
		if m:IsA("Model") and m.PrimaryPart and m:IsDescendantOf(Workspace) then
			table.insert(out, m)
		end
	end
	return out
end

-- `dV` is a velocity change in studs/s.
function HazardService.Hit(model: Model, damage: number, dV: Vector3)
	local mult = Runtime.Mayhem and GameConfig.Mayhem.KnockbackMult or 1
	local launch = dV * mult
	local player = Players:GetPlayerFromCharacter(model)
	if player then
		local s = Runtime.Get(player)
		if not s or not s.Alive or os.clock() < (s.SpawnProtectUntil or 0) then
			return
		end
		local hum = model:FindFirstChildOfClass("Humanoid")
		local root = model.PrimaryPart
		if not hum or not root then
			return
		end
		s.Accumulated += damage
		s.LastAttackAt = os.clock()
		hum:TakeDamage(damage * 0.5)
		if launch.Magnitude > 0 then
			WeaponService.ApplyLaunch(player, hum, root, launch * root.AssemblyMass)
		end
		Remotes.Get("YouWereHit"):FireClient(player, {
			from = "Hazard",
			direction = launch.Magnitude > 0 and launch.Unit or Vector3.yAxis,
			accumulated = s.Accumulated,
		})
	elseif model:GetAttribute("IsBot") then
		BotService.EnvironmentHit(model, damage, launch)
	end
end

-- Knock every cat within `radius` of `center` outward and up.
function HazardService.Blast(center: Vector3, radius: number, damage: number, power: number)
	for _, m in ipairs(HazardService.Cats()) do
		local root = m.PrimaryPart :: BasePart
		local off = root.Position - center
		local d = off.Magnitude
		if d <= radius then
			local flat = Vector3.new(off.X, 0, off.Z)
			local dir = flat.Magnitude > 0.1 and flat.Unit or Vector3.xAxis
			local falloff = 1 - (d / radius) * 0.5
			HazardService.Hit(m, damage * falloff, (dir * 0.75 + Vector3.new(0, 0.65, 0)).Unit * power * falloff)
		end
	end
end

return HazardService
