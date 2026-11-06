extends "res://tests/test_base.gd"
## The fixed-path map: generation rules, placement, enemies following the path, map
## growth, biomes, screen fitting and the basic run flow.
##   godot --headless --path <project> --script res://tests/test_map.gd

const SEEDS: Array[int] = [1, 2, 3, 7, 11, 42, 99, 123, 777, 2024]


func get_tests() -> Array[Callable]:
	return [
		test_map_is_a_tree_with_one_exit,
		test_path_is_one_tile_wide,
		test_path_is_windy,
		test_branches_never_turn_back,
		test_entrances_and_crossroads_grow_with_the_map,
		test_maps_are_reproducible_and_vary,
		test_placement_rules,
		test_enemies_walk_only_the_path,
		test_map_grows_after_each_wave,
		test_board_fits_the_screen_at_every_size,
		test_clicks_hit_the_right_cell_at_any_zoom,
		test_biome_cycle_and_art,
		test_biome_buffs_apply_to_towers,
		test_biome_changes_every_ten_waves,
		test_wave_flow_defeat_and_restart,
		test_window_fit_sizes,
	]


func _all_maps() -> Array[MapLayout]:
	var maps: Array[MapLayout] = []
	for seed_value: int in SEEDS:
		maps.append(MapLayout.new(seed_value))
	return maps


# --- Generation ------------------------------------------------------------------------

func test_map_is_a_tree_with_one_exit() -> void:
	var problem: String = ""
	for m: MapLayout in _all_maps():
		var roots: int = 0
		for cell: Vector2i in m.parent:
			if m.parent[cell] == cell:
				roots += 1
			var steps: int = 0
			var c: Vector2i = cell
			while c != m.exit and steps < 5000:
				var p: Vector2i = m.parent[c]
				if absi(p.x - c.x) + absi(p.y - c.y) != 1:
					problem = "non-adjacent parent at %s" % c
				c = p
				steps += 1
			if c != m.exit:
				problem = "cell %s never reaches the exit" % cell
			if m.distance[cell] != steps:
				problem = "wrong distance at %s" % cell
		if roots != 1 or m.parent[m.exit] != m.exit:
			problem = "expected exactly one exit, found %d" % roots
	_check(problem == "", "10 maps: every path cell leads to the single exit, one step at a time%s" % ("" if problem == "" else " - " + problem))


func test_path_is_one_tile_wide() -> void:
	var problem: String = ""
	for m: MapLayout in _all_maps():
		for cell: Vector2i in m.parent:
			var linked: Array = (m.children.get(cell, []) as Array).duplicate()
			if cell != m.exit:
				linked.append(m.parent[cell])
			for d: Vector2i in MapLayout.DIRECTIONS:
				var n: Vector2i = cell + d
				if m.is_path(n) and n not in linked:
					problem = "path cells %s and %s touch without being connected" % [cell, n]
			if m.is_path(cell + Vector2i(1, 0)) and m.is_path(cell + Vector2i(0, 1)) and m.is_path(cell + Vector2i(1, 1)):
				problem = "2x2 block of path at %s" % cell
	_check(problem == "", "the path is exactly 1 tile wide everywhere%s" % ("" if problem == "" else " - " + problem))


func test_path_is_windy() -> void:
	var worst_ratio: float = 1.0
	var longest_straight: int = 0
	for m: MapLayout in _all_maps():
		var turns: int = 0
		var steps: int = 0
		for cell: Vector2i in m.parent:
			if cell == m.exit or m.parent[cell] == m.exit:
				continue
			var p: Vector2i = m.parent[cell]
			steps += 1
			if cell - p != p - m.parent[p]:
				turns += 1
			# Length of the straight run ending at this cell.
			var run: int = 1
			var a: Vector2i = cell
			while a != m.exit and m.parent[a] != m.exit and a - m.parent[a] == m.parent[a] - m.parent[m.parent[a]]:
				run += 1
				a = m.parent[a]
			longest_straight = maxi(longest_straight, run)
		worst_ratio = minf(worst_ratio, float(turns) / steps)
	_check(worst_ratio >= 0.2, "paths turn often (at least %.0f%% of steps are turns)" % (worst_ratio * 100.0))
	_check(longest_straight <= 14, "no straight run longer than %d tiles" % longest_straight)


