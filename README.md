# Unnamed TD Game

As-of-yet unnamed tower defense made in Godot, mostly written with AI. It draws on Rogue Tower and Sir, We Have an Orc Problem. Built for **Godot 4.7.2 stable** in GDScript.

**The game:**
- **The map:** a winding, fixed path network leads from several entrances, through crossroads, to a single gate at the center, past lakes and scenery. Every run (and every Restart) generates a different map.
- **Towers** go beside the path, never on it.
- **Growth:** the map grows a little after every wave, revealing more path and new entrances.
- **Biomes:** every 10 waves the land changes. Each biome has its own textured ground, lakes (water, oasis, ice, lava or bog), scenery and ambient particles, and buffs one tower type in particular.
- **Enemies** carry stacked shield, armor and health layers, and three tower types each specialize against one layer.
- **Bosses:** every 15th wave is a lone Colossus with enormous health bars.
- **Progression:** clearing waves earns **diamonds**, which unlock a permanent 33-skill tree.
- **Camera:** zoom in and pan around the map; fully zoomed out shows the whole map.
- **Presentation:** a procedural terrain shader, procedurally drawn and animated scenery, towers and enemies, and generated sound effects and music (no external assets).

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
| Place tower | **Left-click** a free tile beside the path. In build mode a tile grid fades in; the hovered tile is green when valid and red when not (the path, the gate and lakes are never valid), and a dashed circle shows the new tower's range. Build mode stays on until you cancel or can't afford another tower. |
| Select a tower | **Left-click** a tower (outside build mode). The SELECTED TOWER card shows its damage per layer and its upgrades. |
| Upgrade / sell | The four upgrade buttons and **Sell** in the SELECTED TOWER card |
| Cancel build mode / deselect | **Right-click**, **Esc**, **Cancel build**, or click empty ground |
| Launch next wave | **Start Wave** |
| Auto-start | **Auto-start waves** toggle: the next wave starts 3 s after the previous one is cleared. The countdown is shown on the toggle and pauses while any menu is open. Wave 1 is always started by you. The setting is saved. |
| Skill tree | **Skill Tree** button (any time). It also opens after every 5th wave. The game pauses while it's open; **Continue** or **Esc** closes it. |
| New run | **Restart** asks "Are you sure?" first; **Esc** or **Cancel** backs out. Diamonds and skills are kept. |
| Zoom | **Mouse wheel** (zooms toward the cursor) or **+ / -**. Fully zoomed out shows the whole map; you can zoom in up to 3×. |
| Pan | **Middle-mouse drag**, or **WASD / arrow keys** while zoomed in. The view never leaves the map. |
| Show the whole map | **Home** |
| Music / sound on/off | **Music** and **Sound** buttons next to Restart. Saved between sessions. |
| Toggle fullscreen | **F11** |

## Rules

Tuning lives in:
- `scripts/game_config.gd`: economy, map size and growth, waves, health scaling, diamonds;
- `scripts/tower_types.gd`: tower stats;
- `scripts/enemy_types.gd`: enemy stats;
- `scripts/biomes.gd`: biome art and buffs;
- `scripts/skill_tree.gd`: skills.

- Start with 200 gold and 10 lives (more with skills).
- Kills pay gold. Each cleared wave pays a gold bonus (30 + 5 per wave number) and **1 diamond**. Escaped enemies cost lives and pay nothing.
- **Endless:** the run ends when lives reach 0.

### The map

- **The path network** is generated per run from the run seed (shown in the panel). Each new run and each Restart picks a fresh random seed, so **the pathing is different every time**.
  - It is a tree of 1-tile-wide, winding paths that all lead to a **single gate** (the exit) at the center.
  - Each map also rolls its own character: the angle the two main branches leave the gate, how twisty the paths are (how long straight stretches run), and how many side branches split off (4-6). A straight stretch (counting through a crossroads) is cut off after 8 tiles whenever the path has another way to go.
  - Branches run outward to **entrances** (swirling rifts in rings of standing stones) and split off each other, which creates **crossroads**.
  - **Lakes:** 6-10 irregular lakes are scattered over open land, always at least 3 steps from any path tile, so they shape the land without taking the best tower spots. Their look follows the biome (pond, oasis, frozen lake, lava pool, bog). **Towers can't be built in a lake.**
  - **The gate** is a small stone keep on a round cobbled plaza, and the road is cobbled for the last few tiles before it.
  - Walking toward the gate never takes an enemy back outward, so routes never leave the visible map.
