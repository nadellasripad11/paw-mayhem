--!strict
-- HeroArt: larger composed illustrations built the same way as Icons.lua (pure
-- Frames/UICorner/UIGradient, no image assets) — a layered parallax sky, a big
-- foreground floating island with a windmill/trees/waterfall, and a fully
-- articulated standing cat holding a blaster. Used behind the main menu so the
-- lobby reads as a scene, not a flat panel, entirely within what native Roblox
-- GuiObjects can draw (flat/vector styled — this is not a substitute for
-- painted artwork, just the richest version achievable in pure UI code).

local TweenService = game:GetService("TweenService")

local HeroArt = {}

local function frame(parent: Instance, size: UDim2, pos: UDim2, color: Color3, cornerScale: number?, anchor: Vector2?): Frame
	local f = Instance.new("Frame")
	f.Size = size
	f.Position = pos
	f.AnchorPoint = anchor or Vector2.new(0.5, 0.5)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	if cornerScale then
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(cornerScale, 0)
		c.Parent = f
	end
	f.Parent = parent
	return f
end

local function grad(f: Frame, c1: Color3, c2: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rotation or 90
	g.Parent = f
	return g
end

-- ── Sky: gradient + sun glow + three drifting cloud layers ──────────────────
function HeroArt.Sky(parent: Instance)
	local sky = frame(parent, UDim2.fromScale(1, 1), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(120, 175, 245), 0, Vector2.new(0.5, 0.5))
	grad(sky, Color3.fromRGB(116, 202, 255), Color3.fromRGB(52, 133, 213), 90)
	sky.ZIndex = 1

	local sun = frame(sky, UDim2.fromOffset(220, 220), UDim2.fromScale(0.78, 0.12), Color3.fromRGB(255, 244, 200), 0.5)
	sun.BackgroundTransparency = 0.55
	sun.ZIndex = 1

	-- three cloud layers at different depths/speeds for a little parallax life
	local layers = {
		{ y = 0.10, count = 4, size = 70, speed = 55, alpha = 0.15 },
		{ y = 0.22, count = 3, size = 100, speed = 40, alpha = 0.25 },
		{ y = 0.16, count = 3, size = 55, speed = 70, alpha = 0.35 },
	}
	for li, layer in ipairs(layers) do
		for i = 1, layer.count do
			local cx = (i - 1) / layer.count + (li * 0.13)
			cx = cx % 1
			local puff = frame(sky, UDim2.fromOffset(layer.size, layer.size * 0.5), UDim2.fromScale(cx, layer.y), Color3.new(1, 1, 1), 0.5)
			puff.BackgroundTransparency = 1 - layer.alpha
			puff.ZIndex = 1
			local goRight = frame == frame -- no-op, keeps type checker calm
			local startX = puff.Position
			local endX = UDim2.fromScale((cx + 0.18) % 1, layer.y)
			task.spawn(function()
				while puff.Parent do
					TweenService:Create(puff, TweenInfo.new(layer.speed, Enum.EasingStyle.Linear), { Position = endX }):Play()
					task.wait(layer.speed)
					puff.Position = startX
				end
			end)
		end
	end
	return sky
end

-- ── Floating island: grass top, stone tiers, windmill, trees, flowers, falls ─
function HeroArt.Island(parent: Instance, opts: any?)
	opts = opts or {}
	local width = opts.width or 900
	local anchorPos = opts.position or UDim2.fromScale(0.5, 1.02)

	local root = Instance.new("Frame")
	root.Size = UDim2.fromOffset(width, width * 0.62)
	root.Position = anchorPos
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.BackgroundTransparency = 1
	root.ZIndex = 2
	root.Parent = parent

	-- stone tapered tiers (drawn first, behind grass)
	for i = 1, 4 do
		local w = width * (1 - i * 0.11)
		local tier = frame(root, UDim2.fromOffset(w, width * 0.10), UDim2.fromScale(0.5, 0.5 + i * 0.085), Color3.fromRGB(120, 122, 134), 0.25)
		tier.ZIndex = 2
		grad(tier, Color3.fromRGB(150, 152, 165), Color3.fromRGB(90, 92, 104), 90)
	end

	-- grass top disc
	local grass = frame(root, UDim2.fromOffset(width, width * 0.30), UDim2.fromScale(0.5, 0.42), Color3.fromRGB(96, 175, 92), 0.5)
	grass.ZIndex = 3
	grad(grass, Color3.fromRGB(140, 210, 110), Color3.fromRGB(80, 155, 80), 90)
	local rim = frame(root, UDim2.fromOffset(width * 1.01, width * 0.06), UDim2.fromScale(0.5, 0.54), Color3.fromRGB(70, 140, 70), 0.5)
	rim.ZIndex = 2

	-- windmill (tower + roof + crossed blades)
	local windX, windY = 0.22, 0.20
	local towerH = width * 0.30
	local tower = frame(root, UDim2.fromOffset(width * 0.045, towerH), UDim2.fromScale(windX, windY), Color3.fromRGB(232, 222, 205), 0.15)
	tower.AnchorPoint = Vector2.new(0.5, 1)
	tower.ZIndex = 4
	local roof = frame(root, UDim2.fromOffset(width * 0.075, width * 0.05), UDim2.fromScale(windX, windY - towerH / (width * 0.62) - 0.015), Color3.fromRGB(178, 88, 78), 0.3)
	roof.ZIndex = 4
	local hub = frame(root, UDim2.fromOffset(width * 0.02, width * 0.02), UDim2.fromScale(windX, windY - towerH / (width * 0.62) * 0.55), Color3.fromRGB(120, 84, 58), 0.5)
	hub.ZIndex = 5
	local blades = Instance.new("Frame")
	blades.Size = UDim2.fromOffset(1, 1)
	blades.Position = hub.Position
	blades.AnchorPoint = Vector2.new(0.5, 0.5)
	blades.BackgroundTransparency = 1
	blades.ZIndex = 4
	blades.Parent = root
	for b = 0, 3 do
		local blade = frame(blades, UDim2.fromOffset(width * 0.016, width * 0.11), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(240, 240, 235), 0.15)
		blade.AnchorPoint = Vector2.new(0.5, 0)
		blade.Rotation = b * 90
		blade.ZIndex = 4
	end
	task.spawn(function()
		local rot = 0
		while blades.Parent do
			rot = (rot + 1.2) % 360
			for _, blade in ipairs(blades:GetChildren()) do
				-- offset preserved via additive rotation from base each frame
			end
			blades.Rotation = rot
			task.wait()
		end
	end)

	-- trees
	local treeSpots = { 0.42, 0.58, 0.7, 0.34 }
	for i, tx in ipairs(treeSpots) do
		local trunk = frame(root, UDim2.fromOffset(width * 0.014, width * 0.055), UDim2.fromScale(tx, 0.5), Color3.fromRGB(120, 84, 58), 0.1)
		trunk.AnchorPoint = Vector2.new(0.5, 1)
		trunk.ZIndex = 4
		for l = 1, 3 do
			local d = width * (0.075 - l * 0.012)
			local leaf = frame(root, UDim2.fromOffset(d, d), UDim2.fromScale(tx, 0.5 - l * 0.028), Color3.fromRGB(80, 165, 90), 0.5)
			leaf.ZIndex = 4
		end
	end

	-- flowers
	for i = 1, 10 do
		local fx = 0.1 + (i / 10) * 0.8
		local fy = 0.44 + (i % 3) * 0.02
		local fcolors = { Color3.fromRGB(255, 150, 200), Color3.fromRGB(255, 220, 120), Color3.fromRGB(200, 160, 255) }
		local bloom = frame(root, UDim2.fromOffset(width * 0.012, width * 0.012), UDim2.fromScale(fx, fy), fcolors[(i % 3) + 1], 0.5)
		bloom.ZIndex = 4
	end

	-- waterfall streak off the right edge
	local fall = frame(root, UDim2.fromOffset(width * 0.05, width * 0.5), UDim2.fromScale(0.86, 0.58), Color3.fromRGB(150, 215, 245), 0.4)
	fall.BackgroundTransparency = 0.35
	fall.ZIndex = 2
	grad(fall, Color3.fromRGB(200, 235, 255), Color3.fromRGB(120, 190, 230), 90)

	return root
end

-- ── Hero cat: fully articulated standing cat holding a blaster ──────────────
function HeroArt.HeroCat(parent: Instance, opts: any?)
	opts = opts or {}
	local size = opts.size or 340
	local furColor = opts.fur or Color3.fromRGB(240, 150, 70)
	local accent = opts.accent or Color3.fromRGB(255, 200, 140)
	local gunColor = opts.gunColor or Color3.fromRGB(140, 90, 255)
	local gunAccent = opts.gunAccent or Color3.fromRGB(95, 210, 255)
	local position = opts.position or UDim2.fromScale(0.85, 1.0)

	local root = Instance.new("Frame")
	root.Size = UDim2.fromOffset(size, size)
	root.Position = position
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.BackgroundTransparency = 1
	root.ZIndex = 6
	root.Parent = parent

	local function part(w, h, x, y, color, cScale, rot)
		local f = frame(root, UDim2.fromOffset(size * w, size * h), UDim2.fromScale(x, y), color, cScale or 0.3)
		if rot then
			f.Rotation = rot
		end
		f.ZIndex = 6
		return f
	end

	-- shadow
	local shadow = frame(root, UDim2.fromOffset(size * 0.5, size * 0.08), UDim2.fromScale(0.5, 1.0), Color3.new(0, 0, 0), 0.5)
	shadow.BackgroundTransparency = 0.75
	shadow.ZIndex = 5

	-- legs
	part(0.12, 0.22, 0.4, 0.94, furColor, 0.4)
	part(0.12, 0.22, 0.6, 0.94, furColor, 0.4)

	-- tail (curled, segmented)
	for s = 1, 5 do
		local t = s / 5
		local d = 0.1 - t * 0.05
		part(d, d, 0.82 + t * 0.05, 0.55 - t * 0.18, furColor, 0.5)
	end

	-- body
	local body = part(0.5, 0.46, 0.46, 0.68, furColor, 0.35)
	local belly = part(0.32, 0.28, 0.42, 0.72, accent, 0.5)

	-- back arm (behind body, holding gun stock)
	part(0.12, 0.3, 0.68, 0.6, furColor, 0.4, 12)

	-- gun (large, held forward)
	local gunW, gunH = 0.5, 0.16
	local gunBody = part(gunW, gunH, 0.66, 0.5, gunColor, 0.25, -6)
	local gunBarrel = part(gunW * 0.4, gunH * 0.8, 0.92, 0.47, gunAccent, 0.35, -6)
	local muzzle = frame(root, UDim2.fromOffset(size * 0.1, size * 0.1), UDim2.fromScale(1.05, 0.46), gunAccent, 0.5)
	muzzle.BackgroundTransparency = 0.15
	muzzle.ZIndex = 6

	-- front arm (in front of body, gripping gun)
	part(0.13, 0.22, 0.58, 0.56, furColor, 0.4, -18)

	-- head
	local head = part(0.42, 0.4, 0.42, 0.28, furColor, 0.5)
	local muzzlePatch = part(0.22, 0.16, 0.4, 0.36, accent, 0.5)
	-- ears
	local earL = frame(root, UDim2.fromOffset(size * 0.16, size * 0.16), UDim2.fromScale(0.3, 0.1), furColor, 0.22)
	earL.Rotation = 45
	earL.ZIndex = 6
	local earR = frame(root, UDim2.fromOffset(size * 0.16, size * 0.16), UDim2.fromScale(0.56, 0.1), furColor, 0.22)
	earR.Rotation = 45
	earR.ZIndex = 6
	local innerL = part(0.07, 0.09, 0.32, 0.12, accent, 0.4)
	local innerR = part(0.07, 0.09, 0.54, 0.12, accent, 0.4)
	-- eyes
	local eyeL = part(0.06, 0.07, 0.36, 0.27, Color3.fromRGB(35, 30, 45), 0.5)
	local eyeR = part(0.06, 0.07, 0.48, 0.27, Color3.fromRGB(35, 30, 45), 0.5)
	part(0.02, 0.02, 0.375, 0.255, Color3.new(1, 1, 1), 0.5)
	part(0.02, 0.02, 0.495, 0.255, Color3.new(1, 1, 1), 0.5)
	-- nose
	part(0.035, 0.03, 0.415, 0.335, Color3.fromRGB(255, 150, 170), 0.5)

	return root
end

-- Dim every descendant Frame of `root` by raising its BackgroundTransparency,
-- turning any HeroArt piece into a faint watermark (used behind panel content).
function HeroArt.Fade(root: Instance, amount: number)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Frame") then
			d.BackgroundTransparency = math.clamp(d.BackgroundTransparency + amount, 0, 0.97)
		end
	end
	return root
end

-- Convenience: a faint island watermark anchored to a panel's bottom, sitting
-- behind its content (caller should still add its own opaque foreground).
-- Wrapped in pcall: decorative background art must NEVER be able to break a
-- functional screen (item grids, buttons, etc.) — if anything here throws, we
-- warn to Output with the real error and simply render no watermark.
function HeroArt.Watermark(parent: Instance, width: number?)
	local ok, result = pcall(function()
		local holder = Instance.new("Frame")
		holder.Size = UDim2.fromScale(1, 1)
		holder.BackgroundTransparency = 1
		holder.ClipsDescendants = true
		holder.ZIndex = 1
		holder.Parent = parent
		local island = HeroArt.Island(holder, { width = width or 700, position = UDim2.fromScale(0.5, 1.3) })
		HeroArt.Fade(island, 0.82)
		return holder
	end)
	if ok then
		return result
	end
	warn("[PAW MAYHEM] HeroArt.Watermark failed (non-fatal, skipped): " .. tostring(result))
	return nil
end

return HeroArt
