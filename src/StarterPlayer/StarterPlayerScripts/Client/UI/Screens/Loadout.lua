--!strict
-- Loadout: pick your equipped weapon + weapon skin. Shows stat bars for the
-- selected weapon (mirrors reference 1's loadout panel).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local ClientActions = require(script.Parent.Parent.Parent.ClientActions)

local Loadout = {}

function Loadout.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false })
	-- Reference-style weapon catalog: eight readable cards, four columns, and
	-- the real gameplay bars directly on each weapon instead of a generic store
	-- tile. The existing purchase/equip remotes remain the only action path.
	local board = UIUtil.panel({ Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -24, 1, -24), BackgroundColor3 = Theme.Color.PanelDark, ClipsDescendants = true })
	UIUtil.padding(12, board)
	local header = UIUtil.make("Frame", { Parent = board, Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 })
	local gunSlot = UIUtil.make("Frame", { Parent = header, Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 1 })
	Icons.Place("Gun", gunSlot, 24, Theme.Color.Accent)
	UIUtil.label({ Parent = header, Text = "WEAPONS", Font = Theme.Font.Title, TextSize = 22, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -32, 1, 0) })
	UIUtil.label({ Parent = header, Text = "Pick your paw-powered playstyle", TextColor3 = Theme.Color.TextMuted, TextSize = 11, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 1, 0) })
	local tabRow = UIUtil.make("Frame", { Parent = board, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1 })
	UIUtil.listLayout(tabRow, 8, Enum.FillDirection.Horizontal)
	local weaponsTab = UIUtil.button({ Parent = tabRow, Size = UDim2.fromOffset(132, 28), BackgroundColor3 = Theme.Color.Accent, Text = "WEAPONS", TextColor3 = Color3.fromRGB(7, 35, 58), TextSize = 11, CornerRadius = Theme.CornerSmall })
	local skinsTab = UIUtil.button({ Parent = tabRow, Size = UDim2.fromOffset(132, 28), BackgroundColor3 = Theme.Color.Panel, Text = "WEAPON SKINS", TextSize = 11, CornerRadius = Theme.CornerSmall })
	local weaponGrid = UIUtil.make("ScrollingFrame", { Parent = board, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -70), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y })
	UIUtil.gridLayout(weaponGrid, UDim2.fromOffset(136, 206), UDim2.fromOffset(8, 8))
	local skinGrid = UIUtil.make("ScrollingFrame", { Parent = board, Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 1, -70), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Visible = false })
	UIUtil.gridLayout(skinGrid, UDim2.fromOffset(164, 184), UDim2.fromOffset(10, 10))
	local function showSkins(on: boolean)
		weaponGrid.Visible = not on
		skinGrid.Visible = on
		weaponsTab.BackgroundColor3 = on and Theme.Color.Panel or Theme.Color.Accent
		weaponsTab.TextColor3 = on and Theme.Color.Text or Color3.fromRGB(7, 35, 58)
		skinsTab.BackgroundColor3 = on and Theme.Color.Accent or Theme.Color.Panel
		skinsTab.TextColor3 = on and Color3.fromRGB(7, 35, 58) or Theme.Color.Text
	end
	weaponsTab.MouseButton1Click:Connect(function() showSkins(false) end)
	skinsTab.MouseButton1Click:Connect(function() showSkins(true) end)
	local weaponCards = {}
	local skinCards = {}
	local statNames = { { key = "Damage", label = "Damage" }, { key = "FireRate", label = "Fire Rate" }, { key = "Knockback", label = "Knockback" }, { key = "Range", label = "Range" }, { key = "Accuracy", label = "Accuracy" } }
	for _, w in ipairs(Weapons.List) do
		local tile = UIUtil.button({ Parent = weaponGrid, Size = UDim2.fromOffset(136, 206), BackgroundColor3 = Theme.Color.Panel, Text = "", CornerRadius = Theme.CornerSmall })
		local tileStroke = UIUtil.stroke(Theme.Color.Stroke, 1, tile)
		local preview = UIUtil.make("Frame", { Parent = tile, Position = UDim2.fromOffset(7, 7), Size = UDim2.new(1, -14, 0, 62), BackgroundColor3 = w.TrailColor, BorderSizePixel = 0 })
		UIUtil.corner(Theme.CornerSmall, preview)
		UIUtil.gradient(w.TrailColor:Lerp(Color3.new(1, 1, 1), 0.16), w.TrailColor:Lerp(Color3.new(0, 0, 0), 0.22), 90, preview)
		Icons.Place(w.Icon or "Gun", preview, 52, w.TrailColor, w.MuzzleColor)
		UIUtil.label({ Parent = tile, Text = w.Name, Font = Theme.Font.Bold, TextSize = 12, Position = UDim2.fromOffset(8, 73), Size = UDim2.new(1, -16, 0, 15), TextTruncate = Enum.TextTruncate.AtEnd })
		local rarityColor = Theme.Rarity[w.Rarity] or Theme.Color.Accent
		UIUtil.label({ Parent = tile, Text = w.Class, Font = Theme.Font.Bold, TextSize = 10, TextColor3 = rarityColor, Position = UDim2.fromOffset(8, 88), Size = UDim2.new(1, -16, 0, 13), TextTruncate = Enum.TextTruncate.AtEnd })
		for index, stat in ipairs(statNames) do
			local fraction = math.clamp(w.Bars[stat.key] or 0, 0, 1)
			local y = 104 + (index - 1) * 14
			UIUtil.label({ Parent = tile, Text = stat.label, TextSize = 9, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(8, y), Size = UDim2.fromOffset(52, 12) })
			local track = UIUtil.make("Frame", { Parent = tile, Position = UDim2.fromOffset(62, y + 3), Size = UDim2.fromOffset(64, 6), BackgroundColor3 = Theme.Color.PanelDark, BorderSizePixel = 0 })
			UIUtil.corner(UDim.new(1, 0), track)
			local fill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(fraction, 1), BackgroundColor3 = Theme.Color.Accent, BorderSizePixel = 0 })
			UIUtil.corner(UDim.new(1, 0), fill)
		end
		local status = UIUtil.label({ Parent = tile, Text = "", Font = Theme.Font.Bold, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(8, 188), Size = UDim2.new(1, -16, 0, 12) })
		local card = { refresh = function(state)
			tile.BackgroundColor3 = state.equipped and Color3.fromRGB(24, 78, 75) or Theme.Color.Panel
			tileStroke.Color = state.equipped and Color3.fromRGB(182, 241, 112) or Theme.Color.Stroke
			tileStroke.Thickness = state.equipped and 2.5 or 1
			status.Text = state.equipped and "EQUIPPED" or (state.owned and "OWNED" or ((w.CoinCost or 0) > 0 and tostring(w.CoinCost) .. " COINS" or "UNLOCK"))
			status.TextColor3 = state.equipped and Color3.fromRGB(182, 241, 112) or Theme.Color.TextMuted
		end }
		table.insert(weaponCards, { card = card, id = w.Id })
		tile.MouseButton1Click:Connect(function()
			local result
			if ClientState.Owns("Weapon", w.Id) then
				result = ClientActions.Equip("Weapon", w.Id)
			else
				result = ClientActions.Purchase("Weapon", w.Id)
				if result and result.ok then ClientActions.Equip("Weapon", w.Id) end
			end
			if result and result.ok then
				for _, entry in ipairs(weaponCards) do
					entry.card.refresh({ owned = ClientState.Owns("Weapon", entry.id), equipped = ClientState.Equipped("Weapon") == entry.id })
				end
			end
		end)
	end
	for _, skin in ipairs(Weapons.Skins) do
		local tile = UIUtil.button({ Parent = skinGrid, Size = UDim2.fromOffset(164, 184), BackgroundColor3 = Theme.Color.Panel, Text = "", CornerRadius = Theme.CornerSmall })
		local tileStroke = UIUtil.stroke(Theme.Color.Stroke, 1, tile)
		local preview = UIUtil.make("Frame", { Parent = tile, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 88), BackgroundColor3 = skin.Tint, BorderSizePixel = 0 })
		UIUtil.corner(Theme.CornerSmall, preview)
		UIUtil.gradient(skin.Tint:Lerp(Color3.new(1, 1, 1), 0.16), skin.Tint:Lerp(Color3.new(0, 0, 0), 0.26), 90, preview)
		Icons.Place("Gun", preview, 68, skin.Tint, Color3.fromRGB(255, 255, 255))
		UIUtil.label({ Parent = tile, Text = skin.Name, Font = Theme.Font.Heading, TextSize = 15, Position = UDim2.fromOffset(10, 106), Size = UDim2.new(1, -20, 0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
		UIUtil.label({ Parent = tile, Text = "COSMETIC ONLY", Font = Theme.Font.Bold, TextSize = 9, TextColor3 = Theme.Color.TextMuted, Position = UDim2.fromOffset(10, 128), Size = UDim2.new(1, -20, 0, 13) })
		local status = UIUtil.label({ Parent = tile, Text = "", Font = Theme.Font.Bold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(10, 151), Size = UDim2.new(1, -20, 0, 17) })
		local card = { refresh = function(state)
			tile.BackgroundColor3 = state.equipped and Color3.fromRGB(24, 78, 75) or Theme.Color.Panel
			tileStroke.Color = state.equipped and Color3.fromRGB(182, 241, 112) or Theme.Color.Stroke
			tileStroke.Thickness = state.equipped and 2.5 or 1
			status.Text = state.equipped and "EQUIPPED" or (state.owned and "OWNED" or ((skin.CoinCost or 0) > 0 and tostring(skin.CoinCost) .. " COINS" or "UNLOCK"))
			status.TextColor3 = state.equipped and Color3.fromRGB(182, 241, 112) or Theme.Color.TextMuted
		end }
		table.insert(skinCards, { card = card, id = skin.Id })
		tile.MouseButton1Click:Connect(function()
			local result
			if ClientState.Owns("Skin", skin.Id) then
				result = ClientActions.Equip("Skin", skin.Id)
			else
				result = ClientActions.Purchase("Skin", skin.Id)
				if result and result.ok then ClientActions.Equip("Skin", skin.Id) end
			end
			if result and result.ok then
				for _, entry in ipairs(skinCards) do
					entry.card.refresh({ owned = ClientState.Owns("Skin", entry.id), equipped = ClientState.Equipped("Skin") == entry.id })
				end
			end
		end)
	end
	local function refreshCatalogCards()
		for _, entry in ipairs(weaponCards) do
			entry.card.refresh({ owned = ClientState.Owns("Weapon", entry.id), equipped = ClientState.Equipped("Weapon") == entry.id })
		end
		for _, entry in ipairs(skinCards) do
			entry.card.refresh({ owned = ClientState.Owns("Skin", entry.id), equipped = ClientState.Equipped("Skin") == entry.id })
		end
	end
	refreshCatalogCards()
	ClientState.ProfileChanged:Connect(refreshCatalogCards)
	Loadout.Root = root
	return root
end

return Loadout
