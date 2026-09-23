--!strict
-- SeasonPass: the season track. Header with season name, current tier, an XP
-- bar and the Premium / +5 Tiers Robux buttons; below it a scrolling row of
-- 30 tiers, each with a FREE reward (top) and a gold PREMIUM reward (bottom).
-- Rewards render in 3D (blasters, cats wearing cosmetics, coin / gem props).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Season = require(ReplicatedStorage.Shared.Config.Season)
local Weapons = require(ReplicatedStorage.Shared.Config.Weapons)
local Cats = require(ReplicatedStorage.Shared.Config.Cats)
local Monetization = require(ReplicatedStorage.Shared.Config.Monetization)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local ShopArt = require(script.Parent.Parent.ShopArt)
local ClientState = require(script.Parent.Parent.Parent.ClientState)
local Monetize = require(script.Parent.Parent.Parent.Monetize)

local SeasonPass = {}

local player = Players.LocalPlayer
local GOLD = Color3.fromRGB(255, 200, 60)
local CARD = Color3.fromRGB(22, 38, 68)
local COL_W = 150

type Slot = { tier: number, track: string, button: TextButton, lock: Frame, stroke: UIStroke }
local slots: { Slot } = {}
local tierBadges: { [number]: Frame } = {}
local tierLabel: TextLabel, xpLabel: TextLabel, xpFill: Frame, premiumButton: TextButton

local function season()
	local p = ClientState.Profile
	return p and p.Season or { XP = 0, Free = {}, Premium = {} }
end

local function nameOf(r: any): string
	if r.Kind == "Coins" or r.Kind == "Gems" then
		return string.format("%d %s", r.Amount or 0, string.upper(r.Kind))
	end
	local lists = { Fur = Cats.FurById, Hat = Cats.HatById, Outfit = Cats.OutfitById, Accessory = Cats.AccessoryById, Emote = Cats.EmoteById }
	if r.Kind == "Skin" then
		local s = Weapons.GetSkin(r.Id)
		return string.upper((s and s.Name or r.Id) .. " SKIN")
	end
	local def = lists[r.Kind] and lists[r.Kind][r.Id]
	return string.upper((def and def.Name or r.Id) .. " " .. (r.Kind == "Fur" and "FUR" or r.Kind))
end

local function render(art: Frame, r: any)
	local p = ClientState.Profile
	local cat = p and p.Loadout and p.Loadout.Cat or {}
	local custom = { Fur = cat.Fur, Outfit = cat.Outfit, Hat = cat.Hat, Accessory = cat.Accessory }
	if r.Kind == "Coins" then
		ShopArt.Prop(art, "Coins")
	elseif r.Kind == "Gems" then
		ShopArt.Prop(art, "Gems", math.clamp(math.floor((r.Amount or 10) / 25) + 1, 1, 4))
	elseif r.Kind == "Skin" then
		ShopArt.Gun(art, p and p.Loadout and p.Loadout.Weapon or Weapons.DefaultLoadout, r.Id)
	elseif r.Kind == "Emote" then
		ShopArt.Cat(art, custom, "Full", r.Id)
	else
		custom[r.Kind] = r.Id
		ShopArt.Cat(art, custom, r.Kind == "Outfit" and "Full" or "Bust")
	end
end

local function refresh()
	local s = season()
	local xp = s.XP or 0
	local tier = Season.TierFor(xp)
	local into = xp - tier * Season.XPPerTier
	tierLabel.Text = string.format("TIER %d / %d", tier, Season.Tiers)
	if tier >= Season.Tiers then
		xpLabel.Text = "SEASON COMPLETE!"
		xpFill.Size = UDim2.fromScale(1, 1)
	else
		xpLabel.Text = string.format("%d / %d XP to tier %d", into, Season.XPPerTier, tier + 1)
		xpFill.Size = UDim2.fromScale(math.clamp(into / Season.XPPerTier, 0.02, 1), 1)
	end
	local premium = player:GetAttribute("SeasonPass") == true
	local pass = Monetization.Passes.SeasonPass
	premiumButton.Text = premium and "PREMIUM ACTIVE" or ("GET PREMIUM  R$ " .. tostring(pass and pass.Price or 299))
	premiumButton.BackgroundColor3 = premium and Color3.fromRGB(80, 70, 30) or GOLD
	for t, badge in pairs(tierBadges) do
		badge.BackgroundColor3 = t <= tier and Color3.fromRGB(64, 200, 255) or Color3.fromRGB(40, 56, 90)
	end
	for _, sl in ipairs(slots) do
		local claimed = (s[sl.track] or {})["t" .. sl.tier] == true
		local reached = sl.tier <= tier
		local locked = sl.track == "Premium" and not premium
		sl.lock.Visible = locked
		if claimed then
			sl.button.Text, sl.button.BackgroundColor3 = "CLAIMED", Color3.fromRGB(40, 90, 70)
		elseif reached and not locked then
			sl.button.Text, sl.button.BackgroundColor3 = "CLAIM", Color3.fromRGB(80, 214, 110)
		elseif locked then
			sl.button.Text, sl.button.BackgroundColor3 = "PREMIUM", Color3.fromRGB(120, 96, 30)
		else
			sl.button.Text, sl.button.BackgroundColor3 = "TIER " .. sl.tier, Color3.fromRGB(40, 56, 90)
		end
		sl.stroke.Color = (reached and not claimed and not locked) and Color3.fromRGB(110, 240, 140) or (sl.track == "Premium" and GOLD or Color3.fromRGB(60, 90, 140))
	end
