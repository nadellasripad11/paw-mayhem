--!strict
-- maptile: the big picture tiles of the vote screens (maps, gamemodes),
-- styled like rivals: a picture filling the tile (a map in 3d from the
-- server's snapshots, or a plain colour), and along the bottom a dark band
-- with diagonal stripes and the name in the middle. a random tile shows a
-- shuffle sign instead.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local UIUtil = require(script.Parent.UIUtil)

local MapTile = {}

export type Tile = { button: TextButton, setPicked: (boolean) -> (), setVotes: (number) -> () }

-- a map from the snapshots, seen from above, filling \`parent\`.
function MapTile.Shot(parent: GuiObject, mapId: string, sky: Color3, turn: number?)
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
		local model = src:Clone()
		model.Parent = vf
		local bbCf, bbSize = model:GetBoundingBox()
		local focus = src:GetAttribute("FocusCenter")
		local span = src:GetAttribute("FocusSize")
		local center = typeof(focus) == "Vector3" and focus or bbCf.Position
		local size = typeof(span) == "Vector3" and span or bbSize
		local cam = Instance.new("Camera")
		cam.FieldOfView = 40
		local t = turn or 0.8
		local dist = math.max(size.X, size.Z) * 0.45
		cam.CFrame = CFrame.lookAt(center + Vector3.new(math.cos(t) * 0.7, 0.5, math.sin(t) * 0.7) * dist, center)
		cam.Parent = vf
		vf.CurrentCamera = cam
	end)
end

-- the shuffle sign for random: two crossing arrows made of bars.
local function shuffle(parent: Instance)
	local h = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromScale(0.34, 0.4),
		BackgroundTransparency = 1, ZIndex = 5,
	})
	local ar = Instance.new("UIAspectRatioConstraint")
	ar.AspectRatio = 1.25
	ar.Parent = h
	for _, r in ipairs({ 30, -30 }) do
		local bar = UIUtil.make("Frame", {
			Parent = h, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.45, 0.5), Size = UDim2.fromScale(0.85, 0.16),
			Rotation = r, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5,
		})
		UIUtil.corner(UDim.new(1, 0), bar)
	end
	for _, y in ipairs({ 0.2, 0.8 }) do
		local head = UIUtil.make("Frame", {
			Parent = h, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.9, y), Size = UDim2.fromScale(0.26, 0.32),
			Rotation = 45, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 5,
		})
		UIUtil.corner(UDim.new(0, 3), head)
	end
end

-- \`art\`: a map id to show in 3d, "random" for the shuffle sign, or nil for
-- just \`color\`. \`stripe\` colours the band's stripes.
function MapTile.New(parent: Instance, name: string, art: string?, color: Color3, stripe: Color3, onClick: () -> ()): Tile
	local b = UIUtil.make("TextButton", {
		Parent = parent, Name = name, Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		BackgroundColor3 = color, ClipsDescendants = true, ZIndex = 2,
	}) :: TextButton
	if art == "Random" then
		b.BackgroundColor3 = Color3.fromRGB(26, 26, 30)
		shuffle(b)
	elseif art then
		MapTile.Shot(b, art, color, #name * 0.7)
	else
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.45))
		g.Rotation = 90
		g.Parent = b
	end
	-- the band: dark, with diagonal stripes, the name in the middle.
	local band = UIUtil.make("Frame", {
		Parent = b, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.22),
		BackgroundColor3 = Color3.fromRGB(14, 16, 14), BackgroundTransparency = 0.15, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = 4,
	})
	for k = 0, 24 do
		UIUtil.make("Frame", {
			Parent = band, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(k / 24, 0.5), Size = UDim2.new(0, 10, 2.4, 0),
			Rotation = 35, BackgroundColor3 = stripe, BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 4,
		})
	end
	local label = UIUtil.label({
		Parent = band, Text = name, Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.9, 0.72), ZIndex = 6,
	})
	local ls = Instance.new("UIStroke")
	ls.Thickness = 2
	ls.Color = Color3.fromRGB(10, 10, 12)
	ls.Parent = label
	-- edge (green normally, gold when it's your pick), votes in the corner.
	local edge = UIUtil.stroke(stripe, 3, b)
	edge.Transparency = 0.35
	local votes = UIUtil.label({
		Parent = b, Text = "", Font = Theme.Font.Title, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(40, 30), Visible = false,
		BackgroundTransparency = 0.1, BackgroundColor3 = Color3.fromRGB(12, 14, 12), ZIndex = 7,
	})
	UIUtil.corner(UDim.new(0, 8), votes)
	local picked = false
	b.MouseEnter:Connect(function()
		edge.Transparency = 0
	end)
	b.MouseLeave:Connect(function()
		edge.Transparency = picked and 0 or 0.35
	end)
	b.MouseButton1Click:Connect(onClick)
	return {
		button = b,
		setPicked = function(on: boolean)
			picked = on
			edge.Color = on and Color3.fromRGB(255, 210, 70) or stripe
			edge.Thickness = on and 5 or 3
			edge.Transparency = on and 0 or 0.35
		end,
		setVotes = function(n: number)
			votes.Visible = n > 0
			votes.Text = tostring(n)
		end,
	}
end

-- lay \`tiles\` out like the reference: the first three big across the top,
-- the rest four to a row underneath (inside \`grid\`, which fills its parent).
function MapTile.Layout(tiles: { Tile })
	local gap = 0.008
	local topH, rowH = 0.42, 0.27
	for i, t in ipairs(tiles) do
		local b = t.button
		if i <= 3 then
			local w = (1 - gap * 2) / 3
			b.Position = UDim2.fromScale((i - 1) * (w + gap), 0)
			b.Size = UDim2.fromScale(w, topH)
		else
			local k = i - 4
			local w = (1 - gap * 3) / 4
			b.Position = UDim2.fromScale((k % 4) * (w + gap), topH + gap * 2 + (k // 4) * (rowH + gap * 2))
			b.Size = UDim2.fromScale(w, rowH)
		end
	end
end

return MapTile
