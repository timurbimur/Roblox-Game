-- Builds the entire screen UI in code (odds panel, spin panel, inventory
-- panel) and returns a table of references the other client controllers use.
-- Styled bright/bold/rounded on purpose -- this is aimed at a young-kid
-- audience, matching the look of games like Steal a Brainrot / Sol's RNG.

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

local function addGradient(instance, color1, color2, rotation)
	return create("UIGradient", {
		Color = ColorSequence.new(color1, color2),
		Rotation = rotation or 90,
	}, instance)
end

local PANEL_TOP = Color3.fromRGB(112, 56, 214)
local PANEL_BOTTOM = Color3.fromRGB(54, 20, 110)
local ACCENT_GOLD = Color3.fromRGB(255, 214, 64)

local function buildOddsPanel(screenGui)
	local rowHeight = 30
	local panel = create("Frame", {
		Name = "OddsPanel",
		Size = UDim2.fromOffset(250, 48 + rowHeight * #RarityConfig.Order),
		Position = UDim2.fromOffset(20, 20),
		BackgroundColor3 = PANEL_TOP,
	}, screenGui)
	create("UICorner", { CornerRadius = UDim.new(0, 18) }, panel)
	create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 3 }, panel)
	addGradient(panel, PANEL_TOP, PANEL_BOTTOM, 90)

	create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundTransparency = 1,
		Text = "DROP CHANCES",
		Font = Enum.Font.GothamBlack,
		TextSize = 19,
		TextColor3 = ACCENT_GOLD,
		TextStrokeTransparency = 0.3,
	}, panel)

	for i, rarityName in ipairs(RarityConfig.Order) do
		local data = RarityConfig.Rarities[rarityName]
		local row = create("Frame", {
			Size = UDim2.new(1, -16, 0, rowHeight - 4),
			Position = UDim2.fromOffset(8, 38 + (i - 1) * rowHeight),
			BackgroundColor3 = data.Color,
			BackgroundTransparency = 0.82,
		}, panel)
		create("UICorner", { CornerRadius = UDim.new(0, 8) }, row)

		local swatch = create("Frame", {
			Size = UDim2.fromOffset(16, 16),
			Position = UDim2.fromOffset(6, 5),
			BackgroundColor3 = data.Color,
		}, row)
		create("UICorner", { CornerRadius = UDim.new(1, 0) }, swatch)
		create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1.5 }, swatch)

		create("TextLabel", {
			Size = UDim2.new(0.6, -30, 1, 0),
			Position = UDim2.fromOffset(28, 0),
			BackgroundTransparency = 1,
			Text = data.DisplayName,
			TextXAlignment = Enum.TextXAlignment.Left,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = Color3.fromRGB(255, 255, 255),
		}, row)

		create("TextLabel", {
			Size = UDim2.new(0.4, -6, 1, 0),
			Position = UDim2.new(0.6, 0, 0, 0),
			BackgroundTransparency = 1,
			Text = string.format("%.2f%%", RarityConfig.GetPercent(rarityName)),
			TextXAlignment = Enum.TextXAlignment.Right,
			Font = Enum.Font.GothamBlack,
			TextSize = 15,
			TextColor3 = data.Color,
			TextStrokeTransparency = 0.5,
		}, row)
	end

	return panel
end

-- The "reel" that slides a strip of candidate brainrots past a center window
-- while rolling (real slot-machine style), landing exactly on the real
-- result. REEL_WIDTH/SLOT_WIDTH here must match SpinController's constants.
local REEL_WIDTH = 208
local REEL_HEIGHT = 92
local SLOT_WIDTH = 190

