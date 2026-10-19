# Unnamed TD Game v0.1

A self-contained maze tower-defense prototype for **Godot 4.7.2 Stable**, written in GDScript. No plugins, autoloads, downloaded art, or export templates are required. The repository root is the Godot project root; no machine-specific Windows path is used.

## Run and controls

1. Check out `Codex-Workspace`, then import/open `project.godot` in Godot 4.7.2 Stable.
2. Allow the initial import to finish and press **F5**.
3. Click **Build Tower**, then **left-click** a green board tile to buy one tower for 60.
4. **Right-click**, **Escape**, or **Cancel** exits build mode. Successful purchases keep it selected until funds are below 60; select it again after earning money.
5. Click **Start Wave** for each wave. Building is allowed before and during waves. The next wave never starts automatically.
6. Click **Restart** at any time, including after victory/defeat, to return to an empty board, 200 currency, and 10 lives.

Keep an entrance-to-exit route open. Towers are permanent in v0.1: no selling or upgrades. Rejected placements and UI clicks never spend currency. Green marks the entrance, orange the exit, cyan squares the towers, and red circles the enemies. Selected-tile color shows placement validity and a circle shows tower range. Shots have a brief beam/flash.

## Rules and configuration

All defaults live in `scripts/game_config.gd`:

| Setting | Value |
| --- | --- |
| Board | 40 × 24 cells, 32 px each; 1280 × 768 px |
| Logical window | 1600 × 900, Compatibility renderer, aspect-preserving canvas scaling |
| Entrance / exit | (0,12) / (39,12), both reserved |
| Starting currency / lives | 200 / 10 |
| Tower | Cost 60, range 112 px, damage 15, cooldown 0.8 s |
| Enemy | Speed 60 px/s; kill bounty 12; escape costs 1 life with no bounty |
| Wave 1 | 8 enemies, 45 HP each |
| Wave 2 | 12 enemies, 60 HP each |
| Wave 3 | 16 enemies, 75 HP each |
| Spawning | First enemy on next process tick, then one every 1.2 s |
| Clear bonus | 30 after waves 1 and 2, if lives remain |
| End states | Clear wave 3 with lives > 0 to win; zero lives loses immediately |

The right 320-pixel panel and bottom 132-pixel panel consume their own clicks. The board only accepts positions with `0 <= x < 1280` and `0 <= y < 768`. All cell centers use `(x*32+16, y*32+16)`.

## Files and ownership

```text
project.godot
.gitignore
README.md
scenes/
  main.tscn                # Board, Towers, Enemies, WaveManager, inspectable HUD controls
  enemy.tscn
  tower.tscn
scripts/
  game_config.gd           # Shared constants only
  main.gd                  # TDGame: economy, purchases, phases, system connections
  board.gd                 # Board: AStarGrid2D, occupancy, coordinates, hover/grid drawing
  enemy.gd                 # Enemy: health, center-to-center movement, one-time resolution
  tower.gd                 # Tower: nearest-target immediate-hit attacks and firing feedback
  wave_manager.gd          # WaveManager: scheduled/active enemy counts and wave completion
  hud.gd                   # GameHUD: state display and button intents
  *.gd.uid                 # Godot source identifiers, intentionally committed
tests/                    # No external test framework
  test_pathfinding.gd
  test_movement.gd
  test_gameplay.gd
  test_input_and_restart.gd
```

`Board` initializes the 960-cell `AStarGrid2D` once, disables diagonal movement, and uses Manhattan heuristics. Temporary candidate solidity is restored on rejection or preview. Purchasing commits occupancy only after tower instantiation succeeds, then deducts currency and emits a board revision. Failed instantiation rolls occupancy back without spending or emitting a revision.

Every placement checks spawn-to-exit connectivity and the committed waypoint of every living enemy. Current and committed cells cannot be built on. An in-flight enemy finishes its protected segment unchanged, then replans at the next center. Navigation errors log an error and display a HUD message; enemies are never silently removed. Death/exit marks the enemy resolved before emitting its signal. Only WaveManager counts unresolved enemies.

## Automated verification

Resolve the actual executable on your machine first; an editor installation does not necessarily put `godot` on PATH. Windows PowerShell, run from this repository root:

```powershell
$godot = 'C:\path\to\Godot_v4.7.2-stable_win64.exe'
& $godot --version
& $godot --headless --editor --path . --quit
& $godot --headless --path . --quit-after 180
& $godot --headless --path . --script res://tests/test_pathfinding.gd
& $godot --headless --path . --script res://tests/test_movement.gd
& $godot --headless --path . --script res://tests/test_gameplay.gd
& $godot --headless --path . --script res://tests/test_input_and_restart.gd
```

