--[[
	QuestsPanel
	-----------
	Tabs:
	  Quests        Main story quest + 3 Daily + 3 Weekly (with reset timers)
	  Daily         7-day login calendar (Day 7 = exclusive Mythic)
	  Playtime      session playtime rewards
	  Achievements  permanent milestones (auto-granted by the server)

	Also exposes QuestsPanel.HasClaimable() for the HUD "!" badge.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Util = require(Shared.Util)
local Quests = require(Shared.Data.Quests)
local Achievements = require(Shared.Data.Achievements)
local Items = require(Shared.Data.Items)

local ClientRoot = script.Parent.Parent
local UIKit = require(ClientRoot.UI.UIKit)
local Theme = require(ClientRoot.UI.Theme)
local State = require(ClientRoot.Lib.State)
local Net = require(ClientRoot.Lib.Net)

local QuestsPanel = {}

local Controllers
local window, tabs
local pages = {}
local questCards = {}
local dailyCards = {}
local playtimeRows = {}
local achievementRows = {}
local dailyResetLabel, weeklyResetLabel, dailyClaimButton, dailyStatus

local function serverNow()
	return Workspace:GetServerTimeNow()
end

-- ============================================================================
-- PROGRESS HELPERS (mirror QuestService rules)
-- ============================================================================
local function questProgress(data, quest, stored)
	if quest.Type == "UnlockZone" then
		return Formulas.GetHighestZone(data)
	end
	if quest.Category == "Main" and quest.Type == "Discover" then
		return Util.CountKeys(data.Discovered)
	end
	return stored or 0
end

local function dailyState(data)
	local today = Util.GetDayNumber(serverNow())
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

local function playtimeMinutes(data)
	local started = data.PlaytimeSession and data.PlaytimeSession.StartedAt or serverNow()
	return (serverNow() - started) / 60
end

function QuestsPanel.HasClaimable()
	local data = State.Data
	if not data then
		return false
	end
	local main = Quests.Main[data.Quests.Main.Index]
	if main and questProgress(data, main, data.Quests.Main.Progress) >= main.Target then
		return true
	end
	for _, category in ipairs({ "Daily", "Weekly" }) do
		for _, entry in ipairs(data.Quests[category].List) do
			local quest = Quests.ById[entry.Id]
			if quest and not entry.Claimed and entry.Progress >= quest.Target then
				return true
			end
		end
	end
	if (dailyState(data)) then
		return true
	end
	local minutes = playtimeMinutes(data)
	for index, reward in ipairs(Config.PlaytimeRewards) do
		if minutes >= reward.Minutes and not data.PlaytimeSession.Claimed[tostring(index)] then
			return true
		end
	end
	return false
end

-- ============================================================================
-- QUEST CARDS
-- ============================================================================
local function questCard(parent, order, color)
	local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 92), LayoutOrder = order, Parent = parent })
	card.UIStroke.Color = color
	local title = UIKit.Label({ Size = UDim2.new(0.62, 0, 0, 28), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, 24)
	local reward = UIKit.Label({ Size = UDim2.new(0.62, 0, 0, 20), Position = UDim2.fromOffset(12, 36), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.Yellow, Font = Theme.BodyFont, Parent = card }, 16)
	local bar = UIKit.ProgressBar({ Size = UDim2.new(0.62, 0, 0, 22), Position = UDim2.fromOffset(12, 62), Color = color, Parent = card, TextSize = 15 })
	local claim = UIKit.Button({
		Text = "Claim",
		Color = Theme.Colors.Green,
		Size = UDim2.new(0.3, 0, 0, 56),
		Position = UDim2.new(1, -12, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		TextSize = 24,
		Parent = card,
	})
	return { Card = card, Title = title, Reward = reward, Bar = bar, Claim = claim }
end

local function header(parent, text, order)
	return UIKit.Label({ Text = text, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = order, TextXAlignment = Enum.TextXAlignment.Left, Parent = parent }, 24)
end

local function buildQuests(page)
	local list = UIKit.ScrollList({ Size = UDim2.fromScale(1, 1), Parent = page })
	header(list, "⭐ Story Quest", 1)
	questCards.Main = questCard(list, 2, Theme.Colors.Yellow)
	questCards.Main.Claim.Activated:Connect(function()
		if not questCards.Main.Claim:GetAttribute("Disabled") then
			Net.RequestAsync("ClaimQuest", { Category = "Main" })
		end
	end)
	dailyResetLabel = header(list, "☀️ Daily Quests", 10)
	for index = 1, Quests.DailyCount do
		local card = questCard(list, 10 + index, Theme.Colors.Blue)
		card.Claim.Activated:Connect(function()
			if not card.Claim:GetAttribute("Disabled") then
				Net.RequestAsync("ClaimQuest", { Category = "Daily", Index = index })
			end
		end)
		questCards["Daily" .. index] = card
	end
	weeklyResetLabel = header(list, "📅 Weekly Quests", 20)
	for index = 1, Quests.WeeklyCount do
		local card = questCard(list, 20 + index, Theme.Colors.Purple)
		card.Claim.Activated:Connect(function()
			if not card.Claim:GetAttribute("Disabled") then
				Net.RequestAsync("ClaimQuest", { Category = "Weekly", Index = index })
			end
		end)
		questCards["Weekly" .. index] = card
	end
end

local function fillCard(card, quest, progress, claimed, zoneScale)
	if not quest then
		card.Card.Visible = false
		return
	end
	card.Card.Visible = true
	card.Title.Text = quest.Title
	card.Reward.Text = "🎁 " .. UIKit.RewardText(quest.Reward, zoneScale)
	local clamped = math.min(progress, quest.Target)
	card.Bar.Set(clamped / quest.Target, ("%s / %s"):format(Util.FormatNumber(clamped), Util.FormatNumber(quest.Target)))
	if claimed then
		card.Claim.Label.Text = "✔ Done"
		card.Claim:SetAttribute("Disabled", true)
	else
		card.Claim.Label.Text = progress >= quest.Target and "Claim!" or "In Progress"
		card.Claim:SetAttribute("Disabled", progress < quest.Target)
	end
end

local function refreshQuests()
	local data = State.Data
	local zoneScale = Formulas.GetZoneScale(data)
	local mainQuest = Quests.Main[data.Quests.Main.Index]
	if mainQuest then
		fillCard(questCards.Main, mainQuest, questProgress(data, mainQuest, data.Quests.Main.Progress), false, zoneScale)
	else
		questCards.Main.Card.Visible = true
		questCards.Main.Title.Text = "All story quests complete! 🎉"
		questCards.Main.Reward.Text = ""
		questCards.Main.Bar.Set(1, "Complete")
		questCards.Main.Claim.Label.Text = "✔"
		questCards.Main.Claim:SetAttribute("Disabled", true)
	end
	for _, category in ipairs({ "Daily", "Weekly" }) do
		local list = data.Quests[category].List
		local count = category == "Daily" and Quests.DailyCount or Quests.WeeklyCount
		for index = 1, count do
			local entry = list[index]
			fillCard(questCards[category .. index], entry and Quests.ById[entry.Id], entry and entry.Progress or 0, entry and entry.Claimed, zoneScale)
		end
	end
end

-- ============================================================================
-- DAILY LOGIN
-- ============================================================================
local function buildDaily(page)
	local grid = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0.7, 0), BackgroundTransparency = 1, Parent = page })
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.new(1 / 4, -10, 0.5, -10),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})
	for index, reward in ipairs(Config.DailyRewards) do
		local isBig = index == #Config.DailyRewards
		local card = UIKit.Card({ LayoutOrder = index, Color = isBig and Color3.fromRGB(110, 40, 90) or Theme.Colors.PanelLight, Parent = grid })
		UIKit.Label({ Text = "Day " .. reward.Day, Size = UDim2.new(1, -10, 0.24, 0), Position = UDim2.fromOffset(5, 4), Parent = card }, 24)
		local icon = reward.Item and Items.ById[reward.Item].Icon or (reward.Boost and Config.Boosts[reward.Boost.Id].Icon) or "💰"
		UIKit.new("TextLabel", { Size = UDim2.fromScale(0.5, 0.36), Position = UDim2.fromScale(0.5, 0.28), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1, TextScaled = true, Text = icon, Parent = card })
		local text = UIKit.Label({ Size = UDim2.new(1, -10, 0.3, 0), Position = UDim2.new(0, 5, 0.66, 0), Font = Theme.BodyFont, Parent = card }, 14)
		local status = UIKit.Label({ Name = "Status", Text = "", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0.4, BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 5, Visible = false, Parent = card }, 40)
		UIKit.Corner(Theme.SmallCorner).Parent = status
		dailyCards[index] = { Card = card, Text = text, Status = status, Reward = reward }
	end
	dailyStatus = UIKit.Label({ Text = "", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 0.72, 0), Parent = page }, 22)
	dailyClaimButton = UIKit.Button({
		Text = "Claim Daily Reward",
		Color = Theme.Colors.Green,
		Size = UDim2.new(0.5, 0, 0, 60),
		Position = UDim2.new(0.5, 0, 1, -6),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 26,
		Parent = page,
		OnClick = function()
			Net.RequestAsync("ClaimDaily", nil)
		end,
	})
