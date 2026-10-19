# Unnamed TD Game — v0.1

As-of-yet unnamed maze-building tower defense made in Godot, mostly written with AI. It draws on Rogue Tower and Sir, We Have an Orc Problem.

v0.1 is a gameplay-systems prototype for **Godot 4.7.2 stable**, written in GDScript. It has one open 40 × 24 map, one tower type, one enemy type and three waves. Towers block tiles, so you build the maze yourself. You can never fully seal the route.

## Running

1. Open `project.godot` in Godot 4.7.2 (Project Manager → Import). Let the editor finish importing.
2. Press **F5**. The main scene is `res://scenes/main.tscn`.

## Controls

| Action | Control |
|---|---|
| Enter build mode | **Build Tower (60)** button |
| Place tower | **Left-click** a highlighted tile (green = valid, red = invalid). Build mode stays on after placing, until you cancel or can't afford another tower. |
| Cancel build mode | **Right-click**, **Esc**, or the **Cancel Build** button |
| Launch next wave | **Start Wave** (disabled while a wave is running) |
| New game | **Restart** (works at any time, including after victory/defeat) |

## Rules (defaults in `scripts/game_config.gd`)

- Start with 200 currency and 10 lives. A tower costs 60.
- Tower: range 112 px, 15 damage every 0.8 s. Shots hit instantly, shown by a short beam.
- Enemies move at 60 px/s from **IN** (green, cell 0,12) to **OUT** (orange, cell 39,12), cardinal moves only.
- Kill bounty: 12. Wave-clear bonus: 30 after waves 1 and 2. Each escaped enemy costs 1 life and pays no bounty.
- Waves: 8 × 45 HP, 12 × 60 HP, 16 × 75 HP, spawning 1.2 s apart.
- **Victory:** clear wave 3 with lives left. **Defeat:** lives reach 0. Spawning stops and only Restart works.
- A placement is rejected, at no charge, if it would:
  - go on the entrance or exit, an occupied tile, or a tile an enemy is on or walking into;
  - cut off the spawn → exit route;
  - cut off any in-flight enemy's next waypoint from the exit.

## Project layout

```text
project.godot          main scene, 1600x900 window, canvas_items stretch, Compatibility renderer
scenes/main.tscn       Main → Board(Towers, Enemies), WaveManager, HUD/UILayout(RightPanel, BottomPanel)
scenes/enemy.tscn      Node2D + enemy.gd (drawn in code)
scenes/tower.tscn      Node2D + tower.gd (drawn in code)
scripts/game_config.gd tuning constants only (class_name GameConfig)
scripts/main.gd        currency, lives, game state, purchases, win/loss, restart, wiring
scripts/board.gd       grid, AStarGrid2D, coordinate helpers, placement validation, rendering, clicks
scripts/enemy.gd       cell-center movement, safe rerouting, health, died/reached_exit (once each)
scripts/tower.gd       targeting, cooldown, immediate-hit attack, beam flash
scripts/wave_manager.gd wave progress, spawn timer, unresolved-enemy count, completion signal
scripts/hud.gd         labels, buttons → intent signals, messages
tests/test_pathfinding.gd headless SceneTree test suite
```

## Tests

Run from the project root (replace `godot` with your executable path; on Windows that's e.g. `Godot_v4.7.2-stable_win64.exe`):

```sh
godot --headless --editor --path . --quit          # import once (builds the global class cache)
godot --headless --path . --quit-after 180         # runtime smoke test
godot --headless --path . --script res://tests/test_pathfinding.gd
```

The test script prints `ok` / `FAIL` per check and exits with code 0 only if every check passes. It covers:

- every pathfinding case in spec §10 (empty-board route, detours, no solid/diagonal steps, the column-20 final-gap rejection, reserved/out-of-bounds/occupied cells, enemy waypoints, and unchanged state after invalid placement);
- purchase economy;
- mid-wave rerouting with no teleporting and no walking into towers;
- the exactly-once death signal;
- tower range and cooldown;
- a full defeat → restart flow and a three-wave victory flow.