end

local function rewardCard(parent: Instance, tier: number, track: string, r: any)
	local premium = track == "Premium"
	local card = UIUtil.make("Frame", {
		Parent = parent, Size = UDim2.new(1, 0, 0.5, -6), Position = premium and UDim2.new(0, 0, 0.5, 6) or UDim2.new(),
		BackgroundColor3 = premium and Color3.fromRGB(58, 46, 20) or CARD, BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(0, 14), card)
	if premium then
		UIUtil.gradient(Color3.fromRGB(110, 84, 26), Color3.fromRGB(40, 30, 14), 90, card)
	end
	local stroke = UIUtil.stroke(premium and GOLD or Color3.fromRGB(60, 90, 140), 1.5, card)
	UIUtil.label({ Parent = card, Text = premium and "PREMIUM" or "FREE", Font = Theme.Font.Bold, TextSize = 10, TextColor3 = premium and GOLD or Theme.Color.TextDim, Position = UDim2.fromOffset(8, 5), Size = UDim2.new(1, -16, 0, 12) })
	local art = UIUtil.make("Frame", { Parent = card, Position = UDim2.fromOffset(6, 18), Size = UDim2.new(1, -12, 1, -80), BackgroundTransparency = 1 }) :: Frame
	pcall(render, art, r)
	UIUtil.label({ Parent = card, Text = nameOf(r), Font = Theme.Font.Title, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Position = UDim2.new(0, 4, 1, -60), Size = UDim2.new(1, -8, 0, 28) })
	local btn = UIUtil.make("TextButton", {
		Parent = card, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -6), Size = UDim2.new(1, -12, 0, 26),
		Text = "", Font = Theme.Font.Title, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = true, BorderSizePixel = 0,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 8), btn)
	local lock = UIUtil.make("Frame", { Parent = card, Size = UDim2.new(1, 0, 1, -34), BackgroundColor3 = Color3.fromRGB(10, 10, 20), BackgroundTransparency = 0.45, BorderSizePixel = 0, Visible = false, ZIndex = 4 }) :: Frame
	UIUtil.corner(UDim.new(0, 14), lock)
	btn.MouseButton1Click:Connect(function()
		if premium and not player:GetAttribute("SeasonPass") then
			Monetize.PromptPass("SeasonPass")
			return
		end
		local ok, res = pcall(function()
			return Remotes.Get("ClaimSeason"):InvokeServer({ tier = tier, track = track })
		end)
		if ok and typeof(res) == "table" and not res.ok and res.reason == "locked" and Monetize.OnUnavailable then
			Monetize.OnUnavailable("Reach tier " .. tier .. " to claim this. Play matches for Season XP!")
		end
	end)
	table.insert(slots, { tier = tier, track = track, button = btn, lock = lock, stroke = stroke })
end

