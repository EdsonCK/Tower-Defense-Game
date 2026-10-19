extends SceneTree
## Standalone, nonzero-exit tests using the production Board and AStarGrid2D.

var checks := 0
var failures := 0


class MockEnemy extends Node2D:
	var current := Vector2i(22, 12)
	var committed := Vector2i(23, 12)

	func is_alive() -> bool:
		return true

	func get_current_cell() -> Vector2i:
		return current

	func get_committed_cell() -> Vector2i:
		return committed


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func _run() -> void:
	var board := Board.new()
	root.add_child(board)
	check(board.find_path().size() == 40, "empty board has 40-cell shortest path")
	check(board.path_is_valid(board.find_path(), GameConfig.SPAWN), "empty path has valid endpoints and only cardinal steps")
	check(board.try_block_cell(Vector2i(20, 12), 200).is_empty(), "block natural route with alternative available")
	board.confirm_placement()
	check(board.is_blocked(Vector2i(20, 12)), "accepted occupancy retained")
	check(board.path_is_valid(board.find_path(), GameConfig.SPAWN), "reroute avoids solid cells and diagonals")
	check(not board.find_path().has(Vector2i(20, 12)), "solid cell absent from path")
	for cell in [GameConfig.SPAWN, GameConfig.EXIT, Vector2i(-1, 0), Vector2i(40, 0), Vector2i(0, -1), Vector2i(0, 24), Vector2i(20, 12)]:
		check(not board.try_block_cell(cell, 200).is_empty(), "reserved/occupied/outside rejected: %s" % cell)
	check(not board.try_block_cell(Vector2i(3, 3), 59).is_empty(), "unaffordable rejected")
	check(not board.is_blocked(Vector2i(3, 3)), "unaffordable leaves occupancy unchanged")
	for cell in [Vector2i(0, 0), Vector2i(39, 0), Vector2i(0, 23), Vector2i(39, 23)]:
		check(board.pixel_to_cell(board.cell_to_pixel(cell)) == cell, "coordinate roundtrip %s" % cell)
	check(board.contains_pixel(Vector2.ZERO) and board.contains_pixel(Vector2(1279.99, 767.99)), "inside inclusive top/left and just inside bottom/right")
	check(not board.contains_pixel(Vector2(1280, 20)) and not board.contains_pixel(Vector2(20, 768)) and not board.contains_pixel(Vector2(-0.01, 20)), "outside boundaries do not map to board clicks")
	board.free()

	var wall: Array[Vector2i] = []
	for y in range(24):
		if y != 12:
			wall.append(Vector2i(20, y))
	board = Board.new(wall)
	root.add_child(board)
	check(board.path_is_valid(board.find_path(), GameConfig.SPAWN), "wall's single gap is navigable")
	var previous_path := board.find_path()
	check(not board.try_block_cell(Vector2i(20, 12), 200).is_empty(), "closing last gap rejected")
	check(not board.is_blocked(Vector2i(20, 12)), "last-gap solidity restored")
	check(board.find_path() == previous_path and board.revision == 0, "rejection preserves route and revision")
	check(board.is_blocked(Vector2i(20, 0)), "existing wall solidity retained")
	board.free()

	# Pocket east of column 21, connected only through (24,12).
	# Spawn remains connected to exit by row 12 and outside the pocket.
	var pocket: Array[Vector2i] = [Vector2i(21, 11), Vector2i(22, 11), Vector2i(23, 11), Vector2i(24, 11), Vector2i(21, 12), Vector2i(21, 13), Vector2i(22, 13), Vector2i(23, 13), Vector2i(24, 13)]
	board = Board.new(pocket)
	var enemies := Node2D.new()
	enemies.name = "Enemies"
	board.add_child(enemies)
	var enemy := MockEnemy.new()
	enemies.add_child(enemy)
	root.add_child(board)
	check(not board.try_block_cell(enemy.current, 200).is_empty(), "current cell protected")
	check(not board.try_block_cell(enemy.committed, 200).is_empty(), "committed next waypoint protected")
	check(board.placement_error(Vector2i(24, 12), 200) == "Cannot trap an active enemy", "enemy-only trap rejected while spawn still routes")
	check(not board.is_blocked(Vector2i(24, 12)), "enemy trap preview restores occupancy")
	check(not board.try_block_cell(Vector2i(24, 12), 200).is_empty(), "enemy trap transaction rejected")
	check(board.path_is_valid(board.find_path(), GameConfig.SPAWN), "spawn still has route after enemy-only rejection")
	check(board.path_is_valid(board.find_path(enemy.committed), enemy.committed), "enemy still has route after rejection")
	board.free()
	print("Pathfinding: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
