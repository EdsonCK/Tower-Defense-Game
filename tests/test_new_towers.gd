extends SceneTree
## Real projectile collision, shared upgrade budget, unlocks and cleanup fixtures.

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func fixture(all_skills: bool = true) -> TDGame:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	if all_skills:
		game.progression.unlocked.assign(SkillCatalog.IDS)
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.currency = 100000 # Explicit combat/economy fixture; not balance evidence.
	return game


func enemy(game: TDGame, point: Vector2, hp: int = 1000) -> Enemy:
	var unit := Enemy.new()
	game.board.get_node("Enemies").add_child(unit)
	unit.setup(game.board, hp)
	unit.position = point
	unit.set_process(false)
	return unit


func build(game: TDGame, kind: int, cell: Vector2i) -> Tower:
	game.select_tower(kind)
	check(game.purchase_tower(cell), "build tower kind %d" % kind)
	var result := game.tower_at_cell(cell)
	result.set_process(false)
	return result


func projectile(game: TDGame) -> CombatProjectile:
	return game.board.get_node("Projectiles").get_child(-1) as CombatProjectile


func _test_unlocks_and_mixing() -> void:
	for kind in range(1, 5):
		var game := fixture(false)
		var gold := game.currency
		game.select_tower(kind)
		game.build_kind = kind as Tower.Kind # Direct transaction must enforce the same gate.
		check(not game.purchase_tower(Vector2i(10, 10)) and game.currency == gold, "locked type cannot be constructed through direct intent")
		game.open_skill_tree()
		game.progression.diamonds = 100
		check(game.purchase_skill("tesla"), "Tesla remains the sole initial unlock")
		if kind > 1:
			check(game.purchase_skill(TowerCatalog.DATA[kind].unlock), "new tower branches from Tesla")
		game.close_skill_tree()
		var tower := build(game, kind, Vector2i(10, 10))
		game.select_placed_tower(tower)
		check(not game.upgrade_selected_tower(Tower.Upgrade.DAMAGE), "each type still requires its own training")
		var before := game.currency
		check(game.remove_selected_tower() and game.currency == before + floori(float(TowerCatalog.DATA[kind].cost) / 2), "new tower refund is half construction")
		game.free()

	for kind in range(5):
		var game := fixture()
		var data: Dictionary = TowerCatalog.DATA[kind]
		game.progression.unlocked.erase(data.mastery)
		var tower := build(game, kind, Vector2i(10, 10))
		game.select_placed_tower(tower)
		var expected := game.currency
		for category in [Tower.Upgrade.DAMAGE, Tower.Upgrade.RANGE, Tower.Upgrade.SPEED, Tower.Upgrade.DAMAGE, Tower.Upgrade.SPECIAL]:
			expected -= tower.next_upgrade_cost()
			check(game.upgrade_selected_tower(category) and game.currency == expected, "kind %d mixes category %d with total-slot pricing" % [kind, category])
		check(tower.upgrade_level == 5 and tower.levels(Tower.Upgrade.DAMAGE) == 2 and tower.levels(Tower.Upgrade.RANGE) == 1 and tower.levels(Tower.Upgrade.SPEED) == 1 and tower.levels(Tower.Upgrade.SPECIAL) == 1, "mixed counts sum to five on type %d" % kind)
		check(not game.upgrade_selected_tower(Tower.Upgrade.RANGE) and game.currency == expected and tower.next_upgrade_cost() == 0, "sixth purchase is gated by per-type mastery")
		game.open_skill_tree()
		game.progression.diamonds = 100
		check(game.purchase_skill(data.mastery) and tower.max_upgrades() == 6, "mastery expands already placed type %d to six" % kind)
		game.close_skill_tree()
		game.select_placed_tower(tower)
		expected -= int(data.prices[5])
		check(game.upgrade_selected_tower(Tower.Upgrade.RANGE) and tower.upgrade_level == 6 and game.currency == expected, "sixth slot charges type-specific sixth price")
		check(not game.upgrade_selected_tower(Tower.Upgrade.SPEED) and tower.upgrade_level == 6 and game.currency == expected, "seventh slot is always rejected")
		check(tower.attack_range() > float(data.range) and tower.attack_interval() < float(data.interval) and tower.damage() > int(data.damage), "damage/range/speed combine on every type")
		check(game.board.path_is_valid(game.board.find_path(), GameConfig.SPAWN), "new upgrades preserve board path")
		game.free()


