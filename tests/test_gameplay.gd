extends "res://tests/test_base.gd"
## Wave generation, enemy types and traits, endless flow, tower upgrades, selling and selection.
##   godot --headless --path <project> --script res://tests/test_gameplay.gd


func get_tests() -> Array[Callable]:
	return [
		test_generator_is_deterministic_per_seed,
		test_generator_varies_between_runs,
		test_generator_long_run_sanity,
		test_generator_boss_waves,
		test_late_waves_bigger_faster_and_longer,
		test_enemy_types_are_distinct,
		test_enemy_stats_follow_type,
		test_layers_only_top_takes_damage,
		test_mender_regenerates_up_to_max,
		test_splitter_spawns_children_and_wave_waits,
		test_boss_escape_costs_five_lives,
		test_endless_waves_never_end_in_victory,
		test_upgrade_one_path_per_tower,
		test_upgrade_effects,
		test_upgrade_rejections_change_nothing,
		test_sell_refunds_half_and_unblocks,
		test_sell_mid_wave_enemies_reroute_through_freed_cell,
		test_selection_and_hud,
	]


# --- Wave generator ------------------------------------------------------------------

func test_generator_is_deterministic_per_seed() -> void:
	var a: WaveGenerator = WaveGenerator.new(777)
	var b: WaveGenerator = WaveGenerator.new(777)
	var same: bool = true
	for wave in range(1, 41):
		if a.generate(wave) != b.generate(wave):
			same = false
	_check(same, "same seed produces identical waves 1-40")
	_check(a.generate(5) == a.generate(5), "regenerating a wave gives the same result (preview matches the real wave)")


func test_generator_varies_between_runs() -> void:
	var differing_waves: int = 0
	var a: WaveGenerator = WaveGenerator.new(1)
	var b: WaveGenerator = WaveGenerator.new(2)
	for wave in range(1, 21):
		if a.generate(wave) != b.generate(wave):
			differing_waves += 1
	_check(differing_waves >= 18, "different seeds give different waves (%d of 20 differ)" % differing_waves)
	var sizes: Dictionary = {}
	for seed_value in 30:
		sizes[WaveGenerator.new(seed_value).generate(6).size()] = true
	_check(sizes.size() >= 2, "wave size varies slightly between runs (%d distinct sizes for wave 6)" % sizes.size())
	var size_1: int = WaveGenerator.new(3).generate(1).size()
	_check(size_1 >= 6 and size_1 <= 10, "wave 1 stays close to the original 8 enemies (%d)" % size_1)


func test_generator_long_run_sanity() -> void:
	var problems: PackedStringArray = PackedStringArray()
	var seen_types: Dictionary = {}
	for seed_value in [11, 222, 3333]:
		var gen: WaveGenerator = WaveGenerator.new(seed_value)
		var window_hp: float = 0.0
		var window_totals: Array[float] = []
		for wave in range(1, 301):
			var entries: Array[Dictionary] = gen.generate(wave)
			if entries.is_empty() or entries.size() > GameConfig.MAX_ENEMIES_PER_WAVE:
				problems.append("seed %d wave %d has %d entries" % [seed_value, wave, entries.size()])
			for entry: Dictionary in entries:
				var type_id: String = entry["type"]
				seen_types[type_id] = true
				if not EnemyTypes.has_type(type_id):
					problems.append("unknown type %s" % type_id)
					continue
				if wave < EnemyTypes.get_def(type_id)["min_wave"]:
					problems.append("%s appeared on wave %d before unlock" % [type_id, wave])
				var health: float = entry["health"]
				if not is_finite(health) or health < 1.0:
					problems.append("bad health %s on wave %d" % [health, wave])
				if entry["reward"] < 1 or entry["lives"] < 1 or entry["interval"] < 0.08:
					problems.append("bad reward/lives/interval on wave %d" % wave)
				window_hp += health
			if wave % 10 == 0:
				# Composition is random, so compare each 10-wave window with the one 30 waves earlier.
				if window_totals.size() >= 3 and window_hp <= window_totals[window_totals.size() - 3]:
					problems.append("seed %d: total health of waves %d-%d not above waves %d-%d" % [seed_value, wave - 9, wave, wave - 39, wave - 30])
				window_totals.append(window_hp)
				window_hp = 0.0
		if problems.size() > 10:
			break
	_check(problems.is_empty(), "300 waves x 3 seeds: valid sizes, unlocked types, finite stats, difficulty keeps rising%s" % ("" if problems.is_empty() else " - " + problems[0]))
	_check(seen_types.size() == EnemyTypes.DEFS.size(), "every enemy type appears in long runs (%d of %d)" % [seen_types.size(), EnemyTypes.DEFS.size()])
	var early: Dictionary = {}
	for entry: Dictionary in WaveGenerator.new(5).generate(2):
		early[entry["type"]] = true
	_check(early.keys() == [EnemyTypes.GRUNT], "wave 2 contains only Grunts (types unlock gradually)")


