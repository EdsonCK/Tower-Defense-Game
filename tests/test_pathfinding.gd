extends SceneTree
## Headless logic tests (no external framework). Import the project once first, then run:
##   godot --headless --path <project> --script res://tests/test_pathfinding.gd
## Exits with code 0 when every check passes, 1 otherwise.
## Frames are never iterated here: enemies, towers and waves are stepped manually so
## every scenario is deterministic.

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")
const TOWER_SCENE: PackedScene = preload("res://scenes/tower.tscn")
const SPAWN: Vector2i = GameConfig.SPAWN_CELL
const EXIT: Vector2i = GameConfig.EXIT_CELL
const NONE: Array[Vector2i] = []

var _checks: int = 0
var _failures: int = 0
var _current_test: String = ""


func _initialize() -> void:
	# Nodes added to root only receive _ready() once the tree is running, so start on the first frame.
	process_frame.connect(_run_all, CONNECT_ONE_SHOT)


func _run_all() -> void:
	var tests: Array[Callable] = [
		test_empty_board_has_cardinal_path,
		test_block_cell_with_alternative_route,
		test_paths_avoid_solid_cells_and_diagonals,
		test_sealing_last_gap_is_rejected,
		test_reserved_out_of_bounds_and_occupied_cells,
		test_enemy_occupied_cells_cannot_be_built,
		test_placement_isolating_enemy_waypoint_is_rejected,
		test_live_enemy_waypoint_isolation_is_rejected,
		test_invalid_placement_leaves_state_unchanged,
		test_purchase_economy,
		test_enemy_reroutes_without_entering_towers,
		test_enemy_resolves_exactly_once,
		test_tower_attack_range_and_cooldown,
		test_wave_flow_defeat_and_restart,
		test_wave_flow_victory,
	]
	for test: Callable in tests:
		_current_test = test.get_method()
		test.call()
		_cleanup_root()
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


func _make_main() -> Node2D:
	var main: Node2D = MAIN_SCENE.instantiate() as Node2D
	root.add_child(main)
	return main


func _spawn_enemy(board: Board, health: int) -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	enemy.setup(board, health)
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


## Steps every live enemy, tower and the wave manager by `dt`, `steps` times.
func _simulate(main: Node2D, dt: float, steps: int) -> void:
	for i in steps:
		if main.is_game_over():
			return
		main.wave_manager.step(dt)
		for node: Node in main.board.enemies.get_children():
			var enemy: Enemy = node as Enemy
			if enemy.is_active():
				enemy.advance(dt)
		for node: Node in main.board.towers.get_children():
			if not node.is_queued_for_deletion():
				(node as Tower).step(dt)


# --- Spec section 10, tests 1-7 ---------------------------------------------------

func test_empty_board_has_cardinal_path() -> void:
	var board: Board = _make_board()
	var path: Array[Vector2i] = board.find_path(SPAWN, EXIT)
	_check(_route_is_clean(board, path, SPAWN, EXIT), "empty 40x24 board has a cardinal route spawn->exit")
	_check(path.size() == 40, "shortest empty-board route visits 40 cells (got %d)" % path.size())


func test_block_cell_with_alternative_route() -> void:
	var board: Board = _make_board()
	var on_route: Vector2i = Vector2i(10, 12)
	_check(board.find_path(SPAWN, EXIT).has(on_route), "(10,12) lies on the initial route")
	_check(board.try_block_cell(on_route, NONE, NONE) == "", "blocking a route cell with an alternative is accepted")
	_check(board.is_blocked(on_route) and board.is_solid(on_route), "accepted cell is blocked and solid")
	var path: Array[Vector2i] = board.find_path(SPAWN, EXIT)
	_check(_route_is_clean(board, path, SPAWN, EXIT) and not path.has(on_route), "new route detours around the tower")


