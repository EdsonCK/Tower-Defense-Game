extends SceneTree
## Exercise real Viewport input dispatch, HUD buttons, and scene reload.

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func click(position: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = button
		event.pressed = pressed
		root.push_input(event)


func _run() -> void:
	create_timer(15.0).timeout.connect(func() -> void:
		printerr("FAIL: input/restart suite timed out")
		quit(1)
	)
	root.size = Vector2i(1600, 900)
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	game.progression.unlocked.assign(["tesla", "basic_training"])
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	var right := game.hud.get_node("RightPanel") as Control
	var bottom := game.hud.get_node("BottomPanel") as Control
	check(right.position == Vector2(1280, 0) and right.size == Vector2(320, 900), "right panel stays inside its 320x900 region (actual %s)" % right.size)
	check(bottom.position == Vector2(0, 768) and bottom.size == Vector2(1280, 132), "bottom panel stays below the 1280x768 board")
	check(game.hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "transparent UI root allows board clicks")
	check(game.hud.get_node("RightPanel").mouse_filter == Control.MOUSE_FILTER_STOP and game.hud.get_node("BottomPanel").mouse_filter == Control.MOUSE_FILTER_STOP, "panels consume UI clicks")
	click(game.hud.skills_button.get_global_rect().get_center())
	check(game.skill_tree.visible, "real Skills button opens modal between waves")
	var close_button := game.skill_tree.get_node("Panel/Margin/Items/Footer/Close") as Button
	click(close_button.get_global_rect().get_center())
	check(not game.skill_tree.visible, "real Close button dismisses modal")
	click(game.hud.build_button.get_global_rect().get_center())
	check(game.building, "real Build Tower button enters build mode")
	click(Vector2(144, 144))
	check(game.currency == 140 and game.board.is_blocked(Vector2i(4, 4)), "board click places exactly one tower at aligned cell")
	for position in [Vector2(144, 144), Vector2(16, 400), Vector2(1264, 400), Vector2(1280, 100), Vector2(100, 768), Vector2(1300, 850), Vector2(-1, 100)]:
		click(position)
	check(game.currency == 140 and game.board.get_node("Towers").get_child_count() == 1, "occupied/reserved/UI/outside clicks do not place or charge")
	click(Vector2(1400, 850), MOUSE_BUTTON_RIGHT)
	check(not game.building, "right-click over panel cancels")
	click(game.hud.build_button.get_global_rect().get_center())
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	check(not game.building, "Escape cancels")
	click(Vector2(240, 240))
	check(game.currency == 140 and not game.board.is_blocked(Vector2i(7, 7)), "click outside build mode does nothing")
	click(Vector2(144, 144))
	check(game.selected_tower != null and not game.building and not game.hud.damage_button.disabled, "clicking existing tower opens management")
	click(game.hud.damage_button.get_global_rect().get_center())
	check(game.currency == 80 and game.selected_tower.damage() == 27 and game.hud.range_button.disabled and game.hud.speed_button.disabled, "damage upgrade button charges once; other categories reflect the next total cost")
	click(game.hud.remove_button.get_global_rect().get_center())
	check(game.currency == 110 and game.selected_tower == null and not game.board.is_blocked(Vector2i(4, 4)), "remove button refunds 30 and reopens cell")
	click(game.hud.build_button.get_global_rect().get_center())
	click(Vector2(144, 144))
	check(game.currency == 50 and game.board.is_blocked(Vector2i(4, 4)), "removed cell can be rebuilt")
	click(game.hud.start_button.get_global_rect().get_center())
	click(game.hud.start_button.get_global_rect().get_center())
	check(game.phase == TDGame.Phase.WAVE_ACTIVE and game.waves.current_wave == 1 and game.hud.start_button.disabled, "real Start Wave button starts exactly one wave")
	game.waves._process(0.01)
	check(game.waves.active_count > 0, "restart fixture includes active enemies")
	click(Vector2(144, 144))
	await process_frame
	await process_frame
	check(game.hud.get_node("RightPanel").size == Vector2(320, 900) and game.hud.get_node("BottomPanel").size == Vector2(1280, 132), "management and active-wave text stay within panel bounds")
	check(game.hud.cancel_button.disabled == false, "Cancel is enabled while a tower is selected")
	game.progression.award_wave("input-fixture", 1)
	var permanent_balance := game.progression.diamonds
	game._finish(TDGame.Phase.DEFEAT)
	var restart_button := game.hud.get_node("RightPanel/Margin/Items/Restart") as Button
	click(restart_button.get_global_rect().get_center())
	check(game.hud.restart_dialog.visible and current_scene == game, "restart first opens confirmation and preserves current run")
	await process_frame
	click(Vector2(game.hud.restart_dialog.position) + game.hud.restart_dialog.get_ok_button().get_global_rect().get_center())
	await scene_changed
	var restarted := current_scene as TDGame
	check(restarted != null and restarted != game, "Restart button reloads the main scene")
	check(restarted.progression.diamonds == permanent_balance and restarted.progression.has_skill("basic_training"), "Restart preserves diamonds and skill unlocks")
	check(restarted.currency == 200 and restarted.lives == 10 and restarted.phase == TDGame.Phase.READY, "restart restores currency, lives, and READY state")
	check(restarted.waves.current_wave == 0 and restarted.waves.active_count == 0 and restarted.waves.remaining_to_spawn == 0, "restart resets wave counters")
	check(restarted.board.get_node("Enemies").get_child_count() == 0 and restarted.board.get_node("Towers").get_child_count() == 0, "restart removes all enemy/tower instances")
	check(not restarted.board.is_blocked(Vector2i(4, 4)) and restarted.board.revision == 0 and restarted.board.path_is_valid(restarted.board.find_path(), GameConfig.SPAWN), "restart restores open navigation")
	check(not restarted.hud.start_button.disabled and not restarted.hud.build_button.disabled and not restarted.building, "restart restores buttons and selection")
	restarted.start_wave()
	restart_button = restarted.hud.get_node("RightPanel/Margin/Items/Restart") as Button
	await process_frame
	click(restart_button.get_global_rect().get_center())
	await process_frame
	click(Vector2(restarted.hud.restart_dialog.position) + restarted.hud.restart_dialog.get_ok_button().get_global_rect().get_center())
	await scene_changed
	restarted = current_scene as TDGame
	check(restarted.phase == TDGame.Phase.READY and restarted.currency == 200 and get_nodes_in_group("enemies").is_empty(), "repeated restart from active play is clean")
	print("Input/restart: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
