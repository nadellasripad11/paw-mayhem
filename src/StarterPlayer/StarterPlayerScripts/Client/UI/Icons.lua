--!strict
-- Icons: original procedural vector icons built entirely from Frames/UICorner
-- (no image assets, no emoji). Roblox's default UI fonts do not reliably
-- render color emoji — glyphs like 🔫🛒🐱🏆⚙💎 can come out blank/missing in
-- Studio. Every icon used in the UI is drawn here instead, so it always
-- renders identically and matches the game's flat, colorful art direction.
--
-- Every Icons.<Name>(size, color, accent) returns an unparented square Frame
-- (Size = size x size) the caller positions/parents like any other element.

local Icons = {}

local function base(size: number): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	return f
end

local function chip(parent: Instance, w: number, h: number, color: Color3, cornerScale: number?): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(w, h)
	f.BackgroundColor3 = color
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(cornerScale or 0.25, 0)
	c.Parent = f
	f.Parent = parent
	return f
end

local function circle(parent: Instance, d: number, color: Color3): Frame
	return chip(parent, d, d, color, 0.5)
end

local function pos(f: Frame, x: number, y: number, rot: number?)
	f.Position = UDim2.fromOffset(x, y)
	if rot then
		f.Rotation = rot
	end
end

-- ── Paw print (Customize nav) ────────────────────────────────────────────────
function Icons.Paw(size: number, color: Color3): Frame
	local f = base(size)
	local pad = chip(f, size * 0.5, size * 0.38, color, 0.5)
	pos(pad, size * 0.5, size * 0.62)
	local toe = size * 0.17
	local rTop = size * 0.28
	for i, ang in ipairs({ -55, -18, 18, 55 }) do
		local rad = math.rad(ang - 90)
		local x = size * 0.5 + math.cos(rad) * rTop
		local y = size * 0.5 + math.sin(rad) * rTop + size * 0.06
		local c = circle(f, toe, color)
		pos(c, x, y)
	end
	return f
end

-- ── Blocky blaster silhouette (weapons / Loadout / fire icon) ───────────────
function Icons.Gun(size: number, color: Color3, accent: Color3?): Frame
	local f = base(size)
	local tip = accent or color
	local body = chip(f, size * 0.62, size * 0.26, color, 0.35)
	pos(body, size * 0.46, size * 0.46)
	local barrel = chip(f, size * 0.30, size * 0.16, tip, 0.4)
	pos(barrel, size * 0.86, size * 0.42)
	local grip = chip(f, size * 0.16, size * 0.34, color:Lerp(Color3.new(0, 0, 0), 0.25), 0.3)
	pos(grip, size * 0.28, size * 0.68, -14)
	local muzzle = circle(f, size * 0.14, tip)
	pos(muzzle, size * 1.0, size * 0.42)
	return f
end

-- ── Weapon-class silhouettes — each weapon reads as a genuinely different
-- shape, not just a recolor of the same gun (Heavy is chunky, Fast is small
-- and twin-barreled, Sniper is long and scoped, Cannon is huge with a glowing
-- orb, Bubble is round-tipped, Ice is angular/crystalline, Golden wears a
-- small crown). Same (size, color, accent) signature as Icons.Gun.
function Icons.GunHeavy(size: number, color: Color3, accent: Color3?): Frame
	local f = base(size)
	local tip = accent or color
	local body = chip(f, size * 0.56, size * 0.36, color, 0.25)
	pos(body, size * 0.42, size * 0.5)
	local barrel = circle(f, size * 0.38, tip)
	pos(barrel, size * 0.82, size * 0.48)
	local barrelRing = circle(f, size * 0.2, color:Lerp(Color3.new(0, 0, 0), 0.3))
	pos(barrelRing, size * 0.82, size * 0.48)
	local grip = chip(f, size * 0.18, size * 0.36, color:Lerp(Color3.new(0, 0, 0), 0.25), 0.25)
	pos(grip, size * 0.24, size * 0.72, -12)
	return f
end

