--[[
	LootService
	-----------
	Server-side random loot generation. The client never sees the RNG and never
	tells us what it found — it only receives the result.

	RollItem(poolName, luck, minRarityOrder)
	  1. Rarity weights are scaled by luck (Formulas.GetRarityWeights).
	  2. A rarity is chosen by weighted random.
	  3. A random item of that rarity is chosen from the pool. If a pool has no
	     item of that rarity, we step down until we find one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)

local LootService = {}

local rng = Random.new()

function LootService.RollRarity(luck, minRarityOrder)
	local weights, total = Formulas.GetRarityWeights(luck, minRarityOrder)
	local roll = rng:NextNumber() * total
	for _, entry in ipairs(weights) do
		roll -= entry.Weight
		if roll <= 0 and entry.Weight > 0 then
			return entry.Name
		end
	end
	-- Floating point edge case: return the best rarity with weight.
	for i = #weights, 1, -1 do
		if weights[i].Weight > 0 then
			return weights[i].Name
		end
	end
	return Config.Rarities[1].Name
end

function LootService.RollItem(poolName, luck, minRarityOrder)
	local rarityName = LootService.RollRarity(luck or 1, minRarityOrder)
	local order = Config.RarityByName[rarityName].Order
	for o = order, 1, -1 do
		local list = Items.GetPoolRarity(poolName, Config.Rarities[o].Name)
		if list and #list > 0 then
			return list[rng:NextInteger(1, #list)]
		end
	end
	error("[LootService] Pool " .. tostring(poolName) .. " has no items")
end

function LootService.Init()
	-- Validate every zone pool covers all rarities (warn only).
	for _, zone in ipairs(Config.Zones) do
		for _, rarity in ipairs(Config.Rarities) do
			local list = Items.GetPoolRarity(zone.Pool, rarity.Name)
			if not list or #list == 0 then
				warn(("[LootService] Pool %s has no %s items"):format(zone.Pool, rarity.Name))
			end
		end
	end
end

function LootService.Start() end

return LootService
