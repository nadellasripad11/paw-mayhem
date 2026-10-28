-- a small stand-in for the roblox api (just what the lobby scripts touch), so
-- they can be run with the luau cli. tools/lobby/test/run.sh.
local Vector3 = {}
Vector3.__index = Vector3
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
Vector3.new = v3
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3.__mul = function(a, b)
	if type(a) == "number" then a, b = b, a end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
Vector3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vector3.__tostring = function(a) return ("%g, %g, %g"):format(a.X, a.Y, a.Z) end
Vector3.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) return v3(t.X / m, t.Y / m, t.Z / m) end
	return rawget(Vector3, k)
end
function Vector3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function Vector3.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end

-- cframe: position + rotation columns (right, up, back)
local CFrame = {}
local function cf(p, r, u, b)
	return setmetatable({ p = p, r = r, u = u, b = b, __cframe = true }, CFrame)
end
CFrame.__index = function(t, k)
	if k == "Position" then return t.p end
	if k == "XVector" or k == "RightVector" then return t.r end
	if k == "YVector" or k == "UpVector" then return t.u end
	if k == "ZVector" then return t.b end
	if k == "LookVector" then return -t.b end
	if k == "Rotation" then return cf(Vector3.zero, t.r, t.u, t.b) end
	return rawget(CFrame, k)
end
local function rot(c, v) return c.r * v.X + c.u * v.Y + c.b * v.Z end
CFrame.identity = cf(Vector3.zero, v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1))
function CFrame.new(x, y, z)
	if type(x) == "table" then return cf(x, v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1)) end
	return cf(v3(x or 0, y or 0, z or 0), v3(1, 0, 0), v3(0, 1, 0), v3(0, 0, 1))
end
function CFrame.fromMatrix(p, r, u, b)
	b = b or r:Cross(u)
	return cf(p, r, u, b)
end
function CFrame.Angles(x, y, z)
	-- only y turns are needed here
	local c, s = math.cos(y), math.sin(y)
	return cf(Vector3.zero, v3(c, 0, -s), v3(0, 1, 0), v3(s, 0, c))
end
function CFrame.lookAt(a, b)
	local f = (b - a)
	f = f / f.Magnitude
	local r = f:Cross(v3(0, 1, 0))
	r = r / r.Magnitude
	local u = r:Cross(f)
	return cf(a, r, u, -f)
end
CFrame.__mul = function(a, b)
	if getmetatable(b) == Vector3 then return a.p + rot(a, b) end
	return cf(a.p + rot(a, b.p), rot(a, b.r), rot(a, b.u), rot(a, b.b))
end
function CFrame.Inverse(c)
	local r, u, b = c.r, c.u, c.b
	local tr, tu, tb = v3(r.X, u.X, b.X), v3(r.Y, u.Y, b.Y), v3(r.Z, u.Z, b.Z)
	local inv = cf(Vector3.zero, tr, tu, tb)
	return cf(-rot(inv, c.p), tr, tu, tb)
end
function CFrame.ToObjectSpace(a, b) return a:Inverse() * b end
function CFrame.VectorToWorldSpace(c, v) return rot(c, v) end
function CFrame.VectorToObjectSpace(c, v) return v3(c.r:Dot(v), c.u:Dot(v), c.b:Dot(v)) end
CFrame.__eq = function(a, b) return a.p == b.p and a.r == b.r and a.u == b.u and a.b == b.b end

local Color3 = {}
Color3.new = function(r, g, b) return { R = r, G = g, B = b } end
Color3.fromRGB = function(r, g, b) return { R = r / 255, G = g / 255, B = b / 255 } end

local function enumOf(names)
	local e = {}
	for _, n in ipairs(names) do
		e[n] = { Name = n }
	end
	return e
end
local Enum = {
	Material = enumOf({ "Slate", "Plaster", "Metal", "Marble", "Fabric", "SmoothPlastic", "Plastic", "Wood", "Neon", "Glass" }),
	Technology = enumOf({ "Legacy", "ShadowMap", "Future" }),
	CollisionFidelity = enumOf({ "Box", "Default" }),
	RenderFidelity = enumOf({ "Precise", "Automatic" }),
	ContentSourceType = enumOf({ "None", "Uri", "Object" }),
	NormalId = enumOf({ "Bottom", "Top" }),
}

