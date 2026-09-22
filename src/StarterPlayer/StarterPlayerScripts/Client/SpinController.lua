-- Drives the "reel" animation: rapidly cycles through random candidate
-- brainrots (slowing down over time, slot-machine style) before revealing the
-- brainrot the server actually awarded. The cycling is purely cosmetic flavor
-- -- the true result always comes from SpinFunction:InvokeServer().

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
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

local function showEntry(ui, entry)
	local rarity = RarityConfig.Rarities[entry.Rarity]
	ui.RevealNameLabel.Text = entry.Name
	ui.RevealRarityLabel.Text = rarity.DisplayName
	ui.RevealRarityLabel.TextColor3 = rarity.Color
	ui.RevealStroke.Color = rarity.Color
end

local function playRoll(ui, onDone)
	local elapsed = 0
	local timeSinceSwap = 0
	local duration = 1.6
	local baseInterval = 0.05
	local list = BrainrotConfig.List

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		timeSinceSwap += dt

		local progress = math.clamp(elapsed / duration, 0, 1)
		-- Ease the swap interval from fast to slow so it feels like it's settling.
		local currentInterval = baseInterval + (progress ^ 2) * 0.25

		if timeSinceSwap >= currentInterval then
			timeSinceSwap = 0
			showEntry(ui, list[spinRandom:NextInteger(1, #list)])
		end

		if elapsed >= duration then
			connection:Disconnect()
			onDone()
		end
	end)
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

		playRoll(ui, function()
			local rarityData = RarityConfig.Rarities[result.Rarity]
			showEntry(ui, { Name = result.Name, Rarity = result.Rarity })

			ui.ResultLabel.Text = string.format("%s  •  %s", result.Name, rarityData.DisplayName)
			ui.ResultLabel.TextColor3 = rarityData.Color

			ui.RevealFrame.BackgroundColor3 = rarityData.Color
			TweenService:Create(ui.RevealFrame, TweenInfo.new(0.6), {
				BackgroundColor3 = Color3.fromRGB(30, 30, 40),
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
