--!strict
-- uiutil: small factory helpers so screens stay declarative and consistent.
-- everything is built in code (no pre-made rbxm assets required).

local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local Theme = require(script.Parent.Theme)
local Icons = require(script.Parent.Icons)

local UIUtil = {}

-- icons that render in their own natural tones (a miniature "portrait" of the
-- item) rather than as a flat white glyph — every gun silhouette + the cat
-- face preview.
local NATURAL_TONE_ICONS = {
	CatFace = true, CatBody = true, Gun = true, GunHeavy = true, GunFast = true, GunSniper = true,
	GunCannon = true, GunBubble = true, GunIce = true, GunGolden = true,
}

-- the top inset roblox reserves for its own topbar (avatar/menu/chat icons).
-- any full-screen (ignoreguiinset = true) gui must add this to top-anchored
-- content or roblox's own chrome will render on top of it.
function UIUtil.topInset(): number
	local ok, inset = pcall(function()
		return GuiService:GetGuiInset()
	end)
	if ok and inset then
		return inset.Y
	end
	return 36
end

-- generic instance factory: uiutil.make("frame", {props}, {children})
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
	-- (only one gradient works per object: a new one replaces the old)
	local old = parent and parent:FindFirstChildOfClass("UIGradient")
	if old then
		old:Destroy()
	end
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(c1, c2)
	g.Rotation = rotation or 90
	if parent then
		g.Parent = parent
	end
	return g
end

-- a rounded panel with optional stroke.
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

-- a clickable button with hover/press feedback. returns the textbutton.
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

-- horizontal stat bar (0..1). returns {frame, set(fraction)}.
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

