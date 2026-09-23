--[[
	Quests (Quest Database)
	-----------------------
	Three quest categories:
	  Main    - linear story chain, one active at a time (teaches the loop)
	  Daily   - 3 random quests from the Daily pool, reroll each UTC day
	  Weekly  - 3 random quests from the Weekly pool, reroll each UTC week

	Quest Types (the server's QuestService increments these on game events):
	  Search       searched N dumpsters
	  Discover     made N brand-new discoveries
	  Fuse         completed N fusions
	  Sell         sold N items
	  EarnCash     earned N cash (from any source)
	  FindRarity   found N items of rarity >= Rarity
	  UnlockZone   own the zone with Id >= Target (absolute, not incremental)

	Rewards:
	  Cash          number (multiplied by the player's zone scale if ScaleCash)
	  Boost         { Id = <Config.Boosts key>, Duration = seconds }
	  Item          item id granted to the backpack
]]

local Quests = {}

Quests.Main = {
	{ Id = "main_1", Title = "Dumpster Diver", Type = "Search", Target = 5, Reward = { Cash = 100 } },
	{ Id = "main_2", Title = "Fresh Finds", Type = "Discover", Target = 3, Reward = { Cash = 200 } },
	{ Id = "main_3", Title = "Mad Scientist", Type = "Fuse", Target = 1, Reward = { Cash = 250, Boost = { Id = "Luck2x", Duration = 300 } } },
	{ Id = "main_4", Title = "Junk Dealer", Type = "Sell", Target = 20, Reward = { Cash = 400 } },
	{ Id = "main_5", Title = "Search 20 Dumpsters", Type = "Search", Target = 20, Reward = { Cash = 600 } },
	{ Id = "main_6", Title = "Fuse 5 Items", Type = "Fuse", Target = 5, Reward = { Item = "exclusive_rookie_trophy" } },
	{ Id = "main_7", Title = "Moving Up", Type = "UnlockZone", Target = 1, Reward = { Cash = 1500 } },
	{ Id = "main_8", Title = "Collector", Type = "Discover", Target = 20, Reward = { Boost = { Id = "Cash2x", Duration = 600 } } },
	{ Id = "main_9", Title = "Rare Taste", Type = "FindRarity", Rarity = "Epic", Target = 3, Reward = { Cash = 8000 } },
	{ Id = "main_10", Title = "White Picket Fence", Type = "UnlockZone", Target = 2, Reward = { Cash = 20000 } },
	{ Id = "main_11", Title = "Fusion Addict", Type = "Fuse", Target = 50, Reward = { Boost = { Id = "FusionSpeed", Duration = 1200 } } },
	{ Id = "main_12", Title = "City Slicker", Type = "UnlockZone", Target = 3, Reward = { Cash = 250000 } },
	{ Id = "main_13", Title = "Legend Hunter", Type = "FindRarity", Rarity = "Legendary", Target = 5, Reward = { Boost = { Id = "Luck2x", Duration = 1800 } } },
	{ Id = "main_14", Title = "High Society", Type = "UnlockZone", Target = 4, Reward = { Cash = 3000000 } },
	{ Id = "main_15", Title = "Encyclopedia", Type = "Discover", Target = 80, Reward = { Cash = 10000000 } },
	{ Id = "main_16", Title = "Walk of Fame", Type = "UnlockZone", Target = 5, Reward = { Cash = 40000000 } },
	{ Id = "main_17", Title = "Mythic Hoarder", Type = "FindRarity", Rarity = "Mythic", Target = 3, Reward = { Boost = { Id = "Luck2x", Duration = 3600 } } },
	{ Id = "main_18", Title = "Island Life", Type = "UnlockZone", Target = 6, Reward = { Item = "exclusive_golden_dumpster" } },
}

Quests.Daily = {
	{ Id = "daily_search_50", Title = "Search 50 Dumpsters", Type = "Search", Target = 50, Reward = { Cash = 1500, ScaleCash = true } },
	{ Id = "daily_search_150", Title = "Search 150 Dumpsters", Type = "Search", Target = 150, Reward = { Boost = { Id = "CooldownReduction", Duration = 900 } } },
	{ Id = "daily_fuse_10", Title = "Fuse 10 Items", Type = "Fuse", Target = 10, Reward = { Cash = 2000, ScaleCash = true } },
	{ Id = "daily_fuse_25", Title = "Fuse 25 Items", Type = "Fuse", Target = 25, Reward = { Boost = { Id = "FusionSpeed", Duration = 900 } } },
	{ Id = "daily_discover_3", Title = "Discover 3 New Items", Type = "Discover", Target = 3, Reward = { Boost = { Id = "Luck2x", Duration = 600 } } },
	{ Id = "daily_sell_100", Title = "Sell 100 Items", Type = "Sell", Target = 100, Reward = { Cash = 2500, ScaleCash = true } },
	{ Id = "daily_earn", Title = "Earn 10K Cash", Type = "EarnCash", Target = 10000, Reward = { Boost = { Id = "Cash2x", Duration = 600 } } },
	{ Id = "daily_rare_5", Title = "Find 5 Rare+ Items", Type = "FindRarity", Rarity = "Rare", Target = 5, Reward = { Cash = 2000, ScaleCash = true } },
	{ Id = "daily_epic_1", Title = "Find an Epic+ Item", Type = "FindRarity", Rarity = "Epic", Target = 1, Reward = { Boost = { Id = "Luck2x", Duration = 900 } } },
}

Quests.Weekly = {
	{ Id = "weekly_search_1000", Title = "Search 1,000 Dumpsters", Type = "Search", Target = 1000, Reward = { Cash = 25000, ScaleCash = true, Boost = { Id = "Luck2x", Duration = 3600 } } },
	{ Id = "weekly_fuse_200", Title = "Fuse 200 Items", Type = "Fuse", Target = 200, Reward = { Boost = { Id = "FusionSpeed", Duration = 3600 } } },
	{ Id = "weekly_discover_15", Title = "Discover 15 New Items", Type = "Discover", Target = 15, Reward = { Item = "exclusive_quest_medal" } },
	{ Id = "weekly_legendary_3", Title = "Find 3 Legendary+ Items", Type = "FindRarity", Rarity = "Legendary", Target = 3, Reward = { Cash = 40000, ScaleCash = true } },
	{ Id = "weekly_sell_1500", Title = "Sell 1,500 Items", Type = "Sell", Target = 1500, Reward = { Boost = { Id = "Cash2x", Duration = 3600 } } },
	{ Id = "weekly_earn", Title = "Earn 500K Cash", Type = "EarnCash", Target = 500000, Reward = { Cash = 50000, ScaleCash = true } },
}

Quests.DailyCount = 3
Quests.WeeklyCount = 3

-- Index every quest by Id for O(1) lookup.
Quests.ById = {}
for _, category in ipairs({ "Main", "Daily", "Weekly" }) do
	for index, quest in ipairs(Quests[category]) do
		quest.Category = category
		quest.Index = index
		assert(not Quests.ById[quest.Id], "Duplicate quest id " .. quest.Id)
		Quests.ById[quest.Id] = quest
	end
end

return Quests