func test_generator_boss_waves() -> void:
	var gen: WaveGenerator = WaveGenerator.new(99)
	var ok: bool = true
	for wave in range(1, 61):
		var bosses: int = 0
		for entry: Dictionary in gen.generate(wave):
			if entry["type"] == EnemyTypes.BOSS:
				bosses += 1
		var expected: int = mini(wave / 10, GameConfig.MAX_BOSSES_PER_WAVE) if wave % 10 == 0 else 0
		if bosses != expected:
			ok = false
	_check(ok, "Warlord bosses appear only every 10th wave (1 on wave 10, 2 on wave 20, capped at 3)")


func test_late_waves_bigger_faster_and_longer() -> void:
	var stats: Dictionary = {}
	for wave: int in [10, 20, 30, 40, 50, 60, 80]:
		var counts: Array[float] = []
		var durations: Array[float] = []
		for seed_value in 8:
			var entries: Array[Dictionary] = WaveGenerator.new(seed_value).generate(wave)
			var duration: float = 0.0
			for entry: Dictionary in entries:
				duration += entry["interval"]
			counts.append(entries.size())
			durations.append(duration)
		var avg_count: float = 0.0
		var avg_duration: float = 0.0
		for i in counts.size():
			avg_count += counts[i] / counts.size()
			avg_duration += durations[i] / durations.size()
		stats[wave] = {"count": avg_count, "duration": avg_duration, "rate": avg_count / avg_duration}
	print("  ..   [%s] %s" % [_current_test, stats])
	_check(stats[60]["count"] >= stats[30]["count"] * 2.5, "far more enemies past wave 30 (wave 30: %d, wave 60: %d)" % [stats[30]["count"], stats[60]["count"]])
	_check(stats[80]["count"] > stats[60]["count"] and stats[80]["count"] <= GameConfig.MAX_ENEMIES_PER_WAVE, "counts keep growing up to the %d cap" % GameConfig.MAX_ENEMIES_PER_WAVE)
	var faster: bool = true
	var longer: bool = true
	var previous: int = 0
	for wave: int in [10, 20, 30, 40, 50, 60, 80]:
		if previous > 0:
			if stats[wave]["rate"] <= stats[previous]["rate"]:
				faster = false
			if stats[wave]["duration"] <= stats[previous]["duration"]:
				longer = false
		previous = wave
	_check(faster, "spawns per second rise every 10 waves")
	_check(longer, "yet every later wave still takes longer to spawn")


# --- Enemy types -----------------------------------------------------------------------

func test_enemy_types_are_distinct() -> void:
	var looks: Dictionary = {}
	var stats: Dictionary = {}
	var traits: int = 0
	for type_id: String in EnemyTypes.DEFS:
		var def: Dictionary = EnemyTypes.get_def(type_id)
		looks[[def["shape"], def["color"]]] = true
		stats[[def["speed"], def["health"], def["reward"]]] = true
		if def["armor"] > 0 or def["regen"] > 0.0 or def["split_count"] > 0 or def["lives"] > 1:
			traits += 1
	var count: int = EnemyTypes.DEFS.size()
	_check(count >= 5, "at least 5 enemy types (%d)" % count)
	_check(looks.size() == count, "every type has a unique shape/color appearance")
	_check(stats.size() == count, "every type has a unique speed/health/reward profile")
	_check(traits >= 4, "several types have unique traits (%d)" % traits)


