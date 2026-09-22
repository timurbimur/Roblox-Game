# Spin a Brainrot

A Roblox gacha game: spin to reveal a random "brainrot," watch the live odds,
and equip the ones you collect so they hop along behind your character.

## How it works

- **Spin** — Click SPIN!. The server rolls a weighted random rarity, then a
  random brainrot within that rarity, and returns the result directly (via a
  RemoteFunction, so the client always gets a real response or a real error --
  never a silent no-op). The reveal box cycles rapidly through random
  candidate names/rarities while waiting, slot-machine style, then lands on
  the true result; that cycling is cosmetic flavor only -- all real rolls
  happen server-side so results can't be predicted or manipulated from the
  client.
- **Odds panel** — top-left panel lists every rarity tier and its live drop
  percentage, computed directly from `RarityConfig.lua`'s weights.
- **Inventory / Equip** — "BRAINROTS" button (top-right) opens your
  collection, showing a real 3D thumbnail of each brainrot plus its "1 in N"
  odds. Equip up to 3 at once; equipped brainrots spawn as 3D models that hop
  along behind your character, spread out side by side, with a floating
  name/rarity/odds tag above them -- visible to other players too.
- **Persistence** — inventory and loadout are saved per-player via
  `DataStoreService`.

## Project layout (Rojo)

```
default.project.json                         -- Rojo project / Roblox instance tree
src/ReplicatedStorage/Modules/
  RarityConfig.lua                            -- rarity tiers, weights, colors
  BrainrotConfig.lua                          -- the full brainrot roster
  BrainrotVisuals.lua                         -- model creation, odds text, world tags, thumbnails
  RemoteHelpers.lua                           -- client-side InvokeServer-with-timeout
src/ServerScriptService/Server/
  DataService.lua                             -- DataStore load/save
  SpinService.lua                             -- weighted RNG, Spin/Equip/Unequip RemoteFunctions
  EquipService.lua                            -- spawns/hops equipped companion models
  Main.server.lua                             -- boots the above; broadcasts startup errors
src/StarterPlayer/StarterPlayerScripts/Client/
  UIController.lua                            -- builds all UI in code
  SpinController.lua                          -- reveal-reel animation + result handling
  InventoryController.lua                     -- collection grid, equip/unequip
  Main.client.lua                             -- boots the above; on-screen debug/error display
```

Remotes (`SpinFunction`, `EquipFunction`, `UnequipFunction`, `InventoryUpdated`,
`ServerLog`) and the `ReplicatedStorage/Assets/Models` folder are declared
directly in `default.project.json`, so Rojo creates them automatically.

## Running it

1. Install [Rojo](https://rojo.space/) — easiest via
   [Rokit](https://github.com/rojo-rbx/rokit): run `rokit install` in this
   repo (picks up the pinned version in `rokit.toml`).
2. `rojo serve` in this directory.
3. In Roblox Studio, install the Rojo plugin (`rojo plugin install` also
   works), open a place, and hit **Connect** in the Rojo plugin panel.
4. Press Play. Click SPIN!.

(Alternatively `rojo build -o Game.rbxlx` produces a place file you can open
directly in Studio without the live server -- but you'll need to rebuild it
after every code change, so live sync via `rojo serve` + Connect is much
less friction for ongoing development.)

## Adding real 3D models

Every brainrot without a real model gets an auto-generated placeholder (a
colored block with a face, tinted by rarity). To use a real model instead:

1. Build/import your model in Studio (or insert one from the Toolbox).
2. Make sure it's a `Model` with a part set as `PrimaryPart` (or just any
   `BasePart` inside it -- `BrainrotVisuals.CreateModel` will pick one
   automatically if `PrimaryPart` isn't set).
3. Drag it into `ReplicatedStorage > Assets > Models`.
4. If the model's own name matches a brainrot's `ModelName` field in
   `BrainrotConfig.lua` exactly, it's picked up automatically -- no rename or
   code change needed. (`ModelName` exists specifically so a messy Toolbox
   model name never has to become the save-data `Id`, which must stay stable
   forever once players start collecting.)

**Important:** this folder lives in `ReplicatedStorage`, not `ServerStorage`
-- the client needs to read it directly to render inventory thumbnails, and
`ServerStorage` never replicates to clients.

## Customizing brainrots & odds

- Add/remove/rename brainrots in `src/ReplicatedStorage/Modules/BrainrotConfig.lua`.
  Each entry needs a unique `Id` (permanent save-data key -- never change an
  existing one), a `Name` (display text, freely editable), a `ModelName`
  (must exactly match the model's name in `ReplicatedStorage/Assets/Models`),
  a `Rarity` (must match a key in `RarityConfig.lua`), and a `Value`.
- Rebalance drop rates by editing the `Weight` numbers in
  `src/ReplicatedStorage/Modules/RarityConfig.lua`. Percentages in the UI (and
  every brainrot's "1 in N" odds) are derived automatically -- no need to
  recompute them by hand.
- Change the spin cooldown or equip slot count via `SPIN_COOLDOWN` in
  `SpinService.lua` and `EquipService.MaxSlots` in `EquipService.lua`.
- Tune the hop/follow feel (distance, spacing, bounce height/speed) via the
  constants at the top of `EquipService.lua`.

## Debug display

`Main.client.lua` currently renders a big red on-screen box for any client
crash, server rejection, or `InvokeServer` timeout, and `Main.server.lua`
broadcasts any server startup failure to every client immediately on join.
This is meant to be temporary scaffolding for early development -- once
things are stable, it's safe to strip out (or gate behind a debug flag) for
a real audience.
