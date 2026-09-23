--[[
	FusionPanel
	-----------
	The fusion machine UI.
	  Left:   two ingredient slots + result preview + FUSE button + progress
	  Right:  tabs — "Items" (your inventory, tap to fill a slot) and
	          "Recipe Book" (recipes whose ingredients you've discovered; results
	          stay ??? until you make them — Pokedex style)

	The preview only reveals a result you've already discovered. Unknown
	recipes show "???"; no-recipe combos warn that they'll produce goo.
	The server decides the real result.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)
local FusionRecipes = require(Shared.Data.FusionRecipes)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local ClientRoot = script.Parent.Parent
local UIKit = require(ClientRoot.UI.UIKit)
local Theme = require(ClientRoot.UI.Theme)
local ItemList = require(ClientRoot.UI.ItemList)
local State = require(ClientRoot.Lib.State)
local Net = require(ClientRoot.Lib.Net)

local FusionPanel = {}

local Controllers
local window, grid, toolbar, recipeList, itemsTab, recipesTab
local slots = {}
local resultCell, resultLabel, fuseButton, progressBar
local slotItems = { nil, nil }
local fusing = false
local activeTab = "Items"

local function available(data, itemId, slotIndex)
	local owned = data.Inventory[itemId] or 0
	local other = slotItems[slotIndex == 1 and 2 or 1]
	if other == itemId then
		owned -= 1
	end
	return owned
end

local function refreshSlots()
	local data = State.Data
	if not data then
		return
	end
	for index = 1, 2 do
		local itemId = slotItems[index]
		if itemId and available(data, itemId, index) < 1 then
			slotItems[index] = nil
			itemId = nil
		end
		local slot = slots[index]
		if itemId then
			slot.Cell.Set(itemId, { ShowName = true })
			slot.Cell.Button.Visible = true
			slot.Placeholder.Visible = false
		else
			slot.Cell.Button.Visible = false
			slot.Placeholder.Visible = true
		end
	end

	local a, b = slotItems[1], slotItems[2]
	if a and b then
		local result = FusionRecipes.Lookup(a, b)
		if result and data.Discovered[result] then
			resultCell.Set(result, { ShowName = true })
			resultCell.Button.Visible = true
			resultLabel.Text = "Known recipe!"
			resultLabel.TextColor3 = Theme.Colors.Green
		elseif result then
			resultCell.Set(result, { Hidden = true, ShowName = true })
			resultCell.Button.Visible = true
			resultLabel.Text = "✨ Undiscovered recipe!"
			resultLabel.TextColor3 = Theme.Colors.Yellow
		else
			resultCell.Button.Visible = false
			resultLabel.Text = "No known recipe — this will make goo 🟢"
			resultLabel.TextColor3 = Theme.Colors.SubText
		end
		fuseButton:SetAttribute("Disabled", fusing or data.PendingFusion ~= false)
	else
		resultCell.Button.Visible = false
		resultLabel.Text = "Pick two items to fuse"
		resultLabel.TextColor3 = Theme.Colors.SubText
		fuseButton:SetAttribute("Disabled", true)
	end
	local duration = Formulas.GetFusionDuration(data, data.Passes)
	fuseButton.Label.Text = ("⚗️ FUSE (%.1fs)"):format(duration)
end

local function renderItems()
	local data = State.Data
	if not data then
		return
	end
	local entries = ItemList.Build(data, toolbar.State)
	for _, entry in ipairs(entries) do
		local used = 0
		if slotItems[1] == entry.ItemId then
			used += 1
		end
		if slotItems[2] == entry.ItemId then
			used += 1
		end
		entry.Count = entry.Count - used
		entry.Selected = used > 0
	end
	grid.Render(entries)
end

local recipeRows = {}
local function renderRecipes()
	local data = State.Data
	if not data then
		return
	end
	local shown = 0
	for index, recipe in ipairs(FusionRecipes.List) do
		local knowsA, knowsB = data.Discovered[recipe.A], data.Discovered[recipe.B]
		local row = recipeRows[index]
		if knowsA and knowsB then
			shown += 1
			if not row then
				row = UIKit.Card({ Size = UDim2.new(1, 0, 0, 64), Parent = recipeList })
				row.Name = "Recipe" .. index
				UIKit.Label({ Name = "Text", Size = UDim2.new(0.72, -10, 1, -10), Position = UDim2.fromOffset(12, 5), TextXAlignment = Enum.TextXAlignment.Left, Parent = row }, 20)
				UIKit.Button({
					Name = "Use",
					Text = "Use",
					Color = Theme.Colors.Purple,
					Size = UDim2.new(0.25, 0, 1, -14),
					Position = UDim2.new(1, -8, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5),
					TextSize = 20,
					Parent = row,
					OnClick = function()
						local d = State.Data
						if fusing or not d then
							return
						end
						slotItems[1], slotItems[2] = nil, nil
						if available(d, recipe.A, 1) < 1 then
							Net.OnError("You don't have " .. Items.ById[recipe.A].Name .. " right now.")
							return
						end
						slotItems[1] = recipe.A
						if available(d, recipe.B, 2) < 1 then
							slotItems[1] = nil
							Net.OnError("You don't have " .. Items.ById[recipe.B].Name .. " right now.")
							return
						end
						slotItems[2] = recipe.B
						refreshSlots()
					end,
				})
				recipeRows[index] = row
			end
			local itemA, itemB, result = Items.ById[recipe.A], Items.ById[recipe.B], Items.ById[recipe.Result]
			local known = data.Discovered[recipe.Result]
			local resultRarity = Config.RarityByName[result.Rarity]
			row.Text.Text = ("%s %s + %s %s  =  %s"):format(
				itemA.Icon, itemA.Name, itemB.Icon, itemB.Name,
				known and (result.Icon .. " " .. result.Name) or "❓ ???????")
			row.UIStroke.Color = known and resultRarity.Color or Theme.Colors.Stroke
			row.LayoutOrder = known and (1000 + index) or index
			row.Visible = true
		elseif row then
			row.Visible = false
		end
	end
	FusionPanel.RecipeCount.Text = ("Recipes found: %d / %d  •  Discover ingredients to reveal more!"):format(shown, #FusionRecipes.List)
end

local function render()
	if not window.Visible then
		return
	end
	refreshSlots()
	if activeTab == "Items" then
		renderItems()
	else
		renderRecipes()
	end
end

local function placeItem(itemId)
	local data = State.Data
	if fusing or not data then
		return
	end
	for index = 1, 2 do
		if not slotItems[index] then
			if available(data, itemId, index) >= 1 then
				slotItems[index] = itemId
				render()
			else
				Net.OnError("You need another one of those to fuse it with itself.")
			end
			return
		end
	end
	-- Both full: replace the second slot.
	if available(data, itemId, 2) >= 1 or slotItems[2] == itemId then
		slotItems[2] = itemId
		render()
	end
end

local function fuse()
	local a, b = slotItems[1], slotItems[2]
	if fusing or not (a and b) then
		return
	end
	fusing = true
	fuseButton:SetAttribute("Disabled", true)
	Net.RequestAsync("Fuse", { A = a, B = b }, function(success)
		if not success then
			fusing = false
			refreshSlots()
		end
	end)
end

local function onFusionStarted(payload)
	fusing = true
	if Controllers.SoundController then
		Controllers.SoundController.Play("FusionStart", 0.6)
	end
	-- Shake the slots and run the progress bar.
	progressBar.Frame.Visible = true
	progressBar.Set(0, "Fusing...", true)
	progressBar.Fill.Size = UDim2.fromScale(0, 1)
	progressBar.Fill.Visible = true
	UIKit.Tween(progressBar.Fill, payload.Duration, { Size = UDim2.fromScale(1, 1) }, Enum.EasingStyle.Linear)
	for _, slot in ipairs(slots) do
		task.spawn(function()
			local frame = slot.Frame
			local start = os.clock()
			while os.clock() - start < payload.Duration and frame.Parent do
				frame.Rotation = math.random(-6, 6)
				task.wait(0.05)
			end
			frame.Rotation = 0
		end)
	end
end

local function onFusionComplete(payload)
	fusing = false
	progressBar.Frame.Visible = false
	slotItems[1], slotItems[2] = nil, nil
	local item = Items.ById[payload.ItemId]
	if Controllers.SoundController then
		Controllers.SoundController.Play("FusionComplete", 0.6)
	end
	if item then
		local extra = payload.Count > 1 and "x2 (Fusion Master!)" or Util.FormatCash(item.Value)
		Controllers.Notifications.ItemPopup(payload.ItemId, payload.IsNew, extra)
		if window.Visible then
			-- Result reveal pop.
			resultCell.Set(payload.ItemId, { ShowName = true, New = payload.IsNew })
			resultCell.Button.Visible = true
			resultLabel.Text = payload.IsNew and "🎉 NEW DISCOVERY!" or "Fusion complete!"
			resultLabel.TextColor3 = Config.RarityByName[item.Rarity].Color
			local scale = resultCell.Button:FindFirstChildOfClass("UIScale")
			if scale then
				scale.Scale = 0.2
				UIKit.Tween(scale, 0.45, { Scale = 1.15 }, Enum.EasingStyle.Back).Completed:Connect(function()
					UIKit.Tween(scale, 0.2, { Scale = 1 })
				end)
			end
			task.delay(1.6, function()
				if not fusing then
					render()
				end
			end)
			if activeTab == "Items" then
				renderItems()
			end
			return
		end
	end
	render()
end

function FusionPanel.Init(controllers)
	Controllers = controllers
	local content
	window, content = UIKit.Window({
		Name = "FusionWindow",
		Title = "Fusion Machine",
		Icon = "⚗️",
		Color = Theme.Colors.Purple,
		Parent = controllers.UIController.Root,
		OnClose = function()
			controllers.UIController.Close()
		end,
	})

	-- LEFT: machine
	local machine = UIKit.Card({
		Size = UDim2.new(0.4, -6, 1, 0),
		Color = Theme.Colors.Background,
		Parent = content,
	})
	local slotRow = UIKit.new("Frame", {
		Size = UDim2.new(1, -20, 0.36, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		Parent = machine,
	})
	for index = 1, 2 do
		local frame = UIKit.new("Frame", {
			Name = "Slot" .. index,
			Size = UDim2.new(0.4, 0, 1, 0),
			Position = UDim2.fromScale(index == 1 and 0.22 or 0.78, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = Theme.Colors.PanelLight,
			Parent = slotRow,
		}, { UIKit.Corner(Theme.CornerRadius), UIKit.Stroke(Theme.Colors.Purple, 3), UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
		local placeholder = UIKit.Label({ Text = "Slot " .. index .. "\nTap an item", Size = UDim2.fromScale(0.8, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), TextColor3 = Theme.Colors.SubText, Parent = frame }, 18)
		local cell = UIKit.ItemCell(frame)
		cell.Button.Size = UDim2.fromScale(1, 1)
		cell.Button.Visible = false
		cell.Button.Activated:Connect(function()
			if not fusing then
				slotItems[index] = nil
				render()
			end
		end)
		slots[index] = { Frame = frame, Cell = cell, Placeholder = placeholder }
	end
	UIKit.Label({ Text = "+", Size = UDim2.fromScale(0.16, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = slotRow }, 60)

	UIKit.Label({ Text = "⬇", Size = UDim2.new(1, 0, 0.07, 0), Position = UDim2.fromScale(0.5, 0.39), AnchorPoint = Vector2.new(0.5, 0), Parent = machine }, 34)

	local resultFrame = UIKit.new("Frame", {
		Size = UDim2.new(0.34, 0, 0.26, 0),
		Position = UDim2.fromScale(0.5, 0.47),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Colors.PanelLight,
		Parent = machine,
	}, { UIKit.Corner(Theme.CornerRadius), UIKit.Stroke(Theme.Colors.Yellow, 3), UIKit.new("UIAspectRatioConstraint", { AspectRatio = 1 }) })
	resultCell = UIKit.ItemCell(resultFrame)
	resultCell.Button.Size = UDim2.fromScale(1, 1)
	resultCell.Button.Visible = false
	resultLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -16, 0.07, 0), Position = UDim2.fromScale(0.5, 0.75), AnchorPoint = Vector2.new(0.5, 0), Parent = machine }, 20)

	progressBar = UIKit.ProgressBar({
		Size = UDim2.new(1, -24, 0, 22),
		Position = UDim2.new(0.5, 0, 0.83, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Theme.Colors.Purple,
		Parent = machine,
	})
	progressBar.Frame.Visible = false

	fuseButton = UIKit.Button({
		Text = "⚗️ FUSE",
		Color = Theme.Colors.Purple,
		Size = UDim2.new(1, -24, 0, 50),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		TextSize = 28,
		Parent = machine,
		OnClick = fuse,
	})

	-- RIGHT: tabs
	local right = UIKit.new("Frame", {
		Size = UDim2.new(0.6, -6, 1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Parent = content,
	})
	itemsTab = UIKit.new("Frame", { Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 48), BackgroundTransparency = 1, Parent = right })
	recipesTab = UIKit.new("Frame", { Size = UDim2.new(1, 0, 1, -48), Position = UDim2.fromOffset(0, 48), BackgroundTransparency = 1, Visible = false, Parent = right })
	local tabs = UIKit.Tabs(right, { "Items", "Recipe Book" }, function(name)
		activeTab = name == "Items" and "Items" or "Recipes"
		itemsTab.Visible = activeTab == "Items"
		recipesTab.Visible = activeTab == "Recipes"
		render()
	end)

	toolbar = ItemList.Toolbar(itemsTab, renderItems, false)
	grid = UIKit.ItemGrid({
		Size = UDim2.new(1, 0, 1, -52),
		Position = UDim2.fromOffset(0, 52),
		CellSize = 84,
		Parent = itemsTab,
		OnClick = placeItem,
	})

	FusionPanel.RecipeCount = UIKit.Label({ Text = "", Size = UDim2.new(1, 0, 0, 26), TextColor3 = Theme.Colors.SubText, Parent = recipesTab }, 18)
	recipeList = UIKit.ScrollList({ Size = UDim2.new(1, 0, 1, -32), Position = UDim2.fromOffset(0, 32), Parent = recipesTab })

	controllers.UIController.RegisterPanel("Fusion", {
		Window = window,
		OnOpen = function()
			tabs.Select(activeTab == "Items" and "Items" or "Recipe Book")
		end,
	})
end

function FusionPanel.Start()
	State.Watch("Inventory", render)
	State.Watch("Discovered", render)
	State.Watch("PendingFusion", function(pending)
		if not pending and fusing then
			-- Server finished (FusionComplete signal handles visuals).
			return
		end
		if window.Visible then
			refreshSlots()
		end
	end)
	Remotes.Signal.OnClientEvent:Connect(function(kind, payload)
		if kind == "FusionStarted" then
			onFusionStarted(payload)
		elseif kind == "FusionComplete" then
			onFusionComplete(payload)
		end
	end)
end

return FusionPanel
