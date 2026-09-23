--[[
	Signal
	------
	Tiny pure-Lua signal (no BindableEvent, so tables are passed by reference
	and there is no serialization cost).
]]

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn)
	local handlers = self._handlers
	table.insert(handlers, fn)
	return {
		Disconnect = function()
			local index = table.find(handlers, fn)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	-- Iterate a copy so handlers can disconnect while firing.
	for _, fn in ipairs(table.clone(self._handlers)) do
		task.spawn(fn, ...)
	end
end

return Signal
