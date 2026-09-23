--[[
	DataService
	-----------
	Owns every player's save data ("profile") for the whole session.

	Features
	  * DataStore load/save with retries + exponential backoff
	  * Session locking (prevents item duplication when hopping servers quickly)
	  * Template reconciliation (new fields auto-added to old saves)
	  * Sanitisation (removes unknown item ids after database edits)
	  * Autosave every Config.AutosaveInterval seconds
	  * Save on leave + BindToClose (server shutdown)
	  * Batched replication: services call MarkDirty(player, key); changed keys
	    are flushed to the owning client at most 10x per second
	  * In-memory fallback in Studio when API access is disabled

	Nothing the client sends is ever written into a profile directly. Other
	services mutate profile.Data and call MarkDirty.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Util = require(Shared.Util)
local Items = require(Shared.Data.Items)
local Remotes = require(Shared.Remotes)

local DataService = {}

local profiles = {} -- [Player] = profile
local loadedCallbacks = {}
local releasingCallbacks = {}

local MAX_RETRIES = 5
local FLUSH_INTERVAL = 0.1

-- Keys that are never sent to the client.
local PRIVATE_KEYS = {
	ProcessedReceipts = true,
	SessionLock = true,
}

-- ============================================================================
-- DATA TEMPLATE — add new fields here; old saves are reconciled automatically.
-- ============================================================================
local Template = {
	Version = Config.DataVersion,
	Cash = Config.StarterCash,
	Inventory = {},      -- [itemId] = count
	Favorites = {},      -- [itemId] = true
	Discovered = {},     -- [itemId] = unix time of first discovery
	Zones = { ["0"] = true }, -- string keys keep DataStore JSON a dictionary
	Upgrades = {
		Backpack = 0, Luck = 0, DumpsterSpeed = 0, FusionSpeed = 0, AutoCollect = 0, AutoSell = 0,
	},
	Boosts = {},         -- [boostId] = remaining seconds (ticks only while online)
	Settings = {
		SFX = true, Music = true, AutoSell = true, AutoCollect = true,
		Announcements = true, LowGraphics = false,
	},
	Stats = {
		Searches = 0, Fusions = 0, ItemsSold = 0, CashEarned = 0,
		LegendaryFinds = 0, MythicFinds = 0, SecretFinds = 0, PlaytimeSeconds = 0,
	},
	Quests = {
		Main = { Index = 1, Progress = 0 },
		Daily = { Period = -1, List = {} },
		Weekly = { Period = -1, List = {} },
	},
	Daily = { Streak = 0, LastClaimDay = -1 },
	PlaytimeSession = { StartedAt = 0, Claimed = {} },
	Achievements = {},   -- [achievementId] = unix time unlocked
	PendingFusion = false, -- { Result, Count, FinishAt } while a fusion runs
	TutorialDone = false,
	ProcessedReceipts = {}, -- recent PurchaseIds (dev product idempotency)
	FirstJoin = 0,
	LastJoin = 0,
}
DataService.Template = Template

-- ============================================================================
-- DATASTORE BACKEND (real or in-memory mock)
-- ============================================================================
local store
local useMock = false
local mockStore = {}

local function setupStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
		-- Probe once: in Studio without API access this errors immediately.
		local probeOk, probeErr = pcall(function()
			store:GetAsync("__probe")
		end)
		if not probeOk and RunService:IsStudio() then
			warn("[DataService] DataStores unavailable in Studio (" .. tostring(probeErr) .. "). Using in-memory saves. Enable 'Studio Access to API Services' to test real saving.")
			useMock = true
		end
	else
		warn("[DataService] Could not open DataStore: " .. tostring(result) .. ". Using in-memory saves.")
		useMock = true
	end
end

local function updateAsync(key, transform)
	if useMock then
		local newValue = transform(Util.DeepCopy(mockStore[key]))
		if newValue ~= nil then
			mockStore[key] = Util.DeepCopy(newValue)
		end
		return true, newValue
	end
	local lastErr
	for attempt = 1, MAX_RETRIES do
		local ok, result = pcall(function()
			return store:UpdateAsync(key, transform)
		end)
		if ok then
			return true, result
		end
		lastErr = result
		warn(("[DataService] UpdateAsync failed for %s (attempt %d): %s"):format(key, attempt, tostring(result)))
		task.wait(2 ^ attempt * 0.5)
	end
	return false, lastErr
end

-- ============================================================================
-- SANITISATION
-- ============================================================================
local function sanitize(data)
	for itemId, count in pairs(data.Inventory) do
		if not Items.ById[itemId] or type(count) ~= "number" or count <= 0 then
			data.Inventory[itemId] = nil
		else
			data.Inventory[itemId] = math.floor(count)
		end
	end
	for itemId in pairs(data.Favorites) do
		if not Items.ById[itemId] then
			data.Favorites[itemId] = nil
		end
	end
	for itemId in pairs(data.Discovered) do
		if not Items.ById[itemId] then
			data.Discovered[itemId] = nil
		end
	end
	for boostId, remaining in pairs(data.Boosts) do
		if not Config.Boosts[boostId] or type(remaining) ~= "number" or remaining <= 0 then
			data.Boosts[boostId] = nil
		end
	end
	for upgradeId, level in pairs(data.Upgrades) do
		local def = Config.UpgradeById[upgradeId]
		if not def then
			data.Upgrades[upgradeId] = nil
		else
			data.Upgrades[upgradeId] = math.clamp(math.floor(tonumber(level) or 0), 0, def.MaxLevel)
		end
	end
	if type(data.Cash) ~= "number" or data.Cash ~= data.Cash or data.Cash < 0 then
		data.Cash = 0
	end
	data.Zones["0"] = true
end

-- ============================================================================
-- LEADERSTATS
-- ============================================================================
local function createLeaderstats(player)
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local cash = Instance.new("StringValue")
	cash.Name = "Cash"
	cash.Parent = folder

	local found = Instance.new("IntValue")
	found.Name = "Found"
	found.Parent = folder

	folder.Parent = player
	return folder
end

function DataService.UpdateLeaderstats(profile)
	local stats = profile.Leaderstats
	if not stats then
		return
	end
	stats.Cash.Value = Util.FormatCash(profile.Data.Cash)
	stats.Found.Value = Util.CountKeys(profile.Data.Discovered)
end

-- ============================================================================
-- LOAD / SAVE
-- ============================================================================
local function keyFor(userId)
	return "Player_" .. userId
end

local function loadProfile(player)
	local key = keyFor(player.UserId)
	local loadedData
	local blockedByLock = false

	-- Try a few times to acquire the session lock (another server may still be saving).
	for attempt = 1, 4 do
		blockedByLock = false
		local ok = updateAsync(key, function(stored)
			stored = stored or {}
			local lock = stored.SessionLock
			if lock and lock.JobId ~= game.JobId and (os.time() - (lock.Time or 0)) < Config.SessionLockTimeout and attempt < 4 then
				blockedByLock = true
				return nil -- abort write, try again shortly
			end
			stored.SessionLock = { JobId = game.JobId, Time = os.time() }
			loadedData = stored
			return stored
		end)
		if not ok then
			return nil
		end
		if not blockedByLock then
			break
		end
		task.wait(3)
	end

	if not loadedData then
		return nil
	end

	local data = Util.Reconcile(loadedData, Template)
	sanitize(data)
	return data
end

-- Saves a profile. `release` clears the session lock (player leaving).
function DataService.SaveProfile(profile, release)
	if profile.Saving then
		-- Wait for an in-flight save so the final save always wins.
		local start = os.clock()
		while profile.Saving and os.clock() - start < 15 do
			task.wait(0.1)
		end
	end
	profile.Saving = true

	local data = profile.Data
	data.Stats.PlaytimeSeconds += math.floor(os.clock() - profile.PlaytimeMark)
	profile.PlaytimeMark = os.clock()

	local ok, err = updateAsync(keyFor(profile.UserId), function(stored)
		stored = stored or {}
		local lock = stored.SessionLock
		if lock and lock.JobId ~= game.JobId then
			-- Another server took over (we were stale); never overwrite its data.
			return nil
		end
		local toSave = Util.DeepCopy(data)
		toSave.SessionLock = (not release) and { JobId = game.JobId, Time = os.time() } or nil
		return toSave
	end)

	profile.Saving = false
	if not ok then
		warn("[DataService] Save failed for " .. tostring(profile.UserId) .. ": " .. tostring(err))
	end
	return ok
end

-- ============================================================================
-- REPLICATION
-- ============================================================================
local function getReplicatedValue(profile, key)
	if key == "Passes" then
		return profile.Passes
	end
	return profile.Data[key]
end

local function buildSnapshot(profile)
	local snapshot = {}
	for key, value in pairs(profile.Data) do
		if not PRIVATE_KEYS[key] then
			snapshot[key] = value
		end
	end
	snapshot.Passes = profile.Passes
	return snapshot
end

function DataService.MarkDirty(player, key)
	local profile = profiles[player]
	if profile and not PRIVATE_KEYS[key] then
		profile.Dirty[key] = true
	end
end

local function flushDirty()
	for player, profile in pairs(profiles) do
		if profile.Loaded and next(profile.Dirty) then
			local patch = {}
			for key in pairs(profile.Dirty) do
				patch[key] = getReplicatedValue(profile, key)
			end
			table.clear(profile.Dirty)
			Remotes.Sync:FireClient(player, "Patch", patch)
			if patch.Cash or patch.Discovered then
				DataService.UpdateLeaderstats(profile)
			end
		end
	end
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================
function DataService.GetProfile(player)
	local profile = profiles[player]
	if profile and profile.Loaded then
		return profile
	end
	return nil
end

function DataService.GetAllProfiles()
	return profiles
end

-- Waits (up to timeout) for a player's profile to load.
function DataService.WaitForProfile(player, timeout)
	local start = os.clock()
	while player.Parent and os.clock() - start < (timeout or 30) do
		local profile = DataService.GetProfile(player)
		if profile then
			return profile
		end
		task.wait(0.1)
	end
	return nil
end

-- Services register callbacks that run once a profile is ready / before release.
function DataService.OnProfileLoaded(callback)
	table.insert(loadedCallbacks, callback)
end

function DataService.OnProfileReleasing(callback)
	table.insert(releasingCallbacks, callback)
end

-- ============================================================================
-- PLAYER LIFECYCLE
-- ============================================================================
local function onPlayerAdded(player)
	local data = loadProfile(player)
	if not player.Parent then
		-- Player left while we were loading: release the lock we took.
		if data then
			local tempProfile = { UserId = player.UserId, Data = data, PlaytimeMark = os.clock() }
			DataService.SaveProfile(tempProfile, true)
		end
		return
	end
	if not data then
		player:Kick("Your data failed to load. Please rejoin in a moment — your progress is safe.")
		return
	end

	local now = os.time()
	if data.FirstJoin == 0 then
		data.FirstJoin = now
	end
	data.LastJoin = now
	data.PlaytimeSession = { StartedAt = now, Claimed = {} }

	local profile = {
		Player = player,
		UserId = player.UserId,
		Data = data,
		Passes = {},
		Dirty = {},
		Session = {
			Cooldowns = {},    -- [dumpsterId] = os.clock() when usable again
			HoldStarts = {},   -- [dumpsterId] = os.clock() hold began
			LastSearch = 0,
			NextAutoCollect = 0,
			RequestTokens = Config.RequestRateLimit,
			RequestRefill = os.clock(),
			LastTeleport = 0,
		},
		PlaytimeMark = os.clock(),
		Loaded = false,
	}
	profiles[player] = profile
	profile.Leaderstats = createLeaderstats(player)

	for _, callback in ipairs(loadedCallbacks) do
		local ok, err = pcall(callback, profile)
		if not ok then
			warn("[DataService] OnProfileLoaded callback error: " .. tostring(err))
		end
	end

	profile.Loaded = true
	DataService.UpdateLeaderstats(profile)
	Remotes.Sync:FireClient(player, "Full", buildSnapshot(profile))
end

local function onPlayerRemoving(player)
	local profile = profiles[player]
	if not profile then
		return
	end
	for _, callback in ipairs(releasingCallbacks) do
		pcall(callback, profile)
	end
	DataService.SaveProfile(profile, true)
	profiles[player] = nil
end

-- ============================================================================
-- INIT / START
-- ============================================================================
function DataService.Init()
	setupStore()
end

function DataService.Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	-- Batched replication flush (10 Hz).
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator >= FLUSH_INTERVAL then
			accumulator = 0
			flushDirty()
		end
	end)

	-- Autosave loop. Staggered so saves don't all hit the same frame.
	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player, profile in pairs(profiles) do
				if profile.Loaded and player.Parent then
					task.spawn(DataService.SaveProfile, profile, false)
					task.wait(0.25)
				end
			end
		end
	end)

	-- Save everyone on shutdown. BindToClose gives us up to 30 seconds.
	game:BindToClose(function()
		if useMock then
			return
		end
		local pending = 0
		for _, profile in pairs(profiles) do
			pending += 1
			task.spawn(function()
				DataService.SaveProfile(profile, true)
				pending -= 1
			end)
		end
		local start = os.clock()
		while pending > 0 and os.clock() - start < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
