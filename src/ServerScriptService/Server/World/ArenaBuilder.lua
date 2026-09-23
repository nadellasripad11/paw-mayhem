--!strict
-- ArenaBuilder: picks a map from MapRegistry and builds it. Kept as the public
-- entry point (same API as before the 3-map refactor) so init.server.lua and
-- anything else that calls ArenaBuilder.Build() doesn't need to change.
--
-- Selection: one random map per server session (chosen once at boot). All 3
-- maps share the exact same tested island layout and spawn-safety guarantees
-- (ArenaKit.StandardLayout) — only the theme differs — so switching maps never
-- changes balance, only look.

local MapRegistry = require(script.Parent.MapRegistry)

local ArenaBuilder = {}

ArenaBuilder.CurrentMap = nil :: any

-- Props that should never block a cat: fences, rails, lamps, crates, banners
-- and other small clutter snagged players or acted like invisible walls.
local DECOR_PREFIXES = {
	"Fence", "Rail", "ToyRail", "Lamp", "PostLamp", "Lantern", "Post", "Bush", "Bloom", "Flower", "BoxBloom",
	"Leaf", "Crate", "ToyCrate", "Barrel", "Banner", "Flag", "ToyTeam", "Seat", "Balloon", "Anvil", "Parapet",
	"Newel", "Finial", "Hang", "Rope", "String", "Sail", "Vane", "Arm", "Hub", "Emblem", "Bulb", "Drum",
	"Chimney", "Window", "WinFrame", "SideWindow", "Door", "Curtain", "Cross", "Chevron", "Ribbon",
}
-- Surfaces people walk on stay solid even when small.
local WALKABLE = { Floor = true, Deck = true, Landing = true, Step = true, Plank = true, Platform = true, Stringer = true, Guard = true, Rim = true, Top = true }

local function isDecor(name: string): boolean
	for _, prefix in ipairs(DECOR_PREFIXES) do
		if string.sub(name, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function freeMovement(arena: Instance)
	for _, p in ipairs(arena:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide and not WALKABLE[p.Name] then
			local biggest = math.max(p.Size.X, p.Size.Y, p.Size.Z)
			if isDecor(p.Name) or biggest < 3 or p.Transparency >= 0.95 then
				p.CanCollide = false
			end
		end
	end
end

local function finish(arena: Folder): Folder
	freeMovement(arena)
	return arena
end

function ArenaBuilder.Build(): Folder
	-- The flagship match map is the bright Sky Islands arena from the
	-- reference. Keep the other maps available for future rotation, but make
	-- the shipped experience consistently land in this arena.
	local map = MapRegistry.GetById("SkyIslands") or MapRegistry.Random()
	ArenaBuilder.CurrentMap = map
	print(string.format("[PAW MAYHEM] Building map: %s", map.Name))
	return finish(map.Build())
end

-- Rebuild using a specific map by id (e.g. for testing, or a future map-vote
-- system). Falls back to a random map if the id is unknown.
function ArenaBuilder.BuildMap(id: string): Folder
	local map = MapRegistry.GetById(id) or MapRegistry.Random()
	ArenaBuilder.CurrentMap = map
	print(string.format("[PAW MAYHEM] Building map: %s", map.Name))
	return finish(map.Build())
end

return ArenaBuilder
