--[[
	FusionRecipes (Fusion Database)
	-------------------------------
	Data-driven fusion recipes. Each recipe is { IngredientA, IngredientB, Result }.
	Order of ingredients does not matter: "banana + microwave" and
	"microwave + banana" are the same recipe.

	To add a recipe, append a line. Recipes are pre-indexed into a hash map with
	a canonical sorted key, so lookup is O(1) even with thousands of recipes.

	When two items have no recipe, the fusion machine produces a "goo" fallback
	whose tier depends on the best ingredient rarity (see Fallbacks).
]]

local Items = require(script.Parent.Items)

local FusionRecipes = {}

local RecipeList = {
	-- Starter Alley
	{ "banana", "shoe", "banana_boot" },
	{ "bottle", "newspaper", "message_bottle" },
	{ "toaster", "bottle", "burnt_smoothie" },
	{ "sock", "shoe", "sock_puppet" },
	{ "banana", "microwave", "baked_banana" },
	{ "clock", "camera", "timelapse_camera" },
	{ "lamp", "newspaper", "reading_nook" },
	{ "skateboard", "bike_wheel", "mega_board" },
	{ "laptop", "camera", "streamer_setup" },
	{ "golden_toilet", "rubber_duck_king", "royal_bath" },

	-- Poor Neighborhood
	{ "frying_pan", "banana", "banana_pancake" },
	{ "pizza_crust", "microwave", "reheated_pizza" },
	{ "tin_can", "radio", "tin_can_radio" },
	{ "tv", "game_console", "retro_rig" },
	{ "cardboard", "robot_arm", "cardboard_mech" },
	{ "guitar", "radio", "garage_band" },
	{ "teddy_bear", "robot_arm", "terminator_teddy" },
	{ "haunted_doll", "teddy_bear", "cursed_plush" },

	-- Suburbs
	{ "bbq_grill", "banana", "grilled_banana" },
	{ "drone", "camera", "spy_drone" },
	{ "hot_tub", "toaster", "hazard_tub" },
	{ "plastic_flamingo", "rocket_fuel", "flaming_o" },
	{ "bike_wheel", "rocket_fuel", "rocket_bike" },
	{ "lawn_mower", "rocket_fuel", "turbo_mower" },
	{ "smart_fridge", "laptop", "sentient_fridge" },
	{ "garden_gnome", "alien_gnome", "gnome_invasion" },

	-- Downtown
	{ "traffic_cone", "neon_sign", "party_cone" },
	{ "smartphone", "briefcase", "hustle_kit" },
	{ "coffee_cup", "server_rack", "caffeinated_server" },
	{ "hoverboard", "rocket_fuel", "jet_board" },
	{ "dragon_egg", "microwave", "microwaved_dragon" },
	{ "dragon_egg", "laptop", "cyber_dragon" },
	{ "arcade_cabinet", "ai_core", "final_boss" },
	{ "time_machine", "banana", "ancient_banana" },

	-- Luxury District
	{ "pearl_necklace", "teddy_bear", "fancy_teddy" },
	{ "painting", "camera", "forged_masterpiece" },
	{ "toaster", "golden_crown", "king_toaster" },
	{ "sports_car_door", "rocket_fuel", "supersonic_car" },
	{ "golden_crown", "raccoon_king", "trash_monarch" },
	{ "marble_bust", "ai_core", "thinking_statue" },
	{ "diamond_toilet", "rubber_duck_king", "royal_throne_room" },

	-- Celebrity Hills
	{ "autograph", "banana", "signed_banana" },
	{ "selfie_stick", "drone", "selfie_drone" },
	{ "platinum_record", "guitar", "rockstar_legacy" },
	{ "gold_microphone", "ai_core", "ai_popstar" },
	{ "fame_star", "golden_crown", "hollywood_royalty" },
	{ "clone_machine", "raccoon_king", "raccoon_army" },

	-- Billionaire Island
	{ "gold_bar", "toaster", "golden_toast" },
	{ "moon_rock", "microwave", "moon_pie" },
	{ "robot_butler", "teddy_bear", "nanny_bot" },
	{ "rocket_engine", "bike_wheel", "space_bike" },
	{ "mars_blueprint", "rocket_engine", "mars_mission" },
	{ "money_glitch", "clone_machine", "economy_breaker" },

	-- Multi-step (fusion results as ingredients)
	{ "king_toaster", "baked_banana", "royal_breakfast" },
	{ "space_bike", "moon_rock", "lunar_rover" },
	{ "rocket_bike", "cyber_dragon", "dragon_rider" },
	{ "cosmic_dumpster", "time_machine", "big_bin_theory" },
}

-- Failed fusions: best ingredient rarity order -> fallback item id.
local Fallbacks = {
	[1] = "garbage_goo", [2] = "garbage_goo",
	[3] = "toxic_sludge", [4] = "toxic_sludge",
	[5] = "radioactive_ooze", [6] = "radioactive_ooze", [7] = "radioactive_ooze",
}

FusionRecipes.List = {}   -- { { A, B, Result, Key }, ... } (validated)
FusionRecipes.ByKey = {}  -- canonical "a|b" -> result id
FusionRecipes.UsageCount = {} -- item id -> number of recipes it appears in

local function makeKey(a, b)
	if a > b then
		a, b = b, a
	end
	return a .. "|" .. b
end
FusionRecipes.MakeKey = makeKey

-- Build + validate the index once at load.
for _, recipe in ipairs(RecipeList) do
	local a, b, result = recipe[1], recipe[2], recipe[3]
	if not (Items.ById[a] and Items.ById[b] and Items.ById[result]) then
		warn(("[FusionRecipes] Skipping invalid recipe %s + %s = %s"):format(tostring(a), tostring(b), tostring(result)))
	else
		local key = makeKey(a, b)
		if FusionRecipes.ByKey[key] then
			warn(("[FusionRecipes] Duplicate recipe key %s ignored"):format(key))
		else
			FusionRecipes.ByKey[key] = result
			table.insert(FusionRecipes.List, { A = a, B = b, Result = result, Key = key })
			FusionRecipes.UsageCount[a] = (FusionRecipes.UsageCount[a] or 0) + 1
			if b ~= a then
				FusionRecipes.UsageCount[b] = (FusionRecipes.UsageCount[b] or 0) + 1
			end
		end
	end
end

-- Returns resultId, isRecipe. Always returns a valid item id for valid inputs.
function FusionRecipes.Resolve(a, b)
	local result = FusionRecipes.ByKey[makeKey(a, b)]
	if result then
		return result, true
	end
	local itemA, itemB = Items.ById[a], Items.ById[b]
	local best = math.max(itemA and itemA.RarityOrder or 1, itemB and itemB.RarityOrder or 1)
	return Fallbacks[best] or "garbage_goo", false
end

-- Returns the recipe result if one exists, otherwise nil (no fallback).
function FusionRecipes.Lookup(a, b)
	return FusionRecipes.ByKey[makeKey(a, b)]
end

return FusionRecipes
