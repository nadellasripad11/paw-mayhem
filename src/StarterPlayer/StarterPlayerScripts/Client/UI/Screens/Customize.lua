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
	{ kind = "Fur", label = "Fur", list = Cats.Fur, icon = "CatFace" },
	{ kind = "Hat", label = "Hat", list = Cats.Hats, icon = "Hat" },
	{ kind = "Accessory", label = "Accessory", list = Cats.Accessories, icon = "Glasses" },
	{ kind = "Outfit", label = "Outfit", list = Cats.Outfits, icon = "Shirt" },
	{ kind = "Emote", label = "Emote", list = Cats.Emotes, icon = "Paw" },
}

-- Each emote gets its own readable icon instead of one generic smiley for all.
local EMOTE_ICON = {
	Happy = "Smiley", Sit = "SitDown", Wave = "Wave", Laugh = "Laugh",
	Celebrate = "Burst", Sleep = "Sleep", Spin = "Spin", Fall = "Fall",
}

local grid, tabButtons, activeKind
local previewFace, previewLabel, gridTitle
local summaryChips = {}
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
	local outfit = Cats.OutfitById[p and p.Loadout.Cat.Outfit or Cats.Default.Outfit] or Cats.OutfitById[Cats.Default.Outfit]
	local hat = Cats.HatById[p and p.Loadout.Cat.Hat or Cats.Default.Hat] or Cats.HatById[Cats.Default.Hat]
	local accessory = Cats.AccessoryById[p and p.Loadout.Cat.Accessory or Cats.Default.Accessory] or Cats.AccessoryById[Cats.Default.Accessory]
	local previewBody = outfit and outfit.Id ~= "None" and outfit.Color or fur.Body
	previewFace:ClearAllChildren()
	Icons.Place("CatBody", previewFace, 220, previewBody, fur.Accent)
	if outfit and outfit.Id ~= "None" then
		Icons.Place("Shirt", previewFace, 64, outfit.Color, nil, UDim2.fromScale(0.5, 0.60))
	end
	if hat and hat.Id ~= "None" then
		Icons.Place("Hat", previewFace, 58, hat.Color, nil, UDim2.fromScale(0.5, 0.20))
	end
	if accessory and accessory.Id ~= "None" then
		Icons.Place(accessory.Shape == "Glasses" and "Glasses" or "Paw", previewFace, 48, accessory.Color, nil, UDim2.fromScale(0.5, 0.40))
	end
	if previewLabel then
		previewLabel.Text = fur.Name .. "  •  " .. (outfit and outfit.Name or "Classic")
	end
	for kind, chip in pairs(summaryChips) do
		local item = kind == "Outfit" and outfit or (kind == "Hat" and hat or accessory)
		if item then
			chip.BackgroundColor3 = item.Color or Theme.Color.PanelLight
		end
	end
end

local function setActiveTab(kind)
	activeKind = kind
	for k, btn in pairs(tabButtons) do
		local active = k == kind
		btn.BackgroundColor3 = active and Color3.fromRGB(20, 83, 92) or Theme.Color.PanelLight
		local stroke = btn:FindFirstChild("ActiveStroke")
		if stroke then
			stroke.Color = active and Theme.Color.Accent or Theme.Color.Stroke
			stroke.Thickness = active and 2 or 1
		end
	end
end

