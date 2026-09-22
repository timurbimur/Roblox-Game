-- Drives the "reel" animation: rapidly cycles through random candidate
-- brainrots (slowing down over time, slot-machine style) before revealing the
-- brainrot the server actually awarded. The cycling is purely cosmetic flavor
-- -- the true result always comes from the server via SpinResult.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RarityConfig = require(ReplicatedStorage.Modules.RarityConfig)
local BrainrotConfig = require(ReplicatedStorage.Modules.BrainrotConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestSpin = Remotes:WaitForChild("RequestSpin")
local SpinResult = Remotes:WaitForChild("SpinResult")

local SpinController = {}

local rolling = false
local spinRandom = Random.new()

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

function SpinController.Init(ui)
	ui.SpinButton.MouseButton1Click:Connect(function()
		if rolling then
			return
		end
		RequestSpin:FireServer()
	end)

	SpinResult.OnClientEvent:Connect(function(result)
		if not result.Success then
			if result.Reason == "Cooldown" then
				local remaining = result.CooldownRemaining or 0
				ui.CooldownLabel.Visible = true
				ui.CooldownLabel.Text = string.format("Wait %.1fs", remaining)
				task.delay(remaining, function()
					ui.CooldownLabel.Visible = false
				end)
			end
			return
		end

		rolling = true
		ui.SpinButton.Active = false
		ui.SpinButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
		ui.ResultLabel.Text = ""
		ui.ResultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

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
			ui.SpinButton.Active = true
			ui.SpinButton.BackgroundColor3 = Color3.fromRGB(90, 160, 255)
		end)
	end)
end

return SpinController