-- instances
local Instance = {}
local CLASS_IS = {
	MeshPart = { MeshPart = true, BasePart = true },
	Part = { Part = true, BasePart = true },
	Model = { Model = true },
	Folder = { Folder = true },
}
local Inst = {}
Inst.__index = function(t, k)
	local m = rawget(Inst, k)
	if m then return m end
	local props = rawget(t, "_props")
	if k == "Position" and props.CFrame then return props.CFrame.Position end
	if props[k] ~= nil then return props[k] end
	local c = t:FindFirstChild(k)
	if c then return c end
	if k == "Parent" then return nil end
	error(("%s is not a valid member of %s"):format(tostring(k), rawget(t, "ClassName")), 2)
end
Inst.__newindex = function(t, k, v)
	if k == "Parent" then
		local old = t._props.Parent
		if old then
			for i, c in ipairs(old._children) do
				if c == t then table.remove(old._children, i) break end
			end
		end
		t._props.Parent = v
		if v then table.insert(v._children, t) end
		return
	end
	local ro = rawget(t, "_readonly")
	if ro and ro[k] then error(k .. " is read only", 2) end
	t._props[k] = v
end
local DEFAULTS = {
	MeshPart = { TextureID = "", Material = Enum.Material.Plastic, Color = Color3.new(0.6, 0.6, 0.6), CastShadow = false, Anchored = false, CanCollide = true, CanQuery = true, CanTouch = true, Size = v3(1, 1, 1), CFrame = CFrame.identity, CollisionFidelity = Enum.CollisionFidelity.Default, RenderFidelity = Enum.RenderFidelity.Automatic },
	MaterialVariant = { StudsPerTile = 10, ColorMap = "", NormalMap = "", RoughnessMap = "", MetalnessMap = "" },
	SurfaceAppearance = { ColorMap = "", NormalMap = "", RoughnessMap = "", MetalnessMap = "" },
}
function Instance.new(class, parent)
	local t = setmetatable({ ClassName = class, _children = {}, _props = { Name = class }, _attrs = {} }, Inst)
	for k, v in pairs(DEFAULTS[class] or {}) do
		t._props[k] = v
	end
	if parent then t.Parent = parent end
	return t
end
function Inst:IsA(c)
	local is = CLASS_IS[self.ClassName]
	return self.ClassName == c or (is and is[c]) or c == "Instance"
end
function Inst:GetChildren()
	return table.clone(self._children)
end
function Inst:GetDescendants()
	local out = {}
	local function walk(n)
		for _, c in ipairs(n._children) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end
function Inst:FindFirstChild(name, recursive)
	for _, c in ipairs(self._children) do
		if c._props.Name == name then return c end
	end
	if recursive then
		for _, c in ipairs(self._children) do
			local f = c:FindFirstChild(name, true)
			if f then return f end
		end
	end
	return nil
end
function Inst:FindFirstChildOfClass(cl)
	for _, c in ipairs(self._children) do
		if c.ClassName == cl then return c end
	end
	return nil
end
function Inst:FindFirstAncestorOfClass(cl)
	local p = self._props.Parent
	while p do
		if p.ClassName == cl then return p end
		p = p._props.Parent
	end
	return nil
end
function Inst:IsDescendantOf(a)
	local p = self._props.Parent
	while p do
		if p == a then return true end
		p = p._props.Parent
	end
	return false
end
function Inst:Destroy()
	self.Parent = nil
	self._destroyed = true
end
function Inst:Clone()
	local t = Instance.new(self.ClassName)
	for k, v in pairs(self._props) do
		if k ~= "Parent" then t._props[k] = v end
	end
	for k, v in pairs(self._attrs) do
		t._attrs[k] = v
	end
	for _, c in ipairs(self._children) do
		c:Clone().Parent = t
	end
	return t
end
function Inst:SetAttribute(k, v) self._attrs[k] = v end
function Inst:GetAttribute(k) return self._attrs[k] end
function Inst:GetPivot() return self._props.WorldPivot or CFrame.identity end
function Inst:GetService(name)
	local s = self:FindFirstChild(name)
	if not s then
		s = Instance.new(name)
		s.Name = name
		s.Parent = self
	end
	return s
end

local game = Instance.new("DataModel")
local workspace = game:GetService("Workspace")
local lighting = game:GetService("Lighting")
lighting.Technology = Enum.Technology.ShadowMap
local runService = game:GetService("RunService")
runService.IsRunning = function() return false end

local function typeof(v)
	if type(v) == "table" then
		if getmetatable(v) == Vector3 then return "Vector3" end
		if getmetatable(v) == CFrame then return "CFrame" end
		if getmetatable(v) == Inst then return "Instance" end
	end
	return type(v)
end

return { Vector3 = Vector3, CFrame = CFrame, Color3 = Color3, Enum = Enum, Instance = Instance, game = game, workspace = workspace, typeof = typeof }
