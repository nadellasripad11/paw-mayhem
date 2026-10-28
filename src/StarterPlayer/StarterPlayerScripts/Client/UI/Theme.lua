--!strict
-- theme: shared colors, fonts, and sizing for the paw mayhem ui. one place to
-- retune the whole look. palette echoes the reference: dark navy panels, cyan
-- accents, playful highlights, a green "play" call-to-action.

local Theme = {}

Theme.Color = {
	-- deep sky/navy surfaces from the reference ui. keep these opaque so
	-- every screen remains legible over the illustrated world backdrop.
	Bg = Color3.fromRGB(8, 21, 43),
	Panel = Color3.fromRGB(13, 36, 67),
	PanelLight = Color3.fromRGB(22, 57, 91),
	PanelDark = Color3.fromRGB(8, 28, 55),
	Stroke = Color3.fromRGB(54, 108, 150),

	Text = Color3.fromRGB(246, 250, 255),
	TextDim = Color3.fromRGB(185, 211, 232),
	TextMuted = Color3.fromRGB(123, 158, 185),

	Accent = Color3.fromRGB(64, 156, 255), -- the one accent blue (same as blue)
	Accent2 = Color3.fromRGB(171, 91, 255), -- blaster purple
	Play = Color3.fromRGB(108, 225, 104), -- green cta
	PlayDark = Color3.fromRGB(51, 158, 91),
	Coin = Color3.fromRGB(255, 207, 72),
	Gem = Color3.fromRGB(224, 96, 255),
	Danger = Color3.fromRGB(255, 89, 111),
	Red = Color3.fromRGB(255, 78, 91),
	Success = Color3.fromRGB(108, 225, 104),
	Warn = Color3.fromRGB(255, 186, 67),

	-- the clean set the ui is moving to (flat, rivals-like): three surface
	-- levels, hairline outlines (white at low opacity) and one blue accent.
	Surface = Color3.fromRGB(17, 21, 34), -- screens, bars
	Surface2 = Color3.fromRGB(26, 31, 48), -- cards, buttons
	Surface3 = Color3.fromRGB(38, 45, 68), -- hover / selected backgrounds
	Line = Color3.fromRGB(255, 255, 255), -- used at linealpha
	Blue = Color3.fromRGB(64, 156, 255),
	PlayGreen = Color3.fromRGB(76, 196, 92),
	PlayGreenDark = Color3.fromRGB(46, 140, 62),
}

-- hairline outline opacity (uistroke.transparency) and the hover version.
Theme.LineAlpha = 0.86
Theme.LineHover = 0.6

-- spacing scale (px) and text sizes, so every screen lines up the same way.
Theme.Space = { XS = 4, S = 8, M = 12, L = 16, XL = 24 }
Theme.Text = { Caption = 12, Body = 14, Label = 16, Title = 22, Display = 32 }

-- rarity colors for weapon/skin cards.
Theme.Rarity = {
	Common = Color3.fromRGB(150, 160, 180),
	Uncommon = Color3.fromRGB(110, 210, 130),
	Rare = Color3.fromRGB(90, 150, 255),
	Epic = Color3.fromRGB(180, 110, 255),
	Legendary = Color3.fromRGB(255, 170, 70),
	Mythic = Color3.fromRGB(255, 110, 170),
}

Theme.Font = {
	Title = Enum.Font.FredokaOne,
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.Gotham,
	Bold = Enum.Font.GothamBold,
	Number = Enum.Font.GothamBlack,
}

Theme.Corner = UDim.new(0, 12)
Theme.CornerSmall = UDim.new(0, 8)
Theme.CornerBig = UDim.new(0, 16)

return Theme
