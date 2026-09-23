--[[
	QuestService
	------------
	Tracks Main (story), Daily and Weekly quests from Data/Quests.

	Other services call QuestService.Increment(profile, type, amount, rarityOrder)
	when things happen. Progress is capped at the target; players claim rewards
	through the "ClaimQuest" request (validated here).

	Daily / Weekly lists re-roll when the UTC day / week changes (checked on join
	and once a minute for online players).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Util = require(Shared.Util)
local Quests = require(Shared.Data.Quests)

local QuestService = {}

local Services

-- Quest types whose progress is an absolute value rather than a counter.
local function getAbsoluteProgress(profile, quest)
	if quest.Type == "UnlockZone" then
		return Formulas.GetHighestZone(profile.Data)
	end
	if quest.Category == "Main" and quest.Type == "Discover" then
		return Util.CountKeys(profile.Data.Discovered)
	end
	return nil
end

local function matches(quest, questType, rarityOrder)
	if quest.Type ~= questType then
		return false
	end
	if quest.Type == "FindRarity" then
		local required = Config.RarityByName[quest.Rarity]
		return rarityOrder ~= nil and required ~= nil and rarityOrder >= required.Order
	end
	return true
end

-- Picks `count` distinct random quests from a pool, seeded by the period so
-- that everyone on the same day gets a consistent-feeling but personal set.
local function rollList(pool, count, seed)
	local random = Random.new(seed)
	local indices = {}
	for i = 1, #pool do
		indices[i] = i
	end
	for i = #indices, 2, -1 do
		local j = random:NextInteger(1, i)
		indices[i], indices[j] = indices[j], indices[i]
	end
	local list = {}
	for i = 1, math.min(count, #indices) do
		table.insert(list, { Id = pool[indices[i]].Id, Progress = 0, Claimed = false })
	end
	return list
end

function QuestService.RefreshPeriodic(profile)
	local questData = profile.Data.Quests
	local changed = false
	local day = Util.GetDayNumber()
	local week = Util.GetWeekNumber()

	if questData.Daily.Period ~= day then
		questData.Daily.Period = day
		questData.Daily.List = rollList(Quests.Daily, Quests.DailyCount, day * 7919 + profile.UserId)
		changed = true
	end
	if questData.Weekly.Period ~= week then
		questData.Weekly.Period = week
		questData.Weekly.List = rollList(Quests.Weekly, Quests.WeeklyCount, week * 104729 + profile.UserId)
		changed = true
	end
	if changed then
		Services.DataService.MarkDirty(profile.Player, "Quests")
	end
end

function QuestService.Increment(profile, questType, amount, rarityOrder)
	local questData = profile.Data.Quests
	local changed = false

	local main = Quests.Main[questData.Main.Index]
	if main and matches(main, questType, rarityOrder) and not getAbsoluteProgress(profile, main) then
		local newProgress = math.min(main.Target, questData.Main.Progress + amount)
		if newProgress ~= questData.Main.Progress then
			questData.Main.Progress = newProgress
			changed = true
		end
	end

	for _, category in ipairs({ "Daily", "Weekly" }) do
		for _, entry in ipairs(questData[category].List) do
			local quest = Quests.ById[entry.Id]
			if quest and not entry.Claimed and matches(quest, questType, rarityOrder) and entry.Progress < quest.Target then
				entry.Progress = math.min(quest.Target, entry.Progress + amount)
				changed = true
			end
		end
	end

	if changed then
		Services.DataService.MarkDirty(profile.Player, "Quests")
	end
end

-- Current progress (handles absolute quests).
function QuestService.GetProgress(profile, quest, storedProgress)
	return getAbsoluteProgress(profile, quest) or storedProgress or 0
end

local function handleClaimQuest(profile, payload)
	if type(payload) ~= "table" or type(payload.Category) ~= "string" then
		return false, "Bad request."
	end
	local questData = profile.Data.Quests
	local category = payload.Category

	if category == "Main" then
		local quest = Quests.Main[questData.Main.Index]
		if not quest then
			return false, "All story quests complete!"
		end
		if QuestService.GetProgress(profile, quest, questData.Main.Progress) < quest.Target then
			return false, "Quest not complete yet."
		end
		questData.Main.Index += 1
		questData.Main.Progress = 0
		Services.DataService.MarkDirty(profile.Player, "Quests")
		Services.RewardService.Grant(profile, quest.Reward, quest.Title)
		return true
	end

	if category ~= "Daily" and category ~= "Weekly" then
		return false, "Bad category."
	end
	local index = payload.Index
	if type(index) ~= "number" then
		return false, "Bad index."
	end
	local entry = questData[category].List[math.floor(index)]
	local quest = entry and Quests.ById[entry.Id]
	if not quest then
		return false, "Quest not found."
	end
	if entry.Claimed then
		return false, "Already claimed."
	end
	if entry.Progress < quest.Target then
		return false, "Quest not complete yet."
	end
	entry.Claimed = true
	Services.DataService.MarkDirty(profile.Player, "Quests")
	Services.RewardService.Grant(profile, quest.Reward, quest.Title)
	return true
end

function QuestService.Init(services)
	Services = services
	Services.DataService.OnProfileLoaded(function(profile)
		QuestService.RefreshPeriodic(profile)
	end)
end

function QuestService.Start()
	Services.Router.Register("ClaimQuest", handleClaimQuest)
	task.spawn(function()
		while true do
			task.wait(60)
			for _, profile in pairs(Services.DataService.GetAllProfiles()) do
				if profile.Loaded then
					QuestService.RefreshPeriodic(profile)
				end
			end
		end
	end)
end

return QuestService
