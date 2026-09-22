local Players = game:GetService("Players")

-- Temporary on-screen debug/error display so failures are visible without
-- needing to find the Output panel -- remove once things are stable.
local function createDebugDisplay()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = Instance.new("ScreenGui")
	gui.Name = "SpinABrainrotDebug"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -40, 0, 260)
	label.Position = UDim2.fromOffset(20, 20)
	label.BackgroundColor3 = Color3.fromRGB(40, 0, 0)
	label.BackgroundTransparency = 0.1
	label.TextColor3 = Color3.fromRGB(255, 140, 140)
	label.TextWrapped = true
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Font = Enum.Font.Code
	label.TextSize = 18
	label.Visible = false
	label.Text = ""
	label.Parent = gui

	return function(message)
		label.Visible = true
		label.Text = "SPIN A BRAINROT -- DEBUG:\n\n" .. tostring(message)
	end
end

local showDebug = createDebugDisplay()

local ok, err = pcall(function()
	local UIController = require(script.Parent.UIController)
	local SpinController = require(script.Parent.SpinController)
	local InventoryController = require(script.Parent.InventoryController)

	local ui = UIController.Init()
	ui.ShowDebug = showDebug

	SpinController.Init(ui)
	InventoryController.Init(ui)
end)

if not ok then
	showDebug("CLIENT ERROR:\n" .. tostring(err))
end
