extends SceneTree
## Gameplay integration tests, without an external framework.

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func _test_purchases() -> void:
	var game := load("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	root.add_child(game)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.select_tower()
	check(game.purchase_tower(Vector2i(20, 12)), "successful purchase")
	check(game.currency == 140 and game.building, "deduct exactly 60, retain build selection")
	check(game.board.get_node("Towers").get_child_count() == 1, "exactly one tower created")
	var revision := game.board.revision
	var path := game.board.find_path()
	for cell in [Vector2i(20, 12), GameConfig.SPAWN, GameConfig.EXIT, Vector2i(40, 0)]:
		check(not game.purchase_tower(cell), "invalid purchase rejected: %s" % cell)
	check(game.currency == 140 and game.board.revision == revision and game.board.find_path() == path, "invalid purchases preserve currency, revision, and route")
	var saved_scene := game.tower_scene
	game.tower_scene = null
	check(not game.purchase_tower(Vector2i(5, 5)), "failed instantiation rejected")
	check(game.currency == 140 and not game.board.is_blocked(Vector2i(5, 5)) and game.board.revision == revision, "failed instantiation rolls back occupancy, revision, and currency")
	var wrong_root := Node2D.new()
	var wrong_scene := PackedScene.new()
	wrong_scene.pack(wrong_root)
	wrong_root.free()
	game.tower_scene = wrong_scene
	check(not game.purchase_tower(Vector2i(5, 5)) and game.currency == 140 and not game.board.is_blocked(Vector2i(5, 5)), "wrong scene type rolls back without charging")
	game.tower_scene = saved_scene
	check(game.purchase_tower(Vector2i(21, 12)) and game.purchase_tower(Vector2i(22, 12)), "three starting towers affordable")
	check(game.currency == 20 and not game.building, "stop build mode below tower cost")
	check(not game.purchase_tower(Vector2i(23, 12)) and not game.board.is_blocked(Vector2i(23, 12)), "unaffordable placement changes nothing")
	game.free()


func make_game() -> TDGame:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.waves.set_run_seed(721)
	return game


func _test_blocked_route_economy() -> void:
	var solids: Array[Vector2i] = []
	for y in range(24):
		if y != 12:
			solids.append(Vector2i(20, y))
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.get_node("Board").free()
	var board := Board.new(solids)
	board.name = "Board"
	for container_name in ["Enemies", "Towers"]:
		var container := Node2D.new()
		container.name = container_name
		board.add_child(container)
	game.add_child(board)
	game.progression = Progression.new("")
	root.add_child(game)
	check(not game.purchase_tower(Vector2i(20, 12)), "Main rejects purchase sealing last gap")
	check(game.currency == 200 and not board.is_blocked(Vector2i(20, 12)) and board.revision == 0 and board.get_node("Towers").get_child_count() == 0, "route rejection leaves all transaction state unchanged")
	game.free()


func _test_cadence_and_rewards() -> void:
	var game := make_game()
	game.start_wave()
	game.start_wave()
	var count := game.waves.wave_size
	check(game.waves.current_wave == 1 and game.waves.remaining_to_spawn == count, "repeated start does not stack waves")
	check(game.phase == TDGame.Phase.WAVE_ACTIVE and game.hud.start_button.disabled, "active wave disables Start Wave")
	game.waves._process(0.001)
	check(game.waves.active_count == 1 and game.waves.remaining_to_spawn == count - 1, "first spawn counted")
	var first := game.board.active_enemies()[0] as Enemy
	check(first.health > 0 and first.speed > 0 and first.bounty > 0, "spawn applies generated profile")
	game.waves._process(game.waves.spawn_interval - 0.002)
	check(game.waves.active_count == 1, "does not spawn early")
	game.waves._process(0.002)
	check(game.waves.active_count == 2, "second spawn uses generated interval")
	var reward := first.bounty
	first.take_damage(first.health + first.shield + first.armor)
	first.take_damage(9999)
	check(game.currency == 200 + reward and game.waves.active_count == 1, "type-specific bounty given once")
	var second := game.board.active_enemies()[0] as Enemy
	second._process(100.0)
	check(game.lives == 9 and game.currency == 200 + reward and game.waves.active_count == 0, "escape costs one life with no bounty")
	check(game.phase == TDGame.Phase.WAVE_ACTIVE, "wave waits for unspawned enemies")
	game.waves._process(100.0)
	check(game.waves.remaining_to_spawn == 0 and game.waves.active_count == count - 2, "exact scheduled count spawns")
	var expected := game.currency + GameConfig.WAVE_CLEAR_BONUS
	for node in game.board.active_enemies():
		var enemy := node as Enemy
		expected += enemy.bounty
		for layer in range(3): # Fixture: one hit per possible layer, not a balance simulation.
			enemy.take_damage(enemy.health + enemy.shield + enemy.armor)
	check(game.currency == expected, "wave clear awards all actual bounties and one bonus")
	check(game.phase == TDGame.Phase.BETWEEN_WAVES and not game.hud.start_button.disabled, "wave waits for button")
	game.waves._process(100.0)
	check(game.waves.current_wave == 1 and game.currency == expected, "no automatic start or repeated bonus")
	for wave in range(2, 9):
		game.close_skill_tree()
		game.start_wave()
		game.waves._process(100.0)
		check(game.waves.current_wave == wave and game.waves.active_count == game.waves.wave_size, "wave %d scheduled count" % wave)
		for node in game.board.active_enemies():
			var enemy := node as Enemy
			expected += enemy.bounty
			for layer in range(3): # Fixture: one hit per possible layer, not a balance simulation.
				enemy.take_damage(enemy.health + enemy.shield + enemy.armor)
		expected += GameConfig.WAVE_CLEAR_BONUS
		check(game.phase == TDGame.Phase.BETWEEN_WAVES and game.currency == expected and game.lives == 9, "wave %d clears and endless play continues" % wave)
	game.free()


func _test_combat() -> void:
	var game := make_game()
	game.purchase_tower(Vector2i(10, 10))
	var tower := game.board.get_node("Towers").get_child(0) as Tower
	var near := preload("res://scenes/enemy.tscn").instantiate() as Enemy
	var far := preload("res://scenes/enemy.tscn").instantiate() as Enemy
	game.board.get_node("Enemies").add_child(near)
	game.board.get_node("Enemies").add_child(far)
	near.setup(game.board, 45)
	far.setup(game.board, 45)
	near.position = tower.position + Vector2(50, 0)
	far.position = tower.position + Vector2(80, 0)
	tower._process(0.01)
	check(near.health == 30 and far.health == 45, "immediate hit damages nearest living enemy by 15")
	tower._process(0.799)
	check(near.health == 30, "cannot fire before cooldown")
	tower._process(0.002)
	check(near.health == 15, "fires again after 0.8s")
	near.take_damage(15)
	tower._process(0.8)
	check(far.health == 30, "resolved enemy ignored, acquire next target")
	far.position = tower.position + Vector2(GameConfig.TOWER_RANGE + 0.1, 0)
	tower._process(0.8)
	check(far.health == 30, "target outside 112 pixel range is not hit")
	far.position = tower.position + Vector2(GameConfig.TOWER_RANGE, 0)
	tower._process(0.8)
	check(far.health == 15, "target exactly 112 pixels away is hit")
	game.free()


func _test_playable_sessions() -> void:
	# Fixed-seed, real combat/economy. Spend only currency earned in gameplay.
	for run_seed in [721, 109, 1337, 9001, 2026]:
		var game := make_game()
		game.waves.set_run_seed(run_seed)
		var build_cells: Array[Vector2i] = []
		for y in [11, 13]:
			for x in range(3, 38, 3):
				build_cells.append(Vector2i(x, y))
		var next_cell := 0
		for wave in range(1, 13):
			game.close_skill_tree()
			while game.currency >= GameConfig.TOWER_COST and next_cell < build_cells.size():
				game.purchase_tower(build_cells[next_cell])
				next_cell += 1
			game.start_wave()
			for frame in range(120 * 60):
				if game.phase != TDGame.Phase.WAVE_ACTIVE:
					break
				game.waves._process(1.0 / 60.0)
				for node in game.board.active_enemies():
					(node as Enemy)._process(1.0 / 60.0)
				for node in game.board.get_node("Towers").get_children():
					(node as Tower)._process(1.0 / 60.0)
			check(game.waves.current_wave == wave and game.waves.active_count == 0 and game.phase == TDGame.Phase.BETWEEN_WAVES, "natural combat clears endless wave %d" % wave)
			if game.is_finished():
				break
		check(game.lives > 0 and game.waves.current_wave == 12, "twelve-wave session using only earned money and production combat")
		print("Endless session: seed=%d, wave=%d, lives=%d, currency=%d" % [run_seed, game.waves.current_wave, game.lives, game.currency])
		game.free()
	var game := make_game()
	for wave in range(1, 4):
		game.close_skill_tree()
		game.start_wave()
		for frame in range(120 * 60):
			if game.phase != TDGame.Phase.WAVE_ACTIVE:
				break
			game.waves._process(1.0 / 60.0)
			for node in game.board.active_enemies():
				if game.is_finished():
					break
				(node as Enemy)._process(1.0 / 60.0)
		if game.is_finished():
			break
	check(game.phase == TDGame.Phase.DEFEAT and game.lives == 0, "unprotected base loses on tenth escaped enemy")
	check(game.currency == 230, "escapes give no bounty; surviving wave 1 gives 30")
	var active := game.waves.active_count
	game.waves._process(100)
	game.start_wave()
	game.select_tower()
	check(not game.waves.running and game.waves.remaining_to_spawn == 0 and game.waves.active_count == active and not game.building, "defeat stops spawning and gameplay input")
	check(game.board.get_node("Enemies").process_mode == Node.PROCESS_MODE_DISABLED and game.board.get_node("Towers").process_mode == Node.PROCESS_MODE_DISABLED, "end state freezes movement/combat")
	game.free()


func _run() -> void:
	_test_purchases()
	_test_blocked_route_economy()
	_test_cadence_and_rewards()
	_test_combat()
	_test_playable_sessions()
	print("Gameplay: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
