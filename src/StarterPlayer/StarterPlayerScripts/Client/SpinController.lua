-- Drives the reel animation: slides a strip of weighted-random candidate
-- brainrots past a center window (real slot-machine style) before landing
-- exactly on the brainrot the server actually awarded. The cycling is purely
-- cosmetic flavor -- the true result always comes from
-- SpinFunction:InvokeServer().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local RarityConfig = require(ReplicatedStorage.Modules.RarityConfig)
local BrainrotConfig = require(ReplicatedStorage.Modules.BrainrotConfig)
local RemoteHelpers = require(ReplicatedStorage.Modules.RemoteHelpers)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local SpinFunction = Remotes:WaitForChild("SpinFunction")

local SpinController = {}

local rolling = false
local spinRandom = Random.new()

local DISABLED_COLOR = Color3.fromRGB(90, 85, 110)

-- Must match UIController's REEL_WIDTH/REEL_HEIGHT/SLOT_WIDTH constants.
local SLOT_WIDTH = 190
local REEL_WINDOW_WIDTH = 208
local REEL_HEIGHT = 92
local ROLL_DURATION = 2.2
local NUM_SLOTS = 26

-- Weighted so the reel visually favors common brainrots and only rarely
-- flashes a high rarity while scrolling -- matches the real odds instead of
-- showing every brainrot with equal likelihood.
local function weightedRandomBrainrot()
	local list = BrainrotConfig.List
	local totalWeight = 0
	for _, entry in ipairs(list) do
		local rarity = RarityConfig.Rarities[entry.Rarity]
		totalWeight += rarity and rarity.Weight or 1
	end

	local roll = spinRandom:NextInteger(1, totalWeight)
	for _, entry in ipairs(list) do
		local rarity = RarityConfig.Rarities[entry.Rarity]
		local weight = rarity and rarity.Weight or 1
		if roll <= weight then
			return entry
		end
		roll -= weight
	end
	return list[1]
end

local function buildSlot(reelTrack, index, entry)
	local rarity = RarityConfig.Rarities[entry.Rarity]

	local slot = Instance.new("TextLabel")
	slot.Size = UDim2.fromOffset(SLOT_WIDTH, REEL_HEIGHT)
	slot.Position = UDim2.fromOffset((index - 1) * SLOT_WIDTH, 0)
	slot.BackgroundColor3 = Color3.fromRGB(60, 30, 110)
	slot.Text = entry.Name
	slot.Font = Enum.Font.GothamBlack
	slot.TextSize = 18
	slot.TextWrapped = true
	slot.TextColor3 = rarity.Color
	slot.TextStrokeTransparency = 0.5
	slot.Parent = reelTrack

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = slot

	local stroke = Instance.new("UIStroke")
	stroke.Color = rarity.Color
	stroke.Thickness = 2
	stroke.Parent = slot
end

local function playRoll(ui, resultEntry, onDone)
	local sequence = {}
	for i = 1, NUM_SLOTS - 1 do
		sequence[i] = weightedRandomBrainrot()
	end
	sequence[NUM_SLOTS] = resultEntry

	for _, child in ipairs(ui.ReelTrack:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for i, entry in ipairs(sequence) do
		buildSlot(ui.ReelTrack, i, entry)
	end

	ui.ReelTrack.Size = UDim2.fromOffset(NUM_SLOTS * SLOT_WIDTH, REEL_HEIGHT)
	local centerOffset = (REEL_WINDOW_WIDTH - SLOT_WIDTH) / 2
	ui.ReelTrack.Position = UDim2.fromOffset(centerOffset, 0)

	-- Slides the track left so the final (real result) slot ends up centered.
	local endX = -((NUM_SLOTS - 1) * SLOT_WIDTH) + centerOffset

	local tween = TweenService:Create(
		ui.ReelTrack,
		TweenInfo.new(ROLL_DURATION, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(endX, 0) }
	)
	tween:Play()
	tween.Completed:Once(onDone)
end

-- The button's bright color comes from a UIGradient, which visually
-- overrides BackgroundColor3 -- so "disabled" toggles the gradient off and
-- falls back to a flat grey instead of trying to recolor it directly.
local function setButtonEnabled(ui, enabled)
	ui.SpinButton.Active = enabled
	ui.SpinButton.BackgroundColor3 = DISABLED_COLOR
	if ui.SpinButtonGradient then
		ui.SpinButtonGradient.Enabled = enabled
	end
end

function SpinController.Init(ui)
	ui.SpinButton.MouseButton1Click:Connect(function()
		if rolling then
			return
		end

		rolling = true
		setButtonEnabled(ui, false)
		ui.ResultLabel.Text = ""
		ui.RevealRarityLabel.Text = "???"

		local ok, result = RemoteHelpers.InvokeWithTimeout(SpinFunction, 5)

		if not ok then
			rolling = false
			setButtonEnabled(ui, true)
			if ui.ShowDebug then
				ui.ShowDebug(tostring(result))
			end
			return
		end

		if not result.Success then
			rolling = false
			setButtonEnabled(ui, true)

			if result.Reason == "Cooldown" then
				local remaining = result.CooldownRemaining or 0
				ui.CooldownLabel.Visible = true
				ui.CooldownLabel.Text = string.format("Wait %.1fs", remaining)
				task.delay(remaining, function()
					ui.CooldownLabel.Visible = false
				end)
			elseif ui.ShowDebug then
				ui.ShowDebug(
					"Server rejected the spin.\nReason: "
						.. tostring(result.Reason)
						.. (result.Detail and ("\n\n" .. tostring(result.Detail)) or "")
				)
			end
			return
		end

		playRoll(ui, { Name = result.Name, Rarity = result.Rarity }, function()
			local rarityData = RarityConfig.Rarities[result.Rarity]
			ui.RevealRarityLabel.Text = rarityData.DisplayName
			ui.RevealRarityLabel.TextColor3 = rarityData.Color
			ui.RevealStroke.Color = rarityData.Color

			ui.ResultLabel.Text = string.format("%s  •  %s", result.Name, rarityData.DisplayName)
			ui.ResultLabel.TextColor3 = rarityData.Color

			ui.RevealFrame.BackgroundColor3 = rarityData.Color
			TweenService:Create(ui.RevealFrame, TweenInfo.new(0.6), {
				BackgroundColor3 = Color3.fromRGB(40, 18, 74),
			}):Play()

			rolling = false
			setButtonEnabled(ui, true)

			if ui.RefreshInventory and result.Inventory then
				ui.RefreshInventory(result.Inventory, result.Equipped)
			end
		end)
	end)
end

return SpinController
