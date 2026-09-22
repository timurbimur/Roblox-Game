-- Spawns/despawns the 3D models for a player's currently-equipped brainrots
-- and keeps them hopping along behind the player's character, spread out
-- side by side.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Modules.BrainrotConfig)
local BrainrotVisuals = require(ReplicatedStorage.Modules.BrainrotVisuals)

local EquipService = {}

EquipService.MaxSlots = 3

local FOLLOW_DISTANCE = 5 -- studs behind the character
local SIDE_SPACING = 3 -- studs between equipped brainrots
local HOP_HEIGHT = 1.4
local HOP_SPEED = 5
local FOLLOW_LERP_ALPHA = 0.12 -- lower = laggier/bouncier trailing

local activeCompanions = {} -- [player] = { {model, connection}, ... }

local function clearCompanions(player)
	local companions = activeCompanions[player]
	if not companions then
		return
	end
	for _, companion in ipairs(companions) do
		if companion.connection then
			companion.connection:Disconnect()
		end
		if companion.model then
			companion.model:Destroy()
		end
	end
	activeCompanions[player] = nil
end

local function spawnCompanions(player, equippedIds)
	clearCompanions(player)

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end

	local companions = {}
	local slotCount = #equippedIds

	for index, brainrotId in ipairs(equippedIds) do
		local data = BrainrotConfig.ById[brainrotId]
		if data then
			local model = BrainrotVisuals.CreateModel(data)
			model.Parent = workspace

			local primary = model.PrimaryPart
			if primary then
				BrainrotVisuals.AttachInfoTag(model, data)
				-- Spreads slots symmetrically around directly-behind (e.g. 3
				-- slots -> -1, 0, 1 spacing units either side of center).
				local centerOffset = index - (slotCount + 1) / 2
				local phase = index * 1.7 -- desyncs each brainrot's hop

				local currentPosition = hrp.Position - hrp.CFrame.LookVector * FOLLOW_DISTANCE
				model:PivotTo(CFrame.new(currentPosition, hrp.Position))

				local connection = RunService.Heartbeat:Connect(function()
					if not hrp.Parent then
						return
					end

					local behind = -hrp.CFrame.LookVector
					local right = hrp.CFrame.RightVector
					local basePosition = hrp.Position + behind * FOLLOW_DISTANCE + right * (centerOffset * SIDE_SPACING)

					local hop = math.abs(math.sin(os.clock() * HOP_SPEED + phase)) * HOP_HEIGHT
					local targetPosition = Vector3.new(basePosition.X, basePosition.Y + hop, basePosition.Z)

					currentPosition = currentPosition:Lerp(targetPosition, FOLLOW_LERP_ALPHA)

					local lookTarget = Vector3.new(hrp.Position.X, currentPosition.Y, hrp.Position.Z)
					model:PivotTo(CFrame.new(currentPosition, lookTarget))
				end)

				table.insert(companions, { model = model, connection = connection })
			else
				model:Destroy()
			end
		end
	end

	activeCompanions[player] = companions
end

function EquipService.Refresh(player, equippedIds)
	spawnCompanions(player, equippedIds)
end

function EquipService.ClearForPlayer(player)
	clearCompanions(player)
end

Players.PlayerRemoving:Connect(clearCompanions)

return EquipService
