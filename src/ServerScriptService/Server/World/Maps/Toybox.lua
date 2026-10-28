--!strict
-- map 3/3: toybox — bright candy-colored block islands, balloon "trees", a
-- giant stacked-block tower with a spinning pinwheel instead of a windmill,
-- and colorful ribbon-streamer falls. same tested island layout as the other
-- two maps (arenakit.standardlayout); completely different theme.

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ArenaKit = require(script.Parent.Parent.ArenaKit)
local MeshLib = require(ReplicatedStorage.Shared.MeshLib)

local Toybox = { Id = "Toybox", Name = "Toybox" }

local PALETTE: ArenaKit.Palette = {
	Top = Color3.fromRGB(120, 210, 235), TopDark = Color3.fromRGB(90, 180, 210), -- candy blue platform
	Stone = Color3.fromRGB(255, 205, 90), StoneDark = Color3.fromRGB(230, 170, 60), -- toy-block yellow
	Wood = Color3.fromRGB(230, 90, 90), WoodDark = Color3.fromRGB(190, 60, 60), -- toy red
}
local BALLOON_COLORS = {
	Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(255, 210, 90), Color3.fromRGB(170, 130, 255), Color3.fromRGB(130, 220, 140),
}
local BLOCK_COLORS = {
	Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 200, 255),
	Color3.fromRGB(255, 210, 90), Color3.fromRGB(170, 130, 255),
}
-- islands with soft rounded toy-block cliffs (once the models are imported).
local TOY_ISLE: ArenaKit.IslandStyle = { softBlocks = true }

-- swap a block for a soft, rounded toy block (meshlib); the block itself stays
-- as invisible collision. no-op until the models are imported.
local function soften(p: BasePart, mesh: string?)
	if MeshLib.Fill(mesh or "U_SoftBlock", p.CFrame, p.Size, p.Color, p.Material, p.Parent) then
		MeshLib.Hide(p)
	end
end

