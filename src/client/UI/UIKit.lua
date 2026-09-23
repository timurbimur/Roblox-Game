--[[
	UIKit
	-----
	Code-built UI component library. Every screen in the game is assembled from
	these helpers, so the whole UI shares one modern "simulator" look:
	rounded corners, gradients, thick strokes, bouncy buttons.

	All components work with mouse, touch and gamepad (buttons are Selectable
	and use .Activated).
]]

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Data.Items)
local Util = require(Shared.Util)
local Theme = require(script.Parent.Theme)

local UIKit = {}

UIKit.ClickSound = nil -- set by Sound controller: function()

-- ============================================================================
-- PRIMITIVES
-- ============================================================================

-- UIKit.new("Frame", { Size = ..., Parent = ... }, { children })
function UIKit.new(className, props, children)
	local instance = Instance.new(className)
	local parent
	if props then
		for key, value in pairs(props) do
			if key == "Parent" then
				parent = value
			else
				instance[key] = value
			end
		end
	end
	if children then
		for _, child in ipairs(children) do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.Corner(radius)
	return UIKit.new("UICorner", { CornerRadius = radius or Theme.CornerRadius })
end

function UIKit.Stroke(color, thickness, transparency)
	return UIKit.new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.TextStroke(thickness)
	return UIKit.new("UIStroke", { Color = Theme.Colors.Stroke, Thickness = thickness or 2 })
end

function UIKit.Gradient(top, bottom, rotation)
	return UIKit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function UIKit.Padding(px)
	local u = UDim.new(0, px or 8)
	return UIKit.new("UIPadding", { PaddingTop = u, PaddingBottom = u, PaddingLeft = u, PaddingRight = u })
end

function UIKit.List(direction, padding, hAlign, vAlign)
	return UIKit.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 8),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UIKit.Tween(instance, duration, props, style, direction)
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- Text label with sensible defaults. maxTextSize caps TextScaled.
function UIKit.Label(props, maxTextSize)
	local label = UIKit.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = Theme.Font,
		TextColor3 = Theme.Colors.Text,
		TextScaled = true,
		Text = "",
	})
	for key, value in pairs(props or {}) do
		if key ~= "Parent" and key ~= "Stroke" then
			label[key] = value
		end
	end
	UIKit.new("UITextSizeConstraint", { MaxTextSize = maxTextSize or 32, MinTextSize = 8, Parent = label })
	if props and props.Stroke ~= false then
		UIKit.TextStroke(1.5).Parent = label
	end
	label.Parent = props and props.Parent
	return label
end

