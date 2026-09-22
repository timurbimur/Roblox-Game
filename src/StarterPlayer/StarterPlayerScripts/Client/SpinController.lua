-- Drives the dice-roll animation and reveals the brainrot the server awarded.
-- The dice face itself is purely cosmetic flavor -- the actual result always
-- comes from the server via SpinResult.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local RarityConfig = require(ReplicatedStorage.Modules.RarityConfig)
local UIController = require(script.Parent.UIController)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local RequestSpin = Remotes:WaitForChild("RequestSpin")
local SpinResult = Remotes:WaitForChild("SpinResult")

local SpinController = {}

local rolling = false
local diceRandom = Random.new()

local function setFace(pips, faceNumber)
	for _, pip in pairs(pips) do
		pip.Visible = false
	end
	for _, coords in ipairs(UIController.FacePatterns[faceNumber]) do
		local key = coords[1] .. "," .. coords[2]
		local pip = pips[key]
		if pip then
			pip.Visible = true
		end
	end
end

local function playRoll(ui, onDone)
	local elapsed = 0
	local timeSinceFace = 0
	local duration = 1.4
	local baseInterval = 0.06

	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		timeSinceFace += dt

		local progress = math.clamp(elapsed / duration, 0, 1)
		local currentInterval = baseInterval + progress * 0.12

		if timeSinceFace >= currentInterval then
			timeSinceFace = 0
			setFace(ui.DicePips, diceRandom:NextInteger(1, 6))
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
		ui.ResultLabel.Text = ""
		ui.ResultLabel.TextColor3 = Color3.fromRGB(255, 255, 255)

		playRoll(ui, function()
			local rarityData = RarityConfig.Rarities[result.Rarity]
			setFace(ui.DicePips, diceRandom:NextInteger(1, 6))

			ui.ResultLabel.Text = string.format("%s  •  %s", result.Name, rarityData.DisplayName)
			ui.ResultLabel.TextColor3 = rarityData.Color

			ui.DiceFrame.BackgroundColor3 = rarityData.Color
			TweenService:Create(ui.DiceFrame, TweenInfo.new(0.5), {
				BackgroundColor3 = Color3.fromRGB(30, 30, 40),
			}):Play()

			rolling = false
			ui.SpinButton.Active = true
		end)
	end)
end

return SpinController
