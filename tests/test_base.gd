extends SceneTree
## Minimal shared test harness (no external framework). Test scripts extend this file,
## override get_tests() and run headless:
##   godot --headless --path <project> --script res://tests/<file>.gd
## The process exits with code 0 only when every check passes.
## Frames are never iterated: enemies, towers and waves are stepped manually so every
## scenario is deterministic.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const TOWER_SCENE: PackedScene = preload("res://scenes/tower.tscn")
const EXIT: Vector2i = GameConfig.EXIT_CELL
const NONE: Array[Vector2i] = []
const TEST_SEED: int = 12345

var _checks: int = 0
var _failures: int = 0
var _current_test: String = ""


func _initialize() -> void:
	# Never read or write the player's real progress file from tests.
	ProgressStore.save_path = ""
	# Nodes added to root only receive _ready() once the tree is running, so start on the first frame.
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


## Overridden by each test script.
func get_tests() -> Array[Callable]:
	return []


func _run_all() -> void:
	var tests: Array[Callable] = get_tests()
	for test: Callable in tests:
		_current_test = test.get_method()
		var started: int = Time.get_ticks_msec()
		# Tests may be coroutines (e.g. layout tests that wait for frames).
		await test.call()
		_cleanup_root()
		print("  ..   [%s] finished in %d ms" % [_current_test, Time.get_ticks_msec() - started])
	print("")
	if _failures == 0:
		print("ALL TESTS PASSED (%d checks, %d tests)" % [_checks, tests.size()])
	else:
		print("FAILED: %d of %d checks failed" % [_failures, _checks])
	quit(1 if _failures > 0 else 0)


# --- Helpers ------------------------------------------------------------------

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if condition:
		print("  ok   [%s] %s" % [_current_test, description])
	else:
		_failures += 1
		printerr("  FAIL [%s] %s" % [_current_test, description])


func _make_board(seed_value: int = TEST_SEED) -> Board:
	var board: Board = Board.new()
	var towers: Node2D = Node2D.new()
	towers.name = "Towers"
	board.add_child(towers)
	var enemies: Node2D = Node2D.new()
	enemies.name = "Enemies"
	board.add_child(enemies)
	root.add_child(board)
	board.setup_map(seed_value)
	return board


## Non-path cells next to the path, closest to the exit first (deterministic and
## independent of which already hold towers, so _spot(main, i) is a stable name).
func _cells_near_path(board: Board) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var rect: Rect2i = board.window_rect_cells()
	var candidates: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var c: Vector2i = Vector2i(x, y)
			if board.in_window(c) and not board.is_path(c) and c != EXIT:
				candidates.append(c)
	for cell: Vector2i in candidates:
		for d: Vector2i in MapLayout.DIRECTIONS:
			if board.is_path(cell + d):
				cells.append(cell)
				break
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = absi(a.x - EXIT.x) + absi(a.y - EXIT.y)
		var db: int = absi(b.x - EXIT.x) + absi(b.y - EXIT.y)
		return da < db or (da == db and a.x * 100 + a.y < b.x * 100 + b.y))
	return cells


## The i-th free cell next to the path (a good, always-valid tower spot).
func _spot(main_or_board: Node, index: int = 0) -> Vector2i:
	var board: Board = main_or_board as Board if main_or_board is Board else main_or_board.board
	return _cells_near_path(board)[index]


## A buildable cell far from the path (out of most towers' reach).
func _far_spot(main_or_board: Node) -> Vector2i:
	var board: Board = main_or_board as Board if main_or_board is Board else main_or_board.board
	var best: Vector2i = Board.NO_CELL
	var best_gap: int = -1
	for cell: Vector2i in board.buildable_cells():
		if not board.is_buildable(cell):
			continue
		var gap: int = 999
		for path_cell: Vector2i in board.layout.parent:
			if board.in_window(path_cell):
				gap = mini(gap, absi(path_cell.x - cell.x) + absi(path_cell.y - cell.y))
		if gap > best_gap:
			best_gap = gap
			best = cell
	return best


## Main scene with a fixed run seed so generated waves are reproducible. By default the
## biome buff is switched off so tower numbers match their base stats exactly; tests of
## biomes and balance pass `real_biome = true`.
func _make_main(seed_value: int = TEST_SEED, real_biome: bool = false) -> Node2D:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	root.add_child(main)
	main.restart_game(seed_value)
	if not real_biome:
		_neutral_biome(main)
	return main


