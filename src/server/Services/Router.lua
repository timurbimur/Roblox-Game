--[[
	Router
	------
	Dispatches the single "Request" RemoteFunction to handlers registered by
	services: Router.Register("Sell", function(profile, payload) ... end)

	Security
	  * action must be a registered string
	  * the player's profile must be loaded
	  * token-bucket rate limit per player (Config.RequestRateLimit / second)
	  * handlers run in pcall; errors never leak to the client
	  * handlers receive the SERVER profile, never client-supplied state
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Router = {}

local Services
local handlers = {}

function Router.Register(action, handler)
	assert(type(action) == "string" and type(handler) == "function", "Router.Register(action, handler)")
	assert(not handlers[action], "Duplicate handler for " .. action)
	handlers[action] = handler
end

local function consumeToken(session)
	local now = os.clock()
	local rate = Config.RequestRateLimit
	session.RequestTokens = math.min(rate, session.RequestTokens + (now - session.RequestRefill) * rate)
	session.RequestRefill = now
	if session.RequestTokens < 1 then
		return false
	end
	session.RequestTokens -= 1
	return true
end

local function onInvoke(player, action, payload)
	if type(action) ~= "string" then
		return false, "Bad request."
	end
	local handler = handlers[action]
	if not handler then
		return false, "Unknown action."
	end
	local profile = Services.DataService.GetProfile(player)
	if not profile then
		return false, "Still loading your data..."
	end
	if not consumeToken(profile.Session) then
		return false, "Slow down!"
	end
	local ok, success, result = pcall(handler, profile, payload)
	if not ok then
		warn(("[Router] %s failed for %s: %s"):format(action, player.Name, tostring(success)))
		return false, "Something went wrong."
	end
	return success == true, result
end

function Router.Init(services)
	Services = services
end

function Router.Start()
	Remotes.Request.OnServerInvoke = onInvoke
end

return Router
