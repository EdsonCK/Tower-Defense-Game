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


func _run() -> void:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	game.progression.unlocked.assign(["tesla", "basic_training", "tesla_training", "piercing", "static_field"])
	game.progression.unlocked.erase("engineering") # Isolate unique-track combat from the passive damage bonus.
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.currency = 10000 # Combat fixture; balance bots use only earned gold.
	game.select_tower(Tower.Kind.TESLA)
	game.purchase_tower(Vector2i(10, 10))
	var tower := game.tower_at_cell(Vector2i(10, 10))
	var targets: Array[Enemy] = []
	for distance in [30.0, -60.0, 80.0, 80.1]:
		var enemy := preload("res://scenes/enemy.tscn").instantiate() as Enemy
		game.board.get_node("Enemies").add_child(enemy)
		enemy.setup(game.board, 200)
		enemy.position = tower.position + Vector2(distance, 0)
		targets.append(enemy)
	tower._process(0.001)
	check(targets[0].health == 188 and targets[1].health == 188 and targets[2].health == 188, "one pulse hits all living enemies within range exactly once")
	check(targets[3].health == 200, "pulse excludes enemies outside the small range")
	tower._process(0.5)
	check(targets[0].health == 188, "Tesla obeys its own cooldown")
	tower._process(0.601)
	check(targets[0].health == 176 and targets[1].health == 176, "next pulse damages all targets again")
	game.free()
	game = preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	game.progression.unlocked.assign(["tesla", "basic_training", "tesla_training", "piercing", "static_field"])
	game.progression.unlocked.erase("engineering") # Isolate unique-track combat from the passive damage bonus.
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.currency = 10000
	game.select_tower(Tower.Kind.TESLA)
	game.purchase_tower(Vector2i(1, 11))
	tower = game.tower_at_cell(Vector2i(1, 11))
	game.select_placed_tower(tower)
	check(game.upgrade_selected_tower(Tower.Upgrade.SPECIAL), "Static Field track requires and uses its own skill unlock")
	check(game.upgrade_selected_tower(Tower.Upgrade.RANGE) and tower.levels(Tower.Upgrade.SPECIAL) == 1 and tower.levels(Tower.Upgrade.RANGE) == 1, "unique and range purchases can share the same tower")
	var slowed := preload("res://scenes/enemy.tscn").instantiate() as Enemy
	game.board.get_node("Enemies").add_child(slowed)
	slowed.setup(game.board, 200)
	tower._process(0.001)
	var before := slowed.position
	slowed._process(1.0)
	check(is_equal_approx(slowed.position.distance_to(before), 50.4), "Static Field slows for 0.8s then movement returns to normal within the frame")
	game.select_tower(Tower.Kind.BASIC)
	game.purchase_tower(Vector2i(4, 11))
	var basic := game.tower_at_cell(Vector2i(4, 11))
	game.select_placed_tower(basic)
	check(game.upgrade_selected_tower(Tower.Upgrade.SPECIAL), "Piercing Rounds is available separately for basic towers")
	var armored := preload("res://scenes/enemy.tscn").instantiate() as Enemy
	game.board.get_node("Enemies").add_child(armored)
	armored.setup_profile(game.board, EnemyProfile.base(EnemyProfile.Kind.ARMORED))
	armored.position = basic.position + Vector2(30, 0)
	basic.attack(armored)
	check(armored.health == 105 and armored.armor == 0, "level-one piercing shot depletes 45 plating without health spill")
	game.free()
	print("Tesla/unique upgrades: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
