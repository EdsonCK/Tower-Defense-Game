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


func make_game() -> TDGame:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.waves.set_run_seed(981)
	return game


func click_button(button: Button) -> void:
	var position := button.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)


func _test_profile() -> void:
	var path := "user://tests/profile_%d.json" % Time.get_ticks_usec()
	var profile := Progression.new(path)
	check(profile.load_profile() and profile.diamonds == 0, "new profile starts empty")
	for wave in range(1, 6):
		check(profile.award_wave("run-a", wave), "completed wave awards one diamond")
	check(not profile.award_wave("run-a", 5) and profile.diamonds == 5, "repeated completion cannot award twice")
	check(not profile.purchase("basic_training") and profile.diamonds == 5, "Tesla is the only initially purchasable skill")
	check(profile.purchase("tesla") and profile.diamonds == 2, "Tesla unlock costs exactly 3")
	check(not profile.purchase("tesla") and not profile.purchase("basic_training") and profile.diamonds == 2, "duplicate/unaffordable purchase cannot charge")
	var loaded := Progression.new(path)
	check(loaded.load_profile() and loaded.diamonds == 2 and loaded.has_skill("tesla"), "diamonds and unlock survive a new profile instance")
	check(not loaded.award_wave("run-a", 5) and loaded.award_wave("run-b", 1) and loaded.diamonds == 3, "persisted award guard and a new run's earnings")
	check(loaded.purchase("basic_training") and loaded.diamonds == 0, "next skill persists")
	# A corrupt primary recovers the immediately preceding valid atomic save.
	var corrupt := FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_string("{incomplete")
	corrupt.close()
	var recovered := Progression.new(path)
	check(recovered.load_profile() and recovered.has_skill("tesla") and not recovered.save_error.is_empty(), "backup recovery is visible")
	check(recovered.save_profile() and recovered.save_error.is_empty(), "backup can repair the primary without destroying the good backup")
	var repaired := Progression.new(path)
	check(repaired.load_profile() and repaired.has_skill("tesla") and repaired.save_error.is_empty(), "repaired primary loads normally")
	for suffix in ["", ".bak"]:
		var invalid := FileAccess.open(path + suffix, FileAccess.WRITE)
		invalid.store_string(JSON.stringify({"schema": 999, "diamonds": -4, "unlocked": []}))
		invalid.close()
	var invalid_profile := Progression.new(path)
	check(not invalid_profile.load_profile() and not invalid_profile.save_error.is_empty(), "invalid schema/data is rejected and surfaced")
	invalid_profile.award_wave("memory-run", 1)
	invalid_profile.diamonds = 3
	check(not invalid_profile.purchase("tesla") and invalid_profile.diamonds == 3 and not invalid_profile.has_skill("tesla"), "failed persistence rolls purchase back")
	check(FileAccess.get_file_as_string(path).contains("999"), "unreadable existing profile is preserved")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))