function Icons.GunFast(size: number, color: Color3, accent: Color3?): Frame
	local f = base(size)
	local tip = accent or color
	local body = chip(f, size * 0.5, size * 0.18, color, 0.5)
	pos(body, size * 0.42, size * 0.42)
	for _, dy in ipairs({ -0.06, 0.06 }) do
		local barrel = chip(f, size * 0.26, size * 0.08, tip, 0.5)
		pos(barrel, size * 0.78, size * 0.42 + dy * size)
	end
	local grip = chip(f, size * 0.12, size * 0.26, color:Lerp(Color3.new(0, 0, 0), 0.25), 0.4)
	pos(grip, size * 0.24, size * 0.62, -16)
	return f
end

function Icons.GunSniper(size: number, color: Color3, accent: Color3?): Frame
	local f = base(size)
	local tip = accent or color
	local body = chip(f, size * 0.5, size * 0.2, color, 0.3)
	pos(body, size * 0.4, size * 0.5)
	local barrel = chip(f, size * 0.5, size * 0.1, tip, 0.5)
	pos(barrel, size * 0.86, size * 0.48)
	local scope = chip(f, size * 0.26, size * 0.1, color:Lerp(Color3.new(0, 0, 0), 0.2), 0.4)
	pos(scope, size * 0.42, size * 0.28)
	local scopeGlass = circle(f, size * 0.08, tip)
	pos(scopeGlass, size * 0.5, size * 0.24)
	local grip = chip(f, size * 0.14, size * 0.28, color:Lerp(Color3.new(0, 0, 0), 0.25), 0.3)
	pos(grip, size * 0.22, size * 0.68, -14)
	local muzzle = circle(f, size * 0.1, tip)
	pos(muzzle, size * 1.08, size * 0.48)
	return f
end

function Icons.GunCannon(size: number, color: Color3, accent: Color3?): Frame
	local f = base(size)
	local tip = accent or color
	local body = chip(f, size * 0.58, size * 0.38, color, 0.2)
	pos(body, size * 0.4, size * 0.5)
	local barrel = chip(f, size * 0.34, size * 0.3, color:Lerp(Color3.new(0, 0, 0), 0.15), 0.3)
	pos(barrel, size * 0.78, size * 0.48)
	local orb = circle(f, size * 0.32, tip)
	pos(orb, size * 0.96, size * 0.48)
	local orbCore = circle(f, size * 0.14, tip:Lerp(Color3.new(1, 1, 1), 0.5))
	pos(orbCore, size * 0.96, size * 0.48)
	local grip = chip(f, size * 0.18, size * 0.38, color:Lerp(Color3.new(0, 0, 0), 0.25), 0.2)
	pos(grip, size * 0.22, size * 0.74, -10)
	return f
end

function Icons.GunBubble(size: number, color: Color3, accent: Color3?): Frame
	local f = base(size)
	local tip = accent or color
	local body = chip(f, size * 0.5, size * 0.24, color, 0.5)
	pos(body, size * 0.4, size * 0.46)
	local bubble = circle(f, size * 0.44, tip)
	pos(bubble, size * 0.86, size * 0.44)
	local shine = circle(f, size * 0.12, Color3.new(1, 1, 1))
	pos(shine, size * 0.76, size * 0.34)
	local grip = chip(f, size * 0.14, size * 0.3, color:Lerp(Color3.new(0, 0, 0), 0.2), 0.4)
	pos(grip, size * 0.22, size * 0.66, -14)
	return f
end

function Icons.GunIce(size: number, color: Color3, accent: Color3?): Frame
	local f = base(size)
	local tip = accent or color
	local body = chip(f, size * 0.5, size * 0.22, color, 0.35)
	pos(body, size * 0.4, size * 0.48)
	local shard1 = chip(f, size * 0.14, size * 0.34, tip, 0.15)
	pos(shard1, size * 0.78, size * 0.4, 15)
	local shard2 = chip(f, size * 0.1, size * 0.26, tip, 0.15)
	pos(shard2, size * 0.92, size * 0.46, -10)
	local grip = chip(f, size * 0.14, size * 0.3, color:Lerp(Color3.new(0, 0, 0), 0.25), 0.3)
	pos(grip, size * 0.22, size * 0.66, -14)
	return f
end

