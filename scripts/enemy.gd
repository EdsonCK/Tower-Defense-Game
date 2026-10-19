class_name Enemy
extends Node2D
## Walks cell center to cell center (cardinal only) toward the exit at constant speed.
## Stats, appearance and traits (armor, regeneration, splitting, lives cost) come from
## an EnemyTypes definition. Emits `died` or `reached_exit` exactly once, then frees itself.
## Route changes are applied only on arriving at a cell center, so the current
## segment always finishes and the enemy never teleports.

signal died(enemy: Enemy)
signal reached_exit(enemy: Enemy)

const COLOR_OUTLINE: Color = Color(0.1, 0.05, 0.05)
const HEALTH_BAR_WIDTH: float = 24.0
const HEALTH_BAR_HEIGHT: float = 4.0

var type_id: String = EnemyTypes.GRUNT
var max_health: float = 1.0
var health: float = 1.0
var speed: float = 60.0
var reward: int = 0
var armor: int = 0
var regen_rate: float = 0.0
var lives_cost: int = 1
var radius: float = 10.0
var color: Color = Color.RED
var shape: String = "diamond"
## Wave the enemy was spawned on; split children use it to scale their stats.
var wave: int = 1
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
var _draw_offset: Vector2 = Vector2.ZERO
var _slow: float = 0.0       # fraction of speed removed while slowed
var _slow_left: float = 0.0  # seconds of slow remaining


## Configures a freshly spawned enemy at the entrance from a WaveGenerator spawn entry.
func setup(board: Board, entry: Dictionary, wave_number: int) -> void:
	_apply_type(entry, wave_number)
	_board = board
	current_cell = GameConfig.SPAWN_CELL
	next_cell = current_cell
	position = Board.cell_to_world(current_cell)
	_register()
	_plan_route()


## Configures an enemy spawned where `parent` died, continuing the parent's movement
## segment so it never stands on or walks into a blocked tile.
func setup_split_from(parent: Enemy, entry: Dictionary, sibling_index: int) -> void:
	_apply_type(entry, parent.wave)
	_board = parent._board
	current_cell = parent.current_cell
	next_cell = parent.next_cell
	_moving = parent._moving
	position = parent.position
	_draw_offset = Vector2.RIGHT.rotated(TAU * sibling_index / 3.0) * 5.0
	_register()
	_route_dirty = true  # re-plan at the next cell center


func _apply_type(entry: Dictionary, wave_number: int) -> void:
	var def: Dictionary = EnemyTypes.get_def(entry["type"])
	type_id = entry["type"]
	wave = wave_number
	max_health = entry["health"]
	health = max_health
	reward = entry["reward"]
	lives_cost = entry["lives"]
	speed = def["speed"]
	armor = def["armor"]
	regen_rate = def["regen"]
	radius = def["radius"]
	color = def["color"]
	shape = def["shape"]


func _register() -> void:
	add_to_group("enemies")
	_board.navigation_changed.connect(_on_navigation_changed)


func _process(delta: float) -> void:
	step(delta)


## One simulation tick: regeneration, then movement.
func step(delta: float) -> void:
	if _resolved:
		return
	if regen_rate > 0.0 and health < max_health:
		health = minf(max_health, health + max_health * regen_rate * delta)
		queue_redraw()
	if _slow_left > 0.0:
		_slow_left -= delta
		if _slow_left <= 0.0:
			_slow = 0.0
			queue_redraw()
	advance(delta)


## Moves the enemy by `delta` seconds of travel, crossing as many cell centers as needed.
func advance(delta: float) -> void:
	var remaining: float = get_effective_speed() * delta
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


## Applies a hit after armor (unless `ignore_armor`). Every hit deals at least 1 damage.
func take_damage(amount: int, ignore_armor: bool = false) -> void:
	if _resolved:
		return
	var effective: int = amount if ignore_armor else amount - armor
	health = maxf(health - maxi(effective, 1), 0.0)
	queue_redraw()
	if health <= 0.0:
		_resolve()
		died.emit(self)
		queue_free()


## Slows the enemy by `amount` (0-1) for `duration` seconds; the strongest slow wins.
func apply_slow(amount: float, duration: float) -> void:
	if _resolved:
		return
	_slow = clampf(maxf(_slow, amount), 0.0, 0.8)
	_slow_left = maxf(_slow_left, duration)
	queue_redraw()


func get_effective_speed() -> float:
	return speed * (1.0 - _slow)


func is_slowed() -> bool:
	return _slow > 0.0


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
	# Movement state is kept intact: split children copy it from a dying parent.
	_resolved = true
	remove_from_group("enemies")


# --- Rendering -------------------------------------------------------------------

func _draw() -> void:
	var points: PackedVector2Array = _shape_points()
	if shape == "circle" or shape == "ring":
		draw_circle(_draw_offset, radius, color)
		draw_arc(_draw_offset, radius, 0.0, TAU, 24, COLOR_OUTLINE, 1.5)
		if shape == "ring":
			draw_circle(_draw_offset, radius * 0.45, COLOR_OUTLINE)
	else:
		draw_colored_polygon(points, color)
		points.append(points[0])
		draw_polyline(points, COLOR_OUTLINE, 1.5)
	if armor > 0:
		draw_arc(_draw_offset, radius + 3.0, 0.0, TAU, 24, Color(0.8, 0.8, 0.85), 2.0)
	if _slow > 0.0:
		draw_arc(_draw_offset, radius + 5.0, 0.0, TAU, 24, Color(0.45, 0.75, 1.0, 0.9), 2.0)
	var bar_origin: Vector2 = _draw_offset + Vector2(-HEALTH_BAR_WIDTH / 2.0, -radius - 9.0)
	draw_rect(Rect2(bar_origin, Vector2(HEALTH_BAR_WIDTH, HEALTH_BAR_HEIGHT)), Color(0.1, 0.1, 0.1))
	var ratio: float = clampf(health / max_health, 0.0, 1.0) if max_health > 0.0 else 0.0
	var bar_color: Color = Color(0.3, 0.95, 0.9) if regen_rate > 0.0 else Color(0.3, 0.95, 0.3)
	draw_rect(Rect2(bar_origin, Vector2(HEALTH_BAR_WIDTH * ratio, HEALTH_BAR_HEIGHT)), bar_color)


func _shape_points() -> PackedVector2Array:
	var r: float = radius
	var o: Vector2 = _draw_offset
	match shape:
		"triangle":
			return PackedVector2Array([o + Vector2(r, 0), o + Vector2(-r * 0.8, -r * 0.8), o + Vector2(-r * 0.8, r * 0.8)])
		"square":
			return PackedVector2Array([o + Vector2(-r, -r), o + Vector2(r, -r), o + Vector2(r, r), o + Vector2(-r, r)])
		"hexagon":
			return _regular_polygon(6, r, 0.0)
		"star":
			var star: PackedVector2Array = PackedVector2Array()
			for i in 10:
				var point_radius: float = r if i % 2 == 0 else r * 0.5
				star.append(o + Vector2.UP.rotated(TAU * i / 10.0) * point_radius)
			return star
		_:
			return PackedVector2Array([o + Vector2(0, -r), o + Vector2(r, 0), o + Vector2(0, r), o + Vector2(-r, 0)])


func _regular_polygon(sides: int, r: float, rotation_offset: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in sides:
		points.append(_draw_offset + Vector2.RIGHT.rotated(rotation_offset + TAU * i / sides) * r)
	return points