func test_paths_avoid_solid_cells_and_diagonals() -> void:
	var board: Board = _make_board()
	var cells: Array[Vector2i] = [
		Vector2i(5, 12), Vector2i(5, 11), Vector2i(5, 13), Vector2i(12, 10), Vector2i(12, 11),
		Vector2i(12, 12), Vector2i(12, 13), Vector2i(12, 14), Vector2i(25, 12), Vector2i(26, 13),
		Vector2i(27, 11), Vector2i(30, 12),
	]
	for cell: Vector2i in cells:
		_check(board.try_block_cell(cell, NONE, NONE) == "", "maze cell %s accepted" % cell)
	var path: Array[Vector2i] = board.find_path(SPAWN, EXIT)
	_check(_route_is_clean(board, path, SPAWN, EXIT), "route avoids every solid cell and has only cardinal steps")
	var from_mid: Array[Vector2i] = board.find_path(Vector2i(20, 3), EXIT)
	_check(_route_is_clean(board, from_mid, Vector2i(20, 3), EXIT), "route from an arbitrary cell is also clean")


func test_sealing_last_gap_is_rejected() -> void:
	var board: Board = _make_board()
	for y in GameConfig.GRID_ROWS:
		if y != 12:
			board.try_block_cell(Vector2i(20, y), NONE, NONE)
	var wall_complete: bool = true
	for y in GameConfig.GRID_ROWS:
		if y != 12 and not board.is_blocked(Vector2i(20, y)):
			wall_complete = false
	_check(wall_complete, "column 20 is blocked except (20,12)")
	var path: Array[Vector2i] = board.find_path(SPAWN, EXIT)
	_check(_route_is_clean(board, path, SPAWN, EXIT) and path.has(Vector2i(20, 12)), "route passes through the single gap")
	var revision_before: int = board.revision
	var reason: String = board.try_block_cell(Vector2i(20, 12), NONE, NONE)
	_check(reason == Board.MSG_BLOCKS_ROUTE, "blocking the final gap is rejected (%s)" % reason)
	_check(not board.is_blocked(Vector2i(20, 12)) and not board.is_solid(Vector2i(20, 12)), "gap stays unblocked and non-solid")
	_check(board.revision == revision_before, "rejected placement does not change the board revision")
	_check(board.has_route(SPAWN, EXIT), "route still exists after rejection")


func test_reserved_out_of_bounds_and_occupied_cells() -> void:
	var board: Board = _make_board()
	_check(board.try_block_cell(SPAWN, NONE, NONE) == Board.MSG_RESERVED, "spawn rejected")
	_check(board.try_block_cell(EXIT, NONE, NONE) == Board.MSG_RESERVED, "exit rejected")
	for cell: Vector2i in [Vector2i(-1, 0), Vector2i(40, 0), Vector2i(0, 24), Vector2i(0, -1), Vector2i(40, 24)]:
		_check(board.try_block_cell(cell, NONE, NONE) == Board.MSG_OUT_OF_BOUNDS, "out-of-bounds %s rejected" % cell)
	_check(board.try_block_cell(Vector2i(5, 5), NONE, NONE) == "", "first placement on (5,5) accepted")
	_check(board.try_block_cell(Vector2i(5, 5), NONE, NONE) == Board.MSG_OCCUPIED, "second placement on (5,5) rejected")
	_check(Board.world_to_cell(Vector2(0, 0)) == Vector2i(0, 0), "pixel (0,0) maps to cell (0,0)")
	_check(Board.world_to_cell(Vector2(1279.9, 767.9)) == Vector2i(39, 23), "last board pixel maps to cell (39,23)")
	_check(Board.cell_to_world(Vector2i(39, 12)) == Vector2(1264, 400), "cell (39,12) center is (1264,400)")
	_check(not Board.is_inside_board_pixels(Vector2(1280, 100)) and not Board.is_inside_board_pixels(Vector2(100, 768)), "pixels on panels are outside the board")


