extends SceneTree
## Optional rendered fixture. Requires a real or virtual X11/Wayland/Windows display.
## Run: godot --path . --script res://tests/capture_ui.gd -- --output=/tmp/td-ui
## Fixture uses free resources and synthetic bars for visual review, not balance.

var output := "user://ui-previews"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless":
		printerr("UI capture needs a rendered display; run without --headless")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) != OK:
		printerr("Could not create UI preview directory")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var game := load("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	game.progression.unlocked.assign(["tesla", "basic_training", "tesla_training", "piercing", "salvage"])
	game.progression.diamonds = 12
	root.add_child(game)
	game.board.process_mode = Node.PROCESS_MODE_DISABLED
	game.waves.set_process(false)
	game.waves.set_run_seed(472)
	game.currency = 10000
	for x in [1, 3, 5]:
		for y in range(1, 23):
			game.purchase_tower(Vector2i(x, y))
	for x in [8, 13, 18, 23, 28, 33]:
		game.purchase_tower(Vector2i(x, 11))
		game.build_kind = Tower.Kind.TESLA
		game.purchase_tower(Vector2i(x, 13))
		game.build_kind = Tower.Kind.BASIC
	game.currency = 1480
	game.select_placed_tower(game.tower_at_cell(Vector2i(3, 12)))
	game.upgrade_selected_tower(Tower.Upgrade.RANGE)
	game.waves.current_wave = 39
	game.start_wave()
	game.waves._process(16.0)
	var index := 0
	for node in game.board.active_enemies():
		var enemy := node as Enemy
		enemy.position = Vector2(220 + index * 28, 400)
		if index % 4 == 0:
			enemy.shield = 28
			enemy.max_shield = 40
			enemy.armor = 34
			enemy.max_armor = 45
			enemy.health = roundi(enemy.max_health * 0.8)
		enemy.queue_redraw()
		index += 1
	game._refresh_hud()
	game.hud.show_message("Hold the line • Purple shields → White armor → Green health • Specialize your damage to break each layer.")
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	_capture("hud.png")
	game.waves.stop()
	game.phase = TDGame.Phase.BETWEEN_WAVES
	game.open_skill_tree()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	_capture("research.png")
	game.close_skill_tree()
	game.hud.get_node("RightPanel/Margin/Items/Restart").pressed.emit()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	_capture("restart.png")
	game.free()
	await process_frame
	quit()

func _capture(name: String) -> void:
	var path := output.path_join(name)
	if root.get_texture().get_image().save_png(path) != OK:
		printerr("UI capture failed: ", path)
		quit(1)
	else:
		print("UI preview: ", path)