-- ============================================================================
-- BUTTON
-- ============================================================================
--[[
	UIKit.Button({
		Text = "Buy", Color = Theme.Colors.Green, Size = UDim2..., Position = ...,
		OnClick = function() end, TextSize = 24, Parent = frame, LayoutOrder = n
	})
	Returns the TextButton. button:SetAttribute("Disabled", true) greys it out.
]]
function UIKit.Button(props)
	local color = props.Color or Theme.Colors.Blue
	local button = UIKit.new("TextButton", {
		Name = props.Name or "Button",
		Size = props.Size or UDim2.fromOffset(160, 48),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		Text = "",
		LayoutOrder = props.LayoutOrder or 0,
		Selectable = true,
		ZIndex = props.ZIndex or 1,
	})
	UIKit.Corner(props.Corner or Theme.SmallCorner).Parent = button
	local gradient = UIKit.Gradient(color:Lerp(Color3.new(1, 1, 1), 0.15), color:Lerp(Color3.new(0, 0, 0), 0.2))
	gradient.Parent = button
	UIKit.Stroke(Theme.Colors.Stroke, 2.5).Parent = button
	local scale = UIKit.new("UIScale", { Parent = button })

	local label = UIKit.Label({
		Name = "Label",
		Size = UDim2.new(1, -12, 1, -8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Text = props.Text or "",
		ZIndex = button.ZIndex + 1,
		Parent = button,
	}, props.TextSize or 24)

	local function refreshColor(newColor)
		color = newColor or color
		local disabled = button:GetAttribute("Disabled")
		local base = disabled and Theme.Colors.Gray or color
		gradient.Color = ColorSequence.new(base:Lerp(Color3.new(1, 1, 1), 0.15), base:Lerp(Color3.new(0, 0, 0), 0.2))
	end
	button:GetAttributeChangedSignal("Disabled"):Connect(function()
		refreshColor()
	end)

	button.MouseEnter:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1.05 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 })
	end)
	button.SelectionGained:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1.07 })
	end)
	button.SelectionLost:Connect(function()
		UIKit.Tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		UIKit.Tween(scale, 0.08, { Scale = 0.93 })
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.Tween(scale, 0.1, { Scale = 1 })
	end)
	button.Activated:Connect(function()
		if UIKit.ClickSound then
			UIKit.ClickSound()
		end
		UIKit.Tween(scale, 0.06, { Scale = 0.93 }).Completed:Connect(function()
			UIKit.Tween(scale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		end)
		if props.OnClick and not button:GetAttribute("Disabled") then
			props.OnClick(button)
		end
	end)

	button.Parent = props.Parent
	return button, label, refreshColor
end

-- ============================================================================
-- PROGRESS BAR
-- ============================================================================
function UIKit.ProgressBar(props)
	local frame = UIKit.new("Frame", {
		Name = props.Name or "ProgressBar",
		Size = props.Size or UDim2.new(1, 0, 0, 24),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundColor3 = Theme.Colors.Background,
		LayoutOrder = props.LayoutOrder or 0,
	}, { UIKit.Corner(UDim.new(1, 0)), UIKit.Stroke(Theme.Colors.Stroke, 2) })
	local fill = UIKit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = frame,
	}, { UIKit.Corner(UDim.new(1, 0)) })
	local gradient = UIKit.Gradient(props.Color or Theme.Colors.Green, (props.Color or Theme.Colors.Green):Lerp(Color3.new(0, 0, 0), 0.25))
	gradient.Parent = fill
	local label = UIKit.Label({
		Size = UDim2.new(1, -10, 1, -4),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ZIndex = 3,
		Parent = frame,
	}, props.TextSize or 18)
	frame.Parent = props.Parent

	local bar = { Frame = frame, Fill = fill, Label = label }
	function bar.Set(fraction, text, instant)
		fraction = math.clamp(fraction or 0, 0, 1)
		if instant then
			fill.Size = UDim2.fromScale(fraction, 1)
		else
			UIKit.Tween(fill, 0.25, { Size = UDim2.fromScale(fraction, 1) })
		end
		fill.Visible = fraction > 0.001
		label.Text = text or ""
	end
	function bar.SetColor(color)
		gradient.Color = ColorSequence.new(color, color:Lerp(Color3.new(0, 0, 0), 0.25))
	end
	return bar
end

