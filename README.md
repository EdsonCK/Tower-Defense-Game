# Unnamed TD Game — Research & Layered Defenses (v0.4)

Godot **4.7.2 Stable**, GDScript, geometric art, no plugins/autoloads/external assets. Open the repository-root `project.godot` and press **F5**. Work is on `Codex-Workspace`.

## Play and progression

- **Gold** buys towers and their run-only upgrades. Start each run with 200 gold and 10 lives.
- Earn **exactly 1 diamond per completed wave**, including a wave survived with escaped enemies. A lost/incomplete wave gives none. Completion callbacks cannot double-pay.
- **Diamonds and skill unlocks are permanent:** retained through Restart and reopening the application. Gold, placed towers, and purchased tower levels reset on Restart.
- After clearing waves **5, 10, 15, …**, the skill menu opens automatically. It is also available through **Research lab** before/between waves. Close the modal to resume building or start the next wave. It cannot open during a wave and blocks gameplay actions while visible.
- **Tesla is the sole first available skill, costing 3 diamonds.** All other skills require it or a descendant.
- **Every tower type starts with all gold upgrades locked.** Unlock that type's training in Skills first; this immediately enables upgrades on existing and future towers of that type. Unique tracks require their additional skill.

Controls: **Build Tower** or **Build Tesla**, then left-click a valid tile. Click an existing tower to manage it, including while in build mode. **Right-click / Escape / Cancel** clears selection; Escape closes the skill menu. **Start Wave** launches a wave manually. Turn on **Auto-start Waves** to launch subsequent waves after each clear. Wave 1 still starts manually; automatic progression waits for skill menus to close, stops on defeat, and resets off on Restart. Turning the toggle off cancels a queued next wave. **Restart** asks “Are you sure?” before creating a new run/random seed. Combat and spawning pause while the confirmation is open; **Keep playing**, Escape, or closing the dialog resumes the current run. Diamonds and skills are preserved. No victory cap: play continues until defeat.

## Interface

The sidebar and footer use fixed control regions. Status changes, wave completion, selection, long messages, and large counters cannot move upgrade or Sell targets. Sell has a separate red-accented row and Restart sits at the bottom. The selected-tower card shows **HP / ARM / SHD damage**, range and firing interval. Large counters abbreviate; tooltips retain exact values.

The research lab has four scrolling branches, prerequisite labels, researched/available states, a fixed diamond header and an always-visible close button. See [rendered previews and UI checks](docs/ui/README.md).

## Permanent skill tree

There are **26 permanent nodes**, including 16 new upgrades with increasing costs. Existing saves and previously purchased unlocks remain valid. Each node is a one-time diamond purchase. The menu shows prerequisites, prices, effects, and acquired/locked states.

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

| New research | Diamonds | Requires | Permanent effect |
| --- | ---: | --- | --- |
| Armor Breaker / II | 7 / 14 | Piercing Rounds / previous tier | +25% / another +40% armor damage for all towers |
| Tower Engineering II / III | 9 / 18 | Engineering / previous tier | Another +15% / +25% to damage; +50% total with all tiers |
| Precision Optics / II | 6 / 12 | Basic Training / previous tier | +8% / another +12% range for all towers |
| Overcharge / II | 7 / 14 | Static Field / previous tier | +25% / another +40% shield damage for all towers |
| Rapid Cycling / II | 8 / 16 | Tesla Training / previous tier | Interval ×0.92 / another ×0.88, about 19% shorter together |
| Gold Mastery II / III | 10 / 20 | Gold Mastery / previous tier | Another +25% / +35% reward gold, +100% total with all tiers |
| Heavy Footsteps II | 9 | Heavy Footsteps | New enemies move another 10% slower, 19% total |
| Brittle Defenses II | 12 | Brittle Defenses | Another 15% less HP and shield, applied multiplicatively |
| Exposed Plating | 8 | Brittle Defenses | New enemies have 20% less armor |
| Shield Decay | 10 | Exposed Plating | New enemies have 25% less shield |

