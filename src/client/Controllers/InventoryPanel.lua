--[[
	InventoryPanel
	--------------
	Grid inventory with rarity colors, quantities, search, sort and favorites.
	Selecting an item shows details and a Favorite toggle (favorites can never
	be sold by any sell mode — enforced on the server).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)
local FusionRecipes = require(Shared.Data.FusionRecipes)
local Util = require(Shared.Util)

local ClientRoot = script.Parent.Parent
local UIKit = require(ClientRoot.UI.UIKit)
local Theme = require(ClientRoot.UI.Theme)
local ItemList = require(ClientRoot.UI.ItemList)
local State = require(ClientRoot.Lib.State)
local Net = require(ClientRoot.Lib.Net)

local InventoryPanel = {}

local window, grid, toolbar, capacityLabel
local details = {}
local selectedId = nil

local function refreshDetails()
	local data = State.Data
	local item = selectedId and Items.ById[selectedId]
	local count = item and data and (data.Inventory[selectedId] or 0) or 0
	if not item or count <= 0 then
		selectedId = nil
		details.Frame.Visible = false
		details.Empty.Visible = true
		return
	end
	details.Frame.Visible = true
	details.Empty.Visible = false
	local rarity = Config.RarityByName[item.Rarity]
	details.IconBox.BackgroundColor3 = rarity.Color:Lerp(Theme.Colors.Cell, 0.4)
	details.IconBox.UIStroke.Color = rarity.Color
	details.Icon.Text = item.Icon
	details.Name.Text = item.Name
	details.Rarity.Text = item.Rarity
	details.Rarity.TextColor3 = rarity.Color
	local mult = Formulas.GetCashMultiplier(data, data.Passes)
	details.Info.Text = ("Sell value: %s\nOwned: %d  (total %s)\nUsed in %d recipe(s)\nDex #%d"):format(
		Util.FormatCash(item.Value * mult), count, Util.FormatCash(item.Value * mult * count),
		FusionRecipes.UsageCount[item.Id] or 0, item.DexId)
	local favorite = data.Favorites[selectedId] == true
	details.Favorite.Label.Text = favorite and "★ Unfavorite" or "☆ Favorite"
end

local function render()
	local data = State.Data
	if not data or not window.Visible then
		return
	end
	local entries = ItemList.Build(data, toolbar.State)
	for _, entry in ipairs(entries) do
		entry.Selected = entry.ItemId == selectedId
	end
	grid.Render(entries)

	local total = 0
	for _, count in pairs(data.Inventory) do
		total += count
	end
	local capacity = Formulas.GetCapacity(data, data.Passes)
	capacityLabel.Text = capacity >= Config.InfiniteCapacity and ("🎒 %d / ∞"):format(total) or ("🎒 %d / %d"):format(total, capacity)
	refreshDetails()
end

function InventoryPanel.Init(controllers)
	local content
	window, content = UIKit.Window({
		Name = "InventoryWindow",
		Title = "Inventory",
		Icon = "🎒",
		Color = Theme.Colors.Blue,
		Parent = controllers.UIController.Root,
		OnClose = function()
			controllers.UIController.Close()
		end,
	})

	toolbar = ItemList.Toolbar(content, render, true)
	capacityLabel = UIKit.Label({
		Text = "",
		Size = UDim2.new(0.12, 0, 1, 0),
		LayoutOrder = 4,
		Parent = toolbar.Frame,
	}, 20)

	grid = UIKit.ItemGrid({
		Size = UDim2.new(0.68, 0, 1, -52),
		Position = UDim2.fromOffset(0, 52),
		Parent = content,
		OnClick = function(itemId)
			selectedId = (selectedId ~= itemId) and itemId or nil
			render()
		end,
	})

	-- Details card
	local card = UIKit.Card({
		Size = UDim2.new(0.3, 0, 1, -52),
		Position = UDim2.new(1, 0, 0, 52),
		AnchorPoint = Vector2.new(1, 0),
		Parent = content,
	})
	details.Empty = UIKit.Label({
		Text = "Select an item to see details",
		Size = UDim2.new(1, -20, 0, 60),
		Position = UDim2.fromScale(0.5, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = Theme.Colors.SubText,
		Parent = card,
	}, 20)
	local frame = UIKit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = card })
	details.Frame = frame
	details.IconBox = UIKit.new("Frame", {
		Size = UDim2.new(0.55, 0, 0.55, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Colors.Cell,
		Parent = frame,
	}, { UIKit.Corner(Theme.CornerRadius), UIKit.Stroke(Color3.new(1, 1, 1), 3), UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	details.Icon = UIKit.new("TextLabel", {
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		TextScaled = true,
		Parent = details.IconBox,
	})
	details.Name = UIKit.Label({ Size = UDim2.new(1, -16, 0, 30), Position = UDim2.new(0.5, 0, 0.47, 0), AnchorPoint = Vector2.new(0.5, 0), Parent = frame }, 26)
	details.Rarity = UIKit.Label({ Size = UDim2.new(1, -16, 0, 22), Position = UDim2.new(0.5, 0, 0.47, 32), AnchorPoint = Vector2.new(0.5, 0), Parent = frame }, 20)
	details.Info = UIKit.Label({
		Size = UDim2.new(1, -16, 0.2, 0),
		Position = UDim2.new(0.5, 0, 0.47, 58),
		AnchorPoint = Vector2.new(0.5, 0),
		Font = Theme.BodyFont,
		TextColor3 = Theme.Colors.SubText,
		Stroke = false,
		Parent = frame,
	}, 16)
	details.Favorite = UIKit.Button({
		Text = "☆ Favorite",
		Color = Theme.Colors.Yellow,
		Size = UDim2.new(1, -20, 0, 44),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = frame,
		OnClick = function()
			if selectedId then
				Net.RequestAsync("ToggleFavorite", { ItemId = selectedId })
			end
		end,
	})

	controllers.UIController.RegisterPanel("Inventory", {
		Window = window,
		OnOpen = render,
	})
end

function InventoryPanel.Start()
	State.Watch("Inventory", render)
	State.Watch("Favorites", render)
end

return InventoryPanel
