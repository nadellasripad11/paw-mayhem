--!strict
-- loadout: the weapons screen (see design/features/weapons-and-shop). a list
-- of blasters down the left (a rarity strip on each row, the equipped one in
-- gold, locked ones dimmed with a lock and their price), the selected blaster
-- big in the middle in 3d over a soft glow in its rarity colour, its details
-- on the right (rarity chip, gold stat bars, what it's good at, the skins you
-- own for it), and along the bottom the action (equip / buy) and skins, which
-- opens a strip of skins for it. selecting a blaster only shows it; the
-- bottom button equips.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local BlasterBuilder = require(ReplicatedStorage.Shared.Character.BlasterBuilder)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local GunView = require(script.Parent.Parent.GunView)
local Orbit = require(script.Parent.Parent.Orbit)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local ClientActions = require(script.Parent.Parent.Parent.ClientActions)
local Monetize = require(script.Parent.Parent.Parent.Monetize)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)

local Loadout = {}

local GOLD = Theme.Color.Gold
local DIM = Theme.Color.TextDim

local STATS = {
	{ key = "Damage", label = "DAMAGE" },
	{ key = "FireRate", label = "FIRE RATE" },
	{ key = "Knockback", label = "KNOCKBACK" },
	{ key = "Range", label = "RANGE" },
	{ key = "Accuracy", label = "ACCURACY" },
}

-- one line that says what the numbers mean: from the blaster's best stat.
local BEST_FOR = {
	Damage = "big hits that end fights fast",
	FireRate = "spraying up close",
	Knockback = "launching cats off the map",
	Range = "long range",
	Accuracy = "picking off far targets",
}

local function rarityColor(r: string?): Color3
	if r == "Legendary" then
		return GOLD
	end
	return (r and Theme.Rarity[r]) or Theme.Rarity.Common
end

local function equippedWeapon(): string
	return ClientState.Equipped("Weapon") or Weapons.DefaultLoadout
end

local function panel(props: { [string]: any }): Frame
	local f = UIUtil.make("Frame", props) :: Frame
	f.BackgroundColor3 = Theme.Color.Surface
	f.BackgroundTransparency = 0.04
	f.BorderSizePixel = 0
	UIUtil.corner(UDim.new(0, 10), f)
	UIUtil.hairline(f)
	return f
end

-- a small padlock drawn from frames (body + shackle).
local function lock(parent: Instance, color: Color3, z: number): Frame
	local holder = UIUtil.make("Frame", { Parent = parent, Size = UDim2.fromOffset(14, 16), BackgroundTransparency = 1, ZIndex = z }) :: Frame
	local shackle = UIUtil.make("Frame", {
		Parent = holder, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(9, 10),
		BackgroundTransparency = 1, ZIndex = z,
	})
	UIUtil.corner(UDim.new(1, 0), shackle)
	UIUtil.stroke(color, 2, shackle)
	local body = UIUtil.make("Frame", {
		Parent = holder, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(14, 10), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z + 1,
	})
	UIUtil.corner(UDim.new(0, 3), body)
	return holder
end

