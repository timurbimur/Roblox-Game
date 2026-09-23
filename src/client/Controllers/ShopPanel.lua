--[[
	ShopPanel
	---------
	Tabs:
	  Upgrades   Backpack, Luck, Dumpster Speed, Fusion Speed, Auto Collect,
	             Auto Sell (exponential costs) + live rarity odds
	  Zones      unlock the next zone / teleport to unlocked zones / VIP room
	  Passes     gamepasses (VIP, 2x Luck, 2x Cash, Auto Sell, Infinite
	             Inventory, Fusion Master)
	  Cash       developer products (cash packs scale with your best zone,
	             Luck Crate)
	All purchases are validated by the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Util = require(Shared.Util)

local ClientRoot = script.Parent.Parent
local UIKit = require(ClientRoot.UI.UIKit)
local Theme = require(ClientRoot.UI.Theme)
local State = require(ClientRoot.Lib.State)
local Net = require(ClientRoot.Lib.Net)

local ShopPanel = {}

local window, tabs
local pages = {}
local upgradeRows = {}
local zoneRows = {}
local passRows = {}
local productRows = {}
local oddsLabels = {}
local luckLabel

-- ============================================================================
-- EFFECT DESCRIPTIONS
-- ============================================================================
local function effectText(upgradeId, level)
	local fakeData = { Upgrades = { [upgradeId] = level }, Boosts = {} }
	if upgradeId == "Backpack" then
		return tostring(Config.BackpackTiers[level + 1].Capacity) .. " slots"
	elseif upgradeId == "Luck" then
		return ("x%.2f luck"):format(1 + level * Config.UpgradeById.Luck.PerLevel)
	elseif upgradeId == "DumpsterSpeed" then
		return ("%.2fs hold"):format(Formulas.GetHoldDuration(fakeData))
	elseif upgradeId == "FusionSpeed" then
		return ("%.1fs fusion"):format(Formulas.GetFusionDuration(fakeData, {}))
	elseif upgradeId == "AutoCollect" then
		local range, interval = Formulas.GetAutoCollect(fakeData)
		return range and ("%d studs / %.1fs"):format(range, interval) or "Off"
	elseif upgradeId == "AutoSell" then
		return level > 0 and ("Up to " .. Config.Rarities[level].Name) or "Off"
	end
	return "Lv " .. level
end

-- ============================================================================
-- UPGRADES
-- ============================================================================
local function buildUpgrades(page)
	local list = UIKit.ScrollList({ Size = UDim2.new(0.64, -6, 1, 0), Parent = page })
	for index, def in ipairs(Config.Upgrades) do
		local row = UIKit.Card({ Size = UDim2.new(1, 0, 0, 86), LayoutOrder = index, Parent = list })
		UIKit.new("TextLabel", { Size = UDim2.fromOffset(62, 62), Position = UDim2.fromOffset(10, 12), BackgroundTransparency = 1, TextScaled = true, Text = def.Icon, Parent = row })
		local title = UIKit.Label({ Size = UDim2.new(0.5, -80, 0, 28), Position = UDim2.fromOffset(80, 6), TextXAlignment = Enum.TextXAlignment.Left, Parent = row }, 24)
		UIKit.Label({ Text = def.Description, Size = UDim2.new(0.62, -80, 0, 20), Position = UDim2.fromOffset(80, 34), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.SubText, Font = Theme.BodyFont, Stroke = false, Parent = row }, 14)
		local effect = UIKit.Label({ Size = UDim2.new(0.62, -80, 0, 22), Position = UDim2.fromOffset(80, 58), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.Green, Parent = row }, 17)
		local buy = UIKit.Button({
			Text = "Buy",
			Color = Theme.Colors.Green,
			Size = UDim2.new(0.34, 0, 0, 60),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextSize = 22,
			Parent = row,
			OnClick = function()
				Net.RequestAsync("BuyUpgrade", { Id = def.Id }, function(success)
					if success and ShopPanel.Sound then
						ShopPanel.Sound.Play("ItemFound", 0.5, 1.4)
					end
				end)
			end,
		})
		upgradeRows[def.Id] = { Title = title, Effect = effect, Buy = buy }
	end

	-- Odds card
	local oddsCard = UIKit.Card({ Size = UDim2.new(0.36, -6, 1, 0), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), Color = Theme.Colors.Background, Parent = page })
	UIKit.Label({ Text = "🎲 Your Odds", Size = UDim2.new(1, -20, 0, 32), Position = UDim2.fromOffset(10, 8), Parent = oddsCard }, 26)
	luckLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 40), TextColor3 = Theme.Colors.Green, Parent = oddsCard }, 18)
	for index, rarity in ipairs(Config.Rarities) do
		local row = UIKit.new("Frame", { Size = UDim2.new(1, -20, 0, 30), Position = UDim2.fromOffset(10, 68 + (index - 1) * 36), BackgroundColor3 = rarity.Color:Lerp(Theme.Colors.Panel, 0.6), Parent = oddsCard }, { UIKit.Corner(Theme.SmallCorner) })
		UIKit.Label({ Text = rarity.Name, Size = UDim2.new(0.6, 0, 1, -6), Position = UDim2.fromOffset(8, 3), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = rarity.Name == "Secret" and Color3.new(1, 1, 1) or rarity.Color:Lerp(Color3.new(1, 1, 1), 0.3), Parent = row }, 18)
		oddsLabels[rarity.Name] = UIKit.Label({ Text = "", Size = UDim2.new(0.4, -8, 1, -6), Position = UDim2.new(1, -8, 0, 3), AnchorPoint = Vector2.new(1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row }, 18)
	end
end

local function refreshUpgrades()
	local data = State.Data
	if not data then
		return
	end
	for _, def in ipairs(Config.Upgrades) do
		local row = upgradeRows[def.Id]
		local level = data.Upgrades[def.Id] or 0
		local cost = Formulas.GetUpgradeCost(def.Id, level)
		row.Title.Text = ("%s  Lv %d/%d"):format(def.Name, level, def.MaxLevel)
		if cost then
			row.Effect.Text = effectText(def.Id, level) .. "  ➜  " .. effectText(def.Id, level + 1)
			row.Buy.Label.Text = Util.FormatCash(cost)
			row.Buy:SetAttribute("Disabled", data.Cash < cost)
		else
			row.Effect.Text = effectText(def.Id, level) .. "  (MAX)"
			row.Buy.Label.Text = "MAXED"
			row.Buy:SetAttribute("Disabled", true)
		end
	end
	local luck = Formulas.GetLuck(data, data.Passes)
	luckLabel.Text = ("Luck: x%.2f"):format(luck)
	local odds = Formulas.GetOddsPercent(luck)
	for name, label in pairs(oddsLabels) do
		local value = odds[name]
		label.Text = value >= 1 and ("%.1f%%"):format(value) or ("%.3f%%"):format(value)
	end
end

-- ============================================================================
-- ZONES
-- ============================================================================
local function buildZones(page)
	local list = UIKit.ScrollList({ Size = UDim2.fromScale(1, 1), Parent = page })
	for index, zone in ipairs(Config.Zones) do
		local row = UIKit.Card({ Size = UDim2.new(1, 0, 0, 74), LayoutOrder = index, Parent = list })
		row.BackgroundColor3 = zone.Theme.Ground:Lerp(Theme.Colors.Panel, 0.55)
		UIKit.Label({ Text = zone.Name, Size = UDim2.new(0.55, 0, 0, 34), Position = UDim2.fromOffset(14, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = zone.Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.4), Parent = row }, 28)
		local sub = UIKit.Label({ Size = UDim2.new(0.55, 0, 0, 24), Position = UDim2.fromOffset(14, 42), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.SubText, Font = Theme.BodyFont, Parent = row }, 16)
		local button = UIKit.Button({
			Text = "",
			Size = UDim2.new(0.36, 0, 0, 54),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextSize = 22,
			Parent = row,
			OnClick = function(btn)
				local data = State.Data
				if data.Zones[tostring(zone.Id)] then
					Net.RequestAsync("Teleport", { ZoneId = zone.Id }, function(success)
						if success then
							ShopPanel.CloseAll()
						end
					end)
				elseif btn:GetAttribute("CanUnlock") then
					Net.RequestAsync("UnlockZone", { ZoneId = zone.Id })
				end
			end,
		})
		zoneRows[zone.Id] = { Sub = sub, Button = button }
	end
	local vipRow = UIKit.Card({ Size = UDim2.new(1, 0, 0, 74), LayoutOrder = 100, Color = Color3.fromRGB(90, 70, 20), Parent = list })
	UIKit.Label({ Text = "👑 VIP Lounge", Size = UDim2.new(0.55, 0, 0, 34), Position = UDim2.fromOffset(14, 6), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.Yellow, Parent = vipRow }, 28)
	UIKit.Label({ Text = "VIP dumpsters roll your best zone with +50% luck", Size = UDim2.new(0.55, 0, 0, 24), Position = UDim2.fromOffset(14, 42), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = Theme.Colors.SubText, Font = Theme.BodyFont, Parent = vipRow }, 16)
	zoneRows.VIP = {
		Button = UIKit.Button({
			Text = "Teleport",
			Color = Theme.Colors.Yellow,
			Size = UDim2.new(0.36, 0, 0, 54),
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			TextSize = 22,
			Parent = vipRow,
			OnClick = function()
				local data = State.Data
				if data.Passes and data.Passes.VIP then
					Net.RequestAsync("Teleport", { ZoneId = "VIP" }, function(success)
						if success then
							ShopPanel.CloseAll()
						end
					end)
				else
					Net.RequestAsync("BuyPass", { Name = "VIP" })
				end
			end,
		}),
	}
end

local function refreshZones()
	local data = State.Data
	if not data then
		return
	end
	local highest = Formulas.GetHighestZone(data)
	for _, zone in ipairs(Config.Zones) do
		local row = zoneRows[zone.Id]
		local unlocked = data.Zones[tostring(zone.Id)]
		local isNext = zone.Id == highest + 1
		row.Button:SetAttribute("CanUnlock", isNext)
		if unlocked then
			row.Sub.Text = ("Unlocked  •  Loot value x%s"):format(Util.FormatNumber(zone.ValueMultiplier))
			row.Button.Label.Text = "Teleport"
			row.Button:SetAttribute("Disabled", false)
		elseif isNext then
			row.Sub.Text = ("Unlock for %s  •  Loot value x%s"):format(Util.FormatCash(zone.Cost), Util.FormatNumber(zone.ValueMultiplier))
			row.Button.Label.Text = "Unlock " .. Util.FormatCash(zone.Cost)
			row.Button:SetAttribute("Disabled", data.Cash < zone.Cost)
		else
			row.Sub.Text = "🔒 Unlock the previous zone first"
			row.Button.Label.Text = "🔒 " .. Util.FormatCash(zone.Cost)
			row.Button:SetAttribute("Disabled", true)
		end
	end
	local vip = data.Passes and data.Passes.VIP
	zoneRows.VIP.Button.Label.Text = vip and "Teleport" or "Get VIP"
end

-- ============================================================================
-- PASSES + PRODUCTS
-- ============================================================================
local function productCard(parent, def, order, onClick)
	local card = UIKit.Card({ Size = UDim2.new(1, 0, 0, 84), LayoutOrder = order, Parent = parent })
	UIKit.new("TextLabel", { Size = UDim2.fromOffset(60, 60), Position = UDim2.fromOffset(10, 12), BackgroundTransparency = 1, TextScaled = true, Text = def.Icon, Parent = card })
	local title = UIKit.Label({ Text = def.Name, Size = UDim2.new(0.6, -80, 0, 30), Position = UDim2.fromOffset(80, 8), TextXAlignment = Enum.TextXAlignment.Left, Parent = card }, 24)
	local desc = UIKit.Label({ Text = def.Description or "", Size = UDim2.new(0.62, -80, 0, 36), Position = UDim2.fromOffset(80, 40), TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, TextColor3 = Theme.Colors.SubText, Font = Theme.BodyFont, Stroke = false, Parent = card }, 14)
	local button = UIKit.Button({
		Text = "R$ " .. def.Price,
		Color = Theme.Colors.Green,
		Size = UDim2.new(0.3, 0, 0, 56),
		Position = UDim2.new(1, -10, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		TextSize = 22,
		Parent = card,
		OnClick = onClick,
	})
	return { Card = card, Title = title, Desc = desc, Button = button }
end

local function buildPasses(page)
	local list = UIKit.ScrollList({ Size = UDim2.fromScale(1, 1), Parent = page })
	for index, name in ipairs(Config.GamePassOrder) do
		local def = Config.GamePasses[name]
		passRows[name] = productCard(list, def, index, function()
			if not (State.Data.Passes and State.Data.Passes[name]) then
				Net.RequestAsync("BuyPass", { Name = name })
			end
		end)
	end
end

local function refreshPasses()
	local passes = State.Get("Passes") or {}
	for name, row in pairs(passRows) do
		local owned = passes[name] == true
		row.Button.Label.Text = owned and "✔ Owned" or ("R$ " .. Config.GamePasses[name].Price)
		row.Button:SetAttribute("Disabled", owned)
	end
end

local function buildCash(page)
	local list = UIKit.ScrollList({ Size = UDim2.fromScale(1, 1), Parent = page })
	for index, name in ipairs(Config.DevProductOrder) do
		local def = Config.DevProducts[name]
		productRows[name] = productCard(list, def, index, function()
			Net.RequestAsync("BuyProduct", { Name = name })
		end)
	end
end

local function refreshCash()
	local data = State.Data
	if not data then
		return
	end
	local scale = Formulas.GetZoneScale(data)
	for name, row in pairs(productRows) do
		local def = Config.DevProducts[name]
		if def.CashBase then
			row.Desc.Text = ("Get %s instantly! (scales with your best zone)"):format(Util.FormatCash(def.CashBase * scale))
		end
	end
end

local function refreshAll()
	if not window.Visible then
		return
	end
	refreshUpgrades()
	refreshZones()
	refreshPasses()
	refreshCash()
end

function ShopPanel.SelectTab(name)
	if tabs then
		tabs.Select(name)
	end
end

function ShopPanel.Init(controllers)
	ShopPanel.Sound = controllers.SoundController
	ShopPanel.CloseAll = function()
		controllers.UIController.Close()
	end
	local content
	window, content = UIKit.Window({
		Name = "ShopWindow",
		Title = "Shop",
		Icon = "🛒",
		Color = Theme.Colors.Green,
		Parent = controllers.UIController.Root,
		OnClose = ShopPanel.CloseAll,
	})

	local names = { "Upgrades", "Zones", "Passes", "Cash" }
	for _, name in ipairs(names) do
		pages[name] = UIKit.new("Frame", {
			Name = name,
			Size = UDim2.new(1, 0, 1, -50),
			Position = UDim2.fromOffset(0, 50),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = content,
		})
	end
	tabs = UIKit.Tabs(content, names, function(selected)
		for name, page in pairs(pages) do
			page.Visible = name == selected
		end
		refreshAll()
	end, Theme.Colors.Green)

	buildUpgrades(pages.Upgrades)
	buildZones(pages.Zones)
	buildPasses(pages.Passes)
	buildCash(pages.Cash)
	tabs.Select("Upgrades")

	controllers.UIController.RegisterPanel("Shop", { Window = window, OnOpen = refreshAll })
end

function ShopPanel.Start()
	State.Watch("Cash", refreshAll)
	State.Watch("Upgrades", refreshAll)
	State.Watch("Zones", refreshAll)
	State.Watch("Passes", refreshAll)
	State.Watch("Boosts", refreshAll)
end

return ShopPanel
