--!strict
-- MapSelect: full-screen map picker opened by the home screen's Play button.
-- Three big map cards with live vote counts, a status line and a PLAY button
-- that queues the player (and casts their vote) for the next round. Changing
-- the selected map after queueing re-sends the vote.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local HeroArt = require(script.Parent.Parent.HeroArt)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Modes = require(ReplicatedStorage.Shared.Config.Modes)

local MapSelect = {}

local MAPS = {
	{ id = "SkyIslands", name = "SKY ISLANDS", subtitle = "Floating Village", accent = Color3.fromRGB(95, 205, 255) },
	{ id = "Volcano", name = "VOLCANO", subtitle = "Lava Foundry", accent = Color3.fromRGB(255, 120, 54) },
	{ id = "Toybox", name = "TOYBOX", subtitle = "Candy Playground", accent = Color3.fromRGB(255, 133, 190) },
}

local W, H = 1000, 560
local CARD_W, CARD_H, ART_H = 316, 400, 292

local root: TextButton
local cards: { any } = {}
local selectedId = "SkyIslands"
local selectedMode = Modes.Default
local modeLabels: { TextLabel } = {}
local modeButtons: { [string]: TextButton } = {}
local rulesLabel: TextLabel? = nil
local queued = false
local statusMain: TextLabel
local statusSub: TextLabel
local playButton: TextButton
local playStroke: UIStroke
local layer = 1 -- later art pieces draw on top of earlier ones

local function box(parent: Instance, size: UDim2, pos: UDim2, color: Color3, corner: number?, anchor: Vector2?): Frame
	local f = UIUtil.make("Frame", {
		Parent = parent, Size = size, Position = pos, AnchorPoint = anchor or Vector2.zero,
		BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = layer,
	}) :: Frame
	layer += 1
	if corner then
		UIUtil.corner(UDim.new(corner, 0), f)
	end
	return f
end

-- ── card art ─────────────────────────────────────────────────────────────────
local function skyArt(art: Instance)
	HeroArt.Sky(art)
	HeroArt.Island(art, { width = 230, position = UDim2.fromScale(0.28, 1.1) })
	HeroArt.Island(art, { width = 300, position = UDim2.fromScale(0.74, 1.14) })
end

local function volcanoArt(art: Instance)
	UIUtil.gradient(Color3.fromRGB(255, 150, 70), Color3.fromRGB(58, 22, 52), 90, box(art, UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1)))
	for i = 1, 14 do
		local e = box(art, UDim2.fromOffset(4, 4), UDim2.fromScale((i * 0.37) % 1, 0.08 + (i * 0.23) % 0.5), Color3.fromRGB(255, 200, 90), 0.5)
		e.BackgroundTransparency = 0.3
	end
	-- mountain: a rotated square whose lower half is clipped by the card
	local peak = UDim2.fromScale(0.5, 0.38)
	local mtn = box(art, UDim2.fromOffset(250, 250), UDim2.new(0.5, 0, 0.38, 177), Color3.new(1, 1, 1), 0.06, Vector2.new(0.5, 0.5))
	mtn.Rotation = 45
	UIUtil.gradient(Color3.fromRGB(92, 56, 72), Color3.fromRGB(40, 26, 40), 45, mtn)
	for _, side in ipairs({ -1, 1 }) do
		local river = box(art, UDim2.fromOffset(9, 130), UDim2.new(0.5, side * 36, 0.38, 60), Color3.fromRGB(255, 120, 40), 0.5, Vector2.new(0.5, 0.5))
		river.Rotation = side * -32
	end
	box(art, UDim2.fromOffset(58, 20), peak, Color3.fromRGB(255, 190, 70), 0.5, Vector2.new(0.5, 0.5))
	local glow = box(art, UDim2.fromOffset(110, 60), peak, Color3.fromRGB(255, 120, 40), 0.5, Vector2.new(0.5, 0.5))
	glow.BackgroundTransparency = 0.7
	for i, spec in ipairs({ { 0.14, 0.78, 96 }, { 0.86, 0.74, 104 }, { 0.5, 0.93, 150 } }) do
		local plat = box(art, UDim2.fromOffset(spec[3], 18), UDim2.fromScale(spec[1], spec[2]), Color3.fromRGB(70, 48, 78), 0.3, Vector2.new(0.5, 0.5))
		box(plat, UDim2.new(1, -10, 0, 3), UDim2.new(0.5, 0, 1, 0), Color3.fromRGB(255, 130, 50), 0.5, Vector2.new(0.5, 0.5))
		if i < 3 then
			box(art, UDim2.fromOffset(4, 34), UDim2.new(spec[1], 0, spec[2], -24), Color3.fromRGB(120, 84, 60), nil, Vector2.new(0.5, 0.5))
		end
	end
