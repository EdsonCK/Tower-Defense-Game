extends "res://tests/test_base.gd"
## Diamonds, the skill tree (rules, persistence, menu), Tesla towers, skill-gated and
## unique upgrades, gold boosts, enemy nerfs and permanent upgrades.
##   godot --headless --path <project> --script res://tests/test_skills.gd


func get_tests() -> Array[Callable]:
	return [
		test_skill_tree_data_is_consistent,
		test_first_skill_is_tesla_for_three_diamonds,
		test_diamond_per_wave_and_menu_every_fifth_wave,
		test_skill_menu_pauses_and_blocks_play,
		test_skill_menu_buttons_unlock_skills,
		test_unlock_rules_and_charging,
		test_progress_is_permanent_across_restarts_and_saves,
		test_corrupt_or_tampered_save_is_safe,
		test_reset_progress,
		test_tesla_locked_until_unlocked,
		test_tesla_hits_every_enemy_in_small_range,
		test_upgrades_locked_per_tower_type,
		test_unique_paths_need_their_own_skill,
		test_armor_piercing_ignores_armor,
		test_static_field_slows,
		test_gold_boosts,
		test_enemy_nerfs_apply_to_new_spawns,
		test_permanent_tower_buffs_and_lives,
		test_auto_start_off_by_default,
		test_auto_start_runs_waves_back_to_back,
		test_auto_start_waits_for_skill_menu,
		test_auto_start_setting_is_saved,
	]


func test_skill_tree_data_is_consistent() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var positions: Dictionary = {}
	for id: String in SkillTree.SKILLS:
		var skill: Dictionary = SkillTree.SKILLS[id]
		for key: String in ["name", "cost", "requires", "pos", "desc", "effects"]:
			if not skill.has(key):
				problems.append("%s missing %s" % [id, key])
		if skill["cost"] <= 0:
			problems.append("%s has no cost" % id)
		for required: String in skill["requires"]:
			if not SkillTree.SKILLS.has(required):
				problems.append("%s requires unknown %s" % [id, required])
		if positions.has(skill["pos"]):
			problems.append("%s and %s share a menu position" % [id, positions[skill["pos"]]])
		positions[skill["pos"]] = id
	# Every skill must be reachable from the root.
	var tree: SkillTree = SkillTree.new()
	tree.restore(SkillTree.SKILLS.keys())
	if tree.unlocked_ids().size() != SkillTree.SKILLS.size():
		problems.append("some skills are unreachable from the root")
	_check(problems.is_empty(), "skill data complete, positions unique, all skills reachable%s" % ("" if problems.is_empty() else " - " + problems[0]))


func test_first_skill_is_tesla_for_three_diamonds() -> void:
	var tree: SkillTree = SkillTree.new()
	var available: Array[String] = []
	for id: String in SkillTree.SKILLS:
		if tree.prerequisites_met(id):
			available.append(id)
	_check(available == ["tesla"], "the only skill available at the start is the Tesla Tower (%s)" % [available])
	_check(tree.cost("tesla") == 3, "it costs 3 diamonds")
	_check(not tree.can_unlock("tesla", 2) and tree.can_unlock("tesla", 3), "affordable with exactly 3 diamonds")


func test_diamond_per_wave_and_menu_every_fifth_wave() -> void:
	var main: Node2D = _make_main()
	var opened_after: Array[int] = []
	for wave in range(1, 11):
		main._on_start_wave_pressed()
		while main.wave_manager.is_wave_active():
			_simulate(main, 0.05, 1)
			_kill_all_active(main)
			_free_resolved(main)
		if wave in [1, 5, 10]:
			_check(main.diamonds == wave, "wave %d complete -> %d diamonds" % [wave, main.diamonds])
		if main.is_skill_menu_open():
			opened_after.append(wave)
			_close_skill_menu(main)
	_check(opened_after == [5, 10], "skill tree pops up after waves 5 and 10 only (%s)" % [opened_after])
	_check(main.diamonds == 10, "10 waves -> 10 diamonds")


