--!strict
-- endscreen: the end-of-match / end-of-duel cinematic.
--   1. final score: the screen dims, both team plates slam in from the sides
--      and their numbers count up; the winning side grows and glows.
--   2. the winner: the score slides up out of the way, slow-turning light rays
--      open behind, victory / defeat / draw drops in letter by letter with a
--      bounce and a shine sweeping across, the winners' avatars pop in (a
--      crown on the first), confetti cannons fire from the bottom corners and
--      confetti rains down (on a win).
--   3. settle: the title shrinks into a slim banner at the top so the podium
--      / arena behind stays in view; \`onsettled\` lets the caller add the
--      scoreboard and round summary.
-- endscreen.play(opts, onsettled?) / endscreen.hide()
--   opts = { score = { blue = n, red = n }, won = bool, draw = bool,
--            winnerteam = "blue" | "red" | nil, winners = { { name, userid } },
--            subtitle = string?, ffa = bool? }

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)

local EndScreen = {}
local player = Players.LocalPlayer

local BLUE = Color3.fromRGB(64, 156, 255)
local RED = Color3.fromRGB(255, 84, 100)
local GOLD = Color3.fromRGB(255, 208, 80)
local WHITE = Color3.new(1, 1, 1)
local CONFETTI = {
	Color3.fromRGB(255, 205, 90), Color3.fromRGB(96, 210, 120), Color3.fromRGB(150, 110, 255),
	Color3.fromRGB(64, 156, 255), Color3.fromRGB(255, 110, 170), Color3.fromRGB(255, 255, 255),
}

local gui: ScreenGui? = nil
local token = 0
local spinConn: RBXScriptConnection? = nil

local function tween(obj: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local function frame(props: { [string]: any }): Frame
	local f = UIUtil.make("Frame", props) :: Frame
	f.BorderSizePixel = 0
	return f
end

local function clear()
	token += 1
	if spinConn then
		spinConn:Disconnect()
		spinConn = nil
	end
	if gui then
		gui:ClearAllChildren()
		gui.Enabled = false
	end
end

function EndScreen.Hide()
	clear()
end

function EndScreen.IsShowing(): boolean
	return gui ~= nil and gui.Enabled
end

-- ── pieces ───────────────────────────────────────────────────────────────────
-- a team plate: its colour, its name and a big number that counts up.
local function teamPlate(parent: Instance, color: Color3, name: string, side: number): (Frame, TextLabel, UIScale, UIStroke)
	local plate = frame({
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, side * 150, 0.5, 0),
		Size = UDim2.fromOffset(240, 150), BackgroundColor3 = color, ZIndex = 20,
	})
	UIUtil.corner(UDim.new(0, 22), plate)
	UIUtil.gradient(color:Lerp(WHITE, 0.25), color:Lerp(Color3.new(0, 0, 0), 0.3), 90, plate)
	local stroke = UIUtil.stroke(color:Lerp(WHITE, 0.6), 3, plate)
	local scale = Instance.new("UIScale")
	scale.Parent = plate
	UIUtil.label({
		Parent = plate, Text = name, Font = Theme.Font.Title, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 10), Size = UDim2.new(1, 0, 0, 26), TextColor3 = WHITE, TextStrokeTransparency = 0.4, ZIndex = 21,
	})
	local num = UIUtil.label({
		Parent = plate, Text = "0", Font = Theme.Font.Title, TextSize = 92, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 104), TextColor3 = WHITE, ZIndex = 21,
	})
	UIUtil.stroke(color:Lerp(Color3.new(0, 0, 0), 0.6), 3, num)
	return plate, num, scale, stroke
end

-- slow-turning light rays behind the title.
local function sunburst(parent: Instance, color: Color3): (Frame, UIScale)
	local holder = frame({
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(900, 900),
		BackgroundTransparency = 1, ZIndex = 10,
	})
	local scale = Instance.new("UIScale")
	scale.Scale = 0
	scale.Parent = holder
	-- (ui turns round each frame's own centre, so every ray is a bar right
	-- through the middle: 9 bars make 18 rays)
	for i = 0, 8 do
		local ray = frame({
			Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 54, 1, 0),
			Rotation = i * 20, BackgroundColor3 = color, ZIndex = 10,
		})
		local g = Instance.new("UIGradient")
		g.Rotation = 90
		g.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.55), NumberSequenceKeypoint.new(1, 1),
		})
		g.Parent = ray
	end
	-- a soft glow in the middle
	local glow = frame({
		Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(380, 380),
		BackgroundColor3 = color, ZIndex = 10,
	})
	UIUtil.corner(UDim.new(1, 0), glow)
	local gg = Instance.new("UIGradient")
	gg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	gg.Parent = glow
	return holder, scale
end

-- the title, one bouncing letter at a time, with a shine sweeping across.
local function dropTitle(parent: Instance, text: string, color: Color3, heavy: boolean, my: number): Frame
	local holder = frame({
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.4), Size = UDim2.fromOffset(#text * 74, 120),
		BackgroundTransparency = 1, ZIndex = 30,
	})
	local letters = {}
	for i = 1, #text do
		local ch = string.sub(text, i, i)
		local l = UIUtil.label({
			Parent = holder, Text = ch, Font = Theme.Font.Title, TextSize = 112, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, (i - 0.5) * 74, 0.5, -420), Size = UDim2.fromOffset(80, 120),
			TextColor3 = WHITE, TextTransparency = 1, Rotation = (i % 2 == 0 and 1 or -1) * math.random(18, 40), ZIndex = 31,
		})
		local stroke = UIUtil.stroke(color:Lerp(Color3.new(0, 0, 0), 0.65), 4, l)
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, color:Lerp(WHITE, 0.55)), ColorSequenceKeypoint.new(0.5, color), ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.25)),
		})
		g.Rotation = 90
		g.Parent = l
		letters[i] = { label = l, stroke = stroke }
		task.delay((i - 1) * 0.065, function()
			if my ~= token then
				return
			end
			tween(l, heavy and 0.45 or 0.55, { Position = UDim2.new(0, (i - 0.5) * 74, 0.5, 0), Rotation = 0, TextTransparency = 0 },
				heavy and Enum.EasingStyle.Bounce or Enum.EasingStyle.Back)
		end)
	end
	-- the shine: a white band sweeping across every letter at once
	task.delay(#text * 0.065 + 0.55, function()
		if my ~= token then
			return
		end
		-- a bright band sweeping across the title
		local band = frame({
			Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(-0.2, 0, 0.5, 0), Size = UDim2.new(0, 60, 1.3, 0),
			Rotation = 18, BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, ZIndex = 32,
		})
		local bg = Instance.new("UIGradient")
		bg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) })
		bg.Parent = band
		tween(band, 0.7, { Position = UDim2.new(1.2, 0, 0.5, 0) }, Enum.EasingStyle.Sine).Completed:Connect(function()
			band:Destroy()
		end)
	end)
	return holder
end

-- confetti: rain from the top and two cannons firing from the bottom corners.
local function confetti(parent: Instance, my: number)
	local layer = frame({ Parent = parent, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 40, ClipsDescendants = true })
	local function piece(x: number, y: number, vx: number, vy: number, life: number)
		local s = 8 + math.random() * 8
		local p = frame({
			Parent = layer, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, y), Size = UDim2.fromOffset(s, s * 1.7),
			Rotation = math.random(0, 360), BackgroundColor3 = CONFETTI[math.random(1, #CONFETTI)], ZIndex = 40,
		})
		local t0 = os.clock()
		local spin = (math.random() - 0.5) * 900
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - t0
			if t > life or my ~= token or not p.Parent then
				conn:Disconnect()
				p:Destroy()
				return
			end
			-- velocity in screen fractions per second, gravity pulls down
			local px = x + vx * t + math.sin(t * 6 + s) * 0.006
			local py = y + vy * t + 0.55 * t * t
			p.Position = UDim2.fromScale(px, py)
			p.Rotation += spin * (1 / 60)
			p.BackgroundTransparency = math.clamp((t - life + 0.6) / 0.6, 0, 1)
		end)
	end
	-- cannons
	for _, side in ipairs({ -1, 1 }) do
		for _ = 1, 45 do
			local x = side < 0 and 0.02 or 0.98
			piece(x, 1.02, -side * (0.12 + math.random() * 0.28), -(0.9 + math.random() * 0.55), 3.2)
		end
	end
	-- rain
	task.spawn(function()
		for k = 1, 70 do
			if my ~= token then
				return
			end
			piece(math.random(), -0.05, (math.random() - 0.5) * 0.06, 0.12 + math.random() * 0.15, 4.5)
			if k % 6 == 0 then
				task.wait(0.05)
			end
		end
	end)
	return layer
end

-- avatars of the winners popping in under the title.
local function winnerCards(parent: Instance, winners: { any }, color: Color3, my: number): Frame
	local n = math.min(#winners, 5)
	local row = frame({
		Parent = parent, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(n * 120, 150),
		BackgroundTransparency = 1, ZIndex = 30,
	})
	for i = 1, n do
		local w = winners[i]
		local card = frame({
			Parent = row, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0, (i - 0.5) * 120, 0, 0), Size = UDim2.fromOffset(104, 140),
			BackgroundTransparency = 1, ZIndex = 30,
		})
		local sc = Instance.new("UIScale")
		sc.Scale = 0
		sc.Parent = card
		local ring = frame({
			Parent = card, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 14), Size = UDim2.fromOffset(84, 84),
			BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.35), ZIndex = 31,
		})
		UIUtil.corner(UDim.new(1, 0), ring)
		UIUtil.stroke(color:Lerp(WHITE, 0.3), 4, ring)
		local uid = tonumber(w.userId) or 0
		if uid > 0 then
			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", uid)
			img.ZIndex = 32
			img.Parent = ring
			UIUtil.corner(UDim.new(1, 0), img)
		else
			UIUtil.label({ Parent = ring, Text = "BOT", Font = Theme.Font.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 32 })
		end
		if i == 1 then
			-- a gold crown: a band with three points on top
			local crown = frame({
				Parent = card, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 8), Size = UDim2.fromOffset(42, 30),
				BackgroundTransparency = 1, Rotation = -12, ZIndex = 33,
			})
			local band = frame({ Parent = crown, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 1), Size = UDim2.new(1, 0, 0.42, 0), BackgroundColor3 = GOLD, ZIndex = 34 })
			UIUtil.corner(UDim.new(0, 3), band)
			for _, x in ipairs({ 0.17, 0.5, 0.83 }) do
				local point = frame({
					Parent = crown, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, x == 0.5 and 0.42 or 0.5), Size = UDim2.fromOffset(13, 13),
					Rotation = 45, BackgroundColor3 = GOLD, ZIndex = 34,
				})
				UIUtil.corner(UDim.new(0, 2), point)
			end
			UIUtil.stroke(Color3.fromRGB(120, 70, 0), 2, band)
		end
		UIUtil.label({
			Parent = card, Text = tostring(w.name), Font = Theme.Font.Title, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(-10, 104), Size = UDim2.new(1, 20, 0, 22), TextColor3 = WHITE, TextStrokeTransparency = 0.3,
			TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 32,
		})
		task.delay((i - 1) * 0.12, function()
			if my == token then
				tween(sc, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
			end
		end)
	end
	return row
end

-- ── the show ─────────────────────────────────────────────────────────────────
function EndScreen.Play(opts: any, onSettled: (() -> ())?)
	if not gui then
		return
	end
	clear()
	local my = token
	local g = gui :: ScreenGui
	g.Enabled = true
	local stage = frame({ Parent = g, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local fit = Instance.new("UIScale")
	fit.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.Y / 760, 0.55, 1.2)
	-- (the stage is full screen; its children are laid out in pixels round
	-- the middle, so scale a centred holder instead)
	local center = frame({
		Parent = stage, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1200, 760),
		BackgroundTransparency = 1,
	})
	fit.Parent = center

	local won, draw = opts.won == true, opts.draw == true
	local accent = draw and Color3.fromRGB(200, 210, 230) or (won and GOLD or RED)

	-- 1. dim + the final score
	local dim = frame({ Parent = stage, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 8, 20), BackgroundTransparency = 1, ZIndex = 1 })
	local vg = Instance.new("UIGradient")
	vg.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	vg.Parent = dim
	tween(dim, 0.4, { BackgroundTransparency = 0.25 })

	local scoreGroup = frame({
		Parent = center, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(700, 260),
		BackgroundTransparency = 1, ZIndex = 20,
	})
	local scoreScale = Instance.new("UIScale")
	scoreScale.Parent = scoreGroup
	local caption = UIUtil.label({
		Parent = scoreGroup, Text = "FINAL SCORE", Font = Theme.Font.Title, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 30), TextColor3 = Theme.Color.TextDim, TextTransparency = 1, ZIndex = 21,
	})
	tween(caption, 0.4, { TextTransparency = 0 })
	local blueName = opts.blueName or (opts.ffa and "YOU" or "BLUE PAWS")
	local redName = opts.redName or (opts.ffa and "WINNER" or "RED CLAWS")
	local lPlate, lNum, lScale, lStroke = teamPlate(scoreGroup, BLUE, blueName, -1)
	local rPlate, rNum, rScale, rStroke = teamPlate(scoreGroup, RED, redName, 1)
	lPlate.Position = UDim2.new(0.5, -1100, 0.58, 0)
	rPlate.Position = UDim2.new(0.5, 1100, 0.58, 0)
	tween(lPlate, 0.5, { Position = UDim2.new(0.5, -150, 0.58, 0) }, Enum.EasingStyle.Back)
	tween(rPlate, 0.5, { Position = UDim2.new(0.5, 150, 0.58, 0) }, Enum.EasingStyle.Back)
	local dash = UIUtil.label({
		Parent = scoreGroup, Text = "-", Font = Theme.Font.Title, TextSize = 70, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromOffset(60, 80), TextColor3 = WHITE, TextTransparency = 1, ZIndex = 22,
	})
	tween(dash, 0.3, { TextTransparency = 0 })
	local score = opts.score or {}
	local bTarget, rTarget = tonumber(score.Blue) or 0, tonumber(score.Red) or 0
	-- count up, a little pop on every point
	local function countUp(num: TextLabel, sc: UIScale, target: number)
		task.spawn(function()
			task.wait(0.55)
			local steps = math.max(target, 1)
			local per = math.clamp(1.1 / steps, 0.04, 0.25)
			for v = 1, target do
				if my ~= token then
					return
				end
				num.Text = tostring(v)
				sc.Scale = 1.12
				tween(sc, per * 0.9, { Scale = 1 })
				task.wait(per)
			end
		end)
	end
	countUp(lNum, lScale, bTarget)
	countUp(rNum, rScale, rTarget)
	-- the winning side grows and glows, the other dims
	task.delay(1.85, function()
		if my ~= token then
			return
		end
		local winSide = opts.winnerTeam
		for _, s in ipairs({ { "Blue", lPlate, lScale, lStroke }, { "Red", rPlate, rScale, rStroke } }) do
			local plate: Frame, sc: UIScale, st: UIStroke = s[2], s[3], s[4]
			if winSide == s[1] then
				tween(sc, 0.35, { Scale = 1.16 }, Enum.EasingStyle.Back)
				st.Color = GOLD
				st.Thickness = 5
				tween(st, 0.6, { Thickness = 3 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			elseif winSide then
				tween(sc, 0.35, { Scale = 0.88 })
				tween(plate, 0.35, { BackgroundTransparency = 0.45 })
			end
		end
	end)

	-- 2. the winner
	task.delay(2.7, function()
		if my ~= token then
			return
		end
		-- the score slides up out of the way
		tween(scoreGroup, 0.5, { Position = UDim2.new(0.5, 0, 0, 92) }, Enum.EasingStyle.Quint)
		tween(scoreScale, 0.5, { Scale = 0.48 }, Enum.EasingStyle.Quint)
		tween(caption, 0.3, { TextTransparency = 1 })
		tween(dim, 0.6, { BackgroundTransparency = 0.5 })
		-- a soft flash (not blinding)
		local flash = frame({ Parent = stage, Size = UDim2.fromScale(1, 1), BackgroundColor3 = accent:Lerp(WHITE, 0.6), BackgroundTransparency = 0.75, ZIndex = 50 })
		tween(flash, 0.5, { BackgroundTransparency = 1 }).Completed:Connect(function()
			flash:Destroy()
		end)

		local rays, rayScale = sunburst(center, accent)
		tween(rayScale, 0.7, { Scale = 1 }, Enum.EasingStyle.Back)
		spinConn = RunService.RenderStepped:Connect(function(dt)
			rays.Rotation += dt * 12
		end)

		local title = draw and "DRAW" or (won and "VICTORY" or "DEFEAT")
		local titleHolder = dropTitle(center, title, accent, not won and not draw, my)
		if not won and not draw then
			-- a heavy thud: the whole stage jolts once
			task.delay(#title * 0.065 + 0.35, function()
				if my ~= token then
					return
				end
				center.Position = UDim2.new(0.5, 0, 0.5, 10)
				tween(center, 0.35, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Elastic)
			end)
		end
		local sub = UIUtil.label({
			Parent = center, Text = tostring(opts.subtitle or ""), Font = Theme.Font.Title, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.47, 30), Size = UDim2.fromOffset(900, 34),
			TextColor3 = WHITE, TextTransparency = 1, TextStrokeTransparency = 1, ZIndex = 30,
		})
		task.delay(0.65, function()
			if my == token then
				tween(sub, 0.4, { TextTransparency = 0, TextStrokeTransparency = 0.35, Position = UDim2.new(0.5, 0, 0.47, 0) })
			end
		end)
		local cards: Frame? = nil
		if typeof(opts.winners) == "table" and #opts.winners > 0 then
			task.delay(0.9, function()
				if my == token then
					cards = winnerCards(center, opts.winners, opts.winnerTeam == "Red" and RED or (opts.winnerTeam == "Blue" and BLUE or GOLD), my)
				end
			end)
		end
		if won then
			task.delay(0.35, function()
				if my == token then
					confetti(stage, my)
				end
			end)
		end

		-- 3. settle: everything tucks into a slim banner at the top
		task.delay(3.4, function()
			if my ~= token then
				return
			end
			tween(rayScale, 0.5, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(dim, 0.6, { BackgroundTransparency = 0.85 })
			tween(titleHolder, 0.55, { Position = UDim2.new(0.5, 0, 0, 120) }, Enum.EasingStyle.Quint)
			local ts = Instance.new("UIScale")
			ts.Parent = titleHolder
			tween(ts, 0.55, { Scale = 0.55 }, Enum.EasingStyle.Quint)
			tween(sub, 0.5, { Position = UDim2.new(0.5, 0, 0, 158), TextSize = 20 }, Enum.EasingStyle.Quint)
			tween(scoreGroup, 0.55, { Position = UDim2.new(0.5, 0, 0, 30) }, Enum.EasingStyle.Quint)
			tween(scoreScale, 0.55, { Scale = 0.32 }, Enum.EasingStyle.Quint)
			if cards then
				tween(cards, 0.4, { Position = UDim2.new(0.5, 0, 1.3, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
			task.delay(0.6, function()
				if my == token and onSettled then
					onSettled()
				end
			end)
			if tonumber(opts.autoHide) then
				task.delay(opts.autoHide, function()
					if my == token then
						tween(stage, 0.4, { Position = UDim2.fromScale(0, -0.1) })
						task.wait(0.4)
						if my == token then
							clear()
						end
					end
				end)
			end
		end)
	end)
end

function EndScreen.Build()
	gui = UIUtil.make("ScreenGui", {
		Name = "PawEndScreen", Parent = player:WaitForChild("PlayerGui"),
		IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 22, Enabled = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}) :: ScreenGui
end

return EndScreen
