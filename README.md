# Unnamed TD Game — v0.1

As-of-yet unnamed maze-building tower defense made in Godot, mostly written with AI. It draws on Rogue Tower and Sir, We Have an Orc Problem.

A maze-building tower defense prototype for **Godot 4.7.2 stable**, written in GDScript. It has one open 40 × 24 map. Towers block tiles, so you build the maze yourself, and you can never fully seal the route. Waves are endless and generated per run, with eight enemy types. Enemies carry stacked **shield, armor and health** layers, and three tower types each deal different damage to each layer. Clearing waves earns **diamonds**, which unlock a permanent 33-skill tree.

## Running

1. Open `project.godot` in Godot 4.7.2 (Project Manager → Import). Let the editor finish importing.
2. Press **F5**. The main scene is `res://scenes/main.tscn`.

### Window size and resizing

The game draws at a fixed 1600×900 logical resolution and scales to whatever size the window is. If the window isn't 16:9, you get black bars, and the whole game always stays visible and centered.

- **On startup** the window shrinks to fit your screen if needed (up to 92% of the usable area, never bigger than 1600×900) and is centered.
- **You can resize** the window freely; the minimum is 800×450. When you finish dragging, the window shrinks if it no longer fits the screen and re-centers.
- **F11** toggles fullscreen.

**If the game looks cropped or shifted left when you press F5:** Godot 4.4+ can run the game *embedded* in the editor's **Game** tab, and the editor controls that size. Either:
- in the Game tab's toolbar, set the embedded size mode to **Keep Aspect** (or **Stretch**) rather than the fixed project-settings size, or
- turn off **Embed Game on Next Play** in the Game tab so the game opens in its own window, where the automatic fitting above applies.

### Screen layout (rules for future changes)

The screen is a fixed 1600×900 layout: the 1280×768 board in the top-left, a 320 px panel on the right and a 132 px strip below. **UI never covers the board.** This is guaranteed by the structure:

- **The board sits inside the UI layout.** The Board node lives inside `BoardArea`, a fixed 1280×768 slot in the same HBox/VBox containers as the panels. Containers can't overlap their siblings, so a panel can't land on a tile.
- **Nothing moves between waves.** Every HUD element is a fixed-size slot: one-line labels end with "…" instead of wrapping, multi-line labels have a fixed line count, and nothing is shown or hidden during play. The selection card is always present, with a placeholder when no tower is selected, and unavailable upgrades are disabled in place rather than hidden. `test_layout.gd` checks that no HUD control moves or resizes across 14 states.
- **Panels scroll, never grow.** Each panel's content is inside a `ScrollContainer`. Too much content, or content too wide, gets a scrollbar instead of pushing into the board.
- **One exception: full-screen modal menus** (the skill tree and the "Are you sure?" dialog, group `hud_modal`). They pause the game and swallow all input while open, so nothing behind them can be played.
- **Scripts find HUD nodes by unique name** (`%CurrencyLabel`, `%Board`, …), so moving nodes around in the scene doesn't break code.
- **Guards:**
  - `tests/test_layout.gd` fails if any visible UI element overlaps the board or leaves the 1600×900 view. It checks extreme states and simulates 40 extra rows of future UI.
  - In debug builds, the HUD logs an error if a panel ever overlaps or pushes the board area.

When adding UI:
- Put it **inside `RightPanel` or `BottomPanel`'s `VBox`**.
- Give labels **autowrap** and buttons **clip text**.
- Mark a node with the `hud_passthrough` group only if it is a pure, invisible layout container.
- Run `test_layout.gd`.

## Controls

| Action | Control |
|---|---|
| Enter build mode | **Basic Tower / Tesla Tower / Cannon** buttons in the BUILD card. Locked towers say "(Skill Tree)". The active build button is highlighted gold. |
| Place tower | **Left-click** a highlighted tile (green = valid, red = invalid). Build mode stays on until you cancel or can't afford another tower. |
| Select a tower | **Left-click** a tower (outside build mode). The SELECTED TOWER card shows its damage per layer and its upgrades. |
| Upgrade / sell | The four upgrade buttons and **Sell** in the SELECTED TOWER card |
| Cancel build mode / deselect | **Right-click**, **Esc**, **Cancel build**, or click empty ground |
| Launch next wave | **Start Wave** |
| Auto-start | **Auto-start waves** toggle: the next wave starts 3 s after the previous one is cleared. The countdown is shown on the toggle and pauses while any menu is open. Wave 1 is always started by you. The setting is saved. |
| Skill tree | **Skill Tree** button (any time). It also opens after every 5th wave. The game pauses while it's open; **Continue** or **Esc** closes it. |
| New run | **Restart** asks "Are you sure?" first; **Esc** or **Cancel** backs out. Diamonds and skills are kept. |
| Toggle fullscreen | **F11** |

