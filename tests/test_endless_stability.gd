extends SceneTree
## Generator soak + production lifecycle soak. Fixed seeds make failures replayable.

var checks := 0
var failures := 0
var generated_enemies := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func signature(plan: Array[EnemyProfile]) -> String:
	var result := ""
	for enemy in plan:
		result += "%d:%d:%.6f:%d;" % [enemy.kind, enemy.hit_points, enemy.speed, enemy.shield]
	return result


func _test_generation() -> void:
	var first := WaveGenerator.new(8107)
	var replay := WaveGenerator.new(8107)
	var other := WaveGenerator.new(991)
	var differences := 0
	for wave in range(1, 101):
		var plan := first.generate(wave)
		check(signature(plan) == signature(replay.generate(wave)), "seed replays wave %d" % wave)
		check(first.interval_for(wave) == replay.interval_for(wave), "seed replays cadence %d" % wave)
		if signature(plan) != signature(other.generate(wave)):
			differences += 1
		other.interval_for(wave)
	check(differences > 90, "independent runs vary")
	check(WaveGenerator.new().run_seed != WaveGenerator.new().run_seed, "new random runs get fresh seeds")

	var generator := WaveGenerator.new(5219)
	var kinds_seen: Dictionary = {}
	for wave in range(1, 10001):
		var plan := generator.generate(wave)
		var interval := generator.interval_for(wave)
		check(plan.size() >= 8 and plan.size() <= GameConfig.MAX_WAVE_ENEMIES, "wave %d count bounded" % wave)
		check(is_finite(interval) and interval >= GameConfig.MIN_SPAWN_INTERVAL, "wave %d cadence bounded" % wave)
		var valid := true
		var wave_kinds: Dictionary = {}
		for profile in plan:
			generated_enemies += 1
			kinds_seen[profile.kind] = true
			wave_kinds[profile.kind] = true
			if profile.hit_points <= 0 or profile.hit_points > GameConfig.MAX_ENEMY_HEALTH or not is_finite(profile.speed) or profile.speed <= 0 or profile.speed > 100 or profile.bounty <= 0 or profile.shield < 0 or profile.shield > GameConfig.MAX_ENEMY_HEALTH or profile.armor < 0 or profile.armor > GameConfig.MAX_ENEMY_HEALTH:
				valid = false
		check(valid and wave_kinds.size() >= 2, "wave %d finite stats and mixed types" % wave)
	check(kinds_seen.size() == 5, "soak includes all five types")
	var extreme := generator.generate(1 << 50)
	check(extreme.size() <= GameConfig.MAX_WAVE_ENEMIES and extreme[0].hit_points > 0 and generator.interval_for(1 << 50) >= GameConfig.MIN_SPAWN_INTERVAL, "extreme wave index stays bounded without overflow")
	var mutable := generator.generate(1)
	mutable[0].hit_points = 1
	check(EnemyProfile.base(EnemyProfile.Kind.GRUNT).hit_points == 45, "per-spawn data cannot mutate type templates")


func _test_wave_manager() -> void:
	var manager := WaveManager.new()
	root.add_child(manager)
	manager.set_process(false)
	manager.set_run_seed(625)
	var totals := {"spawns": 0, "completions": 0}
	manager.spawn_requested.connect(func(_profile: EnemyProfile) -> void:
		totals.spawns += 1
		manager.enemy_resolved()
	)
	manager.wave_completed.connect(func(_wave: int) -> void: totals.completions += 1)
	for wave in range(1, 1001):
		var before: int = totals.spawns
		check(manager.start_next_wave() and not manager.start_next_wave(), "soak starts wave %d once" % wave)
		manager._process(1000.0)
		check(manager.active_count == 0 and manager.remaining_to_spawn == 0 and not manager.running and manager.can_start(), "soak wave %d settles all counters" % wave)
		check(totals.spawns - before == manager.wave_size and totals.completions == wave and manager.current_wave == wave, "soak wave %d spawn/completion counts exact" % wave)
	manager.free()


func _test_scene_lifecycle() -> void:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	game.progression.unlocked.assign(["tesla", "basic_training"])
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.waves.set_run_seed(9193)
	var baseline_nodes := game.get_child_count()
	var expected_currency := game.currency
	var peak_children := 0
	# Instant kills are deliberate here: test accounting, allocation, deferred frees
	# and signal cleanup, not balance (the gameplay suite uses natural combat).
	for wave in range(1, 301):
		game.close_skill_tree()
		game.start_wave()
		game.waves._process(1000.0)
		var active := game.board.active_enemies()
		peak_children = maxi(peak_children, game.board.get_node("Enemies").get_child_count())
		check(active.size() == game.waves.wave_size and active.size() <= GameConfig.MAX_WAVE_ENEMIES, "lifecycle wave %d has bounded live nodes" % wave)
		for node in active:
			var enemy := node as Enemy
			expected_currency += enemy.bounty
			for layer in range(3): # Fixture: one hit per possible layer, not a balance simulation.
				enemy.take_damage(enemy.health + enemy.shield + enemy.armor)
			enemy.take_damage(9999999)
		expected_currency += GameConfig.WAVE_CLEAR_BONUS
		check(game.currency == expected_currency and game.waves.active_count == 0 and game.phase == TDGame.Phase.BETWEEN_WAVES, "lifecycle wave %d settles economy once" % wave)
		await process_frame
		check(game.board.get_node("Enemies").get_child_count() == 0 and get_nodes_in_group("enemies").is_empty() and game.get_child_count() == baseline_nodes, "lifecycle wave %d releases nodes/groups/signals" % wave)
		game.close_skill_tree()
		if wave % 50 == 0:
			check(game.purchase_tower(Vector2i(5, 5)), "soak builds tower")
			game.select_placed_tower(game.tower_at_cell(Vector2i(5, 5)))
			check(game.upgrade_selected_tower(Tower.Upgrade.SPEED), "soak upgrades tower")
			check(game.remove_selected_tower(), "soak removes upgraded tower")
			expected_currency -= 60 + 60 - 30
			await process_frame
			check(game.currency == expected_currency and game.board.get_node("Towers").get_child_count() == 0 and not game.board.is_blocked(Vector2i(5, 5)), "soak sale releases node/occupancy without currency exploit")
	check(peak_children <= GameConfig.MAX_WAVE_ENEMIES, "lifecycle never accumulates prior-wave enemy nodes")
	game.free()
	await process_frame


func _run() -> void:
	_test_generation()
	_test_wave_manager()
	await _test_scene_lifecycle()
	print("Endless stability: %d checks, %d failures; %d generated enemies; 10000 generated / 1000 scheduled / 300 scene waves" % [checks, failures, generated_enemies])
	quit(1 if failures else 0)