func _test_mortar() -> void:
	var game := fixture()
	var mortar := build(game, Tower.Kind.MORTAR, Vector2i(10, 10))
	var center := mortar.position + Vector2(220, 0)
	var first := enemy(game, center)
	var boundary := enemy(game, center + Vector2(mortar.blast_radius(), 0))
	var outside := enemy(game, center + Vector2(mortar.blast_radius() + 0.1, 0))
	mortar.attack(first)
	var shot := projectile(game)
	check(shot.kind == CombatProjectile.Kind.MORTAR and first.health == 1000, "mortar launches with no instant damage")
	shot._process(shot.flight_duration * 0.5)
	check(shot.position.is_equal_approx(mortar.position.lerp(center, 0.5)) and not shot._impact and first.health == 1000, "mortar is in flight halfway, before AoE")
	shot._process(shot.flight_duration * 0.5 + 0.0001)
	check(first.health == 1000 - mortar.damage() and boundary.health == 1000 - mortar.damage(), "mortar impact damages every living enemy within inclusive AoE")
	check(outside.health == 1000, "mortar AoE excludes enemies outside radius")
	shot._process(0.1)
	check(first.health == 1000 - mortar.damage(), "explosion animation cannot deal repeat damage")
	shot._process(0.3)
	check(shot.is_queued_for_deletion(), "explosion expires")
	game.progression.unlocked.erase("mortar_area")
	mortar.configure_progression(game.progression)
	check(mortar.blast_radius() == 64, "base blast radius without special research")
	game.progression.unlocked.append("mortar_area")
	mortar.configure_progression(game.progression)
	check(mortar.blast_radius() == 80 and mortar.apply_upgrade(Tower.Upgrade.SPECIAL) and mortar.blast_radius() == 88, "research and special purchases improve radius independently")
	# A shell hits its ground destination even if its original target disappears.
	var doomed := enemy(game, mortar.position + Vector2(160, 0))
	var survivor := enemy(game, doomed.position + Vector2(10, 0))
	mortar.attack(doomed)
	shot = projectile(game)
	doomed.free()
	shot._process(2.0)
	check(survivor.health == 1000 - mortar.damage(), "arcing shell survives freed target and applies snapshot damage at landing point")
	game.free()


func _test_ice_and_freeze() -> void:
	var game := fixture()
	var ice := build(game, Tower.Kind.ICE, Vector2i(10, 10))
	check(ice.attack_description().contains("35%") and ice.attack_description().contains("8%"), "ice tooltip formats slow and freeze percentages without runtime errors")
	var unit := enemy(game, ice.position + Vector2(80, 0))
	ice.attack(unit)
	var shot := projectile(game)
	shot.freeze_on_hit = false # Deterministically isolate the guaranteed slow.
	check(unit._slow_remaining == 0 and unit.health == 1000, "ice control is delayed until icicle impact")
	shot._process(0.1)
	check(unit.health == 1000 and shot.position != shot.origin, "icicle visibly travels before hitting")
	shot._process(0.2)
	check(unit.health == 1000 - ice.damage() and is_equal_approx(unit._slow_factor, 0.65) and unit._slow_remaining == 2, "ice deals one hit and applies 35 percent slow for two seconds")
	var board_start := game.board.cell_to_pixel(GameConfig.SPAWN)
	unit.position = board_start
	unit.apply_freeze(0.5)
	unit._process(1.0)
	check(is_equal_approx(unit.position.distance_to(board_start), unit.speed * 0.5 * 0.65) and unit._freeze_remaining == 0, "partial-frame freeze preserves slow and moves only for unfrozen time")
	check(game.board.path_is_valid(game.board.find_path(unit.get_committed_cell()), unit.get_committed_cell()), "freezing never changes waypoint safety")
	var committed := unit.get_committed_cell()
	check(not game.purchase_tower(committed), "frozen/slow enemies retain committed-cell placement protection")
	unit.apply_freeze(NAN)
	unit.apply_freeze(-2)
	check(unit._freeze_remaining == 0, "invalid freeze duration cannot poison movement")
	unit.apply_freeze(100)
	check(unit._freeze_remaining == 1.5, "freeze duration is bounded")
	var frozen := enemy(game, ice.position + Vector2(40, 0))
	ice.attack(frozen)
	shot = projectile(game)
	shot.freeze_on_hit = true # Control fixture tests the successful random branch.
	shot._process(1.0)
	check(frozen._freeze_remaining == shot.freeze_duration, "successful freeze roll applies bounded hard freeze at impact")
	var rolls := 0
	ice._rng.seed = 9811
	for i in range(1000):
		ice.attack(frozen)
		var sample := projectile(game)
		rolls += 1 if sample.freeze_on_hit else 0
		sample.free()
	check(rolls > 40 and rolls < 130 and is_equal_approx(ice.freeze_chance(), 0.08), "seeded 8 percent freeze chance stays small")
	game.progression.unlocked.erase("ice_freeze")
	ice.configure_progression(game.progression)
	check(ice.freeze_chance() == 0 and not ice.apply_upgrade(Tower.Upgrade.SPECIAL), "freeze ability and category are locked without research")
	ice.attack(frozen)
	shot = projectile(game)
	frozen.free()
	shot._process(0.01)
	check(shot.is_queued_for_deletion(), "icicle safely disposes if target has been freed")
	game.free()


