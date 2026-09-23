--!strict
-- GunView: shows a BlasterBuilder gun in a ViewportFrame at a 3/4 angle,
-- muzzle pointing right, framed to fill the view.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlasterBuilder = require(ReplicatedStorage.Shared.Character.BlasterBuilder)

local GunView = {}

local ANGLE = CFrame.Angles(0, math.rad(-24), 0) * CFrame.Angles(0, 0, math.rad(9))
local ASPECT = 1.6

function GunView.Set(vf: ViewportFrame, weaponId: string, skinId: string?)
	for _, child in ipairs(vf:GetChildren()) do
		if child:IsA("Model") or child:IsA("Camera") then
			child:Destroy()
		end
	end
	local model = BlasterBuilder.Build(weaponId, skinId, ANGLE)
	model.Parent = vf
	local cf, size = model:GetBoundingBox()
	local cam = Instance.new("Camera")
	cam.FieldOfView = 28
	local t = math.tan(math.rad(cam.FieldOfView / 2))
	local dist = math.max(size.X * 0.56 / (t * ASPECT), size.Y * 0.62 / t) + size.Z * 0.5
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(0, size.Y * 0.12, dist), cf.Position)
	cam.Parent = vf
	vf.CurrentCamera = cam
end

function GunView.Create(parent: Instance, weaponId: string, skinId: string?, size: UDim2, position: UDim2): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	vf.Size = size
	vf.Position = position
	vf.Ambient = Color3.fromRGB(150, 150, 172)
	vf.LightColor = Color3.fromRGB(255, 250, 240)
	vf.LightDirection = Vector3.new(-0.4, -1, -0.7)
	vf.Parent = parent
	GunView.Set(vf, weaponId, skinId)
	return vf
end

return GunView
