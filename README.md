# Unnamed TD Game — Earned Progression (v0.6)

Godot **4.7.2 Stable**, GDScript, original vector artwork, no plugins or external assets. Open the repository-root `project.godot` and press **F5**. Development is on **Codex-Workspace**.

[Artwork, gameplay and branching research previews](docs/visual-overhaul/README.md) · [Advanced bot and progression balance](docs/progression-balance/README.md)

## Playing

Start with **200 gold and 10 lives**. Build a maze without blocking the entrance, exit or any living enemy's committed waypoint. The map remains a **40 × 24 grid**, with 32 px cells, a 1280 × 768 board and a 1600 × 900 logical window.

- Select a tower in the fixed build palette, then left-click a valid tile. Click a placed tower to manage it.
- Right-click / Escape / **Clear** cancels building or selection. Escape also closes research.
- **Start next wave** launches a wave manually. **Auto-start waves** starts later waves automatically, waiting for research and restart dialogs. Wave 1 always starts manually; Restart resets auto-start off.
- **Research lab** opens between waves and automatically after every fifth clear. Hover an icon for its name, cost, requirement and effect; click the icon to buy. Keyboard focus also reveals information and follows the scrolling graph.
- **Sell** refunds **50% of construction**, excluding upgrade spending. **Restart run** asks for confirmation, pauses combat while deciding, and preserves diamonds/research.
- The sidebar and footer have fixed hit areas: status, counter and selection changes cannot move Range or Sell under a stationary cursor.

## Monsters and combat presentation

The five existing stat archetypes now have distinct illustrated silhouettes, contrasting highlights, heavy outlines, shadows and animated limbs:

| Monster | Existing archetype | Base health / speed / gold | Traits and silhouette |
| --- | --- | --- | --- |
| Ember Imp | Grunt | 45 / 60 / 12 | Horns, fangs, curled tail, ember-colored skin |
| Skitterfang | Runner | 30 / 90 / 9 | Six jointed legs, amber segmented shell, mandibles |
| Ironback Ogre | Armored | 105 / 40 / 24 | Heavy plating, shoulder spikes, illuminated visor; 45 base armor |
| Mire Shaman | Regenerator | 68 / 52 / 20 | Green hood, roots, crystal staff; regenerates 3 HP/s after 2 seconds without damage |
| Void Wraith | Shielded | 80 / 66 / 22 | Crown, claws, spectral tails; 30 base shield |

Small perpendicular **render-only** offsets help distinguish overlapping monsters without changing their movement coordinates, target positions or placement protections. Their lower health bars keep fixed vertical positions when defenses break.

Damage layers remain **purple shield → white armor → green health**. A hit affects only the highest remaining pool; overkill never spills into the next layer. Armor is destructible plating. Each tower has separate health, armor and shield damage stats shown in its selected card. Nonpositive damage cannot bypass a protected layer.

## Five tower types

All towers use carved stone bases, metal fittings and distinct weapon silhouettes. Prices and initial combat values:

| Tower | Build / refund | Health / armor / shield damage | Target range | Fire interval | Attack |
| --- | --- | --- | ---: | ---: | --- |
| Sentinel (regular tower) | 60 / 30 | **15 / 24 / 8** | 112 px | 0.8 s | Aimed shot, rotating barrel, recoil, muzzle flash and brief tracer |
| Tesla | 110 / 55 | **12 / 6 / 24** | 80 px | 1.1 s | Jagged circular lightning discharge; every enemy in range is damaged once per pulse |
| Mortar | 160 / 80 | **55 / 77 / 33** | 280 px | 2.4 s | Shell arcs over towers to a fixed ground destination; 64 px area damage on landing |
| Ice | 100 / 50 | **8 / 4 / 10** | 136 px | 1.0 s | Homing icicle at 340 px/s; slows 35% for 2 seconds on impact |
| Cannon | 150 / 75 | **42 / 67 / 21** | 176 px | 1.6 s | Ball at 300 px/s; pierces enemies once each, travels 320 px, stops at the first friendly tower |

Mortar shells have a 0.45–1.5 second flight, scaled by distance. They continue to the landing point if the original target dies, and can miss moving targets. Area damage occurs once, followed by a cosmetic blast. Icicles expire if their target dies. Cannon collision sweeps its full segment, including the ball radius, so large frame steps cannot tunnel through enemies or towers. Collision order respects the nearest tower: targets beyond it receive no damage. A tower constructed during flight can block a ball; a sold tower stops blocking it.

In-flight projectiles snapshot damage and control effects at launch. They survive selling their source, but wave completion/defeat/restart clears them so a previous wave cannot damage the next. Restart confirmation pauses all projectiles with the board. No permanent source/target object references are retained by a projectile.

## Mixed upgrades: five total, or six with mastery

Each tower type needs **its own training** in research before any gold upgrades. Once trained, mix **Damage, Range, Firing speed and researched Unique** upgrades freely, up to **five total purchases per tower**. For example, 2 Damage + 2 Range + 1 Speed uses all five slots. There are no competing-track locks.

