# Unnamed TD Game — Endless (v0.2)

A self-contained Godot **4.7.2 Stable** maze tower-defense game using GDScript and geometric placeholder art. No plugins, autoloads, external assets, or export templates are needed. Open the repository-root `project.godot` and press **F5**.

This extends v0.1 with endless generated waves, five enemy types, tower removal, and exclusive tower upgrade tracks. There is no final victory wave: survive until base lives reach zero, then restart with a fresh run.

## Controls and tower management

- **Build Tower** → left-click a valid board cell to spend 60. Build mode stays selected until canceled or funds drop below 60.
- **Left-click an existing tower** (including in build mode) to select it. Its current range and stats appear; no placement cost is charged.
- Choose **Damage**, **Range**, or **Firing speed** in the panel. The **first upgrade permanently locks that tower to one track**. Each track has five levels.
- **Remove** deletes the selected tower, opens its cell, and refunds **30**, exactly 50% of the original 60 construction cost. **Upgrade costs are not refunded.** Rebuilding creates a fresh, unlocked tower.
- **Right-click**, **Escape**, or **Cancel** clears build mode/tower selection.
- **Start Wave** starts the next generated wave; it never starts automatically. Build, upgrade, and remove before or during a wave.
- **Restart** works during play and after defeat. It resets lives, money, towers, occupancy, upgrades, wave counters, selection, and the random seed.

The 40 × 24 board still uses 32-pixel cells and cardinal movement. The 1600 × 900 logical window preserves the 1280 × 768 playfield plus right/bottom panels, with aspect-preserving scaling. Spawn (0,12) and exit (39,12) remain reserved. UI clicks never place towers. Every build preserves both spawn connectivity and every living enemy's committed waypoint; removing a tower safely replans routes at cell centers.

## Endless waves

Each run owns an independent random generator. Wave composition/order, HP (±5%), speed (±3%), count (±1 within bounds), and cadence (±4% before the minimum clamp) vary between runs. Fixed seeds reproduce the same sequence for testing.

- Starts around 8 enemies; adds about two per wave up to **64**.
- Enemy health scales by `1 + 0.08 * (wave - 1)`, with arithmetic/health safety limits for extreme indices.
- Spacing decreases from about 1.2 seconds toward a **0.45-second minimum**.
- Each wave mixes at least two types. Runners are available immediately, armor from wave 2, regeneration from wave 3, and shields from wave 5. An unlocked type need not appear in every wave.
- Clearing **any** wave with lives remaining awards **30** and enables Start Wave. Kills pay their type's bounty once; every escape costs one life and gives no bounty.
- Plans are bounded to 64 entries and released after completion/stop. The next wave cannot stack on unresolved enemies; previous waves do not accumulate live nodes.

Base enemy stats, before wave scaling and small run variation:

| Type / appearance | HP | Speed px/s | Bounty | Trait |
| --- | ---: | ---: | ---: | --- |
| Grunt / red circle | 45 | 60 | 12 | Standard |
| Runner / orange triangle | 30 | 90 | 9 | Fast, fragile |
| Armored / steel square | 105 | 40 | 24 | Reduces each HP hit by 3; minimum 1 damage |
| Regenerator / purple circle with cross | 68 | 52 | 20 | Heals 3 HP/s starting 2 s after its last hit, up to max HP |
| Shielded / gold diamond with cyan ring | 80 | 66 | 22 | Starts with 30 shield (scaled with wave); absorbs damage before HP; no recharge |

Starting resources remain **200 currency / 10 lives**. Default towers still deal 15 immediate-hit damage at 112-pixel range with a 0.8-second interval and a brief beam. Economy/combat constants are in `game_config.gd`, type templates in `enemy_profile.gd`, and generation rules in `wave_generator.gd`.

## Upgrade values

Levels 1–5 cost **60, 100, 160, 240, 360**, respectively. Insufficient funds, a competing track, an invalid selection, or a maxed track changes nothing and charges nothing.

| Track | Effect per level | Level 5 |
| --- | --- | --- |
| Damage | +12 damage | 75 damage; original range/interval |
| Range | +24 pixels | 232 px; original damage/interval |
| Firing speed | Multiply interval by 0.82 | ~0.297 s; original damage/range |

Speed upgrades shorten the remaining cooldown if needed, without resetting it for a free immediate shot. Upgrade pips distinguish the selected track: orange damage, green range, purple speed. Upgrades do not change board occupancy or navigation revision.

## Source layout

```text
project.godot, .gitignore, README.md
scenes/
  main.tscn               # Board, containers, WaveManager, editor-inspectable HUD
  enemy.tscn
  tower.tscn
scripts/
  game_config.gd          # Defaults and limits
  enemy_profile.gd        # Five type templates and per-spawn stats
  wave_generator.gd       # Seeded bounded wave planning
  main.gd                 # Sole economy/state/purchase/upgrade/removal authority
  board.gd                # Sole AStarGrid2D/occupancy/coordinate authority
  enemy.gd                # Movement, health/traits, exactly-once death/escape
  tower.gd                # Targeting, attacks, exclusive track/level state
  wave_manager.gd         # Scheduled/unresolved counts, completion, run seed
  hud.gd                  # State presentation and button intents only
tests/
  run_checks.py           # Standard-library runner: timeouts + error-log checks
  test_pathfinding.gd
  test_movement.gd
  test_gameplay.gd
  test_input_and_restart.gd
  test_enemy_traits.gd
  test_tower_management.gd
  test_endless_stability.gd
```

