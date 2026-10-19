extends SceneTree

var checks := 0
var failures := 0
var exits := 0
var deaths := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func make_enemy(board: Board) -> Enemy:
	var enemy := preload("res://scenes/enemy.tscn").instantiate() as Enemy
	board.get_node("Enemies").add_child(enemy)
	enemy.setup(board, 45)
	enemy.set_process(false)
	enemy.reached_exit.connect(func(_enemy: Enemy) -> void: exits += 1)
	enemy.died.connect(func(_enemy: Enemy) -> void: deaths += 1)
	return enemy


func _run() -> void:
	var board := Board.new()
	var container := Node2D.new()
	container.name = "Enemies"
	board.add_child(container)
	root.add_child(board)
	var enemy := make_enemy(board)
	check(enemy.is_in_group("enemies"), "enemy group membership")
	enemy._process(0.25)
	check(enemy.position == board.cell_to_pixel(GameConfig.SPAWN) + Vector2(15, 0), "60 pixels/sec movement between centers")
	check(enemy.get_current_cell() == GameConfig.SPAWN and enemy.get_committed_cell() == Vector2i(1, 12), "in-flight segment endpoints exposed")
	check(not board.try_block_cell(Vector2i(1, 12), 200).is_empty(), "in-flight next center protected")
	var before := enemy.position
	check(board.try_block_cell(Vector2i(2, 12), 200).is_empty(), "future route tile may be blocked with escape")
	board.confirm_placement()
	check(enemy.position == before and enemy.get_committed_cell() == Vector2i(1, 12), "navigation revision preserves position and current segment")
	enemy._process(17.0 / 60.0)
	check(enemy.position == board.cell_to_pixel(Vector2i(1, 12)), "finishes old segment at next center")
	check(not board.try_block_cell(Vector2i(1, 12), 200).is_empty(), "enemy at a cell center protects that cell")
	enemy._process(0.1)
	check(enemy.get_current_cell() == Vector2i(1, 12) and enemy.get_committed_cell() != Vector2i(2, 12), "reroutes at center, avoids newly blocked future tile")
	before = enemy.position
	var committed := enemy.get_committed_cell()
	check(board.try_block_cell(Vector2i(3, 12), 200).is_empty(), "another placement succeeds during rerouted segment")
	board.confirm_placement()
	check(enemy.position == before and enemy.get_committed_cell() == committed, "multiple revisions preserve in-flight segment")
	var last := enemy.position
	var movement_safe := true
	for i in range(5000):
		if not enemy.is_alive():
			break
		enemy._process(0.025)
		var change := enemy.position - last
		if change.length() > GameConfig.ENEMY_SPEED * 0.025 + 0.001 or board.is_blocked(board.pixel_to_cell(enemy.position)):
			movement_safe = false
		last = enemy.position
	check(movement_safe, "entire rerouted journey has no teleport or blocked cell crossing")
	check(exits == 1 and deaths == 0 and not enemy.is_alive(), "exit resolved exactly once")
	enemy._process(100)
	enemy.take_damage(1000)
	check(exits == 1 and deaths == 0, "escaped enemy cannot die or exit again")
	var killed := make_enemy(board)
	killed.take_damage(45)
	killed.take_damage(45)
	killed._process(100)
	check(deaths == 1 and exits == 1 and not killed.is_alive(), "killed enemy resolves only once")
	board.free()
	print("Movement: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
