--!strict
-- CatOverheads: floating info above every other cat in the arena.
--   * knockback % (the server's "Fluff" attribute): white at 0, heating up to
--     yellow, orange and red as the cat gets closer to flying off the map
--   * ON FIRE ×N with its bounty, plus a fire aura, while on a kill streak
-- Your own % is shown in the HUD instead.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)

local CatOverheads = {}

local player = Players.LocalPlayer

-- 0% white -> 60% yellow -> 120% orange -> 180%+ red.
function CatOverheads.FluffColor(fluff: number): Color3
	local stops = {
		{ 0, Color3.fromRGB(255, 255, 255) },
		{ 60, Color3.fromRGB(255, 224, 90) },
		{ 120, Color3.fromRGB(255, 140, 50) },
		{ 180, Color3.fromRGB(255, 60, 60) },
	}
	for i = 1, #stops - 1 do
		local a, b = stops[i], stops[i + 1]
		if fluff <= b[1] then
			return a[2]:Lerp(b[2], math.clamp((fluff - a[1]) / (b[1] - a[1]), 0, 1))
		end
	end
	return stops[#stops][2]
end

local function attach(model: Model)
	-- Skip your own cat and the humanoid-less menu mascot.
	if model == player.Character or model.Name == player.Name or not model:IsDescendantOf(Workspace) then
		return
	end
	local head = model:WaitForChild("Head", 5) :: BasePart?
	local root = model.PrimaryPart
	if not head or not root or not model:FindFirstChildOfClass("Humanoid") or model:FindFirstChild("PawOverhead") then
		return
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "PawOverhead"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(150, 64)
	gui.StudsOffset = Vector3.new(0, 2.4, 0)
	gui.MaxDistance = 150
	gui.LightInfluence = 0
	gui.Parent = model

	local pct = Instance.new("TextLabel")
	pct.BackgroundTransparency = 1
	pct.AnchorPoint = Vector2.new(0.5, 1)
	pct.Position = UDim2.fromScale(0.5, 1)
	pct.Size = UDim2.new(1, 0, 0, 30)
	pct.Font = Enum.Font.FredokaOne
	pct.TextScaled = true
	pct.TextStrokeTransparency = 0.25
	pct.RichText = true
	pct.Parent = gui

	local owner = Players:GetPlayerFromCharacter(model)

	local streak = Instance.new("TextLabel")
	streak.BackgroundTransparency = 1
	streak.Size = UDim2.new(1, 0, 0, 30)
	streak.Font = Enum.Font.FredokaOne
	streak.TextScaled = true
	streak.RichText = true
	streak.TextColor3 = Color3.fromRGB(255, 150, 50)
	streak.TextStrokeTransparency = 0.25
	streak.Visible = false
	streak.Parent = gui

	local fire: Fire? = nil

	local function refresh()
		local fluff = model:GetAttribute("Fluff")
		local f = typeof(fluff) == "number" and fluff or 0
		pct.Text = tostring(math.floor(f)) .. "%"
		if owner and owner:GetAttribute("VIP") then
			pct.Text = '<font color="#FFD34A">VIP</font> ' .. pct.Text
		end
		pct.TextColor3 = CatOverheads.FluffColor(f)
		pct.Size = UDim2.new(1, 0, 0, 24 + math.clamp(f / 180, 0, 1) * 12)

		local s = model:GetAttribute("Streak")
		local n = typeof(s) == "number" and s or 0
		local cfg = GameConfig.Streaks
		local onFire = n >= cfg.OnFire
		streak.Visible = onFire
		if onFire then
			local bounty = cfg.BountyCoinsPerKill * (n - cfg.OnFire + 1)
			streak.Text = string.format('ON FIRE ×%d  <font color="#FFD34A">%d BOUNTY</font>', n, bounty)
			if not fire then
				local fx = Instance.new("Fire")
				fx.Size = 4
				fx.Heat = 7
				fx.Color = Color3.fromRGB(255, 120, 30)
				fx.SecondaryColor = Color3.fromRGB(255, 220, 80)
				fx.Parent = root
				fire = fx
			end
		elseif fire then
			fire:Destroy()
			fire = nil
		end
	end
	model:GetAttributeChangedSignal("Fluff"):Connect(refresh)
	model:GetAttributeChangedSignal("Streak"):Connect(refresh)
	if owner then
		owner:GetAttributeChangedSignal("VIP"):Connect(refresh)
	end
	refresh()
end

function CatOverheads.Start()
	local function onTagged(inst: Instance)
		if inst:IsA("Model") then
			task.spawn(attach, inst)
		end
	end
	for _, inst in ipairs(CollectionService:GetTagged(CatBuilder.Tag)) do
		onTagged(inst)
	end
	CollectionService:GetInstanceAddedSignal(CatBuilder.Tag):Connect(onTagged)
end

return CatOverheads
