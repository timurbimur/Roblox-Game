local UIController = require(script.Parent.UIController)
local SpinController = require(script.Parent.SpinController)
local InventoryController = require(script.Parent.InventoryController)

local ui = UIController.Init()

SpinController.Init(ui)
InventoryController.Init(ui)