## Rules

Tuning lives in:
- `scripts/game_config.gd`: economy, upgrades, wave sizes and speed, health scaling, diamonds;
- `scripts/tower_types.gd`: tower stats and damage per layer;
- `scripts/enemy_types.gd`: enemy stats and layers;
- `scripts/skill_tree.gd`: skills.

- Start with 200 gold and 10 lives (more with skills).
- Kills pay gold. Each cleared wave pays a gold bonus (30 + 5 per wave number) and **1 diamond**. Escaped enemies cost lives and pay nothing.
- **Endless:** the run ends when lives reach 0.
- A placement is rejected, at no charge, if it would:
  - go on the entrance or exit, an occupied tile, or a tile an enemy is on or walking into;
  - cut off the spawn → exit route;
  - cut off any in-flight enemy's next waypoint from the exit.

### Health layers and damage types

Enemies have up to three stacked bars above them:
- **purple shield** on top;
- **white armor** below it;
- **green health** at the bottom.

**Only the top non-empty bar takes damage**, and damage beyond what that bar has left is lost; it never spills into the next bar. An enemy dies when its health bar is empty. Every tower has a separate damage value against each layer, so mixing towers matters.

| Tower | Look | Cost | Attack | Damage (health / armor / shield) | Unique upgrade path |
|---|---|---|---|---|---|
| Basic | blue square | 60 | nearest enemy within 112 px, every 0.8 s | 15 / 8 / 6 (all-rounder) | **Piercing:** +100% armor damage per level |
| Tesla | purple hexagon | 80 | **every** enemy within 80 px, every 1.0 s | 10 / 3 / **24** (shield shredder) | **Static field:** slows 15% per level for 1.5 s |
| Cannon | orange turret | 110 | nearest enemy within 128 px, every 1.6 s | 20 / **48** / 4 (armor cracker) | **Shrapnel:** 50% splash damage, radius 40 → 72 px |

### Upgrades and selling

- **Unlocking:** a tower type's upgrades unlock in the skill tree, and each unique path needs its own skill.
- **One path per tower:** each tower takes one path, up to level 3, or level 4 with that type's Mastery skill. Upgrades cost 50, 80, 120, then 180.
- **What each path does:**
  - **Damage:** every damage type +60% per level.
  - **Range:** +24 px per level (+16 px for Tesla).
  - **Speed:** cooldown ×0.75 per level.
  - **Unique:** Piercing, Static field or Shrapnel (see the tower table).
- **Selling** refunds 50% of everything spent on the tower (75% with Salvage). It works mid-wave; enemies re-route through the freed tile immediately.

### Diamonds and the skill tree (permanent)

Diamonds and unlocked skills are **saved** (`user://progress.json`) and carry over to every future run and relaunch. **Reset progress** in the skill tree wipes them after an "Are you sure?" dialog. If a future update reorganizes the tree, any saved skill that no longer fits is **refunded** rather than lost.

There are 33 skills in 7 branches. **Costs rise with each tier**, roughly 3-5 → 6-7 → 10 → 15-16 → 22-24 diamonds. The root is the **Tesla Tower (3)**, the only skill available at the start.

| Branch | Skills, in tier order (cost) |
|---|---|
| Basic | Basic Upgrades (3) → Armor Piercing (6) → Veteran Crews: Basic +25% damage (10) → Basic Mastery: level 4 (16) |
| Tesla | Tesla Upgrades (4) → Static Field (6) → Capacitors: Tesla +25% damage (10) → Tesla Mastery (16) |
| Cannon | **Cannon tower (5)** → Cannon Upgrades (6) → Shrapnel (10) → Cannon Mastery (16) |
| Gold | Bounty Hunter: +20% kill gold (3) → War Chest: +50% wave bonus (6) → Master Hunter: +20% (10) → Salvage: 75% refunds (15) → Head Start: +150 starting gold (22) |
| Damage Types | Hollow Points: +20% vs health (4) → Armor Breaker: +30% vs armor (7) → Shield Breaker: +30% vs shields (10) → Focus Fire: +15% all (16) → Annihilator: +25% all (24) |
| Enemy Nerfs | Frailty: -10% health (4) → Cripple: -10% speed (6) → Decay: -10% health (10) → Rust: -25% armor (15) → Dampening Field: -25% shield (22) |
| Permanent | Fortify: +5 lives (3) → Sharpened Arsenal: +15% damage (6) → Overclock: +15% attack speed (10) → Bastion: +5 lives (15) → Diamond Mine: +1 diamond every 5th wave (22) |

### Waves

