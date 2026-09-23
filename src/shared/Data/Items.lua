--[[
	Items (Item Database)
	---------------------
	Data-driven list of every item in the game. To add items, append entries to
	a pool below — nothing else needs to change. Thousands of entries are fine:
	all lookups are pre-indexed once at require-time.

	Entry format: { Id, Name, Rarity, Icon [, Value] [, Image] }
	  Id     unique string key (saved in DataStores — NEVER rename a shipped Id)
	  Name   display name
	  Rarity one of Config.Rarities names
	  Icon   emoji fallback icon (renders everywhere, zero asset uploads needed)
	  Value  optional explicit sell value; otherwise BaseValue * pool multiplier
	  Image  optional "rbxassetid://..." image; overrides the emoji when set

	Every item automatically receives:
	  DexId  sequential Discoverable ID used by the Collection book ordering
	  Pool   which loot pool (or "Fusion"/"Exclusive") it belongs to
	  Value  resolved sell value
]]

local Config = require(script.Parent.Parent.Config)

local Items = {}

Items.ById = {}
Items.List = {}
Items.Pools = {} -- Pools[poolName][rarityName] = { itemId, ... }
Items.Count = 0

-- Value multiplier per pool. Dumpster pools mirror their zone multiplier.
local PoolMultiplier = {}
for _, zone in ipairs(Config.Zones) do
	PoolMultiplier[zone.Pool] = zone.ValueMultiplier
end

local function register(pool, entry, multiplier)
	local id, name, rarityName, icon, value, image = entry[1], entry[2], entry[3], entry[4], entry[5], entry[6]
	local rarity = Config.RarityByName[rarityName]
	assert(rarity, ("Item %s has invalid rarity %s"):format(tostring(id), tostring(rarityName)))
	assert(not Items.ById[id], ("Duplicate item id %s"):format(tostring(id)))

	Items.Count += 1
	local item = {
		Id = id,
		Name = name,
		Rarity = rarityName,
		RarityOrder = rarity.Order,
		Icon = icon,
		Image = image,
		Pool = pool,
		DexId = Items.Count,
		Value = value or math.floor(rarity.BaseValue * (multiplier or 1)),
	}
	Items.ById[id] = item
	table.insert(Items.List, item)

	Items.Pools[pool] = Items.Pools[pool] or {}
	Items.Pools[pool][rarityName] = Items.Pools[pool][rarityName] or {}
	table.insert(Items.Pools[pool][rarityName], id)
end

-- Registers a dumpster loot pool.
local function pool(poolName, entries)
	local multiplier = PoolMultiplier[poolName] or 1
	for _, entry in ipairs(entries) do
		register(poolName, entry, multiplier)
	end
end

-- Registers non-dumpster items (fusion results, exclusives). `multiplier`
-- scales value relative to the rarity base value.
local function special(poolName, entries)
	for _, entry in ipairs(entries) do
		register(poolName, { entry[1], entry[2], entry[3], entry[4], entry[6], entry[7] }, entry[5] or 1)
	end
end

-- ============================================================================
-- DUMPSTER LOOT POOLS (one per zone; every pool covers all 7 rarities)
-- ============================================================================

pool("Starter", {
	{ "banana", "Banana", "Common", "🍌" },
	{ "shoe", "Shoe", "Common", "👟" },
	{ "bottle", "Bottle", "Common", "🍼" },
	{ "newspaper", "Old Newspaper", "Common", "📰" },
	{ "toaster", "Toaster", "Uncommon", "🍞" },
	{ "clock", "Clock", "Uncommon", "⏰" },
	{ "sock", "Smelly Sock", "Uncommon", "🧦" },
	{ "microwave", "Microwave", "Rare", "📟" },
	{ "camera", "Camera", "Rare", "📷" },
	{ "lamp", "Desk Lamp", "Rare", "💡" },
	{ "bike_wheel", "Bike Wheel", "Epic", "🚲" },
	{ "skateboard", "Skateboard", "Epic", "🛹" },
	{ "laptop", "Laptop", "Legendary", "💻" },
	{ "golden_toilet", "Golden Toilet", "Mythic", "🚽" },
	{ "rubber_duck_king", "Rubber Duck King", "Secret", "🦆" },
})

