-- Single source of truth for rarity tiers, their odds, and their display color.
-- Edit Weight values to rebalance odds; percentages are derived automatically.

local RarityConfig = {}

RarityConfig.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

RarityConfig.Rarities = {
	Common = { Weight = 5000, Color = Color3.fromRGB(174, 174, 174), DisplayName = "Common" },
	Uncommon = { Weight = 2500, Color = Color3.fromRGB(85, 205, 100), DisplayName = "Uncommon" },
	Rare = { Weight = 1500, Color = Color3.fromRGB(75, 150, 255), DisplayName = "Rare" },
	Epic = { Weight = 600, Color = Color3.fromRGB(180, 80, 255), DisplayName = "Epic" },
	Legendary = { Weight = 300, Color = Color3.fromRGB(255, 170, 30), DisplayName = "Legendary" },
	Mythic = { Weight = 90, Color = Color3.fromRGB(255, 60, 60), DisplayName = "Mythic" },
	Secret = { Weight = 10, Color = Color3.fromRGB(255, 0, 200), DisplayName = "Secret" },
}

local totalWeight = 0
for _, rarityName in ipairs(RarityConfig.Order) do
	totalWeight += RarityConfig.Rarities[rarityName].Weight
end
RarityConfig.TotalWeight = totalWeight

function RarityConfig.GetPercent(rarityName)
	local data = RarityConfig.Rarities[rarityName]
	if not data then
		return 0
	end
	return (data.Weight / totalWeight) * 100
end

return RarityConfig
