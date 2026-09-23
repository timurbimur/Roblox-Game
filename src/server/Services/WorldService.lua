--[[
	WorldService
	------------
	Procedurally builds the entire map at server start so the game works from a
	blank baseplate with zero manual building:

	  Spawn (Starter Alley)  tutorial signs, starter dumpsters, Sell Station,
	                         Fusion Machine, Shop, Quest board, Collection book,
	                         VIP room with VIP dumpsters
	  Zones 1-6              themed ground, decorations, better dumpsters,
	                         their own Sell Station + Fusion Machine, lock gate

	Everything is deterministic (fixed RNG seed) so every server looks the same.

	Want hand-built maps instead? Delete the build calls in Start() and place your
	own models. Tag dumpster models "Dumpster" with a "ZoneId" number attribute
	(-1 = VIP) and stations "SellStation"/"FusionStation" — DumpsterService picks
	them up automatically through CollectionService.

	Also provides geometry helpers used by other services (zone lookup, station
	proximity checks, teleport destinations).
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)

local WorldService = {}

local mapFolder
local rng = Random.new(1337)
local dumpsterCounter = 0

local SPACING = Config.World.ZoneSpacing
local VIP_REGION = { Min = Vector3.new(56, -10, 56), Max = Vector3.new(94, 40, 94) }

-- ============================================================================
-- GEOMETRY HELPERS
-- ============================================================================
function WorldService.GetZoneCenter(zoneId)
	return Vector3.new(zoneId * SPACING, 0, 0)
end

function WorldService.GetZoneHalfSize(zoneId)
	return (zoneId == 0 and Config.World.SpawnSize or Config.World.ZoneSize) / 2
end

-- Returns the zone id containing `position`, or nil (roads / outside).
function WorldService.GetZoneAtPosition(position)
	local zoneId = math.floor(position.X / SPACING + 0.5)
	if not Config.ZoneById[zoneId] then
		return nil
	end
	local center = WorldService.GetZoneCenter(zoneId)
	local half = WorldService.GetZoneHalfSize(zoneId)
	if math.abs(position.X - center.X) <= half and math.abs(position.Z - center.Z) <= half then
		return zoneId
	end
	return nil
end

function WorldService.IsInVIPRoom(position)
	return position.X >= VIP_REGION.Min.X and position.X <= VIP_REGION.Max.X
		and position.Z >= VIP_REGION.Min.Z and position.Z <= VIP_REGION.Max.Z
		and position.Y <= VIP_REGION.Max.Y
end

function WorldService.GetSpawnCFrame(zoneId)
	if zoneId == "VIP" then
		return CFrame.new(75, 4, 75)
	end
	local center = WorldService.GetZoneCenter(zoneId)
	if zoneId == 0 then
		return CFrame.lookAt(Vector3.new(-40, 4, 0), Vector3.new(0, 4, 0))
	end
	local half = WorldService.GetZoneHalfSize(zoneId)
	local position = center + Vector3.new(-half + 14, 4, 0)
	return CFrame.lookAt(position, center + Vector3.new(0, 4, 0))
end

local function getRoot(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root
	end
	return nil
end
WorldService.GetRoot = getRoot

-- Server-side proximity validation for station actions (sell/fuse).
function WorldService.IsNearStation(player, tag, range)
	local root = getRoot(player)
	if not root then
		return false
	end
	for _, station in ipairs(CollectionService:GetTagged(tag)) do
		local position = station:IsA("Model") and station:GetPivot().Position or station.Position
		if (position - root.Position).Magnitude <= range then
			return true
		end
	end
	return false
end

-- ============================================================================
-- BUILD HELPERS
-- ============================================================================
local function part(props)
	local p = Instance.new(props.ClassName or "Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape -- set first: shape can constrain Size
	end
	for key, value in pairs(props) do
		if key ~= "ClassName" and key ~= "Parent" and key ~= "Shape" and key ~= "CFrame" then
			p[key] = value
		end
	end
	if props.CFrame then
		p.CFrame = props.CFrame
	end
	p.Parent = props.Parent
	return p
end

local function billboard(adornee, text, color, size, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = size or UDim2.fromOffset(220, 60)
	gui.StudsOffset = offset or Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 120
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.new(0, 0, 0)
	stroke.Parent = label

	gui.Parent = adornee
	return gui, label
end

local function surfaceText(target, face, text, textColor, bgColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 30
	gui.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bgColor or Color3.new(0, 0, 0)
	label.BackgroundTransparency = bgColor and 0 or 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = textColor or Color3.new(1, 1, 1)
	label.Parent = gui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label

	gui.Parent = target
	return gui
end

local function prompt(parent, actionText, objectText, holdDuration, distance)
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionText
	p.ObjectText = objectText or ""
	p.HoldDuration = holdDuration or 0
	p.MaxActivationDistance = distance or 12
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.Parent = parent
	return p
end

local function darken(color, amount)
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

local function lighten(color, amount)
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

-- ============================================================================
-- DUMPSTER MODEL
-- ============================================================================
local function buildDumpster(parent, position, lookAt, zoneId, theme, isVIP)
	dumpsterCounter += 1
	local tier = math.max(zoneId, 0)
	local scale = 1 + tier * 0.06
	local model = Instance.new("Model")
	model.Name = "Dumpster"

	local base = CFrame.lookAt(position, Vector3.new(lookAt.X, position.Y, lookAt.Z))
	local bodyColor = isVIP and Color3.fromRGB(255, 200, 40) or theme.Dumpster
	local bodySize = Vector3.new(8, 5, 5) * scale
	local wheelHeight = 0.9 * scale

	local body = part({
		Name = "Body", Parent = model,
		Size = bodySize,
		CFrame = base * CFrame.new(0, wheelHeight + bodySize.Y / 2, 0),
		Color = bodyColor,
		Material = tier >= 4 and Enum.Material.SmoothPlastic or Enum.Material.Metal,
	})
	model.PrimaryPart = body

	-- Inner "trash" visible when lid opens.
	part({
		Name = "Trash", Parent = model, CanCollide = false,
		Size = Vector3.new(bodySize.X - 0.6, 0.4, bodySize.Z - 0.6),
		CFrame = body.CFrame * CFrame.new(0, bodySize.Y / 2 - 0.4, 0),
		Color = Color3.fromRGB(70, 60, 40), Material = Enum.Material.Pebble,
	})

	-- Trim stripe (neon on higher tiers)
	part({
		Name = "Trim", Parent = model, CanCollide = false,
		Size = Vector3.new(bodySize.X + 0.1, 0.5 * scale, bodySize.Z + 0.1),
		CFrame = body.CFrame * CFrame.new(0, bodySize.Y / 2 - 0.8 * scale, 0),
		Color = isVIP and Color3.fromRGB(255, 255, 255) or theme.Accent,
		Material = (tier >= 3 or isVIP) and Enum.Material.Neon or Enum.Material.SmoothPlastic,
	})

	-- Lid (animated client-side). Hinge is along the back (+Z) edge.
	local lid = part({
		Name = "Lid", Parent = model, CanCollide = false,
		Size = Vector3.new(bodySize.X + 0.3, 0.35, bodySize.Z + 0.3),
		CFrame = body.CFrame * CFrame.new(0, bodySize.Y / 2 + 0.18, 0),
		Color = darken(bodyColor, 0.35),
		Material = Enum.Material.Metal,
	})
	lid:SetAttribute("HingeOffset", lid.Size.Z / 2)

	-- Wheels
	for _, offset in ipairs({ Vector3.new(-1, 0, -1), Vector3.new(1, 0, -1), Vector3.new(-1, 0, 1), Vector3.new(1, 0, 1) }) do
		part({
			Name = "Wheel", Parent = model, CanCollide = false, Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.6, wheelHeight * 1.2, wheelHeight * 1.2),
			CFrame = base * CFrame.new(offset.X * (bodySize.X / 2 - 0.8), wheelHeight * 0.6, offset.Z * (bodySize.Z / 2 - 0.7)) * CFrame.Angles(0, math.rad(90), 0),
			Color = Color3.fromRGB(25, 25, 25),
		})
	end

	-- Zone flair
	if tier >= 3 or isVIP then
		local light = Instance.new("PointLight")
		light.Color = isVIP and Color3.fromRGB(255, 220, 90) or theme.Accent
		light.Range = 10
		light.Brightness = 1.2
		light.Parent = body
	end
	if tier >= 4 or isVIP then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkles.Rate = 3
		sparkles.Lifetime = NumberRange.new(1, 1.6)
		sparkles.Speed = NumberRange.new(1, 2)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new(0.4)
		sparkles.Color = ColorSequence.new(isVIP and Color3.fromRGB(255, 220, 90) or theme.Accent)
		sparkles.LightEmission = 1
		sparkles.Parent = body
	end

	local zoneName = isVIP and "VIP Dumpster" or (Config.ZoneById[zoneId].Name .. " Dumpster")
	local searchPrompt = prompt(body, "Search Dumpster", zoneName, Config.Search.HoldDuration, Config.Search.MaxDistance)
	searchPrompt.Name = "SearchPrompt"

	model:SetAttribute("ZoneId", isVIP and -1 or zoneId)
	model:SetAttribute("DumpsterId", "D" .. dumpsterCounter)
	model.Parent = parent
	CollectionService:AddTag(model, "Dumpster")
	return model
end

-- ============================================================================
-- STATIONS
-- ============================================================================
local function buildSellStation(parent, position)
	local model = Instance.new("Model")
	model.Name = "SellStation"
	local pad = part({
		Name = "Pad", Parent = model, Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1, 14, 14),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(60, 220, 110), Material = Enum.Material.Neon,
	})
	local counter = part({
		Name = "Counter", Parent = model,
		Size = Vector3.new(8, 4, 3),
		CFrame = CFrame.new(position + Vector3.new(0, 3, -5)),
		Color = Color3.fromRGB(40, 150, 80), Material = Enum.Material.SmoothPlastic,
	})
	model.PrimaryPart = pad
	billboard(counter, "💰 SELL", Color3.fromRGB(120, 255, 150), UDim2.fromOffset(240, 70), Vector3.new(0, 5, 0))
	local p = prompt(counter, "Sell Items", "Sell Station", 0, 16)
	p.Name = "StationPrompt"
	p:SetAttribute("Station", "Sell")
	model.Parent = parent
	CollectionService:AddTag(model, "SellStation")
	return model
end

local function buildFusionMachine(parent, position)
	local model = Instance.new("Model")
	model.Name = "FusionMachine"
	local base = part({
		Name = "Base", Parent = model, Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2, 12, 12),
		CFrame = CFrame.new(position + Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(45, 45, 60), Material = Enum.Material.Metal,
	})
	part({
		Name = "Ring", Parent = model, Shape = Enum.PartType.Cylinder, CanCollide = false,
		Size = Vector3.new(0.6, 12.6, 12.6),
		CFrame = CFrame.new(position + Vector3.new(0, 2.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(190, 90, 255), Material = Enum.Material.Neon,
	})
	local dome = part({
		Name = "Dome", Parent = model, Shape = Enum.PartType.Ball,
		Size = Vector3.new(9, 9, 9),
		CFrame = CFrame.new(position + Vector3.new(0, 5.5, 0)),
		Color = Color3.fromRGB(160, 220, 255), Material = Enum.Material.Glass, Transparency = 0.45,
	})
	part({
		Name = "Core", Parent = model, Shape = Enum.PartType.Ball, CanCollide = false,
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(position + Vector3.new(0, 5.5, 0)),
		Color = Color3.fromRGB(200, 120, 255), Material = Enum.Material.Neon,
	})
	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "Pipe", Parent = model, Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(7, 1.6, 1.6),
			CFrame = CFrame.new(position + Vector3.new(side * 6, 3.5, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			Color = Color3.fromRGB(120, 120, 140), Material = Enum.Material.Metal,
		})
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(200, 120, 255)
	light.Range = 18
	light.Brightness = 2
	light.Parent = dome

	model.PrimaryPart = base
	billboard(dome, "⚗️ FUSION", Color3.fromRGB(220, 160, 255), UDim2.fromOffset(260, 70), Vector3.new(0, 7, 0))
	local p = prompt(dome, "Open Fusion Machine", "Fusion Station", 0, 16)
	p.Name = "StationPrompt"
	p:SetAttribute("Station", "Fusion")
	model.Parent = parent
	CollectionService:AddTag(model, "FusionStation")
	return model
end

local function buildKiosk(parent, position, name, text, color, stationType, actionText)
	local model = Instance.new("Model")
	model.Name = name
	local booth = part({
		Name = "Booth", Parent = model,
		Size = Vector3.new(10, 7, 4),
		CFrame = CFrame.new(position + Vector3.new(0, 3.5, 0)),
		Color = color, Material = Enum.Material.SmoothPlastic,
	})
	part({
		Name = "Roof", Parent = model,
		Size = Vector3.new(12, 1, 6),
		CFrame = CFrame.new(position + Vector3.new(0, 7.5, 0.5)),
		Color = lighten(color, 0.3), Material = Enum.Material.Neon,
	})
	model.PrimaryPart = booth
	billboard(booth, text, lighten(color, 0.5), UDim2.fromOffset(260, 70), Vector3.new(0, 7, 0))
	local p = prompt(booth, actionText, name, 0, 14)
	p.Name = "StationPrompt"
	p:SetAttribute("Station", stationType)
	model.Parent = parent
	return model
end

-- ============================================================================
-- DECORATION KIT
-- ============================================================================
local Decor = {}

function Decor.Tree(parent, position, leafColor)
	local height = rng:NextNumber(8, 13)
	part({ Name = "Trunk", Parent = parent, Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.6, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 75, 45), Material = Enum.Material.Wood })
	part({ Name = "Leaves", Parent = parent, Shape = Enum.PartType.Ball,
		Size = Vector3.one * rng:NextNumber(7, 10),
		CFrame = CFrame.new(position + Vector3.new(0, height + 2, 0)),
		Color = leafColor or Color3.fromRGB(60, 150, 60), Material = Enum.Material.Grass })
end

function Decor.Palm(parent, position)
	local height = rng:NextNumber(12, 17)
	part({ Name = "Trunk", Parent = parent, Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, 1.4, 1.4),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(88)),
		Color = Color3.fromRGB(150, 110, 60), Material = Enum.Material.Wood })
	for i = 1, 5 do
		local angle = i / 5 * math.pi * 2
		part({ Name = "Leaf", Parent = parent, CanCollide = false,
			Size = Vector3.new(1.2, 0.3, 7),
			CFrame = CFrame.new(position + Vector3.new(0, height, 0)) * CFrame.Angles(0, angle, 0) * CFrame.new(0, -0.8, -3) * CFrame.Angles(math.rad(-20), 0, 0),
			Color = Color3.fromRGB(50, 170, 70), Material = Enum.Material.Grass })
	end
end

function Decor.House(parent, position, facing, wallColor, roofColor, size)
	size = size or Vector3.new(18, 10, 14)
	local cf = CFrame.lookAt(position, position + facing) * CFrame.new(0, size.Y / 2, 0)
	part({ Name = "Walls", Parent = parent, Size = size, CFrame = cf, Color = wallColor, Material = Enum.Material.SmoothPlastic })
	-- Pitched roof from two wedges
	for _, side in ipairs({ -1, 1 }) do
		part({ ClassName = "WedgePart", Name = "Roof", Parent = parent,
			Size = Vector3.new(size.X + 1, size.Y * 0.45, size.Z / 2 + 0.5),
			CFrame = cf * CFrame.new(0, size.Y / 2 + size.Y * 0.225, side * (size.Z / 4 + 0.25)) * CFrame.Angles(0, side == 1 and math.pi or 0, 0),
			Color = roofColor, Material = Enum.Material.Slate })
	end
	part({ Name = "Door", Parent = parent, Size = Vector3.new(3, 6, 0.3),
		CFrame = cf * CFrame.new(0, -size.Y / 2 + 3, -size.Z / 2 - 0.1),
		Color = darken(wallColor, 0.5), Material = Enum.Material.Wood })
	for _, x in ipairs({ -5, 5 }) do
		part({ Name = "Window", Parent = parent, Size = Vector3.new(3, 3, 0.3),
			CFrame = cf * CFrame.new(x, 0.5, -size.Z / 2 - 0.1),
			Color = Color3.fromRGB(170, 220, 255), Material = Enum.Material.Glass, Transparency = 0.2 })
	end
end

function Decor.Shack(parent, position, facing)
	local size = Vector3.new(rng:NextNumber(10, 14), rng:NextNumber(7, 9), rng:NextNumber(9, 12))
	local cf = CFrame.lookAt(position, position + facing) * CFrame.new(0, size.Y / 2, 0)
	part({ Name = "Shack", Parent = parent, Size = size, CFrame = cf,
		Color = Color3.fromRGB(rng:NextInteger(110, 150), rng:NextInteger(80, 100), 60), Material = Enum.Material.WoodPlanks })
	part({ Name = "TinRoof", Parent = parent, Size = Vector3.new(size.X + 2, 0.4, size.Z + 2),
		CFrame = cf * CFrame.new(0, size.Y / 2 + 0.4, 0) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), 0, math.rad(rng:NextNumber(-5, 5))),
		Color = Color3.fromRGB(140, 90, 60), Material = Enum.Material.CorrodedMetal })
