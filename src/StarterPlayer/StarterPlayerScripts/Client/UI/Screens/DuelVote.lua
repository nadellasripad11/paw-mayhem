--!strict
-- duelvote: once a duel is found, everyone in it votes - first pick a map,
-- then pick a gamemode - on the same picture-tile screen as the arena vote
-- (three big tiles across the top, random and the rest below), the time
-- left at the top. click a tile to vote; you can change it until time's up.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local MapTile = require(script.Parent.Parent.MapTile)

local DuelVote = {}

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local endsAt = 0

local GREEN = Color3.fromRGB(70, 200, 70)
-- picture colours for the duel maps and modes (they have no 3d snapshot).
local COLOR = {
	Meadow = Color3.fromRGB(90, 170, 70), Sakura = Color3.fromRGB(240, 150, 190), Autumn = Color3.fromRGB(220, 120, 40),
	Frost = Color3.fromRGB(150, 200, 240), Classic = Color3.fromRGB(70, 140, 230), Quick = Color3.fromRGB(240, 170, 50),
	Ringout = Color3.fromRGB(170, 110, 240), Marathon = Color3.fromRGB(220, 70, 80),
}

function DuelVote.IsOpen(): boolean
	return gui ~= nil and gui.Enabled
end

function DuelVote.Build()
	local g = UIUtil.make("ScreenGui", {
		Name = "PawDuelVote", Parent = player:WaitForChild("PlayerGui"), IgnoreGuiInset = true, ResetOnSpawn = false,
		DisplayOrder = 9, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
	gui = g
	local bg = UIUtil.make("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.04, BorderSizePixel = 0 })
	UIUtil.gradient(Color3.fromRGB(40, 90, 30), Color3.fromRGB(10, 26, 10), 90, bg)
	local timer = UIUtil.label({
		Parent = g, Text = "", Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 8), Size = UDim2.fromScale(0.1, 0.065),
		BackgroundTransparency = 0.1, BackgroundColor3 = Color3.fromRGB(14, 14, 18),
	})
	UIUtil.corner(UDim.new(0, 10), timer)
	local box = UIUtil.make("Frame", {
		Parent = g, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 66),
		Size = UDim2.new(0.76, 0, 1, -(UIUtil.topInset() + 80)), BackgroundTransparency = 1,
	})
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1.62
	ar.Parent = box
	local title = UIUtil.label({
		Parent = box, Text = "", Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 0.07),
	})
	local grid = UIUtil.make("Frame", { Parent = box, Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.9), BackgroundTransparency = 1 })

	local shownStage = ""
	local tiles: { [string]: MapTile.Tile } = {}
	local function paint(data: any)
		if data.stage ~= shownStage then
			shownStage = data.stage
			for _, c in ipairs(grid:GetChildren()) do
				c:Destroy()
			end
			tiles = {}
			title.Text = (data.stage == "Map" and "PICK A MAP" or "PICK A GAMEMODE") .. "  ·  " .. string.upper(tostring(data.kind or ""))
			-- three across the top, then random first on the row below.
			local options = {}
			local random = nil
			for _, o in ipairs(data.options or {}) do
				if o.id == "Random" then
					random = o
				else
					table.insert(options, o)
				end
			end
			if random then
				table.insert(options, math.min(4, #options + 1), random)
			end
			local list = {}
			for _, o in ipairs(options) do
				local isRandom = o.id == "Random"
				local t = MapTile.New(grid, tostring(o.name), isRandom and "Random" or (data.stage == "Map" and o.id or nil), COLOR[o.id] or Color3.fromRGB(80, 120, 200), GREEN, function()
					Remotes.Get("DuelVote"):FireServer({ choice = o.id })
				end)
				if o.desc and not isRandom then
					local d = UIUtil.label({
						Parent = t.button, Text = tostring(o.desc), Font = Theme.Font.Bold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
						AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(0.84, 0.18), ZIndex = 6,
					})
					d.TextStrokeTransparency = 0.4
				end
				tiles[o.id] = t
				table.insert(list, t)
			end
			MapTile.Layout(list)
		end
		for id, t in pairs(tiles) do
			t.setVotes(data.votes and data.votes[id] or 0)
			t.setPicked(data.myVote == id)
		end
	end

	Remotes.Get("DuelVote").OnClientEvent:Connect(function(data)
		if typeof(data) ~= "table" or type(data.stage) ~= "string" then
			g.Enabled = false
			shownStage = ""
			return
		end
		endsAt = tonumber(data.endsAt) or 0
		paint(data)
		g.Enabled = true
	end)
	task.spawn(function()
		while g.Parent do
			if g.Enabled then
				timer.Text = string.format("%.1f", math.max(0, endsAt - Workspace:GetServerTimeNow()))
			end
			task.wait(0.1)
		end
	end)
end

return DuelVote
