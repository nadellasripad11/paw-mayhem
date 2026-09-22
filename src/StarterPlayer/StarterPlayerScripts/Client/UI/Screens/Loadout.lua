--!strict
-- Loadout: pick your equipped weapon + weapon skin. Shows stat bars for the
-- selected weapon (mirrors reference 1's loadout panel).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local HeroArt = require(script.Parent.Parent.HeroArt)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local ClientActions = require(script.Parent.Parent.Parent.ClientActions)

local Loadout = {}
local cards = {}
local statSetters = {}
local selectedName

local function refreshCards()
	for id, card in pairs(cards) do
		card.refresh({
			owned = ClientState.Owns(card._kind, id),
			equipped = ClientState.Equipped(card._kind) == id,
		})
	end
end

local function showStats(weapon)
	if not weapon then return end
	selectedName.Text = weapon.Name .. "  •  " .. weapon.Rarity
	statSetters.Damage.set(weapon.Bars.Damage)
	statSetters.FireRate.set(weapon.Bars.FireRate)
	statSetters.Knockback.set(weapon.Bars.Knockback)
	statSetters.Range.set(weapon.Bars.Range)
	statSetters.Accuracy.set(weapon.Bars.Accuracy)
end

function Loadout.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	HeroArt.Watermark(root)

	-- Left: stat panel
	local statPanel = UIUtil.panel({ Parent = root, Size = UDim2.new(0, 300, 1, 0), BackgroundColor3 = Theme.Color.PanelDark })
	UIUtil.padding(16, statPanel)
	selectedName = UIUtil.label({ Parent = statPanel, Text = "Select a weapon", Font = Theme.Font.Heading, TextSize = 20, Size = UDim2.new(1, 0, 0, 24) })
	local holder = UIUtil.make("Frame", { Parent = statPanel, BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 140) })
	UIUtil.listLayout(holder, 8)
	statSetters.Damage = UIUtil.statBar(holder, "Damage", 0, Theme.Color.Danger)
	statSetters.FireRate = UIUtil.statBar(holder, "Fire Rate", 0, Theme.Color.Warn)
	statSetters.Knockback = UIUtil.statBar(holder, "Knockback", 0, Theme.Color.Accent2)
	statSetters.Range = UIUtil.statBar(holder, "Range", 0, Theme.Color.Accent)
	statSetters.Accuracy = UIUtil.statBar(holder, "Accuracy", 0, Theme.Color.Success)
	UIUtil.label({ Parent = statPanel, Text = "Skins are cosmetic only — never pay-to-win.", TextColor3 = Theme.Color.TextMuted, TextSize = 11, Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 16) })

	-- Right: weapon grid + skins
	local right = UIUtil.make("Frame", { Parent = root, BackgroundTransparency = 1, Position = UDim2.fromOffset(316, 0), Size = UDim2.new(1, -316, 1, 0) })
	local weaponsHeader = UIUtil.make("Frame", { Parent = right, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1 })
	local gunHeaderSlot = UIUtil.make("Frame", { Parent = weaponsHeader, Size = UDim2.fromOffset(16, 16), BackgroundTransparency = 1 })
	Icons.Place("Gun", gunHeaderSlot, 16, Theme.Color.TextDim)
	UIUtil.label({ Parent = weaponsHeader, Text = "WEAPONS", Font = Theme.Font.Heading, TextSize = 14, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0) })
	local grid = UIUtil.make("ScrollingFrame", {
		Parent = right, Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0.6, -22),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	UIUtil.gridLayout(grid, UDim2.fromOffset(120, 130), UDim2.fromOffset(10, 10))

	for _, w in ipairs(Weapons.List) do
		local card = UIUtil.itemCard(grid, {
			title = w.Name, rarity = w.Rarity, cost = w.CoinCost,
			owned = ClientState.Owns("Weapon", w.Id), equipped = ClientState.Equipped("Weapon") == w.Id,
			accent = w.TrailColor, icon = w.Icon or "Gun", iconAccent = w.MuzzleColor,
		}, function(action)
			if action == "equip" then
				local res = ClientActions.Equip("Weapon", w.Id)
				if res.ok then refreshCards() end
			else
				local res = ClientActions.Purchase("Weapon", w.Id)
				if res.ok then
					ClientActions.Equip("Weapon", w.Id)
					refreshCards()
				end
			end
			showStats(w)
		end)
		card._kind = "Weapon"
		card.button.MouseEnter:Connect(function() showStats(w) end)
		cards[w.Id] = card
	end

	UIUtil.label({ Parent = right, Text = "WEAPON SKINS", Font = Theme.Font.Heading, TextSize = 14, TextColor3 = Theme.Color.TextDim, Position = UDim2.new(0, 0, 0.6, 6), Size = UDim2.new(1, 0, 0, 18) })
	local skinGrid = UIUtil.make("ScrollingFrame", {
		Parent = right, Position = UDim2.new(0, 0, 0.6, 28), Size = UDim2.new(1, 0, 0.4, -28),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	UIUtil.gridLayout(skinGrid, UDim2.fromOffset(110, 120), UDim2.fromOffset(10, 10))
	for _, s in ipairs(Weapons.Skins) do
		local card = UIUtil.itemCard(skinGrid, {
			title = s.Name, subtitle = "Skin", cost = s.CoinCost,
			owned = ClientState.Owns("Skin", s.Id), equipped = ClientState.Equipped("Skin") == s.Id,
			accent = s.Tint, icon = "Gun", iconAccent = s.Tint:Lerp(Color3.new(1, 1, 1), 0.45),
		}, function(action)
			if action == "equip" then
				if ClientActions.Equip("Skin", s.Id).ok then refreshCards() end
			else
				if ClientActions.Purchase("Skin", s.Id).ok then
					ClientActions.Equip("Skin", s.Id)
					refreshCards()
				end
			end
		end)
		card._kind = "Skin"
		cards[s.Id] = card
	end

	ClientState.ProfileChanged:Connect(refreshCards)
	if ClientState.Profile then
		showStats(Weapons.Get(ClientState.Profile.Loadout.Weapon))
	end

	Loadout.Root = root
	return root
end

return Loadout
