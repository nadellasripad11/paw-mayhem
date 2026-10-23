--!strict
-- Orbit: look all the way round a 3D preview (a blaster, your cat). Drag on
-- \`input\` to swing the camera of \`vf\` round the model (left / right and up
-- / down), and the mouse wheel zooms. Works with touch too. A preview that
-- swaps its model (and camera) is picked up on the next drag.

local UserInputService = game:GetService("UserInputService")

local Orbit = {}

function Orbit.Enable(input: GuiObject, vf: ViewportFrame)
	local cam: Camera? = nil
	local center = Vector3.zero
	local yaw, pitch, dist, baseDist = 0, 0, 10, 10
	local dragging: InputObject? = nil
	local last = Vector2.zero

	local function sync()
		cam = vf.CurrentCamera
		local model = vf:FindFirstChildWhichIsA("Model", true)
		if not cam or not model then
			return
		end
		local cf = model:GetBoundingBox()
		center = cf.Position
		local off = (cam :: Camera).CFrame.Position - center
		dist = math.max(off.Magnitude, 0.1)
		baseDist = dist
		yaw = math.atan2(off.X, off.Z)
		pitch = math.asin(math.clamp(off.Y / dist, -1, 1))
	end

	local function apply()
		if not cam or cam ~= vf.CurrentCamera then
			sync()
		end
		local c = cam
		if not c then
			return
		end
		local dir = Vector3.new(math.sin(yaw) * math.cos(pitch), math.sin(pitch), math.cos(yaw) * math.cos(pitch))
		c.CFrame = CFrame.lookAt(center + dir * dist, center)
	end

	input.InputBegan:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseButton1 or io.UserInputType == Enum.UserInputType.Touch then
			if not cam or cam ~= vf.CurrentCamera then
				sync()
			end
			dragging = io
			last = Vector2.new(io.Position.X, io.Position.Y)
		end
	end)
	input.InputChanged:Connect(function(io)
		if io.UserInputType == Enum.UserInputType.MouseWheel then
			if not cam or cam ~= vf.CurrentCamera then
				sync()
			end
			dist = math.clamp(dist * (1 - io.Position.Z * 0.1), baseDist * 0.5, baseDist * 1.8)
			apply()
		end
	end)
	UserInputService.InputChanged:Connect(function(io)
		local d = dragging
		if not d then
			return
		end
		if io == d or (io.UserInputType == Enum.UserInputType.MouseMovement and d.UserInputType == Enum.UserInputType.MouseButton1) then
			local p = Vector2.new(io.Position.X, io.Position.Y)
			local delta = p - last
			last = p
			yaw -= delta.X * 0.012
			pitch = math.clamp(pitch + delta.Y * 0.01, -1.35, 1.35)
			apply()
		end
	end)
	UserInputService.InputEnded:Connect(function(io)
		if io == dragging or (dragging and io.UserInputType == Enum.UserInputType.MouseButton1) then
			dragging = nil
		end
	end)
end

return Orbit
