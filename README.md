# Unnamed TD Game — v0.1

As-of-yet unnamed maze-building tower defense made in Godot, mostly written with AI. It draws on Rogue Tower and Sir, We Have an Orc Problem.

A maze-building tower defense prototype for **Godot 4.7.2 stable**, written in GDScript. It has one open 40 × 24 map. Towers block tiles, so you build the maze yourself, and you can never fully seal the route. Waves are endless and generated per run, with seven enemy types. Clearing waves earns **diamonds**, which unlock a permanent skill tree: the Tesla Tower, tower upgrades, gold boosts, enemy nerfs and global buffs.

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
- **Panels scroll, never grow.** Each panel's content is inside a `ScrollContainer`. Too much content, or content too wide, gets a scrollbar instead of pushing into the board.
- **One exception: full-screen modal menus** (the skill tree, group `hud_modal`). They pause the game and swallow all input while open, so nothing behind them can be played.
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
| Enter build mode | **Build Basic (60)** or **Build Tesla (80)**. Tesla shows "(Skill Tree)" until unlocked. |
| Place tower | **Left-click** a highlighted tile (green = valid, red = invalid). Build mode stays on after placing, until you cancel or can't afford another tower. |
| Select a tower | **Left-click** a tower (outside build mode). Its range is shown and the upgrade/sell panel appears on the right. |
| Upgrade / sell | Upgrade and **Sell** buttons in the selection panel (upgrades appear once unlocked in the skill tree) |
| Cancel build mode / deselect | **Right-click**, **Esc**, the **Cancel Build** button, or click empty ground |
| Launch next wave | **Start Wave** (disabled while a wave is running) |
| Auto-start | **Auto-start waves** toggle: the next wave starts 3 s after the previous one is cleared. The countdown is shown on the toggle and pauses while the skill tree is open. Wave 1 is always started by you. The setting is saved. |
| Skill tree | **Skill Tree** button (any time). It also opens automatically after every 5th wave. Opening it pauses the game; **Continue** or **Esc** closes it. |
| New run | **Restart** (any time; picks a new run seed; diamonds and skills are kept) |
| Toggle fullscreen | **F11** |

## Rules

Tuning lives in:
- `scripts/game_config.gd`: economy, upgrades, wave sizes, health scaling, diamonds;
- `scripts/tower_types.gd`: tower stats;
- `scripts/enemy_types.gd`: enemy stats;
- `scripts/skill_tree.gd`: skills.

- Start with 200 gold and 10 lives (+5 with Fortify).
- Kills pay gold. Each cleared wave pays a gold bonus (30 + 5 per wave number) and **1 diamond**. Escaped enemies cost lives and pay nothing.
- **Endless:** there's no final wave. The run ends when lives reach 0; spawning then stops and only Restart works.
- A placement is rejected, at no charge, if it would:
  - go on the entrance or exit, an occupied tile, or a tile an enemy is on or walking into;
  - cut off the spawn → exit route;
  - cut off any in-flight enemy's next waypoint from the exit.

### Towers

| Tower | Look | Cost | Attack | Unique upgrade path |
|---|---|---|---|---|
| Basic | blue square | 60 | 15 damage to the **nearest** enemy within 112 px, every 0.8 s | **Armor piercing:** ignores armor, +4 damage per level |
| Tesla | purple hexagon | 80 | 12 damage to **every** enemy within 80 px, every 1.0 s (electric bolts) | **Static field:** bolts slow enemies 15% per level for 1.5 s |

### Diamonds and the skill tree (permanent)

Diamonds and unlocked skills are **saved** (`user://progress.json`) and carry over to every future run and every relaunch, so each run builds on the last. **Reset progress** in the skill tree wipes them; it needs a second click to confirm.

| Branch | Skills (diamond cost) |
|---|---|
| Root | **Tesla Tower (3)**: the first and only skill available at the start |
| Basic Tower | Basic Upgrades (3): Damage/Range/Hit speed paths → Armor Piercing (5): unique path |
| Tesla Tower | Tesla Upgrades (4): Damage/Range/Hit speed paths → Static Field (5): unique path |
| Gold | Bounty Hunter (3): +20% kill gold → Master Hunter (5): another +20%; War Chest (4): +50% wave bonus |
| Enemy nerfs | Frailty (4): enemies -10% health → Decay (6): another -10%; Cripple (5): enemies -10% speed |
| Permanent | Fortify (3): +5 lives → Sharpened Arsenal (5): towers +15% damage → Overclock (6): towers attack 15% faster |

**No tower can be upgraded until its type's upgrade skill is unlocked.** Each unique path needs its own skill on top of that.

### Waves

- Each wave is generated from the **run seed** (shown at the bottom of the right panel) and the wave number. Every run differs slightly, while the **Next** preview always matches the wave you get.
- Enemy count starts around 8 and grows by about 2 per wave, with ±10% variation, capped at 70.
- Enemy health grows **exponentially**: (1 + 0.1·(w-1)) × 1.10^(w-1), which is ×4.5 at wave 10, ×18 at 20 and ×62 at 30. Bounties grow 3% per wave. Every run eventually ends; a better maze, plus skills, pushes that point much further out.
- New types unlock as waves progress. A **Warlord** boss joins every 10th wave (1 at wave 10, 2 at 20, up to 3), with half the usual escort.