func test_enemy_occupied_cells_cannot_be_built() -> void:
	var board: Board = _make_board()
	var occupied: Array[Vector2i] = [Vector2i(7, 3), Vector2i(8, 3)]
	_check(board.try_block_cell(Vector2i(7, 3), occupied, NONE) == Board.MSG_ENEMY_ON_TILE, "enemy's current cell rejected")
	_check(board.try_block_cell(Vector2i(8, 3), occupied, NONE) == Board.MSG_ENEMY_ON_TILE, "enemy's committed next cell rejected")
	# Real enemy, mid-segment between (0,12) and (1,12).
	var enemy: Enemy = _spawn_enemy(board, 45)
	enemy.advance(0.25)
	_check(enemy.is_moving() and enemy.current_cell == SPAWN and enemy.next_cell == Vector2i(1, 12), "enemy is moving from (0,12) to (1,12)")
	_check(board.try_block_cell_live(Vector2i(1, 12)) == Board.MSG_ENEMY_ON_TILE, "live enemy's committed waypoint cannot be built over")
	_check(not board.is_solid(Vector2i(1, 12)), "rejected waypoint cell stays open")


func test_placement_isolating_enemy_waypoint_is_rejected() -> void:
	var board: Board = _make_board()
	var waypoint: Vector2i = Vector2i(5, 2)
	var occupied: Array[Vector2i] = [waypoint]
	var committed: Array[Vector2i] = [waypoint]
	for cell: Vector2i in [Vector2i(4, 2), Vector2i(6, 2), Vector2i(5, 1)]:
		_check(board.try_block_cell(cell, occupied, committed) == "", "pocket wall %s accepted" % cell)
	var candidate: Vector2i = Vector2i(5, 3)
	_check(board.validate_placement(candidate, NONE, NONE) == "", "without the enemy, (5,3) would be valid (spawn route exists)")
	var snapshot: Array[Vector2i] = _solid_snapshot(board)
	_check(board.try_block_cell(candidate, occupied, committed) == Board.MSG_STRANDS_ENEMY, "sealing the enemy's waypoint pocket is rejected")
	_check(_solid_snapshot(board) == snapshot, "solid cells unchanged after rejection")
	_check(board.has_route(SPAWN, EXIT), "spawn route still exists")


func test_live_enemy_waypoint_isolation_is_rejected() -> void:
	var board: Board = _make_board()
	var enemy: Enemy = _spawn_enemy(board, 45)
	# 80 px of travel: halfway between (2,12) and (3,12).
	enemy.advance(80.0 / GameConfig.ENEMY_SPEED)
	_check(enemy.current_cell == Vector2i(2, 12) and enemy.next_cell == Vector2i(3, 12), "enemy is between (2,12) and (3,12)")
	for cell: Vector2i in [Vector2i(1, 12), Vector2i(2, 11), Vector2i(2, 13), Vector2i(3, 11), Vector2i(3, 13)]:
		_check(board.try_block_cell_live(cell) == "", "pocket wall %s accepted with live enemy" % cell)
	_check(board.has_route(SPAWN, EXIT), "spawn still has a route via (0,11)/(0,13)")
	var reason: String = board.try_block_cell_live(Vector2i(4, 12))
	_check(reason == Board.MSG_STRANDS_ENEMY, "closing (4,12) would trap the in-flight enemy and is rejected (%s)" % reason)
	_check(not board.is_solid(Vector2i(4, 12)), "(4,12) left open")


func test_invalid_placement_leaves_state_unchanged() -> void:
	var main: Node2D = _make_main()
	var board: Board = main.board
	_check(main.currency == 200 and main.lives == 10, "game starts with 200 currency and 10 lives")
	var snapshot: Array[Vector2i] = _solid_snapshot(board)
	var revision: int = board.revision
	for cell: Vector2i in [SPAWN, EXIT, Vector2i(-1, 5), Vector2i(40, 5)]:
		_check(not main.try_buy_tower(cell), "buying on %s fails" % cell)
	_check(main.currency == 200, "currency unchanged after invalid placements")
	_check(_solid_snapshot(board) == snapshot and board.revision == revision, "pathfinding state unchanged after invalid placements")
	_check(board.towers.get_child_count() == 0, "no tower nodes created")


