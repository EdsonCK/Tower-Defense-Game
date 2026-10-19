class_name Enemy
extends Node2D
## Walks cell center to cell center (cardinal only) toward the exit at constant speed.
## Emits `died` or `reached_exit` exactly once, then frees itself.
## Route changes are applied only on arriving at a cell center, so the current
## segment always finishes and the enemy never teleports.

signal died(enemy: Enemy)
signal reached_exit(enemy: Enemy)

const RADIUS: float = 10.0
const COLOR_BODY: Color = Color(0.9, 0.2, 0.2)
const COLOR_OUTLINE: Color = Color(0.35, 0.05, 0.05)
const HEALTH_BAR_SIZE: Vector2 = Vector2(24, 4)

var max_health: int = 1
var health: int = 1
var speed: float = GameConfig.ENEMY_SPEED
## Cell whose center the enemy most recently reached (or is standing on).
var current_cell: Vector2i = GameConfig.SPAWN_CELL
## Cell whose center the enemy is walking toward; equals current_cell while not moving.
var next_cell: Vector2i = GameConfig.SPAWN_CELL

var _board: Board
var _path: Array[Vector2i] = []
var _path_index: int = 0  # index in _path of the next cell to walk to
var _moving: bool = false
var _route_dirty: bool = true
var _resolved: bool = false
var _route_error_reported: bool = false


func setup(board: Board, enemy_health: int) -> void:
	_board = board
	max_health = enemy_health
	health = enemy_health
	current_cell = GameConfig.SPAWN_CELL
	next_cell = current_cell
	position = Board.cell_to_world(current_cell)
	add_to_group("enemies")
	_board.navigation_changed.connect(_on_navigation_changed)
	_plan_route()


func _process(delta: float) -> void:
	advance(delta)


## Moves the enemy by `delta` seconds of travel, crossing as many cell centers as needed.
func advance(delta: float) -> void:
	var remaining: float = speed * delta
	while remaining > 0.0 and not _resolved:
		if not _moving and not _start_next_segment():
			return
		var target: Vector2 = Board.cell_to_world(next_cell)
		var distance: float = position.distance_to(target)
		if distance <= remaining:
			position = target
			remaining -= distance
			_arrive_at(next_cell)
		else:
			position = position.move_toward(target, remaining)
			remaining = 0.0


func take_damage(amount: int) -> void:
	if _resolved:
		return
	health = maxi(health - amount, 0)
	queue_redraw()
	if health == 0:
		_resolve()
		died.emit(self)
		queue_free()


## True while the enemy is alive, unresolved and may be targeted or block placement.
func is_active() -> bool:
	return not _resolved and not is_queued_for_deletion()


func is_moving() -> bool:
	return _moving


## Cells that must not be built on: the current cell and, while moving, the committed next cell.
func get_occupied_cells() -> Array[Vector2i]:
	if _moving:
		return [current_cell, next_cell]
	return [current_cell]


## The cell center from which this enemy will next choose a route.
func get_committed_waypoint() -> Vector2i:
	return next_cell if _moving else current_cell


## Removes the enemy without emitting died/reached_exit (used by Restart).
func discard() -> void:
	_resolve()
	queue_free()


func _start_next_segment() -> bool:
	if _route_dirty or _path_index >= _path.size():
		if not _plan_route():
			return false
	var candidate: Vector2i = _path[_path_index]
	if _board.is_solid(candidate):
		# Should be impossible given placement validation; replan rather than walk into a tower.
		if not _plan_route():
			return false
		candidate = _path[_path_index]
	next_cell = candidate
	_path_index += 1
	_moving = true
	return true


func _arrive_at(cell: Vector2i) -> void:
	current_cell = cell
	next_cell = cell
	_moving = false
	if cell == GameConfig.EXIT_CELL:
		_resolve()
		reached_exit.emit(self)
		queue_free()


func _plan_route() -> bool:
	var path: Array[Vector2i] = _board.find_path(current_cell, GameConfig.EXIT_CELL)
	if not _board.is_valid_route(path, current_cell, GameConfig.EXIT_CELL) or path.size() < 2:
		if not _route_error_reported and current_cell != GameConfig.EXIT_CELL:
			push_error("Enemy at cell %s has no route to the exit; waiting in place." % current_cell)
			_route_error_reported = true
		return false
	_path = path
	_path_index = 1
	_route_dirty = false
	_route_error_reported = false
	return true


func _on_navigation_changed(_revision: int) -> void:
	_route_dirty = true


func _resolve() -> void:
	_resolved = true
	_moving = false
	remove_from_group("enemies")


func _draw() -> void:
	var diamond: PackedVector2Array = PackedVector2Array([
		Vector2(0, -RADIUS), Vector2(RADIUS, 0), Vector2(0, RADIUS), Vector2(-RADIUS, 0),
	])
	draw_colored_polygon(diamond, COLOR_BODY)
	diamond.append(diamond[0])
	draw_polyline(diamond, COLOR_OUTLINE, 1.5)
	var bar_origin: Vector2 = Vector2(-HEALTH_BAR_SIZE.x / 2.0, -RADIUS - 8.0)
	draw_rect(Rect2(bar_origin, HEALTH_BAR_SIZE), Color(0.1, 0.1, 0.1))
	var ratio: float = float(health) / float(max_health) if max_health > 0 else 0.0
	draw_rect(Rect2(bar_origin, Vector2(HEALTH_BAR_SIZE.x * ratio, HEALTH_BAR_SIZE.y)), Color(0.3, 0.95, 0.3))
