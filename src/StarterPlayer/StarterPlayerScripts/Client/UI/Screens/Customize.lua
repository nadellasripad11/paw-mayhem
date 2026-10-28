--!strict
-- customize: fur / hat / accessory / outfit / emote. a slim icon rail picks
-- the category, the real 3d cat stands in the middle (drag to spin), and a
-- grid of 3d portrait tiles shows your cat wearing each option.

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Cats = require(ReplicatedStorage.Shared.Config.Cats)

local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local Icons = require(script.Parent.Parent.Icons)
local CatView = require(script.Parent.Parent.CatView)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local ClientActions = require(script.Parent.Parent.Parent.ClientActions)
local Monetize = require(script.Parent.Parent.Parent.Monetize)

local Customize = {}

local W, H = 760, 500
local TILE = 108
local EQUIP_GREEN = Color3.fromRGB(182, 241, 112)
local TILE_STROKE = Color3.fromRGB(78, 116, 166)

local CATEGORIES = {
	{ kind = "Fur", title = "FUR", list = Cats.Fur, icon = "CatFace" },
	{ kind = "Hat", title = "HATS", list = Cats.Hats, icon = "Hat" },
	{ kind = "Accessory", title = "ACCESSORIES", list = Cats.Accessories, icon = "Glasses" },
	{ kind = "Outfit", title = "OUTFITS", list = Cats.Outfits, icon = "Shirt" },
	{ kind = "Emote", title = "EMOTES", list = Cats.Emotes, icon = "Paw" },
}

local EMOTE_ICON = {
	Happy = "Smiley", Sit = "SitDown", Wave = "Wave", Laugh = "Laugh",
	Celebrate = "Burst", Sleep = "Sleep", Spin = "Spin", Fall = "Fall",
	Loaf = "CatBody", Knead = "Paw", Purr = "Smiley", Hiss = "Burst", Taunt = "Laugh", Zoomies = "Dash", BoxSit = "SitDown",
	Dance = "Sparkle", Flex = "Bolt",
}

local grid: ScrollingFrame
local gridTitle: TextLabel
local previewVF: ViewportFrame
local previewName: TextLabel
local railButtons: { [string]: any } = {}
local tiles: { any } = {}
-- the six emote slots (shown above the grid on the emotes tab).
local slotBar: Frame? = nil
local slotViews: { { button: TextButton, icon: Frame, stroke: UIStroke, scale: UIScale } } = {}
local selectedSlot = 1
local activeCat = CATEGORIES[1]
local lastSig = ""

local function currentCat(): { [string]: string }
	local p = ClientState.Profile
	local c = p and p.Loadout and p.Loadout.Cat or {}
	return {
		Fur = c.Fur or Cats.Default.Fur,
		Outfit = c.Outfit or Cats.Default.Outfit,
		Hat = c.Hat or Cats.Default.Hat,
		Accessory = c.Accessory or Cats.Default.Accessory,
	}
end

local function catSig(): string
	local c = currentCat()
	return c.Fur .. "|" .. c.Outfit .. "|" .. c.Hat .. "|" .. c.Accessory
end

local function framingFor(kind: string, item): string
	if kind == "Outfit" then
		return "Full"
	elseif kind == "Accessory" and (item.Shape == "Backpack" or item.Shape == "Jetpack") then
		return "Back"
	end
	return "Bust"
end

-- paint the six slots: their emotes, and which one is selected.
local function paintSlots()
	local slots = ClientActions.EmoteSlots()
	for i, v in ipairs(slotViews) do
		v.icon:ClearAllChildren()
		local id = slots[i]
		if id ~= "" then
			Icons.Place(EMOTE_ICON[id] or "Smiley", v.icon, 30, Color3.new(1, 1, 1))
		end
		v.stroke.Color = i == selectedSlot and Color3.fromRGB(255, 210, 70) or TILE_STROKE
		v.stroke.Thickness = i == selectedSlot and 3 or 1.5
	end
end