func _neutral_biome(main: Node2D) -> void:
	main.board.biome_index = -1
	main._apply_skill_modifiers()
	main._refresh_hud()


## Unlocks the Tesla and every tower-upgrade skill (no global stat modifiers).
func _unlock_tower_skills(main: Node2D) -> void:
	for id: String in ["tesla", "basic_upgrades", "basic_pierce", "tesla_upgrades", "tesla_static"]:
		main.skills.unlock(id)
	main._apply_skill_modifiers()
	main._refresh_hud()


## Closes the skill tree if a wave completion opened it.
func _close_skill_menu(main: Node2D) -> void:
	if main.is_skill_menu_open():
		main.close_skill_menu()


func _spawn_enemy(board: Board, health: float = 45.0, type_id: String = EnemyTypes.GRUNT, spawn_cell: Vector2i = Vector2i(-1, -1)) -> Enemy:
	var entry: Dictionary = WaveGenerator.make_entry(type_id, 1)
	entry["health"] = health
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	enemy.setup(board, entry, 1, spawn_cell)
	board.enemies.add_child(enemy)
	return enemy


func _cleanup_root() -> void:
	for child: Node in root.get_children():
		root.remove_child(child)
		child.free()


func _active_enemies(main: Node2D) -> Array[Enemy]:
	var list: Array[Enemy] = []
	for node: Node in main.board.enemies.get_children():
		var enemy: Enemy = node as Enemy
		if enemy.is_active():
			list.append(enemy)
	return list


## Steps the wave manager, every live enemy and every tower by `dt`, `steps` times.
func _simulate(main: Node2D, dt: float, steps: int) -> void:
	for i in steps:
		if main.is_game_over():
			return
		main.wave_manager.step(dt)
		for enemy: Enemy in _active_enemies(main):
			enemy.step(dt)
		for node: Node in main.board.towers.get_children():
			if not node.is_queued_for_deletion():
				(node as Tower).step(dt)


## Frees enemies that resolved during manual stepping (normally freed at frame end).
func _free_resolved(main: Node2D) -> void:
	for node: Node in main.board.enemies.get_children():
		if node.is_queued_for_deletion():
			main.board.enemies.remove_child(node)
			node.free()


func _kill_all_active(main: Node2D) -> void:
	for enemy: Enemy in _active_enemies(main):
		enemy.take_damage(1000000000)


## Returns "" if every game invariant holds, otherwise a description of the first violation.
func _invariant_violation(main: Node2D) -> String:
	var board: Board = main.board
	var blocked: Array[Vector2i] = board.get_blocked_cells()
	if blocked.size() != main.get_tower_count():
		return "blocked cells (%d) != towers (%d)" % [blocked.size(), main.get_tower_count()]
	for cell: Vector2i in blocked:
		if main.get_tower_at(cell) == null:
			return "blocked cell %s has no tower" % cell
		if board.is_path(cell) or cell == EXIT or not board.in_window(cell):
			return "tower on an illegal cell %s" % cell
	var active: Array[Enemy] = _active_enemies(main)
	if active.size() != main.wave_manager.get_unresolved_count():
		return "active enemies (%d) != wave manager unresolved count (%d)" % [active.size(), main.wave_manager.get_unresolved_count()]
	for enemy: Enemy in active:
		if not board.is_path(enemy.current_cell) or not board.is_path(enemy.next_cell):
			return "enemy off the path at %s -> %s" % [enemy.current_cell, enemy.next_cell]
		if enemy.next_cell != board.next_cell(enemy.current_cell) and enemy.next_cell != enemy.current_cell:
			return "enemy not heading along the path at %s" % enemy.current_cell
		if not board.in_window(enemy.current_cell):
			return "enemy outside the visible map at %s" % enemy.current_cell
		if enemy.health <= 0.0 or enemy.health > enemy.max_health or is_nan(enemy.health):
			return "enemy health out of range: %s / %s" % [enemy.health, enemy.max_health]
	if main.currency < 0:
		return "negative currency %d" % main.currency
	if main.lives < 0 or main.lives > main.get_max_lives():
		return "lives out of range %d" % main.lives
	return ""