Real `.gd.uid` files are committed; `.godot/`, Python caches, and generated translations are ignored. Live navigation uses `AStarGrid2D` with no diagonals and Manhattan heuristics. `update()` is called only at initialization. Temporary placement solidity is rolled back on rejection; scene-instantiation failure also rolls back without charging. In-flight enemies retain their committed segment, then replan at its next center on board revision. Dead/escaped enemies cannot award again, heal, receive targeting, or respond to later navigation changes.

## Automated checks

The runner requires Python 3 and the actual **Godot 4.7.2 Stable** executable. It imports first, starts the main scene for 180 frames, then executes all seven SceneTree suites. It checks exit codes **and** engine/script errors, leak reports, nonzero test counts, failures, and timeouts. It never assumes a zero engine exit means the scripts passed.

Windows PowerShell from the project root:

```powershell
python tests/run_checks.py --godot 'C:\path\to\Godot_v4.7.2-stable_win64.exe'
```

Cloud command actually used:

```sh
python3 tests/run_checks.py --godot /workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
```

The runner uses temporary writable Godot config/data/cache directories on Linux. It does not change HOME or any repository source. The installed binary reports `4.7.2.stable.official.ed1daf0bf` and was verified against the official release SHA512.

Individual checks without Python (substitute your actual executable for `godot`):

```sh
godot --version
godot --headless --editor --path . --quit
godot --headless --path . --quit-after 180
godot --headless --path . --script res://tests/test_pathfinding.gd
godot --headless --path . --script res://tests/test_movement.gd
godot --headless --path . --script res://tests/test_gameplay.gd
godot --headless --path . --script res://tests/test_input_and_restart.gd
godot --headless --path . --script res://tests/test_enemy_traits.gd
godot --headless --path . --script res://tests/test_tower_management.gd
godot --headless --path . --script res://tests/test_endless_stability.gd
```

Always import first in a fresh checkout to register global script classes. On a restricted Linux shell outside the runner, set XDG_DATA_HOME, XDG_CONFIG_HOME, and XDG_CACHE_HOME to writable directories.

Latest Godot 4.7.2 headless results:

| Check | Result |
| --- | --- |
| Fresh editor import / 180-frame startup | Passed; no logged errors |
| Pathfinding | 33 checks, 0 failures |
| Movement/rerouting | 15 checks, 0 failures |
| Gameplay/combat/economy | 118 checks, 0 failures |
| Viewport input/restart/layout | 25 checks, 0 failures |
| Enemy traits | 23 checks, 0 failures |
| Tower management | 468 checks, 0 failures |
| Endless generation/lifecycle soak | 34,130 checks, 0 failures |
| Total | **34,812 checks, 0 failures** |

Coverage includes last-gap and enemy-only traps; unchanged economy/occupancy after invalid builds; repeated safe rerouting; death/escape accounting; each enemy's speed, reward and trait; actual upgraded shots/range/timing; exclusive tracks and level caps; exact upgrade prices and 50% base-cost refunds; same-frame death/build handling; repeated build/remove; panel geometry and real Viewport button dispatch; defeat and repeated restart.

Long-run coverage distinguishes different kinds of evidence:

- **10,000 generated waves / 635,730 profiles:** bounded counts and cadence, positive finite stats, type diversity, and extreme wave indices.
- **1,000 scheduled waves:** exact spawn/completion counts and settled counters, using controlled instant resolution.
- **300 main-scene wave cycles:** real enemy instantiation, bounties/bonuses, deferred frees, group/signal cleanup, and interleaved build/upgrade/removal. Instant kills are deliberate for lifecycle testing.
- **Five independent 12-wave sessions:** production spawning/movement/combat with no injected damage, speed, money, or lives; towers are bought using earned currency. All five reached wave 12 with 10 lives. This is not a guarantee for every strategy or late-wave balance.
- **100 build/remove cycles during enemy movement:** protected segment and route invariants, exact net expense, and no retained towers.

Headless checks do not replace human visual acceptance or establish unlimited uptime. No Windows export was produced. This update needs a fresh Windows F5 visual playtest; the earlier v0.1 human acceptance does not validate the new controls and enemy visuals.

## Manual F5 checklist

- [ ] Open in Godot 4.7.2 Stable and press F5. Resize the window; confirm the grid, panels, controls, and click alignment remain readable.
- [ ] Build a tower: 200 → 140. Click it: stats/range and upgrade/removal buttons appear.
- [ ] Upgrade damage once: 140 → 80; damage becomes 27, while range/speed tracks lock. Other towers remain independent. Try an unaffordable or locked upgrade: no charge.
- [ ] Remove that upgraded tower: 80 → 110. The tower and blocking cell disappear; no upgrade money is refunded. Rebuild there: 110 → 50, new tower has no locked track.
- [ ] Try range on a different tower and verify visibly longer reach. Try speed and verify shorter firing intervals. Repeatedly upgrade one track up to level 5; further upgrades are disabled.
- [ ] Start waves and look for distinct colors/shapes, movement speeds, armor, regeneration after a pause in incoming damage, and the cyan shield ring disappearing as it absorbs hits.
- [ ] Build and remove during a wave: no teleporting, enemy trapping, or walking through towers. Current/committed enemy cells remain protected.
- [ ] Clear wave 3: the game continues with Start Wave for wave 4. Every cleared wave grants 30. Restart and observe a different generated sequence.
- [ ] Repeated Start Wave, Remove, and upgrade clicks cannot stack waves, double-refund, or charge locked tracks. Panel clicks never build towers.
- [ ] Let ten enemies escape: defeat stops spawning, movement/combat, and tower management. Restart from both live play and defeat: clean board, wave 0, 200 money, 10 lives, fresh upgrades/seed.
- [ ] Inspect Output/Debugger for script, navigation, or recurring runtime errors.

Late-wave balance remains tunable from play feedback. The original no-art/no-plugin implementation and strict maze-placement rules remain intact.
