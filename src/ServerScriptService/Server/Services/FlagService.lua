--!strict
-- flagservice: capture the flag. each team's flag stands just behind its base
-- spawn. walk into the enemy flag to grab it (it rides on your back and you
-- glow in your team colour); bring it to your own flag while yours is home to
-- capture. knock a carrier off the map and the flag flies straight home;
-- drop them on an island and it lies there until a defender touches it (sends
-- it home) or 15 seconds pass.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)

local FlagService = {}

-- set by matchservice: a team captured (carrier is the capturing cat).
FlagService.OnCapture = nil :: ((team: string, carrier: Model) -> ())?

local GRAB_RADIUS = 5
local RETURN_SECONDS = 15
local FELL_Y = -30 -- a carrier below this was knocked off the map
local TEAM_COLOR = { Blue = Color3.fromRGB(64, 150, 255), Red = Color3.fromRGB(255, 82, 90) }
local TEAM_NAME = { Blue = "BLUE", Red = "RED" }

type Flag = {
	team: string,
	home: Vector3,
	model: Model,
	parts: { BasePart },
	carrier: Model?,
	weld: WeldConstraint?,
	glow: Highlight?,
	droppedAt: number?,
	lastPos: Vector3,
}

local flags: { [string]: Flag } = {}
local folder: Folder? = nil
local conn: RBXScriptConnection? = nil

-- what to call a cat in announcements (display name for players).
local function catName(m: Model): string
	local p = Players:GetPlayerFromCharacter(m)
	return p and p.DisplayName or m.Name
end

local function announce(title: string, sub: string, color: Color3)
	Remotes.Get("Announce"):FireAllClients({ title = title, sub = sub, color = color, small = true })
end

local function part(name: string, size: Vector3, color: Color3, material: Enum.Material, parent: Instance): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- pole, waving cloth and a glowing stand ring (the ring stays at home).
local function buildFlag(team: string, home: Vector3, parent: Instance): Flag
	local color = TEAM_COLOR[team]
	local model = Instance.new("Model")
	model.Name = team .. "Flag"
	local pole = part("Pole", Vector3.new(0.35, 8, 0.35), Color3.fromRGB(235, 235, 240), Enum.Material.Metal, model)
	local cloth = part("Cloth", Vector3.new(3.2, 2.1, 0.15), color, Enum.Material.Neon, model)
	local knob = part("Knob", Vector3.new(0.7, 0.7, 0.7), Color3.fromRGB(255, 214, 90), Enum.Material.Neon, model)
	knob.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 1.5
	light.Parent = cloth
	model.PrimaryPart = pole
	model.Parent = parent
	for _, p in ipairs({ cloth, knob }) do
		local w = Instance.new("WeldConstraint")
		w.Part0 = pole
		w.Part1 = p
		w.Parent = pole
	end

	local stand = part("FlagStand", Vector3.new(0.3, 9, 9), color, Enum.Material.Neon, parent)
	stand.Shape = Enum.PartType.Cylinder
	stand.Transparency = 0.45
	stand.CFrame = CFrame.new(home + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))

	local f: Flag = {
		team = team, home = home, model = model, parts = { pole, cloth, knob },
		carrier = nil, weld = nil, glow = nil, droppedAt = nil, lastPos = home,
	}
	return f
end

-- stand the flag upright at `ground` (anchored).
local function plant(f: Flag, ground: Vector3)
	local pole, cloth, knob = f.parts[1], f.parts[2], f.parts[3]
	local base = CFrame.new(ground + Vector3.new(0, 4, 0))
	for _, p in ipairs(f.parts) do
		p.Anchored = true
	end
	pole.CFrame = base
	cloth.CFrame = base * CFrame.new(1.75, 2.6, 0)
	knob.CFrame = base * CFrame.new(0, 4.2, 0)
	f.lastPos = ground
end

local function release(f: Flag)
	if f.weld then
		f.weld:Destroy()
		f.weld = nil
	end
	if f.glow then
		f.glow:Destroy()
		f.glow = nil
	end
	f.carrier = nil
end

local function sendHome(f: Flag)
	release(f)
	f.droppedAt = nil
	plant(f, f.home)
end

local function atHome(f: Flag): boolean
	return f.carrier == nil and f.droppedAt == nil
end

-- the flag rides on the carrier's back, leaning back a little.
local function pickUp(f: Flag, cat: Model)
	local root = cat.PrimaryPart
	if not root then
		return
	end
	release(f)
	f.droppedAt = nil
	local base = root.CFrame * CFrame.new(0, 1.2, 1.1) * CFrame.Angles(math.rad(-12), 0, 0)
	local pole, cloth, knob = f.parts[1], f.parts[2], f.parts[3]
	pole.CFrame = base
	cloth.CFrame = base * CFrame.new(1.75, 2.6, 0)
	knob.CFrame = base * CFrame.new(0, 4.2, 0)
	for _, p in ipairs(f.parts) do
		p.Anchored = false
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = pole
	weld.Parent = pole
	f.weld = weld
	local glow = Instance.new("Highlight")
	glow.FillTransparency = 1
	glow.OutlineColor = TEAM_COLOR[cat:GetAttribute("Team") :: string] or Color3.new(1, 1, 1)
	glow.Parent = cat
	f.glow = glow
	f.carrier = cat
	announce(TEAM_NAME[f.team] .. " FLAG TAKEN!", catName(cat) .. " has it — stop them!", TEAM_COLOR[f.team])
end

