--!strict
-- Shop: category tabs down the left (Featured, Gems, Blasters, Skins, Fur,
-- Outfits, Hats & Gear, Emotes) and a grid of cards on the right. Every card
-- shows a real 3D render of the item (ShopArt), built the first time its tab
-- opens. Robux items open Roblox's purchase prompt; everything else buys with
-- coins / gems and falls back to Robux when you're short (Monetize.Buy).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Cats = require(ReplicatedStorage.Shared.Config.Cats)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local ShopArt = require(script.Parent.Parent.ShopArt)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local ClientActions = require(script.Parent.Parent.Parent.ClientActions)
local Monetize = require(script.Parent.Parent.Parent.Monetize)

local Shop = {}

local player = Players.LocalPlayer
local ROBUX_GREEN = Color3.fromRGB(52, 196, 104)
local EQUIP_GREEN = Color3.fromRGB(96, 226, 150)
local CARD_BG = Color3.fromRGB(22, 38, 68)
local CARD_STROKE = Color3.fromRGB(54, 84, 132)
local RARITY_COLOR = {
	Common = Color3.fromRGB(180, 190, 205), Uncommon = Color3.fromRGB(110, 220, 130), Rare = Color3.fromRGB(90, 170, 255),
	Epic = Color3.fromRGB(190, 110, 255), Legendary = Color3.fromRGB(255, 170, 60), Mythic = Color3.fromRGB(255, 90, 140),
}

type Card = { refresh: () -> () }
local cards: { Card } = {}

local function currentCat()
	local p = ClientState.Profile
	local c = p and p.Loadout and p.Loadout.Cat or {}
	return { Fur = c.Fur, Outfit = c.Outfit, Hat = c.Hat, Accessory = c.Accessory }
end

local function equippedWeapon(): string
	local p = ClientState.Profile
	return p and p.Loadout and p.Loadout.Weapon or Weapons.DefaultLoadout
end

