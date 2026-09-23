--[[
	Net
	---
	Wrapper around the single Request RemoteFunction. Failed requests show the
	server's message as a toast (unless silent).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)

local Net = {}

Net.OnError = nil -- set by Notifications: function(message)

function Net.Request(action, payload, silent)
	local ok, success, result = pcall(Remotes.Request.InvokeServer, Remotes.Request, action, payload)
	if not ok then
		success, result = false, "Connection problem — try again."
	end
	if not success and not silent and type(result) == "string" and Net.OnError then
		Net.OnError(result)
	end
	return success, result
end

-- Fire-and-forget (UI buttons shouldn't freeze while waiting).
function Net.RequestAsync(action, payload, callback, silent)
	task.spawn(function()
		local success, result = Net.Request(action, payload, silent)
		if callback then
			callback(success, result)
		end
	end)
end

return Net
