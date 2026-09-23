--!strict
-- ShopArt: real 3D renders for store items, drawn in ViewportFrames.
--   * blasters / skins  -> the actual in-game blaster (GunView)
--   * cat cosmetics     -> your cat wearing the item (CatView)
--   * emotes            -> your cat struck in that emote's pose
--   * Robux items       -> small 3D props (gem piles, coin stacks, gift box...)

local CatView = require(script.Parent.CatView)
local GunView = require(script.Parent.GunView)

local ShopArt = {}

local GOLD = Color3.fromRGB(255, 202, 64)
local GOLD_DARK = Color3.fromRGB(214, 150, 30)
local GEM = Color3.fromRGB(196, 92, 255)
local GEM_LIGHT = Color3.fromRGB(236, 170, 255)

local function viewport(parent: Instance): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	vf.Size = UDim2.fromScale(1, 1)
	vf.Ambient = Color3.fromRGB(170, 168, 186)
	vf.LightColor = Color3.fromRGB(255, 248, 238)
	vf.LightDirection = Vector3.new(0.4, -0.8, 0.5)
	vf.Parent = parent
	return vf
end

-- Point a camera at everything in `model`, from the front-ish, filling the view.
local function frame(vf: ViewportFrame, model: Model, yaw: number?, pitch: number?, fill: number?)
	local cf, size = model:GetBoundingBox()
	local radius = size.Magnitude / 2
	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = radius / math.tan(math.rad(15)) * (fill or 1)
	local dir = (CFrame.Angles(0, math.rad(yaw or 0), 0) * CFrame.Angles(math.rad(pitch or -12), 0, 0)).LookVector
	cam.CFrame = CFrame.lookAt(cf.Position - dir * dist, cf.Position)
	cam.Parent = vf
	vf.CurrentCamera = cam
end

