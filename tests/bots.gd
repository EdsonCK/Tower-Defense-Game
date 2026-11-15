extends RefCounted
## Scripted players for balance tests. Each bot spends between waves only through Main's
## public API (try_buy_tower / try_upgrade_tower / try_unlock_skill), exactly like a
## player clicking the UI, and a run is simulated deterministically by manual stepping.
##
##   good    - plays strategically:
##             * treats every entrance's route to the gate separately: a tower's
##               "coverage" of a route is how many of that route's tiles are in range
##               (tiles near the exit and after crossroads count for several routes);
##             * reads the next wave's shield/armor/health mix and tracks how fast the
##               defense strips each layer on each route;
##             * every option - a new tower of any type on any spot, or any upgrade on any
##               tower - is valued by how much it shortens the time to strip the wave on
##               the routes (weak routes dominate, so none is left open), per gold, and the
##               best affordable option is bought until money runs out (Teslas appear when
##               shields are the bottleneck, Cannons for armor);
##             * buys skills in a sensible order.
##   random  - Basic towers on random free tiles, no skills, no upgrades.

const SKILL_PRIORITY: Array[String] = [
	"tesla", "cannon", "basic_upgrades", "bounty_1", "fortify", "hollow_point", "cannon_upgrades",
	"tesla_upgrades", "weaken_1", "war_chest", "sharpen", "armor_breaker", "cripple", "basic_pierce",
	"tesla_static", "cannon_shrapnel", "overclock", "shield_breaker", "weaken_2", "bounty_2",
	"basic_veteran", "tesla_capacitor", "fortify_2", "rust", "focus_fire", "salvage",
	"cannon_mastery", "basic_mastery", "tesla_mastery", "dampen", "head_start", "diamond_mine", "annihilator",
]
## Only the most exposed towers are considered for upgrades each step (keeps bots fast).
const UPGRADE_CANDIDATES: int = 14

var kind: String
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Candidate build spots considered per route (plus the same number overall).
const SPOTS_PER_ROUTE: int = 3

var _cache_half_width: int = -1
var _routes: Array[Dictionary] = []  # per entrance: {path cell: true} for its route
var _path_routes: Dictionary = {}    # path cell -> Array[int] of routes through it
var _coverage: Dictionary = {}       # range (int) -> {cell: PackedFloat32Array per route}
var _mix: Dictionary = {}            # layer -> fraction of the next wave's hit points
var _tower_coverage: Dictionary = {}  # tower -> coverage at its current range
var _defense: Array[Dictionary] = []  # per route: layer -> damage rate on that route


func _init(bot_kind: String, seed_value: int = 1) -> void:
	kind = bot_kind
	rng.seed = seed_value


## Simulates waves until defeat or `max_wave`; returns the last wave reached.
## `stepper` is a Callable(main, dt) that advances the game by one tick.
func play(main: Node2D, max_wave: int, stepper: Callable) -> int:
	var wm: WaveManager = main.wave_manager
	while not main.is_game_over() and wm.current_wave < max_wave:
		spend(main)
		main._on_start_wave_pressed()
		var guard: int = 0
		while wm.is_wave_active() and not main.is_game_over() and guard < 20 * 60 * 20:
			stepper.call(main, 0.05)
			guard += 1
		if main.is_skill_menu_open():
			spend_skills(main)
			main.close_skill_menu()
	return wm.current_wave


func spend(main: Node2D) -> void:
	match kind:
		"good":
			spend_skills(main)
			_spend_good(main)
		"random":
			_spend_random(main)


func spend_skills(main: Node2D) -> void:
	if kind != "good":
		return
	var bought: bool = true
	while bought:
		bought = false
		for id: String in SKILL_PRIORITY:
			if main.try_unlock_skill(id):
				bought = true
				break


func _spend_random(main: Node2D) -> void:
	var cells: Array[Vector2i] = main.board.buildable_cells()
	var attempts: int = 0
	while main.currency >= TowerTypes.cost(TowerTypes.BASIC) and attempts < 50 and not cells.is_empty():
		attempts += 1
		main.try_buy_tower(cells[rng.randi_range(0, cells.size() - 1)], TowerTypes.BASIC)


# --- Strategic bot ---------------------------------------------------------------------

func _spend_good(main: Node2D) -> void:
	_refresh_map_cache(main)
	_mix = _next_wave_mix(main)
	_tower_coverage.clear()
	_defense = []
	for i in _routes.size():
		_defense.append({"shield": 0.0, "armor": 0.0, "health": 0.0})
	for tower: Tower in main._towers_by_cell.values():
		_add(_defense, _rates(_stats_of(tower), _coverage_of(main, tower)), 1.0)
	for guard in 400:
		var best: Dictionary = _best_option(main)
		if best.is_empty():
			return
		var done: bool = false
		if best["kind"] == "build":
			done = main.try_buy_tower(best["cell"], best["type"])
		else:
			done = main.try_upgrade_tower(best["tower"], best["path"])
			_tower_coverage.erase(best["tower"])
		if not done:
			return
		_add(_defense, best["delta"], 1.0)