Verified on the official Godot 4.7.2 Stable Linux build after removing the generated `.godot/` cache and doing a fresh import:

| Check | Result |
| --- | --- |
| Headless editor import | Passed, exit 0, no errors |
| 180-frame headless main-scene startup | Passed, exit 0, no errors |
| Pathfinding | 33 checks, 0 failures |
| Movement/rerouting | 15 checks, 0 failures |
| Gameplay/economy/combat/waves | 50 checks, 0 failures |
| Viewport input/restart/layout | 19 checks, 0 failures |

All **117 checks passed**; logs were also checked for engine/script errors and leaked instances. Windows F5 visual acceptance has not been run.

Check **both exit status and output** for errors. The suites print their check/failure counts and return a nonzero exit code on failed checks. Input/restart also has a timeout. Run the import first so a fresh checkout has its generated global-script-class cache.

Cloud validation uses the checksum-verified official Linux binary at:

```sh
/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
```

Its version is `4.7.2.stable.official.ed1daf0bf`. In a restricted cloud filesystem, use writable Godot data/config/cache directories before running the commands:

```sh
mkdir -p /tmp/td-godot/data /tmp/td-godot/config /tmp/td-godot/cache
export XDG_DATA_HOME=/tmp/td-godot/data
export XDG_CONFIG_HOME=/tmp/td-godot/config
export XDG_CACHE_HOME=/tmp/td-godot/cache
```

Coverage includes cardinal paths and solid-cell avoidance; last-gap and active-enemy traps; protected current/next cells; unchanged state after invalid purchases and instantiation failures; in-flight and repeated rerouting without teleporting; one-time death/escape; purchase costs, cooldown, nearest-target and range boundaries; exact wave counts/HP/cadence; bounties/bonuses; victory/defeat; actual Viewport input dispatch; panel boundaries; and repeated scene restart.

The gameplay suite also runs production spawning, movement and tower combat with fixed time steps through a complete three-wave game without injecting damage, money, lives, or speed. Three initial towers at **(3,11), (6,11), (9,11)** produce a reproducible victory (5 lives, 452 currency). This is an example playtest strategy, not a balance guarantee. A second session without towers exercises defeat. Synthetic walls/pockets in tests do not alter the playable open map.

## Manual Windows F5 acceptance checklist

Headless checks do not replace a visual Windows playtest. This part remains for the human tester:

- [ ] Open `project.godot` in Godot 4.7.2 Stable and press F5. Confirm the 40 × 24 grid, entrance/exit, and readable panels. Resize the window and check the 16:9 layout and click alignment.
- [ ] Build one tower: currency must change from 200 to 140. Check green/red hover and the range circle.
- [ ] Click the occupied tile, entrance, exit, panel backgrounds, and outside the board: no extra towers or charge. Check right-click/Escape/Cancel and automatic deselection below 60.
- [ ] Start a wave twice: only one wave starts. Enemies appear 1.2 s apart and move along cardinal segments. Build on a future route tile and verify rerouting without teleporting; current/committed tiles must be rejected.
- [ ] Watch health bars and shot beams. Kills give 12 once; escapes cost one life and give no bounty. For the synthetic final-gap and enemy-only trap cases, run the automated suites (buying a 23-tower wall is unnecessary).
- [ ] Clear wave 1 and 2: each gives 30 bonus and waits for Start Wave. Clear wave 3 with lives remaining: VICTORY disables building and starting.
- [ ] For an easy full-session check, restart and place towers at zero-based cells (3,11), (6,11), (9,11), then start each wave. Their pixel centers are (112,368), (208,368), (304,368).
- [ ] Restart and start waves without towers: all 8 wave-1 enemies escape, leaving 2 lives; wave 2 reaches DEFEAT on the next two escapes and stops spawning/movement/combat.
- [ ] Restart from active play and each end state: 200 currency, 10 lives, no towers/enemies, open board, wave 0, enabled Start Wave.
- [ ] Inspect Output/Debugger: no parse errors, recurring exceptions, or navigation errors.

## Scope and limitations

This implements phases A–F's code and automated verification. Human F5 visual acceptance is pending. No Windows executable was exported, and no audio, third-party assets/plugins, upgrades, selling, projectiles, save system, or other later-version mechanics are included. No known gameplay defects remain from the automated checks. Visual appearance and Windows-specific behavior still need the checklist above.

After accepting v0.1, the next useful improvement is balancing these test defaults from real play sessions; no future features have been implemented.
