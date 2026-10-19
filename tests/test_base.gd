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
const SPAWN: Vector2i = GameConfig.SPAWN_CELL
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


func _make_board() -> Board:
	var board: Board = Board.new()
	var towers: Node2D = Node2D.new()
	towers.name = "Towers"
	board.add_child(towers)
	var enemies: Node2D = Node2D.new()
	enemies.name = "Enemies"
	board.add_child(enemies)
	root.add_child(board)
	return board


## Main scene with a fixed run seed so generated waves are reproducible.
func _make_main(seed_value: int = TEST_SEED) -> Node2D:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	root.add_child(main)
	main.restart_game(seed_value)
	return main


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


func _spawn_enemy(board: Board, health: float = 45.0, type_id: String = EnemyTypes.GRUNT) -> Enemy:
	var entry: Dictionary = WaveGenerator.make_entry(type_id, 1)
	entry["health"] = health
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	enemy.setup(board, entry, 1)
	board.enemies.add_child(enemy)
	return enemy


func _cleanup_root() -> void:
	for child: Node in root.get_children():
		root.remove_child(child)
		child.free()


func _solid_snapshot(board: Board) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in GameConfig.GRID_ROWS:
		for x in GameConfig.GRID_COLUMNS:
			if board.is_solid(Vector2i(x, y)):
				cells.append(Vector2i(x, y))
	return cells


func _route_is_clean(board: Board, path: Array[Vector2i], from: Vector2i, to: Vector2i) -> bool:
	if path.is_empty() or path[0] != from or path[path.size() - 1] != to:
		return false
	for i in path.size():
		if board.is_solid(path[i]) or not Board.is_in_bounds(path[i]):
			return false
		if i > 0 and absi(path[i].x - path[i - 1].x) + absi(path[i].y - path[i - 1].y) != 1:
			return false
	return true


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
		if main.get_tower_at(cell) == null or not board.is_solid(cell):
			return "blocked cell %s has no tower or is not solid" % cell
	if _solid_snapshot(board).size() != blocked.size():
		return "solid cells differ from blocked cells"
	if not board.has_route(SPAWN, EXIT):
		return "no route from spawn to exit"
	var active: Array[Enemy] = _active_enemies(main)
	if active.size() != main.wave_manager.get_unresolved_count():
		return "active enemies (%d) != wave manager unresolved count (%d)" % [active.size(), main.wave_manager.get_unresolved_count()]
	for enemy: Enemy in active:
		for cell: Vector2i in enemy.get_occupied_cells():
			if board.is_solid(cell):
				return "enemy occupies solid cell %s" % cell
		if not board.has_route(enemy.get_committed_waypoint(), EXIT):
			return "enemy waypoint %s cannot reach the exit" % enemy.get_committed_waypoint()
		if not Board.is_inside_board_pixels(enemy.position):
			return "enemy outside the board at %s" % enemy.position
		if enemy.health <= 0.0 or enemy.health > enemy.max_health or is_nan(enemy.health):
			return "enemy health out of range: %s / %s" % [enemy.health, enemy.max_health]
	if main.currency < 0:
		return "negative currency %d" % main.currency
	if main.lives < 0 or main.lives > main.get_max_lives():
		return "lives out of range %d" % main.lives
	return ""
