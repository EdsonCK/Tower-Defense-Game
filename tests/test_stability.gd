extends "res://tests/test_base.gd"
## Long-running randomized stability checks. Every game invariant is verified repeatedly
## while towers are bought, upgraded and sold at random during real waves.
##   godot --headless --path <project> --script res://tests/test_stability.gd


func get_tests() -> Array[Callable]:
	return [
		test_random_build_sell_upgrade_fuzz,
		test_long_run_with_defending_towers,
		test_many_restarts_leave_no_residue,
	]


func _random_cell(rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i(rng.randi_range(0, GameConfig.GRID_COLUMNS - 1), rng.randi_range(0, GameConfig.GRID_ROWS - 1))


## Random actions (build / sell / upgrade / start wave) interleaved with simulation.
func test_random_build_sell_upgrade_fuzz() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242
	var main: Node2D = _make_main(2024)
	var violation: String = ""
	var actions: Dictionary = {"build": 0, "sell": 0, "upgrade": 0, "waves": 0, "restarts": 0}
	for step in 6000:
		if main.is_game_over():
			main.restart_game(rng.randi_range(0, 1000000))
			actions["restarts"] += 1
		main.currency = maxi(main.currency, 500)  # keep the fuzzer able to act
		var roll: float = rng.randf()
		if roll < 0.25:
			if main.try_buy_tower(_random_cell(rng)):
				actions["build"] += 1
		elif roll < 0.32 and main.get_tower_count() > 0:
			var cells: Array = main._towers_by_cell.keys()
			if main.try_sell_tower(cells[rng.randi_range(0, cells.size() - 1)]):
				actions["sell"] += 1
		elif roll < 0.40 and main.get_tower_count() > 0:
			var cells: Array = main._towers_by_cell.keys()
			var tower: Tower = main.get_tower_at(cells[rng.randi_range(0, cells.size() - 1)])
			if main.try_upgrade_tower(tower, rng.randi_range(1, 3) as Tower.UpgradePath):
				actions["upgrade"] += 1
		if main.state == main.GameState.READY or main.state == main.GameState.BETWEEN_WAVES:
			main._on_start_wave_pressed()
			actions["waves"] += 1
		_simulate(main, 0.05, 1)
		_free_resolved(main)
		if step % 5 == 0:
			violation = _invariant_violation(main)
			if violation != "":
				violation = "step %d: %s" % [step, violation]
				break
	_check(violation == "", "6000 randomized steps keep every invariant%s" % ("" if violation == "" else " - " + violation))
	_check(actions["build"] > 100 and actions["sell"] > 10 and actions["upgrade"] > 10 and actions["waves"] > 3, "fuzzer exercised builds/sells/upgrades/waves: %s" % actions)


## A fixed defensive layout with upgrades fights real generated waves until defeat or
## wave 30, checking invariants and that every wave finishes in bounded time.
func test_long_run_with_defending_towers() -> void:
	var main: Node2D = _make_main(31337)
	var wm: WaveManager = main.wave_manager
	var layout: Array[Vector2i] = []
	for x in [6, 10, 14, 18, 22, 26, 30, 34]:
		for y in range(4, 21):
			# Alternate gaps top/bottom to make a serpentine maze.
			var gap_at_top: bool = (x / 4) % 2 == 0
			if (gap_at_top and y == 4) or (not gap_at_top and y == 20):
				continue
			layout.append(Vector2i(x, y))
	# Build the cells nearest the enemies' row first so early towers actually defend.
	layout.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = absi(a.y - 12) * 4 + a.x
		var db: int = absi(b.y - 12) * 4 + b.x
		return da < db)
	var violation: String = ""
	var stuck_wave: int = -1
	var paths: Array = [Tower.UpgradePath.DAMAGE, Tower.UpgradePath.RANGE, Tower.UpgradePath.SPEED]
	var build_index: int = 0
	var history: PackedStringArray = PackedStringArray()
	var escaped: Dictionary = {}
	wm.enemy_escaped.connect(func(e: Enemy) -> void: escaped[e.type_id] = escaped.get(e.type_id, 0) + 1)
	while not main.is_game_over() and wm.current_wave < 30:
		# Spend between waves: extend the maze, then upgrade towers round-robin.
		while build_index < layout.size() and main.currency >= GameConfig.TOWER_COST:
			main.try_buy_tower(layout[build_index])
			build_index += 1
		var cells: Array = main._towers_by_cell.keys()
		for i in cells.size():
			var tower: Tower = main.get_tower_at(cells[i])
			if tower.next_upgrade_cost() > 0 and main.currency >= tower.next_upgrade_cost():
				main.try_upgrade_tower(tower, paths[i % 3])
		main._on_start_wave_pressed()
		var wave_steps: int = 0
		while wm.is_wave_active() and not main.is_game_over():
			_simulate(main, 0.05, 10)
			_free_resolved(main)
			wave_steps += 10
			violation = _invariant_violation(main)
			if violation != "":
				break
			if wave_steps > 20 * 60 * 10:  # 10 simulated minutes
				stuck_wave = wm.current_wave
				break
		if violation != "" or stuck_wave >= 0:
			break
		history.append("w%d:%dL%s" % [wm.current_wave, main.lives, "" if escaped.is_empty() else str(escaped)])
		escaped.clear()
	print("  ..   [%s] lives after each wave: %s" % [_current_test, " ".join(history)])
	print("  ..   [%s] long run reached wave %d, lives %d, towers %d, state %s" % [_current_test, wm.current_wave, main.lives, main.get_tower_count(), main.GameState.keys()[main.state]])
	_check(violation == "", "invariants hold through the long run%s" % ("" if violation == "" else " - wave %d: %s" % [wm.current_wave, violation]))
	_check(stuck_wave < 0, "every wave resolves in bounded time (stuck on wave %d)" % stuck_wave)
	_check(wm.current_wave >= 10, "towers with upgrades survive at least 10 waves (reached %d)" % wm.current_wave)


func test_many_restarts_leave_no_residue() -> void:
	var main: Node2D = _make_main()
	var clean: bool = true
	for i in 25:
		main.currency = 1000
		main.try_buy_tower(Vector2i(5 + i % 10, 3))
		main.try_buy_tower(Vector2i(5 + i % 10, 20))
		main._on_board_cell_clicked(Vector2i(5 + i % 10, 3))
		main._on_start_wave_pressed()
		_simulate(main, 0.05, 50)
		main.restart_game()
		_free_resolved(main)
		for node: Node in main.board.towers.get_children():
			if not node.is_queued_for_deletion():
				clean = false
		if main.get_tower_count() != 0 or not main.board.get_blocked_cells().is_empty() or main.selected_tower != null \
				or main.wave_manager.get_unresolved_count() != 0 or main.wave_manager.current_wave != 0 \
				or main.currency != GameConfig.STARTING_CURRENCY or main.lives != GameConfig.STARTING_LIVES:
			clean = false
	_check(clean, "25 mid-wave restarts leave no towers, enemies, blocks, selection or counters behind")
