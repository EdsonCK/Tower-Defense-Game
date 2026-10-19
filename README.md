# Unnamed TD Game — Diamonds & Tesla (v0.3)

Godot **4.7.2 Stable**, GDScript, geometric art, no plugins/autoloads/external assets. Open the repository-root `project.godot` and press **F5**. Work is on `Codex-Workspace`.

## Play and progression

- **Gold** buys towers and their run-only upgrades. Start each run with 200 gold and 10 lives.
- Earn **exactly 1 diamond per completed wave**, including a wave survived with escaped enemies. A lost/incomplete wave gives none. Completion callbacks cannot double-pay.
- **Diamonds and skill unlocks are permanent:** retained through Restart and reopening the application. Gold, placed towers, and purchased tower levels reset on Restart.
- After clearing waves **5, 10, 15, …**, the skill menu opens automatically. It is also available through **Permanent Skills** before/between waves. Close the modal to resume building or start the next wave. It cannot open during a wave and blocks gameplay actions while visible.
- **Tesla is the sole first available skill, costing 3 diamonds.** All other skills require it or a descendant.
- **Every tower type starts with all gold upgrades locked.** Unlock that type's training in Skills first; this immediately enables upgrades on existing and future towers of that type. Unique tracks require their additional skill.

Controls: **Build Tower** or **Build Tesla**, then left-click a valid tile. Click an existing tower to manage it, including while in build mode. **Right-click / Escape / Cancel** clears selection; Escape closes the skill menu. **Start Wave** launches each wave manually. **Restart** creates a new run/random seed while preserving the profile. No victory cap: play continues until defeat.

## Permanent skill tree

Each node is a one-time diamond purchase. The menu shows prerequisites, prices, effects, and acquired/locked states.

| Skill | Diamonds | Requires | Permanent effect |
| --- | ---: | --- | --- |
| Tesla Tower | **3** | None | Unlock Tesla construction |
| Basic Tower Training | 3 | Tesla | Enable basic tower gold upgrades |
| Tesla Training | 4 | Tesla | Enable Tesla gold upgrades |
| Salvage | 3 | Tesla | +20% gold from kills and wave-clear bonuses |
| Piercing Rounds | 4 | Basic Training | Unlock basic tower's unique upgrade track |
| Static Field | 4 | Tesla Training | Unlock Tesla's unique upgrade track |
| Tower Engineering | 4 | Basic Training | Permanent +10% damage for both tower types, including existing towers |
| Gold Mastery | 5 | Salvage | Another +20% gold, 40% total |
| Heavy Footsteps | 4 | Tesla | New enemies move 10% slower |
| Brittle Defenses | 5 | Heavy Footsteps | New enemies have 15% less HP and shield |

Tower Engineering scales final damage, including gold levels, and rounds to the nearest HP. Gold boosts are added together, then each reward rounds down. They do **not** boost removal refunds or diamonds. Enemy nerfs apply once to each spawned profile. Skills are bought between waves, so no live enemy stats are abruptly changed.

## Towers and gold upgrades

| Type | Build / refund | Base damage | Range | Interval | Attack |
| --- | --- | ---: | ---: | ---: | --- |
| Basic | 60 / 30 | 15 | 112 px | 0.8 s | Nearest living enemy |
| Tesla | 110 / 55 | 12 | **80 px** | 1.1 s | Electric bolt to **every living enemy in range**, once per pulse |

Tesla has a visible coil and branching electric bolts. Range is center-to-center Euclidean distance, including targets exactly at its radius. Both types block one cell. Removing refunds **50% of original construction**, with no refund for gold spent upgrading. Rebuilding creates a new tower with no selected track; its type's permanent training still applies.

After training, select **one track per tower**, up to five levels. Choosing any track, including a unique track, locks out all others on that tower. Costs are the same for normal and unique tracks of a given type:

- Basic levels 1–5: **60, 100, 160, 240, 360 gold**.
- Tesla levels 1–5: **80, 130, 200, 300, 450 gold**.

| Track | Basic per level | Tesla per level |
| --- | --- | --- |
| Damage | +12 damage | +9 damage |
| Range | +24 px | +12 px |
| Firing speed | Interval ×0.82 | Interval ×0.82 |
| Unique | Piercing Rounds: +8 damage and 3 armor penetration | Static Field: +4 damage; slows targets 20–40% for 0.8 s at levels 1–5 |

