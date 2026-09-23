--[[
	Notifications
	-------------
	All feedback popups driven by the server's Signal remote:

	  Toast          small stacked messages (bottom right)
	  ItemFound      item card that pops up above the hotbar (+ NEW! tag)
	  Announce       LARGE animated banner for Legendary/Mythic/Secret finds
	                 server-wide ("Timur discovered Cyber Dragon!") + chat line
	  Broadcast/Tip  server messages
	  Reward         reward popup (quests, daily, achievements)
	  ZoneUnlocked   full-screen zone splash
	  Sold           cash burst
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Items = require(Shared.Data.Items)
local Achievements = require(Shared.Data.Achievements)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local ClientRoot = script.Parent.Parent
local UIKit = require(ClientRoot.UI.UIKit)
local Theme = require(ClientRoot.UI.Theme)
local State = require(ClientRoot.Lib.State)
local Net = require(ClientRoot.Lib.Net)

local Notifications = {}

local UIController, SoundController
local toastContainer, itemPopupContainer, bannerFrame
local bannerQueue = {}
local bannerRunning = false
local localPlayer = Players.LocalPlayer

local TOAST_COLORS = {
	Info = Theme.Colors.Blue,
	Success = Theme.Colors.Green,
	Error = Theme.Colors.Red,
	Reward = Theme.Colors.Yellow,
}

local function colorToHex(color)
	return string.format("#%02X%02X%02X", color.R * 255, color.G * 255, color.B * 255)
end

-- Adds a line to the chat window (new TextChatService only).
function Notifications.ChatMessage(text)
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		return
	end
	local channels = TextChatService:FindFirstChild("TextChannels")
	local channel = channels and (channels:FindFirstChild("RBXSystem") or channels:FindFirstChild("RBXGeneral"))
	if channel then
		pcall(channel.DisplaySystemMessage, channel, text)
	end
end

-- ============================================================================
-- TOASTS
-- ============================================================================
function Notifications.Toast(text, kind)
	local color = TOAST_COLORS[kind] or Theme.Colors.Blue
	local toast = UIKit.new("Frame", {
		Size = UDim2.fromOffset(340, 50),
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.05,
	}, { UIKit.Corner(Theme.SmallCorner), UIKit.Stroke(color, 3) })
	UIKit.new("Frame", {
		Size = UDim2.new(0, 8, 1, -12),
		Position = UDim2.new(0, 6, 0, 6),
		BackgroundColor3 = color,
		Parent = toast,
	}, { UIKit.Corner(UDim.new(1, 0)) })
	UIKit.Label({
		Text = text,
		Size = UDim2.new(1, -30, 1, -10),
		Position = UDim2.new(0, 20, 0, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.BodyFont,
		Parent = toast,
	}, 18)
	local scale = UIKit.new("UIScale", { Scale = 0.6, Parent = toast })
	toast.Parent = toastContainer
	UIKit.Tween(scale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)

	if kind == "Error" and SoundController then
		SoundController.Play("Error", 0.4)
	end

	-- Keep at most 5 on screen.
	local children = {}
	for _, child in ipairs(toastContainer:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children > 5 then
		children[1]:Destroy()
	end

	task.delay(3.5, function()
		if toast.Parent then
			UIKit.Tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
				toast:Destroy()
			end)
		end
	end)
end

-- ============================================================================
-- ITEM FOUND POPUP
-- ============================================================================
function Notifications.ItemPopup(itemId, isNew, extraText)
	local item = Items.ById[itemId]
	if not item then
		return
	end
	local rarity = Config.RarityByName[item.Rarity]

	local card = UIKit.new("Frame", {
		Size = UDim2.fromOffset(300, 84),
		BackgroundColor3 = Color3.new(1, 1, 1),
	}, {
		UIKit.Corner(Theme.CornerRadius),
		UIKit.Stroke(rarity.Color, 3),
		UIKit.Gradient(rarity.Color:Lerp(Theme.Colors.Panel, 0.35), Theme.Colors.Panel, 0),
	})
	local iconBox = UIKit.new("Frame", {
		Size = UDim2.fromOffset(68, 68),
		Position = UDim2.fromOffset(8, 8),
		BackgroundColor3 = rarity.Color:Lerp(Theme.Colors.Cell, 0.4),
		Parent = card,
	}, { UIKit.Corner(Theme.SmallCorner) })
	UIKit.new("TextLabel", {
		Size = UDim2.fromScale(0.8, 0.8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = item.Icon,
		Parent = iconBox,
	})
	UIKit.Label({
		Text = item.Name,
		Size = UDim2.new(1, -92, 0, 30),
		Position = UDim2.fromOffset(84, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	}, 24)
	UIKit.Label({
		Text = item.Rarity .. (extraText and ("  •  " .. extraText) or ("  •  " .. Util.FormatCash(item.Value))),
		TextColor3 = rarity.Color,
		Size = UDim2.new(1, -92, 0, 22),
		Position = UDim2.fromOffset(84, 44),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = card,
	}, 18)
	if isNew then
		local newTag = UIKit.new("Frame", {
			Size = UDim2.fromOffset(64, 26),
			Position = UDim2.new(1, -6, 0, -10),
			AnchorPoint = Vector2.new(1, 0),
			BackgroundColor3 = Theme.Colors.Yellow,
			Rotation = 8,
			Parent = card,
		}, { UIKit.Corner(UDim.new(1, 0)), UIKit.Stroke(Theme.Colors.Stroke, 2) })
		UIKit.Label({ Text = "NEW!", Size = UDim2.fromScale(1, 1), Parent = newTag }, 18)
	end

	local scale = UIKit.new("UIScale", { Scale = 0.3, Parent = card })
	card.Parent = itemPopupContainer
	UIKit.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)

	local frames = {}
	for _, child in ipairs(itemPopupContainer:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(frames, child)
		end
	end
	if #frames > 3 then
		frames[1]:Destroy()
	end

	task.delay(2.6, function()
		if card.Parent then
			UIKit.Tween(scale, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Connect(function()
				card:Destroy()
			end)
		end
	end)
end

-- ============================================================================
-- BIG BANNER (rare discoveries, zone unlocks, broadcasts)
-- ============================================================================
local function runBanner(entry)
	bannerRunning = true
	local color = entry.Color or Theme.Colors.Yellow
	bannerFrame.Visible = true
	bannerFrame.Position = UDim2.new(0.5, 0, 0, -140)
	bannerFrame.UIGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(0, 0, 0), 0.35)),
		ColorSequenceKeypoint.new(0.5, color),
		ColorSequenceKeypoint.new(1, color:Lerp(Color3.new(0, 0, 0), 0.35)),
	})
	bannerFrame.Title.Text = entry.Title
	bannerFrame.Subtitle.Text = entry.Subtitle or ""
	bannerFrame.Icon.Text = entry.Icon or "✨"

	UIKit.Tween(bannerFrame, 0.45, { Position = UDim2.new(0.5, 0, 0, 70) }, Enum.EasingStyle.Back)
	-- Shimmer sweep
	local shimmer = bannerFrame.UIGradient
	shimmer.Offset = Vector2.new(-1, 0)
	UIKit.Tween(shimmer, 1.2, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine)
	UIKit.Tween(bannerFrame.Icon, 0.5, { Rotation = 360 }, Enum.EasingStyle.Back).Completed:Connect(function()
		bannerFrame.Icon.Rotation = 0
	end)

	task.wait(entry.Duration or 4)
	UIKit.Tween(bannerFrame, 0.3, { Position = UDim2.new(0.5, 0, 0, -140) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.wait(0.35)
	bannerFrame.Visible = false
	bannerRunning = false

	local nextEntry = table.remove(bannerQueue, 1)
	if nextEntry then
		runBanner(nextEntry)
	end
end

function Notifications.Banner(entry)
	if #bannerQueue >= 4 then
		table.remove(bannerQueue, 1)
	end
	table.insert(bannerQueue, entry)
	if not bannerRunning then
		task.spawn(runBanner, table.remove(bannerQueue, 1))
	end
end

-- ============================================================================
-- ZONE SPLASH
-- ============================================================================
function Notifications.ZoneSplash(zoneId)
	local zone = Config.ZoneById[zoneId]
	if not zone then
		return
	end
	local label = UIKit.Label({
		Text = "🔓 " .. zone.Name:upper() .. " UNLOCKED!",
		Size = UDim2.fromScale(0.8, 0.14),
		Position = UDim2.fromScale(0.5, 0.4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		TextColor3 = zone.Theme.Accent:Lerp(Color3.new(1, 1, 1), 0.3),
		TextTransparency = 1,
		Parent = UIController.Overlay,
	}, 72)
	local scale = UIKit.new("UIScale", { Scale = 2, Parent = label })
	UIKit.Tween(label, 0.3, { TextTransparency = 0 })
	UIKit.Tween(scale, 0.5, { Scale = 1 }, Enum.EasingStyle.Back)
	if SoundController then
		SoundController.Play("ZoneUnlock", 0.6)
	end
	task.delay(2.5, function()
		UIKit.Tween(label, 0.5, { TextTransparency = 1 })
		UIKit.Tween(scale, 0.5, { Scale = 0.6 })
		task.wait(0.55)
		label:Destroy()
	end)
end

-- ============================================================================
-- SIGNAL HANDLING
-- ============================================================================
local function announcementsEnabled()
	local settings = State.Get("Settings")
	return not settings or settings.Announcements ~= false
end

local handlers = {}

handlers.Toast = function(payload)
	Notifications.Toast(payload.Text, payload.Kind)
end

handlers.Tip = function(payload)
	Notifications.ChatMessage(payload.Text)
end

handlers.Broadcast = function(payload)
	Notifications.ChatMessage(("<font color='%s'>%s</font>"):format(payload.Color or "#FFFFFF", payload.Text))
	if announcementsEnabled() then
		Notifications.Banner({ Title = payload.Text, Icon = "📢", Color = Theme.Colors.Blue, Duration = 3.5 })
	end
end

handlers.Announce = function(payload)
	local item = Items.ById[payload.ItemId]
	if not item then
		return
	end
	local rarity = Config.RarityByName[item.Rarity]
	local isMe = payload.UserId == localPlayer.UserId
	local verb = payload.IsNew and "discovered" or "found"
	local text = ("%s %s %s!"):format(payload.PlayerName, verb, item.Name)
	Notifications.ChatMessage(("<font color='%s'>[%s] %s %s</font>"):format(colorToHex(rarity.Color), item.Rarity:upper(), item.Icon, text))
	if isMe or announcementsEnabled() then
		Notifications.Banner({
			Title = text,
			Subtitle = ("%s  •  %s"):format(item.Rarity:upper(), Util.FormatCash(item.Value)),
			Icon = item.Icon,
			Color = item.Rarity == "Secret" and Color3.fromRGB(120, 60, 200) or rarity.Color,
			Duration = item.Rarity == "Secret" and 6 or 4,
		})
	end
	if isMe and SoundController then
		SoundController.Play("RareFound", 0.7)
	end
end

handlers.Reward = function(payload)
	Notifications.Toast(("🎁 %s: %s"):format(payload.Source or "Reward", payload.Text or ""), "Reward")
	if SoundController then
		SoundController.Play("ItemFound", 0.5, 0.9)
	end
end

handlers.Achievement = function(payload)
	local achievement = Achievements.ById[payload.Id]
	Notifications.Banner({
		Title = "Achievement Unlocked!",
		Subtitle = achievement and ("🏆 " .. achievement.Name) or "",
		Icon = "🏆",
		Color = Theme.Colors.Orange,
		Duration = 3,
	})
end

handlers.ZoneUnlocked = function(payload)
	Notifications.ZoneSplash(payload.ZoneId)
end

handlers.Sold = function(payload)
	Notifications.Toast(("💰 Sold %d items for %s"):format(payload.Count, Util.FormatCash(payload.Cash)), "Success")
	if SoundController then
		SoundController.Play("Sell", 0.6, 1.3)
	end
end

handlers.ItemFound = function(payload)
	if payload.AutoSold then
		-- Keep auto-sold finds lightweight: no card spam.
		return
	end
	Notifications.ItemPopup(payload.ItemId, payload.IsNew)
	if SoundController then
		SoundController.Play("ItemFound", 0.5, payload.IsNew and 1.25 or 1)
	end
end

function Notifications.Init(controllers)
	UIController = controllers.UIController
	SoundController = controllers.SoundController
	Net.OnError = function(message)
		Notifications.Toast(message, "Error")
	end

	toastContainer = UIKit.new("Frame", {
		Name = "Toasts",
		Size = UDim2.fromOffset(360, 330),
		Position = UDim2.new(1, -16, 1, -110),
		AnchorPoint = Vector2.new(1, 1),
		BackgroundTransparency = 1,
		Parent = UIController.HUDRoot,
	}, { UIKit.List(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Bottom) })

	itemPopupContainer = UIKit.new("Frame", {
		Name = "ItemPopups",
		Size = UDim2.fromOffset(320, 290),
		Position = UDim2.new(0.5, 0, 1, -110),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
		Parent = UIController.HUDRoot,
	}, { UIKit.List(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom) })

	bannerFrame = UIKit.new("Frame", {
		Name = "Banner",
		Size = UDim2.new(0.7, 0, 0, 96),
		Position = UDim2.new(0.5, 0, 0, -140),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = UIController.Overlay,
	}, {
		UIKit.Corner(UDim.new(0, 22)),
		UIKit.Stroke(Theme.Colors.Stroke, 4),
		UIKit.new("UIGradient", { Rotation = 0 }),
		UIKit.new("UISizeConstraint", { MaxSize = Vector2.new(820, 96) }),
	})
	UIKit.new("TextLabel", {
		Name = "Icon",
		Size = UDim2.fromOffset(76, 76),
		Position = UDim2.fromOffset(12, 10),
		BackgroundTransparency = 1,
		TextScaled = true,
		Text = "✨",
		Parent = bannerFrame,
	})
	UIKit.Label({
		Name = "Title",
		Size = UDim2.new(1, -110, 0, 50),
		Position = UDim2.fromOffset(98, 8),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bannerFrame,
	}, 40)
	UIKit.Label({
		Name = "Subtitle",
		Size = UDim2.new(1, -110, 0, 28),
		Position = UDim2.fromOffset(98, 58),
		TextXAlignment = Enum.TextXAlignment.Left,
		Font = Theme.BodyFont,
		Parent = bannerFrame,
	}, 22)
end

function Notifications.Start()
	Remotes.Signal.OnClientEvent:Connect(function(kind, payload)
		local handler = handlers[kind]
		if handler then
			handler(payload)
		end
	end)
end

return Notifications
