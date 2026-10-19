extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func clear_current_wave(game: TDGame) -> void:
	game.waves._process(1000.0)
	for node in game.board.active_enemies():
		var enemy := node as Enemy
		for layer in range(3): # Fixture: one hit per possible layer, not a balance simulation.
			enemy.take_damage(enemy.health + enemy.shield + enemy.armor)


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		printerr("FAIL: auto-start suite timed out")
		quit(1)
	)
	root.size = Vector2i(1600, 900)
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	root.add_child(game)
	current_scene = game
	game.waves.set_process(false)
	game.board.process_mode = Node.PROCESS_MODE_DISABLED
	await process_frame
	await process_frame
	check(not game.auto_start_waves and not game.hud.auto_start_button.button_pressed, "manual start is default")
	game.set_auto_start_waves(true)
	await process_frame
	check(game.phase == TDGame.Phase.READY and game.waves.current_wave == 0, "first wave waits for manual start")
	game.set_auto_start_waves(false)
	game.start_wave()
	clear_current_wave(game)
	await process_frame
	check(game.waves.current_wave == 1 and game.phase == TDGame.Phase.BETWEEN_WAVES, "off leaves cleared wave waiting")
	game.set_auto_start_waves(true)
	game.set_auto_start_waves(true)
	game.set_auto_start_waves(false)
	await process_frame
	check(game.waves.current_wave == 1, "turning off cancels queued auto-starts")
	var position := game.hud.auto_start_button.get_global_rect().get_center()
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)
	await process_frame
	check(game.auto_start_waves and game.waves.current_wave == 2 and game.phase == TDGame.Phase.WAVE_ACTIVE, "actual toggle starts next waiting wave")
	game._try_auto_start_wave()
	game.start_wave()
	check(game.waves.current_wave == 2, "manual and automatic requests cannot stack waves")
	game.set_auto_start_waves(false)
	clear_current_wave(game)
	await process_frame
	check(game.waves.current_wave == 2 and game.phase == TDGame.Phase.BETWEEN_WAVES, "switch off during wave stops subsequent auto-start")
	game.set_auto_start_waves(true)
	await process_frame
	for wave in range(3, 6):
		check(game.waves.current_wave == wave, "auto progression reaches wave %d" % wave)
		clear_current_wave(game)
		await process_frame
	check(game.skill_tree.visible and game.waves.current_wave == 5 and game.phase == TDGame.Phase.BETWEEN_WAVES, "wave-five skill menu blocks auto progression")
	check(game.progression.diamonds == 5 and game.hud.auto_start_button.disabled, "rewards are counted once and modal disables toggle")
	game.close_skill_tree()
	game.close_skill_tree()
	await process_frame
	check(game.waves.current_wave == 6 and game.phase == TDGame.Phase.WAVE_ACTIVE, "closing menu resumes exactly one next wave")
	clear_current_wave(game)
	game.open_skill_tree() # Interrupt the pending auto-start with manual skill access.
	await process_frame
	check(game.waves.current_wave == 6 and game.skill_tree.visible, "manually opened menu also blocks a pending start")
	game.close_skill_tree()
	await process_frame
	check(game.waves.current_wave == 7, "manual menu close resumes auto-start")
	clear_current_wave(game)
	game._finish(TDGame.Phase.DEFEAT)
	await process_frame
	check(game.waves.current_wave == 7 and not game.waves.running and game.hud.auto_start_button.disabled, "defeat cancels pending progression")
	game.restart()
	await scene_changed
	game = current_scene as TDGame
	check(game.phase == TDGame.Phase.READY and game.waves.current_wave == 0 and not game.auto_start_waves and not game.hud.auto_start_button.button_pressed, "restart resets auto mode off and starts no waves")
	game.waves.set_process(false)
	game.board.process_mode = Node.PROCESS_MODE_DISABLED
	game.start_wave()
	clear_current_wave(game)
	game.set_auto_start_waves(true)
	game.restart()
	await scene_changed
	game = current_scene as TDGame
	await process_frame
	check(game.phase == TDGame.Phase.READY and game.waves.current_wave == 0 and not game.auto_start_waves, "restart safely discards a queued auto-start")
	print("Auto-start: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
