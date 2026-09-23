--[[
	FusionService
	-------------
	The signature mechanic. Player puts two items in a Fusion Machine and gets
	a new item after a short timed fusion.

	Server validation
	  * near a Fusion Station
	  * both ids are real items and owned (2 copies when fusing an item with itself)
	  * only one fusion at a time per player

	Persistence
	  Ingredients are consumed immediately and the pending result is stored in
	  data.PendingFusion. If the player leaves (or the server crashes after an
	  autosave) mid-fusion, the result is granted on their next join — items
	  can never be lost or duplicated.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)
local FusionRecipes = require(Shared.Data.FusionRecipes)
local Remotes = require(Shared.Remotes)

local FusionService = {}

local Services
local rng = Random.new()

local function completeFusion(profile)
	local data = profile.Data
	local pending = data.PendingFusion
	if not pending then
		return
	end
	data.PendingFusion = false
	Services.DataService.MarkDirty(profile.Player, "PendingFusion")

	if not Items.ById[pending.Result] then
		return
	end

	local isNew = Services.InventoryService.AddItem(profile, pending.Result, pending.Count or 1, "Fusion")
	data.Stats.Fusions += 1
	Services.DataService.MarkDirty(profile.Player, "Stats")
	Services.QuestService.Increment(profile, "Fuse", 1)
	Services.AchievementService.QueueCheck(profile)

	Remotes.Signal:FireClient(profile.Player, "FusionComplete", {
		ItemId = pending.Result,
		Count = pending.Count or 1,
		IsNew = isNew,
		IsRecipe = pending.IsRecipe,
	})
end

local function handleFuse(profile, payload)
	if type(payload) ~= "table" then
		return false, "Bad request."
	end
	local a, b = payload.A, payload.B
	if not (Items.IsValid(a) and Items.IsValid(b)) then
		return false, "Pick two items."
	end
	local data = profile.Data
	if data.PendingFusion then
		return false, "The machine is already fusing!"
	end
	if not Services.WorldService.IsNearStation(profile.Player, "FusionStation", Config.Fusion.StationRange) then
		return false, "Walk to a Fusion Machine first!"
	end

	local Inventory = Services.InventoryService
	if a == b then
		if Inventory.GetCount(profile, a) < 2 then
			return false, "You need 2 of that item."
		end
	elseif Inventory.GetCount(profile, a) < 1 or Inventory.GetCount(profile, b) < 1 then
		return false, "You don't own those items."
	end

	-- Consume (validated above, so both removals succeed atomically).
	if a == b then
		Inventory.RemoveItem(profile, a, 2)
	else
		Inventory.RemoveItem(profile, a, 1)
		Inventory.RemoveItem(profile, b, 1)
	end

	local result, isRecipe = FusionRecipes.Resolve(a, b)
	local count = 1
	if profile.Passes.FusionMaster and isRecipe and rng:NextNumber() < Config.Fusion.FusionMasterDoubleChance then
		count = 2
	end

	local duration = Formulas.GetFusionDuration(data, profile.Passes)
	data.PendingFusion = { Result = result, Count = count, IsRecipe = isRecipe, FinishAt = os.time() + math.ceil(duration) }
	Services.DataService.MarkDirty(profile.Player, "PendingFusion")

	Remotes.Signal:FireClient(profile.Player, "FusionStarted", { A = a, B = b, Duration = duration })

	task.delay(duration, function()
		-- Profile may have been released (player left); pending result stays saved.
		if Services.DataService.GetProfile(profile.Player) == profile then
			completeFusion(profile)
		end
	end)
	return true, { Duration = duration }
end

function FusionService.Init(services)
	Services = services
	-- Finish any fusion that was interrupted by leaving the game.
	Services.DataService.OnProfileLoaded(function(profile)
		if profile.Data.PendingFusion then
			task.defer(completeFusion, profile)
		end
	end)
end

function FusionService.Start()
	Services.Router.Register("Fuse", handleFuse)
end

return FusionService
