extends "res://tests/test_base.gd"
## Map design and art: lakes, the terrain shader's inputs, the art layer stack, scenery
## placement rules, biome cross-fades, the build grid and ambient particles.
##   godot --headless --path <project> --script res://tests/test_map_art.gd

const SEEDS: Array[int] = [1, 2, 3, 7, 11, 42, 99, 123, 777, 2024]


func get_tests() -> Array[Callable]:
	return [
		test_lakes_stay_clear_of_the_path,
		test_lakes_block_building,
		test_art_layer_stack,
		test_terrain_map_texture,
		test_scenery_placement_rules,
		test_biome_change_cross_fades,
		test_build_grid_follows_build_mode,
		test_atmosphere_particles,
		test_terrain_shader_uniforms,
		test_fog_rolls_back_when_the_map_grows,
	]


func test_lakes_stay_clear_of_the_path() -> void:
	var too_close: int = 0
	var counts: Array[int] = []
	var biggest_share: float = 0.0
	for seed_value: int in SEEDS:
		var layout: MapLayout = MapLayout.new(seed_value)
		var gap: Dictionary = layout.path_gap_field()
		for cell: Vector2i in layout.features:
			if int(gap.get(cell, 0)) < MapLayout.FEATURE_MIN_PATH_GAP or layout.is_path(cell) or not MapLayout.in_grid(cell):
				too_close += 1
		counts.append(layout.features.size())
		biggest_share = maxf(biggest_share, float(layout.features.size()) / (GameConfig.GRID_COLUMNS * GameConfig.GRID_ROWS))
	_check(too_close == 0, "lake tiles are always %d+ steps from every path tile (%d violations)" % [MapLayout.FEATURE_MIN_PATH_GAP, too_close])
	_check(counts.min() > 10, "every map has lakes (%s lake tiles)" % str(counts))
	_check(biggest_share < 0.1, "lakes cover under 10%% of the land (max %.1f%%)" % (biggest_share * 100.0))
	_check(MapLayout.new(9).features == MapLayout.new(9).features and MapLayout.new(9).features != MapLayout.new(10).features, "lakes are reproducible per seed and differ between seeds")


func test_lakes_block_building() -> void:
	var main: Node2D = _make_main(TEST_SEED, true)
	main.currency = 100000
	var board: Board = main.board
	board.set_half_width(GameConfig.MAP_MAX_HALF_WIDTH)
	var lake: Vector2i = board.layout.features.keys()[0]
	_check(not main.try_buy_tower(lake) and main.hud.get_message() == Board.MSG_FEATURE + "pond", "towers can't be built in a lake (%s)" % main.hud.get_message())
	_check(not board.buildable_cells().has(lake), "lake tiles are never listed as buildable")
	board.set_biome(3)
	_check(board.placement_rejection(lake) == "Can't build on the lava pool", "the message names the biome's lakes (%s)" % board.placement_rejection(lake))


func test_art_layer_stack() -> void:
	var main: Node2D = _make_main()
	var board: Board = main.board
	var names: Array[String] = []
	for child: Node in board.get_children():
		names.append(child.name)
	var expected: Array[String] = ["Terrain", "Decor", "Markers", "Overlay", "Towers", "Enemies", "Atmosphere"]
	var order_ok: bool = true
	var last: int = -1
	for name: String in expected:
		var at: int = names.find(name)
		if at <= last:
			order_ok = false
		last = at
	_check(order_ok, "art layers draw back to front: %s (%s)" % [", ".join(expected), names])
	_check(board.terrain.material is ShaderMaterial, "the terrain is a single shader pass")