function Icons.GunGolden(size: number, color: Color3, accent: Color3?): Frame
	local f = base(size)
	local tip = accent or color
	local body = chip(f, size * 0.6, size * 0.26, color, 0.35)
	pos(body, size * 0.44, size * 0.5)
	local barrel = chip(f, size * 0.28, size * 0.16, tip, 0.4)
	pos(barrel, size * 0.84, size * 0.46)
	local grip = chip(f, size * 0.15, size * 0.32, color:Lerp(Color3.new(0, 0, 0), 0.2), 0.3)
	pos(grip, size * 0.26, size * 0.72, -14)
	-- small crown on top
	local band = chip(f, size * 0.2, size * 0.06, tip, 0.3)
	pos(band, size * 0.44, size * 0.3)
	for _, dx in ipairs({ -0.06, 0, 0.06 }) do
		local point = chip(f, size * 0.05, size * 0.08, tip, 0.2)
		pos(point, size * 0.44 + dx * size, size * 0.24)
	end
	return f
end

-- ── Shopping cart (Shop nav) ─────────────────────────────────────────────────
function Icons.Cart(size: number, color: Color3): Frame
	local f = base(size)
	local basket = chip(f, size * 0.58, size * 0.36, color, 0.18)
	pos(basket, size * 0.52, size * 0.46)
	local handle = chip(f, size * 0.06, size * 0.28, color, 0.5)
	pos(handle, size * 0.2, size * 0.28, -35)
	for _, dx in ipairs({ -0.14, 0.14 }) do
		local wheel = circle(f, size * 0.14, color:Lerp(Color3.new(0, 0, 0), 0.2))
		pos(wheel, size * 0.52 + dx * size, size * 0.78)
	end
	return f
end

-- ── Cat face avatar (fur previews, portraits, leaderboard rows) ─────────────
function Icons.CatFace(size: number, furColor: Color3, accentColor: Color3?): Frame
	local f = base(size)
	local accent = accentColor or furColor:Lerp(Color3.new(1, 1, 1), 0.3)
	for _, dx in ipairs({ -0.3, 0.3 }) do
		local ear = chip(f, size * 0.3, size * 0.3, furColor, 0.22)
		pos(ear, size * 0.5 + dx * size, size * 0.24, 45)
	end
	local head = circle(f, size * 0.78, furColor)
	pos(head, size * 0.5, size * 0.54)
	local muzzle = chip(f, size * 0.36, size * 0.26, accent, 0.5)
	pos(muzzle, size * 0.5, size * 0.66)
	for _, dx in ipairs({ -0.16, 0.16 }) do
		local eye = circle(f, size * 0.1, Color3.fromRGB(35, 30, 45))
		pos(eye, size * 0.5 + dx * size, size * 0.5)
	end
	local nose = chip(f, size * 0.08, size * 0.06, Color3.fromRGB(255, 150, 170), 0.5)
	pos(nose, size * 0.5, size * 0.58)
	return f
end

-- Fuller mini character: head + ears + body + 2 stub legs + a curled tail, no
-- gun — a small standing chibi cat rather than just a face. Used for cat
-- variation thumbnails and the Customize preview, where reference 6 shows a
-- full small body, not a portrait crop.
function Icons.CatBody(size: number, furColor: Color3, accentColor: Color3?): Frame
	local f = base(size)
	local accent = accentColor or furColor:Lerp(Color3.new(1, 1, 1), 0.3)

	-- tail (small curl, drawn first so it sits behind the body)
	for s = 1, 3 do
		local t = s / 3
		local d = size * (0.1 - t * 0.03)
		local tail = circle(f, d, furColor)
		pos(tail, size * (0.78 + t * 0.06), size * (0.64 - t * 0.16))
	end

	-- legs
	for _, dx in ipairs({ -0.13, 0.13 }) do
		local leg = chip(f, size * 0.16, size * 0.2, furColor, 0.4)
		pos(leg, size * 0.5 + dx * size, size * 0.86)
	end

	-- body
	local body = circle(f, size * 0.5, furColor)
	pos(body, size * 0.5, size * 0.68)
	local belly = chip(f, size * 0.28, size * 0.22, accent, 0.5)
	pos(belly, size * 0.5, size * 0.74)

	-- ears
	for _, dx in ipairs({ -0.26, 0.26 }) do
		local ear = chip(f, size * 0.24, size * 0.24, furColor, 0.22)
		pos(ear, size * 0.5 + dx * size, size * 0.18, 45)
	end
	-- head
	local head = circle(f, size * 0.6, furColor)
	pos(head, size * 0.5, size * 0.4)
	local muzzle = chip(f, size * 0.28, size * 0.2, accent, 0.5)
	pos(muzzle, size * 0.5, size * 0.48)
	for _, dx in ipairs({ -0.13, 0.13 }) do
		local eye = circle(f, size * 0.07, Color3.fromRGB(35, 30, 45))
		pos(eye, size * 0.5 + dx * size, size * 0.38)
	end
	local nose = chip(f, size * 0.06, size * 0.045, Color3.fromRGB(255, 150, 170), 0.5)
	pos(nose, size * 0.5, size * 0.43)
	return f
