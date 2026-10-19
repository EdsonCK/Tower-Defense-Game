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
	game.tower_scene = saved_scene
	check(game.purchase_tower(Vector2i(21, 12)) and game.purchase_tower(Vector2i(22, 12)), "three starting towers affordable")
	check(game.currency == 20 and not game.building, "stop build mode below tower cost")
	check(not game.purchase_tower(Vector2i(23, 12)) and not game.board.is_blocked(Vector2i(23, 12)), "unaffordable placement changes nothing")
	game.free()


func make_game() -> TDGame:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	return game


func _test_cadence_and_rewards() -> void:
	var game := make_game()
	game.start_wave()
	game.start_wave()
	check(game.waves.current_wave == 1 and game.waves.remaining_to_spawn == 8, "repeated start does not stack waves")
	check(game.phase == TDGame.Phase.WAVE_ACTIVE and game.hud.start_button.disabled, "active wave disables Start Wave")
	game.waves._process(0.001)
	check(game.waves.active_count == 1 and game.waves.remaining_to_spawn == 7, "first spawn counted")
	var first := game.board.get_node("Enemies").get_child(0) as Enemy
	check(first.health == 45, "wave 1 enemy has 45 HP")
	game.waves._process(1.198)
	check(game.waves.active_count == 1, "does not spawn early")
	game.waves._process(0.002)
	check(game.waves.active_count == 2, "second spawn at 1.2 seconds")
	first.take_damage(45)
	first.take_damage(45)
	check(game.currency == 212 and game.waves.active_count == 1, "kill gives 12 once and resolves one enemy")
	var second := game.board.active_enemies()[0] as Enemy
	second._process(30.0)
	check(game.lives == 9 and game.currency == 212 and game.waves.active_count == 0, "escape costs 1 life and gives no bounty")
	check(game.phase == TDGame.Phase.WAVE_ACTIVE, "wave waits for unspawned enemies")
	game.waves._process(10.0)
	check(game.waves.remaining_to_spawn == 0 and game.waves.active_count == 6, "all scheduled enemies spawn")
	for node in game.board.active_enemies():
		(node as Enemy).take_damage(45)
	check(game.currency == 212 + 6 * 12 + 30, "wave 1 bonus awarded once after all resolve")
	check(game.phase == TDGame.Phase.BETWEEN_WAVES and not game.hud.start_button.disabled, "next wave requires button")
	game.waves._process(100)
	check(game.waves.current_wave == 1, "waves do not start automatically")
	game.start_wave()
	game.waves._process(20)
	check(game.waves.active_count == 12 and (game.board.active_enemies()[0] as Enemy).health == 60, "wave 2 count and HP")
	for node in game.board.active_enemies():
		(node as Enemy).take_damage(60)
	check(game.currency == 212 + 6 * 12 + 30 + 12 * 12 + 30, "wave 2 gives bounty and 30 bonus")
	game.start_wave()
	game.waves._process(20)
	check(game.waves.active_count == 16 and (game.board.active_enemies()[0] as Enemy).health == 75, "wave 3 count and HP")
	for node in game.board.active_enemies():
		(node as Enemy).take_damage(75)
	check(game.phase == TDGame.Phase.VICTORY and game.lives == 9, "third wave triggers victory")
	check(game.currency == 212 + 6 * 12 + 30 + 12 * 12 + 30 + 16 * 12, "no wave 3 bonus")
	check(not game.purchase_tower(Vector2i(4, 4)), "no purchases after victory")
	game.start_wave()
	game.select_tower()
	check(game.waves.current_wave == 3 and not game.building and game.hud.start_button.disabled and game.hud.build_button.disabled, "victory disables gameplay intents")
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
	# Drive production movement, spawning, targeting and combat at a fixed delta.
	# No injected damage, speed, money, or lives; the 3 starting towers can win.
	var game := make_game()
	for cell in [Vector2i(3, 11), Vector2i(6, 11), Vector2i(9, 11)]:
		game.purchase_tower(cell)
	for wave in range(1, 4):
		game.start_wave()
		for frame in range(120 * 60):
			if game.phase != TDGame.Phase.WAVE_ACTIVE:
				break
			game.waves._process(1.0 / 60.0)
			for node in game.board.active_enemies():
				(node as Enemy)._process(1.0 / 60.0)
			for node in game.board.get_node("Towers").get_children():
				(node as Tower)._process(1.0 / 60.0)
		check(game.waves.current_wave == wave and game.waves.active_count == 0, "natural combat resolves all enemies in wave %d" % wave)
	check(game.phase == TDGame.Phase.VICTORY and game.lives > 0, "playable three-wave victory using only production combat")
	print("Victory session: lives=%d, currency=%d" % [game.lives, game.currency])
	game.free()
	game = make_game()
	for wave in range(1, 3):
		game.start_wave()
		for frame in range(120 * 60):
			if game.phase != TDGame.Phase.WAVE_ACTIVE:
				break
			game.waves._process(1.0 / 60.0)
			for node in game.board.active_enemies():
				if game.is_finished():
					break
				(node as Enemy)._process(1.0 / 60.0)
	check(game.phase == TDGame.Phase.DEFEAT and game.lives == 0, "unprotected base loses on tenth escaped enemy")
	check(game.currency == 230, "escapes grant no bounty; surviving wave 1 gives only its 30 bonus")
	var active := game.waves.active_count
	game.waves._process(100)
	game.start_wave()
	game.select_tower()
	check(not game.waves.running and game.waves.remaining_to_spawn == 0 and game.waves.active_count == active and not game.building, "defeat stops spawning and gameplay input")
	check(game.board.get_node("Enemies").process_mode == Node.PROCESS_MODE_DISABLED and game.board.get_node("Towers").process_mode == Node.PROCESS_MODE_DISABLED, "end state freezes movement/combat")
	game.free()


func _run() -> void:
	_test_purchases()
	_test_cadence_and_rewards()
	_test_combat()
	_test_playable_sessions()
	print("Gameplay: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