-- just added to a slot: the slot pops with a gold flash and "added!" floats
-- up, and the preview cat does the emote.
local function addedEffect(i: number, id: string)
	local TweenService = game:GetService("TweenService")
	local v = slotViews[i]
	if v then
		v.scale.Scale = 1.4
		TweenService:Create(v.scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		local flash = UIUtil.make("Frame", { Parent = v.button, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 220, 90), BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 5 })
		UIUtil.corner(UDim.new(0, 10), flash)
		TweenService:Create(flash, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
		task.delay(0.55, function()
			flash:Destroy()
		end)
		local added = UIUtil.label({
			Parent = v.button, Text = "ADDED!", Font = Theme.Font.Title, TextSize = 16, TextColor3 = Color3.fromRGB(255, 220, 90),
			TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, -2),
			Size = UDim2.fromOffset(90, 20), TextStrokeTransparency = 0.3, ZIndex = 6,
		})
		TweenService:Create(added, TweenInfo.new(0.9), { Position = UDim2.new(0.5, 0, 0, -26), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		task.delay(0.95, function()
			added:Destroy()
		end)
	end
	local cat = previewVF and previewVF:FindFirstChild("CatModel", true)
	if cat then
		cat:SetAttribute("Emote", id)
		cat:SetAttribute("EmoteAt", workspace:GetServerTimeNow())
	end
	pcall(function()
		require(script.Parent.Parent.Parent.Controllers.SoundController).Play("Pop")
	end)
end

-- an emote tile was picked: buy it if needed, then put it in the selected
-- slot (or the first empty one if that's taken).
local function equipEmote(item)
	if not ClientState.Owns("Emote", item.Id) and not Monetize.Buy("Emote", item.Id, item) then
		return
	end
	local slots = ClientActions.EmoteSlots()
	local target = selectedSlot
	if slots[target] ~= "" and not table.find(slots, item.Id) then
		for i = 1, 6 do
			if slots[i] == "" then
				target = i
				break
			end
		end
	end
	local res = ClientActions.SetEmoteSlot(target, item.Id)
	if res and res.ok then
		selectedSlot = target
		addedEffect(target, item.Id)
	end
end

local function buyOrEquip(kind: string, item)
	if kind == "Emote" then
		equipEmote(item)
		return
	end
	if ClientState.Owns(kind, item.Id) then
		ClientActions.Equip(kind, item.Id)
	elseif Monetize.Buy(kind, item.Id, item) then
		ClientActions.Equip(kind, item.Id)
	end
end

-- ── tiles ────────────────────────────────────────────────────────────────────
local function refreshTiles()
	local level = ClientState.Profile and ClientState.Profile.Level or 1
	for _, t in ipairs(tiles) do
		local owned = ClientState.Owns(t.kind, t.item.Id)
		local equipped = if t.kind == "Emote" then table.find(ClientActions.EmoteSlots(), t.item.Id) ~= nil else ClientState.Equipped(t.kind) == t.item.Id
		t.stroke.Color = equipped and EQUIP_GREEN or TILE_STROKE
		t.stroke.Thickness = equipped and 3 or 1.5
		t.stroke.Transparency = equipped and 0 or 0.35
		t.check.Visible = equipped
		local cost = t.item.CoinCost or 0
		local locked = not owned and (t.item.UnlockLevel or 0) > level
		t.pill.Visible = not owned
		local gems = t.item.GemCost or 0
		local pass = t.item.PassOnly ~= nil or t.item.Season ~= nil
		t.coin.Visible = not owned and not locked and not pass and gems == 0 and cost > 0
		t.gem.Visible = not owned and not locked and not pass and gems > 0
		if locked then
			t.pillText.Text = "LV " .. tostring(t.item.UnlockLevel)
			t.pillText.TextColor3 = Theme.Color.TextDim
		elseif pass then
			t.pillText.Text, t.pillText.TextColor3 = Monetize.PriceTag(t.item)
		else
			t.pillText.Text = gems > 0 and tostring(gems) or (cost > 0 and tostring(cost) or "FREE")
			t.pillText.TextColor3 = gems > 0 and Theme.Color.Gem or Theme.Color.Coin
		end
	end
end

local function buildTile(cat, item, order: number)
	local tile = UIUtil.make("TextButton", {
		Parent = grid, Text = "", AutoButtonColor = false, LayoutOrder = order,
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ClipsDescendants = true,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 14), tile)
	UIUtil.gradient(Color3.fromRGB(38, 66, 110), Color3.fromRGB(16, 32, 62), 90, tile)
	local stroke = UIUtil.stroke(TILE_STROKE, 1.5, tile)

	if cat.kind == "Emote" then
		local slot = UIUtil.make("Frame", { Parent = tile, Size = UDim2.new(1, 0, 1, -20), BackgroundTransparency = 1 })
		Icons.Place(EMOTE_ICON[item.Id] or "Smiley", slot, 46, Color3.new(1, 1, 1))
	else
		local vf = CatView.Create(tile, UDim2.new(1, -4, 1, -4), UDim2.fromOffset(2, 2))
		local custom = currentCat()
		custom[cat.kind] = item.Id
		CatView.Set(vf, custom, framingFor(cat.kind, item))
	end

	-- name caption over a dark fade at the bottom.
	local fade = UIUtil.make("Frame", {
		Parent = tile, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Color3.fromRGB(6, 12, 26), BorderSizePixel = 0,
	})
	local fadeGrad = Instance.new("UIGradient")
	fadeGrad.Rotation = 90
	fadeGrad.Transparency = NumberSequence.new(1, 0.2)
	fadeGrad.Parent = fade
	UIUtil.label({
		Parent = tile, Text = item.Name, Font = Theme.Font.Bold, TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 4, 1, -4), Size = UDim2.new(1, -8, 0, 15),
		TextTruncate = Enum.TextTruncate.AtEnd, TextStrokeTransparency = 0.6,
	})

	-- equipped check (top left) and price / level pill (top right).
	local check = UIUtil.make("Frame", {
		Parent = tile, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = EQUIP_GREEN, BorderSizePixel = 0, Visible = false,
	})
	UIUtil.corner(UDim.new(1, 0), check)
	Icons.Place("Check", check, 12, Color3.fromRGB(16, 40, 30))

	local pill = UIUtil.make("Frame", {
		Parent = tile, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -5, 0, 5),
		Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Color3.fromRGB(8, 16, 32), BackgroundTransparency = 0.15, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), pill)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 5)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = pill
	local layout = UIUtil.listLayout(pill, 2, Enum.FillDirection.Horizontal)
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	local coin = UIUtil.make("Frame", { Parent = pill, Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, LayoutOrder = 1 })
	Icons.Place("Coin", coin, 12, Theme.Color.Coin)
	local gem = UIUtil.make("Frame", { Parent = pill, Size = UDim2.fromOffset(12, 12), BackgroundTransparency = 1, LayoutOrder = 1, Visible = false })
	Icons.Place("Gem", gem, 12, Theme.Color.Gem)
	local pillText = UIUtil.label({
		Parent = pill, Text = "", Font = Theme.Font.Bold, TextSize = 10,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 12), LayoutOrder = 2,
	})

	tile.MouseEnter:Connect(function()
		if ClientState.Equipped(cat.kind) ~= item.Id then
			stroke.Transparency = 0
		end
	end)
	tile.MouseLeave:Connect(refreshTiles)
	tile.MouseButton1Click:Connect(function()
		buyOrEquip(cat.kind, item)
	end)
	table.insert(tiles, { kind = cat.kind, item = item, stroke = stroke, check = check, pill = pill, coin = coin, gem = gem, pillText = pillText })
