# 🗑️ Dumpster Fusion Simulator ⚗️

A complete Roblox simulator game: search dumpsters, fuse junk into increasingly absurd items, fill the Collection book, and work your way from **Starter Alley** to **Billionaire Island**.

Everything is built in code: the map, dumpsters, stations and all of the UI. Sync the project into an empty baseplate and press Play.

---

## ✨ Features

| System | What it does |
|---|---|
| **Dumpster searching** | "Search Dumpster" ProximityPrompt, hold **E** for 1.5s. The server rolls the loot. 5s cooldown per dumpster, per player. The lid swings open with a sound and a rarity-colored particle burst, and the item's icon floats up. |
| **7 rarities** | Common 60%, Uncommon 25%, Rare 10%, Epic 3%, Legendary 1.5%, Mythic 0.45%, Secret 0.05%. Luck shifts the weights toward the higher tiers. |
| **170 items** | 105 dumpster items (15 per zone, every rarity in every zone), 60 fusion results and 5 exclusives. |
| **Fusion** | Two items go into the Fusion Machine and a new item comes out after a timed fusion. There are 57 data-driven recipes, including multi-step ones. A pair with no recipe makes "goo". A Recipe Book shows what you've found. |
| **Collection (Pokedex)** | Tracks total, Rare+ and Secret discoveries and the collection %. Unknown items show as `???????`. |
| **Inventory** | Grid with rarity colors, quantities, search, sorting (Rarity/Value/Name/Amount) and favorites. Capacity goes 50 → 100 → 200 → 500 → 1000. |
| **Selling** | Sell Selected, Sell All or Sell Duplicates at Sell Stations. Favorites can never be sold. |
| **Upgrades** | Backpack, Luck, Dumpster Speed, Fusion Speed, Auto Collect and Auto Sell, all with exponential costs. |
| **6 zones + spawn** | Poor Neighborhood, Suburbs, Downtown, Luxury District, Celebrity Hills and Billionaire Island. Each has its own theme, better dumpsters, better loot and a higher unlock cost. |
| **Quests** | An 18-step story chain, 3 daily quests and 3 weekly quests. Rewards are cash, boosts and exclusive items. |
| **Daily login** | 7-day cycle. Day 7 gives an exclusive Mythic. |
| **Playtime rewards** | Unlock at 5, 10, 20, 30, 45 and 60 minutes per session. |
| **Achievements** | 20 achievements, including collection-completion milestones. |
| **Boosts** | 2x Luck, 2x Cash, Fusion Speed and Dumpster Cooldown Reduction. They are timed, saved, and only tick down while you're online. |
| **Monetization** | 6 gamepasses (VIP, 2x Luck, 2x Cash, Auto Sell, Infinite Inventory, Fusion Master) and 5 dev products (4 cash packs and a Luck Crate). |
| **VIP** | Gold `[👑 VIP]` chat tag, +25% luck, and an exclusive VIP Lounge with VIP dumpsters. |
| **Announcements** | Any Legendary, Mythic or Secret find triggers a large animated banner for every player plus a chat line, e.g. *"Timur discovered Cyber Dragon!"* |
| **Tutorial** | A step-by-step guide with a glowing beam that points at the next target. Steps advance from real server stats. |
| **UI** | Rounded corners, gradients, bouncy buttons, responsive scaling, mobile support, and gamepad support (auto-selection, B to close). |
| **Saving** | DataStore with session locking, retries, autosave every 60s, save on leave and BindToClose. |

---

## 📁 Folder structure