func _test_cannon() -> void:
	var game := fixture()
	var cannon := build(game, Tower.Kind.CANNON, Vector2i(5, 10))
	var origin := cannon.position
	var first := enemy(game, origin + Vector2(40, 0))
	var second := enemy(game, origin + Vector2(70, 0))
	var beyond := enemy(game, origin + Vector2(200, 0))
	var blocker := build(game, Tower.Kind.BASIC, Vector2i(9, 10))
	cannon.attack(first)
	var shot := projectile(game)
	shot._process(1.0) # A single step passes all targets and the blocking tower.
	check(first.health == 1000 - cannon.damage() and second.health == 1000 - cannon.damage(), "swept cannon collision pierces multiple enemies before the first tower")
	check(beyond.health == 1000 and shot._impact and is_equal_approx(shot.position.x, blocker.position.x - 20), "ball stops at tower and cannot damage enemies behind it in same large frame")
	shot._process(0.1)
	check(first.health == 1000 - cannon.damage(), "impact cannot hit a pierced enemy a second time")
	game.select_placed_tower(blocker)
	game.remove_selected_tower()
	first.health = 1000
	second.health = 1000
	cannon.attack(first)
	shot = projectile(game)
	shot._process(0.15)
	shot._process(0.15)
	check(first.health == 1000 - cannon.damage() and second.health == 1000 - cannon.damage(), "multi-frame flight never damages a previously pierced enemy twice")
	shot._process(1.0)
	check(beyond.health == 1000 - cannon.damage(), "removed tower no longer blocks a ball")
	shot._process(2.0)
	check(shot.is_queued_for_deletion(), "ball expires at finite travel budget")
	check(cannon.cannon_distance() == 480, "rifled-bore research extends travel fifty percent")
	game.progression.unlocked.erase("cannon_distance")
	cannon.configure_progression(game.progression)
	check(cannon.cannon_distance() == 320, "base cannon distance is independent of targeting range")
	# New construction in a ball's path must block it immediately.
	first.health = 1000
	cannon.attack(first)
	shot = projectile(game)
	shot._process(0.1)
	blocker = build(game, Tower.Kind.ICE, Vector2i(8, 10))
	shot._process(1.0)
	check(shot._impact and is_equal_approx(shot.position.x, blocker.position.x - 20), "a tower built during flight blocks an existing cannonball")
	check(is_equal_approx(CombatProjectile.rect_fraction(Vector2(0, 0), Vector2(100, 0), Rect2(30, -10, 20, 20)), 0.3), "axis-aligned sweep computes first wall fraction")
	check(is_equal_approx(CombatProjectile.rect_fraction(Vector2(100, 0), Vector2(0, 0), Rect2(30, -10, 20, 20)), 0.5), "reverse sweep computes first wall fraction")
	check(not is_finite(CombatProjectile.rect_fraction(Vector2.ZERO, Vector2(100, 0), Rect2(30, 20, 20, 20))), "parallel sweep ignores walls off its path")
	game.free()


