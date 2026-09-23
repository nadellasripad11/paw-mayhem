--!strict
-- Loadout: weapon + weapon-skin catalog. Every card shows a live 3D blaster
-- (GunView) over a soft glow; weapon cards list the real stat bars, skin cards
-- show your equipped weapon in that skin's colours. Clicking a card buys it if
-- needed, then equips it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local BlasterBuilder = require(ReplicatedStorage.Shared.Character.BlasterBuilder)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local GunView = require(script.Parent.Parent.GunView)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local ClientActions = require(script.Parent.Parent.Parent.ClientActions)
local Monetize = require(script.Parent.Parent.Parent.Monetize)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)

local Loadout = {}

local CARD_BG = Color3.fromRGB(16, 32, 60)
local CARD_STROKE = Color3.fromRGB(42, 72, 114)
local EQUIP_GREEN = Color3.fromRGB(182, 241, 112)
local TAB_ON = Theme.Color.Accent
local TAB_OFF = Color3.fromRGB(20, 40, 70)

local CLASS_COLOR = {
	Balanced = Color3.fromRGB(196, 156, 255),
	Epic = Color3.fromRGB(170, 124, 255),
	Heavy = Color3.fromRGB(255, 152, 72),
	Fast = Color3.fromRGB(255, 124, 230),
	Ice = Color3.fromRGB(120, 222, 255),
	Legendary = Color3.fromRGB(196, 112, 255),
	Fun = Color3.fromRGB(255, 152, 216),
	Premium = Color3.fromRGB(255, 206, 82),
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

-- Dark card with a gradient stage, a soft coloured glow and a live 3D gun.
local function cardShell(parent: Instance, stageH: number, weaponId: string, skinId: string?)
	local card = UIUtil.make("TextButton", {
		Parent = parent, Text = "", AutoButtonColor = false, BackgroundColor3 = CARD_BG, BorderSizePixel = 0,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 12), card)
	local stroke = UIUtil.stroke(CARD_STROKE, 1.5, card)

	local stage = UIUtil.make("Frame", {
		Parent = card, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, stageH),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ClipsDescendants = true,
	}) :: Frame
	UIUtil.corner(UDim.new(0, 9), stage)
	UIUtil.gradient(Color3.fromRGB(30, 54, 96), Color3.fromRGB(12, 24, 48), 90, stage)
	local glowOuter = UIUtil.make("Frame", {
		Parent = stage, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.95, 0.9), BackgroundTransparency = 0.86, BorderSizePixel = 0,
	}) :: Frame
	UIUtil.corner(UDim.new(1, 0), glowOuter)
	local glowInner = UIUtil.make("Frame", {
		Parent = stage, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55),
		Size = UDim2.fromScale(0.6, 0.55), BackgroundTransparency = 0.78, BorderSizePixel = 0,
	}) :: Frame
	UIUtil.corner(UDim.new(1, 0), glowInner)
	local vf = GunView.Create(stage, weaponId, skinId, UDim2.fromScale(1, 1), UDim2.new())

	local function setGun(wId: string, sId: string?)
		local glow = BlasterBuilder.PaletteFor(wId, sId).Glow
		glowOuter.BackgroundColor3 = glow
		glowInner.BackgroundColor3 = glow
		GunView.Set(vf, wId, sId)
	end
	local startGlow = BlasterBuilder.PaletteFor(weaponId, skinId).Glow
	glowOuter.BackgroundColor3 = startGlow
	glowInner.BackgroundColor3 = startGlow

	-- Top-right status pill: EQUIPPED / OWNED / coin price.
	local pill = UIUtil.make("Frame", {
		Parent = stage, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(0, 20), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(8, 16, 32), BackgroundTransparency = 0.15, BorderSizePixel = 0,
	}) :: Frame
	UIUtil.corner(UDim.new(1, 0), pill)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = pill
	local layout = UIUtil.listLayout(pill, 3, Enum.FillDirection.Horizontal)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	local coinSlot = UIUtil.make("Frame", { Parent = pill, Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, LayoutOrder = 1 })
	Icons.Place("Coin", coinSlot, 14, Theme.Color.Coin)
	local gemSlot = UIUtil.make("Frame", { Parent = pill, Size = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, LayoutOrder = 1, Visible = false })
	Icons.Place("Gem", gemSlot, 14, Theme.Color.Gem)
	local pillText = UIUtil.label({
		Parent = pill, Text = "", Font = Theme.Font.Bold, TextSize = 11,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 14), LayoutOrder = 2,
	})

	local hovered = false
	local isEquipped = false
	local function paintStroke()
		stroke.Color = isEquipped and EQUIP_GREEN or (hovered and Color3.fromRGB(96, 150, 210) or CARD_STROKE)
		stroke.Thickness = isEquipped and 2.5 or 1.5
	end
	card.MouseEnter:Connect(function()
		hovered = true
		paintStroke()
	end)
	card.MouseLeave:Connect(function()
		hovered = false
		paintStroke()
	end)

	local function setStatus(owned: boolean, equipped: boolean, def: any, robuxKey: string?)
		isEquipped = equipped
		paintStroke()
		card.BackgroundColor3 = equipped and Color3.fromRGB(20, 52, 62) or CARD_BG
		local cost = def.CoinCost or 0
		local gems = def.GemCost or 0
		local special = def.PassOnly or def.Season
		coinSlot.Visible = not owned and not special and gems == 0 and cost > 0
		gemSlot.Visible = not owned and not special and gems > 0
		if equipped then
			pillText.Text = "EQUIPPED"
			pillText.TextColor3 = EQUIP_GREEN
		elseif owned then
			pillText.Text = "OWNED"
			pillText.TextColor3 = Theme.Color.TextDim
		else
			local price, color = Monetize.PriceTag(def)
			if def.PassOnly or def.Season then
				pillText.Text = price
			elseif gems > 0 or cost > 0 then
				pillText.Text = tostring(gems > 0 and gems or cost)
			else
				pillText.Text = "FREE"
			end
			local product = robuxKey and Monetization.Products[robuxKey]
			if product then
				-- Short on coins/gems? Tapping the card offers the Robux unlock.
				pillText.Text ..= "  or R$" .. tostring(product.Price)
			end
			pillText.TextColor3 = color
		end
	end

	return card, setStatus, setGun