Tower Engineering scales final damage, including gold levels, and rounds to the nearest HP. Gold boosts are added together, then each reward rounds down. They do **not** boost removal refunds or diamonds. Enemy nerfs apply once to each spawned profile. Skills are bought between waves, so no live enemy stats are abruptly changed.

## Towers and gold upgrades

| Type | Build / refund | Health / armor / shield damage | Range | Interval | Attack |
| --- | --- | ---: | ---: | ---: | --- |
| Basic | 60 / 30 | **15 / 24 / 8** | 112 px | 0.8 s | Nearest living enemy |
| Tesla | 110 / 55 | **12 / 6 / 24** | **80 px** | 1.1 s | Electric bolt to **every living enemy in range**, once per pulse |

Tesla has a visible coil and branching electric bolts. Range is center-to-center Euclidean distance, including targets exactly at its radius. Both types block one cell. Removing refunds **50% of original construction**, with no refund for gold spent upgrading. Rebuilding creates a new tower with no selected track; its type's permanent training still applies.

After training, select **one track per tower**, up to five levels. Choosing any track, including a unique track, locks out all others on that tower. Costs are the same for normal and unique tracks of a given type:

- Basic levels 1–5: **60, 100, 160, 240, 360 gold**.
- Tesla levels 1–5: **80, 130, 200, 300, 450 gold**.

| Track | Basic per level | Tesla per level |
| --- | --- | --- |
| Damage | +12 damage | +9 damage |
| Range | +24 px | +12 px |
| Firing speed | Interval ×0.82 | Interval ×0.82 |
| Unique | Piercing Rounds: +8 health damage and +15 concentrated armor damage (before armor specialization bonus) | Static Field: +4 damage; slows targets 20–40% for 0.8 s at levels 1–5 |

Damage upgrades raise the health stat; the armor/shield stats scale from it. Basic armor/shield ratios are 1.6 / 0.55; Tesla ratios are 0.5 / 2.0. Piercing adds its concentrated armor bonus before permanent armor specialization. Engineering applies to the health stat first; derived damage is rounded, then specialized per layer. Every hit affects only the highest remaining pool: **purple shield → white armor → green health**, with **no overflow into lower layers**, even on a lethal overkill. Armor is now destructible plating rather than a permanent damage-reduction number. Nonpositive damage to the active layer cannot bypass it. Depleted bars disappear; remaining bars keep their vertical positions.

Slows retain the strongest factor/longest remaining duration rather than multiplying without limit. Movement resumes at normal speed when they expire, including partway through a frame. Speed upgrades never reset the cooldown to grant a free shot. Invalid, locked, unaffordable, maxed, or stale-selection actions cannot charge gold/diamonds.

## Map, enemies, and balancing

The 40 × 24 grid, 32 px cells, 1280 × 768 board, and 1600 × 900 logical window remain unchanged. Spawn `(0,12)` and exit `(39,12)` are reserved. UI panels consume their own clicks. Every accepted build preserves routes for spawn **and every living enemy's committed waypoint**. In-flight enemies finish their protected segment before rerouting at the next center. Slows, removals, and Tesla damage preserve these rules.

Five enemy types remain distinct:

| Type / shape | Base HP | Speed | Bounty | Trait |
| --- | ---: | ---: | ---: | --- |
| Grunt / red circle | 45 | 60 | 12 | Standard |
| Runner / orange triangle | 30 | 90 | 9 | Fast |
| Armored / steel square | 105 | 40 | 24 | Starts with 45 destructible armor; scales with wave |
| Regenerator / purple cross | 68 | 52 | 20 | Heals 3 HP/s after 2 s without a hit |
| Shielded / gold diamond | 80 | 66 | 22 | Starts with 30 shield; no recharge |