## Best affordable action: the one that most reduces the time the defense needs to strip
## the next wave's shields, armor and health on every route, per gold spent. Specialists
## (Teslas vs shields, Cannons vs armor) become worth buying exactly when that layer is
## the bottleneck, and an uncovered route is the worst bottleneck of all.
func _best_option(main: Node2D) -> Dictionary:
	var best: Dictionary = {}
	var best_value: float = 0.0
	var now: float = _clear_time(_defense)
	for type_id: String in TowerTypes.ORDER:
		var cost: int = TowerTypes.cost(type_id)
		if not main.skills.is_tower_unlocked(type_id) or main.currency < cost:
			continue
		var stats: Dictionary = _hypothetical(main, type_id, Tower.UpgradePath.NONE, 0, Tower.UpgradePath.NONE)
		for spot: Array in _candidate_spots(main, stats["range"]):
			var delta: Array[Dictionary] = _rates(stats, spot[1])
			var value: float = (now - _clear_time_with(delta)) / cost
			if value > best_value:
				best_value = value
				best = {"kind": "build", "type": type_id, "cell": spot[0], "delta": delta}
	for tower: Tower in _top_towers(main):
		var cost: int = tower.next_upgrade_cost()
		if cost < 0 or cost > main.currency:
			continue
		var before: Array[Dictionary] = _rates(_stats_of(tower), _coverage_of(main, tower))
		var paths: Array[Tower.UpgradePath] = tower.available_paths()
		if tower.upgrade_path != Tower.UpgradePath.NONE:
			paths = [tower.upgrade_path]
		for path: Tower.UpgradePath in paths:
			if not main.is_path_unlocked(tower.tower_type, path) or not tower.can_upgrade(path):
				continue
			var after: Dictionary = _hypothetical(main, tower.tower_type, tower.upgrade_path, tower.upgrade_level, path)
			var delta: Array[Dictionary] = _rates(after, _coverage_for_range(tower.position, after["range"]))
			_add(delta, before, -1.0)
			var value: float = (now - _clear_time_with(delta)) / cost
			if value > best_value:
				best_value = value
				best = {"kind": "upgrade", "tower": tower, "path": path, "delta": delta}
	return best


## Per-route, per-layer damage rate a tower contributes (damage/s x route coverage).
func _rates(stats: Dictionary, coverage: PackedFloat32Array) -> Array[Dictionary]:
	var mult: float = 1.0 / stats["cooldown"]
	if stats["area"]:
		mult *= 1.8   # usually several enemies in a Tesla's radius
	if stats["splash"] > 0.0:
		mult *= 1.0 + stats["splash"] / 100.0
	if stats["slow"] > 0.0:
		mult *= 1.0 + stats["slow"]
	var out: Array[Dictionary] = []
	for route in coverage.size():
		var rates: Dictionary = {}
		for layer: String in TowerTypes.LAYERS:
			rates[layer] = float(stats["damage"][layer]) * mult * coverage[route]
		out.append(rates)
	return out


## Average over routes (enemies split across entrances) of the time to chew through one
## unit of the next wave's layer mix. A route with little coverage dominates the total.
func _clear_time(defense: Array[Dictionary]) -> float:
	var total: float = 0.0
	for route: Dictionary in defense:
		for layer: String in _mix:
			total += _mix[layer] / maxf(route[layer], 0.01)
	return total / maxf(1.0, defense.size())


func _clear_time_with(delta: Array[Dictionary]) -> float:
	var combined: Array[Dictionary] = []
	for route: Dictionary in _defense:
		combined.append(route.duplicate())
	_add(combined, delta, 1.0)
	return _clear_time(combined)


static func _add(into: Array[Dictionary], delta: Array[Dictionary], sign: float) -> void:
	for i in mini(into.size(), delta.size()):
		for layer: String in delta[i]:
			into[i][layer] = into[i].get(layer, 0.0) + delta[i][layer] * sign


## Stats of a tower of `type_id` at (`path`, `level`) after one more level of `next_path`
## (or a fresh tower if `next_path` is NONE), with the current skill and biome modifiers.
func _hypothetical(main: Node2D, type_id: String, path: Tower.UpgradePath, level: int, next_path: Tower.UpgradePath) -> Dictionary:
	var probe: Tower = Tower.new()
	probe.configure(type_id)
	main._apply_tower_modifiers(probe)
	for i in level:
		probe.apply_upgrade(path)
	if next_path != Tower.UpgradePath.NONE:
		probe.apply_upgrade(next_path)
	var stats: Dictionary = _stats_of(probe)
	probe.free()
	return stats