func test_terrain_map_texture() -> void:
	var board: Board = _make_board()
	var image: Image = board.terrain.map_image()
	var bad: int = 0
	for cell: Vector2i in board.layout.parent:
		var expected: float = 1.0 if board.in_window(cell) else 0.0
		if absf(image.get_pixelv(cell).r - expected) > 0.01:
			bad += 1
	for cell: Vector2i in board.layout.features:
		if image.get_pixelv(cell).g < 0.99:
			bad += 1
	_check(bad == 0, "the terrain map holds the path only inside the window, and every lake (%d mismatches)" % bad)
	var near_gate: Vector2i = board.layout.children[board.exit_cell()][0]
	_check(image.get_pixelv(near_gate).b > 0.9, "the road is cobbled next to the gate")
	var rect: Vector4 = board.terrain.shader_param("window_rect")
	var world: Rect2 = board.window_rect_world()
	_check(rect == Vector4(world.position.x, world.position.y, world.size.x, world.size.y), "the shader knows the visible window, for the fog edge")
	board.set_half_width(20)
	image = board.terrain.map_image()
	var revealed: bool = true
	for cell: Vector2i in board.layout.parent:
		if board.in_window(cell) and image.get_pixelv(cell).r < 0.99:
			revealed = false
	_check(revealed, "growing the map reveals more path in the terrain")


func test_scenery_placement_rules() -> void:
	var main: Node2D = _make_main(TEST_SEED, true)
	main.currency = 100000
	var board: Board = main.board
	board.set_half_width(GameConfig.MAP_MAX_HALF_WIDTH)
	var spot: Vector2i = _spot(main, 0)
	var far: Vector2i = _far_spot(main)
	main.try_buy_tower(far)
	var problems: Array[String] = []
	var kinds: Dictionary = {}
	var shore: int = 0
	for item: Array in board.decor.placements():
		var cell: Vector2i = item[0]
		kinds[item[1]] = true
		if board.is_path(cell) or board.is_blocked(cell):
			problems.append("%s on path/tower at %s" % [item[1], cell])
		elif item[1] == "lily":
			if not board.is_feature(cell):
				problems.append("lily on land at %s" % cell)
		elif board.is_feature(cell):
			problems.append("%s in a lake at %s" % [item[1], cell])
		elif DecorLayer._next_to(board.layout, cell, true):
			problems.append("%s beside the path at %s" % [item[1], cell])
		if DecorLayer._next_to(board.layout, cell, false) and item[1] != "lily":
			shore += 1
		if not board.in_window(cell):
			problems.append("%s outside the window at %s" % [item[1], cell])
	_check(problems.is_empty(), "scenery never sits on the path, beside it, on a tower, in a lake or off the map%s" % ("" if problems.is_empty() else " - " + str(problems.slice(0, 3))))
	_check(kinds.size() >= 5 and shore > 0, "the Meadow has varied scenery (%s) and shore plants (%d)" % [kinds.keys(), shore])
	_check(spot != far and not board.decor.placements().any(func(item: Array) -> bool: return item[0] == far), "a new tower clears the scenery under it")
	var before: Array = board.decor.placements()
	_check(before == board.decor.placements(), "scenery is stable between redraws (no flicker)")
	board.set_biome(1)
	var desert: Dictionary = {}
	for item: Array in board.decor.placements():
		desert[item[1]] = true
	_check(desert.has("cactus") and not desert.has("tree"), "a new biome brings its own scenery (%s)" % [desert.keys()])


func test_biome_change_cross_fades() -> void:
	var main: Node2D = _make_main(TEST_SEED, true)
	var terrain: Terrain = main.board.terrain
	var meadow: Color = Biomes.get_def(0)["ground"]
	var desert: Color = Biomes.get_def(1)["ground"]
	var start: Vector3 = terrain.shader_param("ground_a")
	_check(start.is_equal_approx(Vector3(meadow.r, meadow.g, meadow.b)), "the Meadow palette is loaded at the start")
	main.board.set_biome(1)
	_check(int(terrain.shader_param("style")) == 1, "the desert texture style switches in")
	await create_timer(0.5).timeout
	var mid: Vector3 = terrain.shader_param("ground_a")
	_check(not mid.is_equal_approx(Vector3(desert.r, desert.g, desert.b)) and not mid.is_equal_approx(start), "the ground color is part way through a cross-fade")
	await create_timer(1.3).timeout
	var done: Vector3 = terrain.shader_param("ground_a")
	_check(done.is_equal_approx(Vector3(desert.r, desert.g, desert.b)), "and settles on the Desert palette")
	main.restart_game(5)
	var reset: Vector3 = terrain.shader_param("ground_a")
	_check(reset.is_equal_approx(Vector3(meadow.r, meadow.g, meadow.b)) and int(terrain.shader_param("style")) == 0, "a new run starts back in the Meadow at once")