**Mastery research for each type unlocks its sixth slot**, immediately affecting placed towers and future construction. A seventh purchase is always rejected. Unique purchases share this same budget; they are not extra free levels. The next price depends on the total number of purchases, not category:

| Tower | Prices for purchases 1–6 | Damage purchase | Range purchase | Unique purchase |
| --- | --- | --- | --- | --- |
| Sentinel | 60, 100, 160, 240, 360, **520** | +12 base HP damage | +24 px | +8 base damage and +15 concentrated armor damage |
| Tesla | 80, 130, 200, 300, 450, **650** | +9 base damage | +12 px | +4 base damage; stronger 0.8 s slow |
| Mortar | 100, 160, 240, 350, 500, **720** | +22 base damage | +32 px | +10 base damage, +8 px blast radius |
| Ice | 70, 110, 170, 250, 370, **540** | +6 base damage | +20 px | +2 base damage, +3 percentage points freeze chance, +0.08 s freeze |
| Cannon | 90, 145, 220, 320, 470, **680** | +16 base damage | +24 px | +6 base damage, +36 px travel |

Each firing-speed purchase multiplies the interval by **0.82**. Damage purchases also increase derived armor/shield damage according to each tower's specialization. Permanent engineering applies before those derived stats are rounded; armor/shield specialization applies afterward. Range and speed passives apply to the combined tower stats. Purchases can shorten an existing cooldown but never grant an immediate free shot.

Slows retain the strongest factor/longest duration without multiplying indefinitely. Ice freezes prevent movement for a bounded time, including correct partial-frame behavior when a freeze ends; the underlying waypoint reservation is retained. The base researched freeze chance is **8%**, rising only with paid Unique purchases, up to 26% with six such purchases. Freeze RNG is local to each tower and never changes the wave generator's random stream.

## Permanent research and saves

Earn **exactly one diamond per cleared wave**. A partial/defeated wave gives none. Duplicate completion callbacks cannot pay twice. Diamonds and all unlocks persist through restarting or reopening the game. Run gold, towers and gold upgrade levels reset.

The Archive has **40 branching icon nodes**, rooted at **Tesla Tower for 3 diamonds**. It is the sole initially eligible research. Icons show researched/available/locked states; node information appears only on hover/focus. Prerequisite lines scroll with the icons. Clicking locked, owned or unaffordable research cannot spend diamonds.

New tower branches and abilities:

| Research | Diamonds | Requires | Effect |
| --- | ---: | --- | --- |
| Mortar Tower | 7 | Tesla | Unlock mortar construction |
| Mortar Training | 8 | Mortar Tower | Enable its mixed upgrades |
| Volatile Payload | 10 | Mortar Training | +25% base blast radius; unlock Unique blast upgrades |
| Ice Tower | 5 | Tesla | Unlock ice construction |
| Ice Training | 6 | Ice Tower | Enable its mixed upgrades |
| Glacial Heart | 9 | Ice Training | 8% chance of 0.5 s freeze; unlock Unique freeze upgrades |
| Cannon Tower | 8 | Tesla | Unlock cannon construction |
| Cannon Training | 9 | Cannon Tower | Enable its mixed upgrades |
| Rifled Bore | 12 | Cannon Training | +50% cannonball travel; unlock Unique travel upgrades |
| Sentinel / Tesla / Mortar / Ice / Cannon Mastery | 12 / 14 / 16 / 14 / 18 | Respective type's training | Sixth upgrade slot for that type |

The previous 26 nodes remain compatible: type training, Piercing Rounds/Static Field, engineering I–III, armor/shield specialization I–II, optics I–II, rapid cycling I–II, gold boosts, slowdown/health nerfs and reduced armor/shields. Generic tower passives now cover **all five types**. All effects and prerequisite costs are defined in `scripts/skill_catalog.gd`.

Profile schema remains **1**. Existing diamond balances and old skill IDs load without a reset. The profile lives at **`user://progression.json`**, outside the repository. On Windows, use Godot **Project → Open User Data Folder** to locate it. Saves flush a temporary file before replacing the primary and retain a previous valid `.bak`. Corrupt primary data can recover from backup; invalid profiles are preserved, and failed purchases roll back. The HUD marks save errors and offers retry in research. Restart passes the same in-memory profile into the new scene.

Tests use isolated in-memory profiles and disposable files, never the player's saved profile.

## Endless waves and navigation

Post-wave-30 density from v0.4 remains: **152 enemies at wave 50**, **442 at wave 100**, and a safety plateau of **512 enemies from wave 110**. Spawn spacing shrinks as counts grow, while the first-to-last spawn window increases from about 44 seconds at wave 31 to 136 seconds at the plateau. Transit/combat adds further time. Composition, HP/defenses and movement speed vary by seeded run. Health/defense caps and bounded arithmetic remain in place.

Board owns AStarGrid2D occupancy and placement transactions. Every accepted tower preserves spawn-to-exit reachability and every living enemy's committed waypoint. In-flight enemies finish their current segment before replanning. The new towers, freezes and visual offsets preserve these protections. Selling opens routes without moving enemies.

