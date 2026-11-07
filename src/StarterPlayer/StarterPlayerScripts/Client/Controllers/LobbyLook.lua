--!strict
-- lobbylook: turns the lobby's floating displays (tagged lobbyspin) while
-- you're in the lobby. it used to swap in its own lobby lighting too; that
-- made the room too bright, so the lobby now keeps the lighting you spawn in
-- with (the place's own, plus the room lights lobbyservice hangs from
-- shared/lobbylighting).

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local LobbyLook = {}

local active = false

function LobbyLook.Set(on: boolean)
	active = on
end

function LobbyLook.Start()
	-- floating displays: a slow turn and a gentle bob round where they were built.
	RunService.RenderStepped:Connect(function()
		if not active then
			return
		end
		local t = os.clock()
		for i, m in ipairs(CollectionService:GetTagged("LobbySpin")) do
			local pivot = m:GetAttribute("SpinPivot")
			if m:IsA("Model") and typeof(pivot) == "CFrame" then
				local bob = math.sin(t * 1.6 + i) * 0.35
				m:PivotTo(CFrame.new(pivot.Position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, t * 0.8 + i, 0) * pivot.Rotation)
			end
		end
	end)
end

return LobbyLook
