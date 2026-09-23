--!strict
-- DailyRewards: a 7-day login calendar. Claim once per day (UTC); missing a
-- day resets the streak to Day 1. After Day 7 the calendar loops.

local DailyRewards = {}

DailyRewards.Days = {
	{ Coins = 100 },
	{ Coins = 150 },
	{ Gems = 10 },
	{ Coins = 250 },
	{ Gems = 20 },
	{ Coins = 400 },
	{ Coins = 500, Gems = 50 }, -- big Day 7 chest
}

function DailyRewards.Today(): number
	return math.floor(os.time() / 86400)
end

-- `daily` = profile.Daily { LastDay, Streak }. Returns what the player would
-- get if they claimed now.
function DailyRewards.Status(daily: any, today: number?): { CanClaim: boolean, Streak: number, NextIndex: number }
	local d = today or DailyRewards.Today()
	local last = daily and daily.LastDay or 0
	local streak = daily and daily.Streak or 0
	local canClaim = last < d
	-- Missed a day: the streak starts over.
	if canClaim and last < d - 1 then
		streak = 0
	end
	local nextIndex = (streak % #DailyRewards.Days) + 1
	if not canClaim then
		nextIndex = ((streak - 1) % #DailyRewards.Days) + 1
	end
	return { CanClaim = canClaim, Streak = streak, NextIndex = nextIndex }
end

return DailyRewards