local function aliveCat(m: Model): boolean
	local hum = m:FindFirstChildOfClass("Humanoid")
	return hum ~= nil and hum.Health > 0 and m.PrimaryPart ~= nil and m:IsDescendantOf(Workspace)
end

local function step()
	for _, f in pairs(flags) do
		local enemy = f.team == "Blue" and flags.Red or flags.Blue
		local carrier = f.carrier
		if carrier then
			if not aliveCat(carrier) then
				-- carrier went down: fell off the map -> home; else it lies there.
				local pos = f.lastPos
				release(f)
				if pos.Y < FELL_Y then
					sendHome(f)
					announce(TEAM_NAME[f.team] .. " FLAG RETURNED", "The carrier got knocked off the map!", TEAM_COLOR[f.team])
				else
					f.droppedAt = os.clock()
					plant(f, pos - Vector3.new(0, 1.9, 0))
					announce(TEAM_NAME[f.team] .. " FLAG DROPPED", "Touch it to send it home, or grab it!", TEAM_COLOR[f.team])
				end
			else
				local root = carrier.PrimaryPart :: BasePart
				f.lastPos = root.Position
				-- capture: carrier reaches their own flag while it is home.
				if enemy and atHome(enemy) then
					local off = root.Position - enemy.home
					if Vector3.new(off.X, 0, off.Z).Magnitude < GRAB_RADIUS + 1 and math.abs(off.Y) < 8 then
						local team = enemy.team
						sendHome(f)
						announce(TEAM_NAME[team] .. " TEAM CAPTURES!", catName(carrier) .. " brought the flag home!", TEAM_COLOR[team])
						if FlagService.OnCapture then
							task.spawn(FlagService.OnCapture, team, carrier)
						end
					end
				end
			end
		else
			if f.droppedAt and os.clock() - f.droppedAt > RETURN_SECONDS then
				sendHome(f)
				announce(TEAM_NAME[f.team] .. " FLAG RETURNED", "", TEAM_COLOR[f.team])
			else
				local spot = f.droppedAt and f.lastPos or f.home
				for _, m in ipairs(CollectionService:GetTagged(CatBuilder.Tag)) do
					if m:IsA("Model") and aliveCat(m) then
						local team = m:GetAttribute("Team")
						local off = (m.PrimaryPart :: BasePart).Position - spot
						if team and Vector3.new(off.X, 0, off.Z).Magnitude < GRAB_RADIUS and math.abs(off.Y) < 7 then
							if team ~= f.team then
								-- only one flag at a time per cat.
								local already = (enemy and enemy.carrier == m)
								if not already then
									pickUp(f, m)
									break
								end
							elseif f.droppedAt then
								sendHome(f)
								announce(TEAM_NAME[f.team] .. " FLAG RETURNED", catName(m) .. " saved it!", TEAM_COLOR[f.team])
								break
							end
						end
					end
				end
			end
		end
	end
end

-- home spot for a team's flag: behind the team's base spawn (the spawn
-- nearest the map's centre line), on the island top.
local function homeFor(team: string): Vector3?
	local arena = Workspace:FindFirstChild("Arena")
	local spawns = arena and arena:FindFirstChild("Spawns")
	if not spawns then
		return nil
	end
	local best: BasePart? = nil
	for _, s in ipairs(spawns:GetChildren()) do
		if s:IsA("BasePart") and s:GetAttribute("Team") == team then
			if not best or math.abs(s.Position.X) < math.abs(best.Position.X) then
				best = s
			end
		end
	end
	if not best then
		return nil
	end
	local p = best.Position
	local out = Vector3.new(p.X, 0, p.Z)
	out = out.Magnitude > 0.1 and out.Unit or Vector3.zAxis
	return Vector3.new(p.X, p.Y - 0.65, p.Z) + out * 6
end

function FlagService.Start()
	FlagService.Stop()
	local f = Instance.new("Folder")
	f.Name = "Flags"
	f.Parent = Workspace
	folder = f
	for _, team in ipairs({ "Blue", "Red" }) do
		local home = homeFor(team)
		if home then
			local flag = buildFlag(team, home, f)
			plant(flag, home)
			flags[team] = flag
		end
	end
	local acc = 0
	conn = RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.1 then
			acc = 0
			step()
		end
	end)
	Remotes.Get("Announce"):FireAllClients({
		title = "CAPTURE THE FLAG", sub = "Grab their flag and bring it to yours!", color = Color3.fromRGB(120, 230, 170),
	})
end

function FlagService.Stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	for _, f in pairs(flags) do
		release(f)
	end
	flags = {}
	if folder then
		folder:Destroy()
		folder = nil
	end
end

-- for bots: where a team should head. returns (goal, iscarrier).
--   carrying the enemy flag -> own flag's home
--   else -> the enemy flag (wherever it is), or chase whoever took ours
function FlagService.Objective(team: string, cat: Model): Vector3?
	local mine = flags[team]
	local theirs = team == "Blue" and flags.Red or flags.Blue
	if not mine or not theirs then
		return nil
	end
	if theirs.carrier == cat then
		return mine.home
	end
	local thief = mine.carrier
	if thief and thief.PrimaryPart then
		return thief.PrimaryPart.Position
	end
	if theirs.carrier then
		return theirs.carrier.PrimaryPart and theirs.carrier.PrimaryPart.Position or nil -- escort
	end
	return theirs.droppedAt and theirs.lastPos or theirs.home
end

function FlagService.IsCarrier(cat: Model): boolean
	for _, f in pairs(flags) do
		if f.carrier == cat then
			return true
		end
	end
	return false
end

return FlagService
