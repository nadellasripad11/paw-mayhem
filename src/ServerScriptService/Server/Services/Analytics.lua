--!strict
-- Analytics: logs where new players are in their first session to Roblox's
-- onboarding funnel (Creator Dashboard -> Analytics -> Funnels), so we can see
-- where people quit. Roblox keeps only the first time each player hits a step.

local AnalyticsService = game:GetService("AnalyticsService")

local Analytics = {}

Analytics.Steps = {
	Joined = 1,
	PressedPlay = 2,
	FirstMatchStarted = 3,
	FirstKnockout = 4,
	FirstMatchFinished = 5,
	SecondMatchFinished = 6,
}

function Analytics.Step(player: Player, name: string)
	local step = Analytics.Steps[name]
	if not step then
		return
	end
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

return Analytics