pool("Poor", {
	{ "tin_can", "Tin Can", "Common", "🥫" },
	{ "cardboard", "Cardboard Box", "Common", "📦" },
	{ "broken_umbrella", "Broken Umbrella", "Common", "☂️" },
	{ "pizza_crust", "Pizza Crust", "Common", "🍕" },
	{ "radio", "Old Radio", "Uncommon", "📻" },
	{ "teddy_bear", "Teddy Bear", "Uncommon", "🧸" },
	{ "frying_pan", "Frying Pan", "Uncommon", "🍳" },
	{ "tv", "TV", "Rare", "📺" },
	{ "guitar", "Broken Guitar", "Rare", "🎸" },
	{ "bike_helmet", "Bike Helmet", "Rare", "⛑️" },
	{ "vacuum", "Vacuum Cleaner", "Epic", "🌀" },
	{ "game_console", "Game Console", "Epic", "🎮" },
	{ "robot_arm", "Robot Arm", "Legendary", "🤖" },
	{ "haunted_doll", "Haunted Doll", "Mythic", "👻" },
	{ "raccoon_king", "Raccoon King", "Secret", "🦝" },
})

pool("Suburbs", {
	{ "garden_gnome", "Garden Gnome", "Common", "🧙" },
	{ "plastic_flamingo", "Plastic Flamingo", "Common", "🐦" },
	{ "grass_clippings", "Grass Clippings", "Common", "🌿" },
	{ "garden_hose", "Garden Hose", "Common", "🐍" },
	{ "bbq_grill", "BBQ Grill", "Uncommon", "🍖" },
	{ "soccer_ball", "Deflated Soccer Ball", "Uncommon", "⚽" },
	{ "lawn_chair", "Lawn Chair", "Uncommon", "💺" },
	{ "lawn_mower", "Lawn Mower", "Rare", "🚜" },
	{ "treadmill", "Treadmill", "Rare", "🏃" },
	{ "drone", "Toy Drone", "Rare", "🚁" },
	{ "hot_tub", "Hot Tub", "Epic", "🛁" },
	{ "smart_fridge", "Smart Fridge", "Epic", "❄️" },
	{ "rocket_fuel", "Rocket Fuel", "Legendary", "⛽" },
	{ "alien_gnome", "Alien Gnome", "Mythic", "👽" },
	{ "suburban_ufo", "Suburban UFO", "Secret", "🛸" },
})

pool("Downtown", {
	{ "coffee_cup", "Coffee Cup", "Common", "☕" },
	{ "traffic_cone", "Traffic Cone", "Common", "🚧" },
	{ "receipt", "Crumpled Receipt", "Common", "🧾" },
	{ "subway_map", "Subway Map", "Common", "🗺️" },
	{ "briefcase", "Briefcase", "Uncommon", "💼" },
	{ "parking_meter", "Parking Meter", "Uncommon", "🅿️" },
	{ "smartphone", "Cracked Smartphone", "Uncommon", "📱" },
	{ "server_rack", "Server Rack", "Rare", "🖥️" },
	{ "neon_sign", "Neon Sign", "Rare", "🌃" },
	{ "espresso_machine", "Espresso Machine", "Rare", "⚙️" },
	{ "hoverboard", "Hoverboard", "Epic", "🏄" },
	{ "arcade_cabinet", "Arcade Cabinet", "Epic", "🕹️" },
	{ "dragon_egg", "Dragon Egg", "Legendary", "🥚" },
	{ "ai_core", "Rogue AI Core", "Mythic", "🧠" },
	{ "time_machine", "Time Machine", "Secret", "⌛" },
})

pool("Luxury", {
	{ "champagne_cork", "Champagne Cork", "Common", "🍾" },
	{ "silk_tie", "Silk Tie", "Common", "👔" },
	{ "caviar_tin", "Caviar Tin", "Common", "🐟" },
	{ "designer_bag", "Designer Shopping Bag", "Common", "👜" },
	{ "pearl_necklace", "Pearl Necklace", "Uncommon", "📿" },
	{ "fancy_watch", "Fancy Watch", "Uncommon", "⌚" },
	{ "perfume", "Perfume Bottle", "Uncommon", "🌸" },
	{ "chandelier", "Crystal Chandelier", "Rare", "🕯️" },
	{ "marble_bust", "Marble Bust", "Rare", "🗿" },
	{ "yacht_wheel", "Yacht Wheel", "Rare", "⚓" },
	{ "sports_car_door", "Sports Car Door", "Epic", "🏎️" },
	{ "painting", "Priceless Painting", "Epic", "🖼️" },
	{ "golden_crown", "Golden Crown", "Legendary", "👑" },
	{ "diamond_toilet", "Diamond Toilet", "Mythic", "💎" },
	{ "philosophers_stone", "Philosopher's Stone", "Secret", "🔮" },
})