func _stats_of(tower: Tower) -> Dictionary:
	return {
		"damage": tower.damage, "cooldown": tower.cooldown, "range": tower.attack_range,
		"area": tower.is_area(), "slow": tower.slow_amount, "splash": tower.splash_radius,
	}


func _next_wave_mix(main: Node2D) -> Dictionary:
	var totals: Dictionary = {"shield": 0.0, "armor": 0.0, "health": 0.0}
	var wave: int = main.wave_manager.current_wave + 1
	var counts: Dictionary = main.wave_manager.preview_next_wave()
	for type_id: String in counts:
		var entry: Dictionary = WaveGenerator.make_entry(type_id, wave)
		for layer: String in totals:
			totals[layer] += float(entry.get(layer, 0.0)) * counts[type_id]
	var sum: float = totals["shield"] + totals["armor"] + totals["health"]
	for layer: String in totals:
		totals[layer] = totals[layer] / maxf(sum, 1.0)
	return totals


## Routes (entrance -> gate) of the current window.
func _refresh_map_cache(main: Node2D) -> void:
	var board: Board = main.board
	if board.half_width == _cache_half_width:
		return
	_cache_half_width = board.half_width
	_routes.clear()
	_path_routes.clear()
	_coverage.clear()
	for entrance: Vector2i in board.entrances():
		var route: Dictionary = {}
		for cell: Vector2i in board.layout.route_from(entrance):
			route[cell] = true
			if not _path_routes.has(cell):
				_path_routes[cell] = []
			(_path_routes[cell] as Array).append(_routes.size())
		_routes.append(route)


## The most promising free spots for a tower with `tower_range`: the best few for each
## route plus the best few overall, as [cell, coverage] pairs.
func _candidate_spots(main: Node2D, tower_range: float) -> Array:
	var key: int = roundi(tower_range)
	if not _coverage.has(key):
		_coverage[key] = _scatter_coverage(main, tower_range)
	var table: Dictionary = _coverage[key]
	var picks: Dictionary = {}
	for route in _routes.size() + 1:
		var ranked: Array = []
		for cell: Vector2i in table:
			var cov: PackedFloat32Array = table[cell]
			var score: float = _sum(cov) if route == _routes.size() else cov[route]
			if score > 0.0:
				ranked.append([score, cell])
		ranked.sort_custom(func(a: Array, b: Array) -> bool: return a[0] > b[0])
		var taken: int = 0
		for item: Array in ranked:
			if taken >= SPOTS_PER_ROUTE:
				break
			if main.board.is_buildable(item[1]):
				picks[item[1]] = true
				taken += 1
	var spots: Array = []
	for cell: Vector2i in picks:
		spots.append([cell, table[cell]])
	return spots


static func _sum(values: PackedFloat32Array) -> float:
	var total: float = 0.0
	for v: float in values:
		total += v
	return total


## For every cell near the path: how many tiles of each route are within range.
func _scatter_coverage(main: Node2D, tower_range: float) -> Dictionary:
	var table: Dictionary = {}
	var reach: int = ceili(tower_range / GameConfig.CELL_SIZE)
	for path_cell: Vector2i in _path_routes:
		var center: Vector2 = Board.cell_to_world(path_cell)
		for dy in range(-reach, reach + 1):
			for dx in range(-reach, reach + 1):
				var cell: Vector2i = path_cell + Vector2i(dx, dy)
				if Board.cell_to_world(cell).distance_to(center) > tower_range or not main.board.in_window(cell):
					continue
				if not table.has(cell):
					var empty: PackedFloat32Array = PackedFloat32Array()
					empty.resize(_routes.size())
					table[cell] = empty
				var cov: PackedFloat32Array = table[cell]
				for route: int in _path_routes[path_cell]:
					cov[route] += 1.0
				table[cell] = cov
	return table


func _coverage_for_range(position: Vector2, tower_range: float) -> PackedFloat32Array:
	var cov: PackedFloat32Array = PackedFloat32Array()
	cov.resize(_routes.size())
	for path_cell: Vector2i in _path_routes:
		if Board.cell_to_world(path_cell).distance_to(position) <= tower_range:
			for route: int in _path_routes[path_cell]:
				cov[route] += 1.0
	return cov


func _coverage_of(main: Node2D, tower: Tower) -> PackedFloat32Array:
	if not _tower_coverage.has(tower):
		_tower_coverage[tower] = _coverage_for_range(tower.position, tower.attack_range)
	return _tower_coverage[tower]


## The towers that cover the most route tiles (the only ones worth upgrading first).
func _top_towers(main: Node2D) -> Array[Tower]:
	var towers: Array[Tower] = []
	for tower: Tower in main._towers_by_cell.values():
		if tower.next_upgrade_cost() > 0:
			towers.append(tower)
	towers.sort_custom(func(a: Tower, b: Tower) -> bool: return _sum(_coverage_of(main, a)) > _sum(_coverage_of(main, b)))
	return towers.slice(0, UPGRADE_CANDIDATES)