Each independent run varies composition/order, HP/defenses (±5%) and speed (±3%). Through wave 30, count varies by ±1 (8–64 enemies) and cadence by ±4%. After wave 30, count is `min(512, 64 + 4*l + floor(0.02*l*l))`, where `l = wave-30` is bounded before arithmetic. Spawn interval is `0.678 * (count/64)^-0.45` seconds: more enemies arrive faster, while total spawn windows get longer. Both plateau at 512 enemies / about 0.266 s spacing to bound resources. Enemies still in transit extend the actual wave beyond its spawn window.

| Wave | Enemies | Spawn interval | First-to-last spawn window |
| --- | ---: | ---: | ---: |
| 31 | 68 | 0.660 s | 44.2 s |
| 40 | 106 | 0.540 s | 56.7 s |
| 50 | 152 | 0.459 s | 69.4 s |
| 75 | 284 | 0.347 s | 98.1 s |
| 100 | 442 | 0.284 s | 125.3 s |
| 110+ | 512 | 0.266 s | 135.9 s |

At least two types appear per wave; armor unlocks from wave 2, regeneration from 3, shields from 5. Waves wait until every enemy resolves, and plans/prior-wave nodes are released. Auto-start waits for both research and restart dialogs.

HP/shield scale is `(1 + 0.08*d + 0.012*max(d-4,0)^2) * (1 + 0.055*max(wave-30,0))`, with `d=wave-1` bounded before arithmetic and ±5% profile variation. Armored plating uses this same scale times `45 * (1 + 0.10*min(12, floor(d/6) + floor(max(wave-30,0)/4)))`. Each defense/health pool caps at 1,000,000. Early HP and spawn cadence are preserved; armor now follows the new pool mechanic. Kills pay their bounty; surviving a wave pays **30 base gold and 1 diamond**. Every escape costs one life. Zero lives immediately stops gameplay.

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
  skill_tree.tscn          # Research modal shell and scrolling branches
scripts/
  ui_style.gd             # Shared vector UI theme and palette
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
  test_progression.gd, test_tesla.gd, test_balance.gd, test_auto_start.gd
  bot_policies.gd, test_hallway_policy.gd, compare_endless.gd
  test_ui_and_layers.gd, capture_ui.gd
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

The official binary reports `4.7.2.stable.official.ed1daf0bf` and was SHA512-verified. The runner sets writable temporary Linux XDG directories, imports first, runs a 180-frame startup, then all thirteen SceneTree suites. It checks timeouts, exit status, logged engine/script/leak errors, nonzero test counts, and failures. It does not modify HOME or repository source. Individual suites can be run with:

```sh
godot --headless --editor --path . --quit
godot --headless --path . --quit-after 180
godot --headless --path . --script res://tests/test_progression.gd
godot --headless --path . --script res://tests/test_tesla.gd
godot --headless --path . --script res://tests/test_balance.gd
```

Use your actual executable instead of `godot` if it is not on PATH. Import first on fresh checkouts.

Verified headless results: **35,392 checks across 13 suites, 0 failures**, plus import/startup, with no logged engine/script errors or leaks. Coverage includes persistence/recovery, real skill-menu button input, exact diamond payouts, milestone/modality, type-specific training, unique tracks, Tesla area damage/range/cooldown, gold boosts, enemy nerfs, and permanent-profile restart. New checks cover stationary upgrade clicks across wave completion, footer stability, real restart confirm/cancel/Escape input, paused/resumed processing and auto-start, strict layer isolation, real specialized shots, 26-node purchase/persistence and late-wave spawn windows. Existing pathfinding, rerouting, economy and combat checks remain active.

Long-run checks still cover **10,000 generated waves (5,086,314 profiles)**, **1,000 scheduled cycles**, **300 scene lifecycle waves**, and **100 build/remove cycles during movement**. Controlled instant kills in lifecycle tests verify accounting/cleanup; natural combat is measured separately by the bots. Automated checks do not establish unlimited uptime, Windows visual acceptance, or balance for every profile/strategy.

## Natural maze comparison

The original [v0.3 calibration](docs/balance/README.md) is retained as historical evidence (reference bot defeat 41 / hallway defeat 49). It predates layered armor and the denser waves. The [v0.4 report](docs/ui/README.md) records new natural comparisons at seed 721, capped at 200 waves, without free resources or combat overrides. The final reference / hallway defeat waves were **39 / 55**, with the existing near-wave-50 assertion passing.

