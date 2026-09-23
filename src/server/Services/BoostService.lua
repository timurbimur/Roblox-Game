--[[
	BoostService
	------------
	Timed boosts (2x Luck, 2x Cash, Fusion Speed, Cooldown Reduction).

	Stored as REMAINING seconds in data.Boosts so they persist across sessions
	and only tick down while the player is online. One 1-second loop updates
	every online player; clients count down locally and are only re-synced when
	a boost is added or expires (no per-second network traffic).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)

local BoostService = {}

local Services

function BoostService.AddBoost(profile, boostId, duration)
	if not Config.Boosts[boostId] or type(duration) ~= "number" or duration <= 0 then
		return false
	end
	local boosts = profile.Data.Boosts
	boosts[boostId] = math.min(Config.MaxBoostDuration, (boosts[boostId] or 0) + math.floor(duration))
	Services.DataService.MarkDirty(profile.Player, "Boosts")
	return true
end

function BoostService.IsActive(profile, boostId)
	return (profile.Data.Boosts[boostId] or 0) > 0
end

local function tick(dt)
	for _, profile in pairs(Services.DataService.GetAllProfiles()) do
		if profile.Loaded then
			local boosts = profile.Data.Boosts
			local expired = false
			for boostId, remaining in pairs(boosts) do
				remaining -= dt
				if remaining <= 0 then
					boosts[boostId] = nil
					expired = true
				else
					boosts[boostId] = remaining
				end
			end
			if expired then
				Services.DataService.MarkDirty(profile.Player, "Boosts")
			end
		end
	end
end

function BoostService.Init(services)
	Services = services
end

function BoostService.Start()
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			tick(now - last)
			last = now
		end
	end)
end

return BoostService