end

local function toyArt(art: Instance)
	UIUtil.gradient(Color3.fromRGB(125, 212, 255), Color3.fromRGB(246, 168, 214), 90, box(art, UDim2.fromScale(1, 1), UDim2.new(), Color3.new(1, 1, 1)))
	for i, c in ipairs({ { 0.22, 0.16, 70 }, { 0.7, 0.1, 90 }, { 0.9, 0.3, 50 } }) do
		local cloud = box(art, UDim2.fromOffset(c[3], c[3] * 0.45), UDim2.fromScale(c[1], c[2]), Color3.new(1, 1, 1), 0.5, Vector2.new(0.5, 0.5))
		cloud.BackgroundTransparency = 0.2 + i * 0.1
	end
	local colors = { Color3.fromRGB(255, 117, 156), Color3.fromRGB(113, 204, 255), Color3.fromRGB(255, 218, 93), Color3.fromRGB(180, 142, 255), Color3.fromRGB(120, 226, 150) }
	local stacks = { { 0.18, 3 }, { 0.4, 2 }, { 0.62, 4 }, { 0.84, 2 } }
	for si, s in ipairs(stacks) do
		for k = 1, s[2] do
			local b = box(art, UDim2.fromOffset(40, 36), UDim2.new(s[1], 0, 1, -8 - (k - 0.5) * 38), colors[(si + k) % #colors + 1], 0.18, Vector2.new(0.5, 0.5))
			b.Rotation = ((si + k) % 3 - 1) * 5
			UIUtil.stroke(Color3.new(1, 1, 1), 2, b).Transparency = 0.4
		end
	end
	for i, l in ipairs({ { 0.29, 0.5 }, { 0.73, 0.42 } }) do
		box(art, UDim2.fromOffset(5, 90), UDim2.new(l[1], 0, l[2], 60), Color3.new(1, 1, 1), 0.5, Vector2.new(0.5, 0.5))
		local candy = box(art, UDim2.fromOffset(46, 46), UDim2.fromScale(l[1], l[2]), colors[i], 0.5, Vector2.new(0.5, 0.5))
		UIUtil.stroke(Color3.new(1, 1, 1), 5, candy)
	end
end

local ART = { SkyIslands = skyArt, Volcano = volcanoArt, Toybox = toyArt }
-- Backdrop colour behind each map's 3D preview.
local PREVIEW_SKY = {
	SkyIslands = Color3.fromRGB(140, 200, 255),
	Volcano = Color3.fromRGB(86, 34, 44),
	Toybox = Color3.fromRGB(196, 214, 255),
}

-- ── state ────────────────────────────────────────────────────────────────────
local function refreshCards()
	local votes = ClientState.Match.votes or {}
	for _, c in ipairs(cards) do
		local on = c.map.id == selectedId
		c.stroke.Color = on and c.map.accent or Color3.fromRGB(60, 80, 110)
		c.stroke.Thickness = on and 4 or 2
		c.scale.Scale = on and 1.03 or 1
		c.badge.Visible = on
		c.card.BackgroundColor3 = on and Color3.fromRGB(22, 42, 70) or Color3.fromRGB(14, 26, 46)
		local n = votes[c.map.id] or 0
		c.votes.Text = n == 1 and "1 VOTE" or (tostring(n) .. " VOTES")
	end
end

local function mapName(id: string?): string
	for _, m in ipairs(MAPS) do
		if m.id == id then
			return m.name
		end
	end
	return "SKY ISLANDS"
end

local function refreshStatus()
	local m = ClientState.Match
	local t = m.timeLeft or 0
	if m.phase == "Playing" then
		statusMain.Text = "MATCH IN PROGRESS"
		statusSub.Text = "Press PLAY to jump straight in on " .. mapName(m.mapId) .. "."
	elseif m.phase == "Countdown" then
		statusMain.Text = "MATCH STARTING"
		statusSub.Text = "Dropping into " .. mapName(m.mapId) .. " in " .. t .. "…"
	elseif m.phase == "Results" then
		statusMain.Text = "ROUND ENDING"
		statusSub.Text = "The next round opens in a moment."
	elseif queued then
		statusMain.Text = "YOU'RE IN!  •  VOTED " .. mapName(selectedId)
		statusSub.Text = "Waiting for the round to start…  Tap another map to change your vote."
	else
		statusMain.Text = "PICK A MAP AND HIT PLAY"
		statusSub.Text = "Next round in " .. t .. "s  •  most votes wins"
	end
	local live = m.phase == "Playing"
	playButton.Text = (queued and not live) and "QUEUED" or "PLAY"
	playButton.BackgroundColor3 = (queued and not live) and Color3.fromRGB(62, 120, 90) or Theme.Color.Play
	playStroke.Transparency = (queued and not live) and 0.6 or 0.1
end

local function sendVote()
	local m = ClientState.Match
	local mapId = m.phase == "Playing" and (m.mapId or selectedId) or selectedId
	Remotes.Get("RequestJoinMatch"):FireServer({ mapId = mapId, modeId = selectedMode })
	if m.phase ~= "Playing" then
		queued = true
	end
	refreshStatus()
end

local function paintModes()
	local mode = Modes.Get(selectedMode)
	for id, b in pairs(modeButtons) do
		local on = id == selectedMode
		local c = Modes.Get(id).Color
		b.BackgroundColor3 = on and c or Color3.fromRGB(22, 36, 62)
		b.TextColor3 = on and Color3.fromRGB(12, 16, 30) or Color3.new(1, 1, 1)
	end
	for _, l in ipairs(modeLabels) do
		l.Text = mode.Short
	end
	if rulesLabel then
		local match = GameConfig.Match
		rulesLabel.Text = string.format("%s  •  %d:%02d  •  %s", mode.Short, match.MatchSeconds // 60, match.MatchSeconds % 60, mode.Rules)
	end
end

local function chooseMode(id: string)
	selectedMode = id
	paintModes()
	if queued and ClientState.Match.phase == "Intermission" then
		sendVote()
	end
end

local function chooseMap(id: string)
	selectedId = id
	refreshCards()
	if queued and ClientState.Match.phase == "Intermission" then
		sendVote()
	else
		refreshStatus()
	end
end

-- ── build ────────────────────────────────────────────────────────────────────
local function buildCard(parent: Instance, map, index: number)
	local card = UIUtil.make("TextButton", {
		Parent = parent, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((index - 1) * (CARD_W + 26) + CARD_W / 2, CARD_H / 2),
		Size = UDim2.fromOffset(CARD_W, CARD_H),
		BackgroundColor3 = Color3.fromRGB(14, 26, 46),
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 18), card)
	local stroke = UIUtil.stroke(Color3.fromRGB(60, 80, 110), 2, card)
	local scale = Instance.new("UIScale")
	scale.Parent = card

	local art = UIUtil.make("CanvasGroup", {
		Parent = card, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, ART_H),
		BackgroundColor3 = map.accent, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(0, 12), art)
	local ok, err = pcall(ART[map.id], art)
	if not ok then
		warn("[PAW MAYHEM] Map art failed for " .. map.id .. ": " .. tostring(err))
	end
	-- Swap the drawing for the real map in 3D once its snapshot arrives
	-- (the server saves one per map at startup).
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("MapPreviews", 30)
		local src = folder and folder:WaitForChild(map.id, 10)
		if not src then
			return
		end
		local vf = Instance.new("ViewportFrame")
		vf.Position = art.Position
		vf.Size = art.Size
		vf.BackgroundColor3 = PREVIEW_SKY[map.id] or map.accent
		vf.Ambient = Color3.fromRGB(215, 215, 225)
		vf.LightColor = Color3.fromRGB(255, 250, 238)
		vf.LightDirection = Vector3.new(-0.35, -1, 0.45)
		vf.ZIndex = 2
		vf.Parent = card
		UIUtil.corner(UDim.new(0, 12), vf)
		local model = src:Clone()
		model.Parent = vf
		-- Frame the playable islands (saved by the server), seen from above at
		-- a three-quarter angle like a map-select splash.
		local bbCf, bbSize = model:GetBoundingBox()
		local focus = src:GetAttribute("FocusCenter")
		local span = src:GetAttribute("FocusSize")
		local center = typeof(focus) == "Vector3" and focus or bbCf.Position
		local size = typeof(span) == "Vector3" and span or bbSize
		local cam = Instance.new("Camera")
		cam.FieldOfView = 38
		local dist = math.max(size.X, size.Z) * 0.5 / math.tan(math.rad(19)) * 0.78
		cam.CFrame = CFrame.lookAt(center + Vector3.new(dist * 0.35, dist * 0.62, dist * 0.7), center + Vector3.new(0, -size.Y * 0.1, 0))
		cam.Parent = vf
		vf.CurrentCamera = cam
		art.Visible = false
	end)

	local votePill = box(card, UDim2.fromOffset(92, 28), UDim2.new(1, -18, 0, 18), Color3.fromRGB(10, 18, 34), 0.5, Vector2.new(1, 0))
	votePill.ZIndex = 20
	votePill.BackgroundTransparency = 0.2
	local votes = UIUtil.label({
		Parent = votePill, Text = "0 VOTES", Font = Theme.Font.Bold, TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1),
	})

	local badge = box(card, UDim2.fromOffset(122, 30), UDim2.new(0, 18, 0, ART_H - 30), map.accent, 0.5)
	badge.ZIndex = 20
	local check = UIUtil.make("Frame", { Parent = badge, Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(8, 4), BackgroundTransparency = 1 })
	Icons.Place("Check", check, 16, Color3.fromRGB(10, 22, 40))
	UIUtil.label({
		Parent = badge, Text = "SELECTED", Font = Theme.Font.Bold, TextSize = 13, TextColor3 = Color3.fromRGB(10, 22, 40),
		Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -36, 1, 0),
	})

	UIUtil.label({
		Parent = card, Text = map.name, Font = Theme.Font.Title, TextSize = 30,
		Position = UDim2.fromOffset(20, ART_H + 20), Size = UDim2.new(1, -40, 0, 34),
	})
	UIUtil.label({
		Parent = card, Text = string.upper(map.subtitle), Font = Theme.Font.Bold, TextSize = 14, TextColor3 = map.accent,
		Position = UDim2.fromOffset(20, ART_H + 56), Size = UDim2.new(1, -40, 0, 18),
	})
	table.insert(modeLabels, UIUtil.label({
		Parent = card, Text = "TEAM DEATHMATCH", Font = Theme.Font.Bold, TextSize = 13, TextColor3 = Theme.Color.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(20, ART_H + 56), Size = UDim2.new(1, -40, 0, 18),
	}))

	card.MouseButton1Click:Connect(function()
		chooseMap(map.id)
	end)
	table.insert(cards, { map = map, card = card, stroke = stroke, scale = scale, badge = badge, votes = votes })