function SeasonPass.Build(parent)
	local root = UIUtil.make("Frame", { Parent = parent, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }) :: Frame

	-- Header
	local header = UIUtil.make("Frame", { Parent = root, Size = UDim2.new(1, 0, 0, 96), BackgroundColor3 = CARD, BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(0, 18), header)
	UIUtil.gradient(Color3.fromRGB(70, 60, 150), Color3.fromRGB(24, 40, 80), 0, header)
	UIUtil.label({ Parent = header, Text = Season.Name, Font = Theme.Font.Title, TextSize = 28, Position = UDim2.fromOffset(20, 10), Size = UDim2.new(0.55, 0, 0, 34) })
	tierLabel = UIUtil.label({ Parent = header, Text = "", Font = Theme.Font.Title, TextSize = 18, TextColor3 = Color3.fromRGB(150, 220, 255), Position = UDim2.fromOffset(20, 44), Size = UDim2.new(0.3, 0, 0, 22) })
	local track = UIUtil.make("Frame", { Parent = header, Position = UDim2.fromOffset(20, 70), Size = UDim2.new(0.5, 0, 0, 12), BackgroundColor3 = Color3.fromRGB(10, 16, 34), BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(1, 0), track)
	xpFill = UIUtil.make("Frame", { Parent = track, Size = UDim2.fromScale(0.1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }) :: Frame
	UIUtil.corner(UDim.new(1, 0), xpFill)
	UIUtil.gradient(Color3.fromRGB(110, 222, 255), Color3.fromRGB(150, 100, 255), 0, xpFill)
	xpLabel = UIUtil.label({ Parent = header, Text = "", TextSize = 13, TextColor3 = Theme.Color.TextDim, Position = UDim2.new(0.3, 20, 0, 46), Size = UDim2.new(0.2, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Right })

	premiumButton = UIUtil.make("TextButton", {
		Parent = header, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 14), Size = UDim2.fromOffset(250, 38),
		Text = "", Font = Theme.Font.Title, TextSize = 17, TextColor3 = Color3.fromRGB(50, 30, 0), AutoButtonColor = true, BorderSizePixel = 0,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 12), premiumButton)
	premiumButton.MouseButton1Click:Connect(function()
		Monetize.PromptPass("SeasonPass")
	end)
	local skip = UIUtil.make("TextButton", {
		Parent = header, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 0, 56), Size = UDim2.fromOffset(250, 28),
		Text = "+5 TIERS  R$ " .. tostring(Monetization.Products.SeasonTiers and Monetization.Products.SeasonTiers.Price or 99),
		Font = Theme.Font.Title, TextSize = 14, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Color3.fromRGB(52, 196, 104), AutoButtonColor = true, BorderSizePixel = 0,
	}) :: TextButton
	UIUtil.corner(UDim.new(0, 10), skip)
	skip.MouseButton1Click:Connect(function()
		Monetize.PromptProduct("SeasonTiers")
	end)

	-- Tier track (built the first time the screen opens)
	local scroller = UIUtil.make("ScrollingFrame", {
		Parent = root, Position = UDim2.fromOffset(0, 108), Size = UDim2.new(1, 0, 1, -108), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 6, ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.fromOffset(Season.Tiers * (COL_W + 12), 0),
	}) :: ScrollingFrame
	local built = false
	local function build()
		built = true
		for t = 1, Season.Tiers do
			local row = Season.Rewards[t]
			local col = UIUtil.make("Frame", { Parent = scroller, Position = UDim2.fromOffset((t - 1) * (COL_W + 12), 0), Size = UDim2.new(0, COL_W, 1, -12), BackgroundTransparency = 1 })
			local badge = UIUtil.make("Frame", { Parent = col, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.fromOffset(40, 28), BorderSizePixel = 0 }) :: Frame
			UIUtil.corner(UDim.new(1, 0), badge)
			UIUtil.label({ Parent = badge, Text = tostring(t), Font = Theme.Font.Title, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1) })
			tierBadges[t] = badge
			local cards = UIUtil.make("Frame", { Parent = col, Position = UDim2.fromOffset(0, 36), Size = UDim2.new(1, 0, 1, -36), BackgroundTransparency = 1 })
			rewardCard(cards, t, "Free", row.Free)
			rewardCard(cards, t, "Premium", row.Premium)
		end
		refresh()
		-- Start scrolled to the current tier.
		local tier = Season.TierFor(season().XP or 0)
		scroller.CanvasPosition = Vector2.new(math.max(0, (tier - 2) * (COL_W + 12)), 0)
	end
	root:GetPropertyChangedSignal("Visible"):Connect(function()
		if root.Visible and not built then
			build()
		end
	end)

	ClientState.ProfileChanged:Connect(function()
		if built then
			refresh()
		end
	end)
	player:GetAttributeChangedSignal("SeasonPass"):Connect(function()
		if built then
			refresh()
		end
	end)
	-- The header is always live.
	local function header()
		local s = season()
		local tier = Season.TierFor(s.XP or 0)
		tierLabel.Text = string.format("TIER %d / %d", tier, Season.Tiers)
		local into = (s.XP or 0) - tier * Season.XPPerTier
		xpLabel.Text = tier >= Season.Tiers and "SEASON COMPLETE!" or string.format("%d / %d XP to tier %d", into, Season.XPPerTier, tier + 1)
		xpFill.Size = UDim2.fromScale(tier >= Season.Tiers and 1 or math.clamp(into / Season.XPPerTier, 0.02, 1), 1)
		local premium = player:GetAttribute("SeasonPass") == true
		premiumButton.Text = premium and "PREMIUM ACTIVE" or ("GET PREMIUM  R$ " .. tostring(Monetization.Passes.SeasonPass.Price))
		premiumButton.BackgroundColor3 = premium and Color3.fromRGB(80, 70, 30) or GOLD
	end
	ClientState.ProfileChanged:Connect(header)
	header()

	SeasonPass.Root = root
	return root
end

return SeasonPass
