-- Builds the entire screen UI in code (odds panel, dice/spin panel, inventory
-- panel) and returns a table of references the other client controllers use.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RarityConfig = require(ReplicatedStorage.Modules.RarityConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local UIController = {}

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

local function buildOddsPanel(screenGui)
	local rowHeight = 24
	local panel = create("Frame", {
		Name = "OddsPanel",
		Size = UDim2.fromOffset(230, 40 + rowHeight * #RarityConfig.Order),
		Position = UDim2.fromOffset(20, 20),
		BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		BackgroundTransparency = 0.1,
	}, screenGui)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)
	create("UIStroke", { Color = Color3.fromRGB(60, 60, 80), Thickness = 1.5 }, panel)

	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 32),
		BackgroundTransparency = 1,
		Text = "DROP CHANCES",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}, panel)

	for i, rarityName in ipairs(RarityConfig.Order) do
		local data = RarityConfig.Rarities[rarityName]
		local row = create("Frame", {
			Size = UDim2.new(1, -16, 0, rowHeight - 2),
			Position = UDim2.fromOffset(8, 32 + (i - 1) * rowHeight),
			BackgroundTransparency = 1,
		}, panel)

		local swatch = create("Frame", {
			Size = UDim2.fromOffset(14, 14),
			Position = UDim2.fromOffset(0, 4),
			BackgroundColor3 = data.Color,
		}, row)
		create("UICorner", { CornerRadius = UDim.new(1, 0) }, swatch)

		create("TextLabel", {
			Size = UDim2.new(0.6, -20, 1, 0),
			Position = UDim2.fromOffset(20, 0),
			BackgroundTransparency = 1,
			Text = data.DisplayName,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.Gotham,
			TextSize = 14,
			TextColor3 = Color3.fromRGB(230, 230, 230),
		}, row)

		create("TextLabel", {
			Size = UDim2.new(0.4, 0, 1, 0),
			Position = UDim2.new(0.6, 0, 0, 0),
			BackgroundTransparency = 1,
			Text = string.format("%.2f%%", RarityConfig.GetPercent(rarityName)),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextColor3 = data.Color,
		}, row)
	end

	return panel
end

-- The "reel" that cycles through candidate brainrots while rolling, then lands
-- on the real result (a slot-machine style reveal rather than a generic die).
local function buildReveal(spinPanel)
	local revealFrame = create("Frame", {
		Name = "RevealFrame",
		Size = UDim2.fromOffset(220, 140),
		Position = UDim2.new(0.5, -110, 0, 16),
		BackgroundColor3 = Color3.fromRGB(30, 30, 40),
	}, spinPanel)
	create("UICorner", { CornerRadius = UDim.new(0, 18) }, revealFrame)
	local stroke = create("UIStroke", {
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 2,
		Transparency = 0.3,
	}, revealFrame)

	local rarityLabel = create("TextLabel", {
		Name = "RevealRarity",
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(8, 10),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(200, 200, 200),
	}, revealFrame)

	local nameLabel = create("TextLabel", {
		Name = "RevealName",
		Size = UDim2.new(1, -16, 0, 90),
		Position = UDim2.fromOffset(8, 34),
		BackgroundTransparency = 1,
		Text = "???",
		TextWrapped = true,
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}, revealFrame)

	return revealFrame, stroke, rarityLabel, nameLabel
end