```
Roblox-Game/
├── default.project.json          Rojo project (maps src/ into the DataModel)
├── tools/
│   └── validate_data.py          Offline consistency tests for the data modules
└── src/
    ├── shared/                   → ReplicatedStorage.Shared
    │   ├── Config.lua            ALL balance numbers: rarities, zones, upgrades,
    │   │                         boosts, gamepasses, products, daily/playtime rewards
    │   ├── Formulas.lua          Shared progression math (luck, capacity, costs…)
    │   ├── Remotes.lua           The 3 remotes (Request / Sync / Signal)
    │   ├── Util.lua              Number/time formatting, table helpers
    │   └── Data/
    │       ├── Items.lua         Item database (170 items)
    │       ├── FusionRecipes.lua Fusion database (57 recipes, O(1) lookup)
    │       ├── Quests.lua        Main / Daily / Weekly quest database
    │       └── Achievements.lua  Achievement database
    ├── server/                   → ServerScriptService.Server (Script)
    │   ├── init.server.lua       Bootstrap: requires, Init(), Start()
    │   └── Services/
    │       ├── DataService.lua          DataStore, session lock, autosave, replication
    │       ├── Router.lua               Request remote dispatch + rate limiting
    │       ├── WorldService.lua         Procedural map, dumpsters, stations, geometry
    │       ├── DumpsterService.lua      Search validation, loot, FX, Auto Collect
    │       ├── LootService.lua          Server-side weighted RNG
    │       ├── InventoryService.lua     Items, discoveries, favorites, settings
    │       ├── EconomyService.lua       Cash, selling, auto-sell, upgrades
    │       ├── FusionService.lua        Timed fusions (crash/leave safe)
    │       ├── ZoneService.lua          Unlocks, teleports, anti-noclip zone guard
    │       ├── QuestService.lua         Quest progress, daily/weekly rerolls
    │       ├── AchievementService.lua   Batched achievement checks
    │       ├── RewardService.lua        Reward grants, daily login, playtime
    │       ├── BoostService.lua         Timed boosts
    │       ├── MonetizationService.lua  Gamepasses + idempotent ProcessReceipt
    │       └── AnnouncementService.lua  Toasts, rare-find banners, tips
    └── client/                   → StarterPlayerScripts.Client (LocalScript)
        ├── init.client.lua       Bootstrap
        ├── Lib/
        │   ├── State.lua         Read-only mirror of server data
        │   ├── Net.lua           Request wrapper
        │   └── Signal.lua        Lightweight signal
        ├── UI/
        │   ├── Theme.lua         Colors + fonts
        │   ├── UIKit.lua         Component library (buttons, windows, grids…)
        │   └── ItemList.lua      Shared inventory filter/sort + toolbar
        └── Controllers/
            ├── UIController.lua     ScreenGuis, scaling, panels, keybinds
            ├── HUD.lua              Cash, menu, capacity, boosts
            ├── InventoryPanel.lua   Inventory grid + details + favorites
            ├── SellPanel.lua        Sell Selected / All / Duplicates
            ├── FusionPanel.lua      Fusion machine + Recipe Book
            ├── CollectionPanel.lua  Pokedex
            ├── ShopPanel.lua        Upgrades / Zones / Passes / Cash
            ├── QuestsPanel.lua      Quests / Daily / Playtime / Achievements
            ├── SettingsPanel.lua    Saved toggles
            ├── Notifications.lua    Toasts, item popups, banners, zone splash
            ├── WorldController.lua  Dumpster FX, cooldowns, gates, station prompts
            ├── Tutorial.lua         First-time guide
            ├── SoundController.lua  SFX + optional music
            └── ChatController.lua   VIP chat tag
```

---

## 🚀 Installation (step by step)

### Option A: Rojo (recommended)

