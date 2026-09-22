local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ServerLog = Remotes:WaitForChild("ServerLog")

-- If server startup fails, broadcast it to every client (present and any
-- that join later) instead of just failing silently -- a crash here means
-- SpinFunction/EquipFunction never get their OnServerInvoke set, which
-- otherwise looks to players like "nothing happens" when they click SPIN.
local function broadcastFatal(message)
	warn("[Main.server] FATAL: " .. message)
	for _, player in ipairs(Players:GetPlayers()) do
		ServerLog:FireClient(player, message)
	end
	Players.PlayerAdded:Connect(function(player)
		ServerLog:FireClient(player, message)
	end)
end

local ok, err = pcall(function()
	local DataService = require(script.Parent.DataService)
	local SpinService = require(script.Parent.SpinService)

	-- Order matters: player save data must be loadable before spin/equip
	-- requests are handled.
	DataService.Init()
	SpinService.Init()
end)

if not ok then
	broadcastFatal("Server failed to start:\n\n" .. tostring(err))
end
