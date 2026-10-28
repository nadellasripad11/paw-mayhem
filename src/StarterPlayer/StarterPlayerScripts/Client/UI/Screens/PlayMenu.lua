--!strict
-- playmenu: the play screen, laid out like rivals. top left: 1v1, 2v2, 3v3,
-- then 4v4 and 5v5 (pick one and you start searching; bots fill in after 15
-- seconds). top right: ranked (locked until level 50). below: the arena
-- match everyone in the server plays, and under it every arena gamemode to
-- jump straight in with. each tile shows a real map in 3d behind its name.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Modes = require(ReplicatedStorage.Shared.Config.Modes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local ClientState = require(script.Parent.Parent.Parent.ClientState)

local PlayMenu = {}

local player = Players.LocalPlayer
local gui: ScreenGui? = nil
local onArena: (() -> ())? = nil
local refreshRanked: (() -> ())? = nil

local RANKED_LEVEL = 50
local W = 1 -- (the layout is in units of the content's width)
local TOTAL_H = 0.745

local function close()
	if gui then
		gui.Enabled = false
	end
end

function PlayMenu.IsOpen(): boolean
	return gui ~= nil and gui.Enabled
end

function PlayMenu.Open(arena: () -> ())
	onArena = arena
	if refreshRanked then
		refreshRanked()
	end
	if gui then
		gui.Enabled = true
	end
end

-- a map from the server's snapshots, seen from above, filling \`parent\`.
local function mapShot(parent: GuiObject, mapId: string, sky: Color3, turn: number)
	task.spawn(function()
		local folder = ReplicatedStorage:WaitForChild("MapPreviews", 30)
		local src = folder and folder:WaitForChild(mapId, 10)
		if not src or not parent.Parent then
			return
		end
		local vf = Instance.new("ViewportFrame")
		vf.Size = UDim2.fromScale(1, 1)
		vf.BackgroundColor3 = sky
		vf.Ambient = Color3.fromRGB(215, 215, 225)
		vf.LightColor = Color3.fromRGB(255, 250, 238)
		vf.LightDirection = Vector3.new(-0.35, -1, 0.45)
		vf.ZIndex = 3
		vf.Parent = parent
		UIUtil.corner(UDim.new(0, 10), vf)
		local model = src:Clone()
		model.Parent = vf
		local bbCf, bbSize = model:GetBoundingBox()
		local focus = src:GetAttribute("FocusCenter")
		local span = src:GetAttribute("FocusSize")
		local center = typeof(focus) == "Vector3" and focus or bbCf.Position
		local size = typeof(span) == "Vector3" and span or bbSize
		local cam = Instance.new("Camera")
		cam.FieldOfView = 40
		local dist = math.max(size.X, size.Z) * 0.42
		local dir = Vector3.new(math.cos(turn) * 0.7, 0.55, math.sin(turn) * 0.7)
		cam.CFrame = CFrame.lookAt(center + dir * dist, center)
		cam.Parent = vf
		vf.CurrentCamera = cam
	end)
end

-- a tile: a 3d map behind, a dark fade, a big outlined title (+ a line under).
local function tile(parent: Instance, name: string, pos: UDim2, size: UDim2, mapId: string, turn: number, tint: Color3, title: string, sub: string?, titleScale: number?): TextButton
	local b = UIUtil.make("TextButton", {
		Parent = parent, Name = name, Text = "", AutoButtonColor = false, BorderSizePixel = 0, Position = pos, Size = size,
		BackgroundColor3 = tint, ClipsDescendants = true, ZIndex = 2,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 10), b)
	mapShot(b, mapId, tint, turn)
	local shade = UIUtil.make("Frame", { Parent = b, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 4 })
	UIUtil.corner(UDim.new(0, 10), shade)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(tint, Color3.new(0, 0, 0))
	g.Transparency = NumberSequence.new(0.3, 0.6)
	g.Rotation = 90
	g.Parent = shade
	local t = UIUtil.label({
		Parent = b, Name = "Title", Text = title, Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, sub and 0.42 or 0.5), Size = UDim2.fromScale(0.86, titleScale or 0.42), ZIndex = 6,
	})
	local st = Instance.new("UIStroke")
	st.Thickness = 3
	st.Color = Color3.fromRGB(20, 20, 26)
	st.Parent = t
	if sub then
		UIUtil.label({
			Parent = b, Text = sub, Font = Theme.Font.Bold, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.68), Size = UDim2.fromScale(0.8, 0.15),
			TextColor3 = Color3.fromRGB(230, 230, 236), ZIndex = 6,
		})
	end
	local ring = UIUtil.stroke(Color3.new(1, 1, 1), 2, b)
	ring.Transparency = 0.75
	b.MouseEnter:Connect(function()
		ring.Transparency = 0
	end)
	b.MouseLeave:Connect(function()
		ring.Transparency = 0.75
	end)
	return b
