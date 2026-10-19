extends SceneTree
## Geometry and combat regression, not a funded survival run.

const Policies = preload("res://tests/bot_policies.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func _run() -> void:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var state := {"index": 0, "gaps": []}
	check(Policies.build_hallways(game, state).is_empty(), "initial hallway purchases succeed")
	check(game.currency == 20 and game.board.get_node("Towers").get_child_count() == 3, "policy respects starting budget")
	for cell in [Vector2i(0, 11), Vector2i(1, 12), Vector2i(1, 13)]:
		check(game.board.is_blocked(cell), "first purchases follow entrance instructions: %s" % cell)
	# Isolated funded fixture tests the complete geometry without claiming survival.
	game.currency = 50000
	check(Policies.build_hallways(game, state).is_empty(), "full pattern only rejects sealing candidates")
	check(game.board.get_node("Towers").get_child_count() == 426 and state.gaps.size() == 19, "full layout has 426 towers and 19 alternating end gaps")
	var route := game.board.find_path()
	check(game.board.path_is_valid(route, GameConfig.SPAWN) and route.size() == 476, "complete maze has valid 476-cell cardinal route")
	for gap in state.gaps:
		var cell := Vector2i(int(gap[0]), int(gap[1]))
		check(not game.board.is_blocked(cell) and route.has(cell), "rejected sealing cell stays open on the route: %s" % cell)
	for x in range(2, 39, 2):
		check(not game.board.is_blocked(Vector2i(x, 12)), "one-column hallway remains between walls at x=%d" % x)
	var basic_only := true
	for child in game.board.get_node("Towers").get_children():
		var tower := child as Tower
		basic_only = basic_only and tower.kind == Tower.Kind.BASIC and tower.upgrade_level == 0
	check(basic_only and game.progression.unlocked.is_empty(), "hallway policy has no upgrades, Tesla towers, or skills")

	# Verify the new shared pressure curve against measured historical generation.
	var baseline: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/balance/baseline.json"))
	var hallway: Dictionary = baseline.results[1]
	var generator := WaveGenerator.new(721)
	var armored_profile: EnemyProfile
	for wave in range(1, 51):
		var plan := generator.generate(wave)
		generator.interval_for(wave)
		var hp := 0
		var armor := 0
		for profile in plan:
			hp = maxi(hp, profile.hit_points)
			armor = maxi(armor, profile.armor)
			if wave == 50 and profile.kind == EnemyProfile.Kind.ARMORED:
				armored_profile = profile
		if wave <= 30:
			var original: Dictionary = hallway.waves[wave - 1].combat
			var factor := minf(GameConfig.APPRENTICE_PRESSURE_LIMIT, 1.0 + GameConfig.APPRENTICE_PRESSURE_PER_WAVE * maxf(0, wave - GameConfig.APPRENTICE_START_WAVE))
			# The archive rounded before this multiplier; current generation rounds after.
			var tolerance := 0.0 if wave <= 5 else ceilf(factor * 0.5 + 0.5)
			check(absf(hp - int(original.max_hp) * factor) <= tolerance, "wave %d follows shared pressure curve, preserving the first five" % wave)
	check(armored_profile != null, "wave-50 fixture contains an armored enemy")
	var enemy := preload("res://scenes/enemy.tscn").instantiate() as Enemy
	game.board.get_node("Enemies").add_child(enemy)
	enemy.setup_profile(game.board, armored_profile)
	var first := game.tower_at_cell(Vector2i(0, 11))
	var armor_before := enemy.armor
	first.attack(enemy)
	check(enemy.health == enemy.max_health and enemy.armor == armor_before - first.armor_damage(), "late plating absorbs basic armor-specific damage")
	# A separate training fixture demonstrates that armor does not cause immunity.
	game.progression.unlocked.assign(["tesla", "basic_training"])
	first.configure_progression(game.progression)
	game.select_placed_tower(first)
	for level in range(5):
		check(game.upgrade_selected_tower(Tower.Upgrade.DAMAGE), "trained damage level remains purchasable")
	armor_before = enemy.armor
	first.attack(enemy)
	check(enemy.health == enemy.max_health and enemy.armor == armor_before - first.armor_damage() and first.armor_damage() == 120, "damage upgrades meaningfully improve plating damage without bypassing it")
	game.free()
	print("Hallway policy: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
