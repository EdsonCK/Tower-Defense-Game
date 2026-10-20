class_name CombatProjectile
extends Node2D
## Snapshot damage; no strong target/source references. Swept collision for cannon.

enum Kind { MORTAR, ICE, CANNON }
const CANNON_RADIUS := 5.0
var kind := Kind.MORTAR
var board: Board
var source_id := 0
var health_damage := 0
var armor_damage := 0
var shield_damage := 0
var origin := Vector2.ZERO
var destination := Vector2.ZERO
var direction := Vector2.RIGHT
var speed := 300.0
var travel_limit := 320.0
var splash_radius := 64.0
var slow_factor := 0.65
var slow_duration := 2.0
var freeze_on_hit := false
var freeze_duration := 0.5
var flight_duration := 1.0
var target: WeakRef
var _age := 0.0
var _traveled := 0.0
var _hit_ids: Dictionary = {}
var _impact := false
var _finished := false
var _trail := Vector2.ZERO


func _ready() -> void:
	add_to_group("projectiles")
	z_index = 20


func _process(delta: float) -> void:
	if _finished or is_queued_for_deletion() or board == null:
		return
	_age += delta
	if _impact:
		if _age >= 0.35:
			_finish()
		queue_redraw()
		return
	match kind:
		Kind.MORTAR:
			var progress := clampf(_age / flight_duration, 0, 1)
			position = origin.lerp(destination, progress)
			if progress >= 1:
				_explode()
		Kind.ICE:
			_tick_ice(delta)
		Kind.CANNON:
			_tick_cannon(delta)
	queue_redraw()


func _explode() -> void:
	_impact = true
	_age = 0.0
	for candidate in board.enemy_index.query(Rect2(position - Vector2.ONE * splash_radius, Vector2.ONE * splash_radius * 2)):
		if is_queued_for_deletion():
			return # Last kill can clear the wave and dispose all in-flight effects.
		var enemy := candidate as Enemy
		if enemy != null and enemy.is_alive() and position.distance_squared_to(enemy.position) <= splash_radius * splash_radius:
			enemy.take_damage(health_damage, armor_damage, shield_damage)


func _tick_ice(delta: float) -> void:
	var enemy := target.get_ref() as Enemy if target != null else null
	if enemy == null or not enemy.is_alive() or _age >= 3.0:
		_finish()
		return
	var offset := enemy.position - position
	direction = offset.normalized() if offset.length_squared() > 0.0 else direction
	var step := minf(speed * delta, offset.length())
	_trail = position
	position += direction * step
	if position.distance_squared_to(enemy.position) <= 100.0:
		enemy.take_damage(health_damage, armor_damage, shield_damage)
		if enemy.is_alive():
			enemy.apply_slow(slow_factor, slow_duration)
			if freeze_on_hit:
				enemy.apply_freeze(freeze_duration)
		_impact = true
		_age = 0.0


func _tick_cannon(delta: float) -> void:
	var distance := minf(speed * delta, travel_limit - _traveled)
	if distance <= 0:
		_finish()
		return
	var end := position + direction * distance
	var wall_fraction := INF
	var segment_bounds := Rect2(position, Vector2.ZERO).expand(end)
	for child in board.tower_index.query(segment_bounds.grow(15.0 + CANNON_RADIUS)):
		if child.get_instance_id() == source_id or child.is_queued_for_deletion():
			continue
		var tower := child as Tower
		if tower != null:
			wall_fraction = minf(wall_fraction, rect_fraction(position, end, Rect2(tower.position - Vector2(15, 15), Vector2(30, 30)).grow(CANNON_RADIUS)))
	var hits: Array[Dictionary] = []
	for candidate in board.enemy_index.query(segment_bounds.grow(10.0 + CANNON_RADIUS)):
		var enemy := candidate as Enemy
		if enemy == null or not enemy.is_alive() or _hit_ids.has(enemy.get_instance_id()):
			continue
		var fraction := circle_fraction(position, end, enemy.position, 10.0 + CANNON_RADIUS)
		if fraction >= 0.0 and fraction < wall_fraction:
			hits.append({"fraction": fraction, "enemy": enemy})
	hits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.fraction < b.fraction)
	for hit in hits:
		if is_queued_for_deletion():
			return
		var enemy: Enemy = hit.enemy
		if enemy.is_alive():
			_hit_ids[enemy.get_instance_id()] = true
			enemy.take_damage(health_damage, armor_damage, shield_damage)
	_trail = position
	position = position.lerp(end, wall_fraction) if is_finite(wall_fraction) else end
	_traveled += distance * (wall_fraction if is_finite(wall_fraction) else 1.0)
	if is_finite(wall_fraction):
		_impact = true
		_age = 0.0
	elif _traveled >= travel_limit or not Rect2(Vector2(-24, -24), GameConfig.BOARD_SIZE + Vector2(48, 48)).has_point(position):
		_finish()


