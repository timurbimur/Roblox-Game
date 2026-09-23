--[[
	DumpsterService
	---------------
	Core loop: searching dumpsters.

	Flow
	  1. Player holds E on a dumpster's ProximityPrompt (client may shorten
	     HoldDuration locally via the Dumpster Speed upgrade).
	  2. The server records PromptButtonHoldBegan and, on Triggered, validates:
	       - character alive and within range
	       - zone unlocked (or VIP pass for VIP dumpsters)
	       - per-player per-dumpster cooldown
	       - global per-player search rate
	       - held long enough (anti auto-clicker / fake trigger)
	       - backpack space (auto-sell may free space)
	  3. Loot is rolled server-side, added to inventory (or auto-sold).
	  4. Client receives "ItemFound"; every client receives "DumpsterFX" to
	     animate the lid, play sound and emit particles locally (no server tweens).

	Auto Collect (upgrade) searches the nearest ready dumpster in range on a timer,
	through the exact same validation path (minus the hold check).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)
local Remotes = require(Shared.Remotes)

local DumpsterService = {}

local Services
local dumpsters = {}       -- [DumpsterId] = model
local dumpstersByZone = {} -- [zoneId] = { model, ... }
local AUTO_COLLECT_TICK = 0.5

local function getDumpsterPosition(model)
	local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
	return primary and primary.Position
end

local function getSearchPrompt(model)
	return model:FindFirstChild("SearchPrompt", true)
end

-- ============================================================================
-- SEARCH
-- ============================================================================
--[[
	Returns ok, reason. `isAuto` = triggered by Auto Collect (skip hold check,
	use Auto Collect range instead of prompt range).
]]
function DumpsterService.TrySearch(player, model, isAuto)
	local profile = Services.DataService.GetProfile(player)
	if not profile then
		return false, "Loading"
	end
	local data = profile.Data
	local session = profile.Session
	local dumpsterId = model:GetAttribute("DumpsterId")
	local zoneId = model:GetAttribute("ZoneId")
	if not dumpsterId or type(zoneId) ~= "number" then
		return false, "Invalid dumpster"
	end

	-- 1. Character + distance
	local root = Services.WorldService.GetRoot(player)
	local position = getDumpsterPosition(model)
	if not root or not position then
		return false, "No character"
	end
	local maxDistance
	if isAuto then
		local range = Formulas.GetAutoCollect(data)
		if not range then
			return false, "No Auto Collect"
		end
		maxDistance = range + Config.Search.ServerDistanceSlack
	else
		maxDistance = Config.Search.MaxDistance + Config.Search.ServerDistanceSlack
	end
	if (root.Position - position).Magnitude > maxDistance then
		return false, "Too far"
	end

	-- 2. Zone access
	local isVIP = zoneId == -1
	if isVIP then
		if not profile.Passes.VIP then
			return false, "VIP only"
		end
	elseif not data.Zones[tostring(zoneId)] then
		return false, "Zone locked"
	end

	-- 3. Cooldowns
	local now = os.clock()
	if (session.Cooldowns[dumpsterId] or 0) > now then
		return false, "Cooldown"
	end
	if now - session.LastSearch < Config.Search.GlobalMinInterval then
		return false, "Too fast"
	end

	-- 4. Hold validation (manual searches only)
	if not isAuto then
		local holdStart = session.HoldStarts[dumpsterId]
		session.HoldStarts[dumpsterId] = nil
		local required = Formulas.GetHoldDuration(data) * Config.Search.HoldTimeTolerance
		if not holdStart or now - holdStart < required then
			return false, "Hold not long enough"
		end
	end

	-- 5. Backpack space (try auto-sell first)
	local Inventory = Services.InventoryService
	if not Inventory.HasSpace(profile, 1) then
		Services.EconomyService.AutoSellInventory(profile)
		if not Inventory.HasSpace(profile, 1) then
			if not isAuto then
				Services.AnnouncementService.Toast(player, "🎒 Backpack full! Sell items or upgrade your backpack.", "Error")
			end
			return false, "Full"
		end
	end

	-- 6. Roll loot
	local poolName, luck
	if isVIP then
		local bestZone = Config.ZoneById[Formulas.GetHighestZone(data)]
		poolName = bestZone.Pool
		luck = Formulas.GetLuck(data, profile.Passes) * Config.VIP.VIPDumpsterLuckBonus
	else
		poolName = Config.ZoneById[zoneId].Pool
		luck = Formulas.GetLuck(data, profile.Passes)
	end
	local itemId = Services.LootService.RollItem(poolName, luck)
	local item = Items.ById[itemId]

	-- 7. Commit state
	local cooldown = Formulas.GetCooldown(data)
	session.Cooldowns[dumpsterId] = now + cooldown
	session.LastSearch = now
	data.Stats.Searches += 1
	Services.DataService.MarkDirty(player, "Stats")
	Services.QuestService.Increment(profile, "Search", 1)
	Services.AchievementService.QueueCheck(profile)

	local soldFor = Services.EconomyService.TryAutoSellFind(profile, itemId)
	local isNew = false
	if soldFor then
		Inventory.RecordFind(profile, item, false, "Dumpster")
	else
		isNew = Inventory.AddItem(profile, itemId, 1, "Dumpster")
	end

	-- 8. Feedback
	Remotes.Signal:FireClient(player, "ItemFound", {
		ItemId = itemId,
		IsNew = isNew,
		AutoSold = soldFor,
		DumpsterId = dumpsterId,
		Cooldown = cooldown,
		Auto = isAuto,
	})
	Remotes.Signal:FireAllClients("DumpsterFX", {
		Dumpster = model,
		Rarity = item.Rarity,
		UserId = player.UserId,
	})
	return true