- **Towers** can be built on any free tile except the path, the gate and lakes.
- **The map grows after every wave.** It starts at 23×13 tiles and gains a ring each wave until it reaches 61×37 (wave 20). The fully zoomed-out view always fits the whole map; if you are zoomed in, your zoom level is kept as it grows.
  - Growing reveals more path, so routes get longer. The fog over the unexplored land rolls back smoothly to reveal the new ring.
  - Branches that split off further out appear as **new entrances**: 2-4 at the start, 6-8 on the full map.
  - Towers keep their tiles as the map grows.
- **Enemies** are split across the entrances (a pack always shares one entrance) and walk their route to the gate. Single-target towers shoot the enemy in range that is **closest to the gate**.
- **Placement strategy:** tiles near the gate and just after crossroads see the most traffic; outer branches only see their own entrance's share.

### Biomes

The biome changes every 10 waves (after waves 10, 20, ...) and cycles after the sixth. Every biome uses the same art style (soft-shaded shapes lit from the top left, soft shadows) and **the same path palette**; the ground, lakes, scenery and ambient particles change. When a biome changes, the land cross-fades into the new palette. Each gives every tower a small buff and its **favored tower** a stronger one.

| Waves | Biome | Look | All towers | Favored tower (total) |
|---|---|---|---|---|
| 1-10 | Meadow | grass rippling in the wind, tiny flowers, trees, bushes, flower clumps, grass tufts; blue ponds with lily pads and cattails; pollen and butterflies | +10% range | **Basic** +25% range |
| 11-20 | Desert | wind-rippled sand and gravel flats, cacti, tumbleweeds, bones; turquoise oases ringed by palms; blowing dust | +5% hit speed | **Cannon** +20% hit speed |
| 21-30 | Tundra | twinkling snow with blue drifts, snowy pines, ice crystals; frozen lakes with cracked, glinting ice; falling snow | +5% damage | **Tesla** +25% damage |
| 31-40 | Volcanic | basalt plates with pulsing lava cracks, vents, charred stumps, obsidian; churning lava pools with cooling crust; rising embers | +5% damage | **Cannon** +25% damage |
| 41-50 | Swamp | wet mud with a slow sheen and moss, reeds, mushrooms, mossy logs; murky bogs with scum and bubbles; fireflies | +10% range | **Tesla** +30% range |
| 51-60 | Autumn Forest | leaf-littered earth, orange and red trees, leaf piles, pumpkins; dark ponds; falling leaves | +5% hit speed | **Basic** +20% hit speed |

**How the map is drawn:**
- **One terrain shader** (`shaders/terrain.gdshader`) paints the ground, path, plaza, lakes, cloud shadows, build grid and fog in a single pass. All its texture is procedural (noise, fbm, voronoi), so there are no image assets and the detail stays sharp at any zoom. It reads a tiny one-pixel-per-tile map of the path, lakes and cobbles, sampled smoothly so path corners and shorelines come out rounded and organic.
- **The path** is packed dirt with wheel ruts, pebbles and a darker, sunken rim; the grass beside it is shaded by the bank.
- **Water** ripples and glints, **lava** churns under cooling crust, **ice** shows cracks and a sliding sheen, and **bogs** swirl and bubble. Lava pools light up the rocks around them.
- **Cloud shadows** drift slowly across the map (lava glows through them).
- **Beyond the map's edge** the unexplored land is dimmed and covered by drifting fog, with a soft vignette inside the edge.
- **Scenery** (trees, rocks, cacti, reeds and so on) is drawn on its own layer from stable per-tile hashes, so it never flickers. It never sits on the path, beside it, on a tower or in a lake; lakeshores get shore plants. Placing a tower clears the scenery under it.
- **Ambient particles** drift over the map (see the table), more of them on a bigger map, up to 90.
- **Build mode** fades in a tile grid over open ground, highlights the hovered tile and shows the new tower's range as a dashed circle.

The current biome and its buff are shown in the wave card. Buffs apply immediately to every tower, including ones you already built.

### Health layers and damage types

Enemies have up to three stacked bars above them:
- **purple shield** on top;
- **white armor** below it;
- **green health** at the bottom.