pool("Celebrity", {
	{ "autograph", "Autograph", "Common", "✍️" },
	{ "sunglasses", "Designer Shades", "Common", "🕶️" },
	{ "selfie_stick", "Selfie Stick", "Common", "🤳" },
	{ "fan_mail", "Fan Mail", "Common", "💌" },
	{ "paparazzi_camera", "Paparazzi Camera", "Uncommon", "📸" },
	{ "movie_clapper", "Movie Clapper", "Uncommon", "🎬" },
	{ "gold_microphone", "Gold Microphone", "Uncommon", "🎤" },
	{ "platinum_record", "Platinum Record", "Rare", "💿" },
	{ "music_award", "Music Award", "Rare", "🏆" },
	{ "stage_light", "Stage Spotlight", "Rare", "🔦" },
	{ "celebrity_wig", "Celebrity Wig", "Epic", "💇" },
	{ "tour_bus_wheel", "Tour Bus Wheel", "Epic", "🚌" },
	{ "fame_star", "Walk of Fame Star", "Legendary", "🌟" },
	{ "clone_machine", "Celebrity Clone Machine", "Mythic", "👯" },
	{ "influencer_soul", "Influencer's Soul", "Secret", "📲" },
})

pool("Billionaire", {
	{ "gold_bar", "Gold Bar", "Common", "🥇" },
	{ "stock_certificate", "Stock Certificate", "Common", "📈" },
	{ "yacht_brochure", "Yacht Brochure", "Common", "🛥️" },
	{ "money_stack", "Stack of Cash", "Common", "💵" },
	{ "jet_seat", "Private Jet Seat", "Uncommon", "✈️" },
	{ "space_ticket", "Space Ticket", "Uncommon", "🎫" },
	{ "diamond_dust", "Diamond Dust", "Uncommon", "💠" },
	{ "rocket_engine", "Rocket Engine", "Rare", "🚀" },
	{ "island_deed", "Island Deed", "Rare", "🏝️" },
	{ "robot_butler", "Robot Butler", "Rare", "🤵" },
	{ "yacht_anchor", "Mega Yacht Anchor", "Epic", "🛳️" },
	{ "moon_rock", "Moon Rock", "Epic", "🌑" },
	{ "mars_blueprint", "Mars Colony Blueprint", "Legendary", "🔴" },
	{ "money_glitch", "Infinite Money Glitch", "Mythic", "♾️" },
	{ "cosmic_dumpster", "Cosmic Dumpster", "Secret", "🌌" },
})

