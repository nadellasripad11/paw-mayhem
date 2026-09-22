--!strict
-- Quests: the three daily quests with progress bars + claim buttons.

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local HeroArt = require(script.Parent.Parent.HeroArt)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local ClientActions = require(script.Parent.Parent.Parent.ClientActions)

local Quests = {}
local list

local function rebuild()
	if not list then return end
	list:ClearAllChildren()
	UIUtil.listLayout(list, 10)
	local profile = ClientState.Profile
	if not profile then return end
	for _, q in ipairs(profile.Quests.Active or {}) do
		local row = UIUtil.panel({ Parent = list, Size = UDim2.new(1, 0, 0, 70), BackgroundColor3 = Theme.Color.PanelLight })
		UIUtil.padding(12, row)
		UIUtil.label({ Parent = row, Text = q.Text, Font = Theme.Font.Bold, TextSize = 16, Size = UDim2.new(1, -120, 0, 20) })
		-- progress bar
		local track = UIUtil.make("Frame", { Parent = row, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -120, 0, 14), BackgroundColor3 = Theme.Color.PanelDark, BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(1, 0), track)
		local frac = math.clamp(q.Progress / q.Target, 0, 1)
		local fill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(frac, 1), BackgroundColor3 = Theme.Color.Accent, BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(1, 0), fill)
		UIUtil.label({ Parent = row, Text = string.format("%d / %d", q.Progress, q.Target), TextColor3 = Theme.Color.TextDim, TextSize = 11, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, -120, 0, 14) })

		-- reward + claim
		local rewardRow = UIUtil.make("Frame", { Parent = row, Position = UDim2.new(1, -110, 0, 0), Size = UDim2.fromOffset(100, 20), BackgroundTransparency = 1 })
		UIUtil.listLayout(rewardRow, 4, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Right
		local coinIconSlot = UIUtil.make("Frame", { Parent = rewardRow, Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1 })
		Icons.Place("Coin", coinIconSlot, 18, Theme.Color.Coin)
		UIUtil.label({ Parent = rewardRow, Text = tostring(q.Coins), TextColor3 = Theme.Color.Coin, Font = Theme.Font.Number, TextSize = 16, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20) })

		local btn = UIUtil.button({ Parent = row, Position = UDim2.new(1, -100, 1, -30), Size = UDim2.fromOffset(100, 30), BackgroundColor3 = Theme.Color.Play, Text = "CLAIM", TextSize = 14 })
		if q.Claimed then
			btn.Text = ""
			Icons.Place("Check", btn, 18, Color3.new(1, 1, 1))
			btn.BackgroundColor3 = Theme.Color.PanelDark; btn.TextColor3 = Theme.Color.TextMuted
		elseif q.Progress < q.Target then
			btn.Text = "LOCKED"; btn.BackgroundColor3 = Theme.Color.PanelDark; btn.TextColor3 = Theme.Color.TextMuted
		else
			btn.MouseButton1Click:Connect(function()
				local res = ClientActions.ClaimQuest(q.Id)
				if res.ok then rebuild() end
			end)
		end
	end
end

function Quests.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	HeroArt.Watermark(root)
	local header = UIUtil.make("Frame", { Parent = root, Size = UDim2.new(1, 0, 0, 24), BackgroundTransparency = 1 })
	local checkSlot = UIUtil.make("Frame", { Parent = header, Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1 })
	Icons.Place("Check", checkSlot, 20, Theme.Color.Success)
	UIUtil.label({ Parent = header, Text = "DAILY QUESTS", Font = Theme.Font.Heading, TextSize = 18, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 1, 0) })
	UIUtil.label({ Parent = root, Text = "Reset every day. Complete them across matches to earn coins.", TextColor3 = Theme.Color.TextMuted, TextSize = 12, Position = UDim2.fromOffset(0, 26), Size = UDim2.new(1, 0, 0, 16) })
	list = UIUtil.make("Frame", { Parent = root, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50) })
	rebuild()
	ClientState.ProfileChanged:Connect(rebuild)
	Quests.Root = root
	return root
end

return Quests
