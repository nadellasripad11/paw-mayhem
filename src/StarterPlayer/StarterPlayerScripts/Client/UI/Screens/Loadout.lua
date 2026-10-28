--!strict
-- loadout: the weapons screen, laid out like rivals. a list of blasters down
-- the left (yours in white, the equipped one highlighted, locked ones in gold
-- with a lock either side), the selected blaster big in the middle in 3d,
-- its details and stat bars on the right, and along the bottom the action
-- (equip / unlock for coins or gems / r$) and skins, which opens a strip of
-- skins for it. selecting a blaster only shows it; the bottom button equips.

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

local GOLD = Color3.fromRGB(255, 196, 60)
local EQUIP_GREEN = Color3.fromRGB(150, 235, 110)
local PANEL = Color3.fromRGB(14, 18, 28)

local CLASS_COLOR = {
	Balanced = Color3.fromRGB(196, 156, 255), Epic = Color3.fromRGB(170, 124, 255), Heavy = Color3.fromRGB(255, 152, 72),
	Fast = Color3.fromRGB(255, 124, 230), Ice = Color3.fromRGB(120, 222, 255), Legendary = Color3.fromRGB(196, 112, 255),
	Fun = Color3.fromRGB(255, 152, 216), Premium = Color3.fromRGB(255, 206, 82), Exclusive = Color3.fromRGB(255, 90, 160),
}

local STATS = {
	{ key = "Damage", label = "Damage" },
	{ key = "FireRate", label = "Fire Rate" },
	{ key = "Knockback", label = "Knockback" },
	{ key = "Range", label = "Range" },
	{ key = "Accuracy", label = "Accuracy" },
}

local function equippedWeapon(): string
	return ClientState.Equipped("Weapon") or Weapons.DefaultLoadout
end

local function panel(props: { [string]: any }): Frame
	local f = UIUtil.make("Frame", props) :: Frame
	f.BackgroundColor3 = PANEL
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	UIUtil.corner(UDim.new(0, 12), f)
	UIUtil.hairline(f)
	return f
end