end

-- ── Trophy (Leaderboard nav) ─────────────────────────────────────────────────
function Icons.Trophy(size: number, color: Color3): Frame
	local f = base(size)
	local bowl = circle(f, size * 0.5, color)
	pos(bowl, size * 0.5, size * 0.36)
	local cut = chip(f, size * 0.5, size * 0.2, Color3.new(0, 0, 0), 0.1)
	cut.BackgroundTransparency = 1
	local stem = chip(f, size * 0.12, size * 0.24, color, 0.2)
	pos(stem, size * 0.5, size * 0.62)
	local base_ = chip(f, size * 0.34, size * 0.1, color, 0.3)
	pos(base_, size * 0.5, size * 0.8)
	for _, dx in ipairs({ -0.32, 0.32 }) do
		local handle = chip(f, size * 0.05, size * 0.22, color, 0.5)
		pos(handle, size * 0.5 + dx * size, size * 0.34, dx > 0 and 20 or -20)
	end
	return f
end

-- ── Checkmark (Quests nav / claim state) ─────────────────────────────────────
function Icons.Check(size: number, color: Color3): Frame
	local f = base(size)
	local short = chip(f, size * 0.14, size * 0.36, color, 0.4)
	pos(short, size * 0.38, size * 0.58, -45)
	local long = chip(f, size * 0.14, size * 0.62, color, 0.4)
	pos(long, size * 0.62, size * 0.44, 45)
	return f
end

-- ── Gear (Settings nav) ──────────────────────────────────────────────────────
function Icons.Gear(size: number, color: Color3, bg: Color3?): Frame
	local f = base(size)
	local outer = circle(f, size * 0.62, color)
	pos(outer, size * 0.5, size * 0.5)
	for i = 0, 5 do
		local ang = i * 60
		local tooth = chip(f, size * 0.16, size * 0.2, color, 0.2)
		local rad = math.rad(ang)
		pos(tooth, size * 0.5 + math.cos(rad) * size * 0.32, size * 0.5 + math.sin(rad) * size * 0.32, ang)
	end
	local hole = circle(f, size * 0.26, bg or Color3.fromRGB(24, 30, 48))
	pos(hole, size * 0.5, size * 0.5)
	return f
end

-- ── Coin ──────────────────────────────────────────────────────────────────────
function Icons.Coin(size: number, color: Color3): Frame
	local f = base(size)
	local c = circle(f, size * 0.86, color)
	pos(c, size * 0.5, size * 0.5)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color:Lerp(Color3.new(0, 0, 0), 0.3)
	stroke.Thickness = math.max(1, size * 0.05)
	stroke.Parent = c
	local inner = circle(f, size * 0.5, color:Lerp(Color3.new(1, 1, 1), 0.25))
	pos(inner, size * 0.5, size * 0.5)
	return f
end

-- ── Gem ───────────────────────────────────────────────────────────────────────
function Icons.Gem(size: number, color: Color3): Frame
	local f = base(size)
	local d = chip(f, size * 0.58, size * 0.58, color, 0.15)
	pos(d, size * 0.5, size * 0.5, 45)
	local shine = chip(f, size * 0.16, size * 0.16, color:Lerp(Color3.new(1, 1, 1), 0.5), 0.3)
	pos(shine, size * 0.38, size * 0.38, 45)
	return f