The hallway policy uses `(0,11)`, then a wall at `x=1` starting `(1,12)` downward; walls at `x=3,5,...,37` alternate bottom-up/top-down with one open column between them. Production placement validation rejects each final sealing tile. The full layout has **426 basic towers, 19 open end gaps, and a 476-cell route**. It never buys upgrades, other tower types, or skills. Purchases occur before wave 1 and after completed waves, using only starting/earned gold.

The reference bot retains its existing earned-skill/upgrade policy and caps itself at 24 towers; it is not an optimal-player search. Both start with fresh in-memory profiles and seed 721. At 30 fixed simulation steps per second, only normal spawning, movement and tower combat decide results. No resources, damage or enemy speed are injected. Saved player progression is never used or modified.

To run the current comparison after editor import (substitute your Godot executable):

```sh
godot --headless --path . --script res://tests/compare_endless.gd -- --seed=721 --cap=200 --report=user://balance_comparison.json --assert-near-50
```

The optional assertion requires both bots to lose naturally and the longer-surviving bot's defeat wave to be 45–55. The benchmark is separate from the normal test runner; the runner includes its geometry, early-HP preservation and armor-pool regressions. Reports record per-wave routes, towers, gold, lives, HP/armor, kills/escapes by type and source hashes. This calibrates these policies and one seed, not a hard wave cap or a guarantee for all builds/profiles.

## Manual F5 acceptance

- [ ] Open in 4.7.2 Stable, press F5, and resize the window. Gold/diamond labels and all controls remain readable; grid clicks remain aligned.
- [ ] On a fresh profile, basic towers build but all upgrades are locked; Tesla is locked. Skills offers only Tesla as the first eligible node, at 3 diamonds.
- [ ] Clear waves: each surviving completion gives exactly one diamond. Wave 5 opens Skills automatically; close it and reopen between waves. Wave 10 repeats. No start/build/upgrade actions leak through the modal.
- [ ] Buy Tesla: spend 3 diamonds once. Build one for 110 gold and verify bolts hit every enemy in its small radius. It cannot upgrade until Tesla Training is bought.
- [ ] Buy Basic Training and verify existing/new basic towers can upgrade. Tesla remains independently gated. Upgrade a track and confirm all competing tracks stay locked.
- [ ] Unlock Piercing Rounds/Static Field and try their gold tracks on fresh towers. Verify concentrated armor damage and Tesla's temporary slow without diagonal movement or teleporting.
- [ ] Buy gold boosts and enemy nerfs: future rewards increase and new enemies slow/weaken. Removal still refunds only half base construction (30 basic / 55 Tesla).
- [ ] Click Range across a wave clear without moving the cursor: it must remain Range; Sell stays below the upgrade block. Confirm selected stats stay fully visible.
- [ ] Click Restart during a wave, then Keep playing/Escape: combat pauses and resumes without losing anything. Confirm Restart only after the question to reset the run.
- [ ] Scroll all four research branches, purchase a higher tier, and verify increased cost/prerequisite and immediate effects on placed towers.
- [ ] Inspect shield/armor/health bars: purple above white above green. Overkill on a layer must not spill into the next. Basic breaks plating faster; Tesla breaks shields faster.
- [ ] Restart, then close/reopen the application: diamonds and skills remain, while gold/lives/board/levels reset. Wave 1 of a new run can earn another diamond normally.
- [ ] Lose during a wave: no partial-wave diamond; defeat blocks further gameplay. Restart preserves permanent progress.
- [ ] Enable Auto-start Waves, start wave 1, and verify later waves start automatically. Wave 5 must wait for the skill menu to close. Turn auto-start off to wait between waves; Restart restores it off.
- [ ] Inspect Output/Debugger for parse, navigation, or recurring runtime errors. The new Windows visual playtest remains pending; no export was produced.
