--[[
	ItemList
	--------
	Shared inventory filtering + sorting for Inventory, Sell and Fusion panels,
	plus a reusable search/sort toolbar.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Items = require(Shared.Data.Items)

local UIKit = require(script.Parent.UIKit)
local Theme = require(script.Parent.Theme)

local ItemList = {}

ItemList.SortModes = { "Rarity", "Value", "Name", "Amount" }

local comparators = {
	Rarity = function(a, b)
		if a.Item.RarityOrder ~= b.Item.RarityOrder then
			return a.Item.RarityOrder > b.Item.RarityOrder
		end
		return a.Item.Value > b.Item.Value
	end,
	Value = function(a, b)
		if a.Item.Value ~= b.Item.Value then
			return a.Item.Value > b.Item.Value
		end
		return a.Item.Name < b.Item.Name
	end,
	Name = function(a, b)
		return a.Item.Name < b.Item.Name
	end,
	Amount = function(a, b)
		if a.Count ~= b.Count then
			return a.Count > b.Count
		end
		return a.Item.RarityOrder > b.Item.RarityOrder
	end,
}

--[[
	Build(data, { Search = "", Sort = "Rarity", FavoritesOnly = false })
	Returns array of { ItemId, Item, Count, Favorite } sorted.
	Favorites always float to the top.
]]
function ItemList.Build(data, options)
	options = options or {}
	local search = (options.Search or ""):lower()
	local entries = {}
	for itemId, count in pairs(data.Inventory or {}) do
		local item = Items.ById[itemId]
		if item and count > 0 then
			local favorite = data.Favorites and data.Favorites[itemId] == true
			local matchesSearch = search == "" or item.Name:lower():find(search, 1, true) or item.Rarity:lower():find(search, 1, true)
			if matchesSearch and (not options.FavoritesOnly or favorite) then
				table.insert(entries, { ItemId = itemId, Item = item, Count = count, Favorite = favorite })
			end
		end
	end
	local compare = comparators[options.Sort or "Rarity"] or comparators.Rarity
	table.sort(entries, function(a, b)
		if a.Favorite ~= b.Favorite then
			return a.Favorite
		end
		return compare(a, b)
	end)
	return entries
end

--[[
	Toolbar: search box + sort cycle button (+ optional favorites toggle).
	Returns api with .State {Search, Sort, FavoritesOnly} and calls onChange().
]]
function ItemList.Toolbar(parent, onChange, includeFavoritesToggle)
	local state = { Search = "", Sort = "Rarity", FavoritesOnly = false }
	local bar = UIKit.new("Frame", {
		Name = "Toolbar",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { UIKit.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })

	local searchFrame = UIKit.new("Frame", {
		Size = UDim2.new(0.42, 0, 1, 0),
		BackgroundColor3 = Theme.Colors.Background,
		LayoutOrder = 1,
		Parent = bar,
	}, { UIKit.Corner(Theme.SmallCorner), UIKit.Stroke(Theme.Colors.Stroke, 2) })
	local searchBox = UIKit.new("TextBox", {
		Size = UDim2.new(1, -20, 1, -8),
		Position = UDim2.fromOffset(10, 4),
		BackgroundTransparency = 1,
		PlaceholderText = "🔍 Search items...",
		PlaceholderColor3 = Theme.Colors.SubText,
		Text = "",
		TextColor3 = Theme.Colors.Text,
		Font = Theme.BodyFont,
		TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		Parent = searchFrame,
	}, { UIKit.new("UITextSizeConstraint", { MaxTextSize = 20 }) })
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		state.Search = searchBox.Text
		onChange()
	end)

	local sortButton
	sortButton = UIKit.Button({
		Text = "Sort: Rarity",
		Size = UDim2.new(0.26, 0, 1, 0),
		Color = Theme.Colors.Blue,
		LayoutOrder = 2,
		TextSize = 20,
		Parent = bar,
		OnClick = function()
			local index = table.find(ItemList.SortModes, state.Sort) or 1
			state.Sort = ItemList.SortModes[index % #ItemList.SortModes + 1]
			sortButton.Label.Text = "Sort: " .. state.Sort
			onChange()
		end,
	})

	if includeFavoritesToggle then
		local favButton
		favButton = UIKit.Button({
			Text = "⭐ All",
			Size = UDim2.new(0.18, 0, 1, 0),
			Color = Theme.Colors.Yellow,
			LayoutOrder = 3,
			TextSize = 20,
			Parent = bar,
			OnClick = function()
				state.FavoritesOnly = not state.FavoritesOnly
				favButton.Label.Text = state.FavoritesOnly and "⭐ Only" or "⭐ All"
				onChange()
			end,
		})
	end

	return { Frame = bar, State = state, SearchBox = searchBox }
end

return ItemList