func test_branches_never_turn_back() -> void:
	var ok: bool = true
	for m: MapLayout in _all_maps():
		for cell: Vector2i in m.parent:
			if MapLayout.ring(m.parent[cell]) > MapLayout.ring(cell):
				ok = false
	_check(ok, "walking toward the exit never moves outward (so a route never leaves the window)")


func test_entrances_and_crossroads_grow_with_the_map() -> void:
	var problem: String = ""
	for m: MapLayout in _all_maps():
		var previous: int = 0
		for hw in range(GameConfig.MAP_START_HALF_WIDTH, GameConfig.MAP_MAX_HALF_WIDTH + 1):
			var entrances: Array[Vector2i] = m.entrances(hw)
			if entrances.size() < previous or entrances.is_empty():
				problem = "entrances shrank or vanished at half-width %d" % hw
			previous = entrances.size()
			for entrance: Vector2i in entrances:
				for cell: Vector2i in m.route_from(entrance):
					if not MapLayout.in_window(cell, hw):
						problem = "route from %s leaves the window" % entrance
		if m.entrances(GameConfig.MAP_START_HALF_WIDTH).size() < 2:
			problem = "fewer than 2 entrances on wave 1"
		if m.entrances(GameConfig.MAP_MAX_HALF_WIDTH).size() < 5:
			problem = "fewer than 5 entrances on the full map"
		if m.junctions(GameConfig.MAP_MAX_HALF_WIDTH).size() < 3:
			problem = "fewer than 3 crossroads on the full map"
		# Every visible path cell is on some entrance's route (no dead stubs).
		var covered: Dictionary = {}
		for entrance: Vector2i in m.entrances(GameConfig.MAP_MAX_HALF_WIDTH):
			for cell: Vector2i in m.route_from(entrance):
				covered[cell] = true
		if covered.size() != m.parent.size():
			problem = "%d path cells are not on any route" % (m.parent.size() - covered.size())
	_check(problem == "", "2+ entrances at the start, more as the map grows (5+), 3+ crossroads, routes stay on the map%s" % ("" if problem == "" else " - " + problem))


func test_maps_are_reproducible_and_vary() -> void:
	_check(MapLayout.new(5).parent == MapLayout.new(5).parent, "the same seed gives the same map")
	var distinct: Dictionary = {}
	for m: MapLayout in _all_maps():
		distinct[m.parent.keys().hash()] = true
	_check(distinct.size() == SEEDS.size(), "every run seed gives a different map")


# --- Placement and movement ----------------------------------------------------------------

func test_placement_rules() -> void:
	var main: Node2D = _make_main()
	var board: Board = main.board
	var path_cell: Vector2i = board.entrances()[0]
	main.currency = 10000
	_check(not main.try_buy_tower(path_cell) and main.hud.get_message() == Board.MSG_ON_PATH, "towers can't be placed on the path")
	_check(not main.try_buy_tower(EXIT) and main.hud.get_message() == Board.MSG_GATE, "or on the gate")
	var outside: Vector2i = EXIT + Vector2i(GameConfig.MAP_START_HALF_WIDTH + 1, 0)
	_check(not main.try_buy_tower(outside) and main.hud.get_message() == Board.MSG_OUTSIDE, "or outside the visible map")
	var spot: Vector2i = _spot(main)
	_check(main.try_buy_tower(spot), "a free tile beside the path accepts a tower")
	_check(not main.try_buy_tower(spot) and main.hud.get_message() == Board.MSG_OCCUPIED, "an occupied tile is rejected")
	var no_path: bool = true
	for cell: Vector2i in board.buildable_cells():
		if board.is_path(cell) or cell == EXIT:
			no_path = false
	_check(no_path and board.buildable_cells().size() > 100, "buildable cells never include the path (%d buildable)" % board.buildable_cells().size())
	_check(main.currency == 10000 - GameConfig.TOWER_COST, "only the valid placement was charged")