- Each wave is generated from the **run seed** and the wave number. The **Next wave** preview always matches what you get.
- **Enemy count:** starts around 8 and grows about 2 per wave. **Past wave 30 it grows much faster**, adding 0.15 × (wave - 30)², up to 320 per wave. On average: wave 40 has 57, wave 60 has 142, wave 80 has 282.
- **Spawn speed** rises every wave (intervals × 1/(1 + 0.03·(wave-1))). Counts grow faster still, so **later waves still last longer**: about 29 s of spawning at wave 40, 53 s at 60, 83 s at 80.
- **Enemy health:** every layer grows exponentially, (1 + 0.1·(w-1)) × 1.10^(w-1).
- **Unlocks:** new types unlock as waves progress. A **Warlord** boss (shield + armor + health) joins every 10th wave, with half the usual escort.

### Enemy types

| Enemy | Look | Speed | Layers (base) | Bounty | Trait | From wave |
|---|---|---|---|---|---|---|
| Grunt | red diamond | 60 | health 45 | 12 | Baseline walker | 1 |
| Runner | yellow triangle | 100 | health 28 | 10 | Fast but fragile | 3 |
| Swarmling | small green dot | 78 | health 14 | 4 | Arrives in packs of 3-5 | 4 |
| Tank | purple square | 36 | armor 60 + health 90 | 28 | Heavy armor: bring Cannons; costs 2 lives | 5 |
| Mender | teal hexagon | 55 | health 70 | 18 | Regenerates 5% health per second | 7 |
| Splitter | orange ring | 50 | health 80 | 15 | Splits into 3 Swarmlings | 8 |
| Aegis | blue pentagon | 56 | shield 75 + health 50 | 20 | Energy shield: bring Teslas | 11 |
| Warlord (boss) | large dark-red star | 34 | shield 120 + armor 120 + health 180 | 150 | Slow regeneration; costs **5 lives** | every 10th |

Slowed enemies show a blue ring.

### Balance targets (checked by `tests/test_balance.gd`)

| Strategy (scripted bots in `tests/bots.gd`) | Typical result |
|---|---|
| Random tower placement | defeated on wave 2 (test: by wave 5) |
| Towers lining the straight route, no maze, no skills | defeated on waves 16-17 by shields and armor (test: by wave 25) |
| Tight serpentine maze with Teslas, Cannons, skills and upgrades (fresh save) | reaches waves 31-35, where the late-wave swarm begins (test: survives 30) |

Permanent skills from earlier runs push this further. Run `tests/balance_report.gd` to print these numbers after tuning.

### Performance

With a 414-tower maze on wave 70, the game logic takes about 7 ms per frame (measured headless). Tower target scans are staggered by tile, and the HUD refreshes at most once per frame.

## Project layout

```text
project.godot             main scene, 1600x900 window, canvas_items stretch, Compatibility renderer
scenes/main.tscn          Main → WaveManager, WindowFit, HUD/UILayout/Root(LeftColumn(BoardArea/Board(Towers, Enemies), BottomPanel), RightPanel)
scenes/enemy.tscn         Node2D + enemy.gd (drawn in code)
scenes/tower.tscn         Node2D + tower.gd (drawn in code)
scenes/skill_tree_menu.tscn  Control + skill_tree_menu.gd (full-screen modal)
scripts/game_config.gd    tuning constants only (class_name GameConfig)
scripts/tower_types.gd    tower type definitions: Basic, Tesla, Cannon (damage per layer)
scripts/skill_tree.gd     skill definitions, prerequisites, unlocked state and summed effects
scripts/skill_tree_menu.gd  modal skill tree UI built from the skill data
scripts/confirm_dialog.gd "Are you sure?" modal (Restart, Reset progress)
scripts/ui_theme.gd       shared visual theme: colors, card/button/label styles
scripts/progress_store.gd permanent progress + settings saved as JSON (user://progress.json)
scripts/enemy_types.gd    enemy type definitions: stats, looks, traits, unlock wave
scripts/wave_generator.gd seeded endless wave generation and scaling formulas
scripts/main.gd           currency, lives, game state, purchases, upgrades, sales, selection, defeat, restart
scripts/board.gd          grid, AStarGrid2D, coordinate helpers, placement validation, rendering, clicks
scripts/enemy.gd          cell-center movement, safe rerouting, armor/regen/split, died/reached_exit (once each)
scripts/tower.gd          targeting, cooldown, immediate-hit attack, upgrade path/levels, sell value
scripts/wave_manager.gd   wave queue, spawn timer, unresolved-enemy count (incl. split children), completion
scripts/hud.gd            labels, buttons → intent signals, next-wave preview, selection panel, messages
scripts/window_fit.gd     fits/centers the OS window on its screen, re-centers after resize, F11 fullscreen
tests/test_base.gd        shared headless test harness and game-invariant checker
tests/test_pathfinding.gd pathfinding, placement, movement, combat, defeat/restart
tests/test_gameplay.gd    wave generator, enemy types and traits, endless flow, upgrades, selling, selection
tests/test_stability.gd   randomized fuzzing and long-run simulations
tests/test_layout.gd      HUD layout guard: nothing may cover the board or leave the view
tests/test_skills.gd      diamonds, skill tree, persistence, Tesla, gated/unique upgrades, auto-start
tests/test_balance.gd     balance guard using scripted bots
tests/bots.gd             scripted strategies (good maze / random / no-maze) used by balance checks
tests/balance_report.gd   tuning tool: prints how far each strategy gets
tests/run_all.sh          runs everything; fails on any test failure OR any script error
```

