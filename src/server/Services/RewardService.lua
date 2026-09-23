--[[
	RewardService
	-------------
	One place that turns a reward table into real grants, used by quests,
	achievements, daily login, playtime rewards and purchases.

	Reward table: { Cash = n, ScaleCash = bool, Boost = { Id, Duration }, Item = itemId }

	Also owns:
	  * Daily login (7-day cycle; missing a day resets the streak)
	  * Playtime rewards (per session, claimable after N minutes)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local RewardService = {}

local Services

function RewardService.Grant(profile, reward, sourceLabel)
	if type(reward) ~= "table" then
		return
	end
	local granted = {}
	if reward.Cash then
		local amount = reward.Cash
		if reward.ScaleCash then
			amount *= Formulas.GetZoneScale(profile.Data)
		end
		local added = Services.EconomyService.AddCash(profile, amount)
		table.insert(granted, Util.FormatCash(added))
	end
	if reward.Boost and Config.Boosts[reward.Boost.Id] then
		Services.BoostService.AddBoost(profile, reward.Boost.Id, reward.Boost.Duration)
		table.insert(granted, ("%s %s (%s)"):format(Config.Boosts[reward.Boost.Id].Icon, Config.Boosts[reward.Boost.Id].Name, Util.FormatTime(reward.Boost.Duration)))
	end
	if reward.Item and Items.ById[reward.Item] then
		Services.InventoryService.AddItem(profile, reward.Item, 1, "Reward")
		table.insert(granted, Items.ById[reward.Item].Icon .. " " .. Items.ById[reward.Item].Name)
	end
	Remotes.Signal:FireClient(profile.Player, "Reward", {
		Source = sourceLabel,
		Text = table.concat(granted, "  •  "),
		ItemId = reward.Item,
	})
end

-- ============================================================================
-- DAILY LOGIN
-- ============================================================================
function RewardService.GetDailyState(data)
	local today = Util.GetDayNumber()
	local daily = data.Daily
	local canClaim = daily.LastClaimDay ~= today
	local nextDay
	if daily.LastClaimDay == today - 1 then
		nextDay = daily.Streak % #Config.DailyRewards + 1
	elseif daily.LastClaimDay == today then
		nextDay = daily.Streak
	else
		nextDay = 1
	end
	return canClaim, nextDay
end

local function handleClaimDaily(profile)
	local data = profile.Data
	local canClaim, day = RewardService.GetDailyState(data)
	if not canClaim then
		return false, "Come back tomorrow!"
	end
	data.Daily.Streak = day
	data.Daily.LastClaimDay = Util.GetDayNumber()
	Services.DataService.MarkDirty(profile.Player, "Daily")

	local reward = Config.DailyRewards[day]
	RewardService.Grant(profile, { Cash = reward.Cash, ScaleCash = true, Boost = reward.Boost, Item = reward.Item }, "Daily Reward — Day " .. day)
	return true, day
end

-- ============================================================================
-- PLAYTIME
-- ============================================================================
local function handleClaimPlaytime(profile, payload)
	local index = type(payload) == "table" and payload.Index
	if type(index) ~= "number" then
		return false, "Bad request."
	end
	index = math.floor(index)
	local reward = Config.PlaytimeRewards[index]
	if not reward then
		return false, "Invalid reward."
	end
	local session = profile.Data.PlaytimeSession
	if session.Claimed[tostring(index)] then
		return false, "Already claimed."
	end
	if os.time() - session.StartedAt < reward.Minutes * 60 then
		return false, "Keep playing to unlock this!"
	end
	session.Claimed[tostring(index)] = true
	Services.DataService.MarkDirty(profile.Player, "PlaytimeSession")
	RewardService.Grant(profile, { Cash = reward.Cash, ScaleCash = true, Boost = reward.Boost, Item = reward.Item }, "Playtime Reward")
	return true
end

function RewardService.Init(services)
	Services = services
end

function RewardService.Start()
	Services.Router.Register("ClaimDaily", handleClaimDaily)
	Services.Router.Register("ClaimPlaytime", handleClaimPlaytime)
end

return RewardService
