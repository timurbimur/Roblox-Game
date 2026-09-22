-- Shared model/visual logic usable from BOTH server and client, since it
-- lives in ReplicatedStorage.Assets.Models -- needed so the client can build
-- real inventory thumbnails (ServerStorage never replicates to clients, so
-- that folder can't be read there).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RarityConfig = require(ReplicatedStorage.Modules.RarityConfig)
local BrainrotConfig = require(ReplicatedStorage.Modules.BrainrotConfig)

local BrainrotVisuals = {}

local PLACEHOLDER_SIZE = Vector3.new(1.6, 1.6, 1.6)

-- Overall probability of landing this exact brainrot (its rarity's odds
-- split evenly across every brainrot in that rarity), as "1 in N".
function BrainrotVisuals.GetOddsText(brainrotData)
	local rarity = RarityConfig.Rarities[brainrotData.Rarity]
	local pool = BrainrotConfig.ByRarity[brainrotData.Rarity]
	local poolSize = (pool and #pool > 0) and #pool or 1
	local chance = (rarity.Weight / RarityConfig.TotalWeight) / poolSize
	local oneInN = math.floor(1 / chance + 0.5)
	return "1 in " .. tostring(oneInN)
end

local function buildPlaceholder(brainrotData)
	local rarity = RarityConfig.Rarities[brainrotData.Rarity]

	local model = Instance.new("Model")
	model.Name = brainrotData.Id

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Block
	body.Size = PLACEHOLDER_SIZE
	body.Color = rarity.Color
	body.Material = Enum.Material.Neon
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.CanCollide = false
	body.Anchored = true
	body.Parent = model

	local face = Instance.new("Part")
	face.Name = "Face"
	face.Shape = Enum.PartType.Ball
	face.Size = Vector3.new(0.7, 0.7, 0.7)
	face.Color = Color3.new(1, 1, 1)
	face.Material = Enum.Material.SmoothPlastic
	face.CanCollide = false
	face.Anchored = false
	face.CFrame = body.CFrame * CFrame.new(0, 0.35, -0.85)
	face.Parent = model

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = body
	weld.Part1 = face
	weld.Parent = body

	model.PrimaryPart = body
	return model
end

-- Clones the real model from ReplicatedStorage.Assets.Models (matched by
-- ModelName) if one exists, otherwise generates a placeholder.
function BrainrotVisuals.CreateModel(brainrotData)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local library = assets and assets:FindFirstChild("Models")
	local lookupName = brainrotData.ModelName or brainrotData.Id
	local template = library and library:FindFirstChild(lookupName)

	local model
	if template then
		model = template:Clone()
		if model:IsA("Model") and not model.PrimaryPart then
			model.PrimaryPart = model:FindFirstChildWhichIsA("BasePart", true)
		end
	else
		model = buildPlaceholder(brainrotData)
	end

	model:AddTag("Brainrot")
	model:SetAttribute("BrainrotId", brainrotData.Id)
	return model
end

-- Floating name/rarity/odds billboard for world companions (not used on
-- inventory thumbnails).
function BrainrotVisuals.AttachInfoTag(model, brainrotData)
	local primary = model.PrimaryPart
	if not primary then
		return
	end
	local rarity = RarityConfig.Rarities[brainrotData.Rarity]

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "InfoTag"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 1.7, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = primary

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.new(1, 0, 0, 30)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Text = brainrotData.Name
	nameLabel.TextColor3 = rarity.Color
	nameLabel.TextStrokeTransparency = 0
	nameLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextScaled = true
	nameLabel.Parent = billboard

	local oddsLabel = Instance.new("TextLabel")
	oddsLabel.Name = "OddsLabel"
	oddsLabel.Size = UDim2.new(1, 0, 0, 22)
	oddsLabel.Position = UDim2.new(0, 0, 0, 32)
	oddsLabel.BackgroundTransparency = 1
	oddsLabel.Text = BrainrotVisuals.GetOddsText(brainrotData)
	oddsLabel.TextColor3 = Color3.fromRGB(255, 230, 120)
	oddsLabel.TextStrokeTransparency = 0
	oddsLabel.TextStrokeColor3 = Color3.new(0, 0, 0)
	oddsLabel.Font = Enum.Font.GothamBold
	oddsLabel.TextScaled = true
	oddsLabel.Parent = billboard
end

-- Builds a self-contained ViewportFrame showing the real model, framed
-- nicely, parented into `parent`. Client-only (ViewportFrame is a GUI type).
function BrainrotVisuals.BuildThumbnail(brainrotData, parent)
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Thumbnail"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.Parent = parent

	local model = BrainrotVisuals.CreateModel(brainrotData)
	model.Parent = viewport

	local camera = Instance.new("Camera")
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	local cf, size = model:GetBoundingBox()
	local maxExtent = math.max(size.X, size.Y, size.Z, 1)
	local distance = maxExtent * 2.2

	local lookFrom = cf.Position + Vector3.new(distance * 0.7, distance * 0.55, distance * 0.7)
	camera.CFrame = CFrame.new(lookFrom, cf.Position)

	return viewport
end

return BrainrotVisuals
