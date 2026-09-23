--[[
	Config
	------
	Central tuning file for Dumpster Fusion Simulator. Every balance number in the
	game lives here so a solo developer can rebalance without touching logic.

	Shared by server and client. The server is the ONLY authority that applies
	these numbers to player data; the client reads them purely for display.
]]

local Config = {}

-- ============================================================================
-- DATA / SAVING
-- ============================================================================
Config.DataStoreName = "DumpsterFusion_PlayerData_v1"
Config.AutosaveInterval = 60 -- seconds
Config.SessionLockTimeout = 600 -- seconds before a stale session lock is ignored
Config.DataVersion = 1

-- ============================================================================
-- RARITIES (ordered from worst to best). Weight = base percent chance.
-- LuckScale controls how strongly Luck multiplies this tier's weight.
-- ============================================================================
Config.Rarities = {
	{ Name = "Common",    Weight = 60,   Color = Color3.fromRGB(186, 190, 196), BaseValue = 5,     LuckScale = 0 },
	{ Name = "Uncommon",  Weight = 25,   Color = Color3.fromRGB(88, 214, 111),  BaseValue = 12,    LuckScale = 0.5 },
	{ Name = "Rare",      Weight = 10,   Color = Color3.fromRGB(64, 156, 255),  BaseValue = 35,    LuckScale = 1 },
	{ Name = "Epic",      Weight = 3,    Color = Color3.fromRGB(178, 92, 255),  BaseValue = 120,   LuckScale = 1.5 },
	{ Name = "Legendary", Weight = 1.5,  Color = Color3.fromRGB(255, 184, 28),  BaseValue = 500,   LuckScale = 2 },
	{ Name = "Mythic",    Weight = 0.45, Color = Color3.fromRGB(255, 64, 118),  BaseValue = 2500,  LuckScale = 2.5 },
	{ Name = "Secret",    Weight = 0.05, Color = Color3.fromRGB(20, 20, 24),    BaseValue = 15000, LuckScale = 3 },
}

-- Lookup: rarity name -> { Order = n, ... }
Config.RarityByName = {}
for order, rarity in ipairs(Config.Rarities) do
	rarity.Order = order
	Config.RarityByName[rarity.Name] = rarity
end

-- Rarity at/above which a server-wide announcement is sent.
Config.AnnounceMinRarity = "Legendary"
-- Rarity at/above which a discovery counts as a "rare discovery" in the Collection book.
Config.RareDiscoveryMinRarity = "Rare"

-- ============================================================================
-- DUMPSTER SEARCHING
-- ============================================================================
Config.Search = {
	HoldDuration = 1.5,          -- base seconds to hold E
	MinHoldDuration = 0.45,      -- floor after Dumpster Speed upgrades
	Cooldown = 5,                -- seconds per dumpster, per player
	MaxDistance = 12,            -- prompt activation distance (studs)
	ServerDistanceSlack = 6,     -- extra studs allowed server-side for latency
	HoldTimeTolerance = 0.8,     -- server accepts holds >= required * tolerance
	GlobalMinInterval = 0.35,    -- hard cap: max ~3 searches/sec per player
}

-- ============================================================================
-- FUSION
-- ============================================================================
Config.Fusion = {
	BaseDuration = 3,            -- seconds a fusion takes before upgrades
	MinDuration = 0.5,
	FusionMasterDuration = 0.25, -- Fusion Master gamepass: near-instant
	FusionMasterDoubleChance = 0.15,
	StationRange = 22,           -- studs from a fusion machine to fuse
}

Config.SellStationRange = 22

