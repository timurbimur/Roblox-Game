--[[
	MonetizationService
	-------------------
	Gamepasses + Developer Products.

	Gamepasses
	  Ownership is checked with UserOwnsGamePassAsync on join and updated live
	  when a pass is bought in-game. Owned passes live in profile.Passes (session
	  state, never trusted from the client) and are replicated for UI display.
	  VIP also sets a "VIP" player attribute so every client can render the gold
	  chat tag.

	Developer Products
	  ProcessReceipt is idempotent: PurchaseIds are stored in the save
	  (ProcessedReceipts) and the profile is saved BEFORE returning
	  PurchaseGranted, as Roblox recommends.

	Testing: any pass/product whose Id is 0 is simulated for free in Studio.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local MonetizationService = {}

local Services
local MAX_STORED_RECEIPTS = 50

local passNameById = {}
local productNameById = {}
for name, pass in pairs(Config.GamePasses) do
	if pass.Id ~= 0 then
		passNameById[pass.Id] = name
	end
end
for name, product in pairs(Config.DevProducts) do
	if product.Id ~= 0 then
		productNameById[product.Id] = name
	end
end

local function setPass(profile, passName, owned)
	profile.Passes[passName] = owned or nil
	Services.DataService.MarkDirty(profile.Player, "Passes")
	if passName == "VIP" then
		profile.Player:SetAttribute("VIP", owned == true)
	end
end

local function refreshPasses(profile)
	for name, pass in pairs(Config.GamePasses) do
		if pass.Id ~= 0 then
			local ok, owned = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, profile.UserId, pass.Id)
			if ok and owned then
				setPass(profile, name, true)
			end
		end
	end
end

-- ============================================================================
-- PRODUCT GRANTS
-- ============================================================================
local ProductGrants = {}

local function grantCash(profile, product)
	local amount = product.CashBase * Formulas.GetZoneScale(profile.Data)
	local added = Services.EconomyService.AddCash(profile, amount)
	Services.AnnouncementService.Toast(profile.Player, ("💰 +%s from %s!"):format(Util.FormatCash(added), product.Name), "Success")
end

ProductGrants.SmallCash = grantCash
ProductGrants.MediumCash = grantCash
ProductGrants.LargeCash = grantCash
ProductGrants.MegaCash = grantCash

ProductGrants.LuckCrate = function(profile)
	Services.BoostService.AddBoost(profile, "Luck2x", 15 * 60)
	local bestZone = Config.ZoneById[Formulas.GetHighestZone(profile.Data)]
	local luck = Formulas.GetLuck(profile.Data, profile.Passes)
	local itemId = Services.LootService.RollItem(bestZone.Pool, luck, Config.RarityByName.Epic.Order)
	local isNew = Services.InventoryService.AddItem(profile, itemId, 1, "Reward")
	Remotes.Signal:FireClient(profile.Player, "ItemFound", { ItemId = itemId, IsNew = isNew, Crate = true })
	Services.AnnouncementService.Toast(profile.Player, ("🎁 Luck Crate: %s %s + 15m 2x Luck!"):format(Items.ById[itemId].Icon, Items.ById[itemId].Name), "Success")
end

local function processReceipt(receiptInfo)
	local productName = productNameById[receiptInfo.ProductId]
	if not productName then
		warn("[Monetization] Unknown product " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	local profile = player and Services.DataService.WaitForProfile(player, 10)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receipts = profile.Data.ProcessedReceipts
	if table.find(receipts, receiptInfo.PurchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local ok, err = pcall(ProductGrants[productName], profile, Config.DevProducts[productName])
	if not ok then
		warn("[Monetization] Grant failed: " .. tostring(err))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	table.insert(receipts, receiptInfo.PurchaseId)
	while #receipts > MAX_STORED_RECEIPTS do
		table.remove(receipts, 1)
	end

	if not Services.DataService.SaveProfile(profile, false) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- ============================================================================
-- REQUEST HANDLERS
-- ============================================================================
local function handleBuyPass(profile, payload)
	local name = type(payload) == "table" and payload.Name
	local pass = type(name) == "string" and Config.GamePasses[name]
	if not pass then
		return false, "Invalid pass."
	end
	if profile.Passes[name] then
		return false, "You already own this!"
	end
	if pass.Id == 0 then
		if RunService:IsStudio() then
			setPass(profile, name, true)
			Services.AnnouncementService.Toast(profile.Player, "🧪 [Studio] Simulated purchase: " .. pass.Name, "Success")
			return true
		end
		return false, "This pass isn't configured yet."
	end
	MarketplaceService:PromptGamePassPurchase(profile.Player, pass.Id)
	return true
end

local function handleBuyProduct(profile, payload)
	local name = type(payload) == "table" and payload.Name
	local product = type(name) == "string" and Config.DevProducts[name]
	if not product then
		return false, "Invalid product."
	end
	if product.Id == 0 then
		if RunService:IsStudio() then
			ProductGrants[name](profile, product)
			return true
		end
		return false, "This product isn't configured yet."
	end
	MarketplaceService:PromptProductPurchase(profile.Player, product.Id)
	return true
end

function MonetizationService.Init(services)
	Services = services
	Services.DataService.OnProfileLoaded(function(profile)
		-- Marketplace calls yield; don't hold up the data load for them.
		task.spawn(refreshPasses, profile)
	end)
end

function MonetizationService.Start()
	Services.Router.Register("BuyPass", handleBuyPass)
	Services.Router.Register("BuyProduct", handleBuyProduct)

	MarketplaceService.ProcessReceipt = processReceipt

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local name = passNameById[passId]
		local profile = Services.DataService.GetProfile(player)
		if purchased and name and profile then
			setPass(profile, name, true)
			Services.AnnouncementService.Toast(player, "🎉 Thanks for buying " .. Config.GamePasses[name].Name .. "!", "Success")
		end
	end)
end

return MonetizationService
