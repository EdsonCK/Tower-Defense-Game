extends SceneTree

var checks := 0
var failures := 0
var deaths := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func spawn(board: Board, kind: EnemyProfile.Kind) -> Enemy:
	var enemy := preload("res://scenes/enemy.tscn").instantiate() as Enemy
	board.get_node("Enemies").add_child(enemy)
	enemy.setup_profile(board, EnemyProfile.base(kind))
	enemy.set_process(false)
	enemy.died.connect(func(_enemy: Enemy) -> void: deaths += 1)
	return enemy


func _run() -> void:
	var board := Board.new()
	var container := Node2D.new()
	container.name = "Enemies"
	board.add_child(container)
	root.add_child(board)
	var speeds: Dictionary = {}
	var rewards: Dictionary = {}
	var colors: Dictionary = {}
	var health_values: Dictionary = {}
	for kind in range(5):
		var enemy := spawn(board, kind as EnemyProfile.Kind)
		var profile := EnemyProfile.base(kind as EnemyProfile.Kind)
		check(enemy.health == profile.hit_points and enemy.bounty == profile.bounty, "type %d applies health/reward" % kind)
		enemy._process(0.25)
		check(is_equal_approx(enemy.position.distance_to(board.cell_to_pixel(GameConfig.SPAWN)), profile.speed * 0.25), "type %d applies movement speed" % kind)
		speeds[enemy.speed] = true
		rewards[enemy.bounty] = true
		colors[enemy.body_color] = true
		health_values[enemy.max_health] = true
		enemy.free()
	check(speeds.size() == 5 and rewards.size() == 5 and colors.size() == 5 and health_values.size() == 5, "all five types have distinct appearance/stats/rewards")

	var armored := spawn(board, EnemyProfile.Kind.ARMORED)
	armored.take_damage(15)
	check(armored.health == 105 and armored.armor == 30, "armor pool absorbs a hit before health")
	armored.take_damage(1)
	check(armored.health == 105 and armored.armor == 29, "small hits deplete armor")
	armored.take_damage(0)
	armored.take_damage(-10)
	check(armored.health == 105 and armored.armor == 29, "nonpositive damage cannot heal or trigger traits")
	armored.free()

	var regenerator := spawn(board, EnemyProfile.Kind.REGENERATOR)
	regenerator.take_damage(15)
	regenerator._process(2.0)
	check(regenerator.health == 53, "regeneration waits two seconds after damage")
	regenerator._process(1.0)
	check(regenerator.health == 56, "regeneration heals three HP/sec")
	regenerator.take_damage(1)
	regenerator._process(1.0)
	check(regenerator.health == 55, "new hit resets regeneration delay")
	regenerator._process(10.0)
	check(regenerator.health == regenerator.max_health, "regeneration cannot exceed max HP")
	regenerator.take_damage(1000)
	regenerator._process(10.0)
	check(not regenerator.is_alive() and regenerator.health == 0 and deaths == 1, "dead regenerator cannot heal or resolve twice")
	regenerator.free()

	var shielded := spawn(board, EnemyProfile.Kind.SHIELDED)
	shielded.take_damage(15)
	check(shielded.health == 80 and shielded.shield == 15, "shield absorbs hits before HP")
	shielded.take_damage(25)
	check(shielded.health == 80 and shielded.shield == 0, "shield overkill never spills into health")
	shielded._process(5.0)
	check(shielded.shield == 0, "shield does not regenerate")
	shielded.take_damage(1000)
	shielded.take_damage(1000)
	check(deaths == 2 and not shielded.is_alive(), "shielded enemy dies once")
	board.free()
	print("Enemy traits: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