end

local function refreshDaily()
	local data = State.Data
	local canClaim, day = dailyState(data)
	local zoneScale = Formulas.GetZoneScale(data)
	for index, entry in ipairs(dailyCards) do
		local reward = entry.Reward
		entry.Text.Text = UIKit.RewardText({ Cash = reward.Cash, ScaleCash = true, Boost = reward.Boost, Item = reward.Item }, zoneScale)
		local claimedThisCycle = (canClaim and index < day) or (not canClaim and index <= day)
		entry.Status.Visible = claimedThisCycle
		entry.Status.Text = "✔"
		entry.Card.UIStroke.Color = (index == day and canClaim) and Theme.Colors.Yellow or Theme.Colors.Stroke
		entry.Card.UIStroke.Thickness = (index == day and canClaim) and 4 or 2
	end
	dailyClaimButton:SetAttribute("Disabled", not canClaim)
	if canClaim then
		dailyStatus.Text = ("Day %d reward is ready! Streak: %d"):format(day, data.Daily.Streak)
	else
		local secondsLeft = 86400 - (serverNow() % 86400)
		dailyStatus.Text = ("Come back in %s for Day %d!"):format(Util.FormatTime(secondsLeft), day % #Config.DailyRewards + 1)
	end
end

-- ============================================================================
-- PLAYTIME
-- ============================================================================
local function buildPlaytime(page)
	local list = UIKit.ScrollList({ Size = UDim2.fromScale(1, 1), Parent = page })
	for index, reward in ipairs(Config.PlaytimeRewards) do
		local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 72), LayoutOrder = index, Parent = list })
		UIKit.Label({ Text = ("⏱️ %d minutes"):format(reward.Minutes), Size = UDim2.new(0.3, 0, 0, 30), Position = UDim2.fromOffset(12, 6), TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, 22)
		local rewardLabel = UIKit.Label({ Size = UDim2.new(0.3, 0, 0, 22), Position = UDim2.fromOffset(12, 40), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.Yellow, Font = Theme.BodyFont, Parent = card }, 15)
		local bar = UIKit.ProgressBar({ Size = UDim2.new(0.3, 0, 0, 22), Position = UDim2.new(0.34, 0, 0.5, -11), Color = Theme.Colors.Blue, Parent = card, TextSize = 14 })
		local claim = UIKit.Button({
			Text = "Claim", Color = Theme.Colors.Green, Size = UDim2.new(0.28, 0, 0, 52),
			Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), TextSize = 22, Parent = card,
			OnClick = function()
				Net.RequestAsync("ClaimPlaytime", { Index = index })
			end,
		})
		playtimeRows[index] = { Reward = rewardLabel, Bar = bar, Claim = claim }
	end
