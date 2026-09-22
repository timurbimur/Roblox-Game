-- Produces the 3D model for a brainrot. If a real model has been placed in
-- ServerStorage.Assets.Models (named exactly like the brainrot's Id) it is cloned.
-- Otherwise a simple placeholder is generated at runtime so the game is playable
-- before any art exists -- swap in real meshes any time without touching code.

local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RarityConfig = require(ReplicatedStorage.Modules.RarityConfig)

local ModelFactory = {}

local PLACEHOLDER_SIZE = Vector3.new(1.6, 1.6, 1.6)

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

	local nameTag = Instance.new("BillboardGui")
	nameTag.Name = "NameTag"
	nameTag.Size = UDim2.fromOffset(160, 36)
	nameTag.StudsOffset = Vector3.new(0, 1.3, 0)
	nameTag.AlwaysOnTop = true
	nameTag.Parent = body

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = brainrotData.Name
	label.TextColor3 = rarity.Color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = nameTag

	model.PrimaryPart = body
	model:AddTag("Brainrot")
	model:SetAttribute("BrainrotId", brainrotData.Id)

	return model
end

function ModelFactory.Create(brainrotData)
	local assets = ServerStorage:FindFirstChild("Assets")
	local library = assets and assets:FindFirstChild("Models")
	-- ModelName lets the ServerStorage lookup use a different name than the
	-- (permanent, save-data-critical) Id -- e.g. a messy Toolbox model name
	-- that shouldn't ever be used as a DataStore key.
	local lookupName = brainrotData.ModelName or brainrotData.Id
	local template = library and library:FindFirstChild(lookupName)

	if template then
		local clone = template:Clone()
		if clone:IsA("Model") and not clone.PrimaryPart then
			clone.PrimaryPart = clone:FindFirstChildWhichIsA("BasePart", true)
		end
		clone:AddTag("Brainrot")
		clone:SetAttribute("BrainrotId", brainrotData.Id)
		return clone
	end

	return buildPlaceholder(brainrotData)
end

return ModelFactory