func test_skill_menu_pauses_and_blocks_play() -> void:
	var main: Node2D = _make_main()
	main.open_skill_menu("test")
	await process_frame
	_check(main.is_skill_menu_open() and paused, "opening the skill tree pauses the game")
	var menu: SkillTreeMenu = main.hud.get_skill_menu()
	_check(menu.get_global_rect() == Rect2(0, 0, 1600, 900) and menu.mouse_filter == Control.MOUSE_FILTER_STOP, "the menu is a full-screen modal that swallows clicks")
	main._on_start_wave_pressed()
	_check(main.wave_manager.current_wave == 0, "Start Wave does nothing while the menu is open")
	_check(not main.try_buy_tower(Vector2i(10, 5)), "building does nothing while the menu is open")
	# A real click over the board must hit the modal, not the board.
	var click: InputEventMouseButton = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(400, 300)
	click.global_position = click.position
	main._on_build_pressed(TowerTypes.BASIC)
	_check(not main.build_mode, "build buttons do nothing while the menu is open")
	click.pressed = true
	root.push_input(click)
	click = click.duplicate()
	click.pressed = false
	root.push_input(click)
	await process_frame
	_check(main.get_tower_count() == 0, "clicks on the board area while the menu is open place nothing")
	var esc: InputEventKey = InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	root.push_input(esc)
	await process_frame
	_check(not main.is_skill_menu_open() and not paused, "Esc closes the menu and unpauses")
	main._on_start_wave_pressed()
	_check(main.wave_manager.current_wave == 1, "waves can start again after closing")


func test_skill_menu_buttons_unlock_skills() -> void:
	var main: Node2D = _make_main()
	main.diamonds = 3
	main.open_skill_menu("test")
	var menu: SkillTreeMenu = main.hud.get_skill_menu()
	_check(not menu.get_skill_button("tesla").disabled, "affordable root skill button is enabled")
	_check(menu.get_skill_button("fortify").disabled, "skills behind the root are disabled")
	menu.get_skill_button("tesla").pressed.emit()
	_check(main.skills.is_unlocked("tesla") and main.diamonds == 0, "pressing the Tesla button unlocks it for 3 diamonds")
	_check(menu.get_skill_button("tesla").disabled and menu.get_skill_button("tesla").text.contains("UNLOCKED"), "button now shows UNLOCKED")
	_check(menu.get_skill_button("fortify").disabled, "next skills visible but unaffordable with 0 diamonds")
	main.diamonds = 3
	main.hud.refresh_skill_menu(main.diamonds, main.skills)
	_check(not menu.get_skill_button("fortify").disabled, "they enable once affordable")
	main.close_skill_menu()


func test_unlock_rules_and_charging() -> void:
	var main: Node2D = _make_main()
	main.diamonds = 2
	_check(not main.try_unlock_skill("tesla") and main.diamonds == 2, "cannot unlock without enough diamonds")
	main.diamonds = 100
	_check(not main.try_unlock_skill("fortify") and main.diamonds == 100, "cannot skip prerequisites")
	_check(main.try_unlock_skill("tesla") and main.diamonds == 97, "Tesla unlock charges 3")
	_check(not main.try_unlock_skill("tesla") and main.diamonds == 97, "cannot buy the same skill twice")
	_check(not main.try_unlock_skill("no_such_skill"), "unknown skills are rejected")


func test_progress_is_permanent_across_restarts_and_saves() -> void:
	var path: String = "user://test_progress_%d.json" % Time.get_ticks_usec()
	ProgressStore.save_path = path
	var main: Node2D = _make_main()
	main.diamonds = 10
	main.try_unlock_skill("tesla")
	main.try_unlock_skill("fortify")
	main.restart_game()
	_check(main.diamonds == 4 and main.skills.is_unlocked("tesla") and main.skills.is_unlocked("fortify"), "Restart keeps diamonds and unlocks")
	_check(main.lives == GameConfig.STARTING_LIVES + 5, "permanent Fortify gives +5 lives on every new run (%d)" % main.lives)
	_cleanup_root()
	var relaunched: Node2D = _make_main()  # fresh scene = game relaunch, loads from disk
	_check(relaunched.diamonds == 4 and relaunched.skills.is_unlocked("fortify") and relaunched.skills.is_tower_unlocked(TowerTypes.TESLA), "progress survives a relaunch (loaded from %s)" % path)
	relaunched._on_start_wave_pressed()
	while relaunched.wave_manager.is_wave_active():
		_simulate(relaunched, 0.05, 1)
		_kill_all_active(relaunched)
	_cleanup_root()
	_check(ProgressStore.load_progress()["diamonds"] == 5, "diamonds earned from a wave are saved immediately")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ProgressStore.save_path = ""