-- ── card shell ───────────────────────────────────────────────────────────────
-- A card with a 3D art area on top, name + subtitle and an action button.
local function cardShell(parent: Instance, accent: Color3, title: string, subtitle: string, subColor: Color3?)
	local card = UIUtil.make("Frame", { Parent = parent, BackgroundColor3 = CARD_BG, BorderSizePixel = 0 }) :: Frame
	UIUtil.corner(UDim.new(0, 14), card)
	local stroke = UIUtil.stroke(CARD_STROKE, 1.5, card)
	local art = UIUtil.make("Frame", {
		Parent = card, Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 1, -78),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ClipsDescendants = true,
	}) :: Frame
	UIUtil.corner(UDim.new(0, 10), art)
	UIUtil.gradient(accent:Lerp(Color3.fromRGB(40, 60, 100), 0.45), Color3.fromRGB(14, 24, 46), 90, art)
	local glow = UIUtil.make("Frame", {
		Parent = art, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.58), Size = UDim2.fromScale(0.8, 0.8),
		BackgroundColor3 = accent, BackgroundTransparency = 0.8, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), glow)
	UIUtil.label({
		Parent = card, Text = title, Font = Theme.Font.Title, TextSize = 16, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.new(0, 10, 1, -70), Size = UDim2.new(1, -20, 0, 20),
	})
	UIUtil.label({
		Parent = card, Text = subtitle, Font = Theme.Font.Bold, TextSize = 11, TextColor3 = subColor or Theme.Color.TextDim,
		Position = UDim2.new(0, 10, 1, -50), Size = UDim2.new(1, -20, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local btn = UIUtil.make("TextButton", {
		Parent = card, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -8), Size = UDim2.new(1, -16, 0, 28),
		Text = "", Font = Theme.Font.Title, TextSize = 15, TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = true, BorderSizePixel = 0, BackgroundColor3 = ROBUX_GREEN,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 9), btn)
	return card, art, btn, stroke
end

local function tag(parent: Instance, text: string, color: Color3)
	local t = UIUtil.label({
		Parent = parent, Text = text, Font = Theme.Font.Bold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 6), Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 0, BackgroundColor3 = color, TextColor3 = Color3.new(1, 1, 1), ZIndex = 3,
	})
	UIUtil.corner(UDim.new(1, 0), t)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = t
end

-- ── Robux cards ──────────────────────────────────────────────────────────────
local function robuxCard(parent: Instance, spec: any)
	local def = spec.pass and Monetization.Passes[spec.pass] or Monetization.Products[spec.product]
	if not def then
		return
	end
	local card, art, btn = cardShell(parent, spec.color, string.upper(def.Name), spec.pass and "GAME PASS  •  FOREVER" or def.Desc, spec.color)
	ShopArt.Prop(art, spec.art, spec.tier)
	if spec.overlay then
		UIUtil.label({
			Parent = art, Text = spec.overlay, Font = Theme.Font.Title, TextSize = 40, TextColor3 = Color3.fromRGB(255, 236, 140),
			AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -4), Size = UDim2.fromOffset(90, 44), ZIndex = 3,
			TextStrokeTransparency = 0.2, TextStrokeColor3 = Color3.fromRGB(90, 50, 0),
		})
	end
	if spec.tag then
		tag(art, spec.tag, Color3.fromRGB(255, 70, 100))
	end
	btn.MouseButton1Click:Connect(function()
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
			btn.BackgroundColor3 = owned and Color3.fromRGB(40, 90, 70) or ROBUX_GREEN
		else
			btn.Text = "R$ " .. tostring(def.Price)
			if spec.product == "StarterPack" then
				local profile = ClientState.Profile
				card.Visible = not (profile and profile.StarterPackBought)
			end
		end
	end
	if spec.pass then
		player:GetAttributeChangedSignal(spec.pass):Connect(refresh)
	end
	refresh()
	table.insert(cards, { refresh = refresh })
end

-- ── catalog cards (coins / gems / pass items) ────────────────────────────────
local function itemCard(parent: Instance, it: any)
	local rarity = it.def.Rarity
	local subColor = rarity and RARITY_COLOR[rarity] or Theme.Color.TextDim
	local card, art, btn, stroke = cardShell(parent, it.accent or Theme.Color.Accent, it.def.Name, it.sub, subColor)
	it.render(art)
	if it.def.Exclusive then
		tag(art, "EXCLUSIVE", Color3.fromRGB(255, 70, 140))
	elseif it.def.PassOnly then
		local pass = Monetization.Passes[it.def.PassOnly]
		tag(art, pass and string.upper(pass.Name) or "PASS", Color3.fromRGB(230, 160, 20))
	end
	local function refresh()
		local owned = ClientState.Owns(it.kind, it.def.Id)
		local equipped = ClientState.Equipped(it.kind) == it.def.Id
		stroke.Color = equipped and EQUIP_GREEN or CARD_STROKE
		stroke.Thickness = equipped and 2.5 or 1.5
		if equipped then
			btn.Text, btn.BackgroundColor3 = "EQUIPPED", Color3.fromRGB(40, 110, 80)
		elseif owned then
			btn.Text, btn.BackgroundColor3 = "EQUIP", Theme.Color.Accent
		else
			local price, color = Monetize.PriceTag(it.def)
			btn.Text, btn.BackgroundColor3 = price, color:Lerp(Color3.new(0, 0, 0), 0.15)
		end
	end
	btn.MouseButton1Click:Connect(function()
		if ClientState.Owns(it.kind, it.def.Id) then
			if it.kind ~= "Emote" then
				ClientActions.Equip(it.kind, it.def.Id)
			end
		elseif Monetize.Buy(it.kind, it.def.Id, it.def) and it.kind ~= "Emote" then
			ClientActions.Equip(it.kind, it.def.Id)
		end
	end)
	refresh()
	table.insert(cards, { refresh = refresh })
end

local function priced(it: any): boolean
	return (it.CoinCost or 0) > 0 or (it.GemCost or 0) > 0 or it.PassOnly ~= nil
end

local function cosmeticItems(list: { any }, kind: string, framing: string?)
	local out = {}
	for _, item in ipairs(list) do
		if priced(item) then
			table.insert(out, {
				kind = kind, def = item, sub = kind == "Accessory" and "Gear" or kind,
				accent = item.Body or item.Color or Theme.Color.Accent,
				render = function(art)
					local custom = currentCat()
					custom[kind] = item.Id
					local f = framing
					if kind == "Accessory" and (item.Shape == "Backpack" or item.Shape == "Jetpack") then
						f = "Back"
					end
					ShopArt.Cat(art, custom, f or "Bust")
				end,
			})
		end
	end
	return out
end

-- ── tabs ─────────────────────────────────────────────────────────────────────
local TABS = {
	{
		id = "Featured", label = "FEATURED", cell = 250,
		robux = {
			{ pass = "VIP", art = "VIP", color = Color3.fromRGB(255, 190, 40), tag = "BEST" },
			{ pass = "DoubleCoins", art = "Coins", color = Theme.Color.Coin, overlay = "2x" },
			{ product = "StarterPack", art = "Gift", color = Color3.fromRGB(90, 200, 255), tag = "ONE TIME" },
			{ product = "CoinRain", art = "CoinRain", color = Color3.fromRGB(255, 214, 70) },
			{ pass = "EmotePack", art = "Emote", color = Color3.fromRGB(255, 120, 180) },
			{ pass = "TrailPack", art = "Rainbow", color = Color3.fromRGB(120, 220, 255) },
		},
	},
	{
		id = "Gems", label = "GEMS", cell = 250,
		robux = {
			{ product = "Gems100", art = "Gems", tier = 1, color = Theme.Color.Gem },
			{ product = "Gems350", art = "Gems", tier = 2, color = Theme.Color.Gem },
			{ product = "Gems1000", art = "Gems", tier = 3, color = Theme.Color.Gem, tag = "POPULAR" },
			{ product = "Gems2800", art = "Gems", tier = 4, color = Theme.Color.Gem, tag = "BEST VALUE" },
		},
	},
	{
		id = "Blasters", label = "BLASTERS", cell = 230,
		items = function()
			local out = {}
			for _, w in ipairs(Weapons.List) do
				if priced(w) then
					table.insert(out, {
						kind = "Weapon", def = w, sub = (w :: any).Exclusive and "EXCLUSIVE BLASTER" or string.upper(w.Rarity) .. " BLASTER",
						accent = w.TrailColor, render = function(art) ShopArt.Gun(art, w.Id, nil) end,
					})
				end
			end
			return out
		end,
	},
	{
		id = "Skins", label = "SKINS", cell = 230,
		items = function()
			local out = {}
			for _, s in ipairs(Weapons.Skins) do
				if priced(s) then
					table.insert(out, {
						kind = "Skin", def = s, sub = "BLASTER SKIN", accent = s.Tint,
						render = function(art) ShopArt.Gun(art, equippedWeapon(), s.Id) end,
					})
				end
			end
			return out
		end,
	},
	{ id = "Fur", label = "FUR", cell = 230, items = function() return cosmeticItems(Cats.Fur, "Fur") end },
	{ id = "Outfits", label = "OUTFITS", cell = 230, items = function() return cosmeticItems(Cats.Outfits, "Outfit", "Full") end },
	{ id = "Hats", label = "HATS", cell = 230, items = function() return cosmeticItems(Cats.Hats, "Hat") end },
	{ id = "Gear", label = "GEAR", cell = 230, items = function() return cosmeticItems(Cats.Accessories, "Accessory") end },
	{
		id = "Emotes", label = "EMOTES", cell = 230,
		items = function()
			local out = {}
			for _, e in ipairs(Cats.Emotes) do
				if priced(e) then
					table.insert(out, {
						kind = "Emote", def = e, sub = "EMOTE", accent = Color3.fromRGB(255, 130, 190),
						render = function(art) ShopArt.Cat(art, currentCat(), "Full", e.Id) end,
					})
				end
			end
			return out
		end,
	},
}

function Shop.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })

	-- Category rail
	local rail = UIUtil.make("ScrollingFrame", {
		Parent = root, Size = UDim2.new(0, 170, 1, 0), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	UIUtil.listLayout(rail, 8)

	local pages: { [string]: ScrollingFrame } = {}
	local built: { [string]: boolean } = {}
	local tabButtons: { [string]: TextButton } = {}

	local function buildPage(tab): ScrollingFrame
		local page = UIUtil.make("ScrollingFrame", {
			Parent = root, Position = UDim2.fromOffset(186, 0), Size = UDim2.new(1, -186, 1, 0), Visible = false,
			BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
			ScrollBarImageColor3 = Theme.Color.Stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
		}) :: ScrollingFrame
		local pad = Instance.new("UIPadding")
		pad.PaddingTop = UDim.new(0, 2)
		pad.PaddingLeft = UDim.new(0, 2)
		pad.PaddingRight = UDim.new(0, 12)
		pad.PaddingBottom = UDim.new(0, 12)
		pad.Parent = page
		UIUtil.gridLayout(page, UDim2.new(0.25, -12, 0, tab.cell), UDim2.fromOffset(14, 14))
		return page
	end

	local function show(id: string)
		for tid, b in pairs(tabButtons) do
			local on = tid == id
			b.BackgroundColor3 = on and Color3.fromRGB(64, 200, 255) or Color3.fromRGB(22, 38, 68)
			b.TextColor3 = on and Color3.fromRGB(8, 30, 52) or Color3.new(1, 1, 1)
		end
		for _, tab in ipairs(TABS) do
			if tab.id == id and not built[id] then
				built[id] = true
				local page = pages[id]
				if tab.robux then
					for _, spec in ipairs(tab.robux) do
						robuxCard(page, spec)
					end
				else
					for _, it in ipairs(tab.items()) do
						local ok, err = pcall(itemCard, page, it)
						if not ok then
							warn("[PAW MAYHEM] Shop card failed: " .. tostring(err))
						end
					end
				end
			end
		end
		for pid, page in pairs(pages) do
			page.Visible = pid == id
		end
	end

	for order, tab in ipairs(TABS) do
		pages[tab.id] = buildPage(tab)
		local b = UIUtil.make("TextButton", {
			Parent = rail, LayoutOrder = order, Size = UDim2.new(1, 0, 0, 44), Text = tab.label,
			Font = Theme.Font.Title, TextSize = 17, AutoButtonColor = true, BorderSizePixel = 0,
		}) :: TextButton
		UIUtil.corner(UDim.new(0, 12), b)
		b.MouseButton1Click:Connect(function()
			show(tab.id)
		end)
		tabButtons[tab.id] = b
	end
	show("Featured")

	ClientState.ProfileChanged:Connect(function()
		for _, c in ipairs(cards) do
			c.refresh()
		end
	end)
	Shop.Root = root
	return root
end

return Shop