**Only the top non-empty bar takes damage**, and damage beyond what that bar has left is lost; it never spills into the next bar. An enemy dies when its health bar is empty. Every tower has a separate damage value against each layer, so mixing towers matters.

| Tower | Look | Cost | Attack | Damage (health / armor / shield) | Unique upgrade path |
|---|---|---|---|---|---|
| Basic | blue square | 60 | first enemy within 112 px, every 0.8 s | 15 / 8 / 8 (all-rounder) | **Piercing:** +100% armor damage per level |
| Tesla | purple hexagon | 80 | **every** enemy within 80 px, every 1.0 s | 10 / 3 / **24** (shield shredder) | **Static field:** slows 15% per level for 1.5 s |
| Cannon | orange turret | 110 | first enemy within 128 px, every 1.6 s | 20 / **48** / 4 (armor cracker) | **Shrapnel:** 50% splash damage, radius 40 → 72 px |

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

**The skill tree screen** shows each branch as a tinted lane with a header that counts how many of its skills you own (with a progress line), and a total "N / 33 skills unlocked" bar at the top. Every skill is a card with its own icon, its name and its cost:
- **owned** skills are filled with the branch color and marked OWNED with a check;
- skills you **can buy now** pulse with a gold glow;
- skills whose prerequisites are met but that you **can't afford yet** show their cost and "(need more)";
- **locked** skills are dimmed with a padlock.

Links between owned skills glow and carry flowing light. Hovering a card lifts it and shows a large icon, the description and what it needs in the info card. Unlocking plays a burst and a chime.

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
- **Enemy health:** every layer grows exponentially, (1 + 0.1·(w-1)) × 1.065^(w-1).
- **Unlocks:** new types unlock as waves progress.
- **Bosses:** every **15th wave** (15, 30, 45, ...) is a **boss wave**: a single **Colossus** arrives **alone**, with enormous stacked shield, armor and health bars drawn extra-wide above it. It is slow but costs **10 lives** if it reaches the gate. Its gold reward is a placeholder for now.
- **Count cap:** once the enemy count reaches its 320 cap (around wave 80), the spawn rate stops rising, so waves never get shorter.

### Enemy types

| Enemy | Look | Speed | Layers (base) | Bounty | Trait | From wave |
|---|---|---|---|---|---|---|
| Grunt | red diamond | 60 | health 45 | 12 | Baseline walker | 1 |
| Runner | yellow triangle | 100 | health 28 | 10 | Fast but fragile | 3 |
| Swarmling | small green dot | 78 | health 14 | 4 | Arrives in packs of 3-5 | 4 |
| Tank | purple square | 36 | armor 60 + health 90 | 28 | Heavy armor: bring Cannons; costs 2 lives | 5 |
| Mender | teal hexagon | 55 | health 70 | 18 | Regenerates 5% health per second | 7 |
| Splitter | orange ring | 50 | health 80 | 15 | Splits into 3 Swarmlings | 8 |
| Aegis | blue pentagon | 56 | shield 60 + health 50 | 20 | Energy shield: bring Teslas | 11 |
| Colossus (boss) | huge dark-red star, extra-wide bars | 26 | shield 190 + armor 290 + health 480 (×wave scaling) | 250 (placeholder) | Arrives alone; costs **10 lives** | every 15th |

**Looks and animation.** Every type keeps its silhouette (so you can read a wave at a glance) and adds character:
- shading, a ground shadow, and a walk cycle (bob and squash) that runs faster for quick enemies;
- eyes that look where the enemy is walking; Runners point their arrowhead along the path and leave speed streaks;
- Swarmlings flap their wings; Tanks roll on treads with a glowing visor; Menders pulse a healing aura; Splitters show the brood wiggling inside; the Colossus has horns, glowing eyes, a dark aura and a slowly turning body;
- **armor** is drawn as white plates around the body, a **shield** as a purple bubble with a travelling shimmer, and a **slow** as orbiting frost specks;
- hits flash the body white, and kills leave a short burst of shards in the enemy's color (bigger for the boss).

### Balance targets (checked by `tests/test_balance.gd`)

Balance is tuned against two scripted players in `tests/bots.gd`, on fixed seeds with a fresh save.