end

local function loadCategory(cat)
	activeCat = cat
	for kind, b in pairs(railButtons) do
		local on = kind == cat.kind
		b.button.BackgroundColor3 = on and Color3.fromRGB(22, 96, 110) or Color3.fromRGB(20, 38, 66)
		b.stroke.Color = on and Theme.Color.Accent or TILE_STROKE
		b.stroke.Thickness = on and 2 or 1
		b.stroke.Transparency = on and 0 or 0.5
		b.glow.Visible = on
	end
	gridTitle.Text = cat.kind == "Emote" and "EMOTES  ·  tap a slot, then an emote (up to 6)" or cat.title
	-- the emote tab shows the six slots above the grid.
	local bar = slotBar
	if bar then
		bar.Visible = cat.kind == "Emote"
		grid.Position = UDim2.fromOffset(394, cat.kind == "Emote" and 120 or 42)
		grid.Size = UDim2.fromOffset(360, H - (cat.kind == "Emote" and 132 or 54))
		paintSlots()
	end
	for _, child in ipairs(grid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	tiles = {}
	for i, item in ipairs(cat.list) do
		buildTile(cat, item, i)
	end
	refreshTiles()
end

-- ── preview ──────────────────────────────────────────────────────────────────
local function refreshPreview()
	local c = currentCat()
	CatView.Set(previewVF, c, "Full")
	local fur = Cats.FurById[c.Fur]
	local outfit = Cats.OutfitById[c.Outfit]
	previewName.Text = (fur and fur.Name or "Cat") .. (outfit and outfit.Id ~= "None" and ("  •  " .. outfit.Name) or "")
end

local function onProfileChanged()
	if slotBar and slotBar.Visible then
		paintSlots()
	end
	local sig = catSig()
	if sig ~= lastSig then
		lastSig = sig
		refreshPreview()
		loadCategory(activeCat)
	else
		refreshTiles()
	end
end

function Customize.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }) :: Frame
	local stage = UIUtil.make("Frame", {
		Parent = root, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(W, H), BackgroundColor3 = Color3.fromRGB(10, 22, 44), BorderSizePixel = 0,
	}) :: Frame
	UIUtil.corner(UDim.new(0, 18), stage)
	UIUtil.stroke(Theme.Color.Stroke, 1.5, stage).Transparency = 0.4
	local stageScale = Instance.new("UIScale")
	stageScale.Parent = stage
	local function fit()
		local s = root.AbsoluteSize
		if s.X > 0 and s.Y > 0 then
			stageScale.Scale = math.min(s.X / W, s.Y / H)
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()

	-- category rail --------------------------------------------------------
	local rail = UIUtil.make("Frame", {
		Parent = stage, Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(66, H - 24),
		BackgroundColor3 = Color3.fromRGB(12, 26, 50), BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(0, 18), rail)
	UIUtil.stroke(TILE_STROKE, 1, rail).Transparency = 0.6
	for i, cat in ipairs(CATEGORIES) do
		local y = 12 + (i - 1) * 62
		local glow = UIUtil.make("Frame", {
			Parent = rail, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(33, y + 25),
			Size = UDim2.fromOffset(62, 62), BackgroundColor3 = Theme.Color.Accent, BackgroundTransparency = 0.82,
			BorderSizePixel = 0, Visible = false,
		})
		UIUtil.corner(UDim.new(0, 18), glow)
		local b = UIUtil.make("TextButton", {
			Parent = rail, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(8, y),
			Size = UDim2.fromOffset(50, 50), BackgroundColor3 = Color3.fromRGB(20, 38, 66), BorderSizePixel = 0,
		}) :: TextButton
		UIUtil.corner(UDim.new(0, 14), b)
		local stroke = UIUtil.stroke(TILE_STROKE, 1, b)
		Icons.Place(cat.icon, b, 28, Color3.new(1, 1, 1))
		b.MouseButton1Click:Connect(function()
			loadCategory(cat)
		end)
		railButtons[cat.kind] = { button = b, stroke = stroke, glow = glow }
	end

	-- 3d preview -------------------------------------------------------------
	local holder = UIUtil.make("Frame", { Parent = stage, Position = UDim2.fromOffset(88, 12), Size = UDim2.fromOffset(296, H - 24), BackgroundTransparency = 1 })
	local spot = UIUtil.make("Frame", {
		Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(148, 200),
		Size = UDim2.fromOffset(270, 330), BackgroundColor3 = Theme.Color.Accent, BackgroundTransparency = 0.9, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), spot)
	local spotCore = UIUtil.make("Frame", {
		Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(148, 190),
		Size = UDim2.fromOffset(180, 230), BackgroundColor3 = Color3.fromRGB(150, 220, 255), BackgroundTransparency = 0.9, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), spotCore)
	local shadow = UIUtil.make("Frame", {
		Parent = holder, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(148, 392),
		Size = UDim2.fromOffset(150, 24), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.6, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(1, 0), shadow)
	previewVF = CatView.Create(holder, UDim2.fromOffset(296, 410), UDim2.new())

	previewName = UIUtil.label({
		Parent = holder, Text = "", Font = Theme.Font.Title, TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 414), Size = UDim2.new(1, 0, 0, 26),
	})
	UIUtil.label({
		Parent = holder, Text = "Drag to look around  ·  scroll to zoom", Font = Theme.Font.Body, TextSize = 12, TextColor3 = Theme.Color.TextMuted,
		TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 442), Size = UDim2.new(1, 0, 0, 16),
	})

	-- drag to spin, with a gentle idle sway.
	local spin = UIUtil.make("TextButton", { Parent = holder, Text = "", BackgroundTransparency = 1, Size = UDim2.fromOffset(296, 410) }) :: TextButton
	local userYaw = math.rad(CatView.Framing.Full.yaw)
	local dragInput: InputObject? = nil
	local lastX = 0
	spin.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
			lastX = input.Position.X
		end
	end)
	-- dragging swings the camera all round the cat (up and down too).
	require(script.Parent.Parent.Orbit).Enable(spin, previewVF)
	UserInputService.InputEnded:Connect(function(input)
		if input == dragInput or (dragInput and input.UserInputType == Enum.UserInputType.MouseButton1) then
			dragInput = nil
		end
	end)
	local t = 0
	RunService.RenderStepped:Connect(function(dt)
		local gui = root:FindFirstAncestorOfClass("ScreenGui")
		if not root.Visible or not (gui and gui.Enabled) then
			return
		end
		t += dt
		local sway = dragInput and 0 or math.sin(t * 0.8) * 0.14
		CatView.SetYaw(previewVF, userYaw + sway)
	end)

	-- grid -------------------------------------------------------------------
	gridTitle = UIUtil.label({
		Parent = stage, Text = "FUR", Font = Theme.Font.Heading, TextSize = 14, TextColor3 = Theme.Color.TextDim,
		Position = UDim2.fromOffset(398, 16), Size = UDim2.fromOffset(348, 18),
	})
	grid = UIUtil.make("ScrollingFrame", {
		Parent = stage, Position = UDim2.fromOffset(394, 42), Size = UDim2.fromOffset(360, H - 54),
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4,
		ScrollBarImageColor3 = Theme.Color.Stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}) :: ScrollingFrame
	local gpad = Instance.new("UIPadding")
	gpad.PaddingTop = UDim.new(0, 4)
	gpad.PaddingLeft = UDim.new(0, 4)
	gpad.PaddingBottom = UDim.new(0, 8)
	gpad.Parent = grid
	UIUtil.gridLayout(grid, UDim2.fromOffset(TILE, TILE), UDim2.fromOffset(10, 10))
	-- the six emote slots (emotes tab): tap one to choose where the next
	-- emote goes.
	local bar = UIUtil.make("Frame", { Parent = stage, Position = UDim2.fromOffset(398, 44), Size = UDim2.fromOffset(352, 66), BackgroundTransparency = 1, Visible = false }) :: Frame
	UIUtil.listLayout(bar, 6, Enum.FillDirection.Horizontal)
	for i = 1, 6 do
		local b = UIUtil.make("TextButton", {
			Parent = bar, LayoutOrder = i, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(53, 62),
			BackgroundColor3 = Color3.fromRGB(20, 30, 52), BorderSizePixel = 0,
		}) :: TextButton
		UIUtil.corner(UDim.new(0, 10), b)
		local st = UIUtil.stroke(TILE_STROKE, 1.5, b)
		local sc = Instance.new("UIScale")
		sc.Parent = b
		local icon = UIUtil.make("Frame", { Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromOffset(30, 30), BackgroundTransparency = 1 }) :: Frame
		UIUtil.label({
			Parent = b, Text = tostring(i), Font = Theme.Font.Bold, TextSize = 11, TextColor3 = Theme.Color.TextDim,
			TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.new(1, 0, 0, 12),
		})
		b.MouseButton1Click:Connect(function()
			selectedSlot = i
			paintSlots()
		end)
		slotViews[i] = { button = b, icon = icon, stroke = st, scale = sc }
	end
	slotBar = bar

	lastSig = catSig()
	refreshPreview()
	loadCategory(CATEGORIES[1])
	ClientState.ProfileChanged:Connect(onProfileChanged)

	Customize.Root = root
	return root
end

return Customize
