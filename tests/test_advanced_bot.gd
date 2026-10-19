extends SceneTree

const Bot = preload("res://tests/advanced_bot.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)

func fixture() -> TDGame:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	return game

func _run() -> void:
	for name in Bot.VARIANTS:
		var game := fixture()
		var bot := Bot.new(name)
		bot.prepare(game)
		check(bot.error.is_empty(), "starting strategy succeeds: " + name)
		check(game.currency >= 0 and game.currency <= 200 and game.progression.unlocked.is_empty(), "fresh strategy receives no free resources or unlocks: " + name)
		check(game.board.find_path().size() > 40 and game.board.path_is_valid(game.board.find_path(), GameConfig.SPAWN), "opening extends the enemy path safely: " + name)
		# Funded geometry fixture is separate from natural survival experiments.
		game.currency = 100000
		bot.prepare(game)
		check(bot.error.is_empty() and bot.gaps.size() > 10, "complete maze rejects sealing candidates: " + name)
		check(game.board.path_is_valid(game.board.find_path(), GameConfig.SPAWN), "completed geometry retains escape route: " + name)
		if int(bot.traits.spacing) == 2:
			check(game.board.find_path().size() == 476 and game.board.get_node("Towers").get_child_count() == 426, "tight spacing reaches the measured maximal template")
		else:
			check(game.board.find_path().size() > 250, "wide spacing still creates substantial path length")
		game.free()
	var game := fixture()
	game.progression.diamonds = 3
	var bot := Bot.new("hybrid")
	bot.research(game)
	check(game.progression.diamonds == 0 and game.progression.unlocked == ["tesla"], "research spends exactly earned diamond budget")
	bot.research(game)
	check(game.progression.diamonds == 0 and game.progression.unlocked == ["tesla"], "research cannot duplicate owned skills")
	game.free()
	game = fixture()
	game.progression.unlocked.assign(SkillCatalog.IDS) # Isolated role/geometry fixture.
	game.currency = 10000
	bot = Bot.new("hybrid")
	bot.prepare(game)
	check(bot.error.is_empty(), "expert-profile fixture builds a legal functional maze")
	game.currency = 2000
	bot.prepare(game)
	var cannon := game.tower_at_cell(Vector2i(0, 11))
	check(cannon != null and cannon.kind == Tower.Kind.CANNON, "cannon replaces entrance cap to face an unobstructed long corridor")
	var counts: Array[int] = [0, 0, 0, 0, 0]
	var controllers: Array[Tower] = []
	var upgraded := 0
	for child in game.board.get_node("Towers").get_children():
		var tower := child as Tower
		counts[tower.kind] += 1
		upgraded += tower.upgrade_level
		if tower.kind == Tower.Kind.ICE:
			for existing in controllers:
				check(tower.position.distance_squared_to(existing.position) >= 180.0 * 180.0, "control towers avoid redundant overlapping positions")
			controllers.append(tower)
	check(counts[1] > 0 and counts[2] > 0 and counts[3] > 0 and counts[4] == 1 and upgraded > 0, "hybrid combines rings, siege, control, cannon lane and upgrades")
	for y in [13, 18]:
		var unit := Enemy.new()
		game.board.get_node("Enemies").add_child(unit)
		unit.setup(game.board, 10000)
		unit.position = game.board.cell_to_pixel(Vector2i(0, y))
	cannon.attack(game.board.active_enemies()[0] as Enemy)
	var payload := game.board.get_node("Projectiles").get_child(-1) as CombatProjectile
	payload._process(1)
	var hit_both := true
	for unit in game.board.active_enemies():
		hit_both = hit_both and (unit as Enemy).health == 10000 - cannon.damage()
	check(hit_both, "functional cannon placement actually pierces both enemies without a friendly wall collision")
	game.free()
	print("Advanced bot: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