**The strategic bot:**
- treats each entrance's route to the gate separately: a tower's value on a route is how many of that route's tiles are in its range (tiles near the gate and after crossroads count for several routes);
- reads the next wave's shield/armor/health mix and tracks how fast its defense strips each layer **on each route**;
- each time, buys whichever option most shortens that time per gold: any tower type on any of the best spots, or any upgrade on any tower. A route with little coverage dominates the total, so no entrance is left open;
- buys skills in a sensible order.

As a result it covers every route, builds where routes merge, adds Teslas when shields are the bottleneck and Cannons for armor, and switches to upgrades once the best spots are taken.

| Strategy | Result |
|---|---|
| Random Basic towers, no skills or upgrades | defeated on waves 2-4 (test: by wave 10) |
| Strategic bot (roughly 430-780 towers of all three types, 140-290 upgrade levels) | defeated on waves 37-46 over 8 seeds (test: between 25 and 50 on two seeds) |

With bosses costing 10 lives, a Colossus that reaches the gate ends a run that has only the starting 10 lives, so boss waves are real checkpoints. The boss's pools were trimmed to match.

Permanent skills from earlier runs push a real player further. Run `tests/balance_report.gd` to print these numbers after tuning.

### Sound and music

All audio is synthesized by `tools/gen_audio.py` (Python + numpy) into `audio/*.wav`: no samples or downloaded assets. Re-run it after changing a sound.
- **Effects:** a shot sound per tower (Basic "pew", Tesla zap, Cannon boom), enemy pop, boss death, escape warning, wave-start horn, wave-clear chime, boss-arrival gong, build, upgrade, sell, error, skill unlock, defeat, and a soft click for every HUD button.
- **No noise wall:** each effect has a few voices and a minimum gap, so 200 towers firing at once still sound like a handful of shots.
- **Music:** a calm 30 s loop plays during a run. Boss waves crossfade to a driving boss loop, and the calm theme returns once the boss wave is cleared. Defeat stops the music.
- **Settings:** the **Music** and **Sound** buttons switch each off separately; the choice is saved to `user://progress_settings.json`.

### Tower animation

- **Basic** turrets turn to track their target, kick back when they fire, and send a tracer with a muzzle flash and an impact spark.
- **Tesla** coils glow brighter as they recharge, crackle when charged, and discharge flickering bolts into every enemy in range.
- **Cannons** swing their barrel onto the target, recoil hard, puff smoke and lob a shell that bursts on impact (with the shrapnel ring when upgraded).
- Animation is cheap: the turret is drawn once and only rotated or nudged for aiming and recoil, and the Tesla glow is only scaled and faded. Only the short shot effects redraw while they play.

### Performance

- **Game logic:** in a full real-time run to wave 33 (310 towers, 7 entrances), it averaged 7 ms per frame (p99 7 ms), measured headless. The occasional longer frames were the test bot's own planning, which doesn't exist in the real game.
- **Board redraw:** the board redraws only when it changes, such as placing a tower, the map growing or a new biome. A full-map redraw with 520 towers costs about 4 ms.
- **Animated art:** with 250 towers on the full map during wave 40, script processing (including the animations) takes about 3 ms per frame, measured headless. Enemy body animation redraws at 20 fps; movement itself stays smooth.
- **Terrain:** the ground, path, lakes, clouds and fog are one full-screen shader pass on the GPU. Animation (water, lava, clouds, particles, portals) costs no redraws on the CPU side except the small particle and portal layers. The scenery layer redraws only when the map, the biome or the towers change. It has only been tested here with a software renderer, so GPU cost on low-end integrated graphics is unmeasured.

## Project layout

