--[[
	Remotes
	-------
	Single source of truth for networking. We intentionally use only THREE
	remotes to keep the attack surface and bandwidth small:

	  Request  (RemoteFunction, client -> server)
	      Every UI action: Request:InvokeServer(actionName, payload)
	      The server validates EVERYTHING and returns (ok, resultOrMessage).

	  Sync     (RemoteEvent, server -> client)
	      Replicates the player's own data. ("Full", snapshot) on join, then
	      batched ("Patch", { key = value, ... }) at most 10x per second.

	  Signal   (RemoteEvent, server -> client)
	      Fire-and-forget game events: item found, fusion complete, banners,
	      toasts, dumpster FX, announcements.

	Dumpster searching uses ProximityPrompts, which the server listens to
	directly — no remote is needed (and none can be spoofed).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

local FOLDER_NAME = "Remotes"
local DEFINITIONS = {
	Request = "RemoteFunction",
	Sync = "RemoteEvent",
	Signal = "RemoteEvent",
}

local folder
if RunService:IsServer() then
	folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for name, className in pairs(DEFINITIONS) do
		if not folder:FindFirstChild(name) then
			local remote = Instance.new(className)
			remote.Name = name
			remote.Parent = folder
		end
	end
else
	folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
end

for name in pairs(DEFINITIONS) do
	Remotes[name] = RunService:IsServer() and folder[name] or folder:WaitForChild(name)
end

return Remotes
