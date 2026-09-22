-- Server-authoritative spin/roll logic. The client only ever asks to spin and
-- plays back whatever the server decides -- the RNG never runs on the client,
-- so results can't be predicted or spoofed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RarityConfig = require(ReplicatedStorage.Modules.RarityConfig)
local BrainrotConfig = require(ReplicatedStorage.Modules.BrainrotConfig)
local DataService = require(script.Parent.DataService)
local EquipService = require(script.Parent.EquipService)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestSpin = Remotes:WaitForChild("RequestSpin")
local SpinResult = Remotes:WaitForChild("SpinResult")
local InventoryUpdated = Remotes:WaitForChild("InventoryUpdated")
local RequestEquip = Remotes:WaitForChild("RequestEquip")
local RequestUnequip = Remotes:WaitForChild("RequestUnequip")

local SpinService = {}

local SPIN_COOLDOWN = 3
local lastSpinAt = {} -- [player] = os.clock()
local rng = Random.new()

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

-- SpinResult is ALWAYS fired, even on failure -- the client waits on a
-- response and has no other way to know the request was rejected/errored.
local function onRequestSpin(player)
	local now = os.clock()
	local last = lastSpinAt[player]
	if last and now - last < SPIN_COOLDOWN then
		SpinResult:FireClient(player, {
			Success = false,
			Reason = "Cooldown",
			CooldownRemaining = SPIN_COOLDOWN - (now - last),
		})
		return
	end

	local data = DataService.Get(player)
	if not data then
		SpinResult:FireClient(player, {
			Success = false,
			Reason = "NotLoaded",
			Detail = "Your save data hasn't finished loading yet (DataStore call still pending or failed). Try again in a moment.",
		})
		return
	end

	local ok, err = pcall(function()
		local rarityName = rollRarity()
		local brainrot = rollBrainrot(rarityName)
		if not brainrot then
			error("rollBrainrot returned nil for rarity " .. tostring(rarityName) .. " -- that rarity has no entries in BrainrotConfig.ByRarity")
		end

		lastSpinAt[player] = now
		DataService.AddBrainrot(player, brainrot.Id)

		SpinResult:FireClient(player, {
			Success = true,
			BrainrotId = brainrot.Id,
			Name = brainrot.Name,
			Rarity = rarityName,
		})

		sendInventory(player)
	end)

	if not ok then
		warn("[SpinService] onRequestSpin error for " .. player.Name .. ": " .. tostring(err))
		SpinResult:FireClient(player, {
			Success = false,
			Reason = "ServerError",
			Detail = tostring(err),
		})
	end
end

local function onRequestEquip(player, brainrotId)
	if typeof(brainrotId) ~= "string" then
		return
	end

	local data = DataService.Get(player)
	if not data then
		return
	end
	if not data.Inventory[brainrotId] or data.Inventory[brainrotId] <= 0 then
		return
	end
	if table.find(data.Equipped, brainrotId) then
		return
	end
	if #data.Equipped >= EquipService.MaxSlots then
		return
	end

	table.insert(data.Equipped, brainrotId)
	DataService.SetEquipped(player, data.Equipped)
	EquipService.Refresh(player, data.Equipped)
	sendInventory(player)
end

local function onRequestUnequip(player, brainrotId)
	if typeof(brainrotId) ~= "string" then
		return
	end

	local data = DataService.Get(player)
	if not data then
		return
	end

	local index = table.find(data.Equipped, brainrotId)
	if not index then
		return
	end

	table.remove(data.Equipped, index)
	DataService.SetEquipped(player, data.Equipped)
	EquipService.Refresh(player, data.Equipped)
	sendInventory(player)
end

function SpinService.Init()
	RequestSpin.OnServerEvent:Connect(onRequestSpin)
	RequestEquip.OnServerEvent:Connect(onRequestEquip)
	RequestUnequip.OnServerEvent:Connect(onRequestUnequip)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			-- DataService loads asynchronously (DataStore call) on its own
			-- PlayerAdded connection, so wait until it's populated before pushing.
			local attempts = 0
			while not DataService.Get(player) and attempts < 50 and player.Parent do
				task.wait(0.1)
				attempts += 1
			end
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
