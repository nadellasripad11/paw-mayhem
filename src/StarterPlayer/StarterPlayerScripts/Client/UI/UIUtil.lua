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

-- ── the clean kit (flat, Rivals-like) ────────────────────────────────────────
-- Everything new is built from these so screens share one look: flat
-- surfaces, a hairline outline, one radius scale, the same hover feedback.

-- A thin light outline (white at low opacity).
function UIUtil.hairline(parent: Instance, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = Theme.Color.Line
	s.Transparency = transparency or Theme.LineAlpha
	s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- A flat surface: level 1 (screens), 2 (cards, buttons) or 3 (selected).
function UIUtil.surface(props: { [string]: any }, level: number?, radius: UDim?): Frame
	local f = UIUtil.make("Frame", props) :: Frame
	local lv = level or 2
	f.BackgroundColor3 = (props.BackgroundColor3 :: Color3?) or (lv == 1 and Theme.Color.Surface or lv == 3 and Theme.Color.Surface3 or Theme.Color.Surface2)
	f.BorderSizePixel = 0
	UIUtil.corner(radius or Theme.Corner, f)
	UIUtil.hairline(f)
	return f
end

-- Hover / press feedback for any button: a small scale pop and a brighter
-- outline (if it has one).
function UIUtil.feedback(b: GuiButton, scaleTo: number?)
	local sc = b:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	sc.Parent = b
	local stroke = b:FindFirstChildOfClass("UIStroke")
	local base = stroke and stroke.Transparency or 0
	b.MouseEnter:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = scaleTo or 1.05 }):Play()
		if stroke then
			stroke.Transparency = math.min(base, Theme.LineHover)
		end
	end)
	b.MouseLeave:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.12), { Scale = 1 }):Play()
		if stroke then
			stroke.Transparency = base
		end
	end)
	b.MouseButton1Down:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.06), { Scale = 0.96 }):Play()
	end)
	b.MouseButton1Up:Connect(function()
		TweenService:Create(sc, TweenInfo.new(0.1), { Scale = scaleTo or 1.05 }):Play()
	end)
end

-- A small dark label that shows under `owner` while the mouse is over it.
function UIUtil.tooltip(owner: GuiObject, text: string)
	local tip = UIUtil.label({
		Parent = owner, Name = "Tooltip", Text = text, Font = Theme.Font.Bold, TextSize = Theme.Text.Caption,
		TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 6),
		Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 0.05,
		BackgroundColor3 = Theme.Color.Surface, Visible = false, ZIndex = 50,
	})
	UIUtil.corner(UDim.new(0, 6), tip)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
	pad.Parent = tip
	owner.MouseEnter:Connect(function()
		tip.Visible = true
	end)
	owner.MouseLeave:Connect(function()
		tip.Visible = false
	end)
	return tip
end

-- A square icon button (rounded), e.g. the top bar's leaderboard / settings.
-- `draw(slot)` puts the icon in a centred slot. Returns the button.
function UIUtil.iconButton(props: { [string]: any }, draw: (Frame) -> (), tip: string?, onClick: (() -> ())?): TextButton
	local size = props.Size or UDim2.fromOffset(40, 40)
	local b = UIUtil.make("TextButton", props) :: TextButton
	b.Size = size
	b.Text = ""
	b.AutoButtonColor = false
	b.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.Surface2
	b.BackgroundTransparency = props.BackgroundTransparency or 0.08
	b.BorderSizePixel = 0
	UIUtil.corner(props.CornerRadius or Theme.Corner, b)
	UIUtil.hairline(b)
	local slot = UIUtil.make("Frame", {
		Parent = b, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.55, 0.55), BackgroundTransparency = 1, ZIndex = b.ZIndex + 1,
	}) :: Frame
	draw(slot)
	UIUtil.feedback(b)
	if tip then
		UIUtil.tooltip(b, tip)
	end
	if onClick then
		b.MouseButton1Click:Connect(onClick)
	end
	return b
end

-- A solid call-to-action button (green by default) with a darker lip under
-- it for depth. Returns the button and its label.
function UIUtil.primaryButton(props: { [string]: any }, text: string, onClick: (() -> ())?, color: Color3?, lip: Color3?): (TextButton, TextLabel)
	local b = UIUtil.make("TextButton", props) :: TextButton
	b.Text = ""
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.BackgroundColor3 = color or Theme.Color.PlayGreen
	UIUtil.corner(props.CornerRadius or Theme.Corner, b)
	-- (A sibling, not a child: children always draw on top of their parent.)
	local under = UIUtil.make("Frame", {
		Parent = b.Parent, Name = b.Name .. "Lip", AnchorPoint = b.AnchorPoint, Position = b.Position + UDim2.fromOffset(0, 4),
		Size = b.Size, BackgroundColor3 = lip or Theme.Color.PlayGreenDark, BorderSizePixel = 0, ZIndex = b.ZIndex - 1,
	}) :: Frame
	UIUtil.corner(props.CornerRadius or Theme.Corner, under)
	local label = UIUtil.label({
		Parent = b, Text = text, Font = Theme.Font.Title, TextSize = props.TextSize or Theme.Text.Title,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = b.ZIndex + 1,
		TextColor3 = Color3.new(1, 1, 1),
	})
	UIUtil.feedback(b, 1.03)
	if onClick then
		b.MouseButton1Click:Connect(onClick)
	end
	return b, label