func test_corrupt_or_tampered_save_is_safe() -> void:
	var path: String = "user://test_progress_bad_%d.json" % Time.get_ticks_usec()
	ProgressStore.save_path = path
	for garbage: String in ["this is not { json", "[1, 2, 3]", ""]:
		var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		file.store_string(garbage)
		file.close()
		var progress: Dictionary = ProgressStore.load_progress()
		_check(progress["diamonds"] == 0 and progress["unlocked"].is_empty() and progress["auto_start"] == false, "unreadable save %s falls back to defaults" % JSON.stringify(garbage))
	var tampered: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	tampered.store_string(JSON.stringify({"diamonds": -50, "unlocked": ["overclock", "bogus", 42, "fortify"], "auto_start": "yes"}))
	tampered.close()
	var main: Node2D = _make_main()
	_check(main.diamonds == 0, "negative diamonds clamp to 0")
	_check(main.skills.unlocked_ids().is_empty(), "skills whose prerequisites are missing (or unknown ids) are ignored")
	_check(main.auto_start == false, "non-boolean settings are ignored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ProgressStore.save_path = ""


func test_reset_progress() -> void:
	var main: Node2D = _make_main()
	main.diamonds = 20
	main.try_unlock_skill("tesla")
	main.try_unlock_skill("fortify")
	main.currency = 999
	main.reset_progress()
	_check(main.diamonds == 0 and main.skills.unlocked_ids().is_empty(), "reset wipes diamonds and unlocks")
	_check(main.lives == GameConfig.STARTING_LIVES and main.currency == GameConfig.STARTING_CURRENCY, "and starts a fresh run")
	var menu: SkillTreeMenu = main.hud.get_skill_menu()
	main.diamonds = 5
	main.open_skill_menu("test")
	var resets: Array[int] = [0]
	menu.reset_requested.connect(func() -> void: resets[0] += 1)
	menu._on_reset_pressed()
	_check(resets[0] == 0, "first Reset click only arms the confirmation")
	menu._on_reset_pressed()
	_check(resets[0] == 1, "second click confirms")


func test_tesla_locked_until_unlocked() -> void:
	var main: Node2D = _make_main()
	_check(not main.try_buy_tower(Vector2i(10, 5), TowerTypes.TESLA) and main.currency == 200, "Tesla cannot be built before it is unlocked")
	main._on_build_pressed(TowerTypes.TESLA)
	_check(not main.build_mode, "Tesla build button does nothing while locked")
	main.diamonds = 3
	main.try_unlock_skill("tesla")
	_check(main.try_buy_tower(Vector2i(10, 5), TowerTypes.TESLA), "Tesla can be built once unlocked")
	var tesla: Tower = main.get_tower_at(Vector2i(10, 5))
	_check(tesla.tower_type == TowerTypes.TESLA and main.currency == 200 - TowerTypes.cost(TowerTypes.TESLA), "Tesla costs %d" % TowerTypes.cost(TowerTypes.TESLA))
	_check(main.board.is_blocked(Vector2i(10, 5)), "Tesla blocks its tile like any tower")


func test_tesla_hits_every_enemy_in_small_range() -> void:
	var board: Board = _make_board()
	var tesla: Tower = TOWER_SCENE.instantiate() as Tower
	tesla.configure(TowerTypes.TESLA)
	tesla.position = Board.cell_to_world(Vector2i(10, 10))
	board.towers.add_child(tesla)
	var near: Array[Enemy] = []
	for offset: Vector2 in [Vector2(30, 0), Vector2(-40, 20), Vector2(0, 60)]:
		var enemy: Enemy = _spawn_enemy(board, 100.0)
		enemy.position = tesla.position + offset
		near.append(enemy)
	var far: Enemy = _spawn_enemy(board, 100.0)
	far.position = tesla.position + Vector2(100, 0)  # inside Basic range, outside Tesla range
	tesla.step(0.1)
	var all_hit: bool = true
	for enemy: Enemy in near:
		if enemy.health != 100.0 - tesla.damage:
			all_hit = false
	_check(all_hit, "one Tesla bolt hits all 3 enemies within %d px" % int(tesla.attack_range))
	_check(far.health == 100.0, "enemies outside the small radius are not hit")
	_check(tesla.attack_range < GameConfig.TOWER_RANGE, "Tesla range (%d) is smaller than the Basic tower's" % int(tesla.attack_range))
	tesla.step(0.5)
	_check(near[0].health == 100.0 - tesla.damage, "Tesla respects its cooldown")
	var tank: Enemy = _spawn_enemy(board, 100.0, EnemyTypes.TANK)
	tank.position = tesla.position + Vector2(10, 10)
	tesla.step(1.0)
	_check(tank.health == 100.0 - maxi(tesla.damage - tank.armor, 1), "armor reduces each Tesla bolt")


func test_upgrades_locked_per_tower_type() -> void:
	var main: Node2D = _make_main()
	main.currency = 10000
	main.diamonds = 100
	main.try_unlock_skill("tesla")
	main.try_buy_tower(Vector2i(10, 5), TowerTypes.BASIC)
	main.try_buy_tower(Vector2i(12, 5), TowerTypes.TESLA)
	var basic: Tower = main.get_tower_at(Vector2i(10, 5))
	var tesla: Tower = main.get_tower_at(Vector2i(12, 5))
	var gold: int = main.currency
	_check(not main.try_upgrade_tower(basic, Tower.UpgradePath.DAMAGE) and not main.try_upgrade_tower(tesla, Tower.UpgradePath.DAMAGE), "no tower can be upgraded before its upgrade skill")
	_check(main.currency == gold and basic.upgrade_level == 0 and tesla.upgrade_level == 0, "locked upgrade attempts change nothing")
	main._on_board_cell_clicked(Vector2i(10, 5))
	_check(main.hud._selection_label.text.contains("locked"), "selection panel explains upgrades are locked")
	_check(not main.hud.get_upgrade_button(Tower.UpgradePath.DAMAGE).visible, "no upgrade buttons are shown while locked")
	main.try_unlock_skill("basic_upgrades")
	_check(main.try_upgrade_tower(basic, Tower.UpgradePath.DAMAGE), "Basic Upgrades unlocks Basic tower upgrades")
	_check(not main.try_upgrade_tower(tesla, Tower.UpgradePath.DAMAGE), "...but not Tesla upgrades")
	main.try_unlock_skill("tesla_upgrades")
	_check(main.try_upgrade_tower(tesla, Tower.UpgradePath.RANGE), "Tesla Upgrades unlocks Tesla upgrades")


func test_unique_paths_need_their_own_skill() -> void:
	var main: Node2D = _make_main()
	main.currency = 10000
	main.diamonds = 100
	for id: String in ["tesla", "basic_upgrades", "tesla_upgrades"]:
		main.try_unlock_skill(id)
	main.try_buy_tower(Vector2i(10, 5), TowerTypes.BASIC)
	main.try_buy_tower(Vector2i(12, 5), TowerTypes.TESLA)
	var basic: Tower = main.get_tower_at(Vector2i(10, 5))
	var tesla: Tower = main.get_tower_at(Vector2i(12, 5))
	_check(not main.try_upgrade_tower(basic, Tower.UpgradePath.PIERCE), "Armor Piercing needs its own skill")
	_check(not main.try_upgrade_tower(tesla, Tower.UpgradePath.STATIC), "Static Field needs its own skill")
	main.try_unlock_skill("basic_pierce")
	main.try_unlock_skill("tesla_static")
	_check(not basic.can_upgrade(Tower.UpgradePath.STATIC) and not tesla.can_upgrade(Tower.UpgradePath.PIERCE), "unique paths belong to their own tower type only")
	_check(main.try_upgrade_tower(basic, Tower.UpgradePath.PIERCE) and main.try_upgrade_tower(tesla, Tower.UpgradePath.STATIC), "unique paths work once unlocked")
	_check(not main.try_upgrade_tower(basic, Tower.UpgradePath.DAMAGE), "a unique path still locks out the other paths")
	main._on_board_cell_clicked(Vector2i(12, 5))
	var unique_button: Button = main.hud.get_upgrade_button(Tower.UpgradePath.STATIC)
	_check(unique_button != null and unique_button.visible and unique_button.text.contains("Static"), "Tesla's selection panel shows its Static field button")


func test_armor_piercing_ignores_armor() -> void:
	var board: Board = _make_board()
	var tower: Tower = TOWER_SCENE.instantiate() as Tower
	tower.configure(TowerTypes.BASIC)
	tower.apply_upgrade(Tower.UpgradePath.PIERCE)
	tower.position = Board.cell_to_world(Vector2i(10, 10))
	board.towers.add_child(tower)
	var tank: Enemy = _spawn_enemy(board, 200.0, EnemyTypes.TANK)
	tank.position = tower.position + Vector2(20, 0)
	tower.step(0.1)
	_check(tower.damage == GameConfig.TOWER_DAMAGE + Tower.PIERCE_DAMAGE_PER_LEVEL and tower.armor_piercing, "Armor Piercing level 1: +4 damage, ignores armor")
	_check(tank.health == 200.0 - tower.damage, "full damage lands on an armored Tank (HP %s)" % tank.health)


func test_static_field_slows() -> void:
	var board: Board = _make_board()
	var tesla: Tower = TOWER_SCENE.instantiate() as Tower
	tesla.configure(TowerTypes.TESLA)
	tesla.apply_upgrade(Tower.UpgradePath.STATIC)
	tesla.apply_upgrade(Tower.UpgradePath.STATIC)
	tesla.position = Board.cell_to_world(Vector2i(2, 11))
	board.towers.add_child(tesla)
	var enemy: Enemy = _spawn_enemy(board, 1000.0)
	enemy.advance(0.5)
	tesla.step(0.1)
	_check(enemy.is_slowed() and is_equal_approx(enemy.get_effective_speed(), enemy.speed * (1.0 - 2 * Tower.STATIC_SLOW_PER_LEVEL)), "Static Field level 2 slows by 30%% (%s px/s)" % enemy.get_effective_speed())
	var before: Vector2 = enemy.position
	enemy.step(0.5)
	_check(is_equal_approx(enemy.position.distance_to(before), enemy.speed * 0.7 * 0.5), "slowed enemies really move slower")
	enemy.step(2.0)
	_check(not enemy.is_slowed() and enemy.get_effective_speed() == enemy.speed, "the slow wears off after 1.5 s")


func test_gold_boosts() -> void:
	var main: Node2D = _make_main()
	main.diamonds = 100
	main.try_unlock_skill("tesla")
	main.try_unlock_skill("bounty_1")
	main.try_unlock_skill("war_chest")
	main._on_start_wave_pressed()
	var rewards: Array[int] = [0]
	main.wave_manager.enemy_killed.connect(func(e: Enemy) -> void: rewards[0] += roundi(e.reward * 1.2))
	var gold_before: int = main.currency
	while main.wave_manager.is_wave_active():
		_simulate(main, 0.05, 1)
		_kill_all_active(main)
	var bonus: int = roundi(WaveGenerator.wave_clear_bonus(1) * 1.5)
	_check(main.currency == gold_before + rewards[0] + bonus, "Bounty Hunter +20%% kill gold and War Chest +50%% wave bonus (%d)" % main.currency)


func test_enemy_nerfs_apply_to_new_spawns() -> void:
	var main: Node2D = _make_main()
	main.diamonds = 100
	for id: String in ["tesla", "weaken_1", "weaken_2", "cripple"]:
		main.try_unlock_skill(id)
	main._on_start_wave_pressed()
	_simulate(main, 0.05, 1)
	var enemy: Enemy = _active_enemies(main)[0]
	var entry: Dictionary = main.wave_manager._queue[0]  # the un-nerfed generated entry
	_check(is_equal_approx(enemy.max_health, entry["health"] * 0.8), "Frailty + Decay: enemies spawn with 20%% less health (%s vs %s)" % [enemy.max_health, entry["health"]])
	_check(is_equal_approx(enemy.speed, EnemyTypes.get_def(enemy.type_id)["speed"] * 0.9), "Cripple: enemies move 10%% slower")


func test_permanent_tower_buffs_and_lives() -> void:
	var main: Node2D = _make_main()
	main.diamonds = 100
	main.try_buy_tower(Vector2i(10, 5), TowerTypes.BASIC)
	var tower: Tower = main.get_tower_at(Vector2i(10, 5))
	for id: String in ["tesla", "fortify"]:
		main.try_unlock_skill(id)
	_check(main.lives == GameConfig.STARTING_LIVES + 5, "Fortify adds 5 lives immediately")
	main.try_unlock_skill("sharpen")
	_check(tower.damage == roundi(GameConfig.TOWER_DAMAGE * 1.15), "Sharpened Arsenal raises existing towers' damage (%d)" % tower.damage)
	main.try_unlock_skill("overclock")
	_check(is_equal_approx(tower.cooldown, GameConfig.TOWER_COOLDOWN / 1.15), "Overclock makes towers attack 15%% faster (%s s)" % tower.cooldown)
	main.try_buy_tower(Vector2i(12, 5), TowerTypes.BASIC)
	_check(main.get_tower_at(Vector2i(12, 5)).damage == tower.damage, "new towers get the buffs too")


# --- Auto-start --------------------------------------------------------------------------

func _finish_wave(main: Node2D) -> void:
	while main.wave_manager.is_wave_active():
		_simulate(main, 0.05, 1)
		_kill_all_active(main)
		_free_resolved(main)


func test_auto_start_off_by_default() -> void:
	var main: Node2D = _make_main()
	_check(not main.auto_start, "auto-start is off by default")
	main._on_start_wave_pressed()
	_finish_wave(main)
	main.step_auto_start(60.0)
	_check(main.wave_manager.current_wave == 1 and main.state == main.GameState.BETWEEN_WAVES, "with it off, the next wave waits for Start Wave")


func test_auto_start_runs_waves_back_to_back() -> void:
	var main: Node2D = _make_main()
	main.hud._auto_start_check.button_pressed = true  # the real HUD toggle
	_check(main.auto_start, "the HUD toggle turns auto-start on")
	main.step_auto_start(60.0)
	_check(main.wave_manager.current_wave == 0, "wave 1 is still started by the player")
	main._on_start_wave_pressed()
	_finish_wave(main)
	_check(is_equal_approx(main.get_auto_start_countdown(), GameConfig.AUTO_START_DELAY), "clearing a wave schedules the next in %d s" % int(GameConfig.AUTO_START_DELAY))
	_check(main.hud._auto_start_check.text.contains("in 3s"), "the toggle shows the countdown (%s)" % main.hud._auto_start_check.text)
	main.step_auto_start(GameConfig.AUTO_START_DELAY - 0.1)
	_check(main.wave_manager.current_wave == 1, "not before the delay")
	main.step_auto_start(0.2)
	_check(main.wave_manager.current_wave == 2 and main.state == main.GameState.WAVE_ACTIVE, "wave 2 starts automatically")
	for i in 2:
		_finish_wave(main)
		main.step_auto_start(GameConfig.AUTO_START_DELAY + 0.1)
	_check(main.wave_manager.current_wave == 4, "waves keep chaining (wave %d)" % main.wave_manager.current_wave)
	main.hud._auto_start_check.button_pressed = false
	_finish_wave(main)
	main.step_auto_start(60.0)
	_check(main.wave_manager.current_wave == 4 and main.get_auto_start_countdown() < 0.0, "turning it off stops the chain")


func test_auto_start_waits_for_skill_menu() -> void:
	var main: Node2D = _make_main()
	main.set_auto_start(true)
	for wave in 5:
		if main.state == main.GameState.READY:
			main._on_start_wave_pressed()
		_finish_wave(main)
		if wave < 4:
			main.step_auto_start(GameConfig.AUTO_START_DELAY + 0.1)
	_check(main.wave_manager.current_wave == 5 and main.is_skill_menu_open(), "wave 5 cleared and the skill tree opened")
	main.step_auto_start(60.0)
	_check(main.wave_manager.current_wave == 5, "no wave starts while the skill tree is open")
	main.close_skill_menu()
	main.step_auto_start(GameConfig.AUTO_START_DELAY + 0.1)
	_check(main.wave_manager.current_wave == 6, "the countdown resumes after closing it")
	main.lives = 1
	main._on_enemy_escaped(_active_enemies(main)[0] if not _active_enemies(main).is_empty() else _spawn_enemy(main.board))
	main.step_auto_start(60.0)
	_check(main.is_game_over() and main.wave_manager.current_wave == 6, "nothing auto-starts after defeat")


func test_auto_start_setting_is_saved() -> void:
	var path: String = "user://test_progress_auto_%d.json" % Time.get_ticks_usec()
	ProgressStore.save_path = path
	var main: Node2D = _make_main()
	main.set_auto_start(true)
	_cleanup_root()
	var relaunched: Node2D = _make_main()
	_check(relaunched.auto_start and relaunched.hud._auto_start_check.button_pressed, "auto-start choice survives a relaunch")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	ProgressStore.save_path = ""