end

function Decor.Tower(parent, position, height, color, accent)
	local width = rng:NextNumber(16, 24)
	part({ Name = "Tower", Parent = parent, Size = Vector3.new(width, height, width),
		CFrame = CFrame.new(position + Vector3.new(0, height / 2, 0)),
		Color = color, Material = Enum.Material.Glass, Reflectance = 0.15 })
	for y = 12, height - 6, 14 do
		part({ Name = "Stripe", Parent = parent, CanCollide = false, Size = Vector3.new(width + 0.3, 0.6, width + 0.3),
			CFrame = CFrame.new(position + Vector3.new(0, y, 0)), Color = accent, Material = Enum.Material.Neon })
	end
end

function Decor.Mansion(parent, position, facing, accent)
	local size = Vector3.new(30, 14, 18)
	local cf = CFrame.lookAt(position, position + facing) * CFrame.new(0, size.Y / 2, 0)
	part({ Name = "Mansion", Parent = parent, Size = size, CFrame = cf, Color = Color3.fromRGB(248, 244, 236), Material = Enum.Material.Marble })
	part({ Name = "Roof", Parent = parent, Size = size + Vector3.new(2, -size.Y + 1.2, 2),
		CFrame = cf * CFrame.new(0, size.Y / 2 + 0.6, 0), Color = accent, Material = Enum.Material.Metal })
	for x = -12, 12, 6 do
		part({ Name = "Column", Parent = parent, Shape = Enum.PartType.Cylinder, Size = Vector3.new(size.Y, 1.6, 1.6),
			CFrame = cf * CFrame.new(x, 0, -size.Z / 2 - 2) * CFrame.Angles(0, 0, math.rad(90)),
			Color = accent, Material = Enum.Material.Metal })
	end