end

-- ── Play triangle ─────────────────────────────────────────────────────────────
function Icons.Play(size: number, color: Color3): Frame
	local f = base(size)
	-- approximate a triangle from 3 thin stacked bars of decreasing width
	local bars = 7
	for i = 0, bars - 1 do
		local t = i / (bars - 1)
		local w = size * 0.62 * (1 - t)
		local bar = chip(f, w, size * (0.9 / bars) + 1, color, 0.15)
		pos(bar, size * (0.22 + t * 0.3), size * (0.12 + (i + 0.5) * (0.76 / bars)))
	end
	return f
end

-- ── Shirt (Outfit category) ──────────────────────────────────────────────────
function Icons.Shirt(size: number, color: Color3): Frame
	local f = base(size)
	local body = chip(f, size * 0.5, size * 0.5, color, 0.2)
	pos(body, size * 0.5, size * 0.58)
	for _, dx in ipairs({ -0.36, 0.36 }) do
		local sleeve = chip(f, size * 0.2, size * 0.22, color, 0.3)
		pos(sleeve, size * 0.5 + dx * size, size * 0.34, dx > 0 and 20 or -20)
	end
	local collar = chip(f, size * 0.18, size * 0.14, color:Lerp(Color3.new(0, 0, 0), 0.15), 0.3)
	pos(collar, size * 0.5, size * 0.3)
	return f
end

-- ── Top hat (Hat category) ───────────────────────────────────────────────────
function Icons.Hat(size: number, color: Color3): Frame
	local f = base(size)
	local brim = chip(f, size * 0.64, size * 0.14, color, 0.4)
	pos(brim, size * 0.5, size * 0.68)
	local crown = chip(f, size * 0.38, size * 0.36, color, 0.18)
	pos(crown, size * 0.5, size * 0.42)
	return f
end

-- ── Sunglasses (Accessory category) ──────────────────────────────────────────
function Icons.Glasses(size: number, color: Color3): Frame
	local f = base(size)
	for _, dx in ipairs({ -0.24, 0.24 }) do
		local lens = chip(f, size * 0.34, size * 0.26, color, 0.5)
		pos(lens, size * 0.5 + dx * size, size * 0.5)
	end
	local bridge = chip(f, size * 0.16, size * 0.06, color, 0.5)
	pos(bridge, size * 0.5, size * 0.5)
	return f
end

-- ── Smiley (Emote category) ──────────────────────────────────────────────────
function Icons.Smiley(size: number, color: Color3): Frame
	local f = base(size)
	local face = circle(f, size * 0.78, color)
	pos(face, size * 0.5, size * 0.5)
	for _, dx in ipairs({ -0.18, 0.18 }) do
		local eye = circle(f, size * 0.08, Color3.fromRGB(35, 30, 45))
		pos(eye, size * 0.5 + dx * size, size * 0.42)
	end
	local mouth = chip(f, size * 0.34, size * 0.1, Color3.fromRGB(35, 30, 45), 0.5)
	pos(mouth, size * 0.5, size * 0.62)
	local maskTop = chip(f, size * 0.34, size * 0.06, color, 0)
	pos(maskTop, size * 0.5, size * 0.58)
	return f
end

-- ── Sparkle (skins / premium accent) ─────────────────────────────────────────
function Icons.Sparkle(size: number, color: Color3): Frame
	local f = base(size)
	local v = chip(f, size * 0.16, size * 0.7, color, 0.5)
	pos(v, size * 0.5, size * 0.5)
	local h = chip(f, size * 0.7, size * 0.16, color, 0.5)
	pos(h, size * 0.5, size * 0.5)
	return f
end

-- ── Shield (power-up) ─────────────────────────────────────────────────────────
function Icons.Shield(size: number, color: Color3): Frame
	local f = base(size)
	local top = circle(f, size * 0.6, color)
	pos(top, size * 0.5, size * 0.4)
	local bottom = chip(f, size * 0.6, size * 0.5, color, 0.2)
	pos(bottom, size * 0.5, size * 0.62)
	return f
end