func test_purchase_economy() -> void:
	var main: Node2D = _make_main()
	var board: Board = main.board
	_check(main.try_buy_tower(Vector2i(10, 5)), "valid purchase succeeds")
	_check(main.currency == 140, "one tower leaves 140 currency (got %d)" % main.currency)
	_check(board.towers.get_child_count() == 1 and board.is_blocked(Vector2i(10, 5)), "exactly one tower exists and its tile is blocked")
	_check(not main.try_buy_tower(Vector2i(10, 5)), "buying on an occupied tile fails")
	_check(main.currency == 140 and board.towers.get_child_count() == 1, "occupied-tile attempt charges nothing")
	_check(main.try_buy_tower(Vector2i(11, 5)) and main.try_buy_tower(Vector2i(12, 5)), "two more purchases succeed")
	_check(main.currency == 20, "three towers leave 20 currency")
	_check(not main.try_buy_tower(Vector2i(13, 5)), "purchase with insufficient currency fails")
	_check(main.currency == 20 and not board.is_solid(Vector2i(13, 5)), "insufficient-currency attempt changes nothing")
	_check(main.hud.get_message() == "Insufficient currency", "insufficient currency message shown")


# --- Movement, combat and waves -------------------------------------------------------

func test_enemy_reroutes_without_entering_towers() -> void:
	var board: Board = _make_board()
	var enemy: Enemy = _spawn_enemy(board, 45)
	var escaped: Array[bool] = [false]
	enemy.reached_exit.connect(func(_e: Enemy) -> void: escaped[0] = true)
	var visited: Array[Vector2i] = [enemy.current_cell]
	var last_pos: Vector2 = enemy.position
	var max_jump: float = 0.0
	var wall_built: bool = false
	var walked_into_tower: bool = false
	var dt: float = 1.0 / 60.0
	for i in 60 * 60:
		if escaped[0]:
			break
		enemy.advance(dt)
		if escaped[0]:
			break
		max_jump = maxf(max_jump, enemy.position.distance_to(last_pos))
		last_pos = enemy.position
		if visited[visited.size() - 1] != enemy.current_cell:
			visited.append(enemy.current_cell)
		if board.is_solid(Board.world_to_cell(enemy.position)):
			walked_into_tower = true
		# Mid-segment, wall off the straight route ahead of the enemy.
		if not wall_built and enemy.current_cell == Vector2i(4, 12) and enemy.is_moving():
			_check(board.try_block_cell_live(enemy.next_cell) == Board.MSG_ENEMY_ON_TILE, "cannot build on the enemy's committed next tile")
			var all_accepted: bool = true
			for y in range(8, 17):
				if board.try_block_cell_live(Vector2i(10, y)) != "":
					all_accepted = false
			_check(all_accepted, "wall (10,8)-(10,16) accepted mid-wave")
			wall_built = true
	_check(wall_built, "wall was built while the enemy was moving")
	_check(escaped[0], "enemy reached the exit after rerouting")
	_check(not walked_into_tower, "enemy never stood on a solid tile")
	_check(max_jump <= GameConfig.ENEMY_SPEED * dt + 0.01, "no teleporting (max per-step move %.3f px)" % max_jump)
	var cardinal: bool = true
	for i in range(1, visited.size()):
		var step: Vector2i = visited[i] - visited[i - 1]
		if absi(step.x) + absi(step.y) != 1:
			cardinal = false
	_check(cardinal, "every visited cell is a cardinal neighbour of the previous one")
	_check(not visited.has(Vector2i(10, 12)), "enemy route avoided the new wall")


func test_enemy_resolves_exactly_once() -> void:
	var board: Board = _make_board()
	var enemy: Enemy = _spawn_enemy(board, 45)
	var deaths: Array[int] = [0]
	enemy.died.connect(func(_e: Enemy) -> void: deaths[0] += 1)
	enemy.take_damage(30)
	_check(enemy.is_active() and enemy.health == 15, "enemy survives 30 damage with 15 HP")
	enemy.take_damage(15)
	enemy.take_damage(15)
	_check(deaths[0] == 1, "died emitted exactly once (got %d)" % deaths[0])
	_check(not enemy.is_active() and not enemy.is_in_group("enemies"), "dead enemy is inactive and untargetable")