func test_enemy_stats_follow_type() -> void:
	var board: Board = _make_board()
	var ok: bool = true
	for type_id: String in EnemyTypes.DEFS:
		var def: Dictionary = EnemyTypes.get_def(type_id)
		var entry: Dictionary = WaveGenerator.make_entry(type_id, 12)
		var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
		enemy.setup(board, entry, 12)
		board.enemies.add_child(enemy)
		if enemy.speed != def["speed"] or enemy.max_armor != entry["armor"] or enemy.max_shield != entry["shield"] or enemy.lives_cost != def["lives"] \
				or enemy.shape != def["shape"] or enemy.max_health != entry["health"] or enemy.reward != entry["reward"]:
			ok = false
	_check(ok, "spawned enemies take speed, health/armor/shield pools, lives, shape and reward from their type/wave")
	_check(WaveGenerator.make_entry(EnemyTypes.GRUNT, 20)["health"] > WaveGenerator.make_entry(EnemyTypes.GRUNT, 1)["health"], "health scales up with wave number")
	_check(WaveGenerator.make_entry(EnemyTypes.GRUNT, 20)["reward"] > WaveGenerator.make_entry(EnemyTypes.GRUNT, 1)["reward"], "rewards scale up with wave number")
	var runner: Enemy = _spawn_enemy(board, 100.0, EnemyTypes.RUNNER)
	var tank: Enemy = _spawn_enemy(board, 100.0, EnemyTypes.TANK)
	runner.advance(0.25)
	tank.advance(0.25)
	_check(runner.position.x - 16.0 > (tank.position.x - 16.0) * 2.0, "Runner covers more ground than Tank in the same time")


func test_layers_only_top_takes_damage() -> void:
	var board: Board = _make_board()
	var tank: Enemy = _spawn_enemy(board, 100.0, EnemyTypes.TANK)
	var armor_before: float = tank.armor
	_check(tank.top_layer() == "armor" and armor_before > 0.0, "a Tank's white armor sits on top of its health")
	tank.take_hit({"health": 999, "armor": 15, "shield": 999})
	_check(tank.armor == armor_before - 15.0 and tank.health == 100.0, "only the armor layer takes the hit, using the armor damage stat")
	tank.take_damage(1.0e9)
	_check(tank.armor == 0.0 and tank.health == 100.0 and tank.is_active(), "excess damage never spills into the next layer")
	tank.take_hit({"health": 15, "armor": 999, "shield": 999})
	_check(tank.health == 85.0, "with armor gone, health takes the health damage stat")
	var aegis: Enemy = _spawn_enemy(board, 50.0, EnemyTypes.AEGIS)
	_check(aegis.top_layer() == "shield" and aegis.shield > 0.0, "an Aegis's purple shield is on top")
	aegis.take_hit({"health": 999, "armor": 999, "shield": 0})
	_check(aegis.health == 50.0, "zero shield damage does nothing to a shielded enemy")
	var boss: Enemy = _spawn_enemy(board, 100.0, EnemyTypes.BOSS)
	var order: Array[String] = [boss.top_layer()]
	boss.take_damage(1.0e9)
	order.append(boss.top_layer())
	boss.take_damage(1.0e9)
	order.append(boss.top_layer())
	_check(order == ["shield", "armor", "health"], "the boss peels shield, then armor, then health (%s)" % [order])


func test_mender_regenerates_up_to_max() -> void:
	var board: Board = _make_board()
	var mender: Enemy = _spawn_enemy(board, 100.0, EnemyTypes.MENDER)
	mender.take_damage(40)
	mender.step(1.0)
	_check(is_equal_approx(mender.health, 65.0), "Mender regenerates 5%% of max health per second (HP %s)" % mender.health)
	mender.step(30.0)
	_check(mender.health == mender.max_health, "regeneration never exceeds max health")
	var grunt: Enemy = _spawn_enemy(board, 100.0, EnemyTypes.GRUNT)
	grunt.take_damage(40)
	grunt.step(1.0)
	_check(grunt.health == 60.0, "non-regenerating types do not heal")


