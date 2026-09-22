-- Owns all player save data (inventory + equipped loadout) and DataStore persistence.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local DataService = {}

-- Wrap in pcall so unpublished Studio playtests don't crash (DataStore is
-- only available in published games or Studio with API access enabled).
local ok, storeResult = pcall(function()
	return DataStoreService:GetDataStore("SpinABrainrot_PlayerData_v1")
end)
local store = ok and storeResult
	or {
		GetAsync = function()
			return nil
		end,
		SetAsync = function() end,
	}
local cache = {} -- [player] = { Inventory = {[brainrotId]=count}, Equipped = {brainrotId, ...} }

local function defaultData()
	return { Inventory = {}, Equipped = {} }
end

local function load(player)
	local key = "Player_" .. player.UserId
	local ok, result = pcall(function()
		return store:GetAsync(key)
	end)

	if ok and result then
		result.Inventory = result.Inventory or {}
		result.Equipped = result.Equipped or {}
		cache[player] = result
	else
		cache[player] = defaultData()
	end

	return cache[player]
end

local function save(player)
	local data = cache[player]
	if not data then
		return
	end
	local key = "Player_" .. player.UserId
	pcall(function()
		store:SetAsync(key, data)
	end)
end

function DataService.Get(player)
	return cache[player]
end

function DataService.AddBrainrot(player, brainrotId)
	local data = cache[player]
	if not data then
		return
	end
	data.Inventory[brainrotId] = (data.Inventory[brainrotId] or 0) + 1
end

function DataService.SetEquipped(player, equippedIds)
	local data = cache[player]
	if not data then
		return
	end
	data.Equipped = equippedIds
end

function DataService.Init()
	Players.PlayerAdded:Connect(load)

	Players.PlayerRemoving:Connect(function(player)
		save(player)
		cache[player] = nil
	end)

	game:BindToClose(function()
		for player in pairs(cache) do
			save(player)
		end
	end)

	-- Players who joined before this script ran (e.g. Studio "Run" edge cases).
	for _, player in ipairs(Players:GetPlayers()) do
		if not cache[player] then
			load(player)
		end
	end
end

DataService.Save = save
DataService.Load = load

return DataService