local function p(model: Model, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	if shape then
		part.Shape = shape
	end
	part.Parent = model
	return part
end

local function coin(model: Model, cf: CFrame)
	-- Cylinder axis is X; tip it so the flat face points along cf's Y.
	local base = cf * CFrame.Angles(0, 0, math.rad(90))
	p(model, Vector3.new(0.22, 1.2, 1.2), base, GOLD_DARK, Enum.Material.Metal, Enum.PartType.Cylinder)
	p(model, Vector3.new(0.24, 0.86, 0.86), base, GOLD, Enum.Material.Metal, Enum.PartType.Cylinder)
end

local function gem(model: Model, pos: Vector3, s: number, spin: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, spin, 0) * CFrame.Angles(math.rad(45), 0, math.rad(35))
	local g = p(model, Vector3.one * s, cf, GEM)
	g.Reflectance = 0.15
	local shine = p(model, Vector3.one * s * 0.35, cf * CFrame.new(-s * 0.2, s * 0.25, -s * 0.25), GEM_LIGHT, Enum.Material.Neon)
	shine.Transparency = 0.2
end

-- ── public ───────────────────────────────────────────────────────────────────
function ShopArt.Gun(parent: Instance, weaponId: string, skinId: string?): ViewportFrame
	return GunView.Create(parent, weaponId, skinId, UDim2.fromScale(1, 1), UDim2.new())
end

-- Static emote poses for the preview (joint name -> extra rotation).
local EMOTE_POSES: { [string]: { [string]: CFrame } } = {
	Wave = { PawShoulderR = CFrame.Angles(0, 0, math.rad(150)) },
	Celebrate = { PawShoulderL = CFrame.Angles(0, 0, math.rad(-150)), PawShoulderR = CFrame.Angles(0, 0, math.rad(150)) },
	Dance = { PawShoulderL = CFrame.Angles(0, 0, math.rad(-140)), PawShoulderR = CFrame.Angles(0, 0, math.rad(40)), PawNeck = CFrame.Angles(0, 0, math.rad(12)) },
	Flex = { PawShoulderL = CFrame.Angles(0, 0, math.rad(-95)) * CFrame.Angles(math.rad(-40), 0, 0), PawShoulderR = CFrame.Angles(0, 0, math.rad(95)) * CFrame.Angles(math.rad(-40), 0, 0) },
	Laugh = { PawNeck = CFrame.Angles(math.rad(-18), 0, 0), PawShoulderL = CFrame.Angles(math.rad(-50), 0, 0), PawShoulderR = CFrame.Angles(math.rad(-50), 0, 0) },
	Sit = { PawHipL = CFrame.Angles(math.rad(-80), 0, 0), PawHipR = CFrame.Angles(math.rad(-80), 0, 0) },
	Sleep = { PawNeck = CFrame.Angles(0, 0, math.rad(22)) },
	Happy = { PawNeck = CFrame.Angles(0, 0, math.rad(-10)), PawShoulderL = CFrame.Angles(0, 0, math.rad(-35)), PawShoulderR = CFrame.Angles(0, 0, math.rad(35)) },
	Spin = {},
	Fall = {},
}

function ShopArt.Cat(parent: Instance, custom: any, framing: string, emote: string?): ViewportFrame
	local vf = CatView.Create(parent, UDim2.fromScale(1, 1), UDim2.new())
	CatView.Set(vf, custom, framing)
	if emote then
		local w = vf:FindFirstChildOfClass("WorldModel")
		local model = w and w:FindFirstChild("CatModel") :: Model?
		if model then
			for joint, rot in pairs(EMOTE_POSES[emote] or {}) do
				local m = model:FindFirstChild(joint, true) :: Motor6D?
				local base = m and m:GetAttribute("BaseC0")
				if m and typeof(base) == "CFrame" then
					m.C0 = base * rot
				end
			end
			if emote == "Sleep" or emote == "Happy" or emote == "Laugh" then
				-- Eyes shut (the same parts the blink toggles).
				for _, d in ipairs(model:GetDescendants()) do
					if d:IsA("BasePart") then
						if d.Name == "ClosedEye" then
							d.Transparency = 0
						elseif d.Name == "EyeWhite" or d.Name == "Iris" or d.Name == "IrisGlow" or d.Name == "Pupil" or d.Name == "Shine" then
							d.Transparency = 1
						end
					end
				end
			end
			if emote == "Spin" then
				model:PivotTo(CFrame.Angles(0, math.rad(95), 0))
			elseif emote == "Fall" then
				model:PivotTo(CFrame.Angles(0, math.rad(-20), math.rad(70)))
			end
		end
	end
	return vf
end

-- 3D prop for a Robux item: "Gems" (with a count 1-4), "Coins", "CoinRain",
-- "Gift", "Rainbow", "VIP".
function ShopArt.Prop(parent: Instance, kind: string, tier: number?): ViewportFrame
	if kind == "Emote" then
		return ShopArt.Cat(parent, { Fur = "White", Outfit = "Hoodie", Hat = "None", Accessory = "None" }, "Full", "Dance")
	elseif kind == "VIP" then
		return ShopArt.Cat(parent, { Fur = "RoyalGold", Outfit = "Royal", Hat = "DiamondCrown", Accessory = "None" }, "Bust")
	end
	local vf = viewport(parent)
	local w = Instance.new("WorldModel")
	w.Parent = vf
	local model = Instance.new("Model")
	model.Parent = w
	local rng = Random.new(#kind * 31 + (tier or 0))

	if kind == "Gems" then
		local count = ({ 3, 6, 10, 16 })[tier or 1] or 3
		for i = 1, count do
			local ring = math.floor((i - 1) / 5)
			local a = i * 2.39
			local r = 0.5 + ring * 0.75
			gem(model, Vector3.new(math.cos(a) * r, ring * -0.25 + rng:NextNumber(0, 0.3), math.sin(a) * r * 0.6), 0.9 - ring * 0.12, rng:NextNumber(0, 6))
		end
		if count >= 10 then
			gem(model, Vector3.new(0, 0.9, 0), 1.3, 0.4)
		end
		frame(vf, model, 0, -18, 0.95)
	elseif kind == "Coins" or kind == "CoinRain" then
		if kind == "Coins" then
			for s = 0, 1 do
				for k = 0, 5 - s * 2 do
					coin(model, CFrame.new(s * 1.3 - 0.65, k * 0.24, s * 0.4) * CFrame.Angles(0, rng:NextNumber(0, 1), 0))
				end
			end
			coin(model, CFrame.new(0.2, 0.9, -0.9) * CFrame.Angles(math.rad(70), 0, math.rad(15)))
		else
			for _ = 1, 14 do
				coin(model, CFrame.new(rng:NextNumber(-2, 2), rng:NextNumber(-1.6, 1.8), rng:NextNumber(-0.8, 0.8)) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), rng:NextNumber(0, 6)))
			end
		end
		frame(vf, model, 12, -16, 0.9)
	elseif kind == "Gift" then
		p(model, Vector3.new(1.8, 1.4, 1.8), CFrame.new(0, 0, 0), Color3.fromRGB(80, 190, 255))
		p(model, Vector3.new(1.95, 0.36, 1.95), CFrame.new(0, 0.82, 0), Color3.fromRGB(60, 160, 235))
		p(model, Vector3.new(0.34, 1.82, 1.99), CFrame.new(0, 0.2, 0), Color3.fromRGB(255, 90, 140))
		p(model, Vector3.new(1.99, 1.82, 0.34), CFrame.new(0, 0.2, 0), Color3.fromRGB(255, 90, 140))
		for i = -1, 1, 2 do
			p(model, Vector3.new(0.8, 0.5, 0.5), CFrame.new(0.38 * i, 1.22, 0) * CFrame.Angles(0, 0, math.rad(-25 * i)), Color3.fromRGB(255, 110, 160), nil, Enum.PartType.Ball)
		end
		coin(model, CFrame.new(1.35, -0.45, -0.5) * CFrame.Angles(math.rad(75), 0, math.rad(20)))
		gem(model, Vector3.new(-1.3, -0.4, -0.5), 0.6, 0.5)
		frame(vf, model, -20, -18, 0.95)
	elseif kind == "Rainbow" then
		local colors = { Color3.fromRGB(255, 80, 90), Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 230, 80), Color3.fromRGB(90, 220, 120), Color3.fromRGB(80, 170, 255), Color3.fromRGB(180, 110, 255) }
		for b, c in ipairs(colors) do
			local r = 2.6 - b * 0.28
			for k = 0, 14 do
				local a = math.pi * k / 14
				p(model, Vector3.one * 0.36, CFrame.new(math.cos(a) * r, math.sin(a) * r, 0), c, Enum.Material.Neon, Enum.PartType.Ball)
			end
		end
		frame(vf, model, 0, -5, 0.8)
	else
		frame(vf, model)
	end
	return vf
end

return ShopArt