end

function Decor.StreetLight(parent, position, color)
	part({ Name = "Pole", Parent = parent, Size = Vector3.new(0.6, 12, 0.6),
		CFrame = CFrame.new(position + Vector3.new(0, 6, 0)), Color = Color3.fromRGB(40, 40, 45), Material = Enum.Material.Metal })
	local bulb = part({ Name = "Bulb", Parent = parent, Shape = Enum.PartType.Ball, CanCollide = false, Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = CFrame.new(position + Vector3.new(0, 12.4, 0)), Color = color or Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon })
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1
	light.Color = color or Color3.fromRGB(255, 240, 200)
	light.Parent = bulb
end

function Decor.TrashPile(parent, position)
	for _ = 1, rng:NextInteger(3, 6) do
		part({ Name = "Junk", Parent = parent, CanCollide = false,
			Size = Vector3.new(rng:NextNumber(0.8, 2.5), rng:NextNumber(0.5, 2), rng:NextNumber(0.8, 2.5)),
			CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-2.5, 2.5), 0.6, rng:NextNumber(-2.5, 2.5))) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)),
			Color = Color3.fromHSV(rng:NextNumber(), 0.4, rng:NextNumber(0.3, 0.8)), Material = Enum.Material.SmoothPlastic })
	end
end

function Decor.Fence(parent, from, to, color)
	local length = (to - from).Magnitude
	local mid = (from + to) / 2
	part({ Name = "Fence", Parent = parent, Size = Vector3.new(0.4, 3, length),
		CFrame = CFrame.lookAt(mid + Vector3.new(0, 1.5, 0), to + Vector3.new(0, 1.5, 0)),
		Color = color, Material = Enum.Material.WoodPlanks })