-- ============================================================================
-- TABS
-- ============================================================================
function UIKit.Tabs(parent, tabs, onSelect, color)
	local bar = UIKit.new("Frame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundTransparency = 1,
		Parent = parent,
	}, { UIKit.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left) })
	local buttons = {}
	local api = {}
	function api.Select(name)
		for tabName, button in pairs(buttons) do
			button:SetAttribute("Disabled", tabName ~= name)
		end
		onSelect(name)
	end
	for index, name in ipairs(tabs) do
		buttons[name] = UIKit.Button({
			Text = name,
			Size = UDim2.new(1 / #tabs, -8, 1, 0),
			Color = color or Theme.Colors.Purple,
			LayoutOrder = index,
			TextSize = 20,
			Parent = bar,
			OnClick = function()
				api.Select(name)
			end,
		})
		-- Tabs use "Disabled" only for visuals; clicking still works.
		buttons[name].Activated:Connect(function()
			if buttons[name]:GetAttribute("Disabled") then
				api.Select(name)
			end
		end)
	end
	api.Bar = bar
	api.Buttons = buttons
	return api
end

-- ============================================================================
-- ITEM CELL (reused by Inventory, Sell, Fusion and Collection grids)
-- ============================================================================
function UIKit.ItemCell(parent)
	local button = UIKit.new("TextButton", {
		Name = "ItemCell",
		BackgroundColor3 = Theme.Colors.Cell,
		AutoButtonColor = false,
		Text = "",
		Selectable = true,
	})
	UIKit.Corner(Theme.SmallCorner).Parent = button
	local stroke = UIKit.Stroke(Color3.new(1, 1, 1), 3)
	stroke.Parent = button
	local gradient = UIKit.new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170)),
		Parent = button,
	})
	local scale = UIKit.new("UIScale", { Parent = button })

	local icon = UIKit.new("TextLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextScaled = true,
		Font = Enum.Font.GothamBold,
		Text = "",
		Parent = button,
	})
	local image = UIKit.new("ImageLabel", {
		Name = "Image",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0.62, 0.62),
		Position = UDim2.fromScale(0.5, 0.42),
		AnchorPoint = Vector2.new(0.5, 0.5),
		ScaleType = Enum.ScaleType.Fit,
		Visible = false,
		Parent = button,
	})
	local nameLabel = UIKit.Label({
		Name = "ItemName",
		Size = UDim2.new(1, -6, 0.2, 0),
		Position = UDim2.new(0.5, 0, 1, -3),
		AnchorPoint = Vector2.new(0.5, 1),
		Parent = button,
	}, 14)
	local countLabel = UIKit.Label({
		Name = "Count",
		Size = UDim2.new(0.5, 0, 0.22, 0),
		Position = UDim2.new(1, -4, 0, 3),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = button,
	}, 16)
	local badge = UIKit.Label({
		Name = "Badge",
		Size = UDim2.new(0.35, 0, 0.24, 0),
		Position = UDim2.new(0, 3, 0, 2),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = button,
	}, 18)
	local check = UIKit.new("Frame", {
		Name = "Selected",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Theme.Colors.Green,
		BackgroundTransparency = 0.55,
		Visible = false,
		ZIndex = 5,
		Parent = button,
	}, { UIKit.Corner(Theme.SmallCorner) })
	UIKit.Label({ Text = "✔", Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6, Parent = check }, 40)

	button.MouseEnter:Connect(function()
		UIKit.Tween(scale, 0.1, { Scale = 1.06 })
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(scale, 0.1, { Scale = 1 })
	end)
	button.SelectionGained:Connect(function()
		UIKit.Tween(scale, 0.1, { Scale = 1.08 })
	end)
	button.SelectionLost:Connect(function()
		UIKit.Tween(scale, 0.1, { Scale = 1 })
	end)

	local cell = { Button = button, ItemId = nil }

	-- opts: { Count, Hidden (undiscovered), Favorite, Selected, Locked, ShowName }
	function cell.Set(itemId, opts)
		opts = opts or {}
		cell.ItemId = itemId
		local item = Items.ById[itemId]
		if not item then
			button.Visible = false
			return
		end
		button.Visible = true
		local rarity = Config.RarityByName[item.Rarity]
		local rarityColor = rarity.Color
		if opts.Hidden then
			button.BackgroundColor3 = Theme.Colors.Background
			stroke.Color = Theme.Colors.Gray
			icon.Text = "❓"
			icon.Visible = true
			image.Visible = false
			nameLabel.Text = "???????"
		else
			button.BackgroundColor3 = rarityColor:Lerp(Theme.Colors.Cell, 0.55)
			stroke.Color = item.Rarity == "Secret" and Color3.fromRGB(255, 255, 255) or rarityColor
			if item.Image then
				image.Image = item.Image
				image.Visible = true
				icon.Visible = false
			else
				icon.Text = item.Icon
				icon.Visible = true
				image.Visible = false
			end
			nameLabel.Text = item.Name
		end
		nameLabel.Visible = opts.ShowName ~= false
		countLabel.Text = (opts.Count and opts.Count > 1) and ("x" .. Util.FormatNumber(opts.Count)) or ""
		badge.Text = (opts.Locked and "🔒") or (opts.Favorite and "⭐") or (opts.New and "🆕") or ""
		check.Visible = opts.Selected == true
		gradient.Enabled = not opts.Hidden
	end

	button.Parent = parent
	return cell
end

--[[
	ItemGrid: pooled, responsive grid of ItemCells inside a ScrollingFrame.
	grid.Render(entries) where entries = { { ItemId = id, ...cell opts }, ... }
	Cells are reused between renders, so re-rendering 200 items is cheap.
]]
function UIKit.ItemGrid(props)
	local scroller = UIKit.new("ScrollingFrame", {
		Name = props.Name or "Grid",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.SubText,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Selectable = false,
		LayoutOrder = props.LayoutOrder or 0,
	})
	local padding = props.CellPadding or 8
	local layout = UIKit.new("UIGridLayout", {
		CellPadding = UDim2.fromOffset(padding, padding),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Parent = scroller,
	})
	UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 6),
		Parent = scroller,
	})

	local targetCell = props.CellSize or 92
	local function resize()
		local width = scroller.AbsoluteSize.X - 20
		if width <= 0 then
			return
		end
		local columns = math.max(2, math.floor((width + padding) / (targetCell + padding)))
		local cell = math.floor((width - padding * (columns - 1)) / columns)
		layout.CellSize = UDim2.fromOffset(cell, cell)
	end
	scroller:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize)
	task.defer(resize)

	local cells = {}
	local grid = { Frame = scroller, Cells = cells }

	function grid.Render(entries)
		for index, entry in ipairs(entries) do
			local cell = cells[index]
			if not cell then
				cell = UIKit.ItemCell(scroller)
				cells[index] = cell
				cell.Button.Activated:Connect(function()
					if props.OnClick and cell.ItemId then
						props.OnClick(cell.ItemId, cell)
					end
				end)
			end
			cell.Button.LayoutOrder = index
			cell.Set(entry.ItemId, entry)
		end
		for index = #entries + 1, #cells do
			cells[index].Button.Visible = false
			cells[index].ItemId = nil
		end
	end

	scroller.Parent = props.Parent
	return grid