-- ── Bolt (rapid fire / speed power-up) ───────────────────────────────────────
function Icons.Bolt(size: number, color: Color3): Frame
	local f = base(size)
	local top = chip(f, size * 0.5, size * 0.16, color, 0.15)
	pos(top, size * 0.44, size * 0.32, -25)
	local bottom = chip(f, size * 0.5, size * 0.16, color, 0.15)
	pos(bottom, size * 0.56, size * 0.68, -25)
	local mid = chip(f, size * 0.16, size * 0.16, color, 0.15)
	pos(mid, size * 0.5, size * 0.5, -25)
	return f
end

-- ── Burst (mega knockback power-up) ──────────────────────────────────────────
function Icons.Burst(size: number, color: Color3): Frame
	local f = base(size)
	for i = 0, 3 do
		local ang = i * 45
		local spike = chip(f, size * 0.1, size * 0.6, color, 0.4)
		pos(spike, size * 0.5, size * 0.5, ang)
	end
	local core = circle(f, size * 0.24, color:Lerp(Color3.new(1, 1, 1), 0.3))
	pos(core, size * 0.5, size * 0.5)
	return f
end

-- ── Multi-shot (three dots) ───────────────────────────────────────────────────
function Icons.MultiShot(size: number, color: Color3): Frame
	local f = base(size)
	for i, dy in ipairs({ 0.28, 0.5, 0.72 }) do
		local dot = circle(f, size * 0.18, color)
		pos(dot, size * (0.4 + (i - 2) * 0.14), size * dy)
	end
	return f
end

-- ── Emote icons (each emote gets its own readable shape) ─────────────────────
function Icons.Wave(size: number, color: Color3): Frame
	local f = base(size)
	local palm = chip(f, size * 0.32, size * 0.4, color, 0.4)
	pos(palm, size * 0.5, size * 0.6, -15)
	for i, dx in ipairs({ -0.1, 0, 0.1, 0.19 }) do
		local finger = chip(f, size * 0.08, size * 0.26, color, 0.5)
		pos(finger, size * 0.5 + dx * size, size * 0.32 - math.abs(dx) * size * 0.06, -15)
	end
	return f
end

function Icons.Sleep(size: number, color: Color3): Frame
	local f = base(size)
	local face = circle(f, size * 0.5, color)
	pos(face, size * 0.42, size * 0.58)
	for _, dx in ipairs({ -0.1, 0.1 }) do
		local eye = chip(f, size * 0.1, size * 0.02, Color3.fromRGB(35, 30, 45), 0.5)
		pos(eye, size * 0.42 + dx * size, size * 0.54)
	end
	-- "Z" marks drifting up
	for i, s in ipairs({ 0.14, 0.19, 0.24 }) do
		local z = chip(f, size * s, size * (s * 0.35), color, 0.1)
		pos(z, size * (0.72 + i * 0.05), size * (0.42 - i * 0.12))
	end
	return f
end

function Icons.Laugh(size: number, color: Color3): Frame
	local f = base(size)
	local face = circle(f, size * 0.78, color)
	pos(face, size * 0.5, size * 0.5)
	for _, dx in ipairs({ -0.18, 0.18 }) do
		local eye = chip(f, size * 0.1, size * 0.02, Color3.fromRGB(35, 30, 45), 0.5)
		pos(eye, size * 0.5 + dx * size, size * 0.4, dx > 0 and -20 or 20)
	end
	local mouth = chip(f, size * 0.4, size * 0.24, Color3.fromRGB(35, 30, 45), 0.5)
	pos(mouth, size * 0.5, size * 0.64)
	local tongue = chip(f, size * 0.2, size * 0.1, Color3.fromRGB(255, 130, 150), 0.5)
	pos(tongue, size * 0.5, size * 0.72)
	return f
end

function Icons.Spin(size: number, color: Color3): Frame
	local f = base(size)
	for i = 0, 2 do
		local ang = i * 120
		local arc = chip(f, size * 0.12, size * 0.5, color, 0.5)
		pos(arc, size * 0.5, size * 0.5, ang)
	end
	local core = circle(f, size * 0.16, color:Lerp(Color3.new(1, 1, 1), 0.3))
	pos(core, size * 0.5, size * 0.5)
	return f