end

function Decor.Hill(parent, position, radius, color)
	part({ Name = "Hill", Parent = parent, Shape = Enum.PartType.Ball, Size = Vector3.one * radius * 2,
		CFrame = CFrame.new(position - Vector3.new(0, radius * 0.55, 0)), Color = color, Material = Enum.Material.Grass })
end

function Decor.Statue(parent, position, color)
	part({ Name = "Plinth", Parent = parent, Size = Vector3.new(6, 4, 6), CFrame = CFrame.new(position + Vector3.new(0, 2, 0)),
		Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.Marble })
	part({ Name = "Figure", Parent = parent, Size = Vector3.new(2.5, 8, 2.5), CFrame = CFrame.new(position + Vector3.new(0, 8, 0)),
		Color = color, Material = Enum.Material.Neon })
	part({ Name = "Head", Parent = parent, Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(position + Vector3.new(0, 13.5, 0)),
		Color = color, Material = Enum.Material.Neon })
end

-- Places decoration objects along the perimeter band of a zone, leaving the
-- road openings (|z| small on the ±X sides) clear.
local function perimeterSpots(center, half, inset, step)
	local spots = {}
	local d = half - inset
	for t = -d, d, step do
		table.insert(spots, { Pos = center + Vector3.new(t, 0, -d), Facing = Vector3.new(0, 0, 1) })
		table.insert(spots, { Pos = center + Vector3.new(t, 0, d), Facing = Vector3.new(0, 0, -1) })
		if math.abs(t) > 26 then
			table.insert(spots, { Pos = center + Vector3.new(-d, 0, t), Facing = Vector3.new(1, 0, 0) })
			table.insert(spots, { Pos = center + Vector3.new(d, 0, t), Facing = Vector3.new(-1, 0, 0) })
		end
	end
	return spots