-- ============================================================================
-- ZONES
-- Pool = which loot pool the zone's dumpsters roll from (see Data/Items).
-- ValueMultiplier is used by the item database to scale sell prices.
-- ============================================================================
Config.Zones = {
	{
		Id = 0, Key = "Spawn", Name = "Starter Alley", Cost = 0, Pool = "Starter",
		ValueMultiplier = 1, DumpsterCount = 8,
		Theme = { Ground = Color3.fromRGB(96, 104, 112), Accent = Color3.fromRGB(80, 200, 120), Dumpster = Color3.fromRGB(46, 125, 50), Material = Enum.Material.Concrete },
	},
	{
		Id = 1, Key = "PoorNeighborhood", Name = "Poor Neighborhood", Cost = 2500, Pool = "Poor",
		ValueMultiplier = 3, DumpsterCount = 10,
		Theme = { Ground = Color3.fromRGB(120, 98, 72), Accent = Color3.fromRGB(170, 120, 70), Dumpster = Color3.fromRGB(110, 80, 50), Material = Enum.Material.Ground },
	},
	{
		Id = 2, Key = "Suburbs", Name = "Suburbs", Cost = 30000, Pool = "Suburbs",
		ValueMultiplier = 12, DumpsterCount = 10,
		Theme = { Ground = Color3.fromRGB(92, 160, 76), Accent = Color3.fromRGB(240, 240, 240), Dumpster = Color3.fromRGB(40, 90, 170), Material = Enum.Material.Grass },
	},
	{
		Id = 3, Key = "Downtown", Name = "Downtown", Cost = 350000, Pool = "Downtown",
		ValueMultiplier = 50, DumpsterCount = 12,
		Theme = { Ground = Color3.fromRGB(58, 60, 68), Accent = Color3.fromRGB(0, 200, 255), Dumpster = Color3.fromRGB(70, 70, 80), Material = Enum.Material.Asphalt },
	},
	{
		Id = 4, Key = "LuxuryDistrict", Name = "Luxury District", Cost = 4500000, Pool = "Luxury",
		ValueMultiplier = 220, DumpsterCount = 12,
		Theme = { Ground = Color3.fromRGB(235, 228, 214), Accent = Color3.fromRGB(212, 175, 55), Dumpster = Color3.fromRGB(30, 30, 30), Material = Enum.Material.Marble },
	},
	{
		Id = 5, Key = "CelebrityHills", Name = "Celebrity Hills", Cost = 60000000, Pool = "Celebrity",
		ValueMultiplier = 1000, DumpsterCount = 12,
		Theme = { Ground = Color3.fromRGB(255, 170, 200), Accent = Color3.fromRGB(255, 80, 160), Dumpster = Color3.fromRGB(200, 40, 120), Material = Enum.Material.SmoothPlastic },
	},
	{
		Id = 6, Key = "BillionaireIsland", Name = "Billionaire Island", Cost = 900000000, Pool = "Billionaire",
		ValueMultiplier = 5000, DumpsterCount = 12,
		Theme = { Ground = Color3.fromRGB(242, 214, 140), Accent = Color3.fromRGB(255, 215, 0), Dumpster = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Sand },
	},
}

Config.ZoneById = {}
for _, zone in ipairs(Config.Zones) do
	Config.ZoneById[zone.Id] = zone
end
Config.MaxZoneId = #Config.Zones - 1

-- World layout (used by WorldBuilder and the server zone-guard).
Config.World = {
	ZoneSpacing = 260,   -- studs between zone centers along +X
	ZoneSize = 220,      -- square zone size
	SpawnSize = 200,
}

-- VIP dumpsters roll from the player's best unlocked zone with extra luck.
Config.VIP = {
	LuckMultiplier = 1.25,       -- VIP pass global luck bonus (+25%)
	VIPDumpsterLuckBonus = 1.5,  -- extra luck when searching VIP-area dumpsters
	ChatTagColor = Color3.fromRGB(255, 205, 40),
}

-- ============================================================================
-- UPGRADES
-- Costs grow exponentially: cost = BaseCost * Growth ^ level
-- Backpack uses an explicit tier list instead.
-- ============================================================================
Config.BackpackTiers = {
	{ Capacity = 50,   Cost = 0 },
	{ Capacity = 100,  Cost = 2000 },
	{ Capacity = 200,  Cost = 40000 },
	{ Capacity = 500,  Cost = 900000 },
	{ Capacity = 1000, Cost = 25000000 },
}
Config.InfiniteCapacity = 1000000

Config.Upgrades = {
	{
		Id = "Backpack", Name = "Backpack Size", Icon = "🎒",
		Description = "Carry more junk before you need to sell.",
		MaxLevel = #Config.BackpackTiers - 1,
	},
	{
		Id = "Luck", Name = "Luck", Icon = "🍀",
		Description = "+10% luck per level. Better rarities, more often.",
		MaxLevel = 30, BaseCost = 300, Growth = 1.52, PerLevel = 0.10,
	},
	{
		Id = "DumpsterSpeed", Name = "Dumpster Speed", Icon = "⚡",
		Description = "Search dumpsters faster (-7% hold time per level).",
		MaxLevel = 10, BaseCost = 500, Growth = 1.75, PerLevel = 0.07,
	},
	{
		Id = "FusionSpeed", Name = "Fusion Speed", Icon = "⚗️",
		Description = "Fuse items faster (-8% fusion time per level).",
		MaxLevel = 10, BaseCost = 400, Growth = 1.7, PerLevel = 0.08,
	},
	{
		Id = "AutoCollect", Name = "Auto Collect", Icon = "🤖",
		Description = "Automatically search nearby dumpsters. Higher levels = more range & speed.",
		MaxLevel = 5, BaseCost = 20000, Growth = 4.5,
		BaseRange = 10, RangePerLevel = 3, BaseInterval = 6.5, IntervalPerLevel = 0.75,
	},
	{
		Id = "AutoSell", Name = "Auto Sell", Icon = "💸",
		Description = "Auto-sells already-discovered junk. Each level sells one rarity higher.",
		MaxLevel = 4, BaseCost = 15000, Growth = 6,
	},
}

Config.UpgradeById = {}
for _, upgrade in ipairs(Config.Upgrades) do
	Config.UpgradeById[upgrade.Id] = upgrade
end