function Loadout.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	local selected = equippedWeapon()

	-- ── left: the list ────────────────────────────────────────────────────────
	local listPanel = panel({ Parent = root, Size = UDim2.new(0.26, 0, 1, 0) })
	UIUtil.label({
		Parent = listPanel, Text = "BLASTERS", Font = Theme.Font.Title, TextSize = 16, TextColor3 = DIM,
		Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -32, 0, 40),
	})
	local list = UIUtil.make("ScrollingFrame", {
		Parent = listPanel, Position = UDim2.fromOffset(8, 40), Size = UDim2.new(1, -12, 1, -48), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Color.Surface3, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}) :: ScrollingFrame
	UIUtil.listLayout(list, 8)
	local rows: { [string]: { button: TextButton, name: TextLabel, tag: TextLabel, lock: Frame, stroke: UIStroke, gun: ViewportFrame, def: any } } = {}

	-- ── middle: the blaster ───────────────────────────────────────────────────
	local stage = UIUtil.make("Frame", {
		Parent = root, Position = UDim2.new(0.27, 0, 0, 0), Size = UDim2.new(0.46, 0, 1, -76), BackgroundTransparency = 1,
	}) :: Frame
	-- a soft glow on the floor under the gun, in its rarity colour (no circle).
	local glow = UIUtil.make("Frame", {
		Parent = stage, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(0.7, 0.07),
		BackgroundTransparency = 0.6, BorderSizePixel = 0,
	}) :: Frame
	glow:SetAttribute("NoPolish", true)
	UIUtil.corner(UDim.new(1, 0), glow)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = glow
	local vf = GunView.Create(stage, selected, ClientState.Equipped("Skin"), UDim2.fromScale(0.9, 0.9), UDim2.fromScale(0.05, 0.02))
	Orbit.Enable(stage, vf) -- drag to look all round it, wheel to zoom
	UIUtil.label({
		Parent = stage, Text = "Drag to look around", Font = Theme.Font.Bold, TextSize = 12, TextColor3 = DIM,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 0, 0, 16),
	})

	-- ── bottom: action + skins ────────────────────────────────────────────────
	local actions = UIUtil.make("Frame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(420, 64),
		BackgroundTransparency = 1,
	}) :: Frame
	local action = UIUtil.make("TextButton", {
		Parent = actions, Text = "", Font = Theme.Font.Title, TextSize = 20, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(0, 4), Size = UDim2.new(0.62, -6, 1, -8), BackgroundColor3 = Theme.Color.PlayGreen,
		AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 2,
	}) :: TextButton
	UIUtil.corner(Theme.CornerSmall, action)
	-- (the gloss is ours to switch: only a real equip / buy shines)
	action:SetAttribute("NoPolish", true)
	UIUtil.gloss(action, Theme.Color.PlayGreen)
	UIUtil.feedback(action, 1.03)
	local actionStroke = action:FindFirstChildOfClass("UIStroke") :: UIStroke
	local actionShine = action:FindFirstChild("Shine") :: GuiObject?
	local actionGrad = action:FindFirstChildOfClass("UIGradient")
	local skinsBtn = UIUtil.make("TextButton", {
		Parent = actions, Text = "SKINS", Font = Theme.Font.Title, TextSize = 16, TextColor3 = GOLD,
		Position = UDim2.new(0.62, 6, 0, 10), Size = UDim2.new(0.38, -6, 1, -20), BackgroundColor3 = Theme.Color.Surface2,
		AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 2,
	}) :: TextButton
	UIUtil.corner(Theme.CornerSmall, skinsBtn)
	UIUtil.hairline(skinsBtn)
	UIUtil.feedback(skinsBtn, 1.03)

	local skinStrip = UIUtil.make("ScrollingFrame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -72), Size = UDim2.new(0.46, 0, 0, 120),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, Visible = false,
	}) :: ScrollingFrame
	UIUtil.listLayout(skinStrip, 8, Enum.FillDirection.Horizontal)

	-- ── right: details ────────────────────────────────────────────────────────
	local info = panel({ Parent = root, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.26, 0, 0, 420) })
	local nameLabel = UIUtil.label({ Parent = info, Text = "", Font = Theme.Font.Title, TextSize = 22, Position = UDim2.fromOffset(16, 14), Size = UDim2.new(1, -32, 0, 26) })
	local chip = UIUtil.label({
		Parent = info, Text = "", Font = Theme.Font.Title, TextSize = 13, TextColor3 = Color3.fromRGB(20, 18, 28), TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(16, 46), Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0,
	})
	UIUtil.corner(UDim.new(1, 0), chip)
	local chipPad = Instance.new("UIPadding")
	chipPad.PaddingLeft = UDim.new(0, 10)
	chipPad.PaddingRight = UDim.new(0, 10)
	chipPad.Parent = chip
	local classLabel = UIUtil.label({ Parent = info, Text = "", Font = Theme.Font.Bold, TextSize = 13, TextColor3 = DIM, Position = UDim2.fromOffset(16, 46), Size = UDim2.new(1, -32, 0, 20), TextXAlignment = Enum.TextXAlignment.Right })
	local statusLabel = UIUtil.label({ Parent = info, Text = "", Font = Theme.Font.Bold, TextSize = 13, TextColor3 = DIM, Position = UDim2.fromOffset(16, 72), Size = UDim2.new(1, -32, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd })
	local fills: { [string]: Frame } = {}
	for i, stat in ipairs(STATS) do
		local y = 100 + (i - 1) * 36
		UIUtil.label({ Parent = info, Text = stat.label, Font = Theme.Font.Title, TextSize = 13, TextColor3 = DIM, Position = UDim2.fromOffset(16, y), Size = UDim2.new(1, -32, 0, 16) })
		local track = UIUtil.make("Frame", { Parent = info, Position = UDim2.fromOffset(16, y + 19), Size = UDim2.new(1, -32, 0, 6), BackgroundColor3 = Theme.Color.Surface3, BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(1, 0), track)
		local fill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = GOLD, BorderSizePixel = 0 }) :: Frame
		UIUtil.corner(UDim.new(1, 0), fill)
		fills[stat.key] = fill
	end
	local line = UIUtil.make("Frame", { Parent = info, Position = UDim2.fromOffset(16, 286), Size = UDim2.new(1, -32, 0, 1), BackgroundColor3 = Theme.Color.Line, BackgroundTransparency = 0.9, BorderSizePixel = 0 })
	line:SetAttribute("NoPolish", true)
	UIUtil.label({ Parent = info, Text = "BEST FOR", Font = Theme.Font.Title, TextSize = 13, TextColor3 = DIM, Position = UDim2.fromOffset(16, 298), Size = UDim2.new(1, -32, 0, 16) })
	local bestLabel = UIUtil.label({ Parent = info, Text = "", Font = Theme.Font.Bold, TextSize = 15, Position = UDim2.fromOffset(16, 316), Size = UDim2.new(1, -32, 0, 36), TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	UIUtil.label({ Parent = info, Text = "YOUR SKINS", Font = Theme.Font.Title, TextSize = 13, TextColor3 = DIM, Position = UDim2.fromOffset(16, 356), Size = UDim2.new(1, -32, 0, 16) })
	local swatches = UIUtil.make("Frame", { Parent = info, Position = UDim2.fromOffset(16, 376), Size = UDim2.new(1, -32, 0, 24), BackgroundTransparency = 1 }) :: Frame
	UIUtil.listLayout(swatches, 6, Enum.FillDirection.Horizontal)

	local function paintSwatches(w: any)
		for _, c in ipairs(swatches:GetChildren()) do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		local n = 0
		for _, skin in ipairs(Weapons.Skins) do
			if ClientState.Owns("Skin", skin.Id) and n < 8 then
				n += 1
				local pal = BlasterBuilder.PaletteFor(w.Id, skin.Id)
				local sw = UIUtil.make("Frame", { Parent = swatches, LayoutOrder = n, Size = UDim2.fromOffset(22, 22), BackgroundColor3 = pal.Body, BorderSizePixel = 0 })
				UIUtil.corner(UDim.new(0, 6), sw)
				local on = ClientState.Equipped("Skin") == skin.Id
				UIUtil.stroke(on and GOLD or Theme.Color.Line, on and 2 or 1, sw).Transparency = on and 0 or 0.8
			end
		end
		if n == 0 then
			UIUtil.label({ Parent = swatches, Text = "None yet: open SKINS", Font = Theme.Font.Bold, TextSize = 13, TextColor3 = DIM, Size = UDim2.new(1, 0, 1, 0) })
		end
	end

	-- the button's look: "go" (green gloss), or owned / disabled (flat, dim).
	local function actionLook(go: boolean)
		action.BackgroundColor3 = go and Theme.Color.PlayGreen or Theme.Color.Surface2
		action.TextColor3 = go and Color3.new(1, 1, 1) or DIM
		action.Active = go
		if actionShine then
			actionShine.Visible = go
		end
		if actionGrad then
			actionGrad.Enabled = go
		end
		if actionStroke then
			actionStroke.Color = go and Theme.Color.PlayGreen:Lerp(Color3.new(0, 0, 0), 0.5) or Theme.Color.Line
			actionStroke.Transparency = go and 0.1 or Theme.LineAlpha
			actionStroke.Thickness = go and 2.6 or 1
		end
		action.TextStrokeTransparency = go and 0.3 or 1
	end

	local function canAfford(w: any): boolean
		local p = ClientState.Profile
		if not p then
			return true
		end
		if (w.GemCost or 0) > 0 then
			return (p.Gems or 0) >= w.GemCost
		end
		return (p.Coins or 0) >= (w.CoinCost or 0)
	end

	-- ── behaviour ─────────────────────────────────────────────────────────────
	local function show()
		local w = Weapons.Get(selected) or Weapons.Get(Weapons.DefaultLoadout)
		local owned = ClientState.Owns("Weapon", w.Id)
		local equipped = ClientState.Equipped("Weapon") == w.Id
		local skin = ClientState.Equipped("Skin")
		local rc = rarityColor(w.Rarity)
		GunView.Set(vf, w.Id, skin)
		glow.BackgroundColor3 = rc
		nameLabel.Text = string.upper(w.Name)
		chip.Text = string.upper(tostring(w.Rarity or "Common"))
		chip.BackgroundColor3 = rc
		classLabel.Text = tostring(w.Class)
		local bestKey, bestVal = "Damage", -1
		for key, fill in pairs(fills) do
			local v = w.Bars and w.Bars[key] or 0
			fill.Size = UDim2.fromScale(math.clamp(v, 0.04, 1), 1)
			if v > bestVal then
				bestKey, bestVal = key, v
			end
		end
		bestLabel.Text = string.upper(string.sub(BEST_FOR[bestKey], 1, 1)) .. string.sub(BEST_FOR[bestKey], 2)
		paintSwatches(w)
		local robuxKey = Monetize.UnlockKey("Weapon", w.Id)
		local product = robuxKey and Monetization.Products[robuxKey]
		if equipped then
			action.Text = "EQUIPPED"
			actionLook(false)
			statusLabel.Text = "In your hands"
			statusLabel.TextColor3 = DIM
		elseif owned then
			action.Text = "EQUIP"
			actionLook(true)
			statusLabel.Text = "Owned"
			statusLabel.TextColor3 = DIM
		else
			local price = Monetize.PriceTag(w)
			action.Text = "BUY  " .. tostring(price)
			-- (short on coins: still green, buy falls back to robux)
			actionLook(true)
			local lvl = w.UnlockLevel and w.UnlockLevel > 0 and ("Level " .. w.UnlockLevel .. "  ·  ") or ""
			local short = not canAfford(w)
			statusLabel.Text = (short and "Not enough yet  ·  " or "Locked  ·  ") .. lvl .. (product and ("or R$" .. product.Price) or "")
			statusLabel.TextColor3 = short and Theme.Color.Red or DIM
		end
		for id, r in pairs(rows) do
			local isSel = id == selected
			local isEq = ClientState.Equipped("Weapon") == id
			local own = ClientState.Owns("Weapon", id)
			r.button.BackgroundTransparency = isSel and 0 or 1
			r.stroke.Color = isEq and GOLD or Theme.Color.Line
			r.stroke.Transparency = isEq and 0 or (isSel and 0.8 or 1)
			r.stroke.Thickness = isEq and 1.5 or 1
			r.name.TextColor3 = own and Theme.Color.Text or DIM
			r.lock.Visible = not own
			r.gun.ImageTransparency = own and 0 or 0.45
			if isEq then
				r.tag.Text = "EQUIPPED"
				r.tag.TextColor3 = GOLD
			elseif own then
				r.tag.Text = ""
			else
				local price, col = Monetize.PriceTag(r.def)
				r.tag.Text = tostring(price)
				r.tag.TextColor3 = canAfford(r.def) and col or Theme.Color.Red
			end
		end
	end

	for order, w in ipairs(Weapons.List) do
		local b = UIUtil.make("TextButton", {
			Parent = list, LayoutOrder = order, Text = "", AutoButtonColor = false, Size = UDim2.new(1, -8, 0, 56),
			BackgroundColor3 = Theme.Color.Surface2, BackgroundTransparency = 1, BorderSizePixel = 0,
		}) :: TextButton
		b:SetAttribute("NoPolish", true)
		UIUtil.corner(Theme.CornerSmall, b)
		local stroke = UIUtil.hairline(b)
		stroke.Transparency = 1
		-- rarity strip on the left edge
		local strip = UIUtil.make("Frame", {
			Parent = b, Position = UDim2.fromOffset(0, 8), Size = UDim2.new(0, 4, 1, -16), BackgroundColor3 = rarityColor(w.Rarity), BorderSizePixel = 0, ZIndex = 2,
		})
		UIUtil.corner(UDim.new(1, 0), strip)
		local gun = GunView.Create(b, w.Id, nil, UDim2.fromOffset(64, 48), UDim2.fromOffset(10, 4))
		local name = UIUtil.label({
			Parent = b, Text = w.Name, Font = Theme.Font.Title, TextSize = 16, Position = UDim2.fromOffset(80, 8),
			Size = UDim2.new(1, -88, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local tag = UIUtil.label({
			Parent = b, Text = "", Font = Theme.Font.Title, TextSize = 13, Position = UDim2.fromOffset(98, 30),
			Size = UDim2.new(1, -106, 0, 16), TextColor3 = DIM,
		})
		local lk = lock(b, DIM, 3)
		lk.Position = UDim2.fromOffset(80, 30)
		b.MouseButton1Click:Connect(function()
			selected = w.Id
			show()
		end)
		rows[w.Id] = { button = b, name = name, tag = tag, lock = lk, stroke = stroke, gun = gun, def = w }
	end
	-- (a row with no lock shows its tag where the lock was)
	local oldShowRows = show
	show = function()
		oldShowRows()
		for _, r in pairs(rows) do
			r.tag.Position = UDim2.fromOffset(r.lock.Visible and 98 or 80, 30)
			r.name.Position = UDim2.fromOffset(80, r.tag.Text == "" and 18 or 8)
		end
	end

	action.MouseButton1Click:Connect(function()
		local w = Weapons.Get(selected)
		if not w or ClientState.Equipped("Weapon") == w.Id then
			return
		end
		if ClientState.Owns("Weapon", w.Id) then
			ClientActions.Equip("Weapon", w.Id)
		elseif Monetize.Buy("Weapon", w.Id, w) then
			ClientActions.Equip("Weapon", w.Id)
		end
	end)

	-- skins for the blaster you're looking at.
	local skinCards = {}
	for order, skin in ipairs(Weapons.Skins) do
		local card = UIUtil.make("TextButton", {
			Parent = skinStrip, LayoutOrder = order, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(110, 112),
			BackgroundColor3 = Theme.Color.Surface, BorderSizePixel = 0,
		}) :: TextButton
		card:SetAttribute("NoPolish", true)
		UIUtil.corner(Theme.CornerSmall, card)
		local stroke = UIUtil.stroke(Theme.Color.Line, 1, card)
		local svf = GunView.Create(card, selected, skin.Id, UDim2.new(1, 0, 0, 76), UDim2.new())
		local label = UIUtil.label({
			Parent = card, Text = skin.Name, Font = Theme.Font.Bold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(4, 78), Size = UDim2.new(1, -8, 0, 14),
		})
		local price = UIUtil.label({
			Parent = card, Text = "", Font = Theme.Font.Title, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(4, 94), Size = UDim2.new(1, -8, 0, 12),
		})
		UIUtil.feedback(card, 1.04)
		card.MouseButton1Click:Connect(function()
			if ClientState.Owns("Skin", skin.Id) then
				ClientActions.Equip("Skin", skin.Id)
			elseif Monetize.Buy("Skin", skin.Id, skin) then
				ClientActions.Equip("Skin", skin.Id)
			end
		end)
		table.insert(skinCards, { skin = skin, vf = svf, stroke = stroke, label = label, price = price })
	end
	local function paintSkins()
		for _, c in ipairs(skinCards) do
			GunView.Set(c.vf, selected, c.skin.Id)
			local owned = ClientState.Owns("Skin", c.skin.Id)
			local on = ClientState.Equipped("Skin") == c.skin.Id
			c.stroke.Color = on and GOLD or Theme.Color.Line
			c.stroke.Transparency = on and 0 or 0.85
			c.stroke.Thickness = on and 2 or 1
			local tagText, tagColor = Monetize.PriceTag(c.skin)
			c.price.Text = on and "EQUIPPED" or owned and "OWNED" or tostring(tagText)
			c.price.TextColor3 = on and GOLD or owned and DIM or tagColor
		end
	end
	skinsBtn.MouseButton1Click:Connect(function()
		skinStrip.Visible = not skinStrip.Visible
		skinsBtn.Text = skinStrip.Visible and "HIDE SKINS" or "SKINS"
		if skinStrip.Visible then
			paintSkins()
		end
	end)

	local function refresh()
		show()
		if skinStrip.Visible then
			paintSkins()
		end
	end
	local oldShow = show
	show = function()
		oldShow()
		if skinStrip.Visible then
			paintSkins()
		end
	end
	refresh()
	ClientState.ProfileChanged:Connect(refresh)
	Loadout.Root = root
	return root
end

return Loadout
