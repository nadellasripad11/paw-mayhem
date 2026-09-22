--!strict
-- Signal: minimal, allocation-light signal implementation (Lua-side events).
-- Used where BindableEvents would be overkill.

local Signal = {}
Signal.__index = Signal

type Connection = { Disconnect: (self: any) -> (), Connected: boolean }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ()): Connection
	local conn = { Connected = true, _fn = fn, _signal = self }
	function conn:Disconnect()
		if not self.Connected then
			return
		end
		self.Connected = false
		local h = self._signal._handlers
		for i, v in ipairs(h) do
			if v == self then
				table.remove(h, i)
				break
			end
		end
	end
	table.insert(self._handlers, conn)
	return conn
end

function Signal:Fire(...)
	-- iterate a copy so handlers can disconnect during dispatch
	local snapshot = table.clone(self._handlers)
	for _, conn in ipairs(snapshot) do
		if conn.Connected then
			task.spawn(conn._fn, ...)
		end
	end
end

function Signal:DisconnectAll()
	table.clear(self._handlers)
end

return Signal
