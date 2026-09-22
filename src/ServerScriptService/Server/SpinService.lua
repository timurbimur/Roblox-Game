-- Server-authoritative spin/equip logic, exposed as RemoteFunctions so every
-- client call gets an explicit response or an explicit error -- there is no
-- "fire and hope" path that can silently do nothing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RarityConfig = require(ReplicatedStorage.Modules.RarityConfig)
local BrainrotConfig = require(ReplicatedStorage.Modules.BrainrotConfig)
local DataService = require(script.Parent.DataService)
local EquipService = require(script.Parent.EquipService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpinFunction = Remotes:WaitForChild("SpinFunction")
local EquipFunction = Remotes:WaitForChild("EquipFunction")
local UnequipFunction = Remotes:WaitForChild("UnequipFunction")
local InventoryUpdated = Remotes:WaitForChild("InventoryUpdated")

local SpinService = {}

local SPIN_COOLDOWN = 3
local lastSpinAt = {} -- [player] = os.clock()
local rng = Random.new()

-- DataService loads asynchronously (a DataStore call) on its own PlayerAdded
-- connection, so any handler here may run before it's populated.
local function waitForData(player, timeout)
	local start = os.clock()
	local data = DataService.Get(player)
	while not data and os.clock() - start < (timeout or 5) and player.Parent do
		task.wait(0.1)
		data = DataService.Get(player)
	end
	return data
end

local function rollRarity()
	local roll = rng:NextInteger(1, RarityConfig.TotalWeight)
	local cumulative = 0
	for _, rarityName in ipairs(RarityConfig.Order) do
		cumulative += RarityConfig.Rarities[rarityName].Weight
		if roll <= cumulative then
			return rarityName
		end
	end
	return RarityConfig.Order[#RarityConfig.Order]
end

local function rollBrainrot(rarityName)
	local pool = BrainrotConfig.ByRarity[rarityName]
	if not pool or #pool == 0 then
		return nil
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function sendInventory(player)
	local data = DataService.Get(player)
	if not data then
		return
	end
	InventoryUpdated:FireClient(player, data.Inventory, data.Equipped)
end

local function onSpin(player)
	local now = os.clock()
	local last = lastSpinAt[player]
	if last and now - last < SPIN_COOLDOWN then
		return {
			Success = false,
			Reason = "Cooldown",
			CooldownRemaining = SPIN_COOLDOWN - (now - last),
		}
	end

	local data = waitForData(player)
	if not data then
		return {
			Success = false,
			Reason = "NotLoaded",
			Detail = "Save data never finished loading (DataStore call pending or failing).",
		}
	end

	local rarityName = rollRarity()
	local brainrot = rollBrainrot(rarityName)
	if not brainrot then
		return {
			Success = false,
			Reason = "ServerError",
			Detail = "No brainrots configured for rarity '" .. tostring(rarityName) .. "' in BrainrotConfig.ByRarity.",
		}
	end

	lastSpinAt[player] = now
	DataService.AddBrainrot(player, brainrot.Id)
	sendInventory(player)

	return {
		Success = true,
		BrainrotId = brainrot.Id,
		Name = brainrot.Name,
		Rarity = rarityName,
		Inventory = data.Inventory,
		Equipped = data.Equipped,
	}
end

local function onEquip(player, brainrotId)
	if typeof(brainrotId) ~= "string" then
		return { Success = false, Reason = "BadRequest" }
	end

	local data = waitForData(player)
	if not data then
		return { Success = false, Reason = "NotLoaded" }
	end
	if not data.Inventory[brainrotId] or data.Inventory[brainrotId] <= 0 then
		return { Success = false, Reason = "NotOwned" }
	end
	if table.find(data.Equipped, brainrotId) then
		return { Success = false, Reason = "AlreadyEquipped" }
	end
	if #data.Equipped >= EquipService.MaxSlots then
		return { Success = false, Reason = "SlotsFull" }
	end

	table.insert(data.Equipped, brainrotId)
	DataService.SetEquipped(player, data.Equipped)
	EquipService.Refresh(player, data.Equipped)

	return { Success = true, Inventory = data.Inventory, Equipped = data.Equipped }
end

local function onUnequip(player, brainrotId)
	if typeof(brainrotId) ~= "string" then
		return { Success = false, Reason = "BadRequest" }
	end

	local data = waitForData(player)
	if not data then
		return { Success = false, Reason = "NotLoaded" }
	end

	local index = table.find(data.Equipped, brainrotId)
	if not index then
		return { Success = false, Reason = "NotEquipped" }
	end

	table.remove(data.Equipped, index)
	DataService.SetEquipped(player, data.Equipped)
	EquipService.Refresh(player, data.Equipped)

	return { Success = true, Inventory = data.Inventory, Equipped = data.Equipped }
end

-- Wraps a handler so an internal bug returns a structured error instead of
-- an opaque "server is not responding" on the client.
local function safe(handler)
	return function(player, ...)
		local ok, result = pcall(handler, player, ...)
		if ok then
			return result
		end
		warn("[SpinService] handler error for " .. player.Name .. ": " .. tostring(result))
		return { Success = false, Reason = "ServerError", Detail = tostring(result) }
	end
end

function SpinService.Init()
	SpinFunction.OnServerInvoke = safe(onSpin)
	EquipFunction.OnServerInvoke = safe(onEquip)
	UnequipFunction.OnServerInvoke = safe(onUnequip)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			waitForData(player)
			sendInventory(player)
		end)

		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			local data = DataService.Get(player)
			if data then
				EquipService.Refresh(player, data.Equipped)
			end
		end)
	end)
end

return SpinService
