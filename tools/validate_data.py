#!/usr/bin/env python3
"""
Offline validator for the shared data modules (no Roblox needed).

Bundles src/shared into a single Luau script with tiny stubs for Roblox types
(Color3, Enum, script/require), then runs consistency checks with the `luau`
CLI (https://github.com/luau-lang/luau/releases):

    python3 tools/validate_data.py [path/to/luau]
"""
import os
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHARED = os.path.join(ROOT, "src", "shared")
LUAU = sys.argv[1] if len(sys.argv) > 1 else "luau"

MODULES = {
    "Config": "Config.lua",
    "Util": "Util.lua",
    "Formulas": "Formulas.lua",
    "Data/Items": "Data/Items.lua",
    "Data/FusionRecipes": "Data/FusionRecipes.lua",
    "Data/Quests": "Data/Quests.lua",
    "Data/Achievements": "Data/Achievements.lua",
}

PRELUDE = r'''
-- Roblox stubs -------------------------------------------------------------
local ColorMT = {}
ColorMT.__index = ColorMT
function ColorMT:Lerp(other, t) return self end
Color3 = {
    fromRGB = function(r, g, b) return setmetatable({ R = r / 255, G = g / 255, B = b / 255 }, ColorMT) end,
    new = function(r, g, b) return setmetatable({ R = r, G = g, B = b }, ColorMT) end,
}
Enum = setmetatable({}, { __index = function(_, category)
    return setmetatable({}, { __index = function(_, item) return category .. "." .. item end })
end })

-- Fake instance tree for script.Parent / require ---------------------------
local nodes = {}
local function node(path)
    if nodes[path] then return nodes[path] end
    local n = { __path = path }
    nodes[path] = n
    local parentPath = path:match("^(.*)/[^/]+$") or ""
    if path ~= "" then
        local parent = node(parentPath)
        n.Parent = parent
        parent[path:match("([^/]+)$")] = n
    end
    return n
end
local loaders, cache = {}, {}
local realRequire = require
function require(target)
    local path = target.__path
    if cache[path] == nil then
        assert(loaders[path], "no module " .. tostring(path))
        cache[path] = loaders[path](target)
    end
    return cache[path]
end
'''

