-- RemoteFunction:InvokeServer() has NO built-in timeout -- if the server
-- never responds (e.g. OnServerInvoke was never set because server startup
-- crashed), the call just hangs forever with zero feedback. This wraps it
-- with an explicit timeout so a broken server always surfaces as a visible
-- message instead of a silent "nothing happens".

local RemoteHelpers = {}

-- Returns (true, result) on a normal response, or (false, message) on either
-- an InvokeServer error or a timeout.
function RemoteHelpers.InvokeWithTimeout(remoteFunction, timeoutSeconds, ...)
	local args = { ... }
	local done = false
	local ok, result

	task.spawn(function()
		ok, result = pcall(function()
			return remoteFunction:InvokeServer(table.unpack(args))
		end)
		done = true
	end)

	local start = os.clock()
	while not done and os.clock() - start < timeoutSeconds do
		task.wait(0.05)
	end

	if not done then
		return false,
			string.format(
				"Timed out waiting %ds for %s to respond. The request never came back at all -- "
					.. "this usually means the server never set up its handler (a script error during "
					.. "server startup), not that it rejected the request.",
				timeoutSeconds,
				remoteFunction.Name
			)
	end

	return ok, result
end

return RemoteHelpers