Slows retain the strongest factor/longest remaining duration rather than multiplying without limit. Movement resumes at normal speed when they expire, including partway through a frame. Speed upgrades never reset the cooldown to grant a free shot. Invalid, locked, unaffordable, maxed, or stale-selection actions cannot charge gold/diamonds.

## Map, enemies, and balancing

The 40 × 24 grid, 32 px cells, 1280 × 768 board, and 1600 × 900 logical window remain unchanged. Spawn `(0,12)` and exit `(39,12)` are reserved. UI panels consume their own clicks. Every accepted build preserves routes for spawn **and every living enemy's committed waypoint**. In-flight enemies finish their protected segment before rerouting at the next center. Slows, removals, and Tesla damage preserve these rules.

Five enemy types remain distinct:

| Type / shape | Base HP | Speed | Bounty | Trait |
| --- | ---: | ---: | ---: | --- |
| Grunt / red circle | 45 | 60 | 12 | Standard |
| Runner / orange triangle | 30 | 90 | 9 | Fast |
| Armored / steel square | 105 | 40 | 24 | Starts with 3 armor; increases gradually with wave |
| Regenerator / purple cross | 68 | 52 | 20 | Heals 3 HP/s after 2 s without a hit |
| Shielded / gold diamond | 80 | 66 | 22 | Starts with 30 shield; no recharge |

Each independent run varies composition/order, count (±1 within bounds), HP/shield (±5%), speed (±3%), and cadence (±4% before clamping). Waves grow from about 8 to **64 enemies maximum**, with spawn spacing falling from about 1.2 s toward a **0.45 s minimum**. At least two types appear per wave; armor unlocks from wave 2, regeneration from 3, shields from 5. Waves wait until all enemies resolve; plans and previous-wave nodes are released.

Health now follows investment in towers more strongly: `1 + 0.08*d + 0.012*max(d-4,0)^2`, where `d = wave-1` is bounded before arithmetic. Armored enemies gain one armor per six waves, capped at +12. HP/shield retain safety caps. Kills pay their bounty; surviving each wave pays **30 base gold and 1 diamond**. Every escape costs one life. Zero lives stops spawning/movement/combat and management immediately.

Fresh-profile bot calibration uses five seeds (`721,109,1337,9001,2026`), with no injected gold, diamonds, damage, speed, lives, or unlocks:

- **Sensible policy:** distributed route coverage, earned-gold purchases/levels, and earned-diamond skill purchases. All five cleared **30 waves with 10 lives**.
- **Poor policy:** the same initial budget spent far from the route. All five lost on **wave 2**, after clearing only wave 1.

These are reproducible reference policies, not a claim that every strategy or late-game build is balanced. Constants/templates/rules are in `game_config.gd`, `enemy_profile.gd`, `wave_generator.gd`, and `skill_catalog.gd`.

## Profile storage and recovery

The local profile is **`user://progression.json`**, outside the repository. On Windows the default Godot location is `%APPDATA%/Godot/app_userdata/Unnamed TD Game/`; Godot's **Project → Open User Data Folder** locates the actual directory. No Windows path is hardcoded in source.

A versioned JSON profile stores the diamond balance, known prerequisite-valid unlocks, and the last rewarded run/wave marker. Saves write and flush a temporary file before replacing the primary, with a previous valid `.bak` retained. A corrupt primary can recover from backup. Unknown versions/invalid data are rejected rather than silently overwritten. A blocked save leaves earned diamonds in memory, marks the HUD balance with `*`, and shows a status/retry action in Skills; failed skill purchases roll back. If both saved copies are unreadable, preserve/repair them while the game is closed and reopen it. Progress cannot survive closing the app if the disk remains unwritable.

Tests inject in-memory profiles. Dedicated persistence tests use unique disposable files under `user://tests/`; **they never reset, spend, or farm the player's real profile**. Restart passes the same profile into the new scene without retaining run objects.

## Files and ownership