end

local Decorators = {}

Decorators.Spawn = function(folder, center, half, theme)
	for _, spot in ipairs(perimeterSpots(center, half, 10, 36)) do
		Decor.StreetLight(folder, spot.Pos, theme.Accent)
	end
	-- Title board behind the stations
	local board = part({ Name = "TitleBoard", Parent = folder, Size = Vector3.new(60, 18, 2),
		CFrame = CFrame.new(center + Vector3.new(0, 16, -80)), Color = Color3.fromRGB(30, 30, 40) })
	surfaceText(board, Enum.NormalId.Front, "🗑️ DUMPSTER FUSION SIMULATOR ⚗️", Color3.fromRGB(120, 255, 150))
	surfaceText(board, Enum.NormalId.Back, "🗑️ DUMPSTER FUSION SIMULATOR ⚗️", Color3.fromRGB(120, 255, 150))
	for _, x in ipairs({ -26, 26 }) do
		part({ Name = "BoardLeg", Parent = folder, Size = Vector3.new(2, 8, 2), CFrame = CFrame.new(center + Vector3.new(x, 4, -80)), Color = Color3.fromRGB(60, 60, 70) })
	end
	-- Tutorial sign
	local sign = part({ Name = "TutorialSign", Parent = folder, Size = Vector3.new(14, 9, 0.6),
		CFrame = CFrame.lookAt(center + Vector3.new(-30, 6, 18), center + Vector3.new(-60, 6, 0)), Color = Color3.fromRGB(255, 255, 255) })
	surfaceText(sign, Enum.NormalId.Front,
		"HOW TO PLAY\n1. Hold E on dumpsters\n2. Fuse items at the machine\n3. Sell junk for cash\n4. Upgrade & unlock zones!",
		Color3.fromRGB(30, 30, 30), Color3.fromRGB(255, 245, 200))
	for i = 1, 6 do
		Decor.TrashPile(folder, center + Vector3.new(rng:NextNumber(-85, -40), 0, rng:NextNumber(-85, 85)))
	end
end

Decorators.PoorNeighborhood = function(folder, center, half, theme)
	for _, spot in ipairs(perimeterSpots(center, half, 14, 30)) do
		if rng:NextNumber() < 0.75 then
			Decor.Shack(folder, spot.Pos, spot.Facing)
		else
			Decor.TrashPile(folder, spot.Pos)
		end
	end
	for _ = 1, 10 do
		Decor.TrashPile(folder, center + Vector3.new(rng:NextNumber(-80, 80), 0, rng:NextNumber(-80, 80)))
	end
	for _ = 1, 4 do
		Decor.Tree(folder, center + Vector3.new(rng:NextNumber(-90, 90), 0, rng:NextNumber(40, 90) * (rng:NextNumber() < 0.5 and -1 or 1)), Color3.fromRGB(110, 120, 60))
	end
end

Decorators.Suburbs = function(folder, center, half, theme)
	local palette = { Color3.fromRGB(255, 230, 200), Color3.fromRGB(200, 230, 255), Color3.fromRGB(255, 210, 220), Color3.fromRGB(220, 255, 210) }
	for i, spot in ipairs(perimeterSpots(center, half, 16, 36)) do
		Decor.House(folder, spot.Pos, spot.Facing, palette[i % #palette + 1], Color3.fromRGB(150, 60, 50))
		local fenceStart = spot.Pos + spot.Facing * 10
		local side = Vector3.new(spot.Facing.Z, 0, -spot.Facing.X)
		Decor.Fence(folder, fenceStart - side * 10, fenceStart + side * 10, Color3.fromRGB(250, 250, 250))
	end
	for _ = 1, 14 do
		Decor.Tree(folder, center + Vector3.new(rng:NextNumber(-85, 85), 0, rng:NextNumber(-85, 85)))
	end
end

Decorators.Downtown = function(folder, center, half, theme)
	for _, spot in ipairs(perimeterSpots(center, half, 14, 28)) do
		Decor.Tower(folder, spot.Pos, rng:NextNumber(50, 120), Color3.fromRGB(40, 60, 90), theme.Accent)
	end
	for x = -80, 80, 32 do
		Decor.StreetLight(folder, center + Vector3.new(x, 0, 20), Color3.fromRGB(120, 220, 255))
		Decor.StreetLight(folder, center + Vector3.new(x, 0, -20), Color3.fromRGB(255, 120, 220))
	end
	local billboardPart = part({ Name = "Billboard", Parent = folder, Size = Vector3.new(40, 14, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 30, 92)), Color = Color3.new(0, 0, 0) })
	surfaceText(billboardPart, Enum.NormalId.Front, "DOWNTOWN 🌃 TRASH NEVER SLEEPS", Color3.fromRGB(0, 220, 255))
end

Decorators.LuxuryDistrict = function(folder, center, half, theme)
	for _, spot in ipairs(perimeterSpots(center, half, 18, 44)) do
		Decor.Mansion(folder, spot.Pos, spot.Facing, theme.Accent)
	end
	-- Fountain
	part({ Name = "FountainBase", Parent = folder, Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 20, 20),
		CFrame = CFrame.new(center + Vector3.new(0, 1, 40)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(240, 240, 240), Material = Enum.Material.Marble })
	part({ Name = "FountainWater", Parent = folder, Shape = Enum.PartType.Cylinder, CanCollide = false, Size = Vector3.new(0.4, 18, 18),
		CFrame = CFrame.new(center + Vector3.new(0, 2.1, 40)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 190, 255), Material = Enum.Material.Glass, Transparency = 0.3 })
	Decor.Statue(folder, center + Vector3.new(0, 1, 40), theme.Accent)
	for _ = 1, 10 do
		part({ Name = "Hedge", Parent = folder, Size = Vector3.new(10, 3, 3),
			CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-80, 80), 1.5, rng:NextNumber(-80, 80))) * CFrame.Angles(0, rng:NextInteger(0, 1) * math.pi / 2, 0),
			Color = Color3.fromRGB(50, 120, 60), Material = Enum.Material.Grass })
	end
