-- Renders the "Your Brainrots" panel from server-pushed inventory/equipped data
-- and lets the player equip/unequip owned brainrots.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Modules.BrainrotConfig)
local RarityConfig = require(ReplicatedStorage.Modules.RarityConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local InventoryUpdated = Remotes:WaitForChild("InventoryUpdated")
local RequestEquip = Remotes:WaitForChild("RequestEquip")
local RequestUnequip = Remotes:WaitForChild("RequestUnequip")

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

local function buildCard(parent, brainrotId, count, isEquipped)
	local data = BrainrotConfig.ById[brainrotId]
	if not data then
		return
	end
	local rarity = RarityConfig.Rarities[data.Rarity]

	local card = create("Frame", {
		Name = brainrotId,
		BackgroundColor3 = Color3.fromRGB(28, 28, 38),
	}, parent)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, card)
	create("UIStroke", { Color = rarity.Color, Thickness = 2 }, card)

	create("Frame", {
		Size = UDim2.new(1, -16, 0, 70),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = rarity.Color,
	}, card)

	create("TextLabel", {
		Size = UDim2.new(1, -16, 0, 36),
		Position = UDim2.fromOffset(8, 82),
		BackgroundTransparency = 1,
		Text = data.Name,
		TextWrapped = true,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}, card)

	create("TextLabel", {
		Size = UDim2.new(1, -16, 0, 18),
		Position = UDim2.fromOffset(8, 118),
		BackgroundTransparency = 1,
		Text = string.format("%s  x%d", rarity.DisplayName, count),
		Font = Enum.Font.Gotham,
		TextSize = 12,
		TextColor3 = rarity.Color,
	}, card)

	local button = create("TextButton", {
		Size = UDim2.new(1, -16, 0, 28),
		Position = UDim2.fromOffset(8, 138),
		BackgroundColor3 = isEquipped and Color3.fromRGB(180, 60, 60) or Color3.fromRGB(60, 160, 90),
		Text = isEquipped and "Unequip" or "Equip",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}, card)
	create("UICorner", { CornerRadius = UDim.new(0, 6) }, button)

	button.MouseButton1Click:Connect(function()
		if isEquipped then
			RequestUnequip:FireServer(brainrotId)
		else
			RequestEquip:FireServer(brainrotId)
		end
	end)

	return card
end

local function render(ui, inventory, equipped)
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
		buildCard(ui.InventoryList, id, inventory[id], equippedSet[id] == true)
	end

	ui.EquippedLabel.Text = string.format("Equipped: %d/%d", #equipped, MAX_SLOTS)
end

function InventoryController.Init(ui)
	ui.InventoryToggleButton.MouseButton1Click:Connect(function()
		ui.InventoryPanel.Visible = not ui.InventoryPanel.Visible
	end)

	ui.InventoryCloseButton.MouseButton1Click:Connect(function()
		ui.InventoryPanel.Visible = false
	end)

	InventoryUpdated.OnClientEvent:Connect(function(inventory, equipped)
		render(ui, inventory, equipped)
	end)
end

return InventoryController
