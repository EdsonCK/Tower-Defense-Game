extends SceneTree
## Regression tests for fixed click targets, confirmation, damage pools and research.

var checks := 0
var failures := 0
var deaths := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func click(viewport: Viewport, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	viewport.push_input(motion)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		viewport.push_input(event)


func _test_layers(game: TDGame) -> void:
	var enemy := Enemy.new()
	game.board.get_node("Enemies").add_child(enemy)
	var profile := EnemyProfile.base(EnemyProfile.Kind.ARMORED)
	profile.shield = 30
	enemy.setup_profile(game.board, profile)
	enemy.set_process(false)
	enemy.died.connect(func(_enemy: Enemy) -> void: deaths += 1)
	check(enemy.max_armor == 45 and enemy.max_shield == 30 and enemy.max_health == 105, "all three maxima initialized independently")
	enemy.take_damage(999, 999, 0)
	check(enemy.shield == 30 and enemy.armor == 45 and enemy.health == 105, "zero shield damage cannot bypass top shield")
	enemy.take_damage(999, 999, 7)
	check(enemy.shield == 23 and enemy.armor == 45 and enemy.health == 105, "shield-specific stat alone damages the top shield")
	enemy.take_damage(999, 999, 999)
	check(enemy.shield == 0 and enemy.armor == 45 and enemy.health == 105 and deaths == 0, "shield overkill never touches armor or health")
	enemy.take_damage(999, 8, 999)
	check(enemy.armor == 37 and enemy.health == 105, "armor-specific stat is used after shields")
	enemy.take_damage(999, 999, 999)
	check(enemy.armor == 0 and enemy.health == 105 and deaths == 0, "armor overkill never touches health")
	enemy.take_damage(12, 999, 999)
	check(enemy.health == 93, "health-specific stat applies only after defenses break")
	enemy.take_damage(0)
	enemy.take_damage(-100)
	check(enemy.health == 93, "nonpositive health hits do not heal")
	enemy.take_damage(999)
	enemy.take_damage(999)
	check(enemy.health == 0 and deaths == 1, "three layers still resolve death once")
	enemy.free()
	var basic := Tower.new()
	var tesla := Tower.new()
	tesla.kind = Tower.Kind.TESLA
	check(basic.damage() == 15 and basic.armor_damage() == 24 and basic.shield_damage() == 8, "basic damage specializes in armor")
	check(tesla.damage() == 12 and tesla.armor_damage() == 6 and tesla.shield_damage() == 24, "Tesla damage specializes in shields")
	game.board.get_node("Towers").add_child(basic)
	game.board.get_node("Towers").add_child(tesla)
	var layered := Enemy.new()
	game.board.get_node("Enemies").add_child(layered)
	profile.shield = 40
	layered.setup_profile(game.board, profile)
	basic.position = layered.position
	tesla.position = layered.position
	basic.attack(layered)
	check(layered.shield == 32 and layered.armor == 45 and layered.health == 105, "real basic shot spends its shield-specific 8 damage")
	tesla.attack(layered)
	check(layered.shield == 8 and layered.armor == 45 and layered.health == 105, "real Tesla pulse specializes with 24 shield damage")
	tesla.attack(layered)
	check(layered.shield == 0 and layered.armor == 45 and layered.health == 105, "real shield-breaking shot cannot hit plating")
	tesla.attack(layered)
	check(layered.armor == 39 and layered.health == 105, "Tesla deals its weaker 6 armor damage after shield break")
	basic.attack(layered)
	check(layered.armor == 15 and layered.health == 105, "basic specializes with 24 armor damage")
	basic.attack(layered)
	check(layered.armor == 0 and layered.health == 105, "real plating-breaking shot cannot hit health")
	layered.free()
	basic.free()
	tesla.free()
	check(Enemy.HEALTH_COLOR.g > Enemy.HEALTH_COLOR.r and Enemy.ARMOR_COLOR.r > 0.9 and Enemy.SHIELD_COLOR.b > Enemy.SHIELD_COLOR.g, "bar palette encodes green health, white armor and purple shield")


func _test_waves() -> void:
	var last_count := 64
	var last_interval := 0.678
	var last_duration := 63 * last_interval
	var generator := WaveGenerator.new(481)
	for wave in [31, 40, 50, 75, 100, 150, 200, 10000]:
		var count := generator.generate(wave).size()
		var interval := generator.interval_for(wave)
		var duration := (count - 1) * interval
		check(count >= last_count and count <= GameConfig.MAX_WAVE_ENEMIES, "late-wave count grows within budget at %d" % wave)
		check(interval <= last_interval and interval >= GameConfig.MIN_SPAWN_INTERVAL, "spawn rate accelerates within budget at %d" % wave)
		check(duration >= last_duration, "spawn window never shrinks as density rises at %d" % wave)
		print("Spawn window: wave=%d enemies=%d interval=%.3fs duration=%.1fs" % [wave, count, interval, duration])
		last_count = count
		last_interval = interval
		last_duration = duration
	check(WaveGenerator.late_wave_count(50) >= 150 and WaveGenerator.late_wave_count(100) >= 400, "post-30 waves have substantially more enemies")


func _test_research() -> void:
	var profile := Progression.new("")
	profile.diamonds = 10000 # Isolated skill-effect fixture, not balance.
	var seen: Array[String] = []
	for id in SkillCatalog.IDS:
		var node: Dictionary = SkillCatalog.NODES[id]
		check(not seen.has(id) and (node.requires.is_empty() or seen.has(node.requires)), "research prerequisite is valid and acyclic: " + id)
		if not node.requires.is_empty():
			check(int(node.cost) >= int(SkillCatalog.NODES[node.requires].cost), "research cost rises with depth: " + id)
		var before := profile.diamonds
		check(profile.purchase(id) and profile.diamonds == before - int(node.cost), "new research purchase charges correctly: " + id)
		check(not profile.purchase(id) and profile.diamonds == before - int(node.cost), "research cannot be purchased twice: " + id)
		seen.append(id)
	check(seen.size() == 40, "catalog has 40 permanent upgrades")
	check(profile.gold_reward(30) == 60, "full economy tree gives double gold")
	var tower := Tower.new()
	tower.configure_progression(profile)
	check(tower.damage() == 23 and tower.armor_damage() == 61 and tower.shield_damage() == 21, "damage and specialty branches update separate damage stats")
	check(is_equal_approx(tower.attack_range(), 134.4) and is_equal_approx(tower.attack_interval(), 0.8 * 0.92 * 0.88), "optics and firing branches apply without choosing a gold track")
	var enemy := EnemyProfile.base(EnemyProfile.Kind.ARMORED)
	profile.apply_enemy_nerfs(enemy)
	check(enemy.armor == 36 and enemy.hit_points == 76 and is_equal_approx(enemy.speed, 32.4), "deep enemy nerfs apply to new profiles")
	tower.free()
	# Schema 1 and all old identifiers remain valid; new branches are opt-in.
	var legacy := {"schema": 1, "diamonds": 7, "unlocked": ["tesla", "basic_training", "engineering"], "last_run": "old", "last_wave": 5}
	check(profile._valid_document(legacy), "existing saved profiles remain readable")
	var path := "user://tests/expanded_%d.json" % Time.get_ticks_usec()
	var saved := Progression.new(path)
	saved.diamonds = profile.diamonds
	saved.unlocked.assign(profile.unlocked)
	check(saved.save_profile(), "expanded tree can be saved")
	var loaded := Progression.new(path)
	check(loaded.load_profile() and loaded.unlocked == saved.unlocked and loaded.diamonds == saved.diamonds, "all new nodes survive a profile reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _test_ui(game: TDGame) -> void:
	var controls: Array[Control] = [game.hud.damage_button, game.hud.range_button, game.hud.speed_button, game.hud.special_button, game.hud.remove_button, game.hud.start_button, game.hud.build_button, game.hud.tesla_button, game.hud.skills_button, game.hud.selected_label, game.hud.status_label, game.hud.get_node("RightPanel/Margin/Items/Restart")]
	var bottom_controls: Array[Control] = [game.hud.selection_label, game.hud.message_label, game.hud.get_node("BottomPanel/Margin/Items/Legend")]
	var bottom_rectangles: Array[Rect2] = []
	for control in bottom_controls:
		bottom_rectangles.append(control.get_global_rect())
	var rectangles: Array[Rect2] = []
	for control in controls:
		rectangles.append(control.get_global_rect())
		check(Rect2(1280, 0, 320, 900).encloses(control.get_global_rect()), "HUD control stays within sidebar: " + control.name)
	game.progression.unlocked.assign(["tesla", "basic_training"])
	game.currency = 10000 # Input fixture to allow repeated range purchases.
	game.purchase_tower(Vector2i(4, 4))
	var tower := game.tower_at_cell(Vector2i(4, 4))
	tower.set_process(false)
	game.select_placed_tower(tower)
	await process_frame
	var cursor := game.hud.range_button.get_global_rect().get_center()
	click(root, cursor)
	check(game.hud.selected_label.get_visible_line_count() == game.hud.selected_label.get_line_count(), "all three tower stat lines are visible")
	check(tower.levels(Tower.Upgrade.RANGE) == 1 and tower.upgrade_level == 1, "real range button selects range track")
	game.start_wave()
	await process_frame
	for i in range(controls.size()):
		check(controls[i].get_global_rect() == rectangles[i], "active-wave text cannot move target: " + controls[i].name)
	game.waves._process(1000.0)
	for node in game.board.active_enemies():
		var enemy := node as Enemy
		for layer in range(3):
			enemy.take_damage(9999999)
	await process_frame
	check(game.phase == TDGame.Phase.BETWEEN_WAVES, "fixture completes a real scheduled wave")
	for i in range(controls.size()):
		check(controls[i].get_global_rect() == rectangles[i], "wave ending cannot move target: " + controls[i].name)
	game.hud.show_message("A long wave-clear message ".repeat(18))
	await process_frame
	for i in range(bottom_controls.size()):
		check(bottom_controls[i].get_global_rect() == bottom_rectangles[i], "footer message cannot move text: " + bottom_controls[i].name)
	click(root, cursor)
	check(game.tower_at_cell(Vector2i(4, 4)) == tower and tower.upgrade_level == 2, "same stationary cursor upgrades range again instead of selling")
	check(not game.hud.remove_button.get_global_rect().has_point(cursor), "Sell is spatially separated from upgrade targets")
	game.currency = 999999999
	game.waves.current_wave = 100000000
	game._refresh_hud()
	await process_frame
	for i in range(controls.size()):
		check(controls[i].get_global_rect() == rectangles[i], "large counters cannot reflow HUD: " + controls[i].name)
	game.waves.current_wave = 1
	game.set_auto_start_waves(true)
	click(root, controls[-1].get_global_rect().get_center())
	await process_frame
	check(game.waves.current_wave == 1 and game.phase == TDGame.Phase.BETWEEN_WAVES, "restart prompt blocks a queued automatic wave")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	root.push_input(escape)
	await process_frame
	check(not game.hud.restart_dialog.visible and not game._restart_confirming and game.waves.current_wave == 2, "Escape cancels confirmation and resumes one queued wave")
	game.set_auto_start_waves(false)
	var before_currency := game.currency
	var before_wave := game.waves.current_wave
	click(root, controls[-1].get_global_rect().get_center())
	await process_frame
	check(game.hud.restart_dialog.visible and game._restart_confirming and not game._restart_pending, "restart asks before any reset")
	check(game.board.process_mode == Node.PROCESS_MODE_DISABLED and game.waves.process_mode == Node.PROCESS_MODE_DISABLED, "restart decision pauses enemies, towers and spawn scheduler")
	game.start_wave()
	check(not game.purchase_tower(Vector2i(5, 5)) and not game.upgrade_selected_tower(Tower.Upgrade.RANGE) and not game.remove_selected_tower(), "pending confirmation blocks direct gameplay intents")
	check(game.currency == before_currency and game.waves.current_wave == before_wave and game.tower_at_cell(Vector2i(4, 4)) == tower, "waiting for confirmation preserves the run")
	click(root, Vector2(game.hud.restart_dialog.position) + game.hud.restart_dialog.get_cancel_button().get_global_rect().get_center())
	await process_frame
	check(not game.hud.restart_dialog.visible and not game._restart_confirming and not game._restart_pending, "real Keep Playing button cancels restart")
	check(game.waves.process_mode == Node.PROCESS_MODE_INHERIT and game.board.process_mode == Node.PROCESS_MODE_DISABLED, "cancel restores prior process modes exactly")
	game.waves.stop()
	game.phase = TDGame.Phase.BETWEEN_WAVES
	game.open_skill_tree()
	await process_frame
	await process_frame
	check(game.skill_tree.buy_buttons.size() == 40 and game.skill_tree.scroll.get_v_scroll_bar().max_value > game.skill_tree.scroll.size.y, "icon research graph scrolls to all 40 upgrades")
	game.progression.diamonds = 1000
	game.progression.unlocked.assign(SkillCatalog.IDS)
	game.progression.unlocked.erase("shield_decay")
	game.skill_tree.refresh(game.progression)
	var last := game.skill_tree.buy_buttons["shield_decay"] as Button
	game.skill_tree.scroll.ensure_control_visible(last)
	await process_frame
	check(game.skill_tree.scroll.get_global_rect().encloses(last.get_global_rect()), "last research button is reachable inside scroll area")
	click(root, last.get_global_rect().get_center())
	check(game.progression.has_skill("shield_decay") and game.progression.diamonds == 990, "last visible research button buys correct expensive node")
	check(tower.damage() == 23 and tower.armor_damage() == 61 and is_equal_approx(tower.attack_range(), 192.0), "new passive purchases refresh already placed towers including their chosen track")
	game.close_skill_tree()


func _run() -> void:
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("FAIL: UI/layer suite timed out")
		quit(1)
	)
	root.size = Vector2i(1600, 900)
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	root.add_child(game)
	game.board.process_mode = Node.PROCESS_MODE_DISABLED
	game.waves.set_process(false)
	await process_frame
	await process_frame
	_test_layers(game)
	_test_waves()
	_test_research()
	await _test_ui(game)
	game.free()
	await process_frame
	print("UI/layers/research: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