end

Decorators.CelebrityHills = function(folder, center, half, theme)
	for _, spot in ipairs(perimeterSpots(center, half, 10, 40)) do
		Decor.Hill(folder, spot.Pos, rng:NextNumber(12, 20), Color3.fromRGB(120, 190, 90))
	end
	local sign = part({ Name = "HillSign", Parent = folder, Size = Vector3.new(70, 12, 1),
		CFrame = CFrame.new(center + Vector3.new(0, 28, 100)) * CFrame.Angles(0, math.pi, 0), Color = Color3.new(1, 1, 1), Transparency = 1 })
	surfaceText(sign, Enum.NormalId.Front, "CELEBRITY HILLS", Color3.fromRGB(255, 255, 255))
	surfaceText(sign, Enum.NormalId.Back, "CELEBRITY HILLS", Color3.fromRGB(255, 255, 255))
	for x = -90, 90, 15 do
		part({ Name = "StarTile", Parent = folder, CanCollide = false, Size = Vector3.new(4, 0.1, 4),
			CFrame = CFrame.new(center + Vector3.new(x, 0.05, 12)) * CFrame.Angles(0, math.rad(45), 0), Color = theme.Accent, Material = Enum.Material.Neon })
	end
	for _, x in ipairs({ -60, -20, 20, 60 }) do
		part({ Name = "Spotlight", Parent = folder, Shape = Enum.PartType.Cylinder, CanCollide = false, Size = Vector3.new(80, 3, 3),
			CFrame = CFrame.new(center + Vector3.new(x, 40, 70)) * CFrame.Angles(0, 0, math.rad(90 + x / 4)), Color = Color3.fromRGB(255, 255, 220),
			Material = Enum.Material.Neon, Transparency = 0.75 })
	end
end

Decorators.BillionaireIsland = function(folder, center, half, theme)
	part({ Name = "Ocean", Parent = folder, Size = Vector3.new(half * 2 + 160, 1, half * 2 + 160),
		CFrame = CFrame.new(center + Vector3.new(0, -3, 0)), Color = Color3.fromRGB(40, 150, 220), Material = Enum.Material.Glass, Transparency = 0.15, CanCollide = false })
	for _, spot in ipairs(perimeterSpots(center, half, 8, 24)) do
		Decor.Palm(folder, spot.Pos)
	end
	for _, pos in ipairs({ Vector3.new(-50, 0, 60), Vector3.new(50, 0, 60), Vector3.new(0, 0, -70) }) do
		Decor.Statue(folder, center + pos, theme.Accent)
	end
	-- Yacht
	local yachtPos = center + Vector3.new(0, 0, half + 40)
	part({ Name = "YachtHull", Parent = folder, Size = Vector3.new(50, 6, 14), CFrame = CFrame.new(yachtPos + Vector3.new(0, 0, 0)), Color = Color3.new(1, 1, 1) })
	part({ Name = "YachtCabin", Parent = folder, Size = Vector3.new(24, 6, 10), CFrame = CFrame.new(yachtPos + Vector3.new(-4, 6, 0)), Color = Color3.fromRGB(30, 40, 60), Material = Enum.Material.Glass })
	-- Helipad
	local pad = part({ Name = "Helipad", Parent = folder, Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 24, 24),
		CFrame = CFrame.new(center + Vector3.new(60, 0.2, -60)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(50, 50, 55) })
	surfaceText(pad, Enum.NormalId.Right, "H", Color3.new(1, 1, 1))
end

