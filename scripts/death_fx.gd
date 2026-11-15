class_name DeathFx
extends Node2D
## Short burst where an enemy died: a flash, an expanding ring and flying shards in the
## enemy's color. Purely visual; frees itself.

var color: Color = Color.WHITE
var size: float = 10.0
var duration: float = 0.45
var _age: float = 0.0
var _shards: Array[Vector2] = []


func setup(at: Vector2, enemy_color: Color, enemy_radius: float, big: bool = false) -> void:
	position = at
	color = enemy_color
	size = enemy_radius
	duration = 1.1 if big else 0.45
	var count: int = 18 if big else 7
	for i in count:
		_shards.append(Vector2.RIGHT.rotated(TAU * i / count + randf_range(-0.3, 0.3)) * randf_range(0.7, 1.3))


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var t: float = _age / duration
	var fade: float = 1.0 - t
	if t < 0.25:
		draw_circle(Vector2.ZERO, size * (0.8 + t * 2.0), Color(1, 1, 1, 0.7 * (1.0 - t / 0.25)))
	draw_arc(Vector2.ZERO, size * (1.0 + 2.2 * t), 0.0, TAU, 28, Color(color.lightened(0.3), 0.8 * fade), 2.0 + size * 0.1 * fade)
	for dir: Vector2 in _shards:
		var pos: Vector2 = dir * size * (0.6 + 2.6 * t) + Vector2(0, 10.0 * t * t)
		var s: float = maxf(1.0, size * 0.28 * fade)
		draw_rect(Rect2(pos - Vector2(s, s) / 2.0, Vector2(s, s)), Color(color, fade))
