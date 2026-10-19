extends SceneTree

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func make_game() -> TDGame:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	game.progression.unlocked.assign(["tesla", "basic_training"])
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	return game


func _run() -> void:
	for track in [Tower.Upgrade.DAMAGE, Tower.Upgrade.RANGE, Tower.Upgrade.SPEED]:
		var game := make_game()
		check(not game.upgrade_selected_tower(track) and not game.remove_selected_tower(), "no selection means no mutation")
		game.purchase_tower(Vector2i(4, 4))
		var tower := game.tower_at_cell(Vector2i(4, 4))
		game.select_placed_tower(tower)
		check(not game.upgrade_selected_tower(-1) and game.currency == 140, "invalid upgrade track cannot charge")
		check(game.upgrade_selected_tower(track) and game.currency == 80, "first upgrade costs 60")
		check(not game.upgrade_selected_tower(track) and tower.upgrade_level == 1 and game.currency == 80, "unaffordable upgrade has no side effects")
		var revision := game.board.revision
		for other in [Tower.Upgrade.DAMAGE, Tower.Upgrade.RANGE, Tower.Upgrade.SPEED]:
			if other != track:
				check(not game.upgrade_selected_tower(other) and tower.levels(other) == 0 and game.currency == 80, "unaffordable mixed purchase cannot mutate another category")
		# Dedicated economy fixture: fund the later levels explicitly.
		game.currency = 10000
		var expected := game.currency
		for level in range(1, GameConfig.MAX_UPGRADE_LEVEL):
			expected -= tower.next_upgrade_cost()
			check(game.upgrade_selected_tower(track) and game.currency == expected, "level %d charges its displayed cost" % (level + 1))
		check(not game.upgrade_selected_tower(track) and game.currency == expected and tower.upgrade_level == 5, "maximum level rejects further charges")
		check(game.board.revision == revision, "combat upgrades do not touch navigation")
		if track == Tower.Upgrade.DAMAGE:
			check(tower.damage() == 75 and tower.attack_range() == 112 and tower.attack_interval() == 0.8, "damage track changes damage alone")
		elif track == Tower.Upgrade.RANGE:
			check(tower.damage() == 15 and tower.attack_range() == 232 and tower.attack_interval() == 0.8, "range track changes range alone")
		else:
			check(tower.damage() == 15 and tower.attack_range() == 112 and is_equal_approx(tower.attack_interval(), 0.8 * pow(0.82, 5)), "speed track changes interval alone")
		var target := preload("res://scenes/enemy.tscn").instantiate() as Enemy
		game.board.get_node("Enemies").add_child(target)
		target.setup(game.board, 1000)
		target.position = tower.position + Vector2(200 if track == Tower.Upgrade.RANGE else 40, 0)
		tower._process(0.001)
		check(target.health == 1000 - tower.damage(), "upgraded damage/range is applied to a real shot")
		tower._process(0.4)
		check(target.health == 1000 - (30 if track == Tower.Upgrade.SPEED else tower.damage()), "only speed upgrade permits a second shot within 0.4s")
		check(game.remove_selected_tower() and game.currency == expected + 30, "removal refunds half construction, not upgrade spending")
		check(not game.board.is_blocked(Vector2i(4, 4)) and game.board.revision == revision + 1 and game.tower_at_cell(Vector2i(4, 4)) == null, "removal opens cell and deletes tower from ownership")
		check(not game.remove_selected_tower() and not game.upgrade_selected_tower(track) and game.currency == expected + 30, "repeated remove/upgrade cannot duplicate refund")
		check(game.purchase_tower(Vector2i(4, 4)) and game.tower_at_cell(Vector2i(4, 4)).upgrade_level == 0, "rebuild starts with an unlocked tower")
		game._finish(TDGame.Phase.DEFEAT)
		check(not game.remove_selected_tower() and not game.upgrade_selected_tower(track), "defeat disables tower management")
		game.free()

	var game := make_game()
	game.purchase_tower(Vector2i(2, 12))
	var enemy := preload("res://scenes/enemy.tscn").instantiate() as Enemy
	game.board.get_node("Enemies").add_child(enemy)
	enemy.setup(game.board, 10000)
	enemy.set_process(false)
	enemy._process(0.25)
	var before := enemy.position
	var committed := enemy.get_committed_cell()
	game.select_placed_tower(game.tower_at_cell(Vector2i(2, 12)))
	check(game.remove_selected_tower(), "remove during active movement")
	check(enemy.position == before and enemy.get_committed_cell() == committed, "removal preserves in-flight segment")
	check(game.board.path_is_valid(game.board.find_path(committed), committed), "removed tower leaves enemy route valid")
	check(game.purchase_tower(Vector2i(2, 12)), "rebuild while in flight preserves escape")
	check(not game.purchase_tower(committed), "removal/rebuild does not weaken committed-cell protection")
	game.free()
	await process_frame
	game = make_game()
	var resolved := preload("res://scenes/enemy.tscn").instantiate() as Enemy
	game.board.get_node("Enemies").add_child(resolved)
	resolved.setup(game.board, 45)
	resolved._process(32.0 / 60.0)
	var errors: Array[String] = []
	resolved.navigation_failed.connect(func(message: String) -> void: errors.append(message))
	resolved.take_damage(45)
	check(game.purchase_tower(Vector2i(1, 12)), "same-frame placement can use a resolved enemy's former cell")
	check(errors.is_empty(), "queued resolved enemies ignore navigation changes")
	game.free()
	await process_frame
	game = make_game()
	game.currency = 100000 # Soak fixture, not the natural-play balance test.
	var moving := preload("res://scenes/enemy.tscn").instantiate() as Enemy
	game.board.get_node("Enemies").add_child(moving)
	moving.setup(game.board, 10000)
	moving.set_process(false)
	for cycle in range(100):
		before = moving.position
		committed = moving.get_committed_cell()
		check(game.purchase_tower(Vector2i(20, 12)), "repeated build accepts escape-preserving cell")
		check(moving.position == before and moving.get_committed_cell() == committed, "repeated builds preserve current segment")
		game.select_placed_tower(game.tower_at_cell(Vector2i(20, 12)))
		check(game.remove_selected_tower(), "repeated removal succeeds once")
		moving._process(0.025)
		check(game.board.path_is_valid(game.board.find_path(moving.get_committed_cell()), moving.get_committed_cell()), "repeated revisions leave moving enemy routable")
		await process_frame
	check(game.currency == 97000 and game.board.get_node("Towers").get_child_count() == 0, "100 build/remove cycles cost exactly 30 each without retaining towers")
	game.free()
	await process_frame
	print("Tower management: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