func test_enemies_walk_only_the_path() -> void:
	var board: Board = _make_board()
	board.set_half_width(GameConfig.MAP_MAX_HALF_WIDTH)
	var problem: String = ""
	for entrance: Vector2i in board.entrances():
		var enemy: Enemy = _spawn_enemy(board, 1.0e9, EnemyTypes.RUNNER, entrance)
		var escaped: Array[bool] = [false]
		enemy.reached_exit.connect(func(_e: Enemy) -> void: escaped[0] = true)
		var visited: Array[Vector2i] = [enemy.current_cell]
		var last_pos: Vector2 = enemy.position
		var last_remaining: float = enemy.remaining_distance()
		for i in 60 * 120:
			enemy.step(1.0 / 60.0)
			if escaped[0]:
				break
			if not board.is_path(enemy.current_cell) or not board.is_path(Board.world_to_cell(enemy.position)):
				problem = "enemy left the path at %s" % enemy.current_cell
			if enemy.position.distance_to(last_pos) > enemy.speed / 60.0 + 0.01:
				problem = "enemy teleported"
			if enemy.remaining_distance() > last_remaining + 0.01:
				problem = "enemy walked away from the exit"
			last_pos = enemy.position
			last_remaining = enemy.remaining_distance()
			if visited[visited.size() - 1] != enemy.current_cell:
				var step: Vector2i = enemy.current_cell - visited[visited.size() - 1]
				if absi(step.x) + absi(step.y) != 1:
					problem = "diagonal step"
				visited.append(enemy.current_cell)
		if not escaped[0]:
			problem = "enemy from %s never reached the exit" % entrance
		if visited != board.layout.route_from(entrance).slice(0, visited.size()):
			problem = "enemy from %s did not follow its route" % entrance
	_check(problem == "", "enemies from all %d entrances follow the path cardinally to the exit%s" % [board.entrances().size(), "" if problem == "" else " - " + problem])


# --- Growth and screen fitting -------------------------------------------------------------

func _clear_wave(main: Node2D) -> void:
	main._on_start_wave_pressed()
	while main.wave_manager.is_wave_active():
		_simulate(main, 0.05, 1)
		_kill_all_active(main)
		_free_resolved(main)
	_close_skill_menu(main)


func test_map_grows_after_each_wave() -> void:
	var main: Node2D = _make_main()
	var board: Board = main.board
	var spot: Vector2i = _spot(main)
	main.try_buy_tower(spot)
	_check(board.half_width == GameConfig.MAP_START_HALF_WIDTH, "wave 1 starts on the small map (%dx%d)" % [board.window_rect_cells().size.x, board.window_rect_cells().size.y])
	var grew_every_wave: bool = true
	var entrances_never_drop: bool = true
	var previous_entrances: int = board.entrances().size()
	for wave in range(1, 25):
		var before: int = board.half_width
		_clear_wave(main)
		var expected: int = mini(before + GameConfig.MAP_GROWTH_PER_WAVE, GameConfig.MAP_MAX_HALF_WIDTH)
		if board.half_width != expected:
			grew_every_wave = false
		if board.entrances().size() < previous_entrances:
			entrances_never_drop = false
		previous_entrances = board.entrances().size()
	_check(grew_every_wave, "the map grows by one ring after every wave until the full %dx%d grid" % [GameConfig.GRID_COLUMNS, GameConfig.GRID_ROWS])
	_check(board.half_width == GameConfig.MAP_MAX_HALF_WIDTH and board.window_rect_cells().size == Vector2i(GameConfig.GRID_COLUMNS, GameConfig.GRID_ROWS), "the full map is reached and kept")
	_check(entrances_never_drop and board.entrances().size() >= 5, "entrances only ever increase (%d on the full map)" % board.entrances().size())
	_check(main.get_tower_at(spot) != null and board.is_blocked(spot), "towers stay put as the map grows")


func test_board_fits_the_screen_at_every_size() -> void:
	var board: Board = _make_board()
	var area: Rect2 = Rect2(0, 0, GameConfig.BOARD_WIDTH, GameConfig.BOARD_HEIGHT)
	var ok: bool = true
	var scales: Array[float] = []
	for hw in range(GameConfig.MAP_START_HALF_WIDTH, GameConfig.MAP_MAX_HALF_WIDTH + 1):
		board.set_half_width(hw)
		var world: Rect2 = board.window_rect_world()
		var screen: Rect2 = Rect2(board.position + world.position * board.scale, world.size * board.scale)
		if not area.grow(0.5).encloses(screen):
			ok = false
		if absf(screen.size.x - area.size.x) > 0.5 and absf(screen.size.y - area.size.y) > 0.5:
			ok = false  # must fill at least one dimension
		if absf(screen.get_center().x - area.get_center().x) > 0.5 or absf(screen.get_center().y - area.get_center().y) > 0.5:
			ok = false
		scales.append(board.scale.x)
	_check(ok, "at every map size the whole window is visible, centered and as large as possible")
	_check(scales[0] > scales[scales.size() - 1] and scales[scales.size() - 1] >= 0.6, "it zooms out as the map grows (%.2fx -> %.2fx)" % [scales[0], scales[scales.size() - 1]])


