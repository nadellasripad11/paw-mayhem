--!strict
-- Shop: the Robux store (Game Passes, gem bundles, Coin Rain, Starter Pack) on
-- top, then every item purchasable with coins or gems (weapons, skins and all
-- cat cosmetics). Buying here auto-adds to your Unlocks; equip from Loadout or
-- Customize. Cosmetics are never pay-to-win.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Cats = require(ReplicatedStorage.Shared.Config.Cats)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local HeroArt = require(script.Parent.Parent.HeroArt)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Monetize = require(script.Parent.Parent.Parent.Monetize)

local Shop = {}
local cards = {}
local robuxCards = {}

local ROBUX_GREEN = Color3.fromRGB(60, 200, 110)

-- Robux store rows, in display order.
local ROBUX_ITEMS = {
	{ pass = "VIP", icon = "Trophy", color = Color3.fromRGB(255, 190, 40), tag = "BEST" },
	{ pass = "DoubleCoins", icon = "Coin", color = Theme.Color.Coin },
	{ product = "StarterPack", icon = "Bag", color = Color3.fromRGB(90, 200, 255), tag = "ONCE" },
	{ product = "Gems100", icon = "Gem", color = Theme.Color.Gem },
	{ product = "Gems350", icon = "Gem", color = Theme.Color.Gem },
	{ product = "Gems1000", icon = "Gem", color = Theme.Color.Gem, tag = "POPULAR" },
	{ product = "Gems2800", icon = "Gem", color = Theme.Color.Gem, tag = "BEST VALUE" },
	{ product = "CoinRain", icon = "Sparkle", color = Color3.fromRGB(255, 214, 70) },
	{ pass = "EmotePack", icon = "Smiley", color = Color3.fromRGB(255, 120, 180) },
	{ pass = "TrailPack", icon = "Dash", color = Color3.fromRGB(120, 220, 255) },
}

local function collectItems()
	local items = {}
	local function priced(it: any): boolean
		return (it.CoinCost or 0) > 0 or (it.GemCost or 0) > 0 or it.PassOnly ~= nil
	end
	for _, w in ipairs(Weapons.List) do
		if priced(w) then
			table.insert(items, { kind = "Weapon", id = w.Id, def = w, name = w.Name, sub = (w :: any).Exclusive and "Exclusive Weapon" or ("Weapon • " .. w.Rarity), accent = w.TrailColor, icon = w.Icon or "Gun", iconAccent = w.MuzzleColor })
		end
	end
	for _, s in ipairs(Weapons.Skins) do
		if priced(s) then
			table.insert(items, { kind = "Skin", id = s.Id, def = s, name = s.Name, sub = "Skin", accent = s.Tint, icon = "Gun", iconAccent = s.Tint:Lerp(Color3.new(1, 1, 1), 0.45) })
		end
	end
	local EMOTE_ICON = {
		Happy = "Smiley", Sit = "SitDown", Wave = "Wave", Laugh = "Laugh",
		Celebrate = "Burst", Sleep = "Sleep", Spin = "Spin", Fall = "Fall",
	}
	local cosmetic = {
		{ list = Cats.Fur, kind = "Fur", icon = "CatBody" }, { list = Cats.Outfits, kind = "Outfit", icon = "Shirt" },
		{ list = Cats.Hats, kind = "Hat", icon = "Hat" }, { list = Cats.Accessories, kind = "Accessory", icon = "Glasses" },
		{ list = Cats.Emotes, kind = "Emote", icon = "Smiley" },
	}
	for _, c in ipairs(cosmetic) do
		for _, item in ipairs(c.list) do
			if priced(item) then
				local icon = (c.kind == "Emote" and EMOTE_ICON[item.Id]) or c.icon
				table.insert(items, { kind = c.kind, id = item.Id, def = item, name = item.Name, sub = c.kind, accent = item.Body or item.Color or item.Tint or Theme.Color.Accent, icon = icon, iconAccent = item.Accent })
			end
		end
	end
	return items
end

local function refreshCards()
	for _, c in ipairs(cards) do
		c.card.refresh({
			owned = ClientState.Owns(c.kind, c.id),
			equipped = ClientState.Equipped(c.kind) == c.id,
		})
	end
	for _, r in ipairs(robuxCards) do
		r.refresh()
	end
end