```text
project.godot             main scene, 1600x900 window, canvas_items stretch, Compatibility renderer
scenes/main.tscn          Main → Audio, WaveManager, WindowFit, HUD/UILayout/Root(LeftColumn(BoardArea/Board(Towers, Enemies), BottomPanel), RightPanel)
scenes/enemy.tscn         Node2D + enemy.gd (drawn in code)
scenes/tower.tscn         Node2D + tower.gd (drawn in code)
scenes/skill_tree_menu.tscn  Control + skill_tree_menu.gd (full-screen modal)
scripts/game_config.gd    tuning constants only (class_name GameConfig)
scripts/tower_types.gd    tower type definitions: Basic, Tesla, Cannon (damage per layer)
scripts/skill_tree.gd     skill definitions, prerequisites, unlocked state and summed effects
scripts/skill_tree_menu.gd  modal skill tree UI built from the skill data (lanes, headers, animated links)
scripts/skill_node.gd     one drawn skill card (icon, state, glow, hover, unlock burst)
scripts/icons.gd          procedural icon glyphs (no image assets)
scripts/audio.gd          GameAudio: pooled, throttled sound effects, music crossfade, mute settings
scripts/confirm_dialog.gd "Are you sure?" modal (Restart, Reset progress)
scripts/ui_theme.gd       shared visual theme: colors, card/button/label styles
scripts/progress_store.gd permanent progress + settings saved as JSON (user://progress.json)
scripts/enemy_types.gd    enemy type definitions: stats, looks, traits, unlock wave
scripts/wave_generator.gd seeded endless wave generation and scaling formulas
scripts/main.gd           currency, lives, game state, purchases, upgrades, sales, selection, defeat, restart
scripts/map_layout.gd     seeded path-network generator (tree to one exit, 1 tile wide, windy), lakes, and queries
scripts/biomes.gd         biome definitions: ground palette, decorations, tower buffs
scripts/board.gd          visible window and growth, camera (fit, zoom, pan), placement rules, clicks, art layer stack
scripts/terrain.gd        feeds the terrain shader: per-tile map texture, biome palette cross-fades, grid, fog reveal
shaders/terrain.gdshader  ground, path, plaza, lakes, clouds, grid and fog in one procedural pass
scripts/decor_layer.gd    scenery placement rules and drawing (trees, rocks, cacti, reeds, lily pads, ...)
scripts/map_markers.gd    the gate keep and the animated entrance portals
scripts/atmosphere.gd     ambient particles per biome
scripts/enemy.gd          walks its route to the gate, layered pools, regen/split/slow, died/reached_exit (once each), animated art
scripts/death_fx.gd       short burst left where an enemy dies
scripts/tower.gd          targeting, cooldown, immediate-hit attack, upgrade path/levels, sell value, turret animation
audio/                    generated sound effects and music (WAV)
tools/gen_audio.py        synthesizes everything in audio/
scripts/wave_manager.gd   wave queue, spawn timer, unresolved-enemy count (incl. split children), completion
scripts/hud.gd            labels, buttons → intent signals, next-wave preview, selection panel, messages
scripts/window_fit.gd     fits/centers the OS window on its screen, re-centers after resize, F11 fullscreen
tests/test_base.gd        shared headless test harness and game-invariant checker
tests/test_map.gd         map generation rules, placement, path following, growth, zoom, clicks, biomes, run flow
tests/test_map_art.gd     lakes, terrain shader inputs, art layers, scenery rules, cross-fades, grid, particles, fog reveal
tests/test_gameplay.gd    wave generator, enemy types and traits, endless flow, upgrades, selling, selection
tests/test_stability.gd   randomized fuzzing and long-run simulations
tests/test_layout.gd      HUD layout guard: nothing may cover the board or leave the view
tests/test_skills.gd      diamonds, skill tree, persistence, Tesla, gated/unique upgrades, auto-start
tests/test_presentation.gd  sounds per event, music switching, mute/persist, tower and enemy animation, icons
tests/test_balance.gd     balance guard using scripted bots
tests/bots.gd             scripted players (strategic / random) used by balance checks
tests/balance_report.gd   tuning tool: prints how far each strategy gets
tests/run_all.sh          runs everything; fails on any test failure OR any script error
```

## Tests

Run everything from the project root with one command (pass your Godot executable; on Windows use Git Bash or WSL, or run the individual commands below):

```sh
tests/run_all.sh path/to/godot      # ~3-4 min
```

`run_all.sh` imports the project, runs a 180-frame startup check, then every suite. It fails if any check fails **or if any script error appears in the output**, so errors inside signal handlers can't slip through. Individual commands:

```sh
godot --headless --editor --path . --quit          # import once (builds the global class cache)
godot --headless --path . --quit-after 180         # runtime smoke test
godot --headless --path . --script res://tests/test_map.gd
godot --headless --path . --script res://tests/test_map_art.gd
godot --headless --path . --script res://tests/test_gameplay.gd
godot --headless --path . --script res://tests/test_skills.gd
godot --headless --path . --script res://tests/test_layout.gd
godot --headless --path . --script res://tests/test_presentation.gd
godot --headless --path . --script res://tests/test_stability.gd
godot --headless --path . --script res://tests/test_balance.gd
godot --headless --path . --script res://tests/balance_report.gd   # tuning report, not pass/fail
```

