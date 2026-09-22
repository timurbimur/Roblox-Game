-- Spawns/despawns the 3D models for a player's currently-equipped brainrots and
-- keeps them orbiting the player's character.

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotConfig = require(ReplicatedStorage.Modules.BrainrotConfig)
local ModelFactory = require(script.Parent.ModelFactory)

local EquipService = {}

EquipService.MaxSlots = 3

local ORBIT_RADIUS = 4
local ORBIT_HEIGHT = 3
local ORBIT_SPEED = 1.2

local activeCompanions = {} -- [player] = { {model = Model, connection = RBXScriptConnection}, ... }

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
	local slotCount = math.max(#equippedIds, 1)

	for index, brainrotId in ipairs(equippedIds) do
		local data = BrainrotConfig.ById[brainrotId]
		if data then
			local model = ModelFactory.Create(data)
			model.Parent = workspace

			local primary = model.PrimaryPart
			if primary then
				local angleOffset = (index - 1) * (math.pi * 2 / slotCount)
				local connection = RunService.Heartbeat:Connect(function()
					if not hrp.Parent then
						return
					end
					local t = os.clock() * ORBIT_SPEED + angleOffset
					local offset = Vector3.new(
						math.cos(t) * ORBIT_RADIUS,
						ORBIT_HEIGHT + math.sin(t * 2) * 0.3,
						math.sin(t) * ORBIT_RADIUS
					)
					local position = hrp.Position + offset
					model:PivotTo(CFrame.new(position, hrp.Position))
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