end

function Icons.Fall(size: number, color: Color3): Frame
	local f = base(size)
	local body = chip(f, size * 0.36, size * 0.36, color, 0.5)
	pos(body, size * 0.5, size * 0.4)
	local arrow = chip(f, size * 0.12, size * 0.36, color, 0.3)
	pos(arrow, size * 0.5, size * 0.74)
	local tipL = chip(f, size * 0.18, size * 0.1, color, 0.2)
	pos(tipL, size * 0.42, size * 0.86, -35)
	local tipR = chip(f, size * 0.18, size * 0.1, color, 0.2)
	pos(tipR, size * 0.58, size * 0.86, 35)
	return f
end

function Icons.SitDown(size: number, color: Color3): Frame
	local f = base(size)
	local body = chip(f, size * 0.4, size * 0.3, color, 0.4)
	pos(body, size * 0.5, size * 0.62)
	local head = circle(f, size * 0.3, color)
	pos(head, size * 0.5, size * 0.32)
	local base_ = chip(f, size * 0.5, size * 0.1, color:Lerp(Color3.new(0, 0, 0), 0.15), 0.3)
	pos(base_, size * 0.5, size * 0.84)
	return f
end

-- Registry so callers can pass a string key (used by itemCard/Icons.Draw).
Icons.Registry = {
	Gun = Icons.Gun,
	GunHeavy = Icons.GunHeavy,
	GunFast = Icons.GunFast,
	GunSniper = Icons.GunSniper,
	GunCannon = Icons.GunCannon,
	GunBubble = Icons.GunBubble,
	GunIce = Icons.GunIce,
	GunGolden = Icons.GunGolden,
	Cart = Icons.Cart,
	CatFace = Icons.CatFace,
	CatBody = Icons.CatBody,
	Trophy = Icons.Trophy,
	Check = Icons.Check,
	Gear = Icons.Gear,
	Coin = Icons.Coin,
	Gem = Icons.Gem,
	Play = Icons.Play,
	Shirt = Icons.Shirt,
	Hat = Icons.Hat,
	Glasses = Icons.Glasses,
	Smiley = Icons.Smiley,
	Sparkle = Icons.Sparkle,
	Paw = Icons.Paw,
	Shield = Icons.Shield,
	Bolt = Icons.Bolt,
	Burst = Icons.Burst,
	MultiShot = Icons.MultiShot,
	Wave = Icons.Wave,
	Sleep = Icons.Sleep,
	Laugh = Icons.Laugh,
	Spin = Icons.Spin,
	Fall = Icons.Fall,
	SitDown = Icons.SitDown,
}

-- Draw an icon by name and parent+position it, centered, in one call.
-- Every icon draw goes through here, from every screen in the game. Wrapped in
-- pcall: a bug in ONE icon must never take down the whole panel that called it
-- (that's exactly what turned a single bad icon into a "temporarily
-- unavailable" screen before — this is the single point that protects all of
-- them at once). On failure it warns with the real error and simply places no
-- icon, so the rest of the card/header still renders normally.
function Icons.Place(name: string, parent: Instance, size: number, color: Color3, accent: Color3?, anchorPos: UDim2?): Frame?
	local fn = Icons.Registry[name]
	if not fn then
		warn(string.format("[PAW MAYHEM] Icons.Place: unknown icon '%s'", tostring(name)))
		return nil
	end
	local ok, iconOrErr = pcall(fn, size, color, accent)
	if not ok then
		warn(string.format("[PAW MAYHEM] Icons.Place('%s') failed (non-fatal, skipped): %s", tostring(name), tostring(iconOrErr)))
		return nil
	end
	local icon = iconOrErr :: Frame
	local ok2, err2 = pcall(function()
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = anchorPos or UDim2.fromScale(0.5, 0.5)
		icon.Parent = parent
	end)
	if not ok2 then
		warn(string.format("[PAW MAYHEM] Icons.Place('%s') failed to parent (non-fatal, skipped): %s", tostring(name), tostring(err2)))
		pcall(function() icon:Destroy() end)
		return nil
	end
	return icon
end

return Icons