Tests never touch your real save file.

- **test_map** (10 seeds):
  - **map structure:** every path cell leads to the single gate; the path is exactly 1 tile wide (no touching runs, no 2×2 blocks); it is windy (20%+ of steps are turns, no straight run over 14); it never turns back outward;
  - **entrances and crossroads:** 2+ entrances at the start, never fewer as the map grows, 5+ and 3+ crossroads on the full map; routes never leave the window and no path is a dead stub; maps are reproducible per seed and differ between seeds;
  - **placement:** not on the path, the gate, outside the map or on an occupied tile;
  - **movement:** enemies from every entrance follow their route cardinally to the gate, never teleporting or backtracking;
  - **growth and zoom:** the map grows one ring per wave to 61×37 while towers keep their tiles; the map is centered and fully visible at every size; real clicks land on the right tile at every zoom;
  - **camera:** zoom never goes below the whole-map view or above 3×; zooming keeps the point under the cursor fixed; panning never shows past the map's edge; real mouse-wheel and middle-drag input works and clicks still hit the right tile while zoomed and panned; Home and a new run reset the view;
  - **new map every time:** 12 consecutive restarts give 12 different starting maps (and different path lengths);
  - **biomes:** 6 biomes with distinct art; changes every 10 waves and cycles; small global buff plus a stronger favored-tower buff, applied to towers and shown in the HUD;
  - **run flow and window:** defeat → restart gives a new seed, map and size; window-fit sizing.
- **test_map_art:**
  - lakes on every map, always 3+ steps from every path tile, under 10% of the land, reproducible per seed; towers can't be built in them and the message names the biome's lakes;
  - the art layers stack in order (Terrain, Decor, Markers, Overlay, Towers, Enemies, Atmosphere) and the terrain is a single shader pass whose inputs (path only inside the window, every lake, cobbles by the gate, the window rectangle) are correct, also after the map grows;
  - scenery never sits on the path, beside it, on a tower, in a lake or off the map; it is stable between redraws, a new tower clears it, and each biome brings its own;
  - biome changes cross-fade the palette, while a new run snaps straight back to the Meadow; the build grid fades in and out with build mode; every biome has its own particles, the count scales with the map, and particles stay over the map;
  - the fog rolls back smoothly when the map grows, and the shader exposes every uniform the game sets.
- **test_gameplay:**
  - **generator:** reproducible per seed, varies between seeds; 300 waves × 3 seeds have valid sizes, unlocked types, finite stats and rising difficulty; every 15th wave is exactly one boss with an enormous pool (20+ Grunts' worth), and no other wave has one;
  - **late waves:** past wave 30 they get much bigger and spawn faster, yet never get shorter (even at the 320-enemy cap);
  - **enemy types and layers:** distinct looks and stats; only the top layer takes damage and nothing spills over; the boss peels shield → armor → health; every trait;
  - **flow:** 30 consecutive waves with exact gold accounting and the 5-wave skill popup;
  - **towers:** upgrade rules, 50% refunds, selection UI;
  - **bosses:** an escaped boss costs 10 lives; bosses are drawn much larger.
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
- **test_presentation:**
  - all 16 sound effects and both music loops exist and load;
  - building, upgrading, selling, errors, wave start and clear, shots, kills and escapes each play their sound;
  - a boss wave sounds the gong and switches to the boss theme; the calm theme returns after it; defeat stops the music; restart brings it back;
  - 50 simultaneous shots play once; muting works from code and from the HUD buttons; settings persist across launches;
  - turrets turn to face their target and their shot animation plays out and stops; the Tesla glow tracks its recharge;
  - hits flash enemies; kills leave a burst on the board (not counted as an enemy) that frees itself; enemies turn to face along the path;
  - every procedural icon draws, and every skill has one.
- **test_stability:**
  - 6,000 randomized steps (all tower types on random tiles including the path, sells, every upgrade path, skill unlocks, opening and closing the skill tree, auto-start toggling, waves), checking every game invariant every 5 steps (no tower on the path, every enemy on the path and heading toward the gate, counters, gold, lives);
  - a 20-wave run by the strategic bot with invariant checks;
  - 25 mid-wave restarts.
- **test_balance:** random placement loses by wave 10; the strategic bot loses between waves 25 and 50 on two seeds, upgrades as well as builds, and uses every tower type.