-- a catalog item card (weapon / skin / cosmetic). opts:
--   { title, subtitle, rarity, cost, owned, equipped, accent, icon, iconaccent }
-- `icon` is a string key into icons.registry (e.g. "gun", "sparkle", "catface").
-- onaction(kind) is called with "equip" or "buy". returns { frame, refresh }.
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
		-- catface / gun render in their own natural tones (a miniature "portrait"
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

-- tween helper.
function UIUtil.tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local ti = TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local t = TweenService:Create(inst, ti, props)
	t:Play()
	return t
end

-- ── the clean kit (flat, rivals-like) ────────────────────────────────────────
-- everything new is built from these so screens share one look: flat
-- surfaces, a hairline outline, one radius scale, the same hover feedback.

-- a thin light outline (white at low opacity).
function UIUtil.hairline(parent: Instance, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = Theme.Color.Line
	s.Transparency = transparency or Theme.LineAlpha
	s.Thickness = 1
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

-- a flat surface: level 1 (screens), 2 (cards, buttons) or 3 (selected).
function UIUtil.surface(props: { [string]: any }, level: number?, radius: UDim?): Frame
	local f = UIUtil.make("Frame", props) :: Frame
	local lv = level or 2
	f.BackgroundColor3 = (props.BackgroundColor3 :: Color3?) or (lv == 1 and Theme.Color.Surface or lv == 3 and Theme.Color.Surface3 or Theme.Color.Surface2)
	f.BorderSizePixel = 0
	UIUtil.corner(radius or Theme.Corner, f)
	UIUtil.hairline(f)
	return f
end

-- hover / press feedback for any button: a small scale pop and a brighter
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

-- a small dark label that shows under `owner` while the mouse is over it.
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

-- a square icon button (rounded), e.g. the top bar's leaderboard / settings.
-- `draw(slot)` puts the icon in a centred slot. returns the button.
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

-- a solid call-to-action button (green by default) with a darker lip under
-- it for depth. returns the button and its label.
function UIUtil.primaryButton(props: { [string]: any }, text: string, onClick: (() -> ())?, color: Color3?, lip: Color3?): (TextButton, TextLabel)
	local b = UIUtil.make("TextButton", props) :: TextButton
	b.Text = ""
	b.AutoButtonColor = false
	b.BorderSizePixel = 0
	b.BackgroundColor3 = color or Theme.Color.PlayGreen
	UIUtil.corner(props.CornerRadius or Theme.Corner, b)
	-- (a sibling, not a child: children always draw on top of their parent.)
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

-- a quiet button: a surface with a hairline and text.
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

-- a vertical rail of tabs. tabs = { { id, label } }; onselect(id). returns
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

-- a currency pill: icon, amount, optional "+" on the right. returns the
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


-- ── restyle: bring older screens onto the clean look ────────────────────────
-- older screens hard-code their own navy shades, bluish outlines and
-- gradients. restyle(root) maps every navy background onto the three surface
-- levels (by brightness), turns bluish outlines into hairlines, drops navy
-- gradients and swaps the old cyan highlight for the accent blue - now, for
-- anything added later, and whenever a screen recolours something (selected
-- tabs, equipped cards), so they all share one look.
local OLD_CYAN = Color3.fromRGB(64, 200, 255)

local function luminance(c: Color3): number
	return 0.2126 * c.R + 0.7152 * c.G + 0.0722 * c.B
end

local function isNavy(c: Color3): boolean
	return c.B >= c.R + 0.04 and c.B >= c.G and luminance(c) < 0.3
end

local function surfaceFor(c: Color3): Color3
	local l = luminance(c)
	if l < 0.09 then
		return Theme.Color.Surface
	elseif l < 0.15 then
		return Theme.Color.Surface2
	end
	return Theme.Color.Surface3
end

local function restyleOne(d: Instance)
	if d:IsA("GuiObject") and d.BackgroundTransparency < 1 then
		local function fix()
			local c = d.BackgroundColor3
			if c == OLD_CYAN then
				d.BackgroundColor3 = Theme.Color.Blue
			elseif isNavy(c) then
				local want = surfaceFor(c)
				if want ~= c then
					d.BackgroundColor3 = want
				end
			end
		end
		fix()
		d:GetPropertyChangedSignal("BackgroundColor3"):Connect(fix)
	elseif d:IsA("UIStroke") and d.Thickness <= 2.5 then
		local function fix()
			if isNavy(d.Color) or (d.Color.B > d.Color.R and luminance(d.Color) < 0.65 and d.Color ~= Theme.Color.Blue) then
				d.Color = Theme.Color.Line
				d.Transparency = math.max(d.Transparency, Theme.LineAlpha)
				d.Thickness = 1
			end
		end
		fix()
		d:GetPropertyChangedSignal("Color"):Connect(fix)
	elseif d:IsA("UIGradient") then
		local keys = d.Color.Keypoints
		if #keys >= 2 and isNavy(keys[1].Value) and isNavy(keys[#keys].Value) then
			d.Enabled = false
		end
	end
end

function UIUtil.restyle(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		restyleOne(d)
	end
	root.DescendantAdded:Connect(function(d)
		task.defer(restyleOne, d) -- after the builder has set its properties
	end)
end

-- ── polish: the raised, glossy look for whole screens ───────────────────────
-- screens build their own buttons and cards; this goes over a screen and
-- finishes them in one style:
--   * coloured action buttons (buy, equip, claim, vote...) get a gloss: lighter
--     at the top, a soft shine across the upper half, a darker outline and an
--     outlined label;
--   * dark buttons and cards get a gentle top-lit gradient so they read as
--     raised panels, not flat boxes.
-- anything with its own gradient, inside a 3d view, or marked nopolish is
-- left alone. uiutil.polish(root) also catches cards made later.
local function lum(c: Color3): number
	return 0.3 * c.R + 0.59 * c.G + 0.11 * c.B
end

local function sat(c: Color3): number
	return math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B)
end

function UIUtil.gloss(b: GuiObject, color: Color3?)
	if b:FindFirstChildOfClass("UIGradient") then
		return
	end
	local c = color or b.BackgroundColor3
	local white, black = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	-- (a uigradient's colours multiply the background: light top, darker foot)
	UIUtil.gradient(white, Color3.new(0.78, 0.78, 0.78), 90, b)
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = white
	shine.BackgroundTransparency = 0.78
	shine.Position = UDim2.new(0, 4, 0, 3)
	shine.Size = UDim2.new(1, -8, 0.44, 0)
	shine.ZIndex = b.ZIndex
	shine.Active = false
	local corner = b:FindFirstChildOfClass("UICorner")
	if corner then
		local sc = Instance.new("UICorner")
		sc.CornerRadius = UDim.new(corner.CornerRadius.Scale, math.max(0, corner.CornerRadius.Offset - 3))
		sc.Parent = shine
	end
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(0.1, 1)
	fade.Parent = shine
	shine.Parent = b
	local stroke = b:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = b
	end
	stroke.Color = c:Lerp(black, 0.5)
	stroke.Transparency = 0.1
	stroke.Thickness = math.max(stroke.Thickness, 2.6) -- (over 2.5: restyle leaves it alone)
	local function outline(t: Instance)
		if t:IsA("TextLabel") or t:IsA("TextButton") then
			t.TextStrokeColor3 = c:Lerp(black, 0.6)
			t.TextStrokeTransparency = math.min(t.TextStrokeTransparency, 0.3)
		end
	end
	outline(b)
	for _, ch in ipairs(b:GetChildren()) do
		outline(ch)
	end
end

local function raise(f: GuiObject)
	if f:FindFirstChildOfClass("UIGradient") then
		return
	end
	UIUtil.gradient(Color3.new(1, 1, 1), Color3.new(0.72, 0.72, 0.76), 90, f)
end

local function polishOne(inst: Instance)
	if not inst:IsA("GuiObject") or inst:GetAttribute("NoPolish") or inst:FindFirstAncestorOfClass("ViewportFrame") then
		return
	end
	local g = inst :: GuiObject
	if g.BackgroundTransparency > 0.4 or not g:FindFirstChildOfClass("UICorner") or g.Name == "Shine" then
		return
	end
	local size = g.AbsoluteSize
	if size.X == 0 and size.Y == 0 then
		-- (a hidden screen: go by its set size; a scaled size counts as big)
		local function px(d: UDim): number
			return d.Scale > 0 and 999 or d.Offset
		end
		size = Vector2.new(px(g.Size.X), px(g.Size.Y))
	end
	if size.Y < 18 or size.X < 18 then
		return
	end
	local c = g.BackgroundColor3
	if g:IsA("GuiButton") then
		if sat(c) > 0.22 and lum(c) > 0.22 then
			UIUtil.gloss(g)
		else
			raise(g)
		end
	elseif g:IsA("Frame") and size.Y >= 40 and size.X >= 60 and lum(c) < 0.3 then
		raise(g)
	end
end

function UIUtil.polish(root: Instance)
	for _, d in ipairs(root:GetDescendants()) do
		polishOne(d)
	end
	root.DescendantAdded:Connect(function(d)
		-- (after the screen has finished setting it up)
		task.defer(function()
			if d.Parent then
				polishOne(d)
			end
		end)
	end)
end

return UIUtil