The v0.6 durability multiplier is **min(8.5, 1 + 1.25 × max(0, wave − 5))**, applied to health, armor and shield before rounding. Waves 1–5 preserve the introduction; waves 6–11 build pressure on a fresh maze. Existing growth and safety caps still apply. This curve is shared by every run, independent of profile or attempt number. Permanent research retains its existing prices/effects.

The [progression balance report](docs/progression-balance/README.md) records natural campaigns, strategy comparisons and retained diamond/research results. The advanced bot extends a safe serpentine route, places weapons by route coverage and functionality, and weighs upgrades against further construction. The standard five-seed regression checks fresh expert placement loses around wave 10 and off-route placement loses within five. Historical [v0.3](docs/balance/README.md), [v0.4](docs/ui/README.md) and [v0.5](docs/visual-overhaul/README.md) measurements describe earlier balance curves.

## Files

- `scripts/main.gd`: authoritative run economy, phase, profile and scene wiring.
- `scripts/board.gd`, `enemy.gd`: grid safety, movement, layered damage, slow/freeze and monster rendering.
- `scripts/tower_catalog.gd`: five types' construction/combat/research defaults.
- `scripts/tower.gd`: mixed upgrade counts, tower passives, target selection and firing.
- `scripts/combat_projectile.gd`: shell/icicle/cannon flight, AoE and swept collision.
- `scripts/monster_art.gd`, `tower_art.gd`, `draw_kit.gd`: original procedural vector illustrations.
- `scripts/skill_catalog.gd`, `progression.gd`: permanent unlocks and atomic local saving.
- `scripts/skill_tree_menu.gd`, `research_graph.gd`, `research_icon.gd`: branching icons, prerequisite edges, hover information and purchase intents.
- `scripts/hud.gd`, `ui_style.gd`: stable controls, state display, confirmation and shared theme.
- `scenes/`: valid Godot main, enemy, tower and research scenes.
- `tests/`: automated regressions, natural reference/advanced bots, retained-profile campaign sweeps and optional rendered preview fixtures.

`.gd.uid` source files are committed. `.godot/` and Python caches are ignored. Preview documentation is excluded from game imports with `.gdignore`.

## Automated checks

Run with your actual Godot 4.7.2 Stable executable:

```sh
python3 tests/run_checks.py --godot /path/to/Godot_v4.7.2-stable_linux.x86_64
```

The standard-library runner imports the editor project, starts the game for 180 frames and executes **16 suites**. It rejects timeouts, nonzero exits, logged engine/script/leak errors, missing check counts and failed assertions. It uses isolated writable temporary Linux XDG directories without modifying HOME.

Coverage includes pathfinding/placement transactions, moving-enemy reroutes, economy, real HUD/restart input, persistent diamond accounting, 40-node research/save compatibility, layer-specific damage, mixed upgrade limits and per-type sixth slots. Suites also exercise real hover/click input on icon nodes, mortar flight/AoE, cannon piercing and first-tower collision, live tower construction/removal, ice slow/freeze timing/chance, snapshot damage, dead targets/sold sources, projectile pause and wave cleanup, and repeated blast lifecycles.

Long-run regression includes **10,000 generated waves / 5,086,314 profiles**, **1,000 scheduled waves**, **300 scene lifecycle waves**, **100 build/remove cycles**, and **80 repeated projectile lifecycles**. Lifecycle fixtures intentionally inject resources or resolve actors; natural placement tests and retained-profile campaigns remain separate. The advanced-bot suite checks safe maze completion, actual gold/research transactions, sparse slow coverage and a real cannon shot through the entrance lane. Rendering checks are separate from headless tests. Optional long campaigns use `tests/sweep_campaigns.py`; see the progression report for commands, seeds, outcomes and wave-cap limitations.

## Manual F5 checks

- Open `project.godot` in 4.7.2 Stable, press F5 and resize the window. Verify five stable build controls and readable monster silhouettes in crowded waves.
- Open research. Only Tesla can be purchased first, for 3 diamonds. Hover icons for details, leave to hide them, and click an eligible icon once to buy.
- Unlock each new tower, build it, then purchase its training. Mix Damage, Range and Speed on one tower; stop at five. Research that type's Mastery, buy a sixth, and verify a seventh is blocked.
- Check Tesla's circular lightning; mortar shells landing with an area blast; icicles slowing/freezing; cannonballs piercing enemies but stopping against a tower. Build/sell a tower in a cannonball's path.
- Try Volatile Payload, Glacial Heart and Rifled Bore, including their gold Unique upgrades. Inspect selected-tower/button tooltips for current specialization.
- Hover/click research without leaking input to the board. Keep the cursor on Range over a wave clear: it must stay on Range, with Sell separate.
- Open Restart during projectile flight, cancel and resume; then confirm a restart. Diamonds/research must persist while every run actor and projectile resets.
- Verify every fifth cleared wave opens research, auto-start waits for it, and defeat awards no partial-wave diamond. Check Output/Debugger for errors.

Linux software-OpenGL previews and automated checks are recorded in the [visual overhaul report](docs/visual-overhaul/README.md). Windows F5 acceptance and export were not run.