static func circle_fraction(start: Vector2, end: Vector2, center: Vector2, radius: float) -> float:
	var offset := start - center
	if offset.length_squared() <= radius * radius:
		return 0.0
	var segment := end - start
	var length := segment.length_squared()
	if length <= 0.000001:
		return -1.0
	var b := offset.dot(segment)
	var discriminant := b * b - length * (offset.length_squared() - radius * radius)
	if discriminant < 0:
		return -1.0
	var fraction := (-b - sqrt(discriminant)) / length
	return fraction if fraction >= 0.0 and fraction <= 1.0 else -1.0


static func rect_fraction(start: Vector2, end: Vector2, rect: Rect2) -> float:
	var near := 0.0
	var far := 1.0
	for axis in [0, 1]:
		var delta: float = end[axis] - start[axis]
		if absf(delta) < 0.000001:
			if start[axis] < rect.position[axis] or start[axis] > rect.end[axis]:
				return INF
		else:
			var first: float = (rect.position[axis] - start[axis]) / delta
			var last: float = (rect.end[axis] - start[axis]) / delta
			near = maxf(near, minf(first, last))
			far = minf(far, maxf(first, last))
			if near > far:
				return INF
	return near


func _finish() -> void:
	_finished = true
	set_process(false)
	queue_free()


func _draw() -> void:
	if _impact:
		var t := clampf(_age / 0.35, 0, 1)
		var radius := splash_radius if kind == Kind.MORTAR else 15.0
		var color := Color("ffb96b") if kind != Kind.ICE else Color("a9efff")
		draw_circle(Vector2.ZERO, radius * (0.25 + 0.75 * t), Color(color, 0.13 * (1 - t)))
		draw_arc(Vector2.ZERO, radius * (0.25 + 0.75 * t), 0, TAU, 48, Color(color, 1 - t), 2, true)
		for i in range(9):
			var ray := Vector2.from_angle(i * TAU / 9 + 0.3)
			draw_line(ray * radius * t * 0.7, ray * radius * t, Color(color, 1 - t), 2, true)
		return
	match kind:
		Kind.MORTAR:
			var t := clampf(_age / flight_duration, 0, 1)
			var height := sin(t * PI) * minf(100.0, origin.distance_to(destination) * 0.4)
			DrawKit.ellipse(self, Vector2.ZERO, Vector2(6, 3), Color(0, 0, 0, 0.35))
			var shell := Vector2(0, -height)
			draw_line(shell + Vector2(-8, -5), shell + Vector2(-3, -2), Color("f2b061"), 2, true)
			draw_circle(shell, 5, DrawKit.INK)
			draw_circle(shell, 3.7, Color("9d754a"))
			draw_circle(shell + Vector2(-1, -1), 1.5, Color("ffdf9e"))
		Kind.ICE:
			var side := direction.orthogonal()
			DrawKit.poly(self, PackedVector2Array([direction * 11, -direction * 8 + side * 4, -direction * 5, -direction * 8 - side * 4]), Color("a9edff"), Color("244e70"), 1.5)
			draw_line(-direction * 4, direction * 7, Color.WHITE, 1.4, true)
			draw_line(-direction * 10, -direction * 21, Color(0.6, 0.9, 1, 0.35), 2, true)
		Kind.CANNON:
			draw_line(-direction * 7, -direction * 20, Color(0.85, 0.73, 0.51, 0.4), 4, true)
			draw_circle(Vector2.ZERO, 5.5, DrawKit.INK)
			draw_circle(Vector2.ZERO, 4, Color("616b78"))
			draw_circle(Vector2(-1.5, -1.5), 1.5, Color("cbd2d4"))
