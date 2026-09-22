--!strict
-- Shop: unified store of everything purchasable with coins (weapons, skins, and
-- all cat cosmetics). Buying here auto-adds to your Unlocks; equip from Loadout
-- or Customize. Cosmetics are never pay-to-win.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Cats = require(ReplicatedStorage.Shared.Config.Cats)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local HeroArt = require(script.Parent.Parent.HeroArt)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local ClientActions = require(script.Parent.Parent.Parent.ClientActions)

local Shop = {}
local cards = {}

local function collectItems()
	local items = {}
	for _, w in ipairs(Weapons.List) do
		if (w.CoinCost or 0) > 0 then
			table.insert(items, { kind = "Weapon", id = w.Id, name = w.Name, sub = "Weapon • " .. w.Rarity, cost = w.CoinCost, accent = w.TrailColor, icon = w.Icon or "Gun", iconAccent = w.MuzzleColor })
		end
	end
	for _, s in ipairs(Weapons.Skins) do
		if (s.CoinCost or 0) > 0 then
			table.insert(items, { kind = "Skin", id = s.Id, name = s.Name, sub = "Skin", cost = s.CoinCost, accent = s.Tint, icon = "Gun", iconAccent = s.Tint:Lerp(Color3.new(1, 1, 1), 0.45) })
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
			if (item.CoinCost or 0) > 0 then
				local icon = (c.kind == "Emote" and EMOTE_ICON[item.Id]) or c.icon
				table.insert(items, { kind = c.kind, id = item.Id, name = item.Name, sub = c.kind, cost = item.CoinCost, accent = item.Body or item.Color or item.Tint or Theme.Color.Accent, icon = icon, iconAccent = item.Accent })
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
end

function Shop.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	HeroArt.Watermark(root)
	local header = UIUtil.make("Frame", { Parent = root, Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1 })
	local cartSlot = UIUtil.make("Frame", { Parent = header, Size = UDim2.fromOffset(20, 20), BackgroundTransparency = 1 })
	Icons.Place("Cart", cartSlot, 20, Theme.Color.Coin)
	UIUtil.label({ Parent = header, Text = "SHOP — spend coins earned from matches. Cosmetics only, no power advantage.", TextColor3 = Theme.Color.TextDim, TextSize = 12, Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 1, 0) })

	local grid = UIUtil.make("ScrollingFrame", {
		Parent = root, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 1, -28),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	UIUtil.gridLayout(grid, UDim2.fromOffset(120, 130), UDim2.fromOffset(10, 10))

	for _, it in ipairs(collectItems()) do
		local card = UIUtil.itemCard(grid, {
			title = it.name, subtitle = it.sub, cost = it.cost,
			owned = ClientState.Owns(it.kind, it.id), equipped = false,
			accent = it.accent, icon = it.icon, iconAccent = it.iconAccent,
		}, function(action)
			if action == "buy" then
				local res = ClientActions.Purchase(it.kind, it.id)
				if res.ok then refreshCards() end
			end
		end)
		table.insert(cards, { card = card, kind = it.kind, id = it.id })
	end

	ClientState.ProfileChanged:Connect(refreshCards)
	Shop.Root = root
	return root
end

return Shop