end

function MapSelect.Build(parent: Instance)
	root = UIUtil.make("TextButton", {
		Parent = parent, Name = "MapSelect", Text = "", AutoButtonColor = false,
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.08, BorderSizePixel = 0, ZIndex = 50, Visible = false,
	}) :: TextButton
	UIUtil.gradient(Color3.fromRGB(16, 36, 70), Color3.fromRGB(4, 8, 18), 90, root)

	local stage = UIUtil.make("Frame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1,
	}) :: Frame
	local stageScale = Instance.new("UIScale")
	stageScale.Parent = stage

	local back = UIUtil.button({
		Parent = stage, Size = UDim2.fromOffset(112, 44), BackgroundColor3 = Color3.fromRGB(28, 44, 74),
		Text = "‹  BACK", Font = Theme.Font.Title, TextSize = 20, CornerRadius = UDim.new(0, 12),
	}, function()
		MapSelect.Close()
	end)
	UIUtil.stroke(Color3.new(1, 1, 1), 1.5, back).Transparency = 0.75
	UIUtil.label({
		Parent = stage, Text = "CHOOSE A MAP", Font = Theme.Font.Title, TextSize = 38,
		Position = UDim2.fromOffset(132, -4), Size = UDim2.fromOffset(600, 42),
	})
	rulesLabel = UIUtil.label({
		Parent = stage, Font = Theme.Font.Bold, TextSize = 14, TextColor3 = Theme.Color.TextMuted, Text = "",
		Position = UDim2.fromOffset(134, 36), Size = UDim2.fromOffset(600, 18),
	})
	-- Mode vote pills (top right)
	local modeRow = UIUtil.make("Frame", {
		Parent = stage, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromOffset(W, 2), Size = UDim2.fromOffset(470, 40), BackgroundTransparency = 1,
	})
	UIUtil.listLayout(modeRow, 6, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Right
	for i, m in ipairs(Modes.List) do
		local b = UIUtil.make("TextButton", {
			Parent = modeRow, LayoutOrder = i, Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X,
			Text = string.upper(m.Name), Font = Theme.Font.Title, TextSize = 13, AutoButtonColor = true, BorderSizePixel = 0,
		}) :: TextButton
		UIUtil.corner(UDim.new(1, 0), b)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.PaddingRight = UDim.new(0, 12)
		pad.Parent = b
		b.MouseButton1Click:Connect(function()
			chooseMode(m.Id)
		end)
		modeButtons[m.Id] = b
	end

	local row = UIUtil.make("Frame", {
		Parent = stage, Position = UDim2.fromOffset(0, 72), Size = UDim2.fromOffset(W, CARD_H), BackgroundTransparency = 1,
	})
	for i, map in ipairs(MAPS) do
		buildCard(row, map, i)
	end

	statusMain = UIUtil.label({
		Parent = stage, Font = Theme.Font.Heading, TextSize = 20, Text = "",
		Position = UDim2.fromOffset(4, H - 62), Size = UDim2.fromOffset(700, 26),
	})
	statusSub = UIUtil.label({
		Parent = stage, Font = Theme.Font.Body, TextSize = 14, TextColor3 = Theme.Color.TextDim, Text = "",
		Position = UDim2.fromOffset(4, H - 32), Size = UDim2.fromOffset(700, 20),
	})
	playButton = UIUtil.make("TextButton", {
		Parent = stage, AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromOffset(W, H + 4),
		Size = UDim2.fromOffset(250, 68), BackgroundColor3 = Theme.Color.Play, Text = "PLAY", AutoButtonColor = false,
		TextColor3 = Color3.fromRGB(8, 46, 30), Font = Theme.Font.Title, TextSize = 36, BorderSizePixel = 0,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 16), playButton)
	playStroke = UIUtil.stroke(Color3.fromRGB(198, 255, 150), 3, playButton)
	local playScale = Instance.new("UIScale")
	playScale.Parent = playButton
	playButton.MouseButton1Down:Connect(function()
		playScale.Scale = 0.95
	end)
	playButton.MouseButton1Up:Connect(function()
		playScale.Scale = 1
	end)
	playButton.MouseLeave:Connect(function()
		playScale.Scale = 1
	end)
	playButton.MouseButton1Click:Connect(sendVote)
	paintModes()

	local camera = Workspace.CurrentCamera
	local function relayout()
		local vp = camera.ViewportSize
		stageScale.Scale = math.min((vp.X - 32) / W, (vp.Y - UIUtil.topInset() - 24) / (H + 20))
	end
	relayout()
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(relayout)

	ClientState.MatchChanged:Connect(function(m)
		if m.phase ~= "Intermission" and m.phase ~= "Countdown" then
			queued = false
		end
		if root.Visible then
			refreshCards()
			refreshStatus()
		end
	end)
	refreshCards()
	refreshStatus()
end

function MapSelect.Open()
	if not root then
		return
	end
	root.Visible = true
	refreshCards()
	refreshStatus()
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
