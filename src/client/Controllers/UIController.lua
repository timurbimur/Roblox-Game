--[[
	UIController
	------------
	Owns the root ScreenGui, responsive scaling, and the modal panel system.

	  UIController.Root         ScreenGui for panels
	  UIController.HUDRoot      scaled frame for HUD widgets (offset-based)
	  UIController.RegisterPanel(name, { Window, OnOpen, OnClose })
	  UIController.Open(name) / Close() / Toggle(name) / IsOpen(name)

	Input
	  Keyboard: F Inventory, C Collection, Q Quests, G Shop, Esc/B-button close
	  Gamepad:  Y Inventory, DPad Up Collection, DPad Left Quests,
	            DPad Right Shop, B closes the open panel
	  When a panel opens with a gamepad, the first button is auto-selected.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local UIFolder = script.Parent.Parent:WaitForChild("UI")
local UIKit = require(UIFolder.UIKit)

local UIController = {}

local player = Players.LocalPlayer
local panels = {}
local currentPanel = nil
local blur

UIController.PanelOpened = nil -- optional hook(name)

local KEYBINDS = {
	[Enum.KeyCode.F] = "Inventory",
	[Enum.KeyCode.C] = "Collection",
	[Enum.KeyCode.Q] = "Quests",
	[Enum.KeyCode.G] = "Shop",
	[Enum.KeyCode.ButtonY] = "Inventory",
	[Enum.KeyCode.DPadUp] = "Collection",
	[Enum.KeyCode.DPadLeft] = "Quests",
	[Enum.KeyCode.DPadRight] = "Shop",
}

function UIController.IsMobile()
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function findFirstSelectable(root)
	for _, descendant in ipairs(root:GetDescendants()) do
		if descendant:IsA("GuiButton") and descendant.Selectable and descendant.Visible and descendant.Name ~= "Close" then
			return descendant
		end
	end
	return nil
end

function UIController.RegisterPanel(name, panel)
	panels[name] = panel
end

function UIController.IsOpen(name)
	return currentPanel == name
end

function UIController.GetOpen()
	return currentPanel
end

function UIController.Close()
	if not currentPanel then
		return
	end
	local panel = panels[currentPanel]
	currentPanel = nil
	local window = panel.Window
	local openScale = window:FindFirstChild("OpenScale")
	if openScale then
		UIKit.Tween(openScale, 0.12, { Scale = 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
			if currentPanel == nil or panels[currentPanel] ~= panel then
				window.Visible = false
			end
		end)
	else
		window.Visible = false
	end
	if blur then
		UIKit.Tween(blur, 0.2, { Size = 0 })
	end
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(window) then
		GuiService.SelectedObject = nil
	end
	if panel.OnClose then
		panel.OnClose()
	end
end

function UIController.Open(name)
	local panel = panels[name]
	if not panel then
		return
	end
	if currentPanel == name then
		return
	end
	if currentPanel then
		local previous = panels[currentPanel]
		previous.Window.Visible = false
		if previous.OnClose then
			previous.OnClose()
		end
	end
	currentPanel = name
	local window = panel.Window
	local openScale = window:FindFirstChild("OpenScale")
	window.Visible = true
	if openScale then
		openScale.Scale = 0.8
		UIKit.Tween(openScale, 0.28, { Scale = 1 }, Enum.EasingStyle.Back)
	end
	if blur then
		UIKit.Tween(blur, 0.2, { Size = 12 })
	end
	if panel.OnOpen then
		panel.OnOpen()
	end
	if UserInputService.GamepadEnabled and UserInputService:GetLastInputType().Name:find("Gamepad") then
		task.defer(function()
			GuiService.SelectedObject = findFirstSelectable(window)
		end)
	end
	if UIController.PanelOpened then
		UIController.PanelOpened(name)
	end
end

function UIController.Toggle(name)
	if currentPanel == name then
		UIController.Close()
	else
		UIController.Open(name)
	end
end

-- Uniform scale for offset-based HUD widgets.
local function updateScale(hudScale)
	local camera = Workspace.CurrentCamera
	local viewport = camera and camera.ViewportSize or Vector2.new(1366, 768)
	local scale = math.min(viewport.X / 1366, viewport.Y / 768)
	hudScale.Scale = math.clamp(scale * (UIController.IsMobile() and 1.25 or 1), 0.55, 1.3)
end

function UIController.Init()
	local playerGui = player:WaitForChild("PlayerGui")

	local root = UIKit.new("ScreenGui", {
		Name = "DumpsterUI",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		DisplayOrder = 5,
		Parent = playerGui,
	})
	UIController.Root = root

	local hudGui = UIKit.new("ScreenGui", {
		Name = "DumpsterHUD",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 2,
		Parent = playerGui,
	})
	local hudRoot = UIKit.new("Frame", {
		Name = "HUDRoot",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = hudGui,
	})
	local hudScale = UIKit.new("UIScale", { Parent = hudRoot })
	UIController.HUDGui = hudGui
	UIController.HUDRoot = hudRoot
	UIController.HUDScale = hudScale

	-- UIScale shrinks the frame's rendered size, so grow the frame to compensate
	-- and keep it covering the whole screen.
	local function rescale()
		updateScale(hudScale)
		hudRoot.Size = UDim2.fromScale(1 / hudScale.Scale, 1 / hudScale.Scale)
	end
	rescale()
	local function hookCamera()
		local camera = Workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
		end
	end
	hookCamera()
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		hookCamera()
		rescale()
	end)

	-- Overlay layer (banners, popups) above panels.
	local overlay = UIKit.new("ScreenGui", {
		Name = "DumpsterOverlay",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = 20,
		Parent = playerGui,
	})
	UIController.Overlay = overlay

	-- Background blur while a panel is open (created locally, so only this
	-- player sees it).
	blur = Instance.new("BlurEffect")
	blur.Name = "PanelBlur"
	blur.Size = 0
	blur.Parent = game:GetService("Lighting")
end

function UIController.Start()
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			-- Still allow B to close panels while a panel button is selected.
			if input.KeyCode == Enum.KeyCode.ButtonB and currentPanel then
				UIController.Close()
			end
			return
		end
		if input.KeyCode == Enum.KeyCode.ButtonB or input.KeyCode == Enum.KeyCode.Escape then
			if currentPanel then
				UIController.Close()
			end
			return
		end
		local panelName = KEYBINDS[input.KeyCode]
		if panelName then
			UIController.Toggle(panelName)
		end
	end)
end

return UIController