-- ============================================================================
-- TIMED BOOSTS (stored as remaining seconds; only tick down while playing)
-- ============================================================================
Config.MaxBoostDuration = 24 * 60 * 60
Config.Boosts = {
	Luck2x = { Name = "2x Luck", Icon = "🍀", Color = Color3.fromRGB(88, 214, 111) },
	Cash2x = { Name = "2x Cash", Icon = "💰", Color = Color3.fromRGB(255, 205, 40) },
	FusionSpeed = { Name = "Fusion Speed", Icon = "⚗️", Color = Color3.fromRGB(178, 92, 255) },
	CooldownReduction = { Name = "Fast Dumpsters", Icon = "⏱️", Color = Color3.fromRGB(64, 156, 255) },
}

-- ============================================================================
-- MONETIZATION
-- Replace Id = 0 with your real IDs from the Creator Dashboard.
-- While an Id is 0 and you are in Studio, purchases are simulated for testing.
-- ============================================================================
Config.GamePasses = {
	VIP = { Id = 0, Name = "VIP", Icon = "👑", Price = 399,
		Description = "Gold chat tag, +25% luck, exclusive VIP area with VIP dumpsters." },
	Luck2x = { Id = 0, Name = "2x Luck", Icon = "🍀", Price = 249,
		Description = "Permanently double your luck." },
	Cash2x = { Id = 0, Name = "2x Cash", Icon = "💰", Price = 299,
		Description = "Permanently double all cash earned." },
	AutoSell = { Id = 0, Name = "Auto Sell", Icon = "💸", Price = 199,
		Description = "Max-level Auto Sell (up to Epic) and auto-clears space when full." },
	InfiniteInventory = { Id = 0, Name = "Infinite Inventory", Icon = "♾️", Price = 449,
		Description = "Never run out of backpack space again." },
	FusionMaster = { Id = 0, Name = "Fusion Master", Icon = "🧪", Price = 349,
		Description = "Instant fusions + 15% chance to get double output." },
}
Config.GamePassOrder = { "VIP", "Luck2x", "Cash2x", "AutoSell", "InfiniteInventory", "FusionMaster" }

-- Cash packs scale with the player's best unlocked zone so they stay relevant.
Config.DevProducts = {
	SmallCash = { Id = 0, Name = "Small Cash Pack", Icon = "💵", Price = 29, CashBase = 1500 },
	MediumCash = { Id = 0, Name = "Medium Cash Pack", Icon = "💰", Price = 79, CashBase = 5000 },
	LargeCash = { Id = 0, Name = "Large Cash Pack", Icon = "🤑", Price = 199, CashBase = 15000 },
	MegaCash = { Id = 0, Name = "Mega Cash Pack", Icon = "🏦", Price = 499, CashBase = 50000 },
	LuckCrate = { Id = 0, Name = "Luck Crate", Icon = "🎁", Price = 99,
		Description = "15 min 2x Luck + a guaranteed Epic-or-better item from your best zone." },
}
Config.DevProductOrder = { "SmallCash", "MediumCash", "LargeCash", "MegaCash", "LuckCrate" }

-- ============================================================================
-- DAILY LOGIN (7-day cycle). Missing more than one day resets the streak.
-- Reward fields: Cash (scaled by zone), Boost = {Id, Duration}, Item = itemId
-- ============================================================================
Config.DailyRewards = {
	{ Day = 1, Cash = 500 },
	{ Day = 2, Boost = { Id = "Luck2x", Duration = 600 } },
	{ Day = 3, Cash = 2500 },
	{ Day = 4, Boost = { Id = "Cash2x", Duration = 900 } },
	{ Day = 5, Cash = 7500 },
	{ Day = 6, Boost = { Id = "CooldownReduction", Duration = 1200 } },
	{ Day = 7, Item = "exclusive_weekly_crown", Cash = 15000 },
}

-- ============================================================================
-- PLAYTIME REWARDS (per session, minutes played)
-- ============================================================================
Config.PlaytimeRewards = {
	{ Minutes = 5,  Cash = 300 },
	{ Minutes = 10, Boost = { Id = "Luck2x", Duration = 300 } },
	{ Minutes = 20, Cash = 1500 },
	{ Minutes = 30, Boost = { Id = "CooldownReduction", Duration = 600 } },
	{ Minutes = 45, Cash = 5000 },
	{ Minutes = 60, Item = "exclusive_timekeeper" },
}

-- ============================================================================
-- SOUNDS (swap for Creator Store audio IDs if you prefer)
-- ============================================================================
Config.Sounds = {
	Click = "rbxasset://sounds/electronicpingshort.wav",
	DumpsterOpen = "rbxasset://sounds/snap.wav",
	ItemFound = "rbxasset://sounds/electronicpingshort.wav",
	RareFound = "rbxasset://sounds/victory.wav",
	FusionStart = "rbxasset://sounds/swoosh.wav",
	FusionComplete = "rbxasset://sounds/victory.wav",
	ZoneUnlock = "rbxasset://sounds/victory.wav",
	Sell = "rbxasset://sounds/electronicpingshort.wav",
	Error = "rbxasset://sounds/button.wav",
}

-- Optional looping background music (e.g. "rbxassetid://1234567890").
-- Leave empty for no music. Toggled by the Music setting.
Config.MusicId = ""

-- ============================================================================
-- MISC
-- ============================================================================
Config.RequestRateLimit = 12 -- max UI requests per second per player
Config.StarterCash = 0

return Config
