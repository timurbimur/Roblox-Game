--[[
	Achievements
	------------
	Permanent milestones auto-granted by the server when a tracked stat reaches
	its target. Stat names map to fields in PlayerData.Stats, plus two derived
	stats computed by AchievementService:
	  Discoveries        number of discovered items
	  CollectionPercent  0-100 collection completion
	  ZonesUnlocked      highest unlocked zone id
]]

local Achievements = {
	{ Id = "search_10", Name = "First Dig", Stat = "Searches", Target = 10, Reward = { Cash = 100 } },
	{ Id = "search_500", Name = "Trash Panda", Stat = "Searches", Target = 500, Reward = { Cash = 5000 } },
	{ Id = "search_5000", Name = "Dumpster Veteran", Stat = "Searches", Target = 5000, Reward = { Boost = { Id = "Luck2x", Duration = 1800 } } },
	{ Id = "search_50000", Name = "Bin Legend", Stat = "Searches", Target = 50000, Reward = { Boost = { Id = "Luck2x", Duration = 7200 } } },

	{ Id = "fuse_1", Name = "It's Alive!", Stat = "Fusions", Target = 1, Reward = { Cash = 150 } },
	{ Id = "fuse_100", Name = "Lab Rat", Stat = "Fusions", Target = 100, Reward = { Cash = 10000 } },
	{ Id = "fuse_1000", Name = "Frankenstein", Stat = "Fusions", Target = 1000, Reward = { Boost = { Id = "FusionSpeed", Duration = 3600 } } },

	{ Id = "sell_1000", Name = "Salesman", Stat = "ItemsSold", Target = 1000, Reward = { Cash = 8000 } },
	{ Id = "cash_1m", Name = "Millionaire", Stat = "CashEarned", Target = 1000000, Reward = { Boost = { Id = "Cash2x", Duration = 1800 } } },
	{ Id = "cash_1b", Name = "Billionaire", Stat = "CashEarned", Target = 1000000000, Reward = { Boost = { Id = "Cash2x", Duration = 7200 } } },

	{ Id = "legendary_1", Name = "Legendary!", Stat = "LegendaryFinds", Target = 1, Reward = { Cash = 1000 } },
	{ Id = "mythic_1", Name = "Myth Buster", Stat = "MythicFinds", Target = 1, Reward = { Boost = { Id = "Luck2x", Duration = 900 } } },
	{ Id = "secret_1", Name = "Top Secret", Stat = "SecretFinds", Target = 1, Reward = { Boost = { Id = "Luck2x", Duration = 3600 } } },

	{ Id = "zone_3", Name = "Downtown Diver", Stat = "ZonesUnlocked", Target = 3, Reward = { Cash = 50000 } },
	{ Id = "zone_6", Name = "Island Owner", Stat = "ZonesUnlocked", Target = 6, Reward = { Boost = { Id = "Luck2x", Duration = 7200 } } },

	-- Collection completion
	{ Id = "collection_10", Name = "Curious", Stat = "CollectionPercent", Target = 10, Reward = { Cash = 500 } },
	{ Id = "collection_25", Name = "Collector", Stat = "CollectionPercent", Target = 25, Reward = { Boost = { Id = "Luck2x", Duration = 900 } } },
	{ Id = "collection_50", Name = "Archivist", Stat = "CollectionPercent", Target = 50, Reward = { Boost = { Id = "Cash2x", Duration = 3600 } } },
	{ Id = "collection_75", Name = "Museum Curator", Stat = "CollectionPercent", Target = 75, Reward = { Boost = { Id = "Luck2x", Duration = 7200 } } },
	{ Id = "collection_100", Name = "Completionist", Stat = "CollectionPercent", Target = 100, Reward = { Cash = 1000000000 } },
}

Achievements.ById = {}
for _, achievement in ipairs(Achievements) do
	Achievements.ById[achievement.Id] = achievement
end

return Achievements
