-- Renders the "Your Brainrots" panel and lets the player equip/unequip owned
-- brainrots via EquipFunction/UnequipFunction (RemoteFunctions -- every click
-- gets an explicit success/failure response, never a silent no-op).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Modules.BrainrotConfig)
local RarityConfig = require(ReplicatedStorage.Modules.RarityConfig)
local RemoteHelpers = require(ReplicatedStorage.Modules.RemoteHelpers)
local BrainrotVisuals = require(ReplicatedStorage.Modules.BrainrotVisuals)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryUpdated = Remotes:WaitForChild("InventoryUpdated")
local EquipFunction = Remotes:WaitForChild("EquipFunction")
local UnequipFunction = Remotes:WaitForChild("UnequipFunction")

local MAX_SLOTS = 3

local InventoryController = {}

local function create(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

function InventoryController.Init(ui)
	local render -- forward-declared: buildCard's button handler calls back into it

	local function buildCard(brainrotId, count, isEquipped)
		local data = BrainrotConfig.ById[brainrotId]
		if not data then
			return
		end
		local rarity = RarityConfig.Rarities[data.Rarity]

		local card = create("Frame", {
			Name = brainrotId,
			BackgroundColor3 = Color3.fromRGB(35, 22, 60),
		}, ui.InventoryList)
		create("UICorner", { CornerRadius = UDim.new(0, 14) }, card)
		create("UIStroke", { Color = rarity.Color, Thickness = 3 }, card)

		local thumbnailFrame = create("Frame", {
			Size = UDim2.new(1, -16, 0, 84),
			Position = UDim2.fromOffset(8, 8),
			BackgroundColor3 = Color3.fromRGB(20, 12, 36),
		}, card)
		create("UICorner", { CornerRadius = UDim.new(0, 10) }, thumbnailFrame)
		BrainrotVisuals.BuildThumbnail(data, thumbnailFrame)

		create("TextLabel", {
			Size = UDim2.new(1, -16, 0, 30),
			Position = UDim2.fromOffset(8, 96),
			BackgroundTransparency = 1,
			Text = data.Name,
			TextWrapped = true,
			Font = Enum.Font.GothamBlack,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextStrokeTransparency = 0.4,
		}, card)

		create("TextLabel", {
			Size = UDim2.new(1, -16, 0, 16),
			Position = UDim2.fromOffset(8, 128),
			BackgroundTransparency = 1,
			Text = string.format("%s  x%d", rarity.DisplayName, count),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = rarity.Color,
		}, card)

		create("TextLabel", {
			Size = UDim2.new(1, -16, 0, 14),
			Position = UDim2.fromOffset(8, 144),
			BackgroundTransparency = 1,
			Text = BrainrotVisuals.GetOddsText(data),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = Color3.fromRGB(255, 221, 120),
		}, card)

		local button = create("TextButton", {
			Size = UDim2.new(1, -16, 0, 30),
			Position = UDim2.fromOffset(8, 162),
			BackgroundColor3 = isEquipped and Color3.fromRGB(255, 90, 90) or Color3.fromRGB(80, 220, 130),
			Text = isEquipped and "UNEQUIP" or "EQUIP!",
			Font = Enum.Font.GothamBlack,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextStrokeTransparency = 0.5,
		}, card)
		create("UICorner", { CornerRadius = UDim.new(0, 8) }, button)
		create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2, Transparency = 0.3 }, button)

		button.MouseButton1Click:Connect(function()
			local originalText = button.Text
			button.Text = "..."
			button.Active = false

			local remote = isEquipped and UnequipFunction or EquipFunction
			local ok, result = RemoteHelpers.InvokeWithTimeout(remote, 5, brainrotId)

			if ok and result and result.Success then
				render(result.Inventory, result.Equipped)
				return
			end

			button.Text = originalText
			button.Active = true
			if ui.ShowDebug then
				local reason = ok and result and result.Reason or tostring(result)
				ui.ShowDebug("Equip/unequip failed.\nReason: " .. tostring(reason))
			end
		end)
	end

	render = function(inventory, equipped)
		for _, child in ipairs(ui.InventoryList:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		local equippedSet = {}
		for _, id in ipairs(equipped) do
			equippedSet[id] = true
		end

		local ids = {}
		for id in pairs(inventory) do
			table.insert(ids, id)
		end
		table.sort(ids, function(a, b)
			local dataA = BrainrotConfig.ById[a]
			local dataB = BrainrotConfig.ById[b]
			if not dataA or not dataB then
				return false
			end
			return dataA.Value > dataB.Value
		end)

		for _, id in ipairs(ids) do
			buildCard(id, inventory[id], equippedSet[id] == true)
		end

		ui.EquippedLabel.Text = string.format("Equipped: %d/%d", #equipped, MAX_SLOTS)
	end

	ui.RefreshInventory = render

	ui.InventoryToggleButton.MouseButton1Click:Connect(function()
		ui.InventoryPanel.Visible = not ui.InventoryPanel.Visible
	end)

	ui.InventoryCloseButton.MouseButton1Click:Connect(function()
		ui.InventoryPanel.Visible = false
	end)

	InventoryUpdated.OnClientEvent:Connect(function(inventory, equipped)
		render(inventory, equipped)
	end)
end

return InventoryController
