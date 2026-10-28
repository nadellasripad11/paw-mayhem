--!strict
-- mapregistry: the full map list. add a new map by dropping a module in
-- world/maps/ (id, name, build()) and adding one line here.

local MapRegistry = {}

MapRegistry.Maps = {
	require(script.Parent.Maps.SkyIslands),
	require(script.Parent.Maps.Volcano),
	require(script.Parent.Maps.Toybox),
	require(script.Parent.Maps.Rooftops),
}

function MapRegistry.GetById(id: string)
	for _, m in ipairs(MapRegistry.Maps) do
		if m.Id == id then
			return m
		end
	end
	return nil
end

function MapRegistry.Random()
	return MapRegistry.Maps[math.random(1, #MapRegistry.Maps)]
end

return MapRegistry