end

local function refreshPlaytime()
	local data = State.Data
	local minutes = playtimeMinutes(data)
	local zoneScale = Formulas.GetZoneScale(data)
	for index, reward in ipairs(Config.PlaytimeRewards) do
		local row = playtimeRows[index]
		local claimed = data.PlaytimeSession.Claimed[tostring(index)]
		row.Reward.Text = "🎁 " .. UIKit.RewardText({ Cash = reward.Cash, ScaleCash = true, Boost = reward.Boost, Item = reward.Item }, zoneScale)
		row.Bar.Set(math.min(1, minutes / reward.Minutes), claimed and "Claimed" or Util.FormatTime(math.max(0, reward.Minutes * 60 - minutes * 60)), true)
		row.Claim.Label.Text = claimed and "✔" or "Claim"
		row.Claim:SetAttribute("Disabled", claimed or minutes < reward.Minutes)
	end
end

-- ============================================================================
-- ACHIEVEMENTS
-- ============================================================================
local function achievementStat(data, stat)
	if stat == "Discoveries" then
		return Util.CountKeys(data.Discovered)
	elseif stat == "CollectionPercent" then
		return Util.CountKeys(data.Discovered) / Items.Count * 100
	elseif stat == "ZonesUnlocked" then
		return Formulas.GetHighestZone(data)
	end
	return data.Stats[stat] or 0
end

