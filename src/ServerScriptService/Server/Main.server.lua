local DataService = require(script.Parent.DataService)
local SpinService = require(script.Parent.SpinService)

-- Order matters: player save data must be loadable before spin/equip requests
-- are handled.
DataService.Init()
SpinService.Init()
