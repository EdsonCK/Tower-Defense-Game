class_name Enemy
extends Node2D
## Maintains its current segment across revisions; replans only at cell centers.

signal died(enemy: Enemy)
signal reached_exit(enemy: Enemy)
signal navigation_failed(message: String)

var health := 0
var max_health := 0
var _alive := true
var _board: Board
var _current_cell := GameConfig.SPAWN
var _committed_cell := GameConfig.SPAWN
var _route: Array[Vector2i] = []
var _route_index := 0
var _route_revision := -1
var _route_dirty := true
var _navigation_error := false


func setup(board: Board, hit_points: int) -> void:
	_board = board
	health = hit_points
	max_health = hit_points
	position = _board.cell_to_pixel(_current_cell)
	_board.navigation_changed.connect(_on_navigation_changed)
	_plan_at_center()
	_board.invalidate_hover()


func _ready() -> void:
	add_to_group("enemies")


func is_alive() -> bool:
	return _alive and not is_queued_for_deletion()


func get_current_cell() -> Vector2i:
	return _current_cell


func get_committed_cell() -> Vector2i:
	return _committed_cell


func _on_navigation_changed(_revision: int) -> void:
	_route_dirty = true
	# At a center we can replan immediately. In flight, keep the segment intact.
	if _current_cell == _committed_cell:
		_plan_at_center()


func _plan_at_center() -> bool:
	_route = _board.find_path(_current_cell)
	_route_index = 0
	_route_revision = _board.revision
	_route_dirty = false
	if not _board.path_is_valid(_route, _current_cell):
		_report_navigation_error("No escape route from %s (board revision %d)" % [_current_cell, _route_revision])
		return false
	return true


func _process(delta: float) -> void:
	if not is_alive() or _board == null or _navigation_error:
		return
	var remaining := GameConfig.ENEMY_SPEED * delta
	while remaining > 0.0 and is_alive():
		if _current_cell == _committed_cell:
			if _current_cell == GameConfig.EXIT:
				_resolve(false)
				return
			if (_route_dirty or _route_revision != _board.revision) and not _plan_at_center():
				return
			if _route_index + 1 >= _route.size():
				_report_navigation_error("Route ended before exit at %s" % _current_cell)
				return
			var next := _route[_route_index + 1]
			var step := next - _current_cell
			if _board.is_blocked(next) or absi(step.x) + absi(step.y) != 1:
				_report_navigation_error("Unsafe movement segment %s -> %s" % [_current_cell, next])
				return
			_committed_cell = next
			_board.invalidate_hover()
		var target := _board.cell_to_pixel(_committed_cell)
		var distance := position.distance_to(target)
		if remaining < distance:
			position = position.move_toward(target, remaining)
			return
		position = target
		remaining -= distance
		_current_cell = _committed_cell
		_route_index += 1
		_board.invalidate_hover()
		# Arrival is resolved even if this frame used exactly the segment distance.
		if _current_cell == GameConfig.EXIT:
			_resolve(false)
			return


func take_damage(damage: int) -> void:
	if not is_alive() or damage <= 0:
		return
	health = maxi(0, health - damage)
	queue_redraw()
	if health == 0:
		_resolve(true)


func _resolve(killed: bool) -> void:
	if not is_alive():
		return
	_alive = false # Before emitting, so synchronous listeners cannot resolve twice.
	set_process(false)
	_board.invalidate_hover()
	if killed:
		died.emit(self)
	else:
		reached_exit.emit(self)
	queue_free()


func _report_navigation_error(message: String) -> void:
	_navigation_error = true
	push_error(message)
	navigation_failed.emit(message)
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, 10, Color("f06464") if not _navigation_error else Color.MAGENTA)
	draw_circle(Vector2(-3, -2), 2, Color("4a1825"))
	draw_circle(Vector2(3, -2), 2, Color("4a1825"))
	draw_rect(Rect2(-12, -17, 24, 4), Color("45212c"))
	if max_health > 0:
		draw_rect(Rect2(-12, -17, 24.0 * health / max_health, 4), Color("89ef88"))