1. Install **Roblox Studio** and **Rojo**: the [Rojo Studio plugin](https://rojo.space/docs/v7/getting-started/installation/) plus the CLI (`aftman add rojo-rbx/rojo`, or download it from the Rojo releases page).
2. Clone this repository.
3. In a terminal in the repo folder, run:
   ```bash
   rojo serve
   ```
4. In Studio, create a new **Baseplate** place.
5. Open the **Rojo** plugin tab and click **Connect**. The scripts sync into the place.
6. Go to **Home → Game Settings → Security** and enable **Enable Studio Access to API Services**. Without it, saving falls back to in-memory mode in Studio and prints a warning.
7. Press **Play**. The server removes the default baseplate and builds the whole map.
8. Publish the place (**File → Publish to Roblox**).

To build a place file instead: `rojo build -o DumpsterFusion.rbxlx`.

### Option B: Manual copy (no Rojo)

Recreate this hierarchy in Studio. Script names must match exactly.

| Studio location | Type | Source |
|---|---|---|
| `ReplicatedStorage/Shared` | Folder | |
| `ReplicatedStorage/Shared/Config`, `Formulas`, `Remotes`, `Util` | ModuleScript | `src/shared/*.lua` |
| `ReplicatedStorage/Shared/Data` | Folder | |
| `ReplicatedStorage/Shared/Data/Items`, `FusionRecipes`, `Quests`, `Achievements` | ModuleScript | `src/shared/Data/*.lua` |
| `ServerScriptService/Server` | **Script** | `src/server/init.server.lua` |
| `ServerScriptService/Server/Services` | Folder | |
| `ServerScriptService/Server/Services/<Name>` | ModuleScript (×15) | `src/server/Services/<Name>.lua` |
| `StarterPlayer/StarterPlayerScripts/Client` | **LocalScript** | `src/client/init.client.lua` |
| `.../Client/Lib`, `.../Client/UI`, `.../Client/Controllers` | Folder | |
| `.../Client/Lib/<Name>` etc. | ModuleScript | `src/client/<Folder>/<Name>.lua` |

Then follow steps 6–8 above. Also set `Workspace.StreamingEnabled = false`: the game references dumpster models across the client/server boundary.

### Setting up monetization

1. Create the gamepasses and developer products in the **Creator Dashboard** (Monetization tab of your experience).
2. Paste their IDs into `src/shared/Config.lua` under `Config.GamePasses[...].Id` and `Config.DevProducts[...].Id`, and update the `Price` fields so the shop shows the right Robux price.
3. While an ID is still `0`, buying it **in Studio** is simulated for free, so every pass and product can be tested before you create it. In a live server, unconfigured items show an error instead.

### Chat tags

The VIP tag and chat announcements use **TextChatService**, which is the default for new places. If your place uses the legacy chat, switch `TextChatService.ChatVersion` to `TextChatService`.

---

## 🧩 Extending the game

**Add an item.** Add a line to a pool in `src/shared/Data/Items.lua`:
```lua
{ "rusty_spoon", "Rusty Spoon", "Common", "🥄" },
```
Pools are indexed once when the module loads, so thousands of items are fine. Once an item ID has shipped, never rename it: it is the key stored in player saves.

**Add a fusion recipe.** Add a line to `src/shared/Data/FusionRecipes.lua`. Ingredient order doesn't matter:
```lua
{ "rusty_spoon", "microwave", "sparky_spoon" },
```

**Add a quest.** Append it to `Main`, `Daily` or `Weekly` in `src/shared/Data/Quests.lua`. The types are `Search`, `Discover`, `Fuse`, `Sell`, `EarnCash`, `FindRarity` and `UnlockZone`.

**Add a zone.** Append it to `Config.Zones` and add a matching item pool. You can also add a decorator in `WorldService` (`Decorators[zone.Key]`); without one, the zone still builds with its ground, gate, dumpsters and stations.

**Use a hand-built map.** Put a Folder named `Map` in Workspace and procedural generation is skipped. Tag dumpster models `Dumpster` and give them a `ZoneId` number attribute (`-1` = VIP). Tag stations `SellStation` / `FusionStation`. Search prompts are created automatically if missing.

**Use real item images.** Set the optional 6th field of an item entry to `"rbxassetid://…"` and the UI shows that image instead of the emoji.

**Validate the data** after edits (requires the [`luau` CLI](https://github.com/luau-lang/luau/releases)):
```bash
python3 tools/validate_data.py path/to/luau
```
It checks that every zone pool covers every rarity, every fusion item has a recipe, all reward items and boosts exist, odds are correct, and more.

---

## 🔒 Architecture & security

- **Server-authoritative.** The client never sends item IDs it "found", prices, cash or counts. It only sends *requests* such as "sell these stacks" or "fuse A + B". The server checks every request against its own copy of the player's data.
- **Three remotes only.** `Request` (a RemoteFunction for every UI action), `Sync` (server → client data replication) and `Signal` (server → client events). Dumpster searches use ProximityPrompts, which the server listens to directly, so no remote can be spoofed to trigger them.
- **Search validation.** Checks distance, zone ownership (or VIP), the per-dumpster cooldown, a global rate cap, backpack space, and that the prompt was actually held long enough, using server-side `PromptButtonHoldBegan` timestamps.
- **Zone guard.** Gates only lose collision on the unlocking player's client. The server also checks every character once per second and returns anyone standing in a locked zone or the VIP room.
- **Rate limiting.** A token bucket per player (12 requests/second). Handlers run in `pcall`, so errors never reach the client.
- **Purchases.** `ProcessReceipt` is idempotent: PurchaseIds are stored in the save, and the profile is saved *before* `PurchaseGranted` is returned.
- **No lost items.** A fusion in progress is stored in the save and granted on the next join if the player leaves mid-fusion.
- **Session locking.** Stops item duplication when a player hops between servers quickly.

### Performance

- Replication is batched: services mark keys dirty, and changed keys are flushed to each client at most 10 times per second.
- Boost timers tick on the server once per second but count down locally on the client, so they cost no network traffic.
- Achievement checks are queued and batched twice per second.
- Auto Collect only scans dumpsters in the player's current zone.
- Grids reuse pooled cells instead of recreating hundreds of GUI objects.
- Lid animations, particles and sounds run on each client (no server tweens).

---

## 🎮 Controls

| Action | Keyboard | Gamepad | Mobile |
|---|---|---|---|
| Search / use station | Hold **E** | Hold **X** | Tap-and-hold the prompt |
| Inventory | **F** | **Y** | 🎒 button |
| Collection | **C** | **D-Pad ↑** | 📖 button |
| Quests | **Q** | **D-Pad ←** | 📜 button |
| Shop | **G** | **D-Pad →** | 🛒 button |
| Close panel | **Esc** | **B** | ✕ button |

---

## 📝 Notes

- **Icons** are emoji, so the game works with zero asset uploads. Add `Image` IDs to items whenever you have art.
- **Sounds** use built-in `rbxasset://sounds/...` files. Replace them in `Config.Sounds` with Creator Store audio for a more polished feel. Background music is optional (`Config.MusicId`).
- **Balance.** Every number is in `Config.lua`: zone costs, rarity values, upgrade growth and reward sizes.