-- ============================================================================
-- ZONE BUILD
-- ============================================================================
local function buildZone(zone)
	local folder = Instance.new("Folder")
	folder.Name = zone.Key
	folder.Parent = mapFolder

	local center = WorldService.GetZoneCenter(zone.Id)
	local half = WorldService.GetZoneHalfSize(zone.Id)
	local theme = zone.Theme

	-- Ground
	part({ Name = "Ground", Parent = folder, Size = Vector3.new(half * 2, 2, half * 2),
		CFrame = CFrame.new(center + Vector3.new(0, -1, 0)), Color = theme.Ground, Material = theme.Material })

	-- Invisible boundary walls with road openings on the ±X sides.
	local wallHeight = 60
	for _, zSign in ipairs({ -1, 1 }) do
		part({ Name = "Boundary", Parent = folder, Transparency = 1, Size = Vector3.new(half * 2, wallHeight, 2),
			CFrame = CFrame.new(center + Vector3.new(0, wallHeight / 2, zSign * (half + 1))) })
	end
	for _, xSign in ipairs({ -1, 1 }) do
		local isOuterEnd = (xSign == -1 and zone.Id == 0) or (xSign == 1 and zone.Id == Config.MaxZoneId)
		if isOuterEnd then
			part({ Name = "Boundary", Parent = folder, Transparency = 1, Size = Vector3.new(2, wallHeight, half * 2),
				CFrame = CFrame.new(center + Vector3.new(xSign * (half + 1), wallHeight / 2, 0)) })
		else
			local segment = half - 15
			for _, zSign in ipairs({ -1, 1 }) do
				part({ Name = "Boundary", Parent = folder, Transparency = 1, Size = Vector3.new(2, wallHeight, segment),
					CFrame = CFrame.new(center + Vector3.new(xSign * (half + 1), wallHeight / 2, zSign * (15 + segment / 2))) })
			end
		end
	end

	-- Road to the next zone
	if zone.Id < Config.MaxZoneId then
		local startX = center.X + half
		local nextCenter = WorldService.GetZoneCenter(zone.Id + 1)
		local endX = nextCenter.X - WorldService.GetZoneHalfSize(zone.Id + 1)
		local length = endX - startX
		local roadCenter = Vector3.new((startX + endX) / 2, -1, 0)
		part({ Name = "Road", Parent = folder, Size = Vector3.new(length, 2, 30), CFrame = CFrame.new(roadCenter),
			Color = Color3.fromRGB(70, 70, 75), Material = Enum.Material.Asphalt })
		part({ Name = "RoadLine", Parent = folder, CanCollide = false, Size = Vector3.new(length, 0.1, 1),
			CFrame = CFrame.new(roadCenter + Vector3.new(0, 1.05, 0)), Color = Color3.fromRGB(255, 220, 60), Material = Enum.Material.Neon })
		for _, zSign in ipairs({ -1, 1 }) do
			part({ Name = "RoadRail", Parent = folder, Size = Vector3.new(length, 3, 1),
				CFrame = CFrame.new(roadCenter + Vector3.new(0, 2.5, zSign * 15)), Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal })
			part({ Name = "RoadWall", Parent = folder, Transparency = 1, Size = Vector3.new(length, wallHeight, 1),
				CFrame = CFrame.new(roadCenter + Vector3.new(0, wallHeight / 2, zSign * 15.5)) })
		end
	end

	-- Gate (locks zones 1+). Collision is removed locally on the client once
	-- the zone is unlocked; the server also guards the region itself.
	if zone.Id > 0 then
		local gate = part({ Name = "Gate", Parent = folder, Size = Vector3.new(2, 22, 30),
			CFrame = CFrame.new(center + Vector3.new(-half - 1, 11, 0)), Color = theme.Accent,
			Material = Enum.Material.ForceField, Transparency = 0.2 })
		gate:SetAttribute("ZoneId", zone.Id)
		CollectionService:AddTag(gate, "ZoneGate")
		local text = ("🔒 %s\n%s"):format(zone.Name, Util.FormatCash(zone.Cost))
		surfaceText(gate, Enum.NormalId.Left, text, Color3.new(1, 1, 1))
		surfaceText(gate, Enum.NormalId.Right, text, Color3.new(1, 1, 1))
		local unlockPrompt = prompt(gate, "Unlock Zone", zone.Name .. " — " .. Util.FormatCash(zone.Cost), 0.4, 14)
		unlockPrompt.Name = "UnlockPrompt"
		unlockPrompt:SetAttribute("ZoneId", zone.Id)

		-- Entrance arch
		for _, zSign in ipairs({ -1, 1 }) do
			part({ Name = "ArchPillar", Parent = folder, Size = Vector3.new(4, 26, 4),
				CFrame = CFrame.new(center + Vector3.new(-half + 2, 13, zSign * 17)), Color = darken(theme.Accent, 0.2), Material = Enum.Material.SmoothPlastic })
		end
		local arch = part({ Name = "ArchTop", Parent = folder, Size = Vector3.new(4, 5, 38),
			CFrame = CFrame.new(center + Vector3.new(-half + 2, 28, 0)), Color = theme.Accent, Material = Enum.Material.Neon })
		surfaceText(arch, Enum.NormalId.Left, zone.Name, Color3.new(1, 1, 1))
		surfaceText(arch, Enum.NormalId.Right, zone.Name, Color3.new(1, 1, 1))
	end

	-- Dumpsters in a ring facing the center
	local dumpsterFolder = Instance.new("Folder")
	dumpsterFolder.Name = "Dumpsters"
	dumpsterFolder.Parent = folder
	local radius = zone.Id == 0 and 58 or 68
	for k = 1, zone.DumpsterCount do
		local angle = (k - 0.5) / zone.DumpsterCount * math.pi * 2
		local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		buildDumpster(dumpsterFolder, position, center, zone.Id, theme, false)
	end

	-- Stations
	buildSellStation(folder, center + Vector3.new(-20, 0, -30))
	buildFusionMachine(folder, center + Vector3.new(20, 0, -30))

	-- Decorations
	local decorator = Decorators[zone.Key]
	if decorator then
		decorator(folder, center, half, theme)
	end

	return folder
end

