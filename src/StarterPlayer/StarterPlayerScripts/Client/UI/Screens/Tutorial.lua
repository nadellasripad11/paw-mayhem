--!strict
-- Tutorial: a short step-by-step intro for first-time players (shown once,
-- before their first match). Each step has a posed 3D cat and a tip, with
-- controls matched to the device. Finishing or skipping tells the server.

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Theme = require(script.Parent.Parent.Theme)
local UIUtil = require(script.Parent.Parent.UIUtil)
local ShopArt = require(script.Parent.Parent.ShopArt)
local ClientState = require(script.Parent.Parent.Parent.ClientState)

local Tutorial = {}

local player = Players.LocalPlayer
local gui: ScreenGui?
local onFinish: (() -> ())? = nil

local function mobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function steps()
	local m = mobile()
	return {
		{ title = "WELCOME TO PAW MAYHEM!", body = "Two teams of cats battle on floating islands. Knock the other team off the map to win!", pose = "Wave" },
		{ title = "MOVE + JUMP", body = m and "Use the left stick to move. Tap JUMP to jump, and tap it again in the air to DOUBLE JUMP." or "WASD to move. SPACE to jump, and press it again in the air to DOUBLE JUMP. Hold SHIFT to sprint.", pose = "Happy" },
		{ title = "BLAST THEM", body = m and "Tap FIRE to shoot your blaster. Every hit raises the enemy's knockback %." or "Click to shoot your blaster. Every hit raises the enemy's knockback %.", pose = "Flex" },
		{ title = "KNOCK THEM OFF", body = "The higher someone's %, the further they fly. Blast them off the island for a RINGOUT!", pose = "Celebrate" },
		{ title = "DASH TO SURVIVE", body = m and "Tap DASH to zip out of danger. Getting knocked off? Dash + double jump back!" or "Press Q to dash out of danger. Getting knocked off? Dash + double jump back!", pose = "Spin" },
		{ title = "GRAB THE GOODIES", body = "Supply drops fall from the sky, jump pads launch you across the map, and healing pickups keep you in the fight.", pose = "Dance" },
		{ title = "YOU'RE READY!", body = "Every match earns coins, XP and Season Pass rewards. Customize your cat and pick a map to play!", pose = "Celebrate" },
	}
end

function Tutorial.ShouldShow(): boolean
	local p = ClientState.Profile
	return p ~= nil and p.TutorialDone ~= true and ((p.Stats and p.Stats.Matches) or 0) == 0
end

function Tutorial.Open(finished: (() -> ())?)
	onFinish = finished
	if gui then
		gui:Destroy()
	end
	local g = UIUtil.make("ScreenGui", {
		Name = "PawTutorial", Parent = player:WaitForChild("PlayerGui"), IgnoreGuiInset = true,
		ResetOnSpawn = false, DisplayOrder = 40,
	}) :: ScreenGui
	gui = g
	UIUtil.make("Frame", { Parent = g, Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(4, 10, 24), BackgroundTransparency = 0.3, BorderSizePixel = 0 })
	local card = UIUtil.make("Frame", {
		Parent = g, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(760, 380),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
	})
	UIUtil.corner(UDim.new(0, 24), card)
	UIUtil.gradient(Color3.fromRGB(46, 90, 160), Color3.fromRGB(14, 24, 50), 90, card)
	UIUtil.stroke(Color3.fromRGB(120, 210, 255), 2, card).Transparency = 0.4
	local scale = Instance.new("UIScale")
	scale.Parent = card
	local vp = workspace.CurrentCamera.ViewportSize
	scale.Scale = math.min(1, (vp.X - 30) / 760, (vp.Y - 40) / 380)

	local artHolder = UIUtil.make("Frame", { Parent = card, Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(280, 348), BackgroundColor3 = Color3.fromRGB(20, 40, 80), BorderSizePixel = 0 })
	UIUtil.corner(UDim.new(0, 18), artHolder)
	local title = UIUtil.label({ Parent = card, Text = "", Font = Theme.Font.Title, TextSize = 32, TextColor3 = Color3.fromRGB(255, 214, 90), Position = UDim2.fromOffset(320, 40), Size = UDim2.fromOffset(420, 40), TextWrapped = true })
	local body = UIUtil.label({ Parent = card, Text = "", TextSize = 19, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(320, 96), Size = UDim2.fromOffset(420, 150) })
	local dots = UIUtil.make("Frame", { Parent = card, Position = UDim2.fromOffset(320, 262), Size = UDim2.fromOffset(420, 12), BackgroundTransparency = 1 })
	UIUtil.listLayout(dots, 8, Enum.FillDirection.Horizontal)

	local function button(text: string, x: number, w: number, color: Color3, textColor: Color3): TextButton
		local b = UIUtil.make("TextButton", {
			Parent = card, Position = UDim2.fromOffset(x, 300), Size = UDim2.fromOffset(w, 52), Text = text, Font = Theme.Font.Title,
			TextSize = 20, TextColor3 = textColor, BackgroundColor3 = color, AutoButtonColor = true, BorderSizePixel = 0,
		}) :: TextButton
		UIUtil.corner(UDim.new(0, 14), b)
		return b
	end
	local skip = button("SKIP", 320, 110, Color3.fromRGB(40, 56, 90), Color3.new(1, 1, 1))
	local nextB = button("NEXT", 540, 200, Color3.fromRGB(80, 214, 110), Color3.fromRGB(10, 40, 20))

	local list = steps()
	local index = 1
	local function finish()
		Remotes.Get("TutorialDone"):FireServer()
		g:Destroy()
		gui = nil
		if onFinish then
			onFinish()
		end
	end
	local function show()
		local st = list[index]
		title.Text = st.title
		body.Text = st.body
		nextB.Text = index == #list and "LET'S PLAY!" or "NEXT"
		artHolder:ClearAllChildren()
		UIUtil.corner(UDim.new(0, 18), artHolder)
		local p = ClientState.Profile
		local cat = p and p.Loadout and p.Loadout.Cat or {}
		pcall(ShopArt.Cat, artHolder, { Fur = cat.Fur, Outfit = cat.Outfit, Hat = cat.Hat, Accessory = cat.Accessory }, "Full", st.pose)
		for _, d in ipairs(dots:GetChildren()) do
			if d:IsA("Frame") then
				d:Destroy()
			end
		end
		for i = 1, #list do
			local d = UIUtil.make("Frame", { Parent = dots, LayoutOrder = i, Size = UDim2.fromOffset(i == index and 28 or 12, 12), BackgroundColor3 = i == index and Color3.fromRGB(255, 214, 90) or Color3.fromRGB(70, 90, 130), BorderSizePixel = 0 })
			UIUtil.corner(UDim.new(1, 0), d)
		end
	end
	nextB.MouseButton1Click:Connect(function()
		if index >= #list then
			finish()
		else
			index += 1
			show()
		end
	end)
	skip.MouseButton1Click:Connect(finish)
	show()
end

return Tutorial