local function buildAchievements(page)
	local list = UIKit.ScrollList({ Size = UDim2.fromScale(1, 1), Parent = page })
	for index, achievement in ipairs(Achievements) do
		local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 66), LayoutOrder = index, Parent = list })
		local title = UIKit.Label({ Text = "🏆 " .. achievement.Name, Size = UDim2.new(0.45, 0, 0, 28), Position = UDim2.fromOffset(12, 4), TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, 22)
		UIKit.Label({ Text = "🎁 " .. UIKit.RewardText(achievement.Reward), Size = UDim2.new(0.45, 0, 0, 20), Position = UDim2.fromOffset(12, 38), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.Yellow, Font = Theme.BodyFont, Parent = card }, 14)
		local bar = UIKit.ProgressBar({ Size = UDim2.new(0.48, 0, 0, 26), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = Theme.Colors.Orange, Parent = card, TextSize = 15 })
		achievementRows[achievement.Id] = { Card = card, Title = title, Bar = bar, Def = achievement }
	end
end

local function refreshAchievements()
	local data = State.Data
	for id, row in pairs(achievementRows) do
		local def = row.Def
		local unlocked = data.Achievements[id] ~= nil
		local value = achievementStat(data, def.Stat)
		local suffix = def.Stat == "CollectionPercent" and "%" or ""
		row.Bar.Set(unlocked and 1 or value / def.Target, unlocked and "✔ Unlocked" or ("%s%s / %s%s"):format(Util.FormatNumber(value), suffix, Util.FormatNumber(def.Target), suffix), true)
		row.Card.UIStroke.Color = unlocked and Theme.Colors.Orange or Theme.Colors.Stroke
		row.Card.LayoutOrder = (unlocked and 1000 or 0) + table.find(Achievements, def)
	end
end

-- ============================================================================
local activeTab = "Quests"
local function refresh()
	if not window.Visible or not State.Data then
		return
	end
	if activeTab == "Quests" then
		refreshQuests()
		local now = serverNow()
		dailyResetLabel.Text = "☀️ Daily Quests  —  resets in " .. Util.FormatTime(86400 - now % 86400)
		local weekSeconds = 7 * 86400
		weeklyResetLabel.Text = "📅 Weekly Quests  —  resets in " .. Util.FormatTime(weekSeconds - ((now + 3 * 86400) % weekSeconds))
	elseif activeTab == "Daily" then
		refreshDaily()
	elseif activeTab == "Playtime" then
		refreshPlaytime()
	else
		refreshAchievements()
	end
end

local function refreshBadge()
	if Controllers.HUD then
		Controllers.HUD.SetBadge("Quests", QuestsPanel.HasClaimable())
	end
end

function QuestsPanel.SelectTab(name)
	tabs.Select(name)
end

function QuestsPanel.Init(controllers)
	Controllers = controllers
	local content
	window, content = UIKit.Window({
		Name = "QuestsWindow",
		Title = "Quests & Rewards",
		Icon = "📜",
		Color = Theme.Colors.Orange,
		Parent = controllers.UIController.Root,
		OnClose = function()
			controllers.UIController.Close()
		end,
	})
	local names = { "Quests", "Daily", "Playtime", "Achievements" }
	for _, name in ipairs(names) do
		pages[name] = UIKit.new("Frame", { Name = name, Size = UDim2.new(1, 0, 1, -50), Position = UDim2.fromOffset(0, 50), BackgroundTransparency = 1, Visible = false, Parent = content })
	end
	tabs = UIKit.Tabs(content, names, function(selected)
		activeTab = selected
		for name, page in pairs(pages) do
			page.Visible = name == selected
		end
		refresh()
	end, Theme.Colors.Orange)
	buildQuests(pages.Quests)
	buildDaily(pages.Daily)
	buildPlaytime(pages.Playtime)
	buildAchievements(pages.Achievements)
	tabs.Select("Quests")

	controllers.UIController.RegisterPanel("Quests", { Window = window, OnOpen = refresh })
end

function QuestsPanel.Start()
	for _, key in ipairs({ "Quests", "Daily", "PlaytimeSession", "Achievements", "Stats", "Discovered", "Zones" }) do
		State.Watch(key, function()
			refresh()
			refreshBadge()
		end)
	end
	-- Timers (playtime, resets) update once per second only while relevant.
	task.spawn(function()
		while true do
			task.wait(1)
			if window.Visible and (activeTab == "Playtime" or activeTab == "Quests" or activeTab == "Daily") then
				refresh()
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(10)
			refreshBadge()
		end
	end)
	-- Show the daily reward on join if it's claimable.
	State.OnLoaded(function(data)
		task.wait(2)
		if dailyState(data) then
			Controllers.UIController.Open("Quests")
			tabs.Select("Daily")
		end
	end)
end

return QuestsPanel