func _test_game_flow() -> void:
	var game := make_game()
	game.purchase_tower(Vector2i(4, 4))
	game.select_placed_tower(game.tower_at_cell(Vector2i(4, 4)))
	check(not game.upgrade_selected_tower(Tower.Upgrade.DAMAGE) and game.currency == 140, "fresh basic towers cannot upgrade")
	game.select_tower(Tower.Kind.TESLA)
	check(not game.building, "Tesla cannot be selected before unlock")
	game.build_kind = Tower.Kind.TESLA
	check(not game.purchase_tower(Vector2i(5, 5)) and not game.board.is_blocked(Vector2i(5, 5)), "direct purchase also enforces Tesla lock")
	game.build_kind = Tower.Kind.BASIC
	for wave in range(1, 11):
		game.close_skill_tree()
		game.start_wave()
		game.waves._process(1000.0)
		for node in game.board.active_enemies():
			var enemy := node as Enemy
			for layer in range(3): # Fixture: one hit per possible layer, not a balance simulation.
				enemy.take_damage(enemy.health + enemy.shield + enemy.armor)
		check(game.progression.diamonds == wave, "wave %d earns exactly one diamond" % wave)
		check(game.skill_tree.visible == (wave % 5 == 0), "skill modal appears exactly at wave %d milestone" % wave)
		game._on_wave_completed(wave)
		check(game.progression.diamonds == wave, "duplicate callback awards no extra diamond")
		if game.skill_tree.visible:
			var gold := game.currency
			game.start_wave()
			check(game.waves.current_wave == wave and not game.purchase_tower(Vector2i(6, 6)) and game.currency == gold, "modal blocks starting/building")
	var panel := game.skill_tree.get_node("Panel") as Control
	await process_frame
	check(panel.position.x >= 0 and panel.position.y >= 0 and panel.get_rect().end.x <= 1600 and panel.get_rect().end.y <= 900, "skill panel fits logical window")
	game.process_mode = Node.PROCESS_MODE_INHERIT
	root.size = Vector2i(1600, 900)
	await process_frame
	click_button(game.skill_tree.buy_buttons["tesla"] as Button)
	check(game.progression.has_skill("tesla") and game.progression.diamonds == 7, "real Tesla skill button buys the correct node")
	click_button(game.skill_tree.buy_buttons["basic_training"] as Button)
	check(game.progression.has_skill("basic_training") and game.progression.diamonds == 4 and game.tower_at_cell(Vector2i(4, 4)).upgrades_enabled, "real training button enables existing basic towers")
	click_button(game.skill_tree.buy_buttons["tesla_training"] as Button)
	check(game.progression.has_skill("tesla_training") and game.progression.diamonds == 0, "real Tesla training button is a separate unlock")
	game.process_mode = Node.PROCESS_MODE_DISABLED
	# A passive permanent upgrade must refresh already placed towers as well.
	game.progression.diamonds = 4 # Dedicated effect fixture after accounting checks.
	check(game.purchase_skill("engineering") and game.tower_at_cell(Vector2i(4, 4)).damage() == 17, "permanent engineering updates existing tower damage")
	game.close_skill_tree()
	game.select_tower(Tower.Kind.TESLA)
	check(game.purchase_tower(Vector2i(5, 5)) and game.tower_at_cell(Vector2i(5, 5)).kind == Tower.Kind.TESLA, "unlocked Tesla can be built")
	var tesla := game.tower_at_cell(Vector2i(5, 5))
	game.select_placed_tower(tesla)
	check(tesla.damage() == 13, "permanent engineering applies to newly built Tesla")
	check(tesla.upgrades_enabled and not game.upgrade_selected_tower(Tower.Upgrade.SPECIAL), "training does not bypass the unique-skill lock")
	var gold := game.currency
	check(game.remove_selected_tower() and game.currency == gold + 55, "Tesla removal refunds half its own construction price")
	game.start_wave()
	game.open_skill_tree()
	check(not game.skill_tree.visible and not game.purchase_skill("salvage"), "tree cannot be opened or purchased mid-wave")
	# Defeat/partial-wave callbacks must not mint a completion diamond.
	var diamonds_before := game.progression.diamonds
	game._finish(TDGame.Phase.DEFEAT)
	game._on_wave_completed(game.waves.current_wave)
	check(game.progression.diamonds == diamonds_before, "defeat does not award a partial-wave diamond")
	game.free()


func _test_effects() -> void:
	var profile := Progression.new("")
	profile.diamonds = 40
	for id in ["tesla", "salvage", "gold_mastery", "sluggish", "fragile"]:
		check(profile.purchase(id), "effect prerequisite purchase: " + id)
	check(profile.gold_reward(12) == 16 and profile.gold_reward(30) == 42, "gold boosts add to 40 percent and round down")
	var enemy := EnemyProfile.base(EnemyProfile.Kind.SHIELDED)
	profile.apply_enemy_nerfs(enemy)
	check(is_equal_approx(enemy.speed, 59.4) and enemy.hit_points == 68 and enemy.shield == 26, "permanent speed, health and shield nerfs apply")


func _run() -> void:
	_test_profile()
	await _test_game_flow()
	_test_effects()
	print("Progression: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
