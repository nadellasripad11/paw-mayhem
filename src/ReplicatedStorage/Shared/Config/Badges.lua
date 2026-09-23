--!strict
-- Badges: Roblox badges awarded for milestones. `Id` is the badge id from the
-- Creator Dashboard (Paw Mayhem > Engagement > Badges). While an Id is 0 the
-- badge is simply skipped.

local Badges = {}

-- key -> { Id, Name, Desc, check(profile, level) }
Badges.List = {
	{ Key = "Welcome", Id = 0, Name = "Welcome to Paw Mayhem", Desc = "Join the game for the first time.", Check = function(_p, _lvl) return true end },
	{ Key = "FirstElim", Id = 0, Name = "First Knockout", Desc = "Eliminate your first cat.", Check = function(p) return (p.Stats.Eliminations or 0) >= 1 end },
	{ Key = "FirstWin", Id = 0, Name = "Winner Winner", Desc = "Win your first match.", Check = function(p) return (p.Stats.Wins or 0) >= 1 end },
	{ Key = "Elims100", Id = 0, Name = "Century Paws", Desc = "Get 100 eliminations.", Check = function(p) return (p.Stats.Eliminations or 0) >= 100 end },
	{ Key = "Wins10", Id = 0, Name = "Top Cat", Desc = "Win 10 matches.", Check = function(p) return (p.Stats.Wins or 0) >= 10 end },
	{ Key = "Level10", Id = 0, Name = "Level 10", Desc = "Reach level 10.", Check = function(_p, lvl) return lvl >= 10 end },
	{ Key = "Streak7", Id = 0, Name = "Loyal Kitty", Desc = "Log in 7 days in a row.", Check = function(p) return (p.Daily and p.Daily.Streak or 0) >= 7 end },
	{ Key = "Season30", Id = 0, Name = "Season Legend", Desc = "Reach tier 30 of the season pass.", Check = function(p) return (p.Season and p.Season.XP or 0) >= 30 * 300 end },
}

return Badges