end

local function buyOrEquip(kind: string, id: string)
	if ClientState.Owns(kind, id) then
		ClientActions.Equip(kind, id)
	else
		local def = kind == "Weapon" and Weapons.Get(id) or Weapons.GetSkin(id)
		if Monetize.Buy(kind, id, def) then
			ClientActions.Equip(kind, id)
		end
	end
end

function Loadout.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	local board = UIUtil.panel({
		Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -24, 1, -24), BackgroundColor3 = Color3.fromRGB(10, 22, 44), ClipsDescendants = true,
	})
	UIUtil.padding(14, board)

	local header = UIUtil.make("Frame", { Parent = board, Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1 })
	local gunSlot = UIUtil.make("Frame", { Parent = header, Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1 })
	Icons.Place("Gun", gunSlot, 26, Theme.Color.Accent)
	local title = UIUtil.label({ Parent = header, Text = "WEAPONS", Font = Theme.Font.Title, TextSize = 26, Position = UDim2.fromOffset(36, 0), Size = UDim2.new(0.6, 0, 1, 0) })
	UIUtil.label({ Parent = header, Text = "Pick your paw-powered playstyle", TextColor3 = Theme.Color.TextMuted, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 1, 0) })

	local tabRow = UIUtil.make("Frame", { Parent = board, Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1 })
	UIUtil.listLayout(tabRow, 8, Enum.FillDirection.Horizontal)
	local function tab(text: string): TextButton
		local b = UIUtil.make("TextButton", {
			Parent = tabRow, Size = UDim2.fromOffset(150, 32), Text = text, Font = Theme.Font.Bold, TextSize = 13,
			AutoButtonColor = false, BorderSizePixel = 0, BackgroundColor3 = TAB_OFF, TextColor3 = Theme.Color.Text,
		}) :: TextButton
		UIUtil.corner(UDim.new(0, 10), b)
		return b
	end
	local weaponsTab = tab("WEAPONS")
	weaponsTab.LayoutOrder = 1
	local skinsTab = tab("WEAPON SKINS")
	skinsTab.LayoutOrder = 2

	local function grid(cellH: number): ScrollingFrame
		local g = UIUtil.make("ScrollingFrame", {
			Parent = board, Position = UDim2.fromOffset(0, 84), Size = UDim2.new(1, 0, 1, -84),
			BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
			ScrollBarImageColor3 = Theme.Color.Stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}) :: ScrollingFrame
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 2)
		pad.PaddingLeft = UDim.new(0, 2)
		pad.PaddingRight = UDim.new(0, 10)
		pad.PaddingBottom = UDim.new(0, 8)
		pad.Parent = g
		UIUtil.gridLayout(g, UDim2.new(0.25, -9, 0, cellH), UDim2.fromOffset(12, 12))
		return g
	end
	local weaponGrid = grid(236)
	local skinGrid = grid(162)
	skinGrid.Visible = false

	local function showSkins(on: boolean)
		weaponGrid.Visible = not on
		skinGrid.Visible = on
		title.Text = on and "WEAPON SKINS" or "WEAPONS"
		weaponsTab.BackgroundColor3 = on and TAB_OFF or TAB_ON
		weaponsTab.TextColor3 = on and Theme.Color.Text or Color3.fromRGB(7, 35, 58)
		skinsTab.BackgroundColor3 = on and TAB_ON or TAB_OFF
		skinsTab.TextColor3 = on and Color3.fromRGB(7, 35, 58) or Theme.Color.Text
	end
	weaponsTab.MouseButton1Click:Connect(function() showSkins(false) end)
	skinsTab.MouseButton1Click:Connect(function() showSkins(true) end)
	showSkins(false)

	-- Weapon cards ----------------------------------------------------------
	local weaponCards = {}
	for order, w in ipairs(Weapons.List) do
		local card, setStatus = cardShell(weaponGrid, 108, w.Id, nil)
		card.LayoutOrder = order
		UIUtil.label({ Parent = card, Text = w.Name, Font = Theme.Font.Heading, TextSize = 15, Position = UDim2.fromOffset(12, 120), Size = UDim2.new(1, -24, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd })
		UIUtil.label({ Parent = card, Text = w.Class, Font = Theme.Font.Bold, TextSize = 11, TextColor3 = CLASS_COLOR[w.Class] or Theme.Color.Accent, Position = UDim2.fromOffset(12, 138), Size = UDim2.new(1, -24, 0, 14) })
		for i, stat in ipairs(STATS) do
			local y = 160 + (i - 1) * 14
			UIUtil.label({ Parent = card, Text = stat.label, TextSize = 10, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(12, y), Size = UDim2.new(0.42, -12, 0, 12) })
			local track = UIUtil.make("Frame", { Parent = card, Position = UDim2.new(0.44, 0, 0, y + 3), Size = UDim2.new(0.56, -12, 0, 6), BackgroundColor3 = Color3.fromRGB(8, 18, 36), BorderSizePixel = 0 })
			UIUtil.corner(UDim.new(1, 0), track)
			local fill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(math.clamp(w.Bars[stat.key] or 0, 0.04, 1), 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 })
			UIUtil.corner(UDim.new(1, 0), fill)
			UIUtil.gradient(Color3.fromRGB(70, 214, 255), Color3.fromRGB(46, 128, 255), 0, fill)
		end
		card.MouseButton1Click:Connect(function()
			buyOrEquip("Weapon", w.Id)
		end)
		table.insert(weaponCards, { id = w.Id, def = w, robux = Monetize.UnlockKey("Weapon", w.Id), setStatus = setStatus })
	end

	-- Skin cards ------------------------------------------------------------
	local skinCards = {}
	local shownWeapon = equippedWeapon()
	for order, skin in ipairs(Weapons.Skins) do
		local card, setStatus, setGun = cardShell(skinGrid, 112, shownWeapon, skin.Id)
		card.LayoutOrder = order
		UIUtil.label({ Parent = card, Text = skin.Name, Font = Theme.Font.Heading, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(8, 124), Size = UDim2.new(1, -16, 0, 18) })
		UIUtil.label({ Parent = card, Text = "COSMETIC ONLY", Font = Theme.Font.Bold, TextSize = 9, TextColor3 = Theme.Color.TextMuted, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(8, 142), Size = UDim2.new(1, -16, 0, 12) })
		card.MouseButton1Click:Connect(function()
			buyOrEquip("Skin", skin.Id)
		end)
		table.insert(skinCards, { id = skin.Id, def = skin, setStatus = setStatus, setGun = setGun })
	end

	local function refresh()
		for _, e in ipairs(weaponCards) do
			e.setStatus(ClientState.Owns("Weapon", e.id), ClientState.Equipped("Weapon") == e.id, e.def, e.robux)
		end
		for _, e in ipairs(skinCards) do
			e.setStatus(ClientState.Owns("Skin", e.id), ClientState.Equipped("Skin") == e.id, e.def)
		end
		-- Skin previews always show the gun you have equipped.
		local weaponId = equippedWeapon()
		if weaponId ~= shownWeapon then
			shownWeapon = weaponId
			for _, e in ipairs(skinCards) do
				e.setGun(weaponId, e.id)
			end
		end
	end
	refresh()
	ClientState.ProfileChanged:Connect(refresh)
	Loadout.Root = root
	return root
end

return Loadout