function Loadout.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	local selected = equippedWeapon()

	-- ── left: the list ────────────────────────────────────────────────────────
	local listPanel = panel({ Parent = root, Size = UDim2.new(0.26, 0, 1, 0) })
	UIUtil.label({
		Parent = listPanel, Text = "BLASTERS", Font = Theme.Font.Title, TextSize = 18, TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 40),
	})
	local list = UIUtil.make("ScrollingFrame", {
		Parent = listPanel, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 1, -48), BackgroundTransparency = 1,
		BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = Theme.Color.Stroke, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}) :: ScrollingFrame
	UIUtil.listLayout(list, 4)
	local rows: { [string]: { button: TextButton, name: TextLabel, def: any } } = {}

	-- ── middle: the blaster ───────────────────────────────────────────────────
	local stage = UIUtil.make("Frame", {
		Parent = root, Position = UDim2.new(0.27, 0, 0, 0), Size = UDim2.new(0.46, 0, 1, -76), BackgroundTransparency = 1,
	}) :: Frame
	local glow = UIUtil.make("Frame", {
		Parent = stage, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.8, 0.8),
		BackgroundTransparency = 0.9, BorderSizePixel = 0,
	}) :: Frame
	UIUtil.corner(UDim.new(1, 0), glow)
	local vf = GunView.Create(stage, selected, ClientState.Equipped("Skin"), UDim2.fromScale(1, 1), UDim2.new())
	Orbit.Enable(stage, vf) -- drag to look all round it, wheel to zoom
	UIUtil.label({
		Parent = stage, Text = "Drag to look around", Font = Theme.Font.Bold, TextSize = 12, TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, 0, 0, 16),
	})

	-- ── bottom: action + skins ────────────────────────────────────────────────
	local actions = UIUtil.make("Frame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.fromOffset(420, 64),
		BackgroundTransparency = 1,
	}) :: Frame
	local actBg = panel({ Parent = actions, Size = UDim2.fromScale(1, 1) })
	actBg.ZIndex = 1
	local action = UIUtil.make("TextButton", {
		Parent = actions, Text = "", Font = Theme.Font.Title, TextSize = 20, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(10, 10), Size = UDim2.new(0.62, -15, 1, -20), BackgroundColor3 = Theme.Color.PlayGreen,
		AutoButtonColor = true, BorderSizePixel = 0, ZIndex = 2,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 10), action)
	local skinsBtn = UIUtil.make("TextButton", {
		Parent = actions, Text = "SKINS", Font = Theme.Font.Title, TextSize = 18, TextColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0.62, 5, 0, 10), Size = UDim2.new(0.38, -15, 1, -20), BackgroundColor3 = Theme.Color.Blue,
		AutoButtonColor = true, BorderSizePixel = 0, ZIndex = 2,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 10), skinsBtn)

	local skinStrip = UIUtil.make("ScrollingFrame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -72), Size = UDim2.new(0.46, 0, 0, 120),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollingDirection = Enum.ScrollingDirection.X,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, Visible = false,
	}) :: ScrollingFrame
	UIUtil.listLayout(skinStrip, 8, Enum.FillDirection.Horizontal)

	-- ── right: details ────────────────────────────────────────────────────────
	local info = panel({ Parent = root, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.26, 0, 0, 300) })
	local nameLabel = UIUtil.label({ Parent = info, Text = "", Font = Theme.Font.Title, TextSize = 24, Position = UDim2.fromOffset(14, 12), Size = UDim2.new(1, -28, 0, 28) })
	local classLabel = UIUtil.label({ Parent = info, Text = "", Font = Theme.Font.Bold, TextSize = 13, Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -28, 0, 16) })
	local statusLabel = UIUtil.label({ Parent = info, Text = "", Font = Theme.Font.Bold, TextSize = 13, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(14, 62), Size = UDim2.new(1, -28, 0, 16) })
	local fills: { [string]: Frame } = {}
	for i, stat in ipairs(STATS) do
		local y = 96 + (i - 1) * 38
		UIUtil.label({ Parent = info, Text = stat.label, Font = Theme.Font.Bold, TextSize = 13, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, 16) })
		local track = UIUtil.make("Frame", { Parent = info, Position = UDim2.fromOffset(14, y + 19), Size = UDim2.new(1, -28, 0, 8), BackgroundColor3 = Color3.fromRGB(30, 36, 50), BorderSizePixel = 0 })
		UIUtil.corner(UDim.new(1, 0), track)
		local fill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }) :: Frame
		UIUtil.corner(UDim.new(1, 0), fill)
		UIUtil.gradient(Color3.fromRGB(70, 214, 255), Color3.fromRGB(46, 128, 255), 0, fill)
		fills[stat.key] = fill
	end

	-- ── behaviour ─────────────────────────────────────────────────────────────
	local function show()
		local w = Weapons.Get(selected) or Weapons.Get(Weapons.DefaultLoadout)
		local owned = ClientState.Owns("Weapon", w.Id)
		local equipped = ClientState.Equipped("Weapon") == w.Id
		local skin = ClientState.Equipped("Skin")
		GunView.Set(vf, w.Id, skin)
		glow.BackgroundColor3 = BlasterBuilder.PaletteFor(w.Id, skin).Glow
		nameLabel.Text = w.Name
		classLabel.Text = string.upper(tostring(w.Rarity or "")) .. "  ·  " .. tostring(w.Class)
		classLabel.TextColor3 = CLASS_COLOR[w.Class] or Theme.Color.Accent
		for key, fill in pairs(fills) do
			fill.Size = UDim2.fromScale(math.clamp(w.Bars and w.Bars[key] or 0, 0.04, 1), 1)
		end
		local robuxKey = Monetize.UnlockKey("Weapon", w.Id)
		local product = robuxKey and Monetization.Products[robuxKey]
		if equipped then
			action.Text = "EQUIPPED"
			action.BackgroundColor3 = Color3.fromRGB(50, 60, 80)
			statusLabel.Text = "In your hands"
		elseif owned then
			action.Text = "EQUIP"
			action.BackgroundColor3 = Theme.Color.PlayGreen
			statusLabel.Text = "Owned"
		else
			local price = Monetize.PriceTag(w)
			action.Text = "UNLOCK  " .. tostring(price)
			action.BackgroundColor3 = GOLD:Lerp(Color3.new(0, 0, 0), 0.15)
			local lvl = w.UnlockLevel and w.UnlockLevel > 0 and ("Level " .. w.UnlockLevel .. "  ·  ") or ""
			statusLabel.Text = "Locked  ·  " .. lvl .. (product and ("or R$" .. product.Price) or "")
		end
		for id, r in pairs(rows) do
			local isSel = id == selected
			local isEq = ClientState.Equipped("Weapon") == id
			local own = ClientState.Owns("Weapon", id)
			r.button.BackgroundTransparency = isSel and 0.1 or 1
			r.name.TextColor3 = own and (isEq and EQUIP_GREEN or Color3.new(1, 1, 1)) or GOLD
			r.name.Text = own and r.def.Name or ("LOCKED  ·  " .. r.def.Name)
		end
	end

	for order, w in ipairs(Weapons.List) do
		local b = UIUtil.make("TextButton", {
			Parent = list, LayoutOrder = order, Text = "", AutoButtonColor = false, Size = UDim2.new(1, -8, 0, 52),
			BackgroundColor3 = Color3.fromRGB(40, 60, 100), BackgroundTransparency = 1, BorderSizePixel = 0,
		}) :: TextButton
		UIUtil.corner(UDim.new(0, 8), b)
		GunView.Create(b, w.Id, nil, UDim2.fromOffset(64, 48), UDim2.fromOffset(4, 2))
		local name = UIUtil.label({
			Parent = b, Text = w.Name, Font = Theme.Font.Title, TextSize = 16, Position = UDim2.fromOffset(72, 0),
			Size = UDim2.new(1, -76, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd,
		})
		b.MouseButton1Click:Connect(function()
			selected = w.Id
			show()
		end)
		rows[w.Id] = { button = b, name = name, def = w }
	end

	action.MouseButton1Click:Connect(function()
		local w = Weapons.Get(selected)
		if not w then
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
			BackgroundColor3 = PANEL, BorderSizePixel = 0,
		}) :: TextButton
		UIUtil.corner(UDim.new(0, 10), card)
		local stroke = UIUtil.stroke(Color3.fromRGB(60, 70, 90), 1.5, card)
		local svf = GunView.Create(card, selected, skin.Id, UDim2.new(1, 0, 0, 76), UDim2.new())
		local label = UIUtil.label({
			Parent = card, Text = skin.Name, Font = Theme.Font.Bold, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(4, 78), Size = UDim2.new(1, -8, 0, 14),
		})
		local price = UIUtil.label({
			Parent = card, Text = "", Font = Theme.Font.Bold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(4, 94), Size = UDim2.new(1, -8, 0, 12),
		})
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
			c.stroke.Color = on and EQUIP_GREEN or (owned and Color3.fromRGB(60, 70, 90) or GOLD)
			c.stroke.Thickness = on and 2.5 or 1.5
			c.price.Text = on and "EQUIPPED" or owned and "OWNED" or tostring((Monetize.PriceTag(c.skin)))
			c.price.TextColor3 = on and EQUIP_GREEN or owned and Theme.Color.TextDim or GOLD
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