TESTS = r'''
-- Tests --------------------------------------------------------------------
local Config = require(node("Config"))
local Util = require(node("Util"))
local Formulas = require(node("Formulas"))
local Items = require(node("Data/Items"))
local Recipes = require(node("Data/FusionRecipes"))
local Quests = require(node("Data/Quests"))
local Achievements = require(node("Data/Achievements"))

local failures = 0
local function check(cond, msg)
    if not cond then failures += 1; print("FAIL: " .. msg) end
end

-- Items
check(Items.Count >= 100, "need at least 100 items, have " .. Items.Count)
for _, zone in ipairs(Config.Zones) do
    for _, rarity in ipairs(Config.Rarities) do
        local list = Items.GetPoolRarity(zone.Pool, rarity.Name)
        check(list and #list > 0, ("pool %s missing %s"):format(zone.Pool, rarity.Name))
    end
end
for _, item in ipairs(Items.List) do
    check(item.Value > 0, item.Id .. " has no value")
    check(type(item.Icon) == "string" and #item.Icon > 0, item.Id .. " has no icon")
end

-- Weights sum to 100
local total = 0
for _, r in ipairs(Config.Rarities) do total += r.Weight end
check(math.abs(total - 100) < 1e-6, "rarity weights sum to " .. total)

-- Recipes
local produced = {}
for _, recipe in ipairs(Recipes.List) do produced[recipe.Result] = true end
for _, item in ipairs(Items.List) do
    if item.Pool == "Fusion" and not item.Id:find("goo") and not item.Id:find("sludge") and not item.Id:find("ooze") then
        check(produced[item.Id], "fusion item " .. item.Id .. " has no recipe")
    end
end
check(Recipes.Lookup("microwave", "banana") == "baked_banana", "recipe order-independence")
local fallback, isRecipe = Recipes.Resolve("banana", "banana")
check(Items.ById[fallback] and not isRecipe, "fallback resolves to an item")

-- Rewards reference real items / boosts
local function checkReward(reward, label)
    if reward.Item then check(Items.ById[reward.Item], label .. " reward item " .. reward.Item) end
    if reward.Boost then check(Config.Boosts[reward.Boost.Id], label .. " reward boost " .. reward.Boost.Id) end
end
for id, quest in pairs(Quests.ById) do
    checkReward(quest.Reward, id)
    if quest.Type == "FindRarity" then check(Config.RarityByName[quest.Rarity], id .. " rarity") end
end
for _, a in ipairs(Achievements) do checkReward(a.Reward, a.Id) end
for _, d in ipairs(Config.DailyRewards) do checkReward(d, "daily " .. d.Day) end
for _, p in ipairs(Config.PlaytimeRewards) do checkReward(p, "playtime " .. p.Minutes) end
check(Items.ById[Config.DailyRewards[7].Item].Rarity == "Mythic", "day 7 must be an exclusive Mythic")

-- Formulas
local data = { Upgrades = { Luck = 0, Backpack = 0, DumpsterSpeed = 10, FusionSpeed = 0 }, Boosts = {} }
check(Formulas.GetCapacity(data, {}) == 50, "starter capacity 50")
check(Formulas.GetCapacity(data, { InfiniteInventory = true }) == Config.InfiniteCapacity, "infinite capacity")
check(Formulas.GetHoldDuration(data) >= Config.Search.MinHoldDuration, "hold floor")
check(Formulas.GetUpgradeCost("Backpack", 0) == 2000, "backpack tier cost")
check(Formulas.GetUpgradeCost("Backpack", 4) == nil, "backpack max")
local odds = Formulas.GetOddsPercent(1)
check(math.abs(odds.Common - 60) < 1e-6 and math.abs(odds.Secret - 0.05) < 1e-6, "base odds")
local lucky = Formulas.GetOddsPercent(3)
check(lucky.Secret > odds.Secret and lucky.Common < odds.Common, "luck shifts odds upward")
check(Formulas.GetLuck({ Upgrades = { Luck = 0 }, Boosts = { Luck2x = 10 } }, { VIP = true, Luck2x = true }) == 1.25 * 4, "luck stacking")

-- Util
check(Util.FormatNumber(100) == "100", "format 100 -> " .. Util.FormatNumber(100))
check(Util.FormatNumber(1500) == "1.5K", "format 1500 -> " .. Util.FormatNumber(1500))
check(Util.FormatNumber(2000000) == "2M", "format 2M -> " .. Util.FormatNumber(2000000))
check(Util.FormatNumber(123456789) == "123M", "format 123M -> " .. Util.FormatNumber(123456789))

-- Zone costs strictly increase
for i = 2, #Config.Zones do
    check(Config.Zones[i].Cost > Config.Zones[i - 1].Cost, "zone costs increase")
end

print(("Items: %d | Recipes: %d | Quests: %d | Achievements: %d"):format(Items.Count, #Recipes.List, #Quests.Main + #Quests.Daily + #Quests.Weekly, #Achievements))
if failures > 0 then
    error(failures .. " validation failure(s)")
end
print("All data checks passed.")
'''

def main():
    parts = [PRELUDE]
    for path, rel in MODULES.items():
        with open(os.path.join(SHARED, rel), encoding="utf-8") as f:
            source = f.read()
        parts.append(f'loaders["{path}"] = function(script)\n{source}\nend\nnode("{path}")\n')
    parts.append(TESTS)
    with tempfile.NamedTemporaryFile("w", suffix=".luau", delete=False, encoding="utf-8") as f:
        f.write("\n".join(parts))
        bundle = f.name
    result = subprocess.run([LUAU, bundle])
    os.unlink(bundle)
    sys.exit(result.returncode)

if __name__ == "__main__":
    main()