func test_tower_attack_range_and_cooldown() -> void:
	var board: Board = _make_board()
	var tower: Tower = TOWER_SCENE.instantiate() as Tower
	tower.position = Board.cell_to_world(Vector2i(2, 11))
	board.towers.add_child(tower)
	tower.step(0.2)
	_check(tower._cooldown_left <= 0.0, "no shot wasted with no enemies in range")
	var enemy: Enemy = _spawn_enemy(board, 45)
	tower.step(0.2)
	_check(enemy.health == 30, "in-range enemy takes 15 damage immediately (HP %d)" % enemy.health)
	_check(tower._flash_left > 0.0, "firing flash is visible")
	tower.step(0.5)
	_check(enemy.health == 30, "no second shot before 0.8 s cooldown")
	tower.step(0.31)
	_check(enemy.health == 15, "second shot after cooldown (HP %d)" % enemy.health)
	var far_tower: Tower = TOWER_SCENE.instantiate() as Tower
	far_tower.position = Board.cell_to_world(Vector2i(20, 3))
	board.towers.add_child(far_tower)
	far_tower.step(1.0)
	_check(enemy.health == 15, "out-of-range tower does not fire")


func test_wave_flow_defeat_and_restart() -> void:
	var main: Node2D = _make_main()
	var wm: WaveManager = main.wave_manager
	main._on_start_wave_pressed()
	_check(main.state == main.GameState.WAVE_ACTIVE and wm.current_wave == 1, "Start Wave launches wave 1")
	main._on_start_wave_pressed()
	_check(wm.current_wave == 1, "pressing Start Wave again does not stack waves")
	_simulate(main, 0.05, 20 * 60 * 2)
	_check(main.lives == 2, "8 escaped enemies cost 8 lives (lives %d)" % main.lives)
	_check(main.currency == 230, "no bounty for escapes; 30 wave-clear bonus (currency %d)" % main.currency)
	_check(main.state == main.GameState.BETWEEN_WAVES and not wm.is_wave_active(), "wave 1 complete -> BETWEEN_WAVES")
	main._on_start_wave_pressed()
	_check(wm.current_wave == 2, "wave 2 starts")
	_simulate(main, 0.05, 20 * 60 * 2)
	_check(main.state == main.GameState.DEFEAT and main.lives == 0, "reaching zero lives triggers DEFEAT")
	var spawned_before: int = main.board.enemies.get_child_count()
	_check(wm.get_remaining_to_spawn() == 0 and not wm.is_wave_active(), "spawning stopped on defeat")
	wm.step(10.0)
	_check(main.board.enemies.get_child_count() == spawned_before, "no further spawns after defeat")
	_check(not main.try_buy_tower(Vector2i(10, 5)), "building is disabled after defeat")
	main._on_start_wave_pressed()
	_check(wm.current_wave == 2, "Start Wave ignored after defeat")
	main.restart_game()
	_check(main.currency == 200 and main.lives == 10 and main.state == main.GameState.READY, "Restart restores 200 currency, 10 lives, READY")
	_check(wm.current_wave == 0 and main.board.get_blocked_cells().is_empty(), "Restart resets waves and board occupancy")
	main._on_start_wave_pressed()
	_check(wm.current_wave == 1 and main.state == main.GameState.WAVE_ACTIVE, "wave 1 can be started again after restart")


func test_wave_flow_victory() -> void:
	var main: Node2D = _make_main()
	var wm: WaveManager = main.wave_manager
	var expected_currency: int = GameConfig.STARTING_CURRENCY
	for wave in 3:
		main._on_start_wave_pressed()
		_check(wm.current_wave == wave + 1, "wave %d started" % (wave + 1))
		var guard: int = 0
		while wm.is_wave_active() and guard < 10000:
			guard += 1
			_simulate(main, 0.05, 1)
			# Kill every enemy shortly after it spawns.
			for node: Node in main.board.enemies.get_children():
				var enemy: Enemy = node as Enemy
				if enemy.is_active():
					enemy.take_damage(10000)
		expected_currency += GameConfig.WAVES[wave]["count"] * GameConfig.ENEMY_BOUNTY
		if wave < 2:
			expected_currency += GameConfig.WAVE_CLEAR_BONUS
	_check(main.state == main.GameState.VICTORY, "clearing wave 3 with lives left triggers VICTORY")
	_check(main.lives == 10, "no lives lost")
	_check(main.currency == expected_currency, "each kill paid 12 once plus two wave bonuses (currency %d, expected %d)" % [main.currency, expected_currency])
