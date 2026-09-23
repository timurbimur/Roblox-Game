--[[
	HUD
	---
	Always-on screen widgets:
	  * Cash counter (animated count-up) + collection progress
	  * Side menu buttons (Inventory, Collection, Quests, Shop, Zones, Settings)
	    with a red "!" badge when rewards are claimable
	  * Backpack capacity bar
	  * Active boost timers
	  * Fusion-in-progress indicator
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)
local Util = require(Shared.Util)

local ClientRoot = script.Parent.Parent
local UIKit = require(ClientRoot.UI.UIKit)
local Theme = require(ClientRoot.UI.Theme)
local State = require(ClientRoot.Lib.State)

local HUD = {}

local Controllers
local cashLabel, collectionLabel, capacityBar, boostContainer, fusionBar
local menuButtons = {}
local displayedCash = 0
local targetCash = 0

local MENU = {
	{ Name = "Inventory", Icon = "🎒", Color = Theme.Colors.Blue, Key = "F" },
	{ Name = "Collection", Icon = "📖", Color = Theme.Colors.Pink, Key = "C" },
	{ Name = "Quests", Icon = "📜", Color = Theme.Colors.Orange, Key = "Q" },
	{ Name = "Shop", Icon = "🛒", Color = Theme.Colors.Green, Key = "G" },
	{ Name = "Zones", Icon = "🗺️", Color = Theme.Colors.Purple },
	{ Name = "Settings", Icon = "⚙️", Color = Theme.Colors.Gray },
}

local function buildMenuButton(parent, entry, order)
	local button = UIKit.Button({
		Name = entry.Name,
		Size = UDim2.fromOffset(78, 78),
		Color = entry.Color,
		LayoutOrder = order,
		Parent = parent,
		OnClick = function()
			if entry.Name == "Zones" then
				Controllers.UIController.Open("Shop")
				Controllers.ShopPanel.SelectTab("Zones")
			else
				Controllers.UIController.Toggle(entry.Name)
			end
		end,
	})
	button.Label.Size = UDim2.new(1, -8, 0, 22)
	button.Label.Position = UDim2.new(0.5, 0, 1, -4)
	button.Label.AnchorPoint = Vector2.new(0.5, 1)
	button.Label.Text = entry.Name
	button.Label.UITextSizeConstraint.MaxTextSize = 15
	UIKit.new("TextLabel", {
		Size = UDim2.new(1, -20, 0, 42),
		Position = UDim2.new(0.5, 0, 0, 6),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = entry.Icon,
		ZIndex = 3,
		Parent = button,
	})
	if entry.Key then
		UIKit.Label({
			Text = entry.Key,
			Size = UDim2.fromOffset(18, 18),
			Position = UDim2.fromOffset(4, 3),
			TextColor3 = Theme.Colors.SubText,
			ZIndex = 3,
			Parent = button,
		}, 13)
	end
	local badge = UIKit.new("Frame", {
		Name = "Badge",
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, 6, 0, -6),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = Theme.Colors.Red,
		Visible = false,
		ZIndex = 4,
		Parent = button,
	}, { UIKit.Corner(UDim.new(1, 0)), UIKit.Stroke(Theme.Colors.Stroke, 2) })
	UIKit.Label({ Text = "!", Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = badge }, 20)
	-- Idle bob animation for the badge to draw attention.
	task.spawn(function()
		local up = true
		while badge.Parent do
			if badge.Visible then
				UIKit.Tween(badge, 0.5, { Position = UDim2.new(1, 6, 0, up and -12 or -6) }, Enum.EasingStyle.Sine)
				up = not up
			end
			task.wait(0.5)
		end
	end)
	menuButtons[entry.Name] = button
	return button
end

function HUD.SetBadge(menuName, visible)
	local button = menuButtons[menuName]
	if button then
		button.Badge.Visible = visible
	end
end

local function refreshCapacity()
	local data = State.Data
	if not data then
		return
	end
	local total = 0
	for _, count in pairs(data.Inventory) do
		total += count
	end
	local capacity = Formulas.GetCapacity(data, data.Passes)
	local infinite = capacity >= Config.InfiniteCapacity
	capacityBar.Set(infinite and 0.02 or total / capacity, infinite and ("🎒 " .. Util.FormatNumber(total) .. " / ∞") or ("🎒 " .. total .. " / " .. capacity))
	capacityBar.SetColor(total >= capacity and Theme.Colors.Red or (total / capacity > 0.8 and Theme.Colors.Orange or Theme.Colors.Green))
end

local function refreshCollection()
	local discovered = Util.CountKeys(State.Get("Discovered") or {})
	collectionLabel.Text = ("📖 %d / %d  (%.1f%%)"):format(discovered, Items.Count, discovered / Items.Count * 100)
end

