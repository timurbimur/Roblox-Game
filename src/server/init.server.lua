--[[
	Dumpster Fusion Simulator — Server Bootstrap
	============================================
	Loads every service, calls Init() on all of them (wiring, no yielding
	work), then Start() on all of them (connections, loops, player handling).

	Services talk to each other through the shared `Services` table instead of
	requiring each other directly, which avoids circular-require problems and
	keeps each module independently testable.
]]

local ServicesFolder = script:WaitForChild("Services")

-- Order matters for Init: WorldService builds the map before DumpsterService
-- scans for dumpsters, and DataService must start listening to players last.
local LOAD_ORDER = {
	"Router",
	"WorldService",
	"AnnouncementService",
	"LootService",
	"BoostService",
	"InventoryService",
	"EconomyService",
	"QuestService",
	"AchievementService",
	"RewardService",
	"ZoneService",
	"DumpsterService",
	"FusionService",
	"MonetizationService",
	"DataService",
}

local Services = {}

for _, name in ipairs(LOAD_ORDER) do
	Services[name] = require(ServicesFolder:WaitForChild(name))
end

for _, name in ipairs(LOAD_ORDER) do
	local service = Services[name]
	if service.Init then
		service.Init(Services)
	end
end

for _, name in ipairs(LOAD_ORDER) do
	local service = Services[name]
	if service.Start then
		task.spawn(service.Start)
	end
end

print("[DumpsterFusion] Server started with " .. #LOAD_ORDER .. " services.")