func _test_cleanup() -> void:
	var game := fixture()
	var mortar := build(game, Tower.Kind.MORTAR, Vector2i(10, 10))
	var target := enemy(game, mortar.position + Vector2(120, 0))
	mortar.attack(target)
	var shot := projectile(game)
	var damage := shot.health_damage
	mortar.apply_upgrade(Tower.Upgrade.DAMAGE)
	check(shot.health_damage == damage and mortar.damage() > damage, "in-flight damage is a purchase-time snapshot")
	game.select_placed_tower(mortar)
	game.remove_selected_tower()
	shot._process(2)
	check(target.health == 1000 - damage, "a fired shell survives selling its source without dangling references")
	game._finish(TDGame.Phase.DEFEAT)
	check(shot.is_queued_for_deletion(), "defeat disposes all flight and impact effects")
	game.free()
	await process_frame
	check(get_nodes_in_group("projectiles").is_empty(), "freeing a run releases projectile group nodes")
	game = fixture()
	for cycle in range(80):
		var unit := enemy(game, Vector2(400, 400))
		var p := CombatProjectile.new()
		p.board = game.board
		p.kind = CombatProjectile.Kind.MORTAR
		p.position = Vector2(200, 400)
		p.origin = p.position
		p.destination = unit.position
		p.health_damage = 1000
		game.board.get_node("Projectiles").add_child(p)
		p._process(2.0)
		p._process(0.5)
		await process_frame
		check(game.board.get_node("Projectiles").get_child_count() == 0 and game.board.active_enemies().is_empty(), "repeated blast lifecycle releases all actors: %d" % cycle)
	game.free()
	await process_frame


func _test_production_wave_cleanup() -> void:
	var game := fixture()
	var mortar := build(game, Tower.Kind.MORTAR, Vector2i(0, 11))
	var ice := build(game, Tower.Kind.ICE, Vector2i(2, 11))
	var cannon := build(game, Tower.Kind.CANNON, Vector2i(4, 11))
	game.start_wave()
	game.waves._process(0.01)
	var unit := game.board.active_enemies()[0] as Enemy
	for tower in [mortar, ice, cannon]:
		tower.attack(unit)
	var shots := game.board.get_node("Projectiles").get_children()
	check(shots.size() == 3, "all three projectile types launch against production-spawned enemies")
	game.process_mode = Node.PROCESS_MODE_INHERIT
	game._on_restart_prompt_changed(true)
	await process_frame
	await process_frame
	var paused := true
	for shot in shots:
		paused = paused and (shot as CombatProjectile)._age == 0 and not shot.can_process()
	check(paused, "restart confirmation pauses all three projectile types")
	game._on_restart_prompt_changed(false)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.waves._process(1000)
	for actor in game.board.active_enemies():
		for layer in range(3):
			(actor as Enemy).take_damage(9999999)
	check(game.phase == TDGame.Phase.BETWEEN_WAVES and game.progression.diamonds == 1, "production wave resolves once with projectiles in flight")
	var discarded := true
	for shot in shots:
		discarded = discarded and shot.is_queued_for_deletion()
	check(discarded, "wave completion cancels every in-flight payload before the next wave")
	await process_frame
	check(game.board.get_node("Projectiles").get_child_count() == 0 and get_nodes_in_group("projectiles").is_empty(), "wave boundary releases projectile nodes and groups")
	game.close_skill_tree()
	game.start_wave()
	check(game.waves.current_wave == 2 and game.waves.remaining_to_spawn == game.waves.wave_size, "next wave begins with its own complete spawn plan")
	game.free()
	await process_frame


func _run() -> void:
	_test_unlocks_and_mixing()
	_test_mortar()
	_test_ice_and_freeze()
	_test_cannon()
	await _test_cleanup()
	await _test_production_wave_cleanup()
	print("New towers/projectiles/mixed upgrades: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
