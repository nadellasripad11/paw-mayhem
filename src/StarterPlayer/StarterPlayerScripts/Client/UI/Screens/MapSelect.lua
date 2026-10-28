--!strict
-- mapselect: the arena vote, in two steps like rivals. first pick a map: the
-- maps as big picture tiles (three across the top, random and the rest
-- below) with their vote counts and the time to the next round at the top.
-- pick one and the same kind of screen asks pick a gamemode (with random
-- too); picking that queues you for the next round with both votes. back
-- goes from the gamemodes to the maps, and from the maps out.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Modes = require(ReplicatedStorage.Shared.Config.Modes)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local MapTile = require(script.Parent.Parent.MapTile)
local ClientState = require(script.Parent.Parent.Parent.ClientState)

local MapSelect = {}

local MAPS = {
	{ id = "SkyIslands", name = "Sky Islands", color = Color3.fromRGB(110, 190, 255) },
	{ id = "Volcano", name = "Volcano", color = Color3.fromRGB(150, 50, 40) },
	{ id = "Toybox", name = "Toybox", color = Color3.fromRGB(150, 220, 255) },
	{ id = "Random", name = "Random" },
	{ id = "Rooftops", name = "Rooftops", color = Color3.fromRGB(110, 60, 170) },
}
local GREEN = Color3.fromRGB(70, 200, 70)

local root: TextButton
local title: TextLabel
local timer: TextLabel
local mapGrid: Frame
local modeGrid: Frame
local mapTiles: { [string]: MapTile.Tile } = {}
local modeTiles: { [string]: MapTile.Tile } = {}
local chosenMap: string? = nil
local chosenMode: string? = nil

local function realMaps(): { string }
	local out = {}
	for _, m in ipairs(MAPS) do
		if m.id ~= "Random" then
			table.insert(out, m.id)
		end
	end
	return out
end

local function showStep(step: string)
	mapGrid.Visible = step == "map"
	modeGrid.Visible = step == "mode"
	title.Text = step == "map" and "PICK A MAP" or "PICK A GAMEMODE"
end

local function refresh()
	local votes = ClientState.Match.votes or {}
	for id, t in pairs(mapTiles) do
		t.setVotes(votes[id] or 0)
		t.setPicked(id == chosenMap)
	end
	for id, t in pairs(modeTiles) do
		t.setPicked(id == chosenMode)
	end
end

local function pickMap(id: string)
	if id == "Random" then
		local list = realMaps()
		id = list[math.random(1, #list)]
	end
	chosenMap = id
	refresh()
	-- the gamemode tiles show the map you picked.
	showStep("mode")
end

local function pickMode(id: string)
	if id == "Random" then
		id = Modes.List[math.random(1, #Modes.List)].Id
	end
	chosenMode = id
	refresh()
	local m = ClientState.Match
	local mapId = m.phase == "Playing" and m.mapId or chosenMap or "SkyIslands"
	Remotes.Get("RequestJoinMatch"):FireServer({ mapId = mapId, modeId = id })
	MapSelect.Close()
end

local function grid(parent: Instance): Frame
	return UIUtil.make("Frame", { Parent = parent, Position = UDim2.fromScale(0, 0.1), Size = UDim2.fromScale(1, 0.9), BackgroundTransparency = 1 }) :: Frame
end

function MapSelect.Build(parent: Instance)
	root = UIUtil.make("TextButton", {
		Parent = parent, Name = "MapSelect", Text = "", AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.04, BorderSizePixel = 0, ZIndex = 50, Visible = false,
	}) :: TextButton
	UIUtil.gradient(Color3.fromRGB(40, 90, 30), Color3.fromRGB(10, 26, 10), 90, root)

	-- time to the next round, top centre, and what to pick under it.
	timer = UIUtil.label({
		Parent = root, Text = "", Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 8), Size = UDim2.fromScale(0.1, 0.065),
		BackgroundTransparency = 0.1, BackgroundColor3 = Color3.fromRGB(14, 14, 18), ZIndex = 52,
	})
	UIUtil.corner(UDim.new(0, 10), timer)

	local box = UIUtil.make("Frame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, UIUtil.topInset() + 66),
		Size = UDim2.new(0.76, 0, 1, -(UIUtil.topInset() + 80)), BackgroundTransparency = 1, ZIndex = 51,
	})
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1.62
	ar.Parent = box
	title = UIUtil.label({
		Parent = box, Text = "", Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 0.07), ZIndex = 52,
	})
	local back = UIUtil.make("TextButton", {
		Parent = box, Text = "BACK", Font = Theme.Font.Title, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0.1, 0.065), BackgroundColor3 = Color3.fromRGB(20, 24, 20), BorderSizePixel = 0, ZIndex = 52,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 8), back)
	back.MouseButton1Click:Connect(function()
		if modeGrid.Visible then
			showStep("map")
		else
			MapSelect.Close()
		end
	end)

	mapGrid = grid(box)
	local list = {}
	for _, m in ipairs(MAPS) do
		local t = MapTile.New(mapGrid, m.name, m.id ~= "Random" and m.id or "Random", m.color or Color3.fromRGB(26, 26, 30), GREEN, function()
			pickMap(m.id)
		end)
		mapTiles[m.id] = t
		table.insert(list, t)
	end
	MapTile.Layout(list)

	modeGrid = grid(box)
	local modes = {}
	local order = { Modes.List[1], Modes.List[2], Modes.List[3], "Random" :: any }
	for i = 4, #Modes.List do
		table.insert(order, Modes.List[i])
	end
	local shots = { "SkyIslands", "Volcano", "Toybox", "Rooftops", "SkyIslands" }
	for i, m in ipairs(order) do
		local id = m == "Random" and "Random" or m.Id
		local t = MapTile.New(modeGrid, m == "Random" and "Random" or (m.Name :: string), m == "Random" and "Random" or shots[(i - 1) % #shots + 1],
			m == "Random" and Color3.fromRGB(26, 26, 30) or m.Color:Lerp(Color3.new(0, 0, 0), 0.3), m == "Random" and GREEN or m.Color, function()
				pickMode(id)
			end)
		if m ~= "Random" then
			-- the rules over the picture.
			local rules = UIUtil.label({
				Parent = t.button, Text = m.Rules, Font = Theme.Font.Bold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
				AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.06), Size = UDim2.fromScale(0.86, 0.12),
				BackgroundTransparency = 0.25, BackgroundColor3 = Color3.fromRGB(12, 12, 14), ZIndex = 6,
			})
			UIUtil.corner(UDim.new(0, 6), rules)
		end
		modeTiles[id] = t
		table.insert(modes, t)
	end
	MapTile.Layout(modes)
	showStep("map")

	task.spawn(function()
		while root.Parent do
			if root.Visible then
				local m = ClientState.Match
				local t = m.timeLeft or 0
				timer.Text = m.phase == "Playing" and "LIVE" or (tostring(math.max(0, math.floor(t))) .. "s")
			end
			task.wait(0.25)
		end
	end)
	ClientState.MatchChanged:Connect(function()
		if root.Visible then
			refresh()
		end
	end)
end

function MapSelect.Open()
	if not root then
		return
	end
	chosenMap, chosenMode = nil, nil
	showStep("map")
	root.Visible = true
	refresh()
end

function MapSelect.Close()
	if root then
		root.Visible = false
	end
end

function MapSelect.IsOpen(): boolean
	return root ~= nil and root.Visible
end

return MapSelect
