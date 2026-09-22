--!strict
-- Theme: shared colors, fonts, and sizing for the PAW MAYHEM UI. One place to
-- retune the whole look. Palette echoes the reference: dark navy panels, cyan
-- accents, playful highlights, a green "Play" call-to-action.

local Theme = {}

Theme.Color = {
	Bg = Color3.fromRGB(16, 20, 34),
	Panel = Color3.fromRGB(24, 30, 48),
	PanelLight = Color3.fromRGB(34, 42, 66),
	PanelDark = Color3.fromRGB(18, 23, 38),
	Stroke = Color3.fromRGB(58, 70, 104),

	Text = Color3.fromRGB(240, 244, 255),
	TextDim = Color3.fromRGB(160, 172, 200),
	TextMuted = Color3.fromRGB(110, 122, 150),

	Accent = Color3.fromRGB(64, 156, 255), -- primary cyan-blue
	Accent2 = Color3.fromRGB(150, 110, 255), -- purple
	Play = Color3.fromRGB(96, 210, 120), -- green CTA
	PlayDark = Color3.fromRGB(70, 175, 96),
	Coin = Color3.fromRGB(255, 205, 90),
	Gem = Color3.fromRGB(180, 120, 255),
	Danger = Color3.fromRGB(255, 90, 90),
	Blue = Color3.fromRGB(64, 132, 255),
	Red = Color3.fromRGB(255, 82, 82),
	Success = Color3.fromRGB(96, 210, 120),
	Warn = Color3.fromRGB(255, 180, 70),
}

-- Rarity colors for weapon/skin cards.
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
Theme.CornerBig = UDim.new(0, 18)

return Theme
