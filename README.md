# Unnamed TD Game — v0.1

As-of-yet unnamed maze-building tower defense made in Godot, mostly written with AI. It draws on Rogue Tower and Sir, We Have an Orc Problem.

A maze-building tower defense prototype for **Godot 4.7.2 stable**, written in GDScript. It has one open 40 × 24 map. Towers block tiles, so you build the maze yourself, and you can never fully seal the route. Waves are endless and generated per run, with seven enemy types. Towers can be upgraded along one path or sold.

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
| Enter build mode | **Build Tower (60)** button |
| Place tower | **Left-click** a highlighted tile (green = valid, red = invalid). Build mode stays on after placing, until you cancel or can't afford another tower. |
| Select a tower | **Left-click** a tower (outside build mode). Its range is shown and the upgrade/sell panel appears on the right. |
| Upgrade / sell | **Upgrade Damage / Range / Hit speed** and **Sell** buttons in the selection panel |
| Cancel build mode / deselect | **Right-click**, **Esc**, the **Cancel Build** button, or click empty ground |
| Launch next wave | **Start Wave** (disabled while a wave is running) |
| New run | **Restart** (any time; picks a new run seed) |
| Toggle fullscreen | **F11** |

## Rules

Tuning lives in `scripts/game_config.gd` (economy, towers, upgrades, wave sizes), `scripts/enemy_types.gd` (enemy stats) and `scripts/wave_generator.gd` (scaling formulas).

- Start with 200 currency and 10 lives. A tower costs 60: range 112 px, 15 damage every 0.8 s. Shots hit instantly, shown by a short beam.
- Kills pay the enemy's bounty. Each cleared wave pays 30 + 5 per wave number. Escaped enemies cost lives and pay nothing.
- **Endless:** there's no final wave. The run ends when lives reach 0; spawning then stops and only Restart works.
- A placement is rejected, at no charge, if it would:
  - go on the entrance or exit, an occupied tile, or a tile an enemy is on or walking into;
  - cut off the spawn → exit route;
  - cut off any in-flight enemy's next waypoint from the exit.

### Waves

- Each wave is generated from the **run seed** (shown at the bottom of the right panel) and the wave number. Every run differs slightly, while the **Next** preview always matches the wave you get.
- Enemy count starts around 8 and grows by about 2 per wave, with ±10% variation, capped at 70.
- Enemy health scales with the wave (×2.9 at wave 10, ×9 at wave 25), and bounties grow 3% per wave.
- New types unlock as waves progress. A **Warlord** boss joins every 10th wave (1 at wave 10, 2 at 20, up to 3), with a smaller escort.

### Enemy types

| Enemy | Look | Speed | Base HP | Bounty | Trait | From wave |
|---|---|---|---|---|---|---|
| Grunt | red diamond | 60 | 45 | 12 | Baseline walker | 1 |
| Runner | yellow triangle | 100 | 28 | 10 | Fast but fragile | 3 |
| Swarmling | small green dot | 78 | 14 | 4 | Arrives in packs of 3-5 | 4 |
| Tank | purple square, grey ring | 36 | 150 | 28 | Armor: every hit does 6 less (minimum 1); costs 2 lives | 5 |
| Mender | teal hexagon, cyan health bar | 55 | 70 | 18 | Regenerates 5% of max HP per second | 7 |
| Splitter | orange ring | 50 | 80 | 15 | Splits into 3 Swarmlings where it dies | 8 |
| Warlord (boss) | large dark-red star, grey ring | 34 | 250 | 150 | Armor 4, slow regeneration, costs **5 lives** | every 10th |

### Upgrades and selling

- Each tower can take **one** upgrade path, then level it up to 3 times. The other paths disappear from its panel once one is chosen.
  - **Damage:** +9 per level (15 → 24 → 33 → 42). Best against armor.
  - **Range:** +24 px per level (112 → 136 → 160 → 184).
  - **Hit speed:** cooldown ×0.75 per level (0.8 → 0.6 → 0.45 → 0.34 s).
- Upgrades cost 50, then 80, then 120. Upgraded towers show colored pips and fire colored beams.
- **Selling** refunds 50% of everything spent on the tower, build plus upgrades. It works mid-wave; enemies immediately re-route through the freed tile.

## Project layout

```text
project.godot             main scene, 1600x900 window, canvas_items stretch, Compatibility renderer
scenes/main.tscn          Main → WaveManager, WindowFit, HUD/UILayout/Root(LeftColumn(BoardArea/Board(Towers, Enemies), BottomPanel), RightPanel)
scenes/enemy.tscn         Node2D + enemy.gd (drawn in code)
scenes/tower.tscn         Node2D + tower.gd (drawn in code)
scripts/game_config.gd    tuning constants only (class_name GameConfig)
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
```

## Tests

Run from the project root (replace `godot` with your executable path; on Windows that's e.g. `Godot_v4.7.2-stable_win64.exe`):

```sh
godot --headless --editor --path . --quit          # import once (builds the global class cache)
godot --headless --path . --quit-after 180         # runtime smoke test
godot --headless --path . --script res://tests/test_pathfinding.gd
godot --headless --path . --script res://tests/test_gameplay.gd
godot --headless --path . --script res://tests/test_stability.gd   # ~10 s
godot --headless --path . --script res://tests/test_layout.gd
```

Each script prints `ok` / `FAIL` per check and exits with code 0 only if every check passes.

- **test_pathfinding:**
  - every spec §10 case (routes, detours, no solid or diagonal steps, the final-gap rejection, reserved/out-of-bounds/occupied cells, enemy waypoints, unchanged state after invalid placement);
  - purchase economy and mid-wave rerouting;
  - the exactly-once death signal, tower range and cooldown;
  - endless-wave defeat → restart;
  - window-fit sizing.
- **test_gameplay:**
  - **generator:** reproducible per seed, varies between seeds; 300 waves × 3 seeds have valid sizes, unlocked types, finite stats and rising difficulty; boss schedule;
  - **enemy types:** distinct looks and stats; armor, regeneration, splitting (children inherit the movement segment, and the wave waits for them), boss lives cost;
  - **flow:** 30 consecutive waves with exact currency accounting;
  - **towers:** one upgrade path per tower and the level cap; upgrade effects; rejected upgrades change nothing; 50% refunds; mid-wave sell rerouting; selection UI.
- **test_stability:**
  - 6,000 randomized build/sell/upgrade/wave steps, checking every game invariant every 5 steps (board ↔ tower bookkeeping, routes from spawn and every enemy waypoint, no enemy on a tower, counters, currency, lives);
  - a long run where scripted towers fight real generated waves until defeat, with per-wave bounded-time checks;
  - 25 mid-wave restarts that must leave nothing behind.
- **test_layout:**
  - the reserved board area is exactly 1280×768 and the Board node sits on it;
  - no visible HUD element covers the board or leaves the view: across 9 extreme HUD states, during real gameplay with a tower selected, and on the defeat screen;
  - panels keep their size and scroll when overloaded with 40 extra rows and a label that refuses to wrap.