func test_build_grid_follows_build_mode() -> void:
	var main: Node2D = _make_main()
	var terrain: Terrain = main.board.terrain
	_check(not terrain.grid_visible(), "no grid during normal play")
	main._on_build_pressed(TowerTypes.BASIC)
	_check(terrain.grid_visible(), "build mode shows the tile grid")
	await create_timer(0.3).timeout
	_check(is_equal_approx(float(terrain.shader_param("show_grid")), 1.0), "the grid fades fully in")
	main._on_cancel_pressed()
	await create_timer(0.3).timeout
	_check(not terrain.grid_visible() and is_equal_approx(float(terrain.shader_param("show_grid")), 0.0), "and out again when building ends")


func test_atmosphere_particles() -> void:
	var main: Node2D = _make_main(TEST_SEED, true)
	var board: Board = main.board
	var atmosphere: Atmosphere = board.atmosphere
	var small: int = atmosphere.particle_count()
	_check(atmosphere.kind == "pollen", "the Meadow has pollen and butterflies")
	board.set_half_width(GameConfig.MAP_MAX_HALF_WIDTH)
	_check(atmosphere.particle_count() > small and atmosphere.particle_count() <= Atmosphere.MAX_PARTICLES, "more particles on a bigger map, within the cap (%d -> %d)" % [small, atmosphere.particle_count()])
	var kinds: Dictionary = {}
	for i in Biomes.count():
		board.set_biome(i)
		kinds[atmosphere.kind] = true
		if not atmosphere.kind in Atmosphere.KINDS:
			kinds["unknown " + atmosphere.kind] = true
	_check(kinds.size() == Biomes.count(), "every biome has its own known particle kind (%s)" % [kinds.keys()])
	for i in 600:
		atmosphere._process(0.05)
	var area: Rect2 = atmosphere.area.grow(13.0)
	var escaped: int = 0
	for p: Dictionary in atmosphere._particles:
		if not area.has_point(p["pos"]):
			escaped += 1
	_check(escaped == 0, "after 30 s of drifting every particle is still over the map")


func test_terrain_shader_uniforms() -> void:
	var names: Array[String] = []
	for uniform: Dictionary in Terrain.SHADER.get_shader_uniform_list():
		names.append(uniform["name"])
	var needed: Array[String] = ["map_tex", "window_rect", "gate_pos", "show_grid", "style", "water_style", "ground_a", "fog_col"]
	var missing: Array[String] = []
	for name: String in needed:
		if name not in names:
			missing.append(name)
	_check(missing.is_empty(), "the terrain shader parses and exposes its inputs%s" % ("" if missing.is_empty() else " - missing " + str(missing)))
	for param: String in Terrain.COLOR_PARAMS:
		if param not in names:
			missing.append(param)
	_check(missing.is_empty(), "every biome color has a shader uniform")


func test_fog_rolls_back_when_the_map_grows() -> void:
	var main: Node2D = _make_main()
	var board: Board = main.board
	var old_world: Rect2 = board.window_rect_world()
	board.set_half_width(board.half_width + 1)
	var target: Rect2 = board.window_rect_world()
	var as_vec: Callable = func(r: Rect2) -> Vector4: return Vector4(r.position.x, r.position.y, r.size.x, r.size.y)
	var now: Vector4 = board.terrain.shader_param("window_rect")
	_check(now == as_vec.call(old_world), "right after growing, the fog still covers the new ring")
	await create_timer(Terrain.REVEAL_SECONDS + 0.3).timeout
	_check(board.terrain.shader_param("window_rect") == as_vec.call(target), "then rolls back to reveal it")
	main.restart_game(3)
	_check(board.terrain.shader_param("window_rect") == as_vec.call(board.window_rect_world()), "a new run snaps straight to the small map")
