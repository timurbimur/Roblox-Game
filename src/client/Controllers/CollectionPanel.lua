--[[
	CollectionPanel (Pokedex)
	-------------------------
	Every item in the game, ordered by Discoverable ID. Undiscovered items show
	as "???????". Header tracks total discoveries, collection %, rare and
	secret discoveries. Selecting an entry shows where it comes from.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Data.Items)
local FusionRecipes = require(Shared.Data.FusionRecipes)
local Util = require(Shared.Util)

local ClientRoot = script.Parent.Parent
local UIKit = require(ClientRoot.UI.UIKit)
local Theme = require(ClientRoot.UI.Theme)
local State = require(ClientRoot.Lib.State)

local CollectionPanel = {}

local window, grid, progress, infoLabel
local stats = {}
local filter = "All"
local rarityFilter = nil
local FILTERS = { "All", "Found", "Missing" }

-- Where does an item come from? (pool -> zone name)
local poolToZone = {}
for _, zone in ipairs(Config.Zones) do
	poolToZone[zone.Pool] = zone.Name
end
local producedBy = {}
for _, recipe in ipairs(FusionRecipes.List) do
	producedBy[recipe.Result] = recipe
end

local function sourceText(item, data)
	if poolToZone[item.Pool] then
		return "Found in " .. poolToZone[item.Pool] .. " dumpsters"
	elseif item.Pool == "Fusion" then
		local recipe = producedBy[item.Id]
		if not recipe then
			return "Made from fusions with no recipe"
		end
		local a, b = Items.ById[recipe.A], Items.ById[recipe.B]
		local nameA = data.Discovered[recipe.A] and a.Name or "???"
		local nameB = data.Discovered[recipe.B] and b.Name or "???"
		return ("Fusion: %s + %s"):format(nameA, nameB)
	end
	return "Exclusive reward (quests, daily login, playtime)"
end

local function render()
	local data = State.Data
	if not data or not window.Visible then
		return
	end
	local discovered = data.Discovered
	local total, found, rare, secret = Items.Count, 0, 0, 0
	local rareOrder = Config.RarityByName[Config.RareDiscoveryMinRarity].Order
	local rareTotal, secretTotal = 0, 0
	for _, item in ipairs(Items.List) do
		if item.RarityOrder >= rareOrder then
			rareTotal += 1
		end
		if item.Rarity == "Secret" then
			secretTotal += 1
		end
		if discovered[item.Id] then
			found += 1
			if item.RarityOrder >= rareOrder then
				rare += 1
			end
			if item.Rarity == "Secret" then
				secret += 1
			end
		end
	end
	local percent = found / total * 100
	stats.Found.Text = ("%d / %d"):format(found, total)
	stats.Percent.Text = ("%.1f%%"):format(percent)
	stats.Rare.Text = ("%d / %d"):format(rare, rareTotal)
	stats.Secret.Text = ("%d / %d"):format(secret, secretTotal)
	progress.Set(found / total, ("Collection %.1f%% complete"):format(percent))

	local entries = {}
	for _, item in ipairs(Items.List) do
		local isFound = discovered[item.Id] ~= nil
		local passFilter = filter == "All" or (filter == "Found" and isFound) or (filter == "Missing" and not isFound)
		if passFilter and (not rarityFilter or item.Rarity == rarityFilter) then
			table.insert(entries, { ItemId = item.Id, Hidden = not isFound })
		end
	end
	grid.Render(entries)
end

local function statCard(parent, title, color, order)
	local card = UIKit.Card({ Size = UDim2.new(0.25, -8, 1, 0), LayoutOrder = order, Parent = parent })
	UIKit.Label({ Text = title, Size = UDim2.new(1, -10, 0.4, 0), Position = UDim2.fromOffset(5, 3), TextColor3 = Theme.Colors.SubText, Parent = card }, 16)
	return UIKit.Label({ Text = "-", Size = UDim2.new(1, -10, 0.55, 0), Position = UDim2.new(0, 5, 0.42, 0), TextColor3 = color, Parent = card }, 28)
end

function CollectionPanel.Init(controllers)
	local content
	window, content = UIKit.Window({
		Name = "CollectionWindow",
		Title = "Collection",
		Icon = "📖",
		Color = Theme.Colors.Pink,
		Parent = controllers.UIController.Root,
		OnClose = function()
			controllers.UIController.Close()
		end,
	})

	local statRow = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 62), BackgroundTransparency = 1, Parent = content },
		{ UIKit.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })
	stats.Found = statCard(statRow, "📖 Discovered", Theme.Colors.Text, 1)
	stats.Percent = statCard(statRow, "📊 Collection", Theme.Colors.Green, 2)
	stats.Rare = statCard(statRow, "💎 Rare+ Found", Theme.Colors.Blue, 3)
	stats.Secret = statCard(statRow, "🕵️ Secrets", Theme.Colors.Purple, 4)

	progress = UIKit.ProgressBar({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 70), Color = Theme.Colors.Pink, Parent = content })

	local filterRow = UIKit.new("Frame", { Size = UDim2.new(1, 0, 0, 38), Position = UDim2.fromOffset(0, 102), BackgroundTransparency = 1, Parent = content },
		{ UIKit.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left) })
	local filterButton, rarityButton
	filterButton = UIKit.Button({
		Text = "Show: All", Size = UDim2.new(0.22, 0, 1, 0), Color = Theme.Colors.Blue, TextSize = 18, LayoutOrder = 1, Parent = filterRow,
		OnClick = function()
			filter = FILTERS[(table.find(FILTERS, filter) or 1) % #FILTERS + 1]
			filterButton.Label.Text = "Show: " .. filter
			render()
		end,
	})
	rarityButton = UIKit.Button({
		Text = "Rarity: Any", Size = UDim2.new(0.26, 0, 1, 0), Color = Theme.Colors.Purple, TextSize = 18, LayoutOrder = 2, Parent = filterRow,
		OnClick = function()
			local index = rarityFilter and Config.RarityByName[rarityFilter].Order or 0
			index += 1
			rarityFilter = Config.Rarities[index] and Config.Rarities[index].Name or nil
			rarityButton.Label.Text = "Rarity: " .. (rarityFilter or "Any")
			render()
		end,
	})
	infoLabel = UIKit.Label({
		Text = "Tap an item for details",
		Size = UDim2.new(0.5, -20, 1, 0),
		LayoutOrder = 3,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Theme.Colors.SubText,
		Font = Theme.BodyFont,
		Parent = filterRow,
	}, 16)

	grid = UIKit.ItemGrid({
		Size = UDim2.new(1, 0, 1, -148),
		Position = UDim2.fromOffset(0, 148),
		CellSize = 84,
		Parent = content,
		OnClick = function(itemId)
			local data = State.Data
			local item = Items.ById[itemId]
			if not data or not item then
				return
			end
			if data.Discovered[itemId] then
				infoLabel.Text = ("#%d %s %s (%s) • %s • %s"):format(item.DexId, item.Icon, item.Name, item.Rarity, Util.FormatCash(item.Value), sourceText(item, data))
			else
				local hint = poolToZone[item.Pool] and ("Found in " .. poolToZone[item.Pool]) or (item.Pool == "Fusion" and "Made by fusion" or "Exclusive reward")
				infoLabel.Text = ("#%d ??????? (%s) • Hint: %s"):format(item.DexId, item.Rarity, hint)
			end
		end,
	})

	controllers.UIController.RegisterPanel("Collection", { Window = window, OnOpen = render })
end

function CollectionPanel.Start()
	State.Watch("Discovered", render)
end

return CollectionPanel
