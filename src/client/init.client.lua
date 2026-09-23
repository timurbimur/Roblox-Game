--[[
	Dumpster Fusion Simulator — Client Bootstrap
	============================================
	Loads every controller, runs Init(controllers) (build UI, no yielding)
	then Start() (connect signals, loops).

	The client is presentation only: it renders server-replicated state and
	sends requests. It never decides loot, prices, balances or progression.
]]

local ControllersFolder = script:WaitForChild("Controllers")

local LOAD_ORDER = {
	"UIController",
	"SoundController",
	"Notifications",
	"HUD",
	"InventoryPanel",
	"SellPanel",
	"FusionPanel",
	"CollectionPanel",
	"ShopPanel",
	"QuestsPanel",
	"SettingsPanel",
	"WorldController",
	"Tutorial",
	"ChatController",
}

local Controllers = {}

for _, name in ipairs(LOAD_ORDER) do
	Controllers[name] = require(ControllersFolder:WaitForChild(name))
end

for _, name in ipairs(LOAD_ORDER) do
	local controller = Controllers[name]
	if controller.Init then
		local ok, err = pcall(controller.Init, Controllers)
		if not ok then
			warn(("[Client] %s.Init failed: %s"):format(name, tostring(err)))
		end
	end
end

for _, name in ipairs(LOAD_ORDER) do
	local controller = Controllers[name]
	if controller.Start then
		task.spawn(controller.Start)
	end
end
