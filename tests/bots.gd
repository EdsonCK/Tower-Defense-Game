extends RefCounted
## Scripted players used by balance tests. Each bot spends between waves through Main's
## public API (try_buy_tower / try_upgrade_tower / try_unlock_skill), exactly like a
## player clicking the UI. A run is simulated deterministically by manual stepping.
##   good    - builds a serpentine maze (walls every 2 columns = 1-wide corridors, gaps at
##             alternating ends)
##             one wall at a time from the spawn side, puts Teslas at the turns and Cannons
##             every third wall cell, buys skills, then upgrades the towers that see the
##             most of the route.
##   random  - Basic towers on random valid tiles, no skills, no upgrades.
##   nomaze  - Basic towers lining the straight route, never forcing a detour.

const SKILL_PRIORITY: Array[String] = [
	"tesla", "cannon", "fortify", "basic_upgrades", "bounty_1", "hollow_point", "weaken_1",
	"cannon_upgrades", "sharpen", "tesla_upgrades", "war_chest", "armor_breaker", "cripple",
	"basic_pierce", "overclock", "weaken_2", "shield_breaker", "bounty_2", "tesla_static",
	"cannon_shrapnel", "basic_veteran", "tesla_capacitor", "fortify_2", "rust", "focus_fire",
	"salvage", "basic_mastery", "cannon_mastery", "tesla_mastery", "dampen", "head_start",
	"diamond_mine", "annihilator",
]

var kind: String
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _built: int = 0
## Good-bot tuning knobs (columns between maze walls, whether to place Teslas).
var wall_spacing: int = 2
var use_tesla: bool = true
var _plan: Array[Vector2i] = []
var _skipped: Dictionary = {}  # planned cells that were rejected (e.g. an enemy stood there)


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
		while wm.is_wave_active() and not main.is_game_over() and guard < 20 * 60 * 15:
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
		"nomaze":
			_spend_nomaze(main)


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
	var attempts: int = 0
	while main.currency >= TowerTypes.cost(TowerTypes.BASIC) and attempts < 200:
		attempts += 1
		main.try_buy_tower(Vector2i(rng.randi_range(0, 39), rng.randi_range(0, 23)), TowerTypes.BASIC)


func _spend_nomaze(main: Node2D) -> void:
	var cells: Array[Vector2i] = []
	for x in range(2, 38):
		cells.append(Vector2i(x, 11))
		cells.append(Vector2i(x, 13))
	for cell: Vector2i in cells:
		if main.currency < TowerTypes.cost(TowerTypes.BASIC):
			return
		if main.get_tower_at(cell) == null:
			main.try_buy_tower(cell, TowerTypes.BASIC)


func _spend_good(main: Node2D) -> void:
	if _plan.is_empty():
		_plan = _serpentine_plan()
	var guard: int = 0
	while guard < 1000:
		guard += 1
		var cell: Vector2i = _next_plan_cell(main)
		if cell == Board.NO_CELL:
			# Maze finished: put the gold into upgrades.
			if not _try_best_upgrade(main):
				return
			continue
		var type_id: String = TowerTypes.BASIC
		if use_tesla and main.skills.is_tower_unlocked(TowerTypes.TESLA) and _is_turn_cell(cell):
			type_id = TowerTypes.TESLA
		elif main.skills.is_tower_unlocked(TowerTypes.CANNON) and cell.y % 3 == 0:
			type_id = TowerTypes.CANNON
		if main.currency < TowerTypes.cost(type_id):
			return
		if main.try_buy_tower(cell, type_id):
			_built += 1
		else:
			_skipped[cell] = true


## Wall cells next to each wall's gap, where the route turns and enemies bunch up.
func _is_turn_cell(cell: Vector2i) -> bool:
	var wall_index: int = (cell.x - wall_spacing) / wall_spacing
	var gap_y: int = 0 if wall_index % 2 == 0 else GameConfig.GRID_ROWS - 1
	return absi(cell.y - gap_y) <= 2


## Vertical walls every `wall_spacing` columns with the gap at alternating ends. Walls are finished one
## at a time from the spawn side, each growing outward from the enemies' row, so every
## tower sits next to the route and each finished wall adds a long detour.
func _serpentine_plan() -> Array[Vector2i]:
	var plan: Array[Vector2i] = []
	var wall_index: int = 0
	for x in range(wall_spacing, GameConfig.GRID_COLUMNS - 2, wall_spacing):
		var gap_y: int = 0 if wall_index % 2 == 0 else GameConfig.GRID_ROWS - 1
		for y in GameConfig.GRID_ROWS:
			if y != gap_y:
				plan.append(Vector2i(x, y))
		wall_index += 1
	plan.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = a.x * 100 + absi(a.y - GameConfig.SPAWN_CELL.y)
		var db: int = b.x * 100 + absi(b.y - GameConfig.SPAWN_CELL.y)
		return da < db)
	return plan


func _next_plan_cell(main: Node2D) -> Vector2i:
	for cell: Vector2i in _plan:
		if main.get_tower_at(cell) == null and not _skipped.has(cell):
			return cell
	return Board.NO_CELL


## Upgrades the affordable tower covering the most route cells.
func _try_best_upgrade(main: Node2D) -> bool:
	var path: Array[Vector2i] = main.board.find_path(GameConfig.SPAWN_CELL, GameConfig.EXIT_CELL)
	var best: Tower = null
	var best_score: int = -1
	for tower: Tower in main._towers_by_cell.values():
		var cost: int = tower.next_upgrade_cost()
		if cost < 0 or cost > main.currency:
			continue
		var wanted: Tower.UpgradePath = _preferred_path(main, tower)
		if not main.is_path_unlocked(tower.tower_type, wanted) or not tower.can_upgrade(wanted):
			continue
		var score: int = _coverage(tower.position, tower.attack_range, path)
		if score > best_score:
			best_score = score
			best = tower
	if best == null:
		return false
	return main.try_upgrade_tower(best, _preferred_path(main, best))


func _preferred_path(main: Node2D, tower: Tower) -> Tower.UpgradePath:
	if tower.upgrade_path != Tower.UpgradePath.NONE:
		return tower.upgrade_path
	return Tower.UpgradePath.DAMAGE


static func _coverage(center: Vector2, tower_range: float, path: Array[Vector2i]) -> int:
	var count: int = 0
	for cell: Vector2i in path:
		if center.distance_to(Board.cell_to_world(cell)) <= tower_range:
			count += 1
	return count