end

-- ============================================================================
-- REGISTRATION (supports dumpsters added at runtime / hand-placed models)
-- ============================================================================
local function registerDumpster(model)
	if not model:IsA("Model") then
		return
	end
	local dumpsterId = model:GetAttribute("DumpsterId")
	if not dumpsterId then
		dumpsterId = "D_" .. model:GetFullName():gsub("%W", "") .. "_" .. tostring(math.random(1, 1e6))
		model:SetAttribute("DumpsterId", dumpsterId)
	end
	if dumpsters[dumpsterId] then
		return
	end
	local zoneId = model:GetAttribute("ZoneId") or 0
	dumpsters[dumpsterId] = model
	dumpstersByZone[zoneId] = dumpstersByZone[zoneId] or {}
	table.insert(dumpstersByZone[zoneId], model)

	local searchPrompt = getSearchPrompt(model)
	if not searchPrompt then
		local primary = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
		if not primary then
			return
		end
		searchPrompt = Instance.new("ProximityPrompt")
		searchPrompt.Name = "SearchPrompt"
		searchPrompt.ActionText = "Search Dumpster"
		searchPrompt.HoldDuration = Config.Search.HoldDuration
		searchPrompt.MaxActivationDistance = Config.Search.MaxDistance
		searchPrompt.RequiresLineOfSight = false
		searchPrompt.Parent = primary
	end

	searchPrompt.PromptButtonHoldBegan:Connect(function(player)
		local profile = Services.DataService.GetProfile(player)
		if profile then
			profile.Session.HoldStarts[dumpsterId] = os.clock()
		end
	end)
	searchPrompt.PromptButtonHoldEnded:Connect(function(player)
		-- Triggered fires before HoldEnded, so clearing here only affects
		-- cancelled holds. Delay slightly to be order-agnostic.
		task.delay(0.1, function()
			local profile = Services.DataService.GetProfile(player)
			if profile then
				local start = profile.Session.HoldStarts[dumpsterId]
				if start and os.clock() - start > 0.2 then
					profile.Session.HoldStarts[dumpsterId] = nil
				end
			end
		end)
	end)
	searchPrompt.Triggered:Connect(function(player)
		DumpsterService.TrySearch(player, model, false)
	end)
end

local function unregisterDumpster(model)
	local dumpsterId = model:GetAttribute("DumpsterId")
	if not dumpsterId or dumpsters[dumpsterId] ~= model then
		return
	end
	dumpsters[dumpsterId] = nil
	local zoneList = dumpstersByZone[model:GetAttribute("ZoneId") or 0]
	if zoneList then
		local index = table.find(zoneList, model)
		if index then
			table.remove(zoneList, index)
		end
	end
end

-- ============================================================================
-- AUTO COLLECT
-- ============================================================================
local function autoCollectTick()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = Services.DataService.GetProfile(player)
		if profile and profile.Data.Settings.AutoCollect then
			local range, interval = Formulas.GetAutoCollect(profile.Data)
			local root = range and Services.WorldService.GetRoot(player)
			if root and now >= profile.Session.NextAutoCollect then
				-- Only scan dumpsters in the zone the player is standing in.
				local zoneId = Services.WorldService.GetZoneAtPosition(root.Position)
				if Services.WorldService.IsInVIPRoom(root.Position) then
					zoneId = -1
				end
				local candidates = zoneId and dumpstersByZone[zoneId]
				if candidates then
					local best, bestDistance = nil, range
					for _, model in ipairs(candidates) do
						local id = model:GetAttribute("DumpsterId")
						local position = getDumpsterPosition(model)
						if position and (profile.Session.Cooldowns[id] or 0) <= now then
							local distance = (position - root.Position).Magnitude
							if distance <= bestDistance then
								best, bestDistance = model, distance
							end
						end
					end
					if best then
						local ok = DumpsterService.TrySearch(player, best, true)
						if ok then
							profile.Session.NextAutoCollect = now + interval
						end
					end
				end
			end
		end
	end
end

function DumpsterService.Init(services)
	Services = services
end

function DumpsterService.Start()
	for _, model in ipairs(CollectionService:GetTagged("Dumpster")) do
		registerDumpster(model)
	end
	CollectionService:GetInstanceAddedSignal("Dumpster"):Connect(registerDumpster)
	CollectionService:GetInstanceRemovedSignal("Dumpster"):Connect(unregisterDumpster)

	task.spawn(function()
		while true do
			task.wait(AUTO_COLLECT_TICK)
			local ok, err = pcall(autoCollectTick)
			if not ok then
				warn("[DumpsterService] Auto collect error: " .. tostring(err))
			end
		end
	end)
end

return DumpsterService
