--!strict
-- Celebrate: the big moments, animated.
--   Celebrate.LevelUp(level)              - LEVEL UP! burst: rays, the new level
--                                            number slamming in, sparkles
--   Celebrate.CoinFly(from, to, amount)   - coins arc from a button into the
--                                            coin counter, which bumps on arrival
--   Celebrate.Versus(left, right, map)    - duel intro: your side and theirs
--                                            slide in, VS slams down, the map
--                                            name, then FIGHT!
-- (Its own ScreenGui on top of everything; nothing here blocks clicks.)

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local UIUtil = require(script.Parent.UIUtil)
local Icons = require(script.Parent.Icons)

local Celebrate = {}
local player = Players.LocalPlayer
local gui: ScreenGui? = nil

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 208, 80)
local BLUE = Color3.fromRGB(64, 156, 255)
local RED = Color3.fromRGB(255, 84, 100)

local function layer(): Frame
	local g = gui :: ScreenGui
	local f = UIUtil.make("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Active = false }) :: Frame
	f:SetAttribute("NoPolish", true)
	return f
end

local function tween(o: Instance, t: number, p: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), p)
	tw:Play()
	return tw
end

local function fit(f: GuiObject)
	local s = Instance.new("UIScale")
	s.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.Y / 760, 0.55, 1.2)
	s.Parent = f
end

