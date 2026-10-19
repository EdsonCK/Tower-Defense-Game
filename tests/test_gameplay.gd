extends SceneTree
## Gameplay integration tests, without an external framework.

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
	var game := load("res://scenes/main.tscn").instantiate() as TDGame
	root.add_child(game)
	game.set_process_input(false)
	game.set_process_unhandled_input(false)
	game.select_tower()
	check(game.purchase_tower(Vector2i(20, 12)), "successful purchase")
	check(game.currency == 140 and game.building, "deduct exactly 60, retain build selection")
	check(game.board.get_node("Towers").get_child_count() == 1, "exactly one tower created")
	var revision := game.board.revision
	var path := game.board.find_path()
	for cell in [Vector2i(20, 12), GameConfig.SPAWN, GameConfig.EXIT, Vector2i(40, 0)]:
		check(not game.purchase_tower(cell), "invalid purchase rejected: %s" % cell)
	check(game.currency == 140 and game.board.revision == revision and game.board.find_path() == path, "invalid purchases preserve currency, revision, and route")
	var saved_scene := game.tower_scene
	game.tower_scene = null
	check(not game.purchase_tower(Vector2i(5, 5)), "failed instantiation rejected")
	check(game.currency == 140 and not game.board.is_blocked(Vector2i(5, 5)) and game.board.revision == revision, "failed instantiation rolls back occupancy, revision, and currency")
	game.tower_scene = saved_scene
	check(game.purchase_tower(Vector2i(21, 12)) and game.purchase_tower(Vector2i(22, 12)), "three starting towers affordable")
	check(game.currency == 20 and not game.building, "stop build mode below tower cost")
	check(not game.purchase_tower(Vector2i(23, 12)) and not game.board.is_blocked(Vector2i(23, 12)), "unaffordable placement changes nothing")
	game.free()
	print("Gameplay: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