end

-- a padlock drawn from shapes (fonts don't all have the symbol).
local function padlock(parent: Instance, pos: UDim2, size: UDim2)
	local holder = UIUtil.make("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size, BackgroundTransparency = 1, ZIndex = 6 })
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 0.85
	ar.Parent = holder
	local shackle = UIUtil.make("Frame", {
		Parent = holder, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.62, 0.62),
		BackgroundTransparency = 1, ZIndex = 6,
	})
	UIUtil.corner(UDim.new(1, 0), shackle)
	local s = Instance.new("UIStroke")
	s.Thickness = 9
	s.Color = Color3.new(1, 1, 1)
	s.Parent = shackle
	local body = UIUtil.make("Frame", {
		Parent = holder, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(1, 0.58),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 7,
	})
	UIUtil.corner(UDim.new(0.18, 0), body)
	local hole = UIUtil.make("Frame", {
		Parent = body, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromScale(0.2, 0.32),
		BackgroundColor3 = Color3.fromRGB(20, 22, 30), BorderSizePixel = 0, ZIndex = 8,
	})
	UIUtil.corner(UDim.new(1, 0), hole)
end

-- a red close button with an x made of two bars (to the right of the tiles).
local function closeButton(parent: Instance)
	local x = UIUtil.make("TextButton", {
		Parent = parent, Text = "", Position = UDim2.new(1, 18, 0, 0), Size = UDim2.fromOffset(84, 46),
		BackgroundColor3 = Color3.fromRGB(230, 50, 60), BorderSizePixel = 0, AutoButtonColor = true, ZIndex = 5,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 8), x)
	UIUtil.stroke(Color3.fromRGB(140, 20, 30), 3, x)
	for _, r in ipairs({ 45, -45 }) do
		local bar = UIUtil.make("Frame", {
			Parent = x, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(30, 8),
			Rotation = r, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6,
		})
		UIUtil.corner(UDim.new(1, 0), bar)
	end
	x.MouseButton1Click:Connect(close)
end

function PlayMenu.Build()
	local g = UIUtil.make("ScreenGui", {
		Name = "PawPlayMenu", Parent = player:WaitForChild("PlayerGui"), IgnoreGuiInset = true, ResetOnSpawn = false,
		DisplayOrder = 8, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
	gui = g
	local bg = UIUtil.make("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.08, BorderSizePixel = 0 })
	UIUtil.gradient(Color3.fromRGB(40, 90, 40), Color3.fromRGB(12, 30, 14), 90, bg)

	-- the content keeps its shape and fits the screen.
	local box = UIUtil.make("Frame", {
		Parent = g, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.47, 0.52), Size = UDim2.fromScale(0.74, 0.86),
		BackgroundTransparency = 1,
	})
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = W / TOTAL_H
	ar.Parent = box
	closeButton(box)
	local function at(x: number, y: number): UDim2
		return UDim2.fromScale(x / W, y / TOTAL_H)
	end
	local function sz(w: number, h: number): UDim2
		return UDim2.fromScale(w / W, h / TOTAL_H)
	end
	local function join(kind: string)
		close()
		Remotes.Get("DuelQueue"):FireServer({ join = kind })
	end

	-- duels: three across, then two across.
	local gap = 0.006
	local leftW = 0.745
	local row1W = (leftW - gap * 2) / 3
	local row2W = (leftW - gap) / 2
	local DUELS = {
		{ "1v1", 0, 0, row1W, "SkyIslands", 0.4, Color3.fromRGB(160, 50, 70) },
		{ "2v2", row1W + gap, 0, row1W, "Volcano", 1.4, Color3.fromRGB(170, 80, 40) },
		{ "3v3", (row1W + gap) * 2, 0, row1W, "Toybox", 2.4, Color3.fromRGB(150, 60, 140) },
		{ "4v4", 0, 0.172, row2W, "Rooftops", 3.4, Color3.fromRGB(60, 80, 170) },
		{ "5v5", row2W + gap, 0.172, row2W, "SkyIslands", 4.4, Color3.fromRGB(110, 50, 170) },
	}
	for _, d in ipairs(DUELS) do
		local kind = d[1] :: string
		local b = tile(box, kind, at(d[2] :: number, d[3] :: number), sz(d[4] :: number, d[3] == 0 and 0.166 or 0.188), d[5] :: string, d[6] :: number, d[7] :: Color3, kind, nil, 0.5)
		b.MouseButton1Click:Connect(function()
			join(kind)
		end)
	end

	-- ranked: tall on the right, locked until level 50.
	local ranked = tile(box, "Ranked", at(leftW + gap * 1.5, 0), sz(W - leftW - gap * 1.5, 0.36), "Volcano", 5.2, Color3.fromRGB(30, 30, 40), "Ranked", nil, 0.16)
	local rankedTitle = ranked:FindFirstChild("Title") :: TextLabel
	rankedTitle.Position = UDim2.fromScale(0.5, 0.11)
	local lockHolder = UIUtil.make("Frame", { Parent = ranked, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6 })
	padlock(lockHolder, UDim2.fromScale(0.5, 0.47), UDim2.fromScale(0.42, 0.34))
	UIUtil.label({
		Parent = lockHolder, Text = "Unlocked at\nLevel " .. RANKED_LEVEL, Font = Theme.Font.Title, TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.72),
		Size = UDim2.fromScale(0.8, 0.18), ZIndex = 7,
	})
	local rankedStroke = UIUtil.stroke(Color3.new(1, 1, 1), 4, ranked)
	local function rankedOpen(): boolean
		local lvl = ClientState.Profile and ClientState.Profile.Level or 1
		return lvl >= RANKED_LEVEL
	end
	refreshRanked = function()
		lockHolder.Visible = not rankedOpen()
		rankedStroke.Transparency = rankedOpen() and 0.6 or 0
	end
	refreshRanked()
	ranked.MouseButton1Click:Connect(function()
		if rankedOpen() then
			join("1v1")
		end
	end)

	-- arena: a wide banner.
	local arena = tile(box, "Arena", at(0, 0.375), sz(W, 0.17), "SkyIslands", 0.9, Color3.fromRGB(40, 110, 70), "ARENA", "Everyone in the server  ·  vote the map", 0.5)
	arena.MouseButton1Click:Connect(function()
		close()
		if onArena then
			onArena()
		end
	end)

	-- the arena's gamemodes: pick one and jump in.
	local header = UIUtil.make("Frame", {
		Parent = box, Position = at(0, 0.555), Size = sz(W, 0.038), BackgroundColor3 = Color3.fromRGB(14, 20, 16),
		BackgroundTransparency = 0.25, BorderSizePixel = 0, ZIndex = 2,
	})
	UIUtil.corner(UDim.new(0, 8), header)
	UIUtil.label({
		Parent = header, Text = "Pick a gamemode and jump into the arena", Font = Theme.Font.Bold, TextScaled = true,
		Position = UDim2.fromScale(0.02, 0.15), Size = UDim2.fromScale(0.9, 0.7), ZIndex = 3,
	})
	local n = #Modes.List
	local modeW = (W - gap * (n - 1)) / n
	local maps = { "SkyIslands", "Volcano", "Toybox", "Rooftops" }
	for i, m in ipairs(Modes.List) do
		local b = tile(box, "Mode" .. m.Id, at((i - 1) * (modeW + gap), 0.6), sz(modeW, 0.145), maps[(i - 1) % #maps + 1], i * 1.3,
			m.Color:Lerp(Color3.new(0, 0, 0), 0.35), string.upper(m.Pill or m.Name), m.Rules, 0.3)
		b.MouseButton1Click:Connect(function()
			close()
			local current = ClientState.Match and ClientState.Match.mapId
			Remotes.Get("RequestJoinMatch"):FireServer({ mapId = typeof(current) == "string" and current or "SkyIslands", modeId = m.Id })
		end)
	end
end

return PlayMenu
