class_name Board
extends Node2D
## Sole owner of grid coordinates, occupancy, placement validation, and A*.

signal navigation_changed(revision: int)

var revision := 0
var _astar := AStarGrid2D.new()
var _building := false
var _currency := 0
var _hover_cell := Vector2i(-1, -1)
var _hover_error := ""
var _hover_revision := -1


func _init(fixture_solids: Array[Vector2i] = []) -> void:
	_astar.region = Rect2i(Vector2i.ZERO, GameConfig.GRID_SIZE)
	_astar.cell_size = Vector2.ONE * GameConfig.CELL_SIZE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	_astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	_astar.update() # Initialization only: update() would erase existing solidity.
	for cell in fixture_solids:
		_astar.set_point_solid(cell, true)


func is_inside(cell: Vector2i) -> bool:
	return _astar.region.has_point(cell)


func is_blocked(cell: Vector2i) -> bool:
	return is_inside(cell) and _astar.is_point_solid(cell)


func find_path(from_cell: Vector2i = GameConfig.SPAWN) -> Array[Vector2i]:
	if not is_inside(from_cell) or is_blocked(from_cell):
		return []
	return _astar.get_id_path(from_cell, GameConfig.EXIT)


func path_is_valid(path: Array[Vector2i], from_cell: Vector2i) -> bool:
	if path.is_empty() or path[0] != from_cell or path[-1] != GameConfig.EXIT:
		return false
	for i in range(path.size()):
		if not is_inside(path[i]) or is_blocked(path[i]):
			return false
		if i > 0:
			var step := path[i] - path[i - 1]
			if absi(step.x) + absi(step.y) != 1:
				return false
	return true


func active_enemies() -> Array[Node]:
	var result: Array[Node] = []
	var container := get_node_or_null("Enemies")
	if container != null:
		for enemy in container.get_children():
			if enemy.has_method("is_alive") and enemy.call("is_alive"):
				result.append(enemy)
	return result


func placement_error(cell: Vector2i, currency: int) -> String:
	return _test_placement(cell, currency, false)


func try_block_cell(cell: Vector2i, currency: int) -> String:
	# Leaves occupancy provisional; Main confirms only after instantiation succeeds.
	return _test_placement(cell, currency, true)


func rollback_placement(cell: Vector2i) -> void:
	_astar.set_point_solid(cell, false)


func confirm_placement() -> void:
	revision += 1
	navigation_changed.emit(revision)
	queue_redraw()


func _test_placement(cell: Vector2i, currency: int, retain: bool) -> String:
	if not is_inside(cell):
		return "Outside the board"
	if cell == GameConfig.SPAWN or cell == GameConfig.EXIT:
		return "Entrance and exit are reserved"
	if is_blocked(cell):
		return "Occupied tile"
	if currency < GameConfig.TOWER_COST:
		return "Insufficient currency"
	var enemies := active_enemies()
	for enemy in enemies:
		if cell == Vector2i(enemy.call("get_current_cell")) or cell == Vector2i(enemy.call("get_committed_cell")):
			return "An enemy is using this tile"
	_astar.set_point_solid(cell, true)
	var error := ""
	if not path_is_valid(find_path(), GameConfig.SPAWN):
		error = "Cannot block the last route"
	else:
		for enemy in enemies:
			var waypoint := Vector2i(enemy.call("get_committed_cell"))
			if not path_is_valid(find_path(waypoint), waypoint):
				error = "Cannot trap an active enemy"
				break
	if not retain or not error.is_empty():
		_astar.set_point_solid(cell, false)
	return error


func set_build_preview(building: bool, currency: int) -> void:
	_building = building
	_currency = currency
	_hover_revision = -1
	queue_redraw()


func _process(_delta: float) -> void:
	if not _building:
		return
	var mouse := get_local_mouse_position()
	var cell := pixel_to_cell(mouse) if contains_pixel(mouse) else Vector2i(-1, -1)
	if cell != _hover_cell or _hover_revision != revision:
		_hover_cell = cell
		_hover_revision = revision
		_hover_error = placement_error(cell, _currency)
		queue_redraw()


func cell_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell * GameConfig.CELL_SIZE) + Vector2.ONE * GameConfig.CELL_SIZE * 0.5


func pixel_to_cell(pixel: Vector2) -> Vector2i:
	return Vector2i(floori(pixel.x / GameConfig.CELL_SIZE), floori(pixel.y / GameConfig.CELL_SIZE))


func contains_pixel(pixel: Vector2) -> bool:
	return Rect2(Vector2.ZERO, GameConfig.BOARD_SIZE).has_point(pixel)


func _draw() -> void:
	for y in range(GameConfig.GRID_SIZE.y):
		for x in range(GameConfig.GRID_SIZE.x):
			var color := Color("243c32") if (x + y) % 2 == 0 else Color("284237")
			draw_rect(Rect2(Vector2(x, y) * GameConfig.CELL_SIZE, Vector2.ONE * GameConfig.CELL_SIZE), color)
	for x in range(GameConfig.GRID_SIZE.x + 1):
		draw_line(Vector2(x * GameConfig.CELL_SIZE, 0), Vector2(x * GameConfig.CELL_SIZE, GameConfig.BOARD_SIZE.y), Color("334d40"))
	for y in range(GameConfig.GRID_SIZE.y + 1):
		draw_line(Vector2(0, y * GameConfig.CELL_SIZE), Vector2(GameConfig.BOARD_SIZE.x, y * GameConfig.CELL_SIZE), Color("334d40"))
	draw_rect(Rect2(cell_to_pixel(GameConfig.SPAWN) - Vector2(15, 15), Vector2(30, 30)), Color("58db83"))
	draw_rect(Rect2(cell_to_pixel(GameConfig.EXIT) - Vector2(15, 15), Vector2(30, 30)), Color("f17c52"))

	if _building and is_inside(_hover_cell):
		var tint := Color(0.3, 1.0, 0.55, 0.35) if _hover_error.is_empty() else Color(1.0, 0.2, 0.2, 0.45)
		var tile := Rect2(cell_to_pixel(_hover_cell) - Vector2(16, 16), Vector2(32, 32))
		draw_rect(tile, tint)
		draw_rect(tile.grow(-1), Color(tint, 0.95), false, 2.0)
		draw_arc(cell_to_pixel(_hover_cell), GameConfig.TOWER_RANGE, 0, TAU, 64, Color(tint, 0.5), 1.0)