func test_clicks_hit_the_right_cell_at_any_zoom() -> void:
	var main: Node2D = _make_main()
	main.currency = 100000
	var ok: bool = true
	for hw: int in [GameConfig.MAP_START_HALF_WIDTH, 20, GameConfig.MAP_MAX_HALF_WIDTH]:
		main.board.set_half_width(hw)
		await _wait(2)
		main._on_build_pressed(TowerTypes.BASIC)
		var target: Vector2i = _spot(main, 3)
		# Board -> canvas -> window pixels, exactly the path a real mouse click takes in reverse.
		var screen: Vector2 = root.get_final_transform() * (main.board.get_global_transform_with_canvas() * Board.cell_to_world(target))
		for pressed: bool in [true, false]:
			var click: InputEventMouseButton = InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = screen
			click.global_position = screen
			root.push_input(click)
		await _wait(2)
		if main.get_tower_at(target) == null:
			ok = false
	_check(ok, "a real click on a tile places the tower on exactly that tile at every zoom level")


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


# --- Biomes ----------------------------------------------------------------------------------

func test_biome_cycle_and_art() -> void:
	_check(Biomes.index_for_wave(1) == 0 and Biomes.index_for_wave(10) == 0 and Biomes.index_for_wave(11) == 1 and Biomes.index_for_wave(25) == 2, "biomes change every 10 waves")
	_check(Biomes.index_for_wave(Biomes.count() * 10 + 1) == 0, "and cycle after the last one")
	var grounds: Dictionary = {}
	var deco_sets: Dictionary = {}
	var favored: Dictionary = {}
	var buffs_ok: bool = true
	for i in Biomes.count():
		var def: Dictionary = Biomes.get_def(i)
		grounds[def["ground"]] = true
		var kinds: Array = []
		for option: Array in def["decorations"]:
			kinds.append(option[0])
		kinds.sort()
		deco_sets[str(kinds)] = true
		favored[def["favored"]] = true
		for effect: String in def["favored_buff"]:
			if Biomes.bonus(i, def["favored"], effect) <= Biomes.bonus(i, "", effect):
				buffs_ok = false
		if def["buff"].is_empty() or Biomes.bonus(i, "", def["buff"].keys()[0]) > 0.11:
			buffs_ok = false
		if i > 0 and def["favored"] == Biomes.get_def(i - 1)["favored"]:
			buffs_ok = false
	_check(Biomes.count() >= 5, "%d biomes" % Biomes.count())
	_check(grounds.size() == Biomes.count() and deco_sets.size() == Biomes.count(), "every biome has its own ground colors and decoration set")
	_check(buffs_ok, "each biome gives every tower a small buff (<= 10%) and its favored tower a stronger one; neighbours favor different towers")
	_check(favored.size() == TowerTypes.ORDER.size(), "every tower type is favored by some biome")


func test_biome_buffs_apply_to_towers() -> void:
	var main: Node2D = _make_main(TEST_SEED, true)
	main.diamonds = 100
	main.try_unlock_skill("tesla")
	main.try_unlock_skill("cannon")
	main.currency = 10000
	main.try_buy_tower(_spot(main, 0), TowerTypes.BASIC)
	main.try_buy_tower(_spot(main, 1), TowerTypes.TESLA)
	main.try_buy_tower(_spot(main, 2), TowerTypes.CANNON)
	var basic: Tower = main.get_tower_at(_spot(main, 0)) if main.get_tower_at(_spot(main, 0)) != null else null
	var towers: Array = main._towers_by_cell.values()
	var by_type: Dictionary = {}
	for t: Tower in towers:
		by_type[t.tower_type] = t
	basic = by_type[TowerTypes.BASIC]
	var tesla: Tower = by_type[TowerTypes.TESLA]
	var cannon: Tower = by_type[TowerTypes.CANNON]
	# Meadow: +10% range for all, Basic +15% more.
	_check(is_equal_approx(basic.attack_range, GameConfig.TOWER_RANGE * 1.25) and is_equal_approx(tesla.attack_range, 80.0 * 1.10), "Meadow: Basic +25%% range (%s), others +10%% (%s)" % [basic.attack_range, tesla.attack_range])
	main.board.set_biome(1)  # Desert: +5% hit speed, Cannon +20%
	main._apply_skill_modifiers()
	_check(is_equal_approx(cannon.cooldown, 1.6 / 1.20) and is_equal_approx(basic.cooldown, GameConfig.TOWER_COOLDOWN / 1.05), "Desert: Cannon +20%% hit speed, others +5%%")
	_check(is_equal_approx(basic.attack_range, GameConfig.TOWER_RANGE), "the Meadow range buff is gone in the Desert")
	main.board.set_biome(2)  # Tundra: +5% damage, Tesla +25%
	main._apply_skill_modifiers()
	_check(tesla.damage["shield"] == roundi(24 * 1.25) and basic.damage["health"] == roundi(GameConfig.TOWER_DAMAGE * 1.05), "Tundra: Tesla +25%% damage, others +5%%")
	main._refresh_hud()
	_check(main.hud._biome_label.text.begins_with("Tundra"), "the HUD names the biome and its buff (%s)" % main.hud._biome_label.text)


