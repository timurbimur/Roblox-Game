--[[
	Formulas
	--------
	Pure progression math shared by server and client. The SERVER uses these to
	apply real effects; the CLIENT uses the exact same functions to preview
	numbers in the UI, so displays never drift from reality.

	`data`   = player save table (Upgrades, Boosts, Zones, ...)
	`passes` = { [passName] = true } owned gamepasses (session state)
]]

local Config = require(script.Parent.Config)

local Formulas = {}

local function upgradeLevel(data, id)
	return (data and data.Upgrades and data.Upgrades[id]) or 0
end

local function boostActive(data, id)
	return data and data.Boosts and (data.Boosts[id] or 0) > 0
end
Formulas.IsBoostActive = boostActive

-- Cost to buy the NEXT level of an upgrade, or nil if maxed.
function Formulas.GetUpgradeCost(upgradeId, currentLevel)
	local upgrade = Config.UpgradeById[upgradeId]
	if not upgrade or currentLevel >= upgrade.MaxLevel then
		return nil
	end
	if upgradeId == "Backpack" then
		local tier = Config.BackpackTiers[currentLevel + 2]
		return tier and tier.Cost
	end
	return math.floor(upgrade.BaseCost * upgrade.Growth ^ currentLevel)
end

function Formulas.GetCapacity(data, passes)
	if passes and passes.InfiniteInventory then
		return Config.InfiniteCapacity
	end
	local tier = Config.BackpackTiers[upgradeLevel(data, "Backpack") + 1]
	return tier and tier.Capacity or Config.BackpackTiers[1].Capacity
end

function Formulas.GetLuck(data, passes)
	local luck = 1 + upgradeLevel(data, "Luck") * Config.UpgradeById.Luck.PerLevel
	if passes and passes.VIP then
		luck *= Config.VIP.LuckMultiplier
	end
	if passes and passes.Luck2x then
		luck *= 2
	end
	if boostActive(data, "Luck2x") then
		luck *= 2
	end
	return luck
end

function Formulas.GetCashMultiplier(data, passes)
	local mult = 1
	if passes and passes.Cash2x then
		mult *= 2
	end
	if boostActive(data, "Cash2x") then
		mult *= 2
	end
	return mult
end

function Formulas.GetHoldDuration(data)
	local reduction = upgradeLevel(data, "DumpsterSpeed") * Config.UpgradeById.DumpsterSpeed.PerLevel
	return math.max(Config.Search.MinHoldDuration, Config.Search.HoldDuration * (1 - reduction))
end

function Formulas.GetCooldown(data)
	local cooldown = Config.Search.Cooldown
	if boostActive(data, "CooldownReduction") then
		cooldown *= 0.5
	end
	return cooldown
end

function Formulas.GetFusionDuration(data, passes)
	if passes and passes.FusionMaster then
		return Config.Fusion.FusionMasterDuration
	end
	local reduction = upgradeLevel(data, "FusionSpeed") * Config.UpgradeById.FusionSpeed.PerLevel
	local duration = Config.Fusion.BaseDuration * (1 - reduction)
	if boostActive(data, "FusionSpeed") then
		duration *= 0.5
	end
	return math.max(Config.Fusion.MinDuration, duration)
end

-- Highest rarity order that Auto Sell is allowed to sell (0 = disabled).
function Formulas.GetAutoSellLevel(data, passes)
	local level = upgradeLevel(data, "AutoSell")
	if passes and passes.AutoSell then
		level = math.max(level, Config.UpgradeById.AutoSell.MaxLevel)
	end
	return level
end

-- Returns range, interval for Auto Collect (nil if not owned).
function Formulas.GetAutoCollect(data)
	local level = upgradeLevel(data, "AutoCollect")
	if level <= 0 then
		return nil
	end
	local def = Config.UpgradeById.AutoCollect
	return def.BaseRange + def.RangePerLevel * (level - 1), def.BaseInterval - def.IntervalPerLevel * (level - 1)
end

function Formulas.GetHighestZone(data)
	local highest = 0
	if data and data.Zones then
		for zoneKey, owned in pairs(data.Zones) do
			local id = tonumber(zoneKey)
			if owned and id and id > highest then
				highest = id
			end
		end
	end
	return highest
end

-- Cash rewards (quests, daily, packs) scale with the best zone's multiplier.
function Formulas.GetZoneScale(data)
	local zone = Config.ZoneById[Formulas.GetHighestZone(data)]
	return zone and zone.ValueMultiplier or 1
end

-- Rarity weights after luck. Returns { {Name, Weight}, ... } and total.
function Formulas.GetRarityWeights(luck, minRarityOrder)
	local weights, total = {}, 0
	for _, rarity in ipairs(Config.Rarities) do
		local weight = 0
		if not minRarityOrder or rarity.Order >= minRarityOrder then
			weight = rarity.Weight * (1 + (luck - 1) * rarity.LuckScale)
		end
		total += weight
		table.insert(weights, { Name = rarity.Name, Weight = weight })
	end
	return weights, total
end

-- Percent chance per rarity for UI display.
function Formulas.GetOddsPercent(luck)
	local weights, total = Formulas.GetRarityWeights(luck)
	local odds = {}
	for _, entry in ipairs(weights) do
		odds[entry.Name] = total > 0 and (entry.Weight / total * 100) or 0
	end
	return odds
end

return Formulas