## Tests

Run everything from the project root with one command (pass your Godot executable; on Windows use Git Bash or WSL, or run the individual commands below):

```sh
tests/run_all.sh path/to/godot      # ~1.5 min
```

`run_all.sh` imports the project, runs a 180-frame startup check, then every suite. It fails if any check fails **or if any script error appears in the output**, so errors inside signal handlers can't slip through. Individual commands:

```sh
godot --headless --editor --path . --quit          # import once (builds the global class cache)
godot --headless --path . --quit-after 180         # runtime smoke test
godot --headless --path . --script res://tests/test_pathfinding.gd
godot --headless --path . --script res://tests/test_gameplay.gd
godot --headless --path . --script res://tests/test_skills.gd
godot --headless --path . --script res://tests/test_layout.gd
godot --headless --path . --script res://tests/test_stability.gd
godot --headless --path . --script res://tests/test_balance.gd
godot --headless --path . --script res://tests/balance_report.gd   # tuning report, not pass/fail
```

Tests never touch your real save file.

- **test_pathfinding:**
  - every spec §10 case (routes, detours, no solid or diagonal steps, the final-gap rejection, reserved/out-of-bounds/occupied cells, enemy waypoints, unchanged state after invalid placement);
  - purchase economy and mid-wave rerouting;
  - the exactly-once death signal, tower range and cooldown;
  - endless-wave defeat → restart;
  - window-fit sizing.
- **test_gameplay:**
  - **generator:** reproducible per seed, varies between seeds; 300 waves × 3 seeds have valid sizes, unlocked types, finite stats and rising difficulty; boss schedule;
  - **late waves:** past wave 30 they get much bigger, spawn faster, and still last longer;
  - **enemy types and layers:** distinct looks and stats; only the top layer takes damage and nothing spills over; the boss peels shield → armor → health; every trait;
  - **flow:** 30 consecutive waves with exact gold accounting and the 5-wave skill popup;
  - **towers:** upgrade rules, 50% refunds, mid-wave sell rerouting, selection UI.
- **test_skills:**
  - **skill data:** complete, every skill reachable, unique menu positions;
  - **unlocks:** Tesla is the only first skill and costs 3; 1 diamond per wave; the popup after waves 5 and 10; the menu pauses the game and swallows board clicks and Esc; menu buttons unlock skills; prerequisite and cost rules;
  - **persistence:** survives Restart and relaunch, corrupt or tampered save files are handled safely, progress reset with a confirm click;
  - **towers:** Tesla locked/unlocked, hits every enemy in its small radius, respects armor; per-type upgrade gating; unique paths; Armor Piercing; Static Field slow;
  - **boosts and nerfs:** gold boosts, enemy nerfs, permanent buffs;
  - **auto-start:** off by default, chains waves, waits for the skill tree, never runs after defeat, setting saved;
  - **expanded tree:** 30+ skills with costs rising by tier; Restart and Reset progress require confirmation (Cancel and Esc back out); Cannon armor damage and Shrapnel splash; damage-type and per-tower skills; Mastery level 4; Salvage, Head Start, Diamond Mine; armor and shield nerfs; refunds for skills a tree change made unreachable.
- **test_layout:**
  - the board area is exactly 1280×768;
  - no visible HUD element covers the board or leaves the view, in 11 extreme HUD states, real gameplay and the defeat screen;
  - panels scroll when overloaded;
  - full-screen modals (skill tree, confirmations) are the only allowed overlays;
  - **no HUD button or label moves or resizes** across 14 states (selecting each tower type, upgrading, build mode, waves, auto-start countdown, huge numbers, long messages, defeat, restart).
- **test_stability:**
  - 6,000 randomized steps (both tower types, sells, every upgrade path, skill unlocks, opening and closing the skill tree, auto-start toggling, waves), checking every game invariant every 5 steps;
  - a 20-wave run by the good bot with invariant checks;
  - 25 mid-wave restarts.
- **test_balance:** random placement loses by wave 5; the no-maze line loses by wave 25; the good maze survives 30 waves.