func test_biome_changes_every_ten_waves() -> void:
	var main: Node2D = _make_main(TEST_SEED, true)
	for wave in range(1, 10):
		_clear_wave(main)
	_check(main.board.biome_index == 0, "still Meadow after wave 9")
	_clear_wave(main)
	_check(main.board.biome_index == 1 and main.hud.get_message().contains("Desert"), "the Desert begins once wave 10 is cleared (%s)" % main.hud.get_message())


# --- Run flow ---------------------------------------------------------------------------------

func test_wave_flow_defeat_and_restart() -> void:
	var main: Node2D = _make_main()
	var wm: WaveManager = main.wave_manager
	var lives_lost: Array[int] = [0]
	wm.enemy_escaped.connect(func(e: Enemy) -> void: lives_lost[0] += e.lives_cost)
	main._on_start_wave_pressed()
	_check(main.state == main.GameState.WAVE_ACTIVE and wm.current_wave == 1, "Start Wave launches wave 1")
	main._on_start_wave_pressed()
	_check(wm.current_wave == 1, "pressing Start Wave again does not stack waves")
	var guard: int = 0
	while not main.is_game_over() and guard < 50:
		guard += 1
		_simulate(main, 0.05, 20 * 60 * 3)
		_free_resolved(main)
		if main.state == main.GameState.BETWEEN_WAVES:
			_check(main.lives == GameConfig.STARTING_LIVES - lives_lost[0], "wave %d: lives reduced exactly by escaped enemies' lives cost" % wm.current_wave)
			main._on_start_wave_pressed()
	_check(main.state == main.GameState.DEFEAT and main.lives == 0, "with no towers the base falls (wave %d)" % wm.current_wave)
	var spawned_before: int = main.board.enemies.get_child_count()
	wm.step(10.0)
	_check(main.board.enemies.get_child_count() == spawned_before and not wm.is_wave_active(), "spawning stopped on defeat")
	_check(not main.try_buy_tower(_spot(main)), "building is disabled after defeat")
	var old_seed: int = wm.run_seed
	var old_map: Dictionary = main.board.layout.parent
	main.restart_game()
	_check(main.currency == 200 and main.lives == 10 and main.state == main.GameState.READY, "Restart restores 200 gold, 10 lives, READY")
	_check(wm.current_wave == 0 and main.board.get_blocked_cells().is_empty() and main.board.half_width == GameConfig.MAP_START_HALF_WIDTH, "Restart resets waves, towers and the map size")
	_check(wm.run_seed != old_seed and main.board.layout.parent != old_map, "Restart picks a new seed and a new map")


func test_window_fit_sizes() -> void:
	_check(WindowFit.fitted_size(Vector2i(1920, 1040)) == Vector2i(1600, 900), "large screens keep the 1600x900 base size")
	var laptop: Vector2i = WindowFit.fitted_size(Vector2i(1256, 706))
	_check(laptop.x <= 1256 and laptop.y <= 706, "1366x768-class screen: window fits (%s)" % laptop)
	_check(absf(float(laptop.x) / laptop.y - 16.0 / 9.0) < 0.01, "fitted window keeps 16:9")
	_check(WindowFit.fitted_size(Vector2i(300, 200)) == WindowFit.MIN_SIZE, "tiny screens fall back to the minimum size")
