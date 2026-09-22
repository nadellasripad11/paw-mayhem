--!strict
-- MapRegistry: the full map list. Add a new map by dropping a module in
-- World/Maps/ (Id, Name, Build()) and adding one line here.

local MapRegistry = {}

MapRegistry.Maps = {
	require(script.Parent.Maps.SkyIslands),
	require(script.Parent.Maps.Volcano),
	require(script.Parent.Maps.Toybox),
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