```text
project.godot, .gitignore, README.md
scenes/
  main.tscn, enemy.tscn, tower.tscn
  skill_tree.tscn          # Inspectable modal, buttons, prices and prerequisites
scripts/
  game_config.gd          # Shared values
  main.gd                 # Authoritative run economy/state/system wiring
  board.gd                # AStarGrid2D, occupancy, placement and coordinates
  enemy.gd                # Movement, health, traits, slowing and resolution
  tower.gd                # Basic/Tesla attacks, training gates, exclusive tracks
  hud.gd                  # State display and player intents
  enemy_profile.gd, wave_generator.gd, wave_manager.gd
  skill_catalog.gd        # Permanent nodes, costs and dependency graph
  progression.gd          # Diamond accounting, unlocks, atomic local profile
  skill_tree_menu.gd      # Modal presentation and button intents
tests/
  run_checks.py
  test_pathfinding.gd, test_movement.gd, test_gameplay.gd
  test_input_and_restart.gd, test_enemy_traits.gd
  test_tower_management.gd, test_endless_stability.gd
  test_progression.gd, test_tesla.gd, test_balance.gd
```

`.gd.uid` files are source and committed; `.godot/` and Python caches are ignored. There are no plugins or autoload singletons. Live pathfinding still uses AStarGrid2D (no diagonal movement, Manhattan heuristic), initialized once; candidate solidity is restored on rejected placements and scene-instantiation failure.

## Run automated checks

Python 3 standard library only, using the actual Godot 4.7.2 Stable executable:

```powershell
python tests/run_checks.py --godot 'C:\path\to\Godot_v4.7.2-stable_win64.exe'
```

Cloud command actually used:

```sh
python3 tests/run_checks.py --godot /workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
```

The official binary reports `4.7.2.stable.official.ed1daf0bf` and was SHA512-verified. The runner sets writable temporary Linux XDG directories, imports first, runs a 180-frame startup, then all ten SceneTree suites. It checks timeouts, exit status, logged engine/script/leak errors, nonzero test counts, and failures. It does not modify HOME or repository source. Individual suites can be run with:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --quit-after 180
godot --headless --path . --script res://tests/test_progression.gd
godot --headless --path . --script res://tests/test_tesla.gd
godot --headless --path . --script res://tests/test_balance.gd
```

Use your actual executable instead of `godot` if it is not on PATH. Import first on fresh checkouts.

Verified headless results: **35,066 checks across 10 suites, 0 failures**, plus import/startup, with no logged engine/script errors or leaks. Coverage includes persistence/recovery, real skill-menu button input, exact diamond payouts, milestone/modality, type-specific training, unique tracks, Tesla area damage/range/cooldown, gold boosts, enemy nerfs, and permanent-profile restart. Existing pathfinding, rerouting, economy and combat checks remain active.

Long-run checks still cover **10,000 generated waves (635,730 profiles)**, **1,000 scheduled cycles**, **300 scene lifecycle waves**, and **100 build/remove cycles during movement**. Controlled instant kills in lifecycle tests verify accounting/cleanup; natural combat is measured separately by the bots. Automated checks do not establish unlimited uptime, Windows visual acceptance, or balance for every profile/strategy.

## Manual F5 acceptance

- [ ] Open in 4.7.2 Stable, press F5, and resize the window. Gold/diamond labels and all controls remain readable; grid clicks remain aligned.
- [ ] On a fresh profile, basic towers build but all upgrades are locked; Tesla is locked. Skills offers only Tesla as the first eligible node, at 3 diamonds.
- [ ] Clear waves: each surviving completion gives exactly one diamond. Wave 5 opens Skills automatically; close it and reopen between waves. Wave 10 repeats. No start/build/upgrade actions leak through the modal.
- [ ] Buy Tesla: spend 3 diamonds once. Build one for 110 gold and verify bolts hit every enemy in its small radius. It cannot upgrade until Tesla Training is bought.
- [ ] Buy Basic Training and verify existing/new basic towers can upgrade. Tesla remains independently gated. Upgrade a track and confirm all competing tracks stay locked.
- [ ] Unlock Piercing Rounds/Static Field and try their gold tracks on fresh towers. Verify armor penetration and Tesla's temporary slow without diagonal movement or teleporting.
- [ ] Buy gold boosts and enemy nerfs: future rewards increase and new enemies slow/weaken. Removal still refunds only half base construction (30 basic / 55 Tesla).
- [ ] Restart, then close/reopen the application: diamonds and skills remain, while gold/lives/board/levels reset. Wave 1 of a new run can earn another diamond normally.
- [ ] Lose during a wave: no partial-wave diamond; defeat blocks further gameplay. Restart preserves permanent progress.
- [ ] Inspect Output/Debugger for parse, navigation, or recurring runtime errors. The new Windows visual playtest remains pending; no export was produced.
