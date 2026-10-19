extends "res://tests/test_base.gd"
## Long-running randomized stability checks. Every game invariant is verified repeatedly
## while towers are bought, upgraded and sold at random during real waves.
##   godot --headless --path <project> --script res://tests/test_stability.gd


const BOTS: GDScript = preload("res://tests/bots.gd")


func get_tests() -> Array[Callable]:
	return [
		test_random_build_sell_upgrade_fuzz,
		test_long_run_with_defending_towers,
		test_many_restarts_leave_no_residue,
	]


func _random_cell(rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i(rng.randi_range(0, GameConfig.GRID_COLUMNS - 1), rng.randi_range(0, GameConfig.GRID_ROWS - 1))


## Random actions (build either tower / sell / upgrade any path / unlock skills / open
## and close the skill tree / toggle auto-start / start waves) interleaved with simulation.
func test_random_build_sell_upgrade_fuzz() -> void:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 424242
	var main: Node2D = _make_main(2024)
	var violation: String = ""
	var actions: Dictionary = {"build": 0, "tesla": 0, "sell": 0, "upgrade": 0, "skills": 0, "menu": 0, "waves": 0, "restarts": 0}
	var skill_ids: Array = SkillTree.SKILLS.keys()
	for step in 6000:
		if main.is_game_over():
			main.restart_game(rng.randi_range(0, 1000000))
			actions["restarts"] += 1
		main.currency = maxi(main.currency, 500)  # keep the fuzzer able to act
		var roll: float = rng.randf()
		if roll < 0.22:
			var type_id: String = TowerTypes.ORDER[rng.randi_range(0, TowerTypes.ORDER.size() - 1)]
			if main.try_buy_tower(_random_cell(rng), type_id):
				actions["tesla" if type_id == TowerTypes.TESLA else "build"] += 1
		elif roll < 0.29 and main.get_tower_count() > 0:
			var cells: Array = main._towers_by_cell.keys()
			if main.try_sell_tower(cells[rng.randi_range(0, cells.size() - 1)]):
				actions["sell"] += 1
		elif roll < 0.37 and main.get_tower_count() > 0:
			var cells: Array = main._towers_by_cell.keys()
			var tower: Tower = main.get_tower_at(cells[rng.randi_range(0, cells.size() - 1)])
			if main.try_upgrade_tower(tower, rng.randi_range(1, 6) as Tower.UpgradePath):
				actions["upgrade"] += 1
		elif roll < 0.40:
			main.diamonds += 6
			if main.try_unlock_skill(skill_ids[rng.randi_range(0, skill_ids.size() - 1)]):
				actions["skills"] += 1
		elif roll < 0.41:
			main.open_skill_menu("fuzz")
			actions["menu"] += 1
		elif roll < 0.42:
			main.set_auto_start(not main.auto_start)
		if main.is_skill_menu_open() and rng.randf() < 0.3:
			main.close_skill_menu()
		if (main.state == main.GameState.READY or main.state == main.GameState.BETWEEN_WAVES) and rng.randf() < 0.5:
			main._on_start_wave_pressed()
			actions["waves"] += 1
		_simulate(main, 0.05, 1)
		main.step_auto_start(0.05)
		_free_resolved(main)
		if step % 5 == 0:
			violation = _invariant_violation(main)
			if violation != "":
				violation = "step %d: %s" % [step, violation]
				break
	_check(violation == "", "6000 randomized steps keep every invariant%s" % ("" if violation == "" else " - " + violation))
	_check(actions["build"] > 50 and actions["tesla"] > 20 and actions["sell"] > 10 and actions["upgrade"] > 10 and actions["skills"] >= 25 and actions["waves"] > 3, "fuzzer exercised every action: %s" % actions)


## The good bot plays real generated waves with every invariant checked every 10 ticks,
## and every wave must resolve in bounded time.
func test_long_run_with_defending_towers() -> void:
	var main: Node2D = _make_main(31337)
	var bot = BOTS.new("good", 31337)
	var violation: Array[String] = [""]
	var ticks: Array[int] = [0]
	var stepper: Callable = func(m: Node2D, dt: float) -> void:
		if violation[0] != "":
			return
		_simulate(m, dt, 1)
		_free_resolved(m)
		ticks[0] += 1
		if ticks[0] % 10 != 0:
			return
		violation[0] = _invariant_violation(m)
		if violation[0] != "":
			violation[0] = "wave %d: %s" % [m.wave_manager.current_wave, violation[0]]
			m.lives = 0
			m._end_game("invariant violated")
	var reached: int = bot.play(main, 20, stepper)
	print("  ..   [%s] good bot reached wave %d, lives %d, towers %d, route %d cells, skills %d" % [_current_test, reached, main.lives, main.get_tower_count(), main.board.find_path(SPAWN, EXIT).size(), main.skills.unlocked_ids().size()])
	_check(violation[0] == "", "invariants hold (checked every 10 ticks) through a 20-wave run%s" % ("" if violation[0] == "" else " - " + violation[0]))
	_check(reached == 20 and not main.is_game_over(), "good bot survives 20 waves (reached %d)" % reached)


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
