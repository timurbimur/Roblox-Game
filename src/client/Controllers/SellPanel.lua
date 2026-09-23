--[[
	SellPanel
	---------
	Opened from a Sell Station. Tap items to select whole stacks, then:
	  Sell Selected | Sell Duplicates (keeps one of each) | Sell All
	Favorites are shown locked and can't be selected. Previews show the value
	with your cash multiplier; the server recomputes everything on sale.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)
local Util = require(Shared.Util)

local ClientRoot = script.Parent.Parent
local UIKit = require(ClientRoot.UI.UIKit)
local Theme = require(ClientRoot.UI.Theme)
local ItemList = require(ClientRoot.UI.ItemList)
local State = require(ClientRoot.Lib.State)
local Net = require(ClientRoot.Lib.Net)

local SellPanel = {}

local window, grid, toolbar
local summaryLabel
local selected = {} -- [itemId] = true
local busy = false

local function computeTotals(data)
	local mult = Formulas.GetCashMultiplier(data, data.Passes)
	local selectedValue, selectedCount = 0, 0
	local dupValue, allValue = 0, 0
	for itemId, count in pairs(data.Inventory) do
		local item = Items.ById[itemId]
		if item and not data.Favorites[itemId] then
			allValue += item.Value * count
			if count > 1 then
				dupValue += item.Value * (count - 1)
			end
			if selected[itemId] then
				selectedValue += item.Value * count
				selectedCount += count
			end
		end
	end
	return selectedValue * mult, selectedCount, dupValue * mult, allValue * mult
end

local function render()
	local data = State.Data
	if not data or not window.Visible then
		return
	end
	-- Drop selections for items no longer owned.
	for itemId in pairs(selected) do
		if not data.Inventory[itemId] or data.Favorites[itemId] then
			selected[itemId] = nil
		end
	end
	local entries = ItemList.Build(data, toolbar.State)
	for _, entry in ipairs(entries) do
		entry.Selected = selected[entry.ItemId] == true
		entry.Locked = entry.Favorite
	end
	grid.Render(entries)

	local selectedValue, selectedCount, dupValue, allValue = computeTotals(data)
	summaryLabel.Text = ("Selected: %d items  •  %s"):format(selectedCount, Util.FormatCash(selectedValue))
	SellPanel.Buttons.Selected.Label.Text = "Sell Selected\n" .. Util.FormatCash(selectedValue)
	SellPanel.Buttons.Duplicates.Label.Text = "Sell Duplicates\n" .. Util.FormatCash(dupValue)
	SellPanel.Buttons.All.Label.Text = "Sell All\n" .. Util.FormatCash(allValue)
end

local function sell(mode)
	if busy then
		return
	end
	local payload = { Mode = mode }
	if mode == "Selected" then
		local data = State.Data
		payload.Items = {}
		for itemId in pairs(selected) do
			payload.Items[itemId] = data.Inventory[itemId] or 0
		end
		if next(payload.Items) == nil then
			return
		end
	end
	busy = true
	Net.RequestAsync("Sell", payload, function(success)
		busy = false
		if success then
			table.clear(selected)
			render()
		end
	end)
end

function SellPanel.Init(controllers)
	local content
	window, content = UIKit.Window({
		Name = "SellWindow",
		Title = "Sell Station",
		Icon = "💰",
		Color = Theme.Colors.Green,
		Parent = controllers.UIController.Root,
		OnClose = function()
			controllers.UIController.Close()
		end,
	})

	toolbar = ItemList.Toolbar(content, render, false)
	summaryLabel = UIKit.Label({ Text = "", Size = UDim2.new(0.28, 0, 1, 0), LayoutOrder = 4, Parent = toolbar.Frame }, 18)

	grid = UIKit.ItemGrid({
		Size = UDim2.new(1, 0, 1, -130),
		Position = UDim2.fromOffset(0, 52),
		Parent = content,
		OnClick = function(itemId)
			local data = State.Data
			if data.Favorites[itemId] then
				Net.OnError("⭐ Favorites can't be sold. Unfavorite it in your Inventory first.")
				return
			end
			selected[itemId] = not selected[itemId] or nil
			render()
		end,
	})

	local buttonRow = UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 66),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		BackgroundTransparency = 1,
		Parent = content,
	}, { UIKit.List(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center) })
	SellPanel.Buttons = {
		Selected = UIKit.Button({ Text = "Sell Selected", Color = Theme.Colors.Blue, Size = UDim2.new(0.31, 0, 1, 0), LayoutOrder = 1, TextSize = 22, Parent = buttonRow, OnClick = function() sell("Selected") end }),
		Duplicates = UIKit.Button({ Text = "Sell Duplicates", Color = Theme.Colors.Orange, Size = UDim2.new(0.31, 0, 1, 0), LayoutOrder = 2, TextSize = 22, Parent = buttonRow, OnClick = function() sell("Duplicates") end }),
		All = UIKit.Button({ Text = "Sell All", Color = Theme.Colors.Green, Size = UDim2.new(0.31, 0, 1, 0), LayoutOrder = 3, TextSize = 22, Parent = buttonRow, OnClick = function() sell("All") end }),
	}

	controllers.UIController.RegisterPanel("Sell", {
		Window = window,
		OnOpen = render,
		OnClose = function()
			table.clear(selected)
		end,
	})
end

function SellPanel.Start()
	State.Watch("Inventory", render)
	State.Watch("Favorites", render)
end

return SellPanel
