--!strict
-- Theme: shared colors, fonts, and sizing for the PAW MAYHEM UI. One place to
-- retune the whole look. Palette echoes the reference: dark navy panels, cyan
-- accents, playful highlights, a green "Play" call-to-action.

local Theme = {}

Theme.Color = {
	-- Deep sky/navy surfaces from the reference UI. Keep these opaque so
	-- every screen remains legible over the illustrated world backdrop.
	Bg = Color3.fromRGB(8, 21, 43),
	Panel = Color3.fromRGB(13, 36, 67),
	PanelLight = Color3.fromRGB(22, 57, 91),
	PanelDark = Color3.fromRGB(8, 28, 55),
	Stroke = Color3.fromRGB(54, 108, 150),

	Text = Color3.fromRGB(246, 250, 255),
	TextDim = Color3.fromRGB(185, 211, 232),
	TextMuted = Color3.fromRGB(123, 158, 185),

	Accent = Color3.fromRGB(35, 190, 255), -- electric cyan
	Accent2 = Color3.fromRGB(171, 91, 255), -- blaster purple
	Play = Color3.fromRGB(108, 225, 104), -- green CTA
	PlayDark = Color3.fromRGB(51, 158, 91),
	Coin = Color3.fromRGB(255, 207, 72),
	Gem = Color3.fromRGB(224, 96, 255),
	Danger = Color3.fromRGB(255, 89, 111),
	Blue = Color3.fromRGB(22, 145, 255),
	Red = Color3.fromRGB(255, 78, 91),
	Success = Color3.fromRGB(108, 225, 104),
	Warn = Color3.fromRGB(255, 186, 67),
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

Theme.Corner = UDim.new(0, 14)
Theme.CornerSmall = UDim.new(0, 9)
Theme.CornerBig = UDim.new(0, 22)

return Theme