end

-- A quiet button: a surface with a hairline and text.
function UIUtil.secondaryButton(props: { [string]: any }, text: string, onClick: (() -> ())?): TextButton
	local b = UIUtil.make("TextButton", props) :: TextButton
	b.Text = text
	b.Font = props.Font or Theme.Font.Bold
	b.TextSize = props.TextSize or Theme.Text.Body
	b.TextColor3 = props.TextColor3 or Theme.Color.Text
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.BackgroundColor3 = props.BackgroundColor3 or Theme.Color.Surface2
	UIUtil.corner(props.CornerRadius or Theme.CornerSmall, b)
	UIUtil.hairline(b)
	UIUtil.feedback(b, 1.03)
	if onClick then
		b.MouseButton1Click:Connect(onClick)
	end
	return b
end

-- A vertical rail of tabs. tabs = { { id, label } }; onSelect(id). Returns
-- select(id) so the screen can pick a tab itself.
function UIUtil.tabRail(parent: Instance, tabs: { { id: string, label: string } }, onSelect: (string) -> ()): (string) -> ()
	UIUtil.listLayout(parent, Theme.Space.S)
	local buttons: { [string]: TextButton } = {}
	local function select(id: string)
		for tid, b in pairs(buttons) do
			local on = tid == id
			b.BackgroundColor3 = on and Theme.Color.Blue or Theme.Color.Surface2
			b.TextColor3 = on and Color3.new(1, 1, 1) or Theme.Color.TextDim
			local st = b:FindFirstChildOfClass("UIStroke")
			if st then
				st.Transparency = on and 1 or Theme.LineAlpha
			end
		end
		onSelect(id)
	end
	for i, t in ipairs(tabs) do
		local b = UIUtil.make("TextButton", {
			Parent = parent, Name = t.id, LayoutOrder = i, Size = UDim2.new(1, 0, 0, 40), Text = t.label,
			Font = Theme.Font.Bold, TextSize = Theme.Text.Body, AutoButtonColor = false, BorderSizePixel = 0,
			BackgroundColor3 = Theme.Color.Surface2, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left,
		}) :: TextButton
		UIUtil.corner(Theme.CornerSmall, b)
		UIUtil.hairline(b)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 14)
		pad.Parent = b
		b.MouseButton1Click:Connect(function()
			select(t.id)
		end)
		buttons[t.id] = b
	end
	return select
end

-- A currency pill: icon, amount, optional "+" on the right. Returns the
-- pill, the amount label and the "+" button (if any).
function UIUtil.currencyPill(props: { [string]: any }, icon: string, iconColor: Color3, withPlus: boolean?): (Frame, TextLabel, TextButton?)
	local pill = UIUtil.make("Frame", props) :: Frame
	pill.BackgroundColor3 = Theme.Color.Surface
	pill.BackgroundTransparency = 0.12
	pill.BorderSizePixel = 0
	UIUtil.corner(UDim.new(1, 0), pill)
	UIUtil.hairline(pill)
	local slot = UIUtil.make("Frame", {
		Parent = pill, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 20, 0.5, 0), Size = UDim2.fromOffset(24, 24),
		BackgroundTransparency = 1, ZIndex = pill.ZIndex + 1,
	})
	Icons.Place(icon, slot, 24, iconColor)
	local amount = UIUtil.label({
		Parent = pill, Text = "0", Font = Theme.Font.Title, TextSize = 18, Position = UDim2.fromOffset(38, 0),
		Size = UDim2.new(1, withPlus and -72 or -46, 1, 0), ZIndex = pill.ZIndex + 1,
	})
	local plus: TextButton? = nil
	if withPlus then
		local p = UIUtil.make("TextButton", {
			Parent = pill, Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -5, 0.5, 0),
			Size = UDim2.fromOffset(26, 26), BackgroundColor3 = Theme.Color.Blue, BorderSizePixel = 0, ZIndex = pill.ZIndex + 1,
		}) :: TextButton
		UIUtil.corner(UDim.new(1, 0), p)
		Icons.Place("Plus", p, 14, Color3.new(1, 1, 1))
		UIUtil.feedback(p, 1.12)
		plus = p
	end
	return pill, amount, plus
end

return UIUtil