-- ── LEVEL UP ─────────────────────────────────────────────────────────────────
function Celebrate.LevelUp(level: number)
	if not gui then
		return
	end
	local root = layer()
	local box = UIUtil.make("Frame", { Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(600, 300), BackgroundTransparency = 1 }) :: Frame
	fit(box)
	-- rays
	local rays = UIUtil.make("Frame", { Parent = box, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, 520), BackgroundTransparency = 1 }) :: Frame
	local rs = Instance.new("UIScale")
	rs.Scale = 0
	rs.Parent = rays
	for i = 0, 7 do
		local r = UIUtil.make("Frame", { Parent = rays, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 40, 1, 0), Rotation = i * 22.5, BackgroundColor3 = GOLD, BorderSizePixel = 0 })
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = r
	end
	tween(rs, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	local spin = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 25
	end)
	-- the words
	local title = UIUtil.label({
		Parent = box, Text = "LEVEL UP!", Font = Theme.Font.Title, TextSize = 64, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromOffset(600, 70), TextColor3 = WHITE,
	})
	UIUtil.stroke(Color3.fromRGB(90, 50, 0), 4, title)
	UIUtil.gradient(Color3.fromRGB(255, 244, 190), GOLD, 90, title)
	local ts = Instance.new("UIScale")
	ts.Scale = 2.4
	ts.Parent = title
	tween(ts, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	local badge = UIUtil.make("Frame", { Parent = box, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.66), Size = UDim2.fromOffset(110, 110), BackgroundColor3 = BLUE, BorderSizePixel = 0 }) :: Frame
	UIUtil.corner(UDim.new(1, 0), badge)
	UIUtil.stroke(WHITE, 4, badge)
	UIUtil.gradient(Color3.fromRGB(150, 200, 255), Color3.fromRGB(40, 100, 210), 90, badge)
	local num = UIUtil.label({ Parent = badge, Text = tostring(level), Font = Theme.Font.Title, TextSize = 56, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), TextColor3 = WHITE })
	UIUtil.stroke(Color3.fromRGB(10, 40, 100), 3, num)
	local bs = Instance.new("UIScale")
	bs.Scale = 0
	bs.Parent = badge
	task.delay(0.25, function()
		tween(bs, 0.5, { Scale = 1 }, Enum.EasingStyle.Elastic)
	end)
	-- sparkles bursting out
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local sp = UIUtil.make("Frame", { Parent = box, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(18, 18), BackgroundTransparency = 1 }) :: Frame
		Icons.Place("Sparkle", sp, 18, i % 2 == 0 and GOLD or WHITE)
		tween(sp, 0.9, { Position = UDim2.new(0.5, math.cos(a) * 220, 0.6, math.sin(a) * 150), Rotation = 180 })
	end
	task.delay(2.4, function()
		tween(box, 0.35, { Position = UDim2.fromScale(0.5, 0.2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(rs, 0.35, { Scale = 0 })
		tween(ts, 0.35, { Scale = 0.2 })
		tween(bs, 0.35, { Scale = 0 })
		task.wait(0.4)
		spin:Disconnect()
		root:Destroy()
	end)
end

-- ── coins flying into the counter ────────────────────────────────────────────
function Celebrate.CoinFly(from: Vector2, to: GuiObject?, amount: number?)
	if not gui or not to then
		return
	end
	local root = layer()
	local n = math.clamp(math.floor((amount or 50) / 25), 5, 12)
	local target = to.AbsolutePosition + to.AbsoluteSize / 2 + Vector2.new(0, (gui :: ScreenGui).IgnoreGuiInset and 0 or 0)
	for i = 1, n do
		local c = UIUtil.make("Frame", { Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(from.X, from.Y), Size = UDim2.fromOffset(26, 26), BackgroundTransparency = 1 }) :: Frame
		Icons.Place("Coin", c, 26, Theme.Color.Coin)
		-- burst out a little, then arc into the counter
		local out = from + Vector2.new(math.random(-70, 70), math.random(-80, -20))
		task.delay((i - 1) * 0.045, function()
			tween(c, 0.25, { Position = UDim2.fromOffset(out.X, out.Y) }, Enum.EasingStyle.Quad).Completed:Wait()
			tween(c, 0.45, { Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(16, 16) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
			c:Destroy()
			-- the counter bumps as each coin lands
			local sc = to:FindFirstChild("CoinBump") :: UIScale?
			if not sc then
				sc = Instance.new("UIScale")
				sc.Name = "CoinBump"
				sc.Parent = to
			end
			(sc :: UIScale).Scale = 1.15
			tween(sc :: UIScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
	end
	task.delay(n * 0.045 + 1, function()
		root:Destroy()
	end)
end

-- ── duel intro: VS ───────────────────────────────────────────────────────────
-- left / right: { { name, userId } } (your side is on the left).
local function side(parent: Instance, people: { any }, color: Color3, dir: number, title: string): Frame
	local f = UIUtil.make("Frame", {
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, dir * 1100, 0.5, 0), Size = UDim2.fromOffset(420, 260),
		BackgroundColor3 = color, BorderSizePixel = 0, Rotation = dir * -3,
	}) :: Frame
	UIUtil.corner(UDim.new(0, 24), f)
	UIUtil.gradient(color:Lerp(WHITE, 0.25), color:Lerp(Color3.new(0, 0, 0), 0.35), 90, f)
	UIUtil.stroke(color:Lerp(WHITE, 0.6), 4, f)
	UIUtil.label({ Parent = f, Text = title, Font = Theme.Font.Title, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 30), TextColor3 = WHITE, TextStrokeTransparency = 0.3 })
	local n = math.max(1, math.min(#people, 5))
	local w = math.min(110, 400 / n)
	for i = 1, n do
		local p = people[i] or { name = "?", userId = 0 }
		local x = (i - (n + 1) / 2) * w
		local ring = UIUtil.make("Frame", { Parent = f, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, x, 0.52, 0), Size = UDim2.fromOffset(w - 16, w - 16), BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.4), BorderSizePixel = 0 }) :: Frame
		UIUtil.corner(UDim.new(1, 0), ring)
		UIUtil.stroke(WHITE, 3, ring)
		local uid = tonumber(p.userId) or 0
		if uid > 0 then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", uid)
			img.Parent = ring
			UIUtil.corner(UDim.new(1, 0), img)
		else
			UIUtil.label({ Parent = ring, Text = "BOT", Font = Theme.Font.Title, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
		end
		UIUtil.label({ Parent = f, Text = tostring(p.name), Font = Theme.Font.Title, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, x, 0.52, w / 2), Size = UDim2.fromOffset(w + 10, 22), TextColor3 = WHITE, TextStrokeTransparency = 0.3, TextTruncate = Enum.TextTruncate.AtEnd })
	end
	return f
end

function Celebrate.Versus(left: { any }, right: { any }, map: string?)
	if not gui then
		return
	end
	local root = layer()
	local dim = UIUtil.make("Frame", { Parent = root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 8, 20), BackgroundTransparency = 1, BorderSizePixel = 0 }) :: Frame
	tween(dim, 0.25, { BackgroundTransparency = 0.35 })
	local stage = UIUtil.make("Frame", { Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(1100, 400), BackgroundTransparency = 1 }) :: Frame
	fit(stage)
	local l = side(stage, left, BLUE, -1, "YOU")
	local r = side(stage, right, RED, 1, "THEM")
	tween(l, 0.4, { Position = UDim2.new(0.5, -250, 0.5, 0) }, Enum.EasingStyle.Back)
	tween(r, 0.4, { Position = UDim2.new(0.5, 250, 0.5, 0) }, Enum.EasingStyle.Back)
	local vs = UIUtil.label({
		Parent = stage, Text = "VS", Font = Theme.Font.Title, TextSize = 110, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(220, 130), TextColor3 = GOLD, TextTransparency = 1, ZIndex = 5,
	})
	UIUtil.stroke(Color3.fromRGB(60, 30, 0), 6, vs)
	local vsScale = Instance.new("UIScale")
	vsScale.Scale = 3
	vsScale.Parent = vs
	task.delay(0.35, function()
		tween(vs, 0.2, { TextTransparency = 0 })
		tween(vsScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		-- the slam jolts both sides
		task.delay(0.25, function()
			stage.Position = UDim2.new(0.5, 0, 0.45, 8)
			tween(stage, 0.3, { Position = UDim2.fromScale(0.5, 0.45) }, Enum.EasingStyle.Elastic)
		end)
	end)
	local mapLabel = UIUtil.label({
		Parent = stage, Text = string.upper(map or "DUEL"), Font = Theme.Font.Title, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 10), Size = UDim2.fromOffset(700, 36), TextColor3 = WHITE, TextTransparency = 1, TextStrokeTransparency = 1,
	})
	task.delay(0.7, function()
		tween(mapLabel, 0.3, { TextTransparency = 0, TextStrokeTransparency = 0.3 })
	end)
	-- out: the sides fly apart, then FIGHT!
	task.delay(1.9, function()
		tween(l, 0.3, { Position = UDim2.new(0.5, -1100, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(r, 0.3, { Position = UDim2.new(0.5, 1100, 0.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		tween(vsScale, 0.25, { Scale = 0 })
		tween(mapLabel, 0.2, { TextTransparency = 1, TextStrokeTransparency = 1 })
		tween(dim, 0.3, { BackgroundTransparency = 1 })
		task.wait(0.3)
		local fight = UIUtil.label({
			Parent = root, Text = "FIGHT!", Font = Theme.Font.Title, TextSize = 120, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(700, 140), TextColor3 = Theme.Color.Warn,
		})
		fit(fight)
		UIUtil.stroke(Color3.fromRGB(60, 20, 0), 6, fight)
		local fs = fight:FindFirstChildOfClass("UIScale") :: UIScale
		fs.Scale = fs.Scale * 2.2
		tween(fs, 0.3, { Scale = fs.Scale / 2.2 }, Enum.EasingStyle.Back)
		task.wait(0.8)
		tween(fight, 0.3, { TextTransparency = 1, Position = UDim2.fromScale(0.5, 0.36) })
		task.wait(0.35)
		root:Destroy()
	end)
end

function Celebrate.Build()
	gui = UIUtil.make("ScreenGui", {
		Name = "PawCelebrate", Parent = player:WaitForChild("PlayerGui"),
		IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 40,
	}) :: ScreenGui
	-- level ups come as a notice from the server
	require(game:GetService("ReplicatedStorage").Shared.Net.Remotes).Get("Notify").OnClientEvent:Connect(function(data)
		if typeof(data) == "table" and data.kind == "level" then
			local lv = tonumber(string.match(tostring(data.text), "(%d+)%s*$"))
			if lv then
				Celebrate.LevelUp(lv)
			end
		end
	end)
end

return Celebrate
