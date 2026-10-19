> Historical v0.3 calibration. Layered defenses and denser waves in v0.4 change these outcomes; see [current results](../ui/README.md). Reproduce this report from commit `2ffad4f`, not the current working revision.

# Single-run bot comparison

Godot `4.7.2.stable.official.ed1daf0bf`, seed **721**, fixed **1/30 s** simulation steps, fresh in-memory profiles, **200-wave maximum per run**. Baseline game source: commit `6e0ec6400e1cfc8f98f3796b08cc4e4396ce20ae`.

One baseline run per policy was completed before balance changes. One confirmation run per policy was completed afterward. No seed search, no best-of-many selection, and no damage, money, lives, speed, or instant-kill overrides were used. All four ended in natural defeat before the cap. The player's real profile was untouched.

| Policy | Baseline cleared | Baseline defeat | Tuned cleared | Tuned defeat |
| --- | ---: | ---: | ---: | ---: |
| Existing reference (prior best) | 45 | **46** | 40 | **41** |
| Requested basic-only hallway | 67 | **68** | 48 | **49** |

The winning bot now reaches **wave 49**, meeting the approximate wave-50 target. “Cleared” excludes the wave on which the base falls.

## Policies and exact hallway interpretation

The reference bot's existing decision functions were moved unchanged into `tests/bot_policies.gd`; the short balance suite calls the same functions. It distributes up to **24 towers (19 basic, 5 Tesla in this seed)** in rows 11/13, purchases ordinary damage levels, and buys skills with earned diamonds. At defeat it had 120 total upgrade levels. Its 24-tower limit leaves surplus gold, so this is the best *existing reference policy*, not an optimal solver. It does not buy the later Tower Engineering node.

The hallway policy:

1. Uses starting gold before wave 1. Places `(0,11)` directly above spawn, then `(1,12)` directly in front, then continues down column 1.
2. The production Board rejects `(1,23)` because it would seal spawn. Leave it open.
3. Start column 3 at `(3,23)` and build upward. Leave `(3,0)` open when sealing it is rejected.
4. Build column 5 downward, leaving `(5,23)` open. Continue alternating through columns 7,9,…,37. Columns 2,4,…,38 are the one-cell-wide hallways. Keep the exit column clear.
5. Spend earned gold only **between waves**, continuing the same ordered construction queue. Never upgrade, sell, buy Tesla, or purchase a skill. Close skill menus without buying anything.

The full pattern has **426 towers**, **19 rejected/open end gaps**, and a valid **476-cell cardinal path**, compared with the reference bot's 40-cell route. It finishes construction before wave 40 in both runs. The fixture suite verifies the geometry and route; construction rejects actual sealing attempts rather than silently bypassing placement validation.

## What the baseline demonstrated

- **Maze geometry is powerful.** Route length grows by 11.9× and enemies pass many unupgraded guns. The hallway policy outlives the capped upgraded layout despite having no skills or upgrades. This does not prove that individual unupgraded towers outperform upgraded ones; the layouts, tower counts, and investment differ.
- **Armor was the final counter.** The baseline hallway retained all 10 lives through wave 66. At wave 67, three armored enemies escaped; at wave 68, seven more escaped and ended the run. At 14 armor, a 15-damage basic shot falls to the minimum **1 damage**.
- **The upgraded layout lost mainly to shields.** Its last three waves lost lives to shielded enemies despite max damage tracks. Its short path and capped coverage could no longer finish them. More gold alone did not help because this policy stopped expanding.
- **Early play was already working.** Both policies retained all lives through wave 30. The five-seed short good/poor-placement regression also still passes, so no early-game stats or economy were changed.

## Tuning and final assessment

Tower prices, range, damage, cooldowns, upgrade costs and rewards remain unchanged. Preserve the original HP curve `1 + 0.08*d + 0.012*max(d-4,0)^2` and all early-wave generation, where `d = wave-1` is bounded before arithmetic. Only after wave 30:

- Multiply HP/shield by **`1 + 0.04*(wave-30)`**.
- Add **one extra armor per four post-30 waves**, on top of the original one per six waves. Total added armor still caps at 12 (15 including base armor).

These are exposed as `VETERAN_START_WAVE`, `VETERAN_HEALTH_PER_WAVE`, and `VETERAN_ARMOR_INTERVAL` in `game_config.gd`. There is no forced death or final-wave rule. Existing actor-count, health and cadence limits remain; extreme wave-index generation still passes its finite-stat/overflow checks.

At wave 50 the health multiplier is 1.8× the previous curve. The tuned hallway starts losing lives on wave 47 and falls on wave 49, with armored enemies around **5,431 HP** and 15 armor. Base hits still deal 1 rather than becoming immune; a max damage basic tower deals **60 through that armor**. More advanced skill/upgrade choices remain relevant rather than being disabled to force the target.

The reference policy now falls on wave 41, while the hallway policy remains the winner. This is expected from applying stronger late enemies to both layouts. Reaching wave 49 took about **76.8 simulated minutes** for the hallway bot (baseline wave 68 took 125.7), excluding time a human spends shopping/building. Late full-maze waves can take several simulated minutes; the harness uses a route-based timeout instead of the old 150-second smoke-test budget.

## Evidence and reproduction

- [baseline.json](baseline.json): all baseline waves and combat metrics; generator SHA256 matches the source at the baseline commit.
- [tuned.json](tuned.json): all confirmation waves, generator/config hashes and final outcomes.
- `tests/compare_endless.gd`: opt-in experiment, maximum cap clamped to 200.
- `tests/test_hallway_policy.gd`: funded geometry fixture (not a survival claim), baseline early-wave preservation, and real basic/upgraded shots against wave-50 armor.

Actual baseline command (with writable Linux XDG directories initialized):

```sh
/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/compare_endless.gd -- --report=/tmp/td-baseline-6e0ec64.json --label=baseline-6e0ec64
```

Actual tuned confirmation:

```sh
/workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64 --headless --path . --script res://tests/compare_endless.gd -- --report=/tmp/td-tuned-comparison.json --label=veteran-pressure-0.04 --assert-near-50
```

Both exited 0 without logged script/engine errors. The tuned run's assertion requires natural defeat for both policies and the winner's defeat wave in **45–55**. On Windows, substitute your actual executable and use `--report=user://balance_comparison.json`.

Standard regression command:

```sh
python3 tests/run_checks.py --godot /workspace/tools/godot-4.7.2/Godot_v4.7.2-stable_linux.x86_64
```

**35,169 checks across 12 suites passed**, plus headless import and startup, with no logged engine/script errors or leaks. No additional full endless runs were added to that standard suite. Windows visual F5 acceptance of the balance change was not run. Results are a single-seed calibration for these policies; stronger players, different skills, other seeds and optimized layouts may exceed wave 50.
