--!strict
-- EmoteController: plays the player's equipped emote as a lightweight procedural
-- animation on the custom cat rig (no external animation assets). Press B (PC),
-- or call Play() from an emote button. Broadcasts intent to the server so it can
-- optionally replicate; visually it runs locally for instant feedback.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local ClientState = require(script.Parent.Parent.ClientState)
local ClientActions = require(script.Parent.Parent.ClientActions)

local EmoteController = {}
local player = Players.LocalPlayer
local playing = false

local function root(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- Simple procedural motions keyed by emote id.
local function animate(emoteId: string)
	local r = root()
	if not r or playing then
		return
	end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health <= 0 then
		return
	end
	playing = true
	local char = player.Character
	if char then
		char:SetAttribute("Emoting", true)
		char:SetAttribute("Emote", emoteId)
		char:SetAttribute("EmoteAt", workspace:GetServerTimeNow())
	end
	local base = r.CFrame

	local function restore()
		playing = false
		if char then
			char:SetAttribute("Emoting", nil)
		end
	end

	if emoteId == "Spin" then
		task.spawn(function()
			for i = 1, 20 do
				local rr = root()
				if not rr then break end
				rr.CFrame = rr.CFrame * CFrame.Angles(0, math.rad(18), 0)
				task.wait(0.02)
			end
			restore()
		end)
	elseif emoteId == "Zoomies" then
		-- Tear round in a little circle.
		task.spawn(function()
			local rr = root()
			if not rr then
				restore()
				return
			end
			local lv = Instance.new("LinearVelocity")
			local att = Instance.new("Attachment")
			att.Parent = rr
			lv.Attachment0 = att
			lv.RelativeTo = Enum.ActuatorRelativeTo.World
			lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
			lv.PrimaryTangentAxis = Vector3.xAxis
			lv.SecondaryTangentAxis = Vector3.zAxis
			lv.MaxForce = rr.AssemblyMass * 3000
			lv.Parent = rr
			local t0 = os.clock()
			while os.clock() - t0 < 2.4 and rr.Parent do
				local a = (os.clock() - t0) * 6
				local dir = Vector3.new(math.cos(a), 0, math.sin(a))
				lv.PlaneVelocity = Vector2.new(dir.X, dir.Z) * 26
				rr.CFrame = CFrame.lookAt(rr.Position, rr.Position + dir)
				RunService.Heartbeat:Wait()
			end
			lv:Destroy()
			att:Destroy()
			restore()
		end)
	elseif emoteId == "Happy" or emoteId == "Celebrate" or emoteId == "Wave" then
		-- little hops
		task.spawn(function()
			for i = 1, 3 do
				local rr = root()
				if not rr then break end
				rr:ApplyImpulse(Vector3.new(0, rr.AssemblyMass * 18, 0))
				task.wait(0.35)
			end
			restore()
		end)
	else
		-- The pose itself comes from CatBuilder.Pose (Emote attributes).
		task.delay(2.6, restore)
	end
end

function EmoteController.Play(emoteId: string?)
	local id = emoteId or (ClientState.Profile and ClientState.Profile.Loadout.Cat.Emote) or "Happy"
	ClientActions.UseEmote(id)
	animate(id)
end

function EmoteController.Start()
	UserInputService.InputBegan:Connect(function(input, gpe)
		if gpe then
			return
		end
		if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.ButtonY then
			EmoteController.Play()
		end
	end)
end

return EmoteController