local function loadCategory(cat)
	setActiveTab(cat.kind)
	if gridTitle then
		gridTitle.Text = string.upper(cat.label .. " VARIATIONS")
	end
	grid:ClearAllChildren()
	UIUtil.gridLayout(grid, UDim2.fromOffset(110, 116), UDim2.fromOffset(9, 9))
	cards = {}
	for _, item in ipairs(cat.list) do
		local swatchColor = item.Body or item.Color or item.Tint or Theme.Color.Accent
		local icon = (cat.kind == "Emote" and EMOTE_ICON[item.Id]) or cat.icon
		local tile = UIUtil.button({
			Parent = grid, Size = UDim2.fromOffset(110, 116), BackgroundColor3 = Theme.Color.PanelLight,
			Text = "", CornerRadius = Theme.CornerSmall,
		}, function()
			local owned = ClientState.Owns(cat.kind, item.Id)
			local result
			if owned then
				result = ClientActions.Equip(cat.kind, item.Id)
			else
				result = ClientActions.Purchase(cat.kind, item.Id)
				if result and result.ok then
					ClientActions.Equip(cat.kind, item.Id)
				end
			end
			if result and result.ok then
				refreshCards()
				refreshPreview()
			end
		end)
		local tileStroke = UIUtil.stroke(Theme.Color.Stroke, 1, tile)
		local tilePreview = UIUtil.make("Frame", { Parent = tile, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 6), Size = UDim2.fromOffset(90, 82), BackgroundColor3 = swatchColor, BorderSizePixel = 0 })
		UIUtil.corner(Theme.CornerSmall, tilePreview)
		UIUtil.gradient(swatchColor:Lerp(Color3.new(1, 1, 1), 0.12), swatchColor:Lerp(Color3.new(0, 0, 0), 0.18), 90, tilePreview)
		Icons.Place(icon, tilePreview, cat.kind == "Fur" and 78 or 56, swatchColor, item.Accent)
		UIUtil.label({ Parent = tile, Text = item.Name, Font = Theme.Font.Bold, TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 89), Size = UDim2.new(1, -8, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd })
		UIUtil.label({ Parent = tile, Text = item.Desc or cat.label, TextColor3 = Theme.Color.TextMuted, TextSize = 9, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(4, 103), Size = UDim2.new(1, -8, 0, 12), TextTruncate = Enum.TextTruncate.AtEnd })
		local card = {
			refresh = function(state)
				tile.BackgroundColor3 = state.equipped and Color3.fromRGB(30, 82, 79) or Theme.Color.PanelLight
				tileStroke.Color = state.equipped and Color3.fromRGB(182, 241, 112) or Theme.Color.Stroke
				tileStroke.Thickness = state.equipped and 2.5 or 1
			end,
		}
		card.refresh({ owned = ClientState.Owns(cat.kind, item.Id), equipped = ClientState.Equipped(cat.kind) == item.Id })
		table.insert(cards, { card = card, kind = cat.kind, id = item.Id })
	end
end

function Customize.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, Size = UDim2.fromOffset(650, 500), Visible = false }) :: Frame
	local shell = UIUtil.panel({ Parent = root, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Theme.Color.PanelDark, ClipsDescendants = true })

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
		local activeStroke = UIUtil.stroke(Theme.Color.Stroke, 1, btn)
		activeStroke.Name = "ActiveStroke"
		Icons.Place(cat.icon, btn, 26, Theme.Color.Text)
		tabButtons[cat.kind] = btn
	end

	-- Big live preview
	local previewPanel = UIUtil.make("Frame", { Parent = root, Position = UDim2.fromOffset(74, 0), Size = UDim2.fromOffset(200, 500), BackgroundTransparency = 1 })
	UIUtil.padding(14, previewPanel)
	local previewCard = UIUtil.make("Frame", { Parent = previewPanel, Size = UDim2.new(1, 0, 0, 360), BackgroundColor3 = Theme.Color.PanelDark, BorderSizePixel = 0 })
	UIUtil.corner(Theme.CornerSmall, previewCard)
	UIUtil.gradient(Color3.fromRGB(18, 47, 73), Color3.fromRGB(8, 27, 52), 90, previewCard)
	previewFace = UIUtil.make("Frame", { Parent = previewCard, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(220, 330), BackgroundTransparency = 1 })
	previewLabel = UIUtil.label({ Parent = previewPanel, Text = "Your Cat", Font = Theme.Font.Heading, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 370), Size = UDim2.new(1, 0, 0, 22) })

	-- equipped summary chips (outfit / hat / accessory)
	local summary = UIUtil.make("Frame", { Parent = previewPanel, Position = UDim2.fromOffset(0, 404), Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 })
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
		summaryChips[catKind] = chip
	end

	-- Item grid
	gridTitle = UIUtil.label({ Parent = root, Text = "FUR VARIATIONS", Font = Theme.Font.Heading, TextSize = 14, TextColor3 = Theme.Color.TextDim, Position = UDim2.fromOffset(288, 10), Size = UDim2.new(1, -300, 0, 20) })
	grid = UIUtil.make("ScrollingFrame", {
		Parent = root, Position = UDim2.fromOffset(288, 38), Size = UDim2.new(1, -300, 1, -50),
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
