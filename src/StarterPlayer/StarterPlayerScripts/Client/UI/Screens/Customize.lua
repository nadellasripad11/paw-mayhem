--!strict
-- Customize: change fur / outfit / hat / accessory / emote. A slim icon rail on
-- the far left picks the category (mirrors reference 3), a big live preview of
-- the equipped cat sits next to it, and the item grid fills the rest.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cats = require(ReplicatedStorage.Shared.Config.Cats)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local ClientActions = require(script.Parent.Parent.Parent.ClientActions)

local Customize = {}

local CATEGORIES = {
	{ kind = "Fur", label = "Fur", list = Cats.Fur, icon = "CatBody" },
	{ kind = "Outfit", label = "Outfit", list = Cats.Outfits, icon = "Shirt" },
	{ kind = "Hat", label = "Hat", list = Cats.Hats, icon = "Hat" },
	{ kind = "Accessory", label = "Accessory", list = Cats.Accessories, icon = "Glasses" },
	{ kind = "Emote", label = "Emote", list = Cats.Emotes, icon = "Smiley" },
}

-- Each emote gets its own readable icon instead of one generic smiley for all.
local EMOTE_ICON = {
	Happy = "Smiley", Sit = "SitDown", Wave = "Wave", Laugh = "Laugh",
	Celebrate = "Burst", Sleep = "Sleep", Spin = "Spin", Fall = "Fall",
}

local grid, tabButtons, activeKind
local previewFace, previewLabel
local cards = {}

local function refreshCards()
	for _, c in ipairs(cards) do
		c.card.refresh({
			owned = ClientState.Owns(c.kind, c.id),
			equipped = ClientState.Equipped(c.kind) == c.id,
		})
	end
end

local function refreshPreview()
	if not previewFace then
		return
	end
	local p = ClientState.Profile
	local fur = Cats.FurById[p and p.Loadout.Cat.Fur or Cats.Default.Fur] or Cats.FurById[Cats.Default.Fur]
	previewFace:ClearAllChildren()
	Icons.Place("CatBody", previewFace, 132, fur.Body, fur.Accent)
	if previewLabel then
		previewLabel.Text = fur.Name .. " Cat"
	end
end

local function setActiveTab(kind)
	activeKind = kind
	for k, btn in pairs(tabButtons) do
		btn.BackgroundColor3 = (k == kind) and Theme.Color.Accent or Theme.Color.PanelLight
	end
end

local function loadCategory(cat)
	setActiveTab(cat.kind)
	grid:ClearAllChildren()
	UIUtil.gridLayout(grid, UDim2.fromOffset(120, 130), UDim2.fromOffset(10, 10))
	cards = {}
	for _, item in ipairs(cat.list) do
		local swatchColor = item.Body or item.Color or item.Tint or Theme.Color.Accent
		local icon = (cat.kind == "Emote" and EMOTE_ICON[item.Id]) or cat.icon
		local card = UIUtil.itemCard(grid, {
			title = item.Name, subtitle = item.Desc or cat.label, cost = item.CoinCost or 0,
			owned = ClientState.Owns(cat.kind, item.Id), equipped = ClientState.Equipped(cat.kind) == item.Id,
			accent = swatchColor, icon = icon, iconAccent = item.Accent,
		}, function(action)
			if action == "equip" then
				if ClientActions.Equip(cat.kind, item.Id).ok then
					refreshCards()
					refreshPreview()
				end
			else
				if ClientActions.Purchase(cat.kind, item.Id).ok then
					ClientActions.Equip(cat.kind, item.Id)
					refreshCards()
					refreshPreview()
				end
			end
		end)
		table.insert(cards, { card = card, kind = cat.kind, id = item.Id })
	end
end

function Customize.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }) :: Frame

	-- Slim category icon rail
	local rail = UIUtil.panel({ Parent = root, Size = UDim2.new(0, 64, 1, 0), BackgroundColor3 = Theme.Color.PanelDark })
	UIUtil.padding(8, rail)
	UIUtil.listLayout(rail, 8)
	tabButtons = {}
	for _, cat in ipairs(CATEGORIES) do
		local btn = UIUtil.button({
			Parent = rail, Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = Theme.Color.PanelLight, Text = "",
		}, function()
			loadCategory(cat)
		end)
		Icons.Place(cat.icon, btn, 26, Theme.Color.Text)
		tabButtons[cat.kind] = btn
	end

	-- Big live preview
	local previewPanel = UIUtil.panel({ Parent = root, Position = UDim2.fromOffset(74, 0), Size = UDim2.fromOffset(200, 1000), BackgroundColor3 = Theme.Color.PanelDark })
	previewPanel.Size = UDim2.new(0, 200, 1, 0)
	UIUtil.padding(14, previewPanel)
	local previewCard = UIUtil.make("Frame", { Parent = previewPanel, Size = UDim2.new(1, 0, 0, 172), BackgroundColor3 = Theme.Color.Panel, BorderSizePixel = 0 })
	UIUtil.corner(Theme.CornerSmall, previewCard)
	UIUtil.gradient(Color3.fromRGB(60, 74, 112), Color3.fromRGB(30, 38, 62), 90, previewCard)
	previewFace = UIUtil.make("Frame", { Parent = previewCard, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(132, 132), BackgroundTransparency = 1 })
	previewLabel = UIUtil.label({ Parent = previewPanel, Text = "Your Cat", Font = Theme.Font.Heading, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 182), Size = UDim2.new(1, 0, 0, 22) })

	-- equipped summary chips (outfit / hat / accessory)
	local summary = UIUtil.make("Frame", { Parent = previewPanel, Position = UDim2.fromOffset(0, 212), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 })
	UIUtil.listLayout(summary, 8, Enum.FillDirection.Horizontal).HorizontalAlignment = Enum.HorizontalAlignment.Center
	for _, catKind in ipairs({ "Outfit", "Hat", "Accessory" }) do
		local cat
		for _, c in ipairs(CATEGORIES) do
			if c.kind == catKind then
				cat = c
			end
		end
		local chip = UIUtil.make("Frame", { Parent = summary, Size = UDim2.fromOffset(36, 36), BackgroundColor3 = Theme.Color.PanelLight, BorderSizePixel = 0 })
		UIUtil.corner(Theme.CornerSmall, chip)
		Icons.Place(cat.icon, chip, 20, Theme.Color.TextDim)
	end

	-- Item grid
	grid = UIUtil.make("ScrollingFrame", {
		Parent = root, Position = UDim2.fromOffset(288, 0), Size = UDim2.new(1, -288, 1, 0),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 5,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	})
	loadCategory(CATEGORIES[1])
	refreshPreview()

	ClientState.ProfileChanged:Connect(function()
		refreshCards()
		refreshPreview()
	end)
	Customize.Root = root
	return root
end

return Customize
