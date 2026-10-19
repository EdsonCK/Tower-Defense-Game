class_name Enemy
extends Node2D
## Maintains its current segment across revisions; replans only at cell centers.

signal died(enemy: Enemy)
signal reached_exit(enemy: Enemy)
signal navigation_failed(message: String)

var health := 0
var max_health := 0
var kind := EnemyProfile.Kind.GRUNT
var speed := GameConfig.ENEMY_SPEED
var bounty := GameConfig.KILL_BOUNTY
var armor := 0
var max_armor := 0
var shield := 0
var max_shield := 0

const HEALTH_COLOR := Color("63df96")
const ARMOR_COLOR := Color("f1f5fc")
const SHIELD_COLOR := Color("b987ff")
var regeneration := 0.0
var body_color := Color("f06464")
var _slow_factor := 1.0
var _slow_remaining := 0.0
var _since_damage := 0.0
var _regen_fraction := 0.0
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
	# Baseline fixture/scene setup also remains useful for focused movement tests.
	var profile := EnemyProfile.base(EnemyProfile.Kind.GRUNT)
	profile.hit_points = hit_points
	setup_profile(board, profile)


func setup_profile(board: Board, profile: EnemyProfile) -> void:
	_board = board
	health = profile.hit_points
	max_health = profile.hit_points
	kind = profile.kind
	speed = profile.speed
	bounty = profile.bounty
	armor = profile.armor
	max_armor = armor
	shield = profile.shield
	max_shield = shield
	regeneration = profile.regeneration
	body_color = profile.color
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
	if not is_alive():
		return # A resolved enemy may remain queued until the end of this frame.
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
	_tick_regeneration(delta)
	var slowed_time := minf(delta, _slow_remaining)
	var remaining := speed * (slowed_time * _slow_factor + delta - slowed_time)
	_slow_remaining = maxf(0.0, _slow_remaining - delta)
	if _slow_remaining == 0.0:
		_slow_factor = 1.0
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


func take_damage(health_damage: int, armor_damage: int = -1, shield_damage: int = -1) -> void:
	if not is_alive():
		return
	# A hit spends its layer-specific stat on ONE pool. Overkill never spills.
	var amount := health_damage
	if shield > 0:
		amount = health_damage if shield_damage < 0 else shield_damage
	elif armor > 0:
		amount = health_damage if armor_damage < 0 else armor_damage
	if amount <= 0:
		return
	_since_damage = 0.0
	if shield > 0:
		shield = maxi(0, shield - amount)
	elif armor > 0:
		armor = maxi(0, armor - amount)
	else:
		health = maxi(0, health - amount)
	queue_redraw()
	if health == 0:
		_resolve(true)


func apply_slow(factor: float, duration: float) -> void:
	if not is_alive() or not is_finite(factor) or not is_finite(duration) or duration <= 0:
		return
	_slow_factor = minf(_slow_factor, clampf(factor, 0.25, 1.0))
	_slow_remaining = maxf(_slow_remaining, minf(duration, 10.0))


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


func _tick_regeneration(delta: float) -> void:
	var previous := _since_damage
	_since_damage += delta
	if regeneration <= 0.0 or health >= max_health:
		_regen_fraction = 0.0
		return
	var healing_time := maxf(0.0, _since_damage - GameConfig.REGEN_DELAY) - maxf(0.0, previous - GameConfig.REGEN_DELAY)
	_regen_fraction += regeneration * healing_time
	var healed := floori(_regen_fraction)
	if healed > 0:
		health = mini(max_health, health + healed)
		_regen_fraction -= healed
		queue_redraw()


func _draw() -> void:
	var color := body_color if not _navigation_error else Color.MAGENTA
	match kind:
		EnemyProfile.Kind.RUNNER:
			draw_colored_polygon(PackedVector2Array([Vector2(12, 0), Vector2(-9, -8), Vector2(-9, 8)]), color)
		EnemyProfile.Kind.ARMORED:
			draw_rect(Rect2(-11, -11, 22, 22), color)
			draw_rect(Rect2(-7, -7, 14, 14), Color("455866"), false, 2.0)
		EnemyProfile.Kind.SHIELDED:
			draw_colored_polygon(PackedVector2Array([Vector2(0, -12), Vector2(11, 0), Vector2(0, 12), Vector2(-11, 0)]), color)
		_:
			draw_circle(Vector2.ZERO, 10, color)
	if kind == EnemyProfile.Kind.REGENERATOR:
		draw_line(Vector2(-5, 0), Vector2(5, 0), Color.WHITE, 3.0)
		draw_line(Vector2(0, -5), Vector2(0, 5), Color.WHITE, 3.0)
	if shield > 0:
		draw_arc(Vector2.ZERO, 14, 0, TAU, 24, SHIELD_COLOR, 2.0)
	# Fixed stack positions; depleted layers disappear without moving health.
	_draw_bar(-18.0, health, max_health, HEALTH_COLOR)
	if armor > 0:
		_draw_bar(-23.0, armor, max_armor, ARMOR_COLOR)
	if shield > 0:
		_draw_bar(-28.0, shield, max_shield, SHIELD_COLOR)


func _draw_bar(y: float, current: int, maximum: int, color: Color) -> void:
	draw_rect(Rect2(-13, y - 1, 26, 5), Color("101827"))
	if maximum > 0:
		draw_rect(Rect2(-12, y, 24.0 * current / maximum, 3), color)
