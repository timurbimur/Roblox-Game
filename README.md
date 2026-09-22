# Spin a Brainrot

A Roblox gacha game: roll a dice, watch the odds, land on a "brainrot," and
equip the ones you collect as 3D companions that follow your character.

## How it works

- **Spin** — Click SPIN. The server rolls a weighted random rarity, then a
  random brainrot within that rarity, and tells your client the result. The
  dice on screen just plays a rolling animation while you wait; it's cosmetic
  flavor, not the actual RNG (all real rolls happen server-side so results
  can't be predicted or manipulated from the client).
- **Odds panel** — top-left panel lists every rarity tier and its live drop
  percentage, computed directly from `RarityConfig.lua`'s weights.
- **Inventory / Equip** — "BRAINROTS" button (top-right) opens your
  collection. Equip up to 3 at once; equipped brainrots spawn as 3D models
  that orbit your character in the world, visible to other players.
- **Persistence** — inventory and loadout are saved per-player via
  `DataStoreService`.

## Project layout (Rojo)

```
default.project.json                         -- Rojo project / Roblox instance tree
src/ReplicatedStorage/Modules/
  RarityConfig.lua                            -- rarity tiers, weights, colors
  BrainrotConfig.lua                          -- the full brainrot roster
src/ServerScriptService/Server/
  DataService.lua                             -- DataStore load/save
  SpinService.lua                             -- weighted RNG, spin/equip remotes
  EquipService.lua                            -- spawns/orbits equipped models
  ModelFactory.lua                            -- builds/clones brainrot 3D models
  Main.server.lua                             -- boots the above
src/StarterPlayer/StarterPlayerScripts/Client/
  UIController.lua                            -- builds all UI in code
  SpinController.lua                          -- dice animation + result reveal
  InventoryController.lua                     -- collection grid, equip/unequip
  Main.client.lua                             -- boots the above
```

Remotes (`RequestSpin`, `SpinResult`, `RequestEquip`, `RequestUnequip`,
`InventoryUpdated`) and the `ServerStorage/Assets/Models` folder are declared
directly in `default.project.json`, so Rojo creates them automatically.

## Running it

1. Install [Rojo](https://rojo.space/) — easiest via
   [Rokit](https://github.com/rojo-rbx/rokit): run `rokit install` in this
   repo (picks up the pinned version in `rokit.toml`).
2. `rojo serve` in this directory.
3. In Roblox Studio, install the Rojo plugin, open a new/blank place, and hit
   **Connect** in the Rojo plugin panel.
4. Press Play. Click SPIN.

(Alternatively `rojo build -o Game.rbxlx` produces a place file you can open
directly in Studio without the live server.)

## Adding real 3D models

Right now every brainrot without a real model gets an auto-generated
placeholder (a colored block with a name tag, tinted by rarity). To use a
real model instead:

1. Build/import your model in Studio (or insert a mesh from the toolbox).
2. Make sure it's a `Model` with a part set as `PrimaryPart` (or just any
   `BasePart` inside it — `ModelFactory` will pick one automatically if
   `PrimaryPart` isn't set).
3. Rename the model to match the brainrot's `Id` **exactly** as it appears in
   `BrainrotConfig.lua` (e.g. `ColosseoDraghino`).
4. Drag it into `ServerStorage > Assets > Models` and save/publish.

No code changes needed — `ModelFactory.Create` automatically clones your
model instead of generating a placeholder.

## Customizing brainrots & odds

- Add/remove/rename brainrots in `src/ReplicatedStorage/Modules/BrainrotConfig.lua`.
  Each entry needs a unique `Id`, a `Name`, a `Rarity` (must match a key in
  `RarityConfig.lua`), and a `Value`.
- Rebalance drop rates by editing the `Weight` numbers in
  `src/ReplicatedStorage/Modules/RarityConfig.lua`. Percentages in the UI are
  derived automatically — no need to recompute them by hand.
- Change the spin cooldown or equip slot count via `SPIN_COOLDOWN` in
  `SpinService.lua` and `EquipService.MaxSlots` in `EquipService.lua`.
