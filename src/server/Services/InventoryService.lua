--[[
	InventoryService
	----------------
	The ONLY code allowed to add/remove items. Handles:
	  * stack counts + capacity
	  * discoveries (Collection book) and discovery stats
	  * rarity stats + rare-find announcements
	  * favorites and player settings (UI requests)

	Inventory is stored as stacks: Inventory[itemId] = count. Capacity limits the
	TOTAL number of items (sum of counts), just like a real backpack.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)

local InventoryService = {}

local Services

local ANNOUNCE_ORDER = Config.RarityByName[Config.AnnounceMinRarity].Order

function InventoryService.GetCount(profile, itemId)
	return profile.Data.Inventory[itemId] or 0
end

function InventoryService.GetTotal(profile)
	local total = 0
	for _, count in pairs(profile.Data.Inventory) do
		total += count
	end
	return total
end

function InventoryService.GetCapacity(profile)
	return Formulas.GetCapacity(profile.Data, profile.Passes)
end

function InventoryService.HasSpace(profile, amount)
	return InventoryService.GetTotal(profile) + (amount or 1) <= InventoryService.GetCapacity(profile)
end

-- Marks an item as discovered. Returns true if it was new.
function InventoryService.Discover(profile, itemId)
	local data = profile.Data
	if data.Discovered[itemId] then
		return false
	end
	data.Discovered[itemId] = os.time()
	Services.DataService.MarkDirty(profile.Player, "Discovered")
	Services.QuestService.Increment(profile, "Discover", 1)
	Services.AchievementService.QueueCheck(profile)
	return true
end

--[[
	Adds items. Capacity is NOT enforced here (callers decide whether rewards may
	overflow). `source` is used for stats/announcements:
	"Dumpster" | "Fusion" | "Reward" | "Purchase"
	Returns isNewDiscovery.
]]
function InventoryService.AddItem(profile, itemId, count, source)
	local item = Items.ById[itemId]
	if not item then
		warn("[InventoryService] Tried to add unknown item " .. tostring(itemId))
		return false
	end
	count = math.max(1, math.floor(count or 1))
	local data = profile.Data

	data.Inventory[itemId] = (data.Inventory[itemId] or 0) + count
	Services.DataService.MarkDirty(profile.Player, "Inventory")

	local isNew = InventoryService.Discover(profile, itemId)
	InventoryService.RecordFind(profile, item, isNew, source)
	return isNew
end

-- Stats, quest progress, and announcements for any obtained item (also used
-- for auto-sold finds, which never touch the inventory).
function InventoryService.RecordFind(profile, item, isNew, source)
	local data = profile.Data
	if source == "Dumpster" or source == "Fusion" then
		Services.QuestService.Increment(profile, "FindRarity", 1, item.RarityOrder)
		if item.Rarity == "Legendary" then
			data.Stats.LegendaryFinds += 1
		elseif item.Rarity == "Mythic" then
			data.Stats.MythicFinds += 1
		elseif item.Rarity == "Secret" then
			data.Stats.SecretFinds += 1
		end
		Services.DataService.MarkDirty(profile.Player, "Stats")
		Services.AchievementService.QueueCheck(profile)
	end
	if item.RarityOrder >= ANNOUNCE_ORDER and source ~= "Purchase" then
		Services.AnnouncementService.AnnounceFind(profile.Player, item.Id, isNew)
	end
end

-- Removes items. Returns true on success (false if not enough).
function InventoryService.RemoveItem(profile, itemId, count)
	count = math.floor(count or 1)
	local inventory = profile.Data.Inventory
	local owned = inventory[itemId] or 0
	if count <= 0 or owned < count then
		return false
	end
	local remaining = owned - count
	inventory[itemId] = remaining > 0 and remaining or nil
	Services.DataService.MarkDirty(profile.Player, "Inventory")
	return true
end

-- ============================================================================
-- REQUEST HANDLERS
-- ============================================================================
local function handleToggleFavorite(profile, payload)
	local itemId = type(payload) == "table" and payload.ItemId
	if not Items.IsValid(itemId) then
		return false, "Invalid item."
	end
	local favorites = profile.Data.Favorites
	if favorites[itemId] then
		favorites[itemId] = nil
	else
		if not profile.Data.Discovered[itemId] then
			return false, "You haven't discovered that item yet."
		end
		favorites[itemId] = true
	end
	Services.DataService.MarkDirty(profile.Player, "Favorites")
	return true, favorites[itemId] == true
end

local function handleSetSetting(profile, payload)
	if type(payload) ~= "table" then
		return false, "Bad request."
	end
	local key, value = payload.Key, payload.Value
	local settings = profile.Data.Settings
	if type(key) ~= "string" or type(value) ~= "boolean" or type(Services.DataService.Template.Settings[key]) ~= "boolean" then
		return false, "Invalid setting."
	end
	settings[key] = value
	Services.DataService.MarkDirty(profile.Player, "Settings")
	return true
end

local function handleCompleteTutorial(profile)
	if not profile.Data.TutorialDone then
		profile.Data.TutorialDone = true
		Services.DataService.MarkDirty(profile.Player, "TutorialDone")
	end
	return true
end

function InventoryService.Init(services)
	Services = services
end

function InventoryService.Start()
	local Router = Services.Router
	Router.Register("ToggleFavorite", handleToggleFavorite)
	Router.Register("SetSetting", handleSetSetting)
	Router.Register("CompleteTutorial", handleCompleteTutorial)
end

return InventoryService