local function buildReveal(spinPanel)
	local revealFrame = create("Frame", {
		Name = "RevealFrame",
		Size = UDim2.fromOffset(240, 150),
		Position = UDim2.new(0.5, -120, 0, 18),
		BackgroundColor3 = Color3.fromRGB(40, 18, 74),
	}, spinPanel)
	create("UICorner", { CornerRadius = UDim.new(0, 22) }, revealFrame)
	local stroke = create("UIStroke", {
		Color = Color3.fromRGB(255, 255, 255),
		Thickness = 3,
	}, revealFrame)

	local rarityLabel = create("TextLabel", {
		Name = "RevealRarity",
		Size = UDim2.new(1, -16, 0, 22),
		Position = UDim2.fromOffset(8, 10),
		BackgroundTransparency = 1,
		Text = "???",
		Font = Enum.Font.GothamBlack,
		TextSize = 16,
		TextColor3 = Color3.fromRGB(230, 230, 230),
		TextStrokeTransparency = 0.5,
	}, revealFrame)

	local reelWindow = create("Frame", {
		Name = "ReelWindow",
		Size = UDim2.fromOffset(REEL_WIDTH, REEL_HEIGHT),
		Position = UDim2.fromOffset((240 - REEL_WIDTH) / 2, 40),
		BackgroundColor3 = Color3.fromRGB(24, 10, 44),
		ClipsDescendants = true,
	}, revealFrame)
	create("UICorner", { CornerRadius = UDim.new(0, 14) }, reelWindow)

	local reelTrack = create("Frame", {
		Name = "ReelTrack",
		Size = UDim2.fromOffset(SLOT_WIDTH, REEL_HEIGHT),
		Position = UDim2.fromOffset((REEL_WIDTH - SLOT_WIDTH) / 2, 0),
		BackgroundTransparency = 1,
	}, reelWindow)

	local placeholder = create("TextLabel", {
		Size = UDim2.fromOffset(SLOT_WIDTH, REEL_HEIGHT),
		BackgroundColor3 = Color3.fromRGB(60, 30, 110),
		Text = "???",
		Font = Enum.Font.GothamBlack,
		TextSize = 30,
		TextColor3 = Color3.fromRGB(220, 210, 255),
		TextStrokeTransparency = 0.5,
	}, reelTrack)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, placeholder)
	create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 1.5, Transparency = 0.5 }, placeholder)

	-- Edge fades + center pointer lines for a polished slot-machine look.
	local leftFade = create("Frame", {
		Name = "LeftFade",
		Size = UDim2.fromOffset(26, REEL_HEIGHT),
		BackgroundColor3 = Color3.fromRGB(24, 10, 44),
		BorderSizePixel = 0,
	}, reelWindow)
	create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}, leftFade)

	local rightFade = create("Frame", {
		Name = "RightFade",
		Size = UDim2.fromOffset(26, REEL_HEIGHT),
		Position = UDim2.fromOffset(REEL_WIDTH - 26, 0),
		BackgroundColor3 = Color3.fromRGB(24, 10, 44),
		BorderSizePixel = 0,
	}, reelWindow)
	create("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(1, 0),
		}),
	}, rightFade)

	local centerOffset = (REEL_WIDTH - SLOT_WIDTH) / 2
	create("Frame", {
		Name = "IndicatorLeft",
		Size = UDim2.fromOffset(3, REEL_HEIGHT),
		Position = UDim2.fromOffset(centerOffset, 0),
		BackgroundColor3 = Color3.fromRGB(255, 214, 64),
		BackgroundTransparency = 0.2,
	}, reelWindow)
	create("Frame", {
		Name = "IndicatorRight",
		Size = UDim2.fromOffset(3, REEL_HEIGHT),
		Position = UDim2.fromOffset(centerOffset + SLOT_WIDTH, 0),
		BackgroundColor3 = Color3.fromRGB(255, 214, 64),
		BackgroundTransparency = 0.2,
	}, reelWindow)

	return revealFrame, stroke, rarityLabel, reelTrack
end