func test_splitter_spawns_children_and_wave_waits() -> void:
	var main: Node2D = _make_main()
	var wm: WaveManager = main.wave_manager
	main._on_start_wave_pressed()
	_kill_all_active(main)
	# Replace the generated wave with a single Splitter.
	wm._queue = [WaveGenerator.make_entry(EnemyTypes.SPLITTER, 8)]
	wm._queue_index = 0
	wm._alive = 0
	_free_resolved(main)
	var currency_before: int = main.currency
	_simulate(main, 0.05, 1)
	var splitter: Enemy = _active_enemies(main)[0]
	_check(splitter.type_id == EnemyTypes.SPLITTER, "Splitter spawned")
	_simulate(main, 0.05, 30)
	var pos: Vector2 = splitter.position
	var cells: Array[Vector2i] = splitter.get_occupied_cells()
	var reward: int = splitter.reward
	splitter.take_damage(1000000)
	var children: Array[Enemy] = _active_enemies(main)
	_check(children.size() == 3, "Splitter death spawns 3 Swarmlings (%d)" % children.size())
	var same_place: bool = true
	for child: Enemy in children:
		if child.type_id != EnemyTypes.SWARMLING or child.position != pos or child.get_occupied_cells() != cells:
			same_place = false
	_check(same_place, "children appear exactly where the Splitter died, on the same movement segment")
	_check(wm.get_unresolved_count() == 3 and wm.is_wave_active(), "wave stays active while children live")
	_check(main.currency == currency_before + reward, "Splitter bounty paid once")
	_check(_invariant_violation(main) == "", "invariants hold after split: %s" % _invariant_violation(main))
	_simulate(main, 0.05, 20)
	var moved: bool = true
	for child: Enemy in children:
		if child.position == pos:
			moved = false
	_check(moved, "children keep walking toward the exit")
	var child_rewards: int = 0
	for child: Enemy in children:
		child_rewards += child.reward
	_kill_all_active(main)
	_check(not wm.is_wave_active() and main.state == main.GameState.BETWEEN_WAVES, "wave completes once the children are resolved")
	_check(main.currency == currency_before + reward + child_rewards + WaveGenerator.wave_clear_bonus(1), "children pay their own bounty, plus the wave bonus")


func test_boss_escape_costs_five_lives() -> void:
	var main: Node2D = _make_main()
	var wm: WaveManager = main.wave_manager
	main._on_start_wave_pressed()
	_kill_all_active(main)
	_free_resolved(main)
	wm._queue = [WaveGenerator.make_entry(EnemyTypes.BOSS, 10)]
	wm._queue_index = 0
	wm._alive = 0
	_simulate(main, 0.05, 20 * 60 * 2)
	_check(main.lives == GameConfig.STARTING_LIVES - 5, "an escaped Warlord costs 5 lives (lives %d)" % main.lives)
	_check(main.state == main.GameState.BETWEEN_WAVES, "game continues after a boss escape with lives left")


func test_endless_waves_never_end_in_victory() -> void:
	var main: Node2D = _make_main()
	var wm: WaveManager = main.wave_manager
	var earned: Array[int] = [0]
	wm.enemy_killed.connect(func(e: Enemy) -> void: earned[0] += e.reward)
	var bonuses: int = 0
	var clean: bool = true
	for wave in range(1, 31):
		main._on_start_wave_pressed()
		if wm.current_wave != wave:
			clean = false
			break
		var guard: int = 0
		while wm.is_wave_active() and guard < 20000:
			guard += 1
			_simulate(main, 0.05, 1)
			_kill_all_active(main)
			_free_resolved(main)
		if wm.is_wave_active() or main.state != main.GameState.BETWEEN_WAVES or wm.get_unresolved_count() != 0:
			clean = false
			break
		if main.is_skill_menu_open() != (wave % GameConfig.SKILL_MENU_WAVE_INTERVAL == 0):
			clean = false
			break
		_close_skill_menu(main)
		bonuses += WaveGenerator.wave_clear_bonus(wave)
	_check(clean, "30 consecutive waves (3 boss waves) complete cleanly; the skill tree opens after every 5th")
	_check(wm.current_wave == 30 and wm.has_next_wave(), "after wave 30 another wave is still available")
	_check(main.lives == GameConfig.STARTING_LIVES, "no lives lost when everything is killed")
	_check(main.currency == GameConfig.STARTING_CURRENCY + earned[0] + bonuses, "currency = start + every bounty once + every wave bonus (%d)" % main.currency)
	_check(main.board.enemies.get_child_count() == 0, "no enemy nodes leak between waves")


# --- Upgrades, selling and selection ----------------------------------------------------

