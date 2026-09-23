--[[
	EconomyService
	--------------
	Cash, selling, and upgrades. All values are computed server-side from the
	item database and the player's server-held data. The client can only ASK to
	sell/buy; it never supplies prices or balances.

	Selling rules
	  * Must be standing near a Sell Station.
	  * Favorited items are NEVER sold (Sell Selected / All / Duplicates / Auto).
	  * Sell Duplicates keeps exactly one of every item.

	Auto Sell
	  * When enabled (setting) and the Auto Sell level covers an item's rarity,
	    ALREADY-DISCOVERED finds are sold instantly instead of taking space.
	  * When the backpack is full, auto-sell clears eligible stacks to make room.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local EconomyService = {}

local Services

-- ============================================================================
-- CASH
-- ============================================================================

-- Adds cash. opts.ApplyMultiplier applies 2x Cash passes/boosts.
-- Returns the final amount added.
function EconomyService.AddCash(profile, amount, opts)
	amount = tonumber(amount) or 0
	if amount <= 0 or amount ~= amount then
		return 0
	end
	if opts and opts.ApplyMultiplier then
		amount *= Formulas.GetCashMultiplier(profile.Data, profile.Passes)
	end
	amount = math.floor(amount)
	local data = profile.Data
	data.Cash += amount
	data.Stats.CashEarned += amount
	Services.DataService.MarkDirty(profile.Player, "Cash")
	Services.DataService.MarkDirty(profile.Player, "Stats")
	Services.QuestService.Increment(profile, "EarnCash", amount)
	Services.AchievementService.QueueCheck(profile)
	return amount
end

function EconomyService.SpendCash(profile, amount)
	amount = math.floor(tonumber(amount) or 0)
	if amount < 0 or profile.Data.Cash < amount then
		return false
	end
	profile.Data.Cash -= amount
	Services.DataService.MarkDirty(profile.Player, "Cash")
	return true
end

-- ============================================================================
-- SELLING
-- ============================================================================

-- Sells a batch { [itemId] = count }. Assumes counts were validated.
-- Returns cash earned, items sold.
local function sellBatch(profile, batch)
	local baseValue, sold = 0, 0
	for itemId, count in pairs(batch) do
		local item = Items.ById[itemId]
		if item and count > 0 and Services.InventoryService.RemoveItem(profile, itemId, count) then
			baseValue += item.Value * count
			sold += count
		end
	end
	if sold == 0 then
		return 0, 0
	end
	local earned = EconomyService.AddCash(profile, baseValue, { ApplyMultiplier = true })
	profile.Data.Stats.ItemsSold += sold
	Services.QuestService.Increment(profile, "Sell", sold)
	return earned, sold
end

-- Instant auto-sell of a fresh find. Returns earned cash or nil if not eligible.
function EconomyService.TryAutoSellFind(profile, itemId)
	local data = profile.Data
	local item = Items.ById[itemId]
	if not item or not data.Settings.AutoSell then
		return nil
	end
	local level = Formulas.GetAutoSellLevel(data, profile.Passes)
	if level < item.RarityOrder or not data.Discovered[itemId] or data.Favorites[itemId] then
		return nil
	end
	local earned = EconomyService.AddCash(profile, item.Value, { ApplyMultiplier = true })
	data.Stats.ItemsSold += 1
	Services.QuestService.Increment(profile, "Sell", 1)
	return earned
end

-- Frees space when full by selling every eligible (non-favorite) stack.
function EconomyService.AutoSellInventory(profile)
	local data = profile.Data
	if not data.Settings.AutoSell then
		return 0, 0
	end
	local level = Formulas.GetAutoSellLevel(data, profile.Passes)
	if level <= 0 then
		return 0, 0
	end
	local batch = {}
	for itemId, count in pairs(data.Inventory) do
		local item = Items.ById[itemId]
		if item and item.RarityOrder <= level and not data.Favorites[itemId] then
			batch[itemId] = count
		end
	end
	return sellBatch(profile, batch)
end

local function handleSell(profile, payload)
	if type(payload) ~= "table" or type(payload.Mode) ~= "string" then
		return false, "Bad request."
	end
	if not Services.WorldService.IsNearStation(profile.Player, "SellStation", Config.SellStationRange) then
		return false, "Walk to a Sell Station first!"
	end

	local data = profile.Data
	local batch = {}
	local mode = payload.Mode

	if mode == "All" then
		for itemId, count in pairs(data.Inventory) do
			if not data.Favorites[itemId] then
				batch[itemId] = count
			end
		end
	elseif mode == "Duplicates" then
		for itemId, count in pairs(data.Inventory) do
			if not data.Favorites[itemId] and count > 1 then
				batch[itemId] = count - 1
			end
		end
	elseif mode == "Selected" then
		if type(payload.Items) ~= "table" then
			return false, "Nothing selected."
		end
		local entries = 0
		for itemId, count in pairs(payload.Items) do
			entries += 1
			if entries > 500 then
				break
			end
			-- Validate every client-supplied value.
			if Items.IsValid(itemId) and type(count) == "number" and count == count and not data.Favorites[itemId] then
				local owned = data.Inventory[itemId] or 0
				local amount = math.clamp(math.floor(count), 0, owned)
				if amount > 0 then
					batch[itemId] = amount
				end
			end
		end
	else
		return false, "Unknown sell mode."
	end

	local earned, sold = sellBatch(profile, batch)
	if sold == 0 then
		return false, "Nothing to sell (favorites are protected)."
	end
	Remotes.Signal:FireClient(profile.Player, "Sold", { Cash = earned, Count = sold })
	return true, { Cash = earned, Count = sold }
end

-- ============================================================================
-- UPGRADES
-- ============================================================================
local function handleBuyUpgrade(profile, payload)
	local upgradeId = type(payload) == "table" and payload.Id
	local def = type(upgradeId) == "string" and Config.UpgradeById[upgradeId]
	if not def then
		return false, "Invalid upgrade."
	end
	local data = profile.Data
	local level = data.Upgrades[upgradeId] or 0
	local cost = Formulas.GetUpgradeCost(upgradeId, level)
	if not cost then
		return false, "Already maxed!"
	end
	if not EconomyService.SpendCash(profile, cost) then
		return false, "Not enough cash! Need " .. Util.FormatCash(cost)
	end
	data.Upgrades[upgradeId] = level + 1
	Services.DataService.MarkDirty(profile.Player, "Upgrades")
	return true, level + 1
end

function EconomyService.Init(services)
	Services = services
end

function EconomyService.Start()
	Services.Router.Register("Sell", handleSell)
	Services.Router.Register("BuyUpgrade", handleBuyUpgrade)
end

return EconomyService