local function buildSpawnExtras()
	local folder = mapFolder:FindFirstChild("Spawn")

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(-40, 0.5, 0)
	spawn.Color = Color3.fromRGB(80, 200, 120)
	spawn.Material = Enum.Material.Neon
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = folder

	buildKiosk(folder, Vector3.new(0, 0, 32), "Shop", "🛒 SHOP", Color3.fromRGB(60, 140, 255), "Shop", "Open Shop")
	buildKiosk(folder, Vector3.new(-28, 0, 38), "QuestBoard", "📜 QUESTS", Color3.fromRGB(255, 170, 40), "Quests", "View Quests")
	buildKiosk(folder, Vector3.new(28, 0, 38), "CollectionBook", "📖 COLLECTION", Color3.fromRGB(230, 80, 160), "Collection", "Open Collection")

	-- VIP room
	local vipFolder = Instance.new("Folder")
	vipFolder.Name = "VIPRoom"
	vipFolder.Parent = folder
	local vipCenter = (VIP_REGION.Min + VIP_REGION.Max) / 2
	local vipSize = VIP_REGION.Max - VIP_REGION.Min
	part({ Name = "VIPFloor", Parent = vipFolder, Size = Vector3.new(vipSize.X, 0.4, vipSize.Z),
		CFrame = CFrame.new(vipCenter.X, 0.2, vipCenter.Z), Color = Color3.fromRGB(255, 205, 60), Material = Enum.Material.Neon })
	local wallH = 14
	part({ Name = "VIPWall", Parent = vipFolder, Size = Vector3.new(vipSize.X, wallH, 1),
		CFrame = CFrame.new(vipCenter.X, wallH / 2, VIP_REGION.Max.Z), Color = Color3.fromRGB(40, 30, 10), Material = Enum.Material.SmoothPlastic })
	part({ Name = "VIPWall", Parent = vipFolder, Size = Vector3.new(1, wallH, vipSize.Z),
		CFrame = CFrame.new(VIP_REGION.Max.X, wallH / 2, vipCenter.Z), Color = Color3.fromRGB(40, 30, 10), Material = Enum.Material.SmoothPlastic })
	part({ Name = "VIPWall", Parent = vipFolder, Size = Vector3.new(vipSize.X, wallH, 1),
		CFrame = CFrame.new(vipCenter.X, wallH / 2, VIP_REGION.Min.Z), Color = Color3.fromRGB(40, 30, 10), Material = Enum.Material.SmoothPlastic })
	-- West wall with a gated doorway
	local doorWidth = 10
	local segment = (vipSize.Z - doorWidth) / 2
	for _, zSign in ipairs({ -1, 1 }) do
		part({ Name = "VIPWall", Parent = vipFolder, Size = Vector3.new(1, wallH, segment),
			CFrame = CFrame.new(VIP_REGION.Min.X, wallH / 2, vipCenter.Z + zSign * (doorWidth / 2 + segment / 2)), Color = Color3.fromRGB(40, 30, 10) })
	end
	local vipGate = part({ Name = "VIPGate", Parent = vipFolder, Size = Vector3.new(1, wallH, doorWidth),
		CFrame = CFrame.new(VIP_REGION.Min.X, wallH / 2, vipCenter.Z), Color = Color3.fromRGB(255, 205, 40),
		Material = Enum.Material.ForceField, Transparency = 0.2 })
	CollectionService:AddTag(vipGate, "VIPGate")
	surfaceText(vipGate, Enum.NormalId.Left, "👑 VIP ONLY", Color3.fromRGB(255, 220, 90))
	local vipPrompt = prompt(vipGate, "Get VIP", "VIP Room", 0, 12)
	vipPrompt.Name = "VIPPrompt"
	local roof = part({ Name = "VIPSign", Parent = vipFolder, Size = Vector3.new(vipSize.X, 4, vipSize.Z),
		CFrame = CFrame.new(vipCenter.X, wallH + 2, vipCenter.Z), Color = Color3.fromRGB(40, 30, 10) })
	billboard(roof, "👑 VIP LOUNGE", Color3.fromRGB(255, 220, 90), UDim2.fromOffset(260, 70), Vector3.new(0, 5, 0))

	local vipTheme = Config.ZoneById[0].Theme
	for i, offset in ipairs({ Vector3.new(10, 0, -8), Vector3.new(10, 0, 8), Vector3.new(-4, 0, 12) }) do
		local model = buildDumpster(vipFolder, vipCenter * Vector3.new(1, 0, 1) + offset, vipCenter * Vector3.new(1, 0, 1) - Vector3.new(10, 0, 0), 0, vipTheme, true)
		model.Name = "VIPDumpster" .. i
	end
end

local function setupLighting()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.5

	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.28
		atmosphere.Haze = 1
		atmosphere.Color = Color3.fromRGB(200, 220, 255)
		atmosphere.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("BloomEffect") then
		local bloom = Instance.new("BloomEffect")
		bloom.Intensity = 0.6
		bloom.Size = 30
		bloom.Threshold = 1.4
		bloom.Parent = Lighting
	end
	if not Lighting:FindFirstChildOfClass("ColorCorrectionEffect") then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Saturation = 0.15
		cc.Contrast = 0.05
		cc.Parent = Lighting
	end
end

function WorldService.Init()
	mapFolder = Workspace:FindFirstChild("Map")
	if mapFolder then
		-- A hand-built map exists; keep it and skip generation.
		return
	end

	-- Remove the default Studio baseplate/spawn so our map is the only ground.
	for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
		local existing = Workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "Map"
	mapFolder.Parent = Workspace

	for _, zone in ipairs(Config.Zones) do
		buildZone(zone)
	end
	buildSpawnExtras()
	setupLighting()
end

function WorldService.Start() end

return WorldService
