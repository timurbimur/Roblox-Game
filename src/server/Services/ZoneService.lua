--[[
	ZoneService
	-----------
	Zone unlocking, teleporting and region protection.

	  UnlockZone  zones must be unlocked in order; cost comes from Config.
	  Teleport    only to unlocked zones (or the VIP room with the VIP pass).
	  Guard loop  gates are only non-collidable on clients that unlocked them,
	              but exploiters can noclip — so once a second the server checks
	              every character and returns anyone standing in a locked zone
	              (or the VIP room without VIP) to safety.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Formulas = require(Shared.Formulas)
local Util = require(Shared.Util)
local Remotes = require(Shared.Remotes)

local ZoneService = {}

local Services
local TELEPORT_COOLDOWN = 2

local function teleport(player, cframe)
	local character = player.Character
	if character then
		character:PivotTo(cframe)
	end
end

local function handleUnlockZone(profile, payload)
	local zoneId = type(payload) == "table" and payload.ZoneId
	if type(zoneId) ~= "number" then
		return false, "Bad request."
	end
	local zone = Config.ZoneById[zoneId]
	if not zone then
		return false, "Invalid zone."
	end
	local data = profile.Data
	if data.Zones[tostring(zoneId)] then
		return false, "Already unlocked!"
	end
	local highest = Formulas.GetHighestZone(data)
	if zoneId ~= highest + 1 then
		return false, "Unlock " .. Config.ZoneById[highest + 1].Name .. " first!"
	end
	if not Services.EconomyService.SpendCash(profile, zone.Cost) then
		return false, "Need " .. Util.FormatCash(zone.Cost) .. " to unlock " .. zone.Name
	end
	data.Zones[tostring(zoneId)] = true
	Services.DataService.MarkDirty(profile.Player, "Zones")
	Services.QuestService.Increment(profile, "UnlockZone", 1)
	Services.AchievementService.QueueCheck(profile)

	Remotes.Signal:FireClient(profile.Player, "ZoneUnlocked", { ZoneId = zoneId })
	if zoneId >= 4 then
		Services.AnnouncementService.Broadcast(("🔓 %s unlocked %s!"):format(profile.Player.DisplayName, zone.Name), "#FFD700")
	end
	return true
end

local function handleTeleport(profile, payload)
	local target = type(payload) == "table" and payload.ZoneId
	local now = os.clock()
	if now - profile.Session.LastTeleport < TELEPORT_COOLDOWN then
		return false, "Slow down!"
	end
	if target == "VIP" then
		if not profile.Passes.VIP then
			return false, "VIP only!"
		end
	elseif type(target) ~= "number" or not Config.ZoneById[target] then
		return false, "Invalid zone."
	elseif not profile.Data.Zones[tostring(target)] then
		return false, "Zone locked."
	end
	profile.Session.LastTeleport = now
	teleport(profile.Player, Services.WorldService.GetSpawnCFrame(target))
	return true
end

local function guardTick()
	local World = Services.WorldService
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = Services.DataService.GetProfile(player)
		local root = profile and World.GetRoot(player)
		if root then
			local position = root.Position
			local zoneId = World.GetZoneAtPosition(position)
			if zoneId and not profile.Data.Zones[tostring(zoneId)] then
				teleport(player, World.GetSpawnCFrame(Formulas.GetHighestZone(profile.Data)))
				Services.AnnouncementService.Toast(player, "🔒 Unlock " .. Config.ZoneById[zoneId].Name .. " first!", "Error")
			elseif World.IsInVIPRoom(position) and not profile.Passes.VIP then
				teleport(player, World.GetSpawnCFrame(0))
				Services.AnnouncementService.Toast(player, "👑 The VIP Lounge is for VIP pass owners!", "Error")
			end
		end
	end
end

function ZoneService.Init(services)
	Services = services
end

function ZoneService.Start()
	Services.Router.Register("UnlockZone", handleUnlockZone)
	Services.Router.Register("Teleport", handleTeleport)

	-- Spawn players in their best zone when they respawn/join.
	local function onCharacterAdded(player, character)
		local profile = Services.DataService.WaitForProfile(player, 30)
		if not profile or not character.Parent then
			return
		end
		local highest = Formulas.GetHighestZone(profile.Data)
		if highest > 0 then
			character:WaitForChild("HumanoidRootPart", 10)
			task.wait(0.2)
			teleport(player, Services.WorldService.GetSpawnCFrame(highest))
		end
	end
	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		if player.Character then
			task.spawn(onCharacterAdded, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(guardTick)
			if not ok then
				warn("[ZoneService] Guard error: " .. tostring(err))
			end
		end
	end)
end

return ZoneService
