--!strict
-- CatView: renders the real in-game cat (CatBuilder) inside a ViewportFrame,
-- framed full-body, as a head-and-shoulders portrait, or from behind (for
-- back accessories).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CatBuilder = require(ReplicatedStorage.Shared.Character.CatBuilder)

local CatView = {}

local FRAMING = {
	Full = { target = Vector3.new(0, 0.75, 0), span = 5.0, yaw = -22 },
	Bust = { target = Vector3.new(0, 1.5, 0), span = 3.5, yaw = -18 },
	Back = { target = Vector3.new(0, 0.6, 0), span = 4.4, yaw = 155 },
}
CatView.Framing = FRAMING

function CatView.Create(parent: Instance, size: UDim2, position: UDim2): ViewportFrame
	local vf = Instance.new("ViewportFrame")
	vf.BackgroundTransparency = 1
	vf.Size = size
	vf.Position = position
	vf.Ambient = Color3.fromRGB(168, 166, 182)
	vf.LightColor = Color3.fromRGB(255, 248, 238)
	vf.LightDirection = Vector3.new(0.35, -0.8, 0.6)
	vf.Parent = parent
	return vf
end

-- Joints only move parts inside a WorldModel, so the cat lives in one (lets
-- CatAnimator pose previews too).
local function world(vf: ViewportFrame): WorldModel
	local w = vf:FindFirstChildOfClass("WorldModel")
	if not w then
		w = Instance.new("WorldModel")
		w.Parent = vf
	end
	return w :: WorldModel
end

function CatView.SetYaw(vf: ViewportFrame, yaw: number)
	local model = world(vf):FindFirstChild("CatModel") :: Model?
	if model then
		model:PivotTo(CFrame.Angles(0, yaw, 0))
	end
end

-- `custom` is a Loadout.Cat-style table: { Fur, Outfit, Hat, Accessory }.
function CatView.Set(vf: ViewportFrame, custom: any, framing: string)
	local w = world(vf)
	w:ClearAllChildren()
	for _, child in ipairs(vf:GetChildren()) do
		if child:IsA("Camera") then
			child:Destroy()
		end
	end
	local f = FRAMING[framing] or FRAMING.Full
	local model = CatBuilder.Build(custom)
	model.Name = "CatModel"
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		hum:Destroy()
	end
	model:PivotTo(CFrame.Angles(0, math.rad(f.yaw), 0))
	model.Parent = w

	local cam = Instance.new("Camera")
	cam.FieldOfView = 30
	local dist = (f.span / 2) / math.tan(math.rad(15))
	-- The cat faces -Z, so the camera sits on that side looking back at it.
	cam.CFrame = CFrame.lookAt(f.target + Vector3.new(0, 0.2, -dist), f.target)
	cam.Parent = vf
	vf.CurrentCamera = cam
end

return CatView