-- a big toy balloon on a string, in place of a tree.
local function makeBalloon(pos: Vector3, parent: Instance)
	local color = BALLOON_COLORS[math.random(1, #BALLOON_COLORS)]
	local h = 4 + math.random() * 2
	ArenaKit.NewPart("String", Vector3.new(0.15, h, 0.15), CFrame.new(pos + Vector3.new(0, h / 2, 0)), Color3.fromRGB(230, 230, 230), Enum.Material.SmoothPlastic, parent)
	if MeshLib.Place("Balloon", CFrame.new(pos + Vector3.new(0, h + 1.6 - 1.8, 0)), 1, color, Enum.Material.SmoothPlastic, parent) then
		return
	end
	local balloon = ArenaKit.NewPart("Balloon", Vector3.new(3, 3.6, 3), CFrame.new(pos + Vector3.new(0, h + 1.6, 0)), color, Enum.Material.SmoothPlastic, parent)
	balloon.Shape = Enum.PartType.Ball
	balloon.CanCollide = false
end

-- a small colorful toy block, in place of a flower.
local function makeBlock(pos: Vector3, parent: Instance)
	local color = BLOCK_COLORS[math.random(1, #BLOCK_COLORS)]
	soften(ArenaKit.NewPart("ToyBlock", Vector3.new(0.9, 0.9, 0.9), CFrame.new(pos + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, math.rad(math.random(0, 45)), 0), color, Enum.Material.SmoothPlastic, parent))
end

local function scatterDecor(center: Vector3, radius: number, parent: Instance, balloons: number, blocks: number)
	for _ = 1, balloons do
		local a = math.random() * math.pi * 2
		local r = radius * (0.3 + math.random() * 0.55)
		makeBalloon(center + Vector3.new(math.cos(a) * r, 1.6, math.sin(a) * r), parent)
	end
	for _ = 1, blocks do
		local a = math.random() * math.pi * 2
		local r = radius * (0.2 + math.random() * 0.7)
		makeBlock(center + Vector3.new(math.cos(a) * r, 1.6, math.sin(a) * r), parent)
	end
end

local function makeCrate(pos: Vector3, parent: Instance)
	local color = BLOCK_COLORS[math.random(1, #BLOCK_COLORS)]
	local box = ArenaKit.NewPart("ToyCrate", Vector3.new(4, 4, 4), CFrame.new(pos + Vector3.new(0, 3.6, 0)), color, Enum.Material.SmoothPlastic, parent)
	box.CanCollide = true
	soften(box)
	soften(ArenaKit.NewPart("Trim", Vector3.new(4.1, 0.4, 4.1), CFrame.new(pos + Vector3.new(0, 5.4, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, parent))
end

local function makeToyHouse(pos: Vector3, parent: Instance, scale: number?)
	local s = scale or 1
	local folder = Instance.new("Folder")
	folder.Name = "ToyHouse"
	folder.Parent = parent
	local colors = BLOCK_COLORS
	local body = ArenaKit.NewPart("HouseBlock", Vector3.new(7 * s, 5 * s, 6 * s), CFrame.new(pos + Vector3.new(0, 2.5 * s, 0)), colors[math.random(1, #colors)], Enum.Material.SmoothPlastic, folder)
	body.CanCollide = true
	soften(body)
	local roof = Instance.new("WedgePart")
	roof.Name = "HouseRoof"
	roof.Size = Vector3.new(9 * s, 3.5 * s, 7 * s)
	roof.CFrame = CFrame.new(pos + Vector3.new(0, 6.75 * s, 0)) * CFrame.Angles(0, math.rad(90), 0)
	roof.Color = Color3.fromRGB(255, 255, 255)
	roof.Material = Enum.Material.SmoothPlastic
	roof.Anchored = true
	roof.Parent = folder
	local door = ArenaKit.NewPart("Door", Vector3.new(1.3 * s, 2.3 * s, 0.2 * s), CFrame.new(pos + Vector3.new(0, 1.3 * s, -3.1 * s)), Color3.fromRGB(90, 120, 180), Enum.Material.Neon, folder)
	door.CanCollide = false
	for _, x in ipairs({ -2 * s, 2 * s }) do
		local window = ArenaKit.NewPart("Window", Vector3.new(1.5 * s, 1.3 * s, 0.2 * s), CFrame.new(pos + Vector3.new(x, 3.2 * s, -3.11 * s)), Color3.fromRGB(255, 238, 133), Enum.Material.Neon, folder)
		window.CanCollide = false
	end
	local flag = ArenaKit.NewPart("FlagPole", Vector3.new(0.25 * s, 3.5 * s, 0.25 * s), CFrame.new(pos + Vector3.new(2.5 * s, 8.1 * s, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, folder)
	flag.CanCollide = false
	ArenaKit.NewPart("Flag", Vector3.new(1.6 * s, 0.8 * s, 0.2 * s), CFrame.new(pos + Vector3.new(3.2 * s, 9.2 * s, 0)), colors[math.random(1, #colors)], Enum.Material.Neon, folder).CanCollide = false
end

local function makePlatform(pos: Vector3, size: Vector3, parent: Instance)
	local top = ArenaKit.NewPart("Platform", size, CFrame.new(pos), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, parent)
	top.CanCollide = true
	soften(top)
	for _, ox in ipairs({ -1, 1 }) do
		for _, oz in ipairs({ -1, 1 }) do
			ArenaKit.NewPart("Leg", Vector3.new(0.8, pos.Y + 1.6, 0.8), CFrame.new(pos.X + ox * (size.X / 2 - 1), pos.Y / 2, pos.Z + oz * (size.Z / 2 - 1)), PALETTE.Wood, Enum.Material.SmoothPlastic, parent)
		end
	end
end

-- central landmark: a stacked-block tower with a spinning colorful pinwheel
-- on top, standing in for the windmill.
local function makeBlockTower(pos: Vector3, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "BlockTower"
	folder.Parent = parent
	local stackColors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 210, 90), Color3.fromRGB(120, 200, 255), Color3.fromRGB(170, 130, 255) }
	for i = 0, 3 do
		local size = 6 - i * 0.6
		local block = ArenaKit.NewPart("Block" .. i, Vector3.new(size, 4, size), CFrame.new(pos + Vector3.new(0, 2 + i * 4, 0)), stackColors[i + 1], Enum.Material.SmoothPlastic, folder)
		block.CanCollide = true
		soften(block)
	end

	local hub = ArenaKit.NewPart("Hub", Vector3.new(0.8, 0.8, 0.8), CFrame.new(pos + Vector3.new(0, 18, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, folder)
	hub.Shape = Enum.PartType.Ball
	local blades = Instance.new("Model")
	blades.Name = "Pinwheel"
	blades.Parent = folder
	hub.Parent = blades
	local wheelColors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 210, 90), Color3.fromRGB(130, 220, 140) }
	for i = 0, 3 do
		local ang = math.rad(i * 90)
		local blade = ArenaKit.NewPart("Vane", Vector3.new(0.2, 4, 2.6), CFrame.new(pos + Vector3.new(0, 18, 0)) * CFrame.Angles(0, 0, ang) * CFrame.new(0, 2, 0), wheelColors[i + 1], Enum.Material.SmoothPlastic, blades)
		blade.CanCollide = false
	end
	blades.PrimaryPart = hub

	local pivot = CFrame.new(pos + Vector3.new(0, 18, 0))
	task.spawn(function()
		local a = 0
		while blades.Parent do
			a += 3
			pcall(function()
				blades:PivotTo(pivot * CFrame.Angles(0, 0, math.rad(a)))
			end)
			task.wait()
		end
	end)
end

-- colorful ribbon-streamer cascade in place of a waterfall.
local function makeStreamerFall(top: Vector3, height: number, parent: Instance)
	local folder = Instance.new("Folder")
	folder.Name = "Streamers"
	folder.Parent = parent
	for i, color in ipairs(BALLOON_COLORS) do
		local x = (i - 3) * 1.6
		local ribbon = ArenaKit.NewPart("Ribbon", Vector3.new(1.2, height, 0.3), CFrame.new(top + Vector3.new(x, -height / 2, 0)), color, Enum.Material.SmoothPlastic, folder)
		ribbon.Transparency = 0.15
		ribbon.CanCollide = false
	end
end

local function makeToyRail(origin: Vector3, length: number, parent: Instance)
	for _, x in ipairs({ -length / 2, length / 2 }) do
		local post = ArenaKit.NewPart("ToyRailPost", Vector3.new(0.6, 3.2, 0.6), CFrame.new(origin + Vector3.new(x, 1.6, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, parent)
		post.CanCollide = true
		soften(post)
	end
	local rail = ArenaKit.NewPart("ToyRail", Vector3.new(length, 0.5, 0.5), CFrame.new(origin + Vector3.new(0, 2.8, 0)), Color3.fromRGB(255, 120, 150), Enum.Material.SmoothPlastic, parent)
	rail.CanCollide = true
	soften(rail)
end

local function makeToySlide(pos: Vector3, parent: Instance, color: Color3)
	local ramp = Instance.new("WedgePart")
	ramp.Name = "ToySlide"
	ramp.Size = Vector3.new(8, 5, 12)
	ramp.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, math.rad(90), 0)
	ramp.Color = color
	ramp.Material = Enum.Material.SmoothPlastic
	ramp.Anchored = true
	ramp.CanCollide = true
	ramp.Parent = parent
	local strip = ArenaKit.NewPart("SlideStrip", Vector3.new(2.2, 0.18, 8), CFrame.new(pos + Vector3.new(0, 4.7, -1)), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, parent)
	strip.CanCollide = false
end

local function makeToyDice(pos: Vector3, parent: Instance)
	local dice = ArenaKit.NewPart("GiantDice", Vector3.new(5.2, 5.2, 5.2), CFrame.new(pos + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, math.rad(18), 0), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, parent)
	dice.CanCollide = true
	soften(dice, "U_Dice")
	for _, side in ipairs({ Vector3.new(0, 0, -2.66), Vector3.new(0, 0, 2.66), Vector3.new(-2.66, 0, 0) }) do
		local pip = ArenaKit.NewPart("DicePip", Vector3.new(0.65, 0.65, 0.12), CFrame.new(pos + Vector3.new(0, 2.6, 0) + side), Color3.fromRGB(90, 130, 220), Enum.Material.Neon, parent)
		pip.Shape = Enum.PartType.Ball
		pip.CanCollide = false
	end
end

local function makeToyArch(pos: Vector3, parent: Instance)
	local colors = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 210, 90) }
	for i, x in ipairs({ -4, 0, 4 }) do
		local pillar = ArenaKit.NewPart("ToyArchBlock", Vector3.new(2.2, 7 + (i % 2) * 2, 2.2), CFrame.new(pos + Vector3.new(x, 3.5 + (i % 2), 0)), colors[i], Enum.Material.SmoothPlastic, parent)
		pillar.CanCollide = true
		soften(pillar)
	end
	local top = ArenaKit.NewPart("ToyArchTop", Vector3.new(10, 1.8, 2.4), CFrame.new(pos + Vector3.new(0, 8.4, 0)), Color3.fromRGB(170, 130, 255), Enum.Material.SmoothPlastic, parent)
	top.CanCollide = true
	soften(top)
end

local function makeToyTeamMarker(pos: Vector3, teamId: string, parent: Instance)
	local color = teamId == "Red" and Color3.fromRGB(255, 100, 150) or Color3.fromRGB(86, 180, 255)
	local pole = ArenaKit.NewPart("ToyTeamPole", Vector3.new(0.45, 7, 0.45), CFrame.new(pos + Vector3.new(0, 3.5, 0)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, parent)
	pole.CanCollide = false
	local flag = ArenaKit.NewPart("ToyTeamFlag", Vector3.new(4.2, 2, 0.18), CFrame.new(pos + Vector3.new(2.1, 5.8, 0)), color, Enum.Material.Neon, parent)
	flag.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10
	light.Brightness = 0.7
	light.Parent = flag
end

-- ── the toy world dressing ───────────────────────────────────────────────────
local TOY = { Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 200, 70), Color3.fromRGB(110, 200, 255), Color3.fromRGB(150, 230, 120), Color3.fromRGB(190, 140, 255), Color3.fromRGB(255, 150, 80) }
local toyRng = Random.new(20261023)
local function toyColor(): Color3
	return TOY[toyRng:NextInteger(1, #TOY)]
end
local function toyDeco(p: BasePart): BasePart
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end
local function toyBall(d: number, pos: Vector3, color: Color3, parent: Instance): BasePart
	local p = toyDeco(ArenaKit.NewPart("Bloom", Vector3.one * d, CFrame.new(pos), color, Enum.Material.SmoothPlastic, parent)) :: Part
	p.Shape = Enum.PartType.Ball
	return p
end

-- a lollipop tree: a white stick and a big swirl disc.
local function lollipop(pos: Vector3, s: number, parent: Instance)
	ArenaKit.NewPart("Trunk", Vector3.new(0.6 * s, 7 * s, 0.6 * s), CFrame.new(pos + Vector3.new(0, 3.5 * s, 0)), Color3.fromRGB(250, 248, 244), Enum.Material.SmoothPlastic, parent)
	local top = pos + Vector3.new(0, 8.6 * s, 0)
	local face = CFrame.new(top) * CFrame.Angles(0, toyRng:NextNumber(0, 6.28), 0)
	local c1, c2 = toyColor(), Color3.new(1, 1, 1)
	if MeshLib.Has("LollipopDisc") then
		local o = face * CFrame.Angles(0, math.pi / 2, 0)
		MeshLib.Place("LollipopDisc", o, s, c1, Enum.Material.SmoothPlastic, parent)
		MeshLib.Place("LollipopStripe", o, s, c2, Enum.Material.SmoothPlastic, parent)
		return
	end
	for i, d in ipairs({ 5.2, 4.1, 3, 1.9, 0.9 }) do
		local disc = toyDeco(ArenaKit.NewPart("Bloom", Vector3.new(0.6 + i * 0.02, d * s, d * s), face, i % 2 == 1 and c1 or c2, Enum.Material.SmoothPlastic, parent)) :: Part
		disc.Shape = Enum.PartType.Cylinder
	end
end

-- an abc block stack (solid cover), letters on the sides.
local function abcBlocks(pos: Vector3, parent: Instance)
	local letters = { "A", "B", "C", "P", "A", "W" }
	for i = 0, toyRng:NextInteger(1, 2) do
		local size = 3.2 - i * 0.4
		local b = ArenaKit.NewPart("ToyCrate", Vector3.new(size, size, size), CFrame.new(pos + Vector3.new(toyRng:NextNumber(-0.3, 0.3), size / 2 + i * 3.1, toyRng:NextNumber(-0.3, 0.3))) * CFrame.Angles(0, toyRng:NextNumber(-0.5, 0.5), 0), toyColor(), Enum.Material.SmoothPlastic, parent)
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.LightInfluence = 0.3
			gui.PixelsPerStud = 30
			gui.Parent = b
			local l = Instance.new("TextLabel")
			l.Size = UDim2.fromScale(1, 1)
			l.BackgroundTransparency = 1
			l.Text = letters[toyRng:NextInteger(1, #letters)]
			l.Font = Enum.Font.FredokaOne
			l.TextScaled = true
			l.TextColor3 = Color3.new(1, 1, 1)
			l.TextStrokeTransparency = 0.6
			l.Parent = gui
		end
		soften(b)
	end
end

-- a crayon standing up (a tall pillar with a pointed tip).
local function crayon(pos: Vector3, h: number, parent: Instance)
	local c = toyColor()
	if MeshLib.Has("CrayonBody") then
		local proxy = ArenaKit.NewPart("Crayon", Vector3.new(1.6, h, 1.6), CFrame.new(pos + Vector3.new(0, h / 2, 0)), c, Enum.Material.SmoothPlastic, parent)
		MeshLib.Hide(proxy)
		local o = CFrame.new(pos) * CFrame.Angles(0, toyRng:NextNumber(0, 6.28), 0)
		MeshLib.Place("CrayonBody", o, Vector3.new(1, h, 1), c, Enum.Material.SmoothPlastic, parent)
		MeshLib.Place("CrayonBands", o, Vector3.new(1, h, 1), c:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.SmoothPlastic, parent)
		MeshLib.Place("CrayonTip", o + Vector3.new(0, h, 0), 1, c, Enum.Material.SmoothPlastic, parent)
		return
	end
	local body = ArenaKit.NewPart("Crayon", Vector3.new(h, 1.6, 1.6), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), c, Enum.Material.SmoothPlastic, parent) :: Part
	body.Shape = Enum.PartType.Cylinder
	for _, y in ipairs({ h * 0.15, h * 0.85 }) do
		local band = toyDeco(ArenaKit.NewPart("Bloom", Vector3.new(0.5, 1.7, 1.7), CFrame.new(pos + Vector3.new(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), c:Lerp(Color3.new(0, 0, 0), 0.35), Enum.Material.SmoothPlastic, parent)) :: Part
		band.Shape = Enum.PartType.Cylinder
	end
	toyDeco(ArenaKit.NewWedge("Bloom", Vector3.new(1.4, 1.6, 1.4), CFrame.new(pos + Vector3.new(0, h + 0.8, 0)), c, Enum.Material.SmoothPlastic, parent))
end

-- a bunch of balloons on strings, tied to a spot.
local function balloons(pos: Vector3, parent: Instance)
	for k = 1, 3 do
		local top = pos + Vector3.new(toyRng:NextNumber(-1.6, 1.6), 9 + k * 1.2, toyRng:NextNumber(-1.6, 1.6))
		local color = toyColor()
		if not MeshLib.Place("Balloon", CFrame.new(top - Vector3.new(0, 1.8 * 0.8, 0)), 0.8, color, Enum.Material.Glass, parent) then
			toyBall(2.4, top, color, parent).Material = Enum.Material.Glass
		end
		toyDeco(ArenaKit.Beam("String", pos + Vector3.new(0, 0.2, 0), top - Vector3.new(0, 1.2, 0), 0.06, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, parent))
	end
end

-- a candy-cane lamp (red and white stripes, a warm light on top).
local function candyLamp(pos: Vector3, parent: Instance)
	if MeshLib.Has("CandyCaneWhite") then
		-- a real candy cane: a striped pole with the hook, the light hanging
		-- from it.
		local o = CFrame.new(pos) * CFrame.Angles(0, toyRng:NextNumber(0, 6.28), 0)
		MeshLib.Place("CandyCaneWhite", o, 1, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, parent)
		MeshLib.Place("CandyCaneRed", o, 1, Color3.fromRGB(240, 60, 70), Enum.Material.SmoothPlastic, parent)
		local bulb = toyBall(0.9, (o * CFrame.new(1.2, 6.5, 0)).Position, Color3.fromRGB(255, 236, 170), parent)
		bulb.Material = Enum.Material.Neon
		local l = Instance.new("PointLight")
		l.Color = Color3.fromRGB(255, 220, 160)
		l.Range = 16
		l.Brightness = 0.8
		l.Parent = bulb
		return
	end
	for i = 0, 6 do
		toyDeco(ArenaKit.NewPart("Post", Vector3.new(0.5, 1, 0.5), CFrame.new(pos + Vector3.new(0, 0.5 + i, 0)), i % 2 == 0 and Color3.fromRGB(240, 60, 70) or Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, parent))
	end
	local bulb = toyBall(1.3, pos + Vector3.new(0, 7.6, 0), Color3.fromRGB(255, 236, 170), parent)
	bulb.Material = Enum.Material.Neon
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 220, 160)
	l.Range = 16
	l.Brightness = 0.8
	l.Parent = bulb
end

-- confetti sprinkles on a surface.
local function sprinkles(center: Vector3, r: number, parent: Instance)
	for _ = 1, math.floor(r * 2.2) do
		local a = toyRng:NextNumber(0, math.pi * 2)
		local d = toyRng:NextNumber(2, r - 1.5)
		toyDeco(ArenaKit.NewPart("Bloom", Vector3.new(0.9, 0.05, 0.25), CFrame.new(center + Vector3.new(math.cos(a) * d, 0.03, math.sin(a) * d)) * CFrame.Angles(0, toyRng:NextNumber(0, 3.14), 0), toyColor(), Enum.Material.SmoothPlastic, parent))
	end
end

-- a free spot on an island's rim, away from the bridge toward the centre.
local function rimSpot(pos: Vector3, r: number, avoidDir: Vector3?): Vector3
	for _ = 1, 12 do
		local a = toyRng:NextNumber(0, math.pi * 2)
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		if not avoidDir or dir:Dot(avoidDir) < 0.55 then
			return pos + dir * (r - toyRng:NextNumber(2.5, 4)) + Vector3.new(0, 1.6, 0)
		end
	end
	return pos + Vector3.new(r - 3, 1.6, 0)
end

-- a toy train going round and round the centre island on its own track.
local function toyTrain(center: Vector3, radius: number, parent: Instance)
	local track = Instance.new("Folder")
	track.Name = "TrainTrack"
	track.Parent = parent
	local n = 48
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		local p = center + Vector3.new(math.cos(a) * radius, 0.05, math.sin(a) * radius)
		toyDeco(ArenaKit.NewPart("Rail", Vector3.new(2.4, 0.12, 0.5), CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a))) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(150, 100, 70), Enum.Material.Wood, track))
	end
	local cars = {}
	for c = 0, 3 do
		local car = Instance.new("Model")
		car.Name = "ToyTrain"
		local body = toyDeco(ArenaKit.NewPart("Bloom", Vector3.new(1.6, 1.4, 2.6), CFrame.new(), c == 0 and Color3.fromRGB(240, 70, 80) or toyColor(), Enum.Material.SmoothPlastic, car))
		if c == 0 then
			toyDeco(ArenaKit.NewPart("Bloom", Vector3.new(0.6, 1.2, 0.6), CFrame.new(0, 1.2, -0.7), Color3.fromRGB(40, 40, 50), Enum.Material.SmoothPlastic, car))
		end
		for _, w in ipairs({ { -0.85, -0.8 }, { 0.85, -0.8 }, { -0.85, 0.8 }, { 0.85, 0.8 } }) do
			local wheel = toyDeco(ArenaKit.NewPart("Bloom", Vector3.new(0.3, 0.8, 0.8), CFrame.new(w[1], -0.6, w[2]), Color3.fromRGB(40, 40, 50), Enum.Material.SmoothPlastic, car)) :: Part
			wheel.Shape = Enum.PartType.Cylinder
		end
		car.PrimaryPart = body
		car.Parent = track
		-- (weld the bits to the body so the car moves as one.)
		for _, p in ipairs(car:GetChildren()) do
			if p:IsA("BasePart") and p ~= body then
				p.CFrame = body.CFrame * p.CFrame
			end
		end
		table.insert(cars, { model = car, offsets = (function()
			local o = {}
			for _, p in ipairs(car:GetChildren()) do
				if p:IsA("BasePart") then
					o[p] = body.CFrame:ToObjectSpace(p.CFrame)
				end
			end
			return o
		end)() })
	end
	task.spawn(function()
		local t = 0
		while track.Parent do
			t += task.wait(1 / 15)
			for i, c in ipairs(cars) do
				local a = t * 0.25 - (i - 1) * 0.07
				local p = center + Vector3.new(math.cos(a) * radius, 1, math.sin(a) * radius)
				local cf = CFrame.lookAt(p, p + Vector3.new(-math.sin(a), 0, math.cos(a)))
				for part, off in pairs(c.offsets) do
					part.CFrame = cf * off
				end
			end
		end
	end)
end

-- a rainbow arching high over the centre.
local function rainbow(center: Vector3, parent: Instance)
	local colors = { Color3.fromRGB(255, 90, 90), Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 230, 80), Color3.fromRGB(110, 220, 120), Color3.fromRGB(90, 170, 255), Color3.fromRGB(170, 110, 255) }
	for b, c in ipairs(colors) do
		local r = 70 - b * 2.2
		for k = 0, 23 do
			local a = math.pi * k / 23
			local p = center + Vector3.new(math.cos(a) * r, 18 + math.sin(a) * r * 0.75, 30)
			local seg = toyDeco(ArenaKit.NewPart("Bloom", Vector3.new(2.2, 2.2, 10.5), CFrame.lookAt(p, p + Vector3.new(-math.sin(a), math.cos(a) * 0.75, 0)), c, Enum.Material.SmoothPlastic, parent))
			seg.Transparency = 0.15
		end
	end
end

-- a giant rubber duck bobbing in the clouds.
local function giantDuck(pos: Vector3, parent: Instance)
	local yellow, orange = Color3.fromRGB(255, 214, 50), Color3.fromRGB(255, 140, 40)
	if MeshLib.Has("DuckBody") then
		MeshLib.Place("DuckBody", CFrame.new(pos), 1, yellow, Enum.Material.SmoothPlastic, parent)
		MeshLib.Place("DuckBeak", CFrame.new(pos), 1, orange, Enum.Material.SmoothPlastic, parent)
		for _, s in ipairs({ -1, 1 }) do
			toyBall(1.4, pos + Vector3.new(s * 2.2, 9.6, -7.9), Color3.fromRGB(20, 20, 30), parent)
		end
		return
	end
	toyBall(14, pos, yellow, parent)
	toyBall(9, pos + Vector3.new(0, 8, -4), yellow, parent)
	toyDeco(ArenaKit.NewPart("Bloom", Vector3.new(4, 1.4, 3.2), CFrame.new(pos + Vector3.new(0, 7.4, -8.6)), orange, Enum.Material.SmoothPlastic, parent))
	for _, s in ipairs({ -1, 1 }) do
		toyBall(1.4, pos + Vector3.new(s * 2.2, 9.6, -7.9), Color3.fromRGB(20, 20, 30), parent)
	end
	toyBall(5, pos + Vector3.new(0, 3, 6), yellow, parent)
end

local function dressToyWorld(arena: Instance, centerPos: Vector3, centerR: number, layout: any, outerFolders: { Folder })
	local f = Instance.new("Folder")
	f.Name = "ToyWorld"
	f.Parent = arena
	local top = centerPos + Vector3.new(0, 1.6, 0)
	sprinkles(top, centerR, f)
	toyTrain(top, centerR - 3, f)
	rainbow(centerPos, f)
	for i, o in ipairs(layout.Outer) do
		local isl = outerFolders[i]
		local toCenter = (centerPos - o.pos) * Vector3.new(1, 0, 1)
		local avoid = toCenter.Magnitude > 0 and toCenter.Unit or nil
		local surf = o.pos + Vector3.new(0, 1.6, 0)
		sprinkles(surf, o.r, isl)
		lollipop(rimSpot(o.pos, o.r, avoid), toyRng:NextNumber(0.8, 1.1), isl)
		lollipop(rimSpot(o.pos, o.r, avoid), toyRng:NextNumber(0.7, 0.9), isl)
		abcBlocks(rimSpot(o.pos, o.r, avoid), isl)
		balloons(rimSpot(o.pos, o.r, avoid), isl)
		candyLamp(rimSpot(o.pos, o.r, avoid), isl)
		if i > 2 then
			crayon(rimSpot(o.pos, o.r, avoid), 9 + toyRng:NextNumber(0, 4), isl)
		end
	end
	for _, s in ipairs(layout.Satellites) do
		balloons(s.pos + Vector3.new(0, 1.6, 0), f)
	end
	-- giant toys out in the sky.
	giantDuck(centerPos + Vector3.new(-150, -20, 90), f)
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2 + 0.3
		local p = centerPos + Vector3.new(math.cos(a) * 165, toyRng:NextNumber(-30, 30), math.sin(a) * 165)
		local size = toyRng:NextNumber(10, 18)
		toyDeco(ArenaKit.NewPart("Bloom", Vector3.one * size, CFrame.new(p) * CFrame.Angles(toyRng:NextNumber(0, 1), toyRng:NextNumber(0, 3), toyRng:NextNumber(0, 1)), toyColor(), Enum.Material.SmoothPlastic, f))
	end
	for k = 1, 10 do
		local a = toyRng:NextNumber(0, math.pi * 2)
		local d = toyRng:NextNumber(90, 200)
		local p = centerPos + Vector3.new(math.cos(a) * d, toyRng:NextNumber(20, 70), math.sin(a) * d)
		toyBall(toyRng:NextNumber(5, 8), p, toyColor(), f).Material = Enum.Material.Glass
		toyDeco(ArenaKit.Beam("String", p - Vector3.new(0, 3, 0), p - Vector3.new(0, 14, 0), 0.1, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, f))
	end
end

function Toybox.Build(): Folder
	local arena, spawns, powerPads = ArenaKit.SetupFolders(Workspace, Toybox.Name)
	local layout = ArenaKit.StandardLayout

	local centerPos = layout.Center.pos
	local centerR = layout.Center.r
	local center = ArenaKit.MakeIslandBase(centerPos, centerR, "CenterIsland", PALETTE, Enum.Material.SmoothPlastic, arena, TOY_ISLE)
	scatterDecor(centerPos, centerR, center, 8, 30)
	makeBlockTower(centerPos + Vector3.new(0, 1.6, 0), center)
	makeToyHouse(Vector3.new(-16, 1.6, -8), center, 0.9)
	makeToyHouse(Vector3.new(14, 1.6, 10), center, 0.72)
	makeToyArch(Vector3.new(0, 1.6, -15), center)
	makeToyRail(Vector3.new(-13, 1.6, 3), 16, center)
	makeToySlide(Vector3.new(10, 1.6, -9), center, Color3.fromRGB(255, 120, 150))
	makeToyDice(Vector3.new(-10, 1.6, 12), center)
	makePlatform(Vector3.new(0, 8, 0), Vector3.new(16, 1.5, 16), center)
	-- ladders: up to the platform, then on up the block tower.
	ArenaKit.AddLadder(centerPos + Vector3.new(9, 1.6, 0), 7.4, Vector3.xAxis, center)
	ArenaKit.AddLadder(centerPos + Vector3.new(3.9, 8.75, 0), 9, Vector3.xAxis, center)
	makeCrate(Vector3.new(-14, 1.6, 10), center)
	makeCrate(Vector3.new(14, 1.6, -10), center)
	ArenaKit.AddPowerPad(Vector3.new(0, 9, 0), powerPads)

	local outerFolders: { Folder } = {}
	local satFolders: { Folder } = {}
	for i, o in ipairs(layout.Outer) do
		local isl = ArenaKit.MakeIslandBase(o.pos, o.r, "Island" .. i, PALETTE, Enum.Material.SmoothPlastic, arena, TOY_ISLE)
		outerFolders[i] = isl
		scatterDecor(o.pos, o.r, isl, 5, 16)
		-- the two side islands get a bubble tube you can swim up (turned off
		-- the outward side so it misses the ribbon falls).
		if i == 3 or i == 4 then
			ArenaKit.AddSwimColumn("Bubbles", ArenaKit.NewIsle(o.pos, o.r, isl), ArenaKit.AngleTo(Vector3.zero, o.pos) + 0.6, isl)
		end
		makeStreamerFall(o.pos + Vector3.new(o.r - 2, 1, 0), 36 + i * 3, isl)
		makeStreamerFall(o.pos + Vector3.new(-(o.r - 2), 1, 4), 30 + i * 3, isl)
		if i == 3 or i == 4 or i == 5 or i == 6 then
			makeToyHouse(o.pos + Vector3.new(-5, 1.6, 4), isl, 0.66)
		end
		if o.team then
			makeToyTeamMarker(o.pos + Vector3.new(-8, 1.6, -8), o.team, isl)
			makeToyRail(o.pos + Vector3.new(0, 1.6, 9), 14, isl)
			makeToySlide(o.pos + Vector3.new(8, 1.6, -5), isl, o.team == "Red" and Color3.fromRGB(255, 120, 150) or Color3.fromRGB(120, 200, 255))
		else
			makeToyArch(o.pos + Vector3.new(0, 1.6, -8), isl)
			makeToyDice(o.pos + Vector3.new(7, 1.6, 6), isl)
		end
		local dir = centerPos - o.pos
		local edgeA = o.pos + Vector3.new(0, 1.6, 0) + dir.Unit * (o.r - 2)
		local edgeB = centerPos + Vector3.new(0, 1.6, 0) - dir.Unit * (centerR - 2)
		ArenaKit.MakeBridge(edgeA, edgeB, arena, PALETTE)
		if o.team == "Blue" or o.team == "Red" then
			-- three spawns spread wide across the team island.
			for _, deg in ipairs({ 30, 150, 270 }) do
				local a = math.rad(deg)
				ArenaKit.AddTeamSpawnPoint(o.pos + Vector3.new(math.cos(a), 0, math.sin(a)) * o.r * 0.6, o.team, spawns, isl)
			end
		end
		if not o.team then
			ArenaKit.AddPowerPad(o.pos, powerPads)
			makeCrate(o.pos + Vector3.new(6, 0, 6), isl)
		end
	end

	for si, s in ipairs(layout.Satellites) do
		local isl = ArenaKit.MakeIslandBase(s.pos, s.r, "Satellite" .. si, PALETTE, Enum.Material.SmoothPlastic, arena, TOY_ISLE)
		satFolders[si] = isl
		scatterDecor(s.pos, s.r, isl, 1, 6)
	end

	-- supply drops land on the centre and outer islands. jump pads on two outer
	-- islands reach the floating satellites, whose own pads drop you back onto
	-- the centre (landing spots chosen clear of the toy houses and arch).
	ArenaKit.MarkPlayable(center)
	for _, f in ipairs(outerFolders) do
		ArenaKit.MarkPlayable(f)
	end
	local pads = Instance.new("Folder")
	pads.Name = "JumpPads"
	pads.Parent = arena
	local centerIsle = ArenaKit.NewIsle(centerPos, centerR, center)
	local o3 = ArenaKit.NewIsle(layout.Outer[3].pos, layout.Outer[3].r, outerFolders[3])
	local o4 = ArenaKit.NewIsle(layout.Outer[4].pos, layout.Outer[4].r, outerFolders[4])
	local s1 = ArenaKit.NewIsle(layout.Satellites[1].pos, layout.Satellites[1].r, satFolders[1])
	local s2 = ArenaKit.NewIsle(layout.Satellites[2].pos, layout.Satellites[2].r, satFolders[2])
	ArenaKit.AddJumpPad(o3, ArenaKit.AngleTo(o3.pos, s2.pos), o3.r * 0.55, ArenaKit.FacingPoint(s2, o3.pos, s2.r * 0.55, 0), pads)
	ArenaKit.AddJumpPad(o4, math.rad(112), o4.r * 0.55, ArenaKit.FacingPoint(s1, o4.pos, s1.r * 0.55, 0), pads)
	ArenaKit.AddJumpPad(s1, 0, 0, ArenaKit.Polar(centerIsle, math.rad(80), centerR * 0.6), pads)
	ArenaKit.AddJumpPad(s2, 0, 0, ArenaKit.Polar(centerIsle, math.rad(240), centerR * 0.6), pads)

	ArenaKit.ScatterDebris(arena, 22, PALETTE, false)
	dressToyWorld(arena, centerPos, centerR, layout, outerFolders)
	-- cotton-candy clouds below and above.
	ArenaKit.MakeCloudBank(arena, Color3.fromRGB(255, 214, 236), 36, -62, -34, 40, 300, 0.1)
	ArenaKit.MakeCloudBank(arena, Color3.fromRGB(214, 236, 255), 18, -50, -30, 60, 300, 0.15)
	ArenaKit.MakeCloudBank(arena, Color3.fromRGB(255, 245, 250), 12, 70, 100, 140, 320, 0.35)
	ArenaKit.ApplyAtmosphere({
		Density = 0.2, Offset = 0.22, Color = Color3.fromRGB(255, 222, 242),
		Decay = Color3.fromRGB(170, 200, 255), Glare = 0.25, Haze = 1,
		Ambient = Color3.fromRGB(160, 150, 180), OutdoorAmbient = Color3.fromRGB(210, 200, 230),
		ClockTime = 14, Brightness = 2.3,
	})
	arena:SetAttribute("SpawnCount", #spawns:GetChildren())

	-- a giant toy spring each side of the block tower, and a ball pit to hide in.
	for _, p in ipairs({ Vector3.new(22, 1.6, -14), Vector3.new(-22, 1.6, 14) }) do
		ArenaKit.AddSpring(centerPos + p, 125, center)
	end
	ArenaKit.AddBallPit(centerPos + Vector3.new(0, 1.6, 21), 12, 8, Random.new(20260930), center)

	return arena
end

return Toybox
