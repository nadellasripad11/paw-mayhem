--!strict
-- UIJuice: game-feel for every button in the game, automatically. Buttons
-- grow a little on hover, squish when pressed and spring back on release.
-- Buttons that already scale themselves (they own a UIScale) or that cover
-- big areas (full-screen click-catchers) are left alone.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local UIJuice = {}

local HOVER, PRESS = 1.05, 0.93
local SPRING = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function juicy(b: GuiButton): boolean
	local size = b.AbsoluteSize
	return size.X > 0 and size.X < 460 and size.Y < 200
end

local function hook(inst: Instance)
	if not inst:IsA("GuiButton") or inst:GetAttribute("NoJuice") then
		return
	end
	local b = inst :: GuiButton
	if b:FindFirstChildOfClass("UIScale") then
		return
	end
	local scale = Instance.new("UIScale")
	scale.Name = "PawJuice"
	scale.Parent = b
	local hovering = false
	local function to(v: number, info: TweenInfo)
		if juicy(b) then
			TweenService:Create(scale, info, { Scale = v }):Play()
		end
	end
	b.MouseEnter:Connect(function()
		hovering = true
		to(HOVER, SPRING)
	end)
	b.MouseLeave:Connect(function()
		hovering = false
		to(1, SPRING)
	end)
	b.MouseButton1Down:Connect(function()
		to(PRESS, QUICK)
	end)
	b.MouseButton1Up:Connect(function()
		to(hovering and HOVER or 1, SPRING)
	end)
end

function UIJuice.Start()
	local gui = Players.LocalPlayer:WaitForChild("PlayerGui")
	for _, d in ipairs(gui:GetDescendants()) do
		hook(d)
	end
	gui.DescendantAdded:Connect(function(d)
		-- Let the builder finish (it may add its own UIScale) before deciding.
		task.defer(hook, d)
	end)
end

-- Slide + fade a freshly opened screen into place.
function UIJuice.Enter(frame: GuiObject)
	local target = UDim2.new() -- screens sit at the content origin
	frame.Position = target + UDim2.fromOffset(0, 28)
	TweenService:Create(frame, TweenInfo.new(0.32, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = target }):Play()
end

return UIJuice
