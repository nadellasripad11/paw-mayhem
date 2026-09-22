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

function ArenaBuilder.Build(): Folder
	-- The flagship match map is the bright Sky Islands arena from the
	-- reference. Keep the other maps available for future rotation, but make
	-- the shipped experience consistently land in this arena.
	local map = MapRegistry.GetById("SkyIslands") or MapRegistry.Random()
	ArenaBuilder.CurrentMap = map
	print(string.format("[PAW MAYHEM] Building map: %s", map.Name))
	return map.Build()
end

-- Rebuild using a specific map by id (e.g. for testing, or a future map-vote
-- system). Falls back to a random map if the id is unknown.
function ArenaBuilder.BuildMap(id: string): Folder
	local map = MapRegistry.GetById(id) or MapRegistry.Random()
	ArenaBuilder.CurrentMap = map
	print(string.format("[PAW MAYHEM] Building map: %s", map.Name))
	return map.Build()
end

return ArenaBuilder