end

-- ============================================================================
-- WINDOW (modal panel)
-- ============================================================================
--[[
	Creates a centered window. Returns window, content.
	Size is responsive: scale-based with a max pixel size.
]]
function UIKit.Window(props)
	local color = props.Color or Theme.Colors.Purple
	local window = UIKit.new("Frame", {
		Name = props.Name,
		Size = UDim2.fromScale(0.9, 0.82),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 10,
	})
	UIKit.new("UISizeConstraint", { MaxSize = props.MaxSize or Vector2.new(940, 620), Parent = window })
	UIKit.Corner(UDim.new(0, 20)).Parent = window
	UIKit.Stroke(Theme.Colors.Stroke, 4).Parent = window
	UIKit.Gradient(Theme.Colors.PanelLight, Theme.Colors.Panel).Parent = window
	UIKit.new("UIScale", { Name = "OpenScale", Parent = window })

	local header = UIKit.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Parent = window,
	}, { UIKit.Corner(UDim.new(0, 20)), UIKit.Gradient(color:Lerp(Color3.new(1, 1, 1), 0.2), color:Lerp(Color3.new(0, 0, 0), 0.15)) })
	-- Square off the header's bottom corners
	UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.new(0, 0, 1, -20),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		Parent = header,
	}, { UIKit.Gradient(color:Lerp(Color3.new(0, 0, 0), 0.05), color:Lerp(Color3.new(0, 0, 0), 0.15)) })

	UIKit.Label({
		Name = "Title",
		Text = (props.Icon and (props.Icon .. " ") or "") .. (props.Title or ""),
		Size = UDim2.new(1, -140, 0, 44),
		Position = UDim2.new(0, 20, 0, 7),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 2,
		Parent = header,
	}, 36)

	local closeButton = UIKit.Button({
		Name = "Close",
		Text = "✕",
		Color = Theme.Colors.Red,
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(1, -10, 0, 6),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 28,
		ZIndex = 3,
		Parent = header,
		OnClick = function()
			if props.OnClose then
				props.OnClose()
			end
		end,
	})

	local content = UIKit.new("Frame", {
		Name = "Content",
		Size = UDim2.new(1, -24, 1, -72),
		Position = UDim2.new(0, 12, 0, 64),
		BackgroundTransparency = 1,
		Parent = window,
	})

	window.Parent = props.Parent
	return window, content, closeButton
end

-- Simple rounded card frame.
function UIKit.Card(props)
	local card = UIKit.new("Frame", {
		Name = props.Name or "Card",
		Size = props.Size or UDim2.new(1, 0, 0, 80),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		BackgroundColor3 = props.Color or Theme.Colors.PanelLight,
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundTransparency = props.Transparency or 0,
	}, { UIKit.Corner(props.Corner or Theme.SmallCorner), UIKit.Stroke(Theme.Colors.Stroke, 2) })
	card.Parent = props.Parent
	return card
end

-- Vertical scrolling list container.
function UIKit.ScrollList(props)
	local scroller = UIKit.new("ScrollingFrame", {
		Name = props.Name or "List",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = Theme.Colors.SubText,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Selectable = false,
		LayoutOrder = props.LayoutOrder or 0,
	})
	UIKit.List(Enum.FillDirection.Vertical, props.Padding or 8).Parent = scroller
	UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 8),
		Parent = scroller,
	})
	scroller.Parent = props.Parent
	return scroller
end

function UIKit.ClearChildren(frame, classNames)
	for _, child in ipairs(frame:GetChildren()) do
		if not classNames or classNames[child.ClassName] then
			child:Destroy()
		end
	end
end

-- Formats a reward table as short text: "$500 • 🍀 2x Luck (10m) • 👑 Item"
function UIKit.RewardText(reward, zoneScale)
	local parts = {}
	if reward.Cash then
		local cash = reward.Cash
		if reward.ScaleCash and zoneScale then
			cash *= zoneScale
		end
		table.insert(parts, Util.FormatCash(cash))
	end
	if reward.Boost then
		local boost = Config.Boosts[reward.Boost.Id]
		if boost then
			table.insert(parts, ("%s %s (%s)"):format(boost.Icon, boost.Name, Util.FormatTime(reward.Boost.Duration)))
		end
	end
	if reward.Item then
		local item = Items.ById[reward.Item]
		if item then
			table.insert(parts, item.Icon .. " " .. item.Name)
		end
	end
	return table.concat(parts, "  •  ")
end

return UIKit
