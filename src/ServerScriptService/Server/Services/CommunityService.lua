--!strict
-- communityservice: the group reward (members get +10% coins) and weekend
-- mayhem (sat + sun utc: lower gravity and bonus coins). also logs the
-- "joined" onboarding step.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Community = require(ReplicatedStorage.Shared.Config.Community)
local Analytics = require(script.Parent.Analytics)

local CommunityService = {}

local NORMAL_GRAVITY = 196.2

local function isWeekend(): boolean
	local wday = (os.date("!*t") :: any).wday
	return wday == 1 or wday == 7
end

-- workspace attributes the rest of the game reads: basegravity (eventservice
-- returns to it after its own gravity events) and coinboost (economyservice).
local function applyWeekend()
	local on = isWeekend()
	if Workspace:GetAttribute("Weekend") == on then
		return
	end
	Workspace:SetAttribute("Weekend", on)
	local base = on and Community.WeekendGravity or NORMAL_GRAVITY
	Workspace:SetAttribute("BaseGravity", base)
	Workspace:SetAttribute("CoinBoost", on and Community.WeekendCoinBoost or 1)
	Workspace.Gravity = base
end

local function onPlayer(player: Player)
	Analytics.Step(player, "Joined")
	if Community.GroupId > 0 then
		local ok, member = pcall(function()
			return player:IsInGroup(Community.GroupId)
		end)
		if ok and member then
			player:SetAttribute("GroupMember", true)
			task.delay(6, function()
				Remotes.Get("Notify"):FireClient(player, { text = "Group bonus: +10% coins!", kind = "success" })
			end)
		end
	end
end

function CommunityService.Start()
	applyWeekend()
	task.spawn(function()
		while true do
			task.wait(60)
			applyWeekend()
		end
	end)
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayer, p)
	end
	Players.PlayerAdded:Connect(onPlayer)
end

return CommunityService