local function sectionTitle(parent: Instance, order: number, text: string, sub: string, color: Color3)
	local row = UIUtil.make("Frame", { Parent = parent, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
	UIUtil.label({ Parent = row, Text = text, Font = Theme.Font.Title, TextSize = 20, TextColor3 = color, Size = UDim2.new(0, 200, 1, 0), AutomaticSize = Enum.AutomaticSize.X })
	UIUtil.label({ Parent = row, Text = sub, TextSize = 12, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, -8, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })
end

local function robuxCard(parent: Instance, spec: any)
	local def = spec.pass and Monetization.Passes[spec.pass] or Monetization.Products[spec.product]
	if not def then
		return
	end
	local card = UIUtil.panel({ Parent = parent, BackgroundColor3 = Theme.Color.PanelLight })
	UIUtil.padding(8, card)
	UIUtil.stroke(spec.color, 2, card).Transparency = 0.3

	local swatch = UIUtil.make("Frame", {
		Parent = card, Size = UDim2.fromOffset(46, 46), BackgroundColor3 = spec.color, BorderSizePixel = 0,
	})
	UIUtil.corner(Theme.CornerSmall, swatch)
	UIUtil.gradient(spec.color:Lerp(Color3.new(1, 1, 1), 0.25), spec.color:Lerp(Color3.new(0, 0, 0), 0.3), 90, swatch)
	Icons.Place(spec.icon, swatch, 30, Color3.new(1, 1, 1))

	UIUtil.label({
		Parent = card, Text = string.upper(def.Name), Font = Theme.Font.Title, TextSize = 17,
		Position = UDim2.fromOffset(54, 0), Size = UDim2.new(1, -54, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd,
	})
	UIUtil.label({
		Parent = card, Text = spec.pass and "GAME PASS" or "ITEM", Font = Theme.Font.Bold, TextSize = 10, TextColor3 = spec.color,
		Position = UDim2.fromOffset(54, 21), Size = UDim2.new(1, -54, 0, 12),
	})
	UIUtil.label({
		Parent = card, Text = def.Desc, TextSize = 11, TextColor3 = Theme.Color.TextDim, TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -82),
	})
	if spec.tag then
		local tag = UIUtil.label({
			Parent = card, Text = spec.tag, Font = Theme.Font.Bold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 4, 0, -4), Size = UDim2.fromOffset(62, 16),
			BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(255, 70, 90), TextColor3 = Color3.new(1, 1, 1),
		})
		UIUtil.corner(UDim.new(1, 0), tag)
	end

	local btn = UIUtil.button({
		Parent = card, Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 26),
		BackgroundColor3 = ROBUX_GREEN, TextSize = 14, CornerRadius = Theme.CornerSmall,
		Text = "R$ " .. tostring(def.Price),
	}, function()
		if spec.pass then
			Monetize.PromptPass(spec.pass)
		else
			Monetize.PromptProduct(spec.product)
		end
	end)

	local function refresh()
		if spec.pass then
			local owned = Monetize.OwnsPass(spec.pass)
			btn.Text = owned and "OWNED" or ("R$ " .. tostring(def.Price))
			btn.Active = not owned
			btn.BackgroundColor3 = owned and Theme.Color.PlayDark or ROBUX_GREEN
		elseif spec.product == "StarterPack" then
			local profile = ClientState.Profile
			card.Visible = not (profile and profile.StarterPackBought)
		end
	end
	if spec.pass then
		game:GetService("Players").LocalPlayer:GetAttributeChangedSignal(spec.pass):Connect(refresh)
	end
	refresh()
	table.insert(robuxCards, { refresh = refresh })
end

function Shop.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	HeroArt.Watermark(root)

	local scroll = UIUtil.make("ScrollingFrame", {
		Parent = root, Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	UIUtil.listLayout(scroll, 10)

	-- ── Robux store ──
	sectionTitle(scroll, 1, "ROBUX STORE", "Support the game and get something awesome", Color3.fromRGB(110, 230, 140))
	local robuxGrid = UIUtil.make("Frame", {
		Parent = scroll, LayoutOrder = 2, BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	})
	UIUtil.gridLayout(robuxGrid, UDim2.fromOffset(190, 150), UDim2.fromOffset(10, 10))
	for _, spec in ipairs(ROBUX_ITEMS) do
		robuxCard(robuxGrid, spec)
	end

	-- ── coin + gem items ──
	local header = UIUtil.make("Frame", { Parent = scroll, LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 26), BackgroundTransparency = 1 })
	local cartSlot = UIUtil.make("Frame", { Parent = header, Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(0, 3), BackgroundTransparency = 1 })
	Icons.Place("Cart", cartSlot, 20, Theme.Color.Coin)
	UIUtil.label({ Parent = header, Text = "ITEMS", Font = Theme.Font.Title, TextSize = 20, TextColor3 = Theme.Color.Coin, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(0, 80, 1, 0) })
	UIUtil.label({ Parent = header, Text = "Spend coins from matches or gems. Cosmetics only, no power advantage.", TextColor3 = Theme.Color.TextDim, TextSize = 12, Size = UDim2.new(1, -8, 1, 0), TextXAlignment = Enum.TextXAlignment.Right })

	local grid = UIUtil.make("Frame", {
		Parent = scroll, LayoutOrder = 4, BackgroundTransparency = 1,
		Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
	})
	UIUtil.gridLayout(grid, UDim2.fromOffset(120, 130), UDim2.fromOffset(10, 10))

	for _, it in ipairs(collectItems()) do
		local priceText, priceColor = Monetize.PriceTag(it.def)
		local card = UIUtil.itemCard(grid, {
			title = it.name, subtitle = it.sub, priceText = priceText, priceColor = priceColor,
			owned = ClientState.Owns(it.kind, it.id), equipped = false,
			accent = it.accent, icon = it.icon, iconAccent = it.iconAccent,
		}, function(action)
			if action == "buy" and Monetize.Buy(it.kind, it.id, it.def) then
				refreshCards()
			end
		end)
		table.insert(cards, { card = card, kind = it.kind, id = it.id })
	end

	ClientState.ProfileChanged:Connect(refreshCards)
	Shop.Root = root
	return root
end

return Shop
