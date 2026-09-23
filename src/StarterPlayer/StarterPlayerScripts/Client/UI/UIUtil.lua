--!strict
-- UIUtil: small factory helpers so screens stay declarative and consistent.
-- Everything is built in code (no pre-made rbxm assets required).

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local UIUtil = {}

-- Icons that render in their own natural tones (a miniature "portrait" of the
-- item) rather than as a flat white glyph — every gun silhouette + the cat
-- face preview.
local NATURAL_TONE_ICONS = {
	CatFace = true, CatBody = true, Gun = true, GunHeavy = true, GunFast = true, GunSniper = true,
	GunCannon = true, GunBubble = true, GunIce = true, GunGolden = true,
}

-- The top inset Roblox reserves for its own topbar (avatar/menu/chat icons).
-- Any full-screen (IgnoreGuiInset = true) GUI must add this to top-anchored
-- content or Roblox's own chrome will render on top of it.
function UIUtil.topInset(): number
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and inset then
		return inset.Y
	end
	return 36
end

-- Generic instance factory: UIUtil.make("Frame", {props}, {children})
function UIUtil.make(className: string, props: { [string]: any }?, children: { Instance }?): Instance
	local inst = Instance.new(className)
	if props then
		for k, v in pairs(props) do
			if k ~= "Parent" and k ~= "CornerRadius" then
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in ipairs(children) do
			c.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function UIUtil.corner(radius: UDim?, parent: Instance?): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or Theme.Corner
	if parent then
		c.Parent = parent
	end
	return c
end

function UIUtil.stroke(color: Color3?, thickness: number?, parent: Instance?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Color.Stroke
	s.Thickness = thickness or 1.5
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	if parent then
		s.Parent = parent
	end
	return s
end

function UIUtil.padding(all: number, parent: Instance?): UIPadding
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, all)
	p.PaddingBottom = UDim.new(0, all)
	p.PaddingLeft = UDim.new(0, all)
	p.PaddingRight = UDim.new(0, all)
	if parent then
		p.Parent = parent
	end
	return p
end

function UIUtil.gradient(c1: Color3, c2: Color3, rotation: number?, parent: Instance?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rotation or 90
	if parent then
		g.Parent = parent
	end
	return g
end

-- A rounded panel with optional stroke.
function UIUtil.panel(props: { [string]: any }?): Frame
	local f = UIUtil.make("Frame", props) :: Frame
	f.BackgroundColor3 = (props and props.BackgroundColor3) or Theme.Color.Panel
	f.BorderSizePixel = 0
	UIUtil.corner(Theme.Corner, f)
	UIUtil.stroke(Theme.Color.Stroke, 1.5, f)
	return f
end

function UIUtil.label(props: { [string]: any }?): TextLabel
	local l = UIUtil.make("TextLabel", props) :: TextLabel
	l.BackgroundTransparency = (props and props.BackgroundTransparency) or 1
	l.TextColor3 = (props and props.TextColor3) or Theme.Color.Text
	l.Font = (props and props.Font) or Theme.Font.Body
	l.TextSize = (props and props.TextSize) or 16
	if props and props.TextXAlignment == nil then
		l.TextXAlignment = Enum.TextXAlignment.Left
	end
	return l
end

-- A clickable button with hover/press feedback. Returns the TextButton.
function UIUtil.button(props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local b = UIUtil.make("TextButton", props) :: TextButton
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.Font = (props and props.Font) or Theme.Font.Bold
	b.TextSize = (props and props.TextSize) or 18
	b.TextColor3 = (props and props.TextColor3) or Theme.Color.Text
	local baseColor = b.BackgroundColor3
	UIUtil.corner((props and props.CornerRadius) or Theme.Corner, b)

	b.MouseEnter:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = baseColor:Lerp(Color3.new(1, 1, 1), 0.12) }):Play()
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = baseColor }):Play()
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.06), { BackgroundColor3 = baseColor:Lerp(Color3.new(0, 0, 0), 0.15) }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(b, TweenInfo.new(0.06), { BackgroundColor3 = baseColor }):Play()
	end)
	if onClick then
		b.MouseButton1Click:Connect(onClick)
	end
	return b
end