local function buildSpinPanel(screenGui)
	local panel = create("Frame", {
		Name = "SpinPanel",
		Size = UDim2.fromOffset(280, 320),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -30),
		BackgroundColor3 = PANEL_TOP,
	}, screenGui)
	create("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
	create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 3 }, panel)
	addGradient(panel, PANEL_TOP, PANEL_BOTTOM, 90)

	local revealFrame, revealStroke, revealRarityLabel, reelTrack = buildReveal(panel)

	local resultLabel = create("TextLabel", {
		Name = "ResultLabel",
		Size = UDim2.new(1, -20, 0, 40),
		Position = UDim2.fromOffset(10, 176),
		BackgroundTransparency = 1,
		Text = "",
		TextWrapped = true,
		Font = Enum.Font.GothamBlack,
		TextSize = 17,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeTransparency = 0.5,
	}, panel)

	local spinButton = create("TextButton", {
		Name = "SpinButton",
		Size = UDim2.new(1, -32, 0, 54),
		Position = UDim2.fromOffset(16, 224),
		BackgroundColor3 = Color3.fromRGB(80, 220, 130),
		Text = "SPIN!",
		Font = Enum.Font.GothamBlack,
		TextSize = 28,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeTransparency = 0.3,
		AutoButtonColor = true,
	}, panel)
	create("UICorner", { CornerRadius = UDim.new(0, 16) }, spinButton)
	create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 3 }, spinButton)
	local spinButtonGradient = addGradient(spinButton, Color3.fromRGB(120, 255, 170), Color3.fromRGB(50, 190, 110), 90)

	local cooldownLabel = create("TextLabel", {
		Name = "CooldownLabel",
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 284),
		BackgroundTransparency = 1,
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 140, 140),
		Visible = false,
	}, panel)

	return {
		SpinPanel = panel,
		RevealFrame = revealFrame,
		RevealStroke = revealStroke,
		RevealRarityLabel = revealRarityLabel,
		ReelTrack = reelTrack,
		ResultLabel = resultLabel,
		SpinButton = spinButton,
		SpinButtonGradient = spinButtonGradient,
		CooldownLabel = cooldownLabel,
	}
end

local function buildInventoryPanel(screenGui)
	local toggleButton = create("TextButton", {
		Name = "InventoryToggleButton",
		Size = UDim2.fromOffset(180, 50),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -20, 0, 20),
		BackgroundColor3 = Color3.fromRGB(255, 170, 40),
		Text = "BRAINROTS",
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 255, 255),
		TextStrokeTransparency = 0.4,
	}, screenGui)
	create("UICorner", { CornerRadius = UDim.new(0, 14) }, toggleButton)
	create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 3 }, toggleButton)
	addGradient(toggleButton, Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 140, 20), 90)

	local panel = create("Frame", {
		Name = "InventoryPanel",
		Size = UDim2.fromOffset(660, 460),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = PANEL_TOP,
		Visible = false,
		ZIndex = 5,
	}, screenGui)
	create("UICorner", { CornerRadius = UDim.new(0, 22) }, panel)
	create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 3 }, panel)
	addGradient(panel, PANEL_TOP, PANEL_BOTTOM, 90)

	create("TextLabel", {
		Size = UDim2.new(1, -80, 0, 44),
		Position = UDim2.fromOffset(20, 12),
		BackgroundTransparency = 1,
		Text = "YOUR BRAINROTS",
		Font = Enum.Font.GothamBlack,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = ACCENT_GOLD,
		TextStrokeTransparency = 0.3,
	}, panel)

	local equippedLabel = create("TextLabel", {
		Name = "EquippedLabel",
		Size = UDim2.new(1, -140, 0, 24),
		Position = UDim2.fromOffset(20, 52),
		BackgroundTransparency = 1,
		Text = "Equipped: 0/3",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Color3.fromRGB(230, 220, 255),
	}, panel)

	local closeButton = create("TextButton", {
		Name = "InventoryCloseButton",
		Size = UDim2.fromOffset(36, 36),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16),
		BackgroundColor3 = Color3.fromRGB(255, 90, 90),
		Text = "X",
		Font = Enum.Font.GothamBlack,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 255, 255),
	}, panel)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, closeButton)
	create("UIStroke", { Color = Color3.fromRGB(255, 255, 255), Thickness = 2 }, closeButton)

	local list = create("ScrollingFrame", {
		Name = "InventoryList",
		Size = UDim2.new(1, -32, 1, -100),
		Position = UDim2.fromOffset(16, 88),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.fromOffset(0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = ACCENT_GOLD,
	}, panel)
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(150, 200),
		CellPadding = UDim2.fromOffset(14, 14),
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
