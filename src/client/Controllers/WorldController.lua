--[[
	WorldController
	---------------
	Client-side world presentation (all purely visual / local):

	  * Dumpster FX: lid swings open, sound, rarity-colored particle burst and a
	    floating item icon — triggered by the server's "DumpsterFX" signal, so
	    every player sees everyone's searches without server-side tweens.
	  * Per-player cooldown: after YOUR search, that dumpster's prompt is hidden
	    locally and a countdown billboard is shown.
	  * Hold duration: prompts use your Dumpster Speed upgrade locally (the
	    server independently validates hold time).
	  * Zone gates / VIP gate: unlocked gates become non-collidable and
	    invisible on YOUR client only.
	  * Station prompts (Sell, Fusion, Shop, Quests, Collection) open panels.
	  * Gate prompts request zone unlocks / VIP purchase.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Items = require(Shared.Data.Items)
local Remotes = require(Shared.Remotes)

local ClientRoot = script.Parent.Parent
local UIKit = require(ClientRoot.UI.UIKit)
local State = require(ClientRoot.Lib.State)
local Net = require(ClientRoot.Lib.Net)

local WorldController = {}

local Controllers
local localPlayer = Players.LocalPlayer
local dumpsterById = {}
local lidClosed = {}      -- [lid] = original CFrame
local lidAnimating = {}   -- [lid] = true
local cooldownUntil = {}  -- [dumpsterId] = os.clock()

local function lowGraphics()
	local settings = State.Get("Settings")
	return settings and settings.LowGraphics
end

-- ============================================================================
-- DUMPSTER FX
-- ============================================================================
local function animateLid(model)
	local lid = model:FindFirstChild("Lid")
	if not lid or lidAnimating[lid] then
		return
	end
	lidAnimating[lid] = true
	local closed = lidClosed[lid] or lid.CFrame
	lidClosed[lid] = closed
	local hinge = lid:GetAttribute("HingeOffset") or lid.Size.Z / 2
	local open = closed * CFrame.new(0, 0, hinge) * CFrame.Angles(math.rad(75), 0, 0) * CFrame.new(0, 0, -hinge)
	UIKit.Tween(lid, 0.2, { CFrame = open }, Enum.EasingStyle.Back)
	task.delay(0.9, function()
		UIKit.Tween(lid, 0.35, { CFrame = closed }, Enum.EasingStyle.Bounce).Completed:Wait()
		lidAnimating[lid] = nil
	end)
end

local function burst(model, color, amount)
	local body = model:FindFirstChild("Body") or model.PrimaryPart
	if not body then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, body.Size.Y / 2 + 0.5, 0)
	attachment.Parent = body
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.8
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Lifetime = NumberRange.new(0.6, 1.1)
	emitter.Acceleration = Vector3.new(0, -20, 0)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Rate = 0
	emitter.Parent = attachment
	emitter:Emit(lowGraphics() and math.floor(amount / 3) or amount)
	Debris:AddItem(attachment, 2)
end

local function floatingIcon(model, itemId)
	local item = Items.ById[itemId]
	local body = model:FindFirstChild("Body") or model.PrimaryPart
	if not item or not body then
		return
	end
	local rarity = Config.RarityByName[item.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 90)
	gui.StudsOffset = Vector3.new(0, 4, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Adornee = body
	UIKit.new("TextLabel", { Size = UDim2.fromScale(1, 0.62), BackgroundTransparency = 1, TextScaled = true, Text = item.Icon, Parent = gui })
	UIKit.Label({ Text = item.Name, TextColor3 = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.2), Size = UDim2.fromScale(1, 0.36), Position = UDim2.fromScale(0, 0.64), Parent = gui }, 22)
	gui.Parent = localPlayer:FindFirstChildOfClass("PlayerGui")
	UIKit.Tween(gui, 1.4, { StudsOffset = Vector3.new(0, 8, 0) }, Enum.EasingStyle.Quad)
	task.delay(1.1, function()
		for _, child in ipairs(gui:GetChildren()) do
			if child:IsA("TextLabel") then
				UIKit.Tween(child, 0.3, { TextTransparency = 1 })
			end
		end
	end)
	Debris:AddItem(gui, 1.5)
end

local function showCooldown(model, dumpsterId, seconds)
	local body = model:FindFirstChild("Body") or model.PrimaryPart
	local searchPrompt = model:FindFirstChild("SearchPrompt", true)
	if not body then
		return
	end
	cooldownUntil[dumpsterId] = os.clock() + seconds
	if searchPrompt then
		searchPrompt.Enabled = false
	end
	local gui = body:FindFirstChild("CooldownGui")
	if not gui then
		gui = Instance.new("BillboardGui")
		gui.Name = "CooldownGui"
		gui.Size = UDim2.fromOffset(90, 40)
		gui.StudsOffset = Vector3.new(0, 4.5, 0)
		gui.MaxDistance = 60
		gui.LightInfluence = 0
		UIKit.Label({ Name = "Text", Size = UDim2.fromScale(1, 1), Text = "", Parent = gui }, 28)
		gui.Parent = body
	end
	gui.Enabled = true
	task.spawn(function()
		while cooldownUntil[dumpsterId] and os.clock() < cooldownUntil[dumpsterId] do
			gui.Text.Text = ("⏱️ %.1f"):format(cooldownUntil[dumpsterId] - os.clock())
			task.wait(0.1)
		end
		if cooldownUntil[dumpsterId] and os.clock() >= cooldownUntil[dumpsterId] then
			cooldownUntil[dumpsterId] = nil
			gui.Enabled = false
			if searchPrompt then
				searchPrompt.Enabled = true
			end
		end
	end)
end

local function onDumpsterFX(payload)
	local model = payload.Dumpster
	if not model or not model.Parent then
		return
	end
	local rarity = Config.RarityByName[payload.Rarity]
	animateLid(model)
	local isMine = payload.UserId == localPlayer.UserId
	local body = model:FindFirstChild("Body")
	if Controllers.SoundController and body then
		Controllers.SoundController.PlayAt("DumpsterOpen", body, isMine and 0.6 or 0.25)
	end
	local amount = rarity and (8 + rarity.Order * 6) or 10
	burst(model, rarity and rarity.Color or Color3.new(1, 1, 1), amount)
end

local function onItemFound(payload)
	local model = payload.DumpsterId and dumpsterById[payload.DumpsterId]
	if not model then
		return
	end
	if payload.Cooldown then
		showCooldown(model, payload.DumpsterId, payload.Cooldown)
	end
	floatingIcon(model, payload.ItemId)
end

-- ============================================================================
-- DUMPSTER REGISTRATION + HOLD DURATION
-- ============================================================================
local function applyHoldDuration(model)
	local searchPrompt = model:FindFirstChild("SearchPrompt", true)
	if searchPrompt and State.Data then
		searchPrompt.HoldDuration = Formulas.GetHoldDuration(State.Data)
	end
end

local function registerDumpster(model)
	local id = model:GetAttribute("DumpsterId")
	if id then
		dumpsterById[id] = model
	end
	applyHoldDuration(model)
end

-- ============================================================================
-- GATES
-- ============================================================================
local function setGateOpen(gate, open)
	gate.CanCollide = not open
	gate.Transparency = open and 1 or 0.2
	for _, child in ipairs(gate:GetChildren()) do
		if child:IsA("SurfaceGui") then
			child.Enabled = not open
		elseif child:IsA("ProximityPrompt") then
			child.Enabled = not open
		end
	end
end

local function refreshGates()
	local data = State.Data
	if not data then
		return
	end
	for _, gate in ipairs(CollectionService:GetTagged("ZoneGate")) do
		local zoneId = gate:GetAttribute("ZoneId")
		setGateOpen(gate, data.Zones[tostring(zoneId)] == true)
	end
	local vip = data.Passes and data.Passes.VIP
	for _, gate in ipairs(CollectionService:GetTagged("VIPGate")) do
		setGateOpen(gate, vip == true)
	end
end

-- ============================================================================
-- STATION / GATE PROMPTS
-- ============================================================================
local STATION_PANELS = {
	Sell = "Sell",
	Fusion = "Fusion",
	Shop = "Shop",
	Quests = "Quests",
	Collection = "Collection",
}

local function onPromptTriggered(prompt)
	local station = prompt:GetAttribute("Station")
	if station and STATION_PANELS[station] then
		Controllers.UIController.Open(STATION_PANELS[station])
		return
	end
	if prompt.Name == "UnlockPrompt" then
		local zoneId = prompt:GetAttribute("ZoneId")
		Net.RequestAsync("UnlockZone", { ZoneId = zoneId }, function(success)
			if not success then
				Controllers.UIController.Open("Shop")
				Controllers.ShopPanel.SelectTab("Zones")
			end
		end, false)
	elseif prompt.Name == "VIPPrompt" then
		Net.RequestAsync("BuyPass", { Name = "VIP" })
	end
end

function WorldController.Init(controllers)
	Controllers = controllers
end

function WorldController.Start()
	for _, model in ipairs(CollectionService:GetTagged("Dumpster")) do
		registerDumpster(model)
	end
	CollectionService:GetInstanceAddedSignal("Dumpster"):Connect(registerDumpster)
	CollectionService:GetInstanceAddedSignal("ZoneGate"):Connect(refreshGates)
	CollectionService:GetInstanceAddedSignal("VIPGate"):Connect(refreshGates)

	State.Watch("Upgrades", function()
		for _, model in pairs(dumpsterById) do
			applyHoldDuration(model)
		end
	end)
	State.Watch("Zones", refreshGates)
	State.Watch("Passes", refreshGates)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player == localPlayer then
			onPromptTriggered(prompt)
		end
	end)

	Remotes.Signal.OnClientEvent:Connect(function(kind, payload)
		if kind == "DumpsterFX" then
			onDumpsterFX(payload)
		elseif kind == "ItemFound" then
			onItemFound(payload)
		end
	end)
end

return WorldController