-- Horizontal stat bar (0..1). Returns {frame, set(fraction)}.
function UIUtil.statBar(parent: Instance, labelText: string, fraction: number, color: Color3?)
	local row = UIUtil.make("Frame", {
		Parent = parent,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
	}) :: Frame

	UIUtil.label({
		Parent = row,
		Text = labelText,
		Size = UDim2.new(0, 82, 1, 0),
		TextSize = 13,
		TextColor3 = Theme.Color.TextDim,
	})

	local track = UIUtil.make("Frame", {
		Parent = row,
		Position = UDim2.new(0, 88, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, -92, 0, 8),
		BackgroundColor3 = Theme.Color.PanelDark,
		BorderSizePixel = 0,
	}) :: Frame
	UIUtil.corner(UDim.new(1, 0), track)

	local fill = UIUtil.make("Frame", {
		Parent = track,
		Size = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0),
		BackgroundColor3 = color or Theme.Color.Accent,
		BorderSizePixel = 0,
	}) :: Frame
	UIUtil.corner(UDim.new(1, 0), fill)
	UIUtil.gradient(Theme.Color.Accent2, color or Theme.Color.Accent, 0, fill)

	return {
		frame = row,
		set = function(f: number)
			fill.Size = UDim2.new(math.clamp(f, 0, 1), 0, 1, 0)
		end,
	}
end

function UIUtil.listLayout(parent: Instance, padding: number, dir: Enum.FillDirection?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = dir or Enum.FillDirection.Vertical
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
	return l
end

function UIUtil.gridLayout(parent: Instance, cell: UDim2, pad: UDim2): UIGridLayout
	local g = Instance.new("UIGridLayout")
	g.CellSize = cell
	g.CellPadding = pad
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = parent
	return g
end

-- A catalog item card (weapon / skin / cosmetic). opts:
--   { title, subtitle, rarity, cost, owned, equipped, accent, icon, iconAccent }
-- `icon` is a string key into Icons.Registry (e.g. "Gun", "Sparkle", "CatFace").
-- onAction(kind) is called with "equip" or "buy". Returns { frame, refresh }.
function UIUtil.itemCard(parent: Instance, opts: any, onAction: (action: string) -> ())
	local card = UIUtil.panel({
		Parent = parent,
		BackgroundColor3 = Theme.Color.PanelLight,
	})
	UIUtil.padding(8, card)
	local rarityColor = opts.rarity and Theme.Rarity[opts.rarity] or Theme.Color.Accent
	local swatchColor = opts.accent or rarityColor

	-- preview swatch
	local swatch = UIUtil.make("Frame", {
		Parent = card, Size = UDim2.new(1, 0, 0, 54),
		BackgroundColor3 = swatchColor, BorderSizePixel = 0,
	}) :: Frame
	UIUtil.corner(Theme.CornerSmall, swatch)
	UIUtil.gradient(swatchColor:Lerp(Color3.new(1,1,1),0.2), swatchColor:Lerp(Color3.new(0,0,0),0.25), 90, swatch)
	if opts.icon then
		-- CatFace / Gun render in their own natural tones (a miniature "portrait"
		-- of the item); every other icon reads as a flat white glyph on the
		-- colored swatch so it stays legible at small sizes.
		if NATURAL_TONE_ICONS[opts.icon] then
			Icons.Place(opts.icon, swatch, 34, swatchColor, opts.iconAccent)
		else
			Icons.Place(opts.icon, swatch, 30, Color3.new(1, 1, 1))
		end
	end

	local title = UIUtil.label({
		Parent = card, Text = opts.title or "?", Font = Theme.Font.Bold, TextSize = 14,
		Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 0, 16), TextTruncate = Enum.TextTruncate.AtEnd,
	})
	UIUtil.label({
		Parent = card, Text = opts.subtitle or (opts.rarity or ""), TextColor3 = rarityColor, TextSize = 11,
		Font = Theme.Font.Bold, Position = UDim2.fromOffset(0, 74), Size = UDim2.new(1, 0, 0, 14),
	})

	local btn = UIUtil.button({
		Parent = card, Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 24),
		BackgroundColor3 = Theme.Color.Accent, TextSize = 13, CornerRadius = Theme.CornerSmall,
	})

	local function refresh(state)
		opts.owned = state.owned
		opts.equipped = state.equipped
		if state.equipped then
			btn.Text = "EQUIPPED"
			btn.BackgroundColor3 = Theme.Color.PlayDark
			UIUtil.stroke(Theme.Color.Play, 2, card).Transparency = 0
		elseif state.owned then
			btn.Text = "EQUIP"
			btn.BackgroundColor3 = Theme.Color.Accent
		else
			btn.Text = opts.priceText or ((opts.cost and opts.cost > 0) and (tostring(opts.cost) .. " COINS") or "UNLOCK")
			btn.BackgroundColor3 = opts.priceColor or Theme.Color.Coin
			btn.TextColor3 = Color3.fromRGB(40, 30, 10)
		end
	end

	btn.MouseButton1Click:Connect(function()
		if opts.owned then
			onAction("equip")
		else
			onAction("buy")
		end
	end)

	refresh({ owned = opts.owned, equipped = opts.equipped })
	return { frame = card, refresh = refresh, button = btn }
end

-- Tween helper.
function UIUtil.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local ti = TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = TweenService:Create(inst, ti, props)
	t:Play()
	return t
end

return UIUtil
