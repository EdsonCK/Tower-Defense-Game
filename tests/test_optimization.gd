extends SceneTree
## Differential checks against linear scans and uncached A*, including lifecycle edits.
var checks := 0
var failures := 0
var rng := RandomNumberGenerator.new()

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", message)

func point() -> Vector2:
	return Vector2(rng.randf_range(-100, 1400), rng.randf_range(-100, 900))

func run() -> void:
	rng.seed = 61723
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var units: Array[Enemy] = []
	for i in range(100):
		var unit := Enemy.new()
		game.board.get_node("Enemies").add_child(unit)
		unit.setup(game.board, 10000)
		unit.position = point()
		units.append(unit)
	for trial in range(250):
		# Teleports must be reflected immediately, without waiting for a process tick.
		units[trial % units.size()].position = point()
		var center := point()
		var radius := rng.randf_range(0, 350)
		var rect := Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2)
		var actual: Array = []
		for unit in game.board.enemy_index.query(rect):
			if rect.has_point(unit.position): actual.append(unit)
		var expected: Array = []
		for unit in units:
			if rect.has_point(unit.position): expected.append(unit)
		check(actual == expected, "spatial query equals ordered linear scan after immediate teleport")
	check(game.board.enemy_index.query(Rect2(-1000000, -1000000, 2000000, 2000000)).size() == units.size(), "huge queries visit only bounded occupied buckets")
	check(game.board.enemy_index.query(Rect2(500000, 500000, 2000000, 2000000)).is_empty(), "huge distant queries remain empty")
	var container := game.board.get_node("Enemies") as Node2D
	container.position = Vector2(11, -23)
	container.rotation = 0.37
	container.scale = Vector2(1.2, 0.7)
	for trial in range(80):
		var center := point()
		var radius := rng.randf_range(10, 300)
		var actual: Array = []
		for unit in game.board.enemy_index.query_global(center, radius, container):
			if center.distance_squared_to(unit.global_position) <= radius * radius: actual.append(unit)
		var expected: Array = []
		for unit in units:
			if center.distance_squared_to(unit.global_position) <= radius * radius: expected.append(unit)
		check(actual == expected, "rotated nonuniform parent transforms preserve global range queries")
	container.transform = Transform2D.IDENTITY
	# Negative coordinates and exact bucket boundaries, insertion order on ties.
	for unit in units: unit.position = Vector2(10000, 10000)
	units[0].position = Vector2(-64, 0)
	units[1].position = Vector2(64, 0)
	game.currency = 10000
	game.select_tower(Tower.Kind.BASIC)
	check(game.purchase_tower(Vector2i(8, 8)), "fixture tower purchased")
	var tower := game.tower_at_cell(Vector2i(8, 8))
	tower.position = Vector2.ZERO
	check(tower._nearest_target() == units[1], "nearest tie still selects last group-order enemy")
	units[1].free()
	units.remove_at(1)
	check(tower._nearest_target() == units[0], "free removes spatial entry immediately")
	container.remove_child(units[0])
	container.add_child(units[0])
	units[1].position = Vector2(64, 0)
	check(tower._nearest_target() == units[0], "tree reentry preserves group-order ties")
	units[1].position = Vector2(10000, 10000)
	units[0].take_damage(10000)
	check(tower._nearest_target() == null, "resolved queued enemy is never targeted")
	await process_frame
	units.remove_at(0)
	# Towers move in focused collision fixtures too. Broad phase must not miss them.
	for i in range(70):
		var item := Tower.new()
		item.position = point()
		game.board.get_node("Towers").add_child(item)
	for trial in range(150):
		var start := point()
		var end := point()
		var expected := INF
		for item in game.board.get_node("Towers").get_children():
			expected = minf(expected, CombatProjectile.rect_fraction(start, end, Rect2(item.position - Vector2(20, 20), Vector2(40, 40))))
		var actual := INF
		for item in game.board.tower_index.query(Rect2(start, Vector2.ZERO).expand(end).grow(20)):
			actual = minf(actual, CombatProjectile.rect_fraction(start, end, Rect2(item.position - Vector2(20, 20), Vector2(40, 40))))
		check(actual == expected, "cannon broad phase preserves first swept tower hit, including long steps")
	game.free()
	await process_frame
	# Mass kills update economy synchronously and coalesce only visual work.
	var burst := preload("res://scenes/main.tscn").instantiate() as TDGame
	burst.progression = Progression.new("")
	root.add_child(burst)
	burst.process_mode = Node.PROCESS_MODE_DISABLED
	burst.phase = TDGame.Phase.WAVE_ACTIVE
	burst.waves.active_count = 41
	for i in range(40): burst._spawn_enemy(EnemyProfile.base(EnemyProfile.Kind.GRUNT))
	burst._refresh_hud()
	var gold_before := burst.currency
	for unit in burst.board.active_enemies(): (unit as Enemy).take_damage(999999)
	check(burst.currency == gold_before + 40 * GameConfig.KILL_BOUNTY, "mass kills award every bounty synchronously")
	check(burst.waves.active_count == 1, "mass kills resolve all wave counters synchronously")
	check(burst._hud_refresh_queued, "mass kills request a shared visual refresh")
	await process_frame
	await process_frame
	check(not burst._hud_refresh_queued and burst.hud.currency_label.tooltip_text == "%d gold" % burst.currency, "coalesced HUD displays final gold before the next interaction")
	burst.free()
	await process_frame
	# A long-lived board must release every retired actor/bucket.
	var lifecycle_board := Board.new()
	var enemies := Node2D.new()
	enemies.name = "Enemies"
	lifecycle_board.add_child(enemies)
	root.add_child(lifecycle_board)
	for i in range(300):
		var unit := Enemy.new()
		enemies.add_child(unit)
		unit.setup(lifecycle_board, 10)
		unit.position = point()
		unit.free()
		check(lifecycle_board.enemy_index._cells.is_empty() and lifecycle_board.enemy_index._buckets.is_empty() and lifecycle_board.enemy_index._order.is_empty(), "retired actors leave no index history or references")
	lifecycle_board.free()
	# Reachability oracle: compare all cells against genuine A* on random fixtures.
	for trial in range(12):
		var solids: Array[Vector2i] = []
		for y in range(24):
			for x in range(40):
				var cell := Vector2i(x, y)
				if cell != GameConfig.SPAWN and cell != GameConfig.EXIT and rng.randf() < 0.24: solids.append(cell)
		var board := Board.new(solids)
		root.add_child(board)
		var excluded := Vector2i(4 + trial, 10)
		if board.is_blocked(excluded): board.remove_block(excluded)
		var reachable := board._reachable_without(excluded)
		var trial_solids: Array[Vector2i] = solids.duplicate()
		trial_solids.append(excluded)
		var oracle := Board.new(trial_solids)
		for y in range(24):
			for x in range(40):
				var cell := Vector2i(x, y)
				check(bool(reachable[board._cell_id(cell)]) == not oracle.find_path(cell).is_empty(), "flood fill agrees with A* for every cell")
		oracle.free()
		board.free()
	var blocked_exit: Array[Vector2i] = [GameConfig.EXIT]
	var invalid_fixture := Board.new(blocked_exit)
	check(invalid_fixture.placement_error(Vector2i(2, 2), 1000) == "Cannot block the last route", "blocked-exit fixture remains unreachable")
	invalid_fixture.free()
	var board := Board.new()
	root.add_child(board)
	var original := board.find_path()
	var edited := board.find_path()
	edited.clear()
	check(board.find_path() == original, "callers cannot mutate shared cached routes")
	check(board.placement_error(Vector2i(10, 12), 1000).is_empty(), "preview succeeds")
	check(board.find_path() == original and board.revision == 0, "preview preserves occupancy, exact route and revision")
	check(board.try_block_cell(Vector2i(10, 12), 1000).is_empty(), "provisional block succeeds")
	check(not board.find_path().has(Vector2i(10, 12)), "provisional block invalidates cache before revision changes")
	board.rollback_placement(Vector2i(10, 12))
	check(board.find_path() == original, "rollback invalidates provisional cached paths")
	board.try_block_cell(Vector2i(10, 12), 1000)
	board.confirm_placement()
	board.remove_block(Vector2i(10, 12))
	check(board.find_path() == original, "selling restores cached route correctly")
	board.free()
	check(CombatArt.MONSTERS.get_size() == Vector2(1536, 1920), "all 320 monster animation cells are imported")
	check(CombatArt.TOWERS.get_size() == Vector2(480, 96), "all five cached tower bodies are imported")
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/generated/art_manifest.json"))
	check(int(manifest.frames) == CombatArt.FRAMES and int(manifest.tile) == CombatArt.TILE, "baked animation layout matches runtime layout")
	for i in range(5):
		check(float(manifest.frequencies[i]) == CombatArt.FREQUENCIES[i], "baked phase frequency matches runtime animation")
	for file in manifest.source_hashes:
		check(FileAccess.get_sha256("res://" + file) == manifest.source_hashes[file], "cached art matches its procedural source: " + file)
	print("Optimization: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
