--[[
	AchievementService
	------------------
	Auto-grants achievements from Data/Achievements when their stat target is
	reached. To keep hot paths cheap, services call QueueCheck(profile) which
	just sets a flag; a single loop evaluates flagged profiles twice a second.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Util = require(Shared.Util)
local Items = require(Shared.Data.Items)
local Achievements = require(Shared.Data.Achievements)
local Remotes = require(Shared.Remotes)

local AchievementService = {}

local Services

local function getStat(profile, statName)
	local data = profile.Data
	if statName == "Discoveries" then
		return Util.CountKeys(data.Discovered)
	elseif statName == "CollectionPercent" then
		return Util.CountKeys(data.Discovered) / Items.Count * 100
	elseif statName == "ZonesUnlocked" then
		return Formulas.GetHighestZone(data)
	end
	return data.Stats[statName] or 0
end

function AchievementService.QueueCheck(profile)
	profile.AchievementCheckQueued = true
end

function AchievementService.Check(profile)
	profile.AchievementCheckQueued = false
	local unlocked = profile.Data.Achievements
	for _, achievement in ipairs(Achievements) do
		if not unlocked[achievement.Id] and getStat(profile, achievement.Stat) >= achievement.Target then
			unlocked[achievement.Id] = os.time()
			Services.DataService.MarkDirty(profile.Player, "Achievements")
			Remotes.Signal:FireClient(profile.Player, "Achievement", { Id = achievement.Id })
			Services.RewardService.Grant(profile, achievement.Reward, "🏆 " .. achievement.Name)
		end
	end
end

function AchievementService.Init(services)
	Services = services
	Services.DataService.OnProfileLoaded(function(profile)
		AchievementService.QueueCheck(profile)
	end)
end

function AchievementService.Start()
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, profile in pairs(Services.DataService.GetAllProfiles()) do
				if profile.Loaded and profile.AchievementCheckQueued then
					local ok, err = pcall(AchievementService.Check, profile)
					if not ok then
						warn("[AchievementService] " .. tostring(err))
					end
				end
			end
		end
	end)
end

return AchievementService