func test_upgrade_one_path_per_tower() -> void:
	var main: Node2D = _make_main()
	_unlock_tower_skills(main)
	main.currency = 10000
	main.try_buy_tower(Vector2i(10, 5))
	var tower: Tower = main.get_tower_at(Vector2i(10, 5))
	var before: int = main.currency
	_check(main.try_upgrade_tower(tower, Tower.UpgradePath.DAMAGE), "first Damage upgrade succeeds")
	_check(main.currency == before - GameConfig.UPGRADE_COSTS[0], "first upgrade costs %d" % GameConfig.UPGRADE_COSTS[0])
	before = main.currency
	_check(not main.try_upgrade_tower(tower, Tower.UpgradePath.RANGE), "Range upgrade rejected once Damage was chosen")
	_check(not main.try_upgrade_tower(tower, Tower.UpgradePath.SPEED), "Speed upgrade rejected once Damage was chosen")
	_check(main.currency == before and tower.upgrade_path == Tower.UpgradePath.DAMAGE and tower.upgrade_level == 1, "rejected upgrades cost nothing and change nothing")
	_check(main.try_upgrade_tower(tower, Tower.UpgradePath.DAMAGE) and main.try_upgrade_tower(tower, Tower.UpgradePath.DAMAGE), "Damage levels 2 and 3 succeed")
	_check(tower.upgrade_level == 3 and tower.damage["health"] == roundi(GameConfig.TOWER_DAMAGE * (1.0 + 3 * GameConfig.UPGRADE_DAMAGE_FACTOR_PER_LEVEL)), "level 3 Damage tower deals %s" % [tower.damage])
	before = main.currency
	_check(not main.try_upgrade_tower(tower, Tower.UpgradePath.DAMAGE) and main.currency == before, "no upgrades past max level")
	_check(main.hud.get_message() == "Tower is fully upgraded", "max-level message shown")
	var expected_invested: int = GameConfig.TOWER_COST + GameConfig.UPGRADE_COSTS[0] + GameConfig.UPGRADE_COSTS[1] + GameConfig.UPGRADE_COSTS[2]
	_check(tower.invested == expected_invested, "tower tracks total invested (%d)" % tower.invested)


func test_upgrade_effects() -> void:
	var main: Node2D = _make_main()
	_unlock_tower_skills(main)
	main.currency = 10000
	main.try_buy_tower(Vector2i(10, 5))
	main.try_buy_tower(Vector2i(12, 5))
	var ranged: Tower = main.get_tower_at(Vector2i(10, 5))
	var fast: Tower = main.get_tower_at(Vector2i(12, 5))
	main.try_upgrade_tower(ranged, Tower.UpgradePath.RANGE)
	main.try_upgrade_tower(fast, Tower.UpgradePath.SPEED)
	_check(ranged.attack_range == GameConfig.TOWER_RANGE + GameConfig.UPGRADE_RANGE_PER_LEVEL and ranged.damage["health"] == GameConfig.TOWER_DAMAGE, "Range upgrade only increases range (%s)" % ranged.attack_range)
	_check(is_equal_approx(fast.cooldown, GameConfig.TOWER_COOLDOWN * GameConfig.UPGRADE_COOLDOWN_FACTOR) and fast.damage["health"] == GameConfig.TOWER_DAMAGE, "Speed upgrade only shortens the cooldown (%s s)" % fast.cooldown)
	# A Range-upgraded tower hits an enemy the base range cannot reach.
	var board: Board = main.board
	var enemy: Enemy = _spawn_enemy(board, 1000.0)
	enemy.position = ranged.position + Vector2(GameConfig.TOWER_RANGE + 10.0, 0)
	ranged.step(0.2)
	_check(enemy.health < 1000.0, "upgraded range reaches an enemy beyond base range")
	enemy.position = Vector2(-1000, -1000)
	enemy.discard()
	var target: Enemy = _spawn_enemy(board, 1000.0)
	target.position = fast.position + Vector2(20, 0)
	var shots: int = 0
	for i in 100:  # 5 seconds
		var before: float = target.health
		fast.step(0.05)
		if target.health < before:
			shots += 1
	_check(shots >= 7, "Speed-upgraded tower fires more often (%d shots in 5 s, base would be ~7)" % shots)


func test_upgrade_rejections_change_nothing() -> void:
	var main: Node2D = _make_main()
	_unlock_tower_skills(main)
	main.try_buy_tower(Vector2i(10, 5))
	main.try_buy_tower(Vector2i(11, 5))
	main.try_buy_tower(Vector2i(12, 5))
	var tower: Tower = main.get_tower_at(Vector2i(10, 5))
	_check(main.currency == 20, "20 currency left after 3 towers")
	_check(not main.try_upgrade_tower(tower, Tower.UpgradePath.DAMAGE), "upgrade rejected with insufficient currency")
	_check(main.currency == 20 and tower.upgrade_level == 0 and tower.damage["health"] == GameConfig.TOWER_DAMAGE, "rejected upgrade changes nothing")
	_check(not main.try_upgrade_tower(null, Tower.UpgradePath.DAMAGE), "upgrading nothing is rejected safely")
	_check(not main.try_upgrade_tower(tower, Tower.UpgradePath.NONE), "the NONE path is not an upgrade")