local boostRows = {}
local function refreshBoosts()
	local boosts = State.Get("Boosts") or {}
	for id, row in pairs(boostRows) do
		if not boosts[id] then
			row:Destroy()
			boostRows[id] = nil
		end
	end
	for id in pairs(boosts) do
		local def = Config.Boosts[id]
		if def and not boostRows[id] then
			local row = UIKit.new("Frame", {
				Name = id,
				Size = UDim2.fromOffset(170, 40),
				BackgroundColor3 = Theme.Colors.Panel,
			}, { UIKit.Corner(Theme.SmallCorner), UIKit.Stroke(def.Color, 3) })
			UIKit.Label({ Text = def.Icon .. " " .. def.Name, Size = UDim2.new(1, -12, 0.55, 0), Position = UDim2.fromOffset(8, 2), TextXAlignment = Enum.TextXAlignment.Left, Parent = row }, 16)
			UIKit.Label({ Name = "Timer", Text = "", Size = UDim2.new(1, -12, 0.45, 0), Position = UDim2.new(0, 8, 0.55, -2), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = def.Color, Font = Theme.BodyFont, Parent = row }, 14)
			row.Parent = boostContainer
			boostRows[id] = row
		end
	end
end

-- Local countdown (server only re-syncs on add/expire).
local function updateBoostTimers()
	local boosts = State.Get("Boosts")
	if not boosts then
		return
	end
	local elapsed = os.clock() - (State.KeyReceivedAt.Boosts or os.clock())
	for id, row in pairs(boostRows) do
		local remaining = (boosts[id] or 0) - elapsed
		row.Timer.Text = Util.FormatTime(remaining)
	end
end

local function refreshFusion()
	local pending = State.Get("PendingFusion")
	fusionBar.Frame.Visible = pending and true or false
end

function HUD.Init(controllers)
	Controllers = controllers
	local root = controllers.UIController.HUDRoot

	-- Cash pill (top center)
	local cashPill = UIKit.new("Frame", {
		Name = "Cash",
		Size = UDim2.fromOffset(280, 58),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = root,
	}, { UIKit.Corner(UDim.new(1, 0)), UIKit.Stroke(Theme.Colors.Stroke, 3), UIKit.Gradient(Color3.fromRGB(60, 200, 100), Color3.fromRGB(30, 130, 60)) })
	cashLabel = UIKit.Label({ Text = "$0", Size = UDim2.new(1, -24, 1, -10), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Parent = cashPill }, 40)
	local cashScale = UIKit.new("UIScale", { Parent = cashPill })
	HUD.CashScale = cashScale

	collectionLabel = UIKit.Label({
		Text = "",
		Size = UDim2.fromOffset(280, 24),
		Position = UDim2.new(0.5, 0, 0, 70),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = root,
	}, 20)

	-- Side menu (left)
	local menu = UIKit.new("Frame", {
		Name = "Menu",
		Size = UDim2.fromOffset(172, 270),
		Position = UDim2.new(0, 12, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
		Parent = root,
	})
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(78, 78),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = menu,
	})
	for index, entry in ipairs(MENU) do
		buildMenuButton(menu, entry, index)
	end

	-- Capacity bar (bottom center)
	capacityBar = UIKit.ProgressBar({
		Name = "Capacity",
		Size = UDim2.fromOffset(300, 30),
		Position = UDim2.new(0.5, 0, 1, -70),
		AnchorPoint = Vector2.new(0.5, 0),
		Parent = root,
		TextSize = 18,
	})

	-- Fusion indicator (above capacity)
	fusionBar = UIKit.ProgressBar({
		Name = "Fusing",
		Size = UDim2.fromOffset(240, 24),
		Position = UDim2.new(0.5, 0, 1, -102),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = Theme.Colors.Purple,
		Parent = root,
		TextSize = 16,
	})
	fusionBar.Frame.Visible = false
	fusionBar.Set(1, "⚗️ Fusing...", true)

	-- Boosts (top right)
	boostContainer = UIKit.new("Frame", {
		Name = "Boosts",
		Size = UDim2.fromOffset(180, 260),
		Position = UDim2.new(1, -12, 0, 60),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
		Parent = root,
	}, { UIKit.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right) })
end

function HUD.Start()
	State.Watch("Cash", function(value)
		targetCash = value or 0
		if displayedCash == 0 then
			displayedCash = targetCash
		end
		if HUD.CashScale then
			UIKit.Tween(HUD.CashScale, 0.08, { Scale = 1.08 }).Completed:Connect(function()
				UIKit.Tween(HUD.CashScale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
			end)
		end
	end)
	State.Watch("Inventory", refreshCapacity)
	State.Watch("Upgrades", refreshCapacity)
	State.Watch("Passes", refreshCapacity)
	State.Watch("Discovered", refreshCollection)
	State.Watch("Boosts", refreshBoosts)
	State.Watch("PendingFusion", refreshFusion)

	-- Smooth cash count-up + boost timers (cheap per-frame work only).
	local timerAccumulator = 0
	RunService.RenderStepped:Connect(function(dt)
		if displayedCash ~= targetCash then
			local diff = targetCash - displayedCash
			if math.abs(diff) < 1 then
				displayedCash = targetCash
			else
				displayedCash += diff * math.min(1, dt * 8)
			end
			cashLabel.Text = "💰 " .. Util.FormatCash(displayedCash)
		elseif cashLabel.Text == "$0" then
			cashLabel.Text = "💰 " .. Util.FormatCash(displayedCash)
		end
		timerAccumulator += dt
		if timerAccumulator >= 0.5 then
			timerAccumulator = 0
			updateBoostTimers()
		end
	end)
end

return HUD
