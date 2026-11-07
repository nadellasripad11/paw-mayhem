--!strict
-- theme: shared colors, fonts, and sizing for the paw mayhem ui. one place to
-- retune the whole look. it matches the retro lobby (shared/lobbypalette):
-- walnut brown panels, cream text, one orange accent, a green "play".

local Theme = {}

Theme.Color = {
	-- older names some screens still use (walnut now; uiutil.restyle maps any
	-- old navy left in a screen onto the surfaces below).
	Bg = Color3.fromRGB(56, 39, 30),
	Panel = Color3.fromRGB(74, 52, 40),
	PanelLight = Color3.fromRGB(112, 82, 64),
	PanelDark = Color3.fromRGB(60, 42, 32),
	Stroke = Color3.fromRGB(150, 112, 88),

	Text = Color3.fromRGB(255, 244, 230), -- cream (#FFF4E6)
	TextDim = Color3.fromRGB(217, 195, 174), -- (#D9C3AE)
	TextMuted = Color3.fromRGB(176, 150, 128),

	Accent = Color3.fromRGB(242, 147, 58), -- the one accent: orange (#F2933A, see design/DESIGN.md)
	Accent2 = Color3.fromRGB(217, 98, 43), -- burnt orange (bar gradients)
	Play = Color3.fromRGB(108, 225, 104), -- green cta
	PlayDark = Color3.fromRGB(51, 158, 91),
	Coin = Color3.fromRGB(255, 207, 72),
	Gem = Color3.fromRGB(196, 107, 255),
	Danger = Color3.fromRGB(255, 89, 111),
	Red = Color3.fromRGB(255, 78, 91),
	Success = Color3.fromRGB(108, 225, 104),
	Warn = Color3.fromRGB(255, 186, 67),

	-- the clean set (design/DESIGN.md): three walnut surface levels, hairline
	-- outlines (white at low opacity) and one orange accent. blue is only for
	-- the blue team in matches, never for buttons.
	Surface = Color3.fromRGB(74, 52, 40), -- panels, bars (walnut #4A3428)
	Surface2 = Color3.fromRGB(92, 66, 51), -- rows, cards, buttons (#5C4233)
	Surface3 = Color3.fromRGB(112, 82, 64), -- hover / selected backgrounds (#705240)
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