func test_sell_refunds_half_and_unblocks() -> void:
	var main: Node2D = _make_main()
	_unlock_tower_skills(main)
	var cell: Vector2i = Vector2i(10, 12)
	main.try_buy_tower(cell)
	_check(main.currency == 140, "bought one tower")
	_check(main.try_sell_tower(cell), "selling succeeds")
	_check(main.currency == 140 + GameConfig.TOWER_COST / 2, "plain tower refunds 50%% of 60 (%d)" % main.currency)
	_check(not main.board.is_blocked(cell) and not main.board.is_solid(cell) and main.get_tower_at(cell) == null, "sold cell is free again")
	_check(main.board.towers.get_child_count() == 0, "tower node removed")
	_check(not main.try_sell_tower(cell), "selling an empty cell does nothing")
	main.currency = 1000
	main.try_buy_tower(cell)
	var tower: Tower = main.get_tower_at(cell)
	main.try_upgrade_tower(tower, Tower.UpgradePath.RANGE)
	var before: int = main.currency
	main.try_sell_tower(cell)
	_check(main.currency == before + (GameConfig.TOWER_COST + GameConfig.UPGRADE_COSTS[0]) / 2, "upgraded tower refunds 50%% of build + upgrade cost")
	_check(main.board.has_route(SPAWN, EXIT) and main.board.find_path(SPAWN, EXIT).size() == 40, "straight route restored after selling")


func test_sell_mid_wave_enemies_reroute_through_freed_cell() -> void:
	var main: Node2D = _make_main()
	main.currency = 10000
	# Wall at column 20 with a single gap at (20, 2) forces a long detour.
	for y in GameConfig.GRID_ROWS:
		if y != 2:
			main.try_buy_tower(Vector2i(20, y))
	main._on_start_wave_pressed()
	_simulate(main, 0.05, 40)
	var enemy: Enemy = _active_enemies(main)[0]
	enemy.max_health = 1.0e9  # the wall towers must not kill it before it reroutes
	enemy.health = 1.0e9
	main.try_sell_tower(Vector2i(20, 12))
	_check(_invariant_violation(main) == "", "invariants hold right after a mid-wave sale: %s" % _invariant_violation(main))
	var used_gap: bool = false
	var guard: int = 0
	while enemy.is_active() and guard < 4000:
		guard += 1
		_simulate(main, 0.05, 1)
		if enemy.current_cell == Vector2i(20, 12):
			used_gap = true
	_check(used_gap, "enemy reroutes through the freed cell instead of the old detour")


func test_selection_and_hud() -> void:
	var main: Node2D = _make_main()
	_unlock_tower_skills(main)
	main.currency = 1000
	main.try_buy_tower(Vector2i(10, 5))
	var tower: Tower = main.get_tower_at(Vector2i(10, 5))
	main._on_board_cell_clicked(Vector2i(10, 5))
	_check(main.selected_tower == tower and tower.selected, "clicking a tower outside build mode selects it")
	_check(main.hud.is_selection_visible(), "upgrade/sell panel is shown")
	main._on_upgrade_pressed(Tower.UpgradePath.SPEED)
	_check(tower.upgrade_path == Tower.UpgradePath.SPEED, "upgrade button applies to the selected tower")
	var hud: Hud = main.hud
	var others_closed: bool = true
	for path: int in [Tower.UpgradePath.DAMAGE, Tower.UpgradePath.RANGE, Tower.UpgradePath.PIERCE]:
		var button: Button = hud.get_upgrade_button(path)
		if not button.visible or not button.disabled or not button.text.contains("n/a"):
			others_closed = false
	_check(others_closed and not hud.get_upgrade_button(Tower.UpgradePath.SPEED).disabled, "other paths (incl. the unique one) stay in place but are disabled as n/a once one is chosen")
	main._on_board_cell_clicked(Vector2i(30, 20))
	_check(main.selected_tower == null and not tower.selected and not main.hud.is_selection_visible(), "clicking empty ground deselects")
	main._on_board_cell_clicked(Vector2i(10, 5))
	main._on_cancel_pressed()
	_check(main.selected_tower == null, "Esc / right-click deselects")
	main._on_board_cell_clicked(Vector2i(10, 5))
	main._on_build_pressed(TowerTypes.BASIC)
	_check(main.selected_tower == null and main.build_mode, "entering build mode clears the selection")
	main._on_cancel_pressed()
	main._on_board_cell_clicked(Vector2i(10, 5))
	var before: int = main.currency
	main._on_sell_pressed()
	_check(main.get_tower_at(Vector2i(10, 5)) == null and main.currency == before + tower.sell_value() and main.selected_tower == null, "Sell button sells the selected tower and clears the selection")
