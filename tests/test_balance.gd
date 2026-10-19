extends SceneTree
## Fresh-profile bots. Neither bot receives free gold, diamonds, levels, or damage.
## The good policy covers the route and spends earned resources; the poor policy
## spends the same starting budget on towers far away from all natural traffic.

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func spend_skills(game: TDGame) -> void:
	preload("res://tests/bot_policies.gd").spend_skills(game)


func build_and_upgrade(game: TDGame, wave: int) -> void:
	preload("res://tests/bot_policies.gd").build_and_upgrade(game, wave)


func session(seed_value: int, good: bool) -> Dictionary:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.waves.set_run_seed(seed_value)
	var cleared := 0
	for wave in range(1, 31):
		game.close_skill_tree()
		if good:
			if wave > 5:
				spend_skills(game)
			build_and_upgrade(game, wave)
		else:
			for cell in [Vector2i(4, 1), Vector2i(16, 1), Vector2i(28, 22)]:
				if game.tower_at_cell(cell) == null:
					game.purchase_tower(cell)
		game.start_wave()
		for frame in range(150 * 30):
			if game.phase != TDGame.Phase.WAVE_ACTIVE:
				break
			game.waves._process(1.0 / 30.0)
			for node in game.board.active_enemies():
				if game.is_finished():
					break
				(node as Enemy)._process(1.0 / 30.0)
			for node in game.board.get_node("Towers").get_children():
				if game.is_finished():
					break
				(node as Tower)._process(1.0 / 30.0)
		check(game.phase != TDGame.Phase.WAVE_ACTIVE, "bot wave resolves without timeout/stuck actors")
		if game.phase == TDGame.Phase.BETWEEN_WAVES:
			cleared += 1
		await process_frame # Flush resolved actors/signals between waves.
		if game.is_finished():
			break
	var result := {"cleared": cleared, "wave": game.waves.current_wave, "lives": game.lives, "diamonds": game.progression.diamonds}
	print("Balance bot: seed=%d policy=%s cleared=%d wave=%d lives=%d" % [seed_value, "good" if good else "poor", cleared, game.waves.current_wave, game.lives])
	game.free()
	await process_frame
	return result


func _run() -> void:
	for seed_value in [721, 109, 1337, 9001, 2026]:
		var good: Dictionary = await session(seed_value, true)
		var poor: Dictionary = await session(seed_value, false)
		check(good.cleared >= 20, "well-placed/spent fresh profile clears at least 20 waves")
		check(poor.wave <= 5 and poor.lives == 0, "off-route fresh profile fails within five waves")
	print("Balance: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
