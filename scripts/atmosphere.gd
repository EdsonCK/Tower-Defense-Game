class_name Atmosphere
extends Node2D
## Ambient particles drifting over the visible map, one kind per biome: pollen and
## butterflies, blowing dust, snow, rising embers, fireflies or falling leaves. Purely
## visual; the count scales with the visible area.

const KINDS: Array[String] = ["pollen", "dust", "snow", "embers", "fireflies", "leaves"]
const MAX_PARTICLES: int = 90
const CELLS_PER_PARTICLE: float = 25.0

var kind: String = "pollen"
var area: Rect2 = Rect2(0, 0, 100, 100)
var _particles: Array[Dictionary] = []
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _time: float = 0.0


func configure(new_kind: String, new_area: Rect2) -> void:
	var cells: float = new_area.get_area() / float(GameConfig.CELL_SIZE * GameConfig.CELL_SIZE)
	var count: int = clampi(int(cells / CELLS_PER_PARTICLE), 12, MAX_PARTICLES)
	var rebuild: bool = new_kind != kind or count != _particles.size()
	kind = new_kind
	area = new_area
	if rebuild:
		_particles.clear()
		for i in count:
			_particles.append(_spawn(true))
	queue_redraw()


func particle_count() -> int:
	return _particles.size()


func _spawn(anywhere: bool) -> Dictionary:
	var pos: Vector2 = Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
	var v: Vector2 = Vector2.ZERO
	match kind:
		"dust":
			v = Vector2(_rng.randf_range(40, 80), _rng.randf_range(-6, 6))
		"snow":
			v = Vector2(_rng.randf_range(-8, 14), _rng.randf_range(16, 34))
		"embers":
			v = Vector2(_rng.randf_range(-6, 6), _rng.randf_range(-30, -14))
		"leaves":
			v = Vector2(_rng.randf_range(4, 18), _rng.randf_range(12, 24))
		_:
			v = Vector2(_rng.randf_range(-10, 10), _rng.randf_range(-6, 6))
	if not anywhere:
		# Re-enter from the side the particles drift in from.
		if absf(v.x) > absf(v.y):
			pos.x = area.position.x if v.x > 0.0 else area.end.x
		else:
			pos.y = area.position.y if v.y > 0.0 else area.end.y
	return {
		"pos": pos, "vel": v, "phase": _rng.randf() * TAU, "size": _rng.randf_range(0.6, 1.4),
		"special": _rng.randf() < 0.15, "spin": _rng.randf_range(-3.0, 3.0),
	}


func _process(delta: float) -> void:
	_time += delta
	for i in _particles.size():
		var p: Dictionary = _particles[i]
		var wobble: Vector2 = Vector2(sin(_time * 1.3 + p["phase"]), cos(_time * 1.1 + p["phase"])) * 6.0
		p["pos"] += (p["vel"] + wobble) * delta
		if not area.grow(12.0).has_point(p["pos"]):
			_particles[i] = _spawn(false)
	queue_redraw()


func _draw() -> void:
	for p: Dictionary in _particles:
		var pos: Vector2 = p["pos"]
		var s: float = p["size"]
		var ph: float = p["phase"]
		match kind:
			"pollen":
				if p["special"]:
					_butterfly(pos, ph)
				else:
					draw_circle(pos, 1.3 * s, Color(1.0, 1.0, 0.8, 0.55))
			"dust":
				var a: float = 0.25 + 0.2 * sin(_time * 2.0 + ph)
				if p["special"]:
					draw_line(pos, pos - Vector2(18, 0) * s, Color(1.0, 0.92, 0.75, a * 0.6), 1.0)
				else:
					draw_circle(pos, 1.1 * s, Color(0.95, 0.85, 0.65, a))
			"snow":
				draw_circle(pos, 1.6 * s, Color(1, 1, 1, 0.85))
				if p["special"]:
					draw_circle(pos, 3.0 * s, Color(1, 1, 1, 0.25))
			"embers":
				var flick: float = 0.55 + 0.45 * sin(_time * 7.0 + ph * 5.0)
				draw_circle(pos, 3.2 * s, Color(1.0, 0.45, 0.1, 0.18 * flick))
				draw_circle(pos, 1.2 * s, Color(1.0, 0.75, 0.3, flick))
			"fireflies":
				var blink: float = clampf(sin(_time * 1.7 + ph * 3.0) * 1.6, 0.0, 1.0)
				draw_circle(pos, 5.0, Color(0.8, 1.0, 0.4, 0.18 * blink))
				draw_circle(pos, 1.4, Color(0.95, 1.0, 0.6, 0.3 + 0.7 * blink))
			"leaves":
				var colors: Array[Color] = [Color(0.9, 0.45, 0.12), Color(0.95, 0.7, 0.2), Color(0.75, 0.2, 0.1)]
				draw_set_transform(pos, _time * float(p["spin"]) + ph, Vector2(1.0, 0.5 + 0.3 * sin(_time * 3.0 + ph)))
				draw_circle(Vector2.ZERO, 2.8 * s, colors[int(ph * 10.0) % 3])
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _butterfly(pos: Vector2, ph: float) -> void:
	var flap: float = absf(sin(_time * 14.0 + ph))
	var col: Color = [Color(1.0, 0.8, 0.3), Color(0.6, 0.75, 1.0), Color(1.0, 0.55, 0.75)][int(ph * 10.0) % 3]
	for side: float in [-1.0, 1.0]:
		draw_set_transform(pos + Vector2(side * 2.0 * flap, 0), 0.0, Vector2(0.35 + 0.65 * flap, 1.0))
		draw_circle(Vector2(side * 2.0, -1.0), 2.4, col)
		draw_circle(Vector2(side * 1.6, 1.6), 1.6, col.darkened(0.15))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_line(pos + Vector2(0, -2), pos + Vector2(0, 2.5), Color(0.15, 0.1, 0.1), 1.0)
