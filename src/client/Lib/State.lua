--[[
	State
	-----
	Client-side mirror of the player's own data, fed ONLY by the server's Sync
	remote. The client never edits this table; UI reads it and re-renders when
	keys change.

	State.Watch("Cash", function(value) ... end)   -- fires now (if loaded) + on change
	State.OnLoaded(function(data) ... end)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Signal = require(script.Parent.Signal)

local State = {
	Data = nil,
	Loaded = false,
	KeyReceivedAt = {}, -- [key] = os.clock() when last received (boost countdowns)
}

local keySignals = {}
local loadedSignal = Signal.new()
local anySignal = Signal.new()

local function getSignal(key)
	local signal = keySignals[key]
	if not signal then
		signal = Signal.new()
		keySignals[key] = signal
	end
	return signal
end

function State.Get(key)
	return State.Data and State.Data[key]
end

function State.Watch(key, fn)
	local connection = getSignal(key):Connect(fn)
	if State.Loaded then
		task.spawn(fn, State.Data[key])
	end
	return connection
end

-- Fires with the set of changed keys after every update.
function State.OnAnyChanged(fn)
	return anySignal:Connect(fn)
end

function State.OnLoaded(fn)
	if State.Loaded then
		task.spawn(fn, State.Data)
		return
	end
	loadedSignal:Connect(fn)
end

Remotes.Sync.OnClientEvent:Connect(function(kind, payload)
	local now = os.clock()
	if kind == "Full" then
		State.Data = payload
		local changed = {}
		for key in pairs(payload) do
			State.KeyReceivedAt[key] = now
			changed[key] = true
		end
		local firstLoad = not State.Loaded
		State.Loaded = true
		if firstLoad then
			loadedSignal:Fire(State.Data)
		end
		for key, signal in pairs(keySignals) do
			signal:Fire(State.Data[key])
		end
		anySignal:Fire(changed)
	elseif kind == "Patch" and State.Data then
		for key, value in pairs(payload) do
			State.Data[key] = value
			State.KeyReceivedAt[key] = now
			local signal = keySignals[key]
			if signal then
				signal:Fire(value)
			end
		end
		anySignal:Fire(payload)
	end
end)

return State
