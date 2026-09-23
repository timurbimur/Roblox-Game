--[[
	Tutorial
	--------
	First-time player guide. Steps advance from REAL server stats, so the
	tutorial can't desync from progress:
	  1. Search a dumpster        (Stats.Searches >= 1)
	  2. Search 5 dumpsters       (Stats.Searches >= 5)
	  3. Fuse two items           (Stats.Fusions >= 1)
	  4. Sell some junk           (Stats.ItemsSold >= 1)
	  5. Buy an upgrade           (any upgrade level > 0)
	A glowing beam + bouncing arrow points at the nearest target.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ClientRoot = script.Parent.Parent
local UIKit = require(ClientRoot.UI.UIKit)
local Theme = require(ClientRoot.UI.Theme)
local State = require(ClientRoot.Lib.State)
local Net = require(ClientRoot.Lib.Net)

local Tutorial = {}

local Controllers
local localPlayer = Players.LocalPlayer
local card, stepLabel, textLabel
local beam, beamAttachment, targetAttachment, arrowGui
local finished = false

local function nearestTagged(tag, filter)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, instance in ipairs(CollectionService:GetTagged(tag)) do
		if not filter or filter(instance) then
			local part = instance:IsA("Model") and (instance.PrimaryPart or instance:FindFirstChildWhichIsA("BasePart")) or instance
			if part then
				local distance = (part.Position - root.Position).Magnitude
				if distance < bestDistance then
					best, bestDistance = part, distance
				end
			end
		end
	end
	return best
end

local function findShop()
	local map = Workspace:FindFirstChild("Map")
	local shop = map and map:FindFirstChild("Shop", true)
	return shop and (shop.PrimaryPart or shop:FindFirstChildWhichIsA("BasePart"))
end

local function anyUpgrade(data)
	for _, level in pairs(data.Upgrades) do
		if level > 0 then
			return true
		end
	end
	return false
end

local STEPS = {
	{
		Text = "Walk up to a dumpster and HOLD E to search it!",
		Done = function(data) return data.Stats.Searches >= 1 end,
		Target = function()
			return nearestTagged("Dumpster", function(model) return model:GetAttribute("ZoneId") == 0 end)
		end,
	},
	{
		Text = "Nice find! Search 5 dumpsters to fill your backpack.",
		Progress = function(data) return ("%d / 5"):format(math.min(5, data.Stats.Searches)) end,
		Done = function(data) return data.Stats.Searches >= 5 end,
		Target = function()
			return nearestTagged("Dumpster", function(model) return model:GetAttribute("ZoneId") == 0 end)
		end,
	},
	{
		Text = "Go to the Fusion Machine ⚗️ and fuse two items together!",
		Done = function(data) return data.Stats.Fusions >= 1 end,
		Target = function() return nearestTagged("FusionStation") end,
	},
	{
		Text = "Sell your junk at the Sell Station 💰 for cash!",
		Done = function(data) return data.Stats.ItemsSold >= 1 end,
		Target = function() return nearestTagged("SellStation") end,
	},
	{
		Text = "Open the Shop 🛒 and buy your first upgrade!",
		Done = anyUpgrade,
		Target = findShop,
	},
}

local function clearGuide()
	if beam then
		beam.Enabled = false
	end
	if arrowGui then
		arrowGui.Enabled = false
	end
end

local function pointAt(part)
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not part or not root then
		clearGuide()
		return
	end
	if not beamAttachment or beamAttachment.Parent ~= root then
		beamAttachment = Instance.new("Attachment")
		beamAttachment.Name = "TutorialAttachment"
		beamAttachment.Parent = root
	end
	if not targetAttachment then
		targetAttachment = Instance.new("Attachment")
		targetAttachment.Name = "TutorialTarget"
	end
	if targetAttachment.Parent ~= part then
		targetAttachment.Parent = part
		targetAttachment.Position = Vector3.new(0, part.Size.Y / 2 + 1, 0)
	end
	if not beam then
		beam = Instance.new("Beam")
		beam.Color = ColorSequence.new(Theme.Colors.Yellow)
		beam.Width0 = 0.6
		beam.Width1 = 0.6
		beam.FaceCamera = true
		beam.LightEmission = 1
		beam.Transparency = NumberSequence.new(0.2)
		beam.Segments = 20
		beam.CurveSize0 = 4
		beam.Parent = Workspace
	end
	beam.Attachment0 = beamAttachment
	beam.Attachment1 = targetAttachment
	beam.Enabled = true

	if not arrowGui then
		arrowGui = Instance.new("BillboardGui")
		arrowGui.Size = UDim2.fromOffset(80, 80)
		arrowGui.AlwaysOnTop = true
		arrowGui.LightInfluence = 0
		arrowGui.StudsOffset = Vector3.new(0, 7, 0)
		UIKit.Label({ Text = "⬇", Size = UDim2.fromScale(1, 1), TextColor3 = Theme.Colors.Yellow, Parent = arrowGui }, 80)
		arrowGui.Parent = localPlayer:WaitForChild("PlayerGui")
		task.spawn(function()
			local up = true
			while arrowGui do
				UIKit.Tween(arrowGui, 0.45, { StudsOffset = Vector3.new(0, up and 8.5 or 7, 0) }, Enum.EasingStyle.Sine)
				up = not up
				task.wait(0.45)
			end
		end)
	end
	arrowGui.Adornee = part
	arrowGui.Enabled = true
end

local function finish()
	finished = true
	clearGuide()
	if beam then
		beam:Destroy()
		beam = nil
	end
	if arrowGui then
		arrowGui:Destroy()
		arrowGui = nil
	end
	if card then
		UIKit.Tween(card, 0.3, { Position = UDim2.new(0.5, 0, 0, -200) })
	end
	Net.RequestAsync("CompleteTutorial", nil, nil, true)
	if Controllers.Notifications then
		Controllers.Notifications.Banner({ Title = "Tutorial complete!", Subtitle = "Unlock new zones and discover every item!", Icon = "🎓", Color = Theme.Colors.Green, Duration = 3.5 })
	end
end

local function update()
	local data = State.Data
	if finished or not data then
		return
	end
	if data.TutorialDone then
		finished = true
		card.Visible = false
		clearGuide()
		return
	end
	for index, step in ipairs(STEPS) do
		if not step.Done(data) then
			card.Visible = true
			stepLabel.Text = ("TUTORIAL  •  STEP %d / %d"):format(index, #STEPS)
			textLabel.Text = step.Text .. (step.Progress and ("  (" .. step.Progress(data) .. ")") or "")
			local panelOpen = Controllers.UIController.GetOpen() ~= nil
			if panelOpen then
				clearGuide()
			else
				pointAt(step.Target())
			end
			return
		end
	end
	finish()
end

function Tutorial.Init(controllers)
	Controllers = controllers
	card = UIKit.new("Frame", {
		Name = "Tutorial",
		Size = UDim2.fromOffset(520, 84),
		Position = UDim2.new(0.5, 0, 0, 100),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		Parent = controllers.UIController.HUDRoot,
	}, { UIKit.Corner(Theme.CornerRadius), UIKit.Stroke(Theme.Colors.Yellow, 3) })
	stepLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 6), TextColor3 = Theme.Colors.Yellow, Parent = card }, 18)
	textLabel = UIKit.Label({ Text = "", Size = UDim2.new(1, -20, 0, 44), Position = UDim2.fromOffset(10, 32), Font = Theme.BodyFont, Parent = card }, 20)
end

function Tutorial.Start()
	State.OnAnyChanged(function()
		update()
	end)
	task.spawn(function()
		while not finished do
			task.wait(0.5)
			update()
		end
	end)
end

return Tutorial