-- ============================================================================
-- FUSION RESULTS  { Id, Name, Rarity, Icon, ValueMultiplier }
-- Recipes that produce these live in Data/FusionRecipes.
-- ============================================================================
special("Fusion", {
	-- Failed-fusion fallbacks (no recipe matched)
	{ "garbage_goo", "Garbage Goo", "Common", "🟢", 1 },
	{ "toxic_sludge", "Toxic Sludge", "Uncommon", "☣️", 3 },
	{ "radioactive_ooze", "Radioactive Ooze", "Rare", "☢️", 20 },

	-- Starter tier
	{ "banana_boot", "Banana Boot", "Uncommon", "🥾", 2 },
	{ "message_bottle", "Message in a Bottle", "Uncommon", "📜", 2 },
	{ "burnt_smoothie", "Burnt Smoothie", "Uncommon", "🥤", 2 },
	{ "sock_puppet", "Sock Puppet", "Uncommon", "🎭", 2 },
	{ "baked_banana", "Baked Banana", "Rare", "🍠", 2 },
	{ "timelapse_camera", "Time-Lapse Camera", "Rare", "🎞️", 2 },
	{ "reading_nook", "Reading Nook", "Rare", "📖", 2 },
	{ "mega_board", "Mega Board", "Epic", "🏂", 2 },
	{ "streamer_setup", "Streamer Setup", "Legendary", "🎥", 2 },
	{ "royal_bath", "Royal Bath", "Secret", "🛀", 2 },

	-- Poor Neighborhood tier
	{ "banana_pancake", "Banana Pancake", "Uncommon", "🥞", 6 },
	{ "reheated_pizza", "Reheated Pizza", "Uncommon", "🔥", 6 },
	{ "tin_can_radio", "Tin Can Radio", "Rare", "📡", 6 },
	{ "retro_rig", "Retro Gaming Rig", "Epic", "👾", 6 },
	{ "cardboard_mech", "Cardboard Mech", "Epic", "🦿", 6 },
	{ "garage_band", "Garage Band", "Epic", "🥁", 6 },
	{ "terminator_teddy", "Terminator Teddy", "Legendary", "🐻", 6 },
	{ "cursed_plush", "Cursed Plush", "Mythic", "👹", 6 },

	-- Suburbs tier
	{ "grilled_banana", "Grilled Banana", "Rare", "🍢", 24 },
	{ "spy_drone", "Spy Drone", "Epic", "🛰️", 24 },
	{ "hazard_tub", "Hazard Tub", "Epic", "⚡", 24 },
	{ "flaming_o", "Flaming-O", "Epic", "🔥", 24 },
	{ "rocket_bike", "Rocket Bike", "Legendary", "🏍️", 24 },
	{ "turbo_mower", "Turbo Mower", "Legendary", "💨", 24 },
	{ "sentient_fridge", "Sentient Fridge", "Legendary", "🧟", 24 },
	{ "gnome_invasion", "Gnome Invasion", "Mythic", "🍄", 24 },

	-- Downtown tier
	{ "party_cone", "Party Cone", "Rare", "🎉", 100 },
	{ "hustle_kit", "Hustle Kit", "Rare", "💹", 100 },
	{ "caffeinated_server", "Caffeinated Server", "Epic", "🔋", 100 },
	{ "jet_board", "Jet Board", "Legendary", "🌠", 100 },
	{ "microwaved_dragon", "Microwaved Dragon", "Legendary", "🐲", 100 },
	{ "cyber_dragon", "Cyber Dragon", "Mythic", "🐉", 100 },
	{ "final_boss", "Final Boss", "Mythic", "😈", 100 },
	{ "ancient_banana", "Ancient Banana", "Secret", "🦴", 100 },

	-- Luxury tier
	{ "fancy_teddy", "Fancy Teddy", "Rare", "🎀", 440 },
	{ "forged_masterpiece", "Forged Masterpiece", "Epic", "🎨", 440 },
	{ "king_toaster", "King Toaster", "Legendary", "🤴", 440 },
	{ "supersonic_car", "Supersonic Car", "Legendary", "🏁", 440 },
	{ "trash_monarch", "Trash Monarch", "Mythic", "🗑️", 440 },
	{ "thinking_statue", "Thinking Statue", "Mythic", "🤔", 440 },
	{ "royal_throne_room", "Royal Throne Room", "Secret", "🏰", 440 },

	-- Celebrity tier
	{ "signed_banana", "Signed Banana", "Rare", "🖊️", 2000 },
	{ "selfie_drone", "Selfie Drone", "Epic", "🤩", 2000 },
	{ "rockstar_legacy", "Rockstar Legacy", "Legendary", "🤘", 2000 },
	{ "ai_popstar", "AI Pop Star", "Mythic", "💃", 2000 },
	{ "hollywood_royalty", "Hollywood Royalty", "Mythic", "🎖️", 2000 },
	{ "raccoon_army", "Raccoon Army", "Secret", "🐾", 2000 },

	-- Billionaire tier
	{ "golden_toast", "Golden Toast", "Rare", "✨", 10000 },
	{ "moon_pie", "Moon Pie", "Epic", "🥧", 10000 },
	{ "nanny_bot", "Nanny Bot", "Epic", "🦾", 10000 },
	{ "space_bike", "Space Bike", "Legendary", "🌍", 10000 },
	{ "mars_mission", "Mars Mission", "Mythic", "🔭", 10000 },
	{ "economy_breaker", "Economy Breaker", "Secret", "💥", 10000 },

	-- Multi-step fusions (fusion results as ingredients)
	{ "royal_breakfast", "Royal Breakfast", "Mythic", "🍽️", 1000 },
	{ "lunar_rover", "Lunar Rover", "Mythic", "🌙", 15000 },
	{ "dragon_rider", "Dragon Rider", "Secret", "🏇", 1000 },
	{ "big_bin_theory", "The Big Bin Theory", "Secret", "🪐", 20000 },
})

-- ============================================================================
-- EXCLUSIVES (quests, daily login, playtime, shop crates)
-- ============================================================================
special("Exclusive", {
	{ "exclusive_rookie_trophy", "Rookie Scavenger Trophy", "Epic", "🏅", 5 },
	{ "exclusive_quest_medal", "Weekly Hustler Medal", "Legendary", "🎖️", 20 },
	{ "exclusive_timekeeper", "Timekeeper's Hourglass", "Legendary", "⏳", 10 },
	{ "exclusive_weekly_crown", "Crown of Consistency", "Mythic", "💫", 10 },
	{ "exclusive_golden_dumpster", "Golden Dumpster", "Mythic", "🏆", 200 },
})

-- ============================================================================
-- HELPERS
-- ============================================================================

function Items.Get(id)
	return Items.ById[id]
end

function Items.IsValid(id)
	return type(id) == "string" and Items.ById[id] ~= nil
end

-- Returns the list of item ids in a pool for a rarity (may be nil).
function Items.GetPoolRarity(poolName, rarityName)
	local p = Items.Pools[poolName]
	return p and p[rarityName]
end

function Items.GetRarityColor(id)
	local item = Items.ById[id]
	local rarity = item and Config.RarityByName[item.Rarity]
	return rarity and rarity.Color or Color3.new(1, 1, 1)
end

return Items