local function buildSpinPanel(screenGui)
	local panel = create("Frame", {
		Name = "SpinPanel",
		Size = UDim2.fromOffset(260, 300),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		BackgroundTransparency = 0.1,
	}, screenGui)
	create("UICorner", { CornerRadius = UDim.new(0, 16) }, panel)
	create("UIStroke", { Color = Color3.fromRGB(60, 60, 80), Thickness = 1.5 }, panel)

	local revealFrame, revealStroke, revealRarityLabel, revealNameLabel = buildReveal(panel)

	local resultLabel = create("TextLabel", {
		Name = "ResultLabel",
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 164),
		BackgroundTransparency = 1,
		Text = "",
		TextWrapped = true,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}, panel)

	local spinButton = create("TextButton", {
		Name = "SpinButton",
		Size = UDim2.new(1, -32, 0, 48),
		Position = UDim2.fromOffset(16, 212),
		BackgroundColor3 = Color3.fromRGB(90, 160, 255),
		Text = "SPIN",
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		AutoButtonColor = true,
	}, panel)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, spinButton)

	local cooldownLabel = create("TextLabel", {
		Name = "CooldownLabel",
		Size = UDim2.new(1, -20, 0, 24),
		Position = UDim2.fromOffset(10, 268),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(255, 120, 120),
		Visible = false,
	}, panel)

	return {
		SpinPanel = panel,
		RevealFrame = revealFrame,
		RevealStroke = revealStroke,
		RevealRarityLabel = revealRarityLabel,
		RevealNameLabel = revealNameLabel,
		ResultLabel = resultLabel,
		SpinButton = spinButton,
		CooldownLabel = cooldownLabel,
	}
end

local function buildInventoryPanel(screenGui)
	local toggleButton = create("TextButton", {
		Name = "InventoryToggleButton",
		Size = UDim2.fromOffset(160, 44),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		BackgroundColor3 = Color3.fromRGB(20, 20, 28),
		Text = "BRAINROTS",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}, screenGui)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, toggleButton)
	create("UIStroke", { Color = Color3.fromRGB(60, 60, 80), Thickness = 1.5 }, toggleButton)

	local panel = create("Frame", {
		Name = "InventoryPanel",
		Size = UDim2.fromOffset(600, 420),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(18, 18, 24),
		Visible = false,
		ZIndex = 5,
	}, screenGui)
	create("UICorner", { CornerRadius = UDim.new(0, 16) }, panel)
	create("UIStroke", { Color = Color3.fromRGB(60, 60, 80), Thickness = 1.5 }, panel)

	create("TextLabel", {
		Size = UDim2.new(1, -80, 0, 40),
		Position = UDim2.fromOffset(20, 12),
		BackgroundTransparency = 1,
		Text = "YOUR BRAINROTS",
		Font = Enum.Font.GothamBold,
		TextSize = 20,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}, panel)

	local equippedLabel = create("TextLabel", {
		Name = "EquippedLabel",
		Size = UDim2.new(1, -140, 0, 24),
		Position = UDim2.fromOffset(20, 46),
		BackgroundTransparency = 1,
		Text = "Equipped: 0/3",
		Font = Enum.Font.Gotham,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(180, 180, 190),
	}, panel)

	local closeButton = create("TextButton", {
		Name = "InventoryCloseButton",
		Size = UDim2.fromOffset(32, 32),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		BackgroundColor3 = Color3.fromRGB(60, 60, 75),
		Text = "X",
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}, panel)
	create("UICorner", { CornerRadius = UDim.new(0, 8) }, closeButton)

	local list = create("ScrollingFrame", {
		Name = "InventoryList",
		Size = UDim2.new(1, -32, 1, -100),
		Position = UDim2.fromOffset(16, 84),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
	}, panel)
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(140, 170),
		CellPadding = UDim2.fromOffset(12, 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, list)

	return {
		InventoryToggleButton = toggleButton,
		InventoryPanel = panel,
		InventoryCloseButton = closeButton,
		InventoryList = list,
		EquippedLabel = equippedLabel,
	}
end

function UIController.Init()
	local screenGui = create("ScreenGui", {
		Name = "SpinABrainrotGui",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	local ui = {
		ScreenGui = screenGui,
	}

	buildOddsPanel(screenGui)

	local spinRefs = buildSpinPanel(screenGui)
	for key, value in pairs(spinRefs) do
		ui[key] = value
	end

	local inventoryRefs = buildInventoryPanel(screenGui)
	for key, value in pairs(inventoryRefs) do
		ui[key] = value
	end

	return ui
end

return UIController
