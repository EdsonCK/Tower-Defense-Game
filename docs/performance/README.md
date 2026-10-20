# Late-wave optimization

The optimization keeps tower prices/stats, enemy stats/counts, spawning cadence,
movement, research, damage layers, targeting rules and projectile collision tests.
The baseline is `431f653af7645f1da48d1f6670f6d1c723a15a29` on Codex-Workspace.

## Changes

- **Combat broad phase:** each board indexes enemies and towers in 64 px buckets.
  Towers, Tesla rings, mortar explosions and swept cannonballs query nearby
  candidates. The original global-distance, circle/segment and expanded-rectangle
  tests still decide hits. Candidates retain enemy group insertion order, including
  the original “last enemy wins” rule for equal-distance targets. Transform-change
  notifications update entries immediately, including movement/teleports in the
  middle of a frame. Exit-tree cleanup releases entries; large ranges visit only
  occupied buckets.
- **Placement:** one reverse cardinal flood fill replaces an A* search plus full
  path validation for every enemy. Spawn and every committed waypoint must still
  reach the exit; current/committed occupied tiles stay protected. A hover's
  reachability map is reusable while enemies move, but protected cells are checked
  again each time. Purchases remain synchronous transactions. Preview queries no
  longer modify the navigation grid.
- **Routes:** cache exact A* results by start cell, with copies for callers.
  Every solidity change invalidates the cache, including provisional purchases,
  rollback and selling. The grid bounds its size; no wave history accumulates.
- **Tower stats:** cache derived damage, armor/shield damage, range and firing
  interval until a gold upgrade, research reconfiguration or tower-kind change.
- **Rendering:** bake the existing procedural monster bodies into 64 animation
  phases per type at 2x resolution. Tower bases also use shared cached textures;
  weapons, recoil, lightning, projectiles, impacts, status effects and health bars
  remain live. The small animation phase quantization is cosmetic. The original
  vector sources and a Godot baker are included; no downloaded art or plugins.
  Texture storage is approximately 12 MiB of RGBA pixels, shared by all actors.
- **HUD:** coalesce spawn/death bursts into one deferred visual refresh. Gold,
  wave counters, rewards and phase transitions still update synchronously;
  purchases and selection still refresh controls immediately.
- **Board:** retain floor draw commands on a separate CanvasItem and avoid
  redundant overlay invalidations when HUD calls supply unchanged values.

## Measurement

See the committed raw JSON/logs beside this report. The harness uses a funded
stress fixture, **not natural survival or balance evidence**: a legal 426-tower,
476-cell hallway maze, all research, all five tower types and three gold upgrades
per tower. Seed-721 native wave profiles are spread along the route to exercise
all defenses simultaneously. Wave 60 has 202 enemies and wave 110 has 512.
A sentinel keeps the fixture active; wave 5 exercises kills and gold rewards.

Each workload executes 240 fixed 1/60-second gameplay steps, with deletion flushed
between frames. One valid placement preview is checked every frame. Component
CPU times exclude the combat-state audit. Frame time includes the scene-tree
frame/render wait; **headless frame timings are not desktop FPS**. These are
single workload samples with within-sample mean/p50/p95, not broad hardware
benchmarks. Before/after processes run sequentially with the same harness.

Rendered measurements use Godot 4.7.2 Stable, OpenGL Compatibility, a 1600x900
window, dummy audio, Xorg's dummy display and Mesa llvmpipe software graphics in
this cloud environment. Software rendering exaggerates graphics cost relative to
many desktop GPUs. No Windows/GPU/F5 acceptance result is claimed.

| Workload | Wave | Initial enemies | Mean frame ms, before → after | p95 frame ms, before → after |
| --- | ---: | ---: | ---: | ---: |
| Headless, preview | 5 | 17 | 7.13 → 6.77 | 8.13 → 6.84 |
| Headless, preview | 60 | 202 | 49.66 → 7.42 | 91.46 → 12.25 |
| Headless, preview | 110 | 512 | 107.78 → 9.93 | 164.79 → 18.21 |
| Software OpenGL, preview | 60 | 202 | 370.80 → 88.55 | 641.12 → 131.07 |
| Headless, no preview | 60 | 202 | 23.42 → 7.39 | 59.12 → 11.88 |

The rendered sample improves mean frame time by **4.19×**. At wave 60,
mean preview CPU time falls from **26.49 to 0.17 ms**, and
mean projectile CPU time from **5.32 to 0.28 ms**.
The no-preview workload confirms a gain when the player is watching combat too.

Final validation: **48,989 checks across 17 suites**, zero failures/logged errors;
editor import and 180-frame startup passed. The additional optimization suite
contributes 12,331 checks. Linux software-rendered before/after screenshots were
also inspected for the preserved silhouettes, tower art, bars and layout.

The per-frame SHA-256 combat recordings match before/after for waves 5, 60 and
110. They cover ordered enemy positions, current/committed cells, health/armor/
shield, slow/freeze/regen state, tower cooldowns, projectile kinds/positions/
lifetimes/impact/travel/hit counts, lives and gold. These are finite recordings,
not a proof of every possible game state. The existing natural balance tests also
retain their prior seed-specific defeat waves.

## Verification and reproduction

```sh
python3 tests/run_checks.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64
```

The optimization suite compares spatial queries to ordered linear scans after
teleports, tree reentry, death, freeing and rotated/nonuniform parent transforms.
It compares swept tower-hit fractions against a full scan, and flood-fill
reachability against real A* for every cell of 12 randomized boards. It checks
provisional/rollback/sell path-cache invalidation, caller mutation isolation,
retired-index cleanup, extreme query bounds, and cached-art source hashes.
The normal suite also covers long-wave generation, repeated actor lifecycles,
layered damage, all towers, research, upgrades, restart and natural bot balance.

To reproduce a comparison without changing branches, extract the baseline to a
scratch directory with `git archive`, import it using the same Godot version,
and run:

```sh
python3 tests/compare_performance.py --godot /path/to/godot \
  --baseline /tmp/td-baseline --candidate . --out /tmp/td-performance
# With a working graphics display, add --rendered --waves 60.
# Add --no-preview to measure gameplay without the continuous-hover workload.
```

Both checkouts must already be imported. The comparison runner uses isolated XDG
profile/cache directories, installs the identical temporary benchmark script in
each checkout, removes it afterwards, rejects logged engine/script errors, and
fails if the combat digests differ. JSON includes runtime source hashes.

Regenerate artwork after changing its procedural sources:

```sh
godot --path . --rendering-method gl_compatibility --audio-driver Dummy \
  --script res://tools/bake_combat_art.gd
```

Baking needs a real renderer; normal headless tests use the committed PNGs. The
baker records source hashes in `assets/generated/art_manifest.json`; tests catch
stale art or mismatched animation layouts. Reimport after regeneration.

For a manual check, open `project.godot` in Godot 4.7.2 and press F5. In a dense
late-wave maze, move a build preview over open/occupied/protected tiles, build and
sell during combat, mix all five tower types, and watch cannon obstruction,
layered bars, freeze/slow, research pauses and restart confirmation. The controls
and saved progression format are unchanged.