### Balance targets (checked by `tests/test_balance.gd`)

Scripted strategies in `tests/bots.gd` play real waves on fixed seeds:

| Strategy | Typical result |
|---|---|
| Random tower placement | defeated by wave 2-3 (test: by wave 5) |
| Towers lining the straight route, no maze, no skills | defeated around wave 19-20 (test: by wave 25) |
| Tight serpentine maze (1-wide corridors) with skills and upgrades | survives to about wave 36-37 (test: survives 30) |

To print these numbers after tuning, run `tests/balance_report.gd` (see Tests).

### Enemy types

| Enemy | Look | Speed | Base HP | Bounty | Trait | From wave |
|---|---|---|---|---|---|---|
| Grunt | red diamond | 60 | 45 | 12 | Baseline walker | 1 |
| Runner | yellow triangle | 100 | 28 | 10 | Fast but fragile | 3 |
| Swarmling | small green dot | 78 | 14 | 4 | Arrives in packs of 3-5 | 4 |
| Tank | purple square, grey ring | 36 | 150 | 28 | Armor: every hit does 4 less (minimum 1); costs 2 lives | 5 |
| Mender | teal hexagon, cyan health bar | 55 | 70 | 18 | Regenerates 5% of max HP per second | 7 |
| Splitter | orange ring | 50 | 80 | 15 | Splits into 3 Swarmlings where it dies | 8 |
| Warlord (boss) | large dark-red star, grey ring | 34 | 250 | 150 | Armor 3, slow regeneration, costs **5 lives** | every 10th |

Slowed enemies show a blue ring.

### Upgrades and selling

- Upgrades must first be unlocked per tower type in the skill tree.
- Each tower can take **one** upgrade path, then level it up to 3 times. The other paths disappear from its panel once one is chosen.
  - **Damage:** Basic +9 per level (15 → 42); Tesla +5 per level (12 → 27).
  - **Range:** Basic +24 px per level (112 → 184); Tesla +16 px per level (80 → 128).
  - **Hit speed:** cooldown ×0.75 per level.
  - **Unique:** Armor piercing (Basic) or Static field (Tesla).
- Upgrades cost 50, then 80, then 120. Upgraded towers show colored pips and fire colored beams.
- **Selling** refunds 50% of everything spent on the tower, build plus upgrades. It works mid-wave; enemies immediately re-route through the freed tile.

## Project layout

```text
project.godot             main scene, 1600x900 window, canvas_items stretch, Compatibility renderer
scenes/main.tscn          Main → WaveManager, WindowFit, HUD/UILayout/Root(LeftColumn(BoardArea/Board(Towers, Enemies), BottomPanel), RightPanel)
scenes/enemy.tscn         Node2D + enemy.gd (drawn in code)
scenes/tower.tscn         Node2D + tower.gd (drawn in code)
scenes/skill_tree_menu.tscn  Control + skill_tree_menu.gd (full-screen modal)
scripts/game_config.gd    tuning constants only (class_name GameConfig)
scripts/tower_types.gd    tower type definitions: Basic, Tesla
scripts/skill_tree.gd     skill definitions, prerequisites, unlocked state and summed effects
scripts/skill_tree_menu.gd  modal skill tree UI built from the skill data
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
  - **enemy types:** distinct looks and stats, every trait;
  - **flow:** 30 consecutive waves with exact gold accounting and the 5-wave skill popup;
  - **towers:** upgrade rules, 50% refunds, mid-wave sell rerouting, selection UI.
- **test_skills:**
  - **skill data:** complete, every skill reachable, unique menu positions;
  - **unlocks:** Tesla is the only first skill and costs 3; 1 diamond per wave; the popup after waves 5 and 10; the menu pauses the game and swallows board clicks and Esc; menu buttons unlock skills; prerequisite and cost rules;
  - **persistence:** survives Restart and relaunch, corrupt or tampered save files are handled safely, progress reset with a confirm click;
  - **towers:** Tesla locked/unlocked, hits every enemy in its small radius, respects armor; per-type upgrade gating; unique paths; Armor Piercing; Static Field slow;
  - **boosts and nerfs:** gold boosts, enemy nerfs, permanent buffs;
  - **auto-start:** off by default, chains waves, waits for the skill tree, never runs after defeat, setting saved.
- **test_layout:**
  - the board area is exactly 1280×768;
  - no visible HUD element covers the board or leaves the view, in 11 extreme HUD states, real gameplay and the defeat screen;
  - panels scroll when overloaded;
  - the skill tree is the only allowed full-screen overlay.
- **test_stability:**
  - 6,000 randomized steps (both tower types, sells, every upgrade path, skill unlocks, opening and closing the skill tree, auto-start toggling, waves), checking every game invariant every 5 steps;
  - a 20-wave run by the good bot with invariant checks;
  - 25 mid-wave restarts.
- **test_balance:** random placement loses by wave 5; the no-maze line loses by wave 25; the good maze survives 30 waves.
