--!strict
-- Trove: track objects/connections and clean them all up at once.
-- Handles RBXScriptConnection, Instances, functions, and objects with
-- :Destroy() or :Disconnect().

local Trove = {}
Trove.__index = Trove

function Trove.new()
	return setmetatable({ _items = {} }, Trove)
end

function Trove:Add(item: any): any
	table.insert(self._items, item)
	return item
end

function Trove:Connect(signal: RBXScriptSignal, fn: (...any) -> ()): RBXScriptConnection
	local conn = signal:Connect(fn)
	self:Add(conn)
	return conn
end

local function cleanupItem(item: any)
	if typeof(item) == "RBXScriptConnection" then
		item:Disconnect()
	elseif typeof(item) == "Instance" then
		item:Destroy()
	elseif type(item) == "function" then
		item()
	elseif type(item) == "table" then
		if type(item.Destroy) == "function" then
			item:Destroy()
		elseif type(item.Disconnect) == "function" then
			item:Disconnect()
		end
	end
end

function Trove:Clean()
	for _, item in ipairs(self._items) do
		pcall(cleanupItem, item)
	end
	table.clear(self._items)
end

Trove.Destroy = Trove.Clean

return Trove
