class_name Enemy
extends Node2D
## Walks the fixed path from its entrance to the exit, cell center to cell center
## (cardinal only), at constant speed.
## Stats, appearance and traits (layers, regeneration, splitting, lives cost) come from
## an EnemyTypes definition. Hit points come in up to three stacked layers: shield on
## top, then armor, then health. A hit only damages the top non-empty layer, using the
## attacker's damage against that layer; excess damage is lost. The enemy dies when its
## health layer is empty. Emits `died` or `reached_exit` exactly once, then frees itself.

signal died(enemy: Enemy)
signal reached_exit(enemy: Enemy)

const COLOR_OUTLINE: Color = Color(0.1, 0.05, 0.05)
const HEALTH_BAR_WIDTH: float = 26.0
const HEALTH_BAR_HEIGHT: float = 3.0
const HEALTH_BAR_GAP: float = 1.0
const LAYER_COLORS: Dictionary = {
	"shield": Color(0.72, 0.4, 1.0),
	"armor": Color(0.92, 0.94, 0.98),
	"health": Color(0.3, 0.95, 0.35),
}

var type_id: String = EnemyTypes.GRUNT
var max_health: float = 1.0
var health: float = 1.0
var max_armor: float = 0.0
var armor: float = 0.0
var max_shield: float = 0.0
var shield: float = 0.0
var speed: float = 60.0
var reward: int = 0
var regen_rate: float = 0.0
var lives_cost: int = 1
var radius: float = 10.0
var color: Color = Color.RED
var shape: String = "diamond"
## Wave the enemy was spawned on; split children use it to scale their stats.
var wave: int = 1
## Cell whose center the enemy most recently reached (or is standing on).
var current_cell: Vector2i = GameConfig.EXIT_CELL
## Cell whose center the enemy is walking toward; equals current_cell while not moving.
var next_cell: Vector2i = GameConfig.EXIT_CELL

var _board: Board
var _moving: bool = false
var _resolved: bool = false
var _draw_offset: Vector2 = Vector2.ZERO
var _slow: float = 0.0       # fraction of speed removed while slowed
var _slow_left: float = 0.0  # seconds of slow remaining
# Animation state (visual only).
var _anim_time: float = 0.0
var _anim_frame: int = -1
var _hit_flash: float = 0.0
var _facing: float = 0.0  # radians, direction of travel

const ANIM_FPS: float = 20.0  # body animation redraw rate (movement itself is smooth)


## Configures a freshly spawned enemy at `spawn_cell` (an entrance) from a
## WaveGenerator spawn entry. It then follows the path toward the exit.
func setup(board: Board, entry: Dictionary, wave_number: int, spawn_cell: Vector2i = Vector2i(-1, -1)) -> void:
	_apply_type(entry, wave_number)
	_board = board
	if spawn_cell == Vector2i(-1, -1):
		var entrances: Array[Vector2i] = board.entrances()
		spawn_cell = entrances[0] if not entrances.is_empty() else board.exit_cell()
	current_cell = spawn_cell
	next_cell = board.next_cell(spawn_cell)
	_moving = current_cell != next_cell
	position = Board.cell_to_world(current_cell)
	_anim_time = randf() * 10.0
	_update_facing()
	add_to_group("enemies")


## Configures an enemy spawned where `parent` died, continuing the parent's movement
## segment along the path.
func setup_split_from(parent: Enemy, entry: Dictionary, sibling_index: int) -> void:
	_apply_type(entry, parent.wave)
	_board = parent._board
	current_cell = parent.current_cell
	next_cell = parent.next_cell
	_moving = parent._moving
	position = parent.position
	_draw_offset = Vector2.RIGHT.rotated(TAU * sibling_index / 3.0) * 5.0
	_anim_time = randf() * 10.0
	_facing = parent._facing
	add_to_group("enemies")


func _apply_type(entry: Dictionary, wave_number: int) -> void:
	var def: Dictionary = EnemyTypes.get_def(entry["type"])
	type_id = entry["type"]
	wave = wave_number
	max_health = entry["health"]
	health = max_health
	max_armor = entry.get("armor", 0.0)
	armor = max_armor
	max_shield = entry.get("shield", 0.0)
	shield = max_shield
	reward = entry["reward"]
	lives_cost = entry["lives"]
	speed = def["speed"]
	regen_rate = def["regen"]
	radius = def["radius"]
	color = def["color"]
	shape = def["shape"]


func _process(delta: float) -> void:
	step(delta)
	_animate(delta)


func _animate(delta: float) -> void:
	_anim_time += delta
	if _hit_flash > 0.0:
		_hit_flash = maxf(0.0, _hit_flash - delta)
		queue_redraw()
		return
	var frame: int = int(_anim_time * ANIM_FPS)
	if frame != _anim_frame:
		_anim_frame = frame
		queue_redraw()


func _update_facing() -> void:
	if next_cell != current_cell:
		_facing = Vector2(next_cell - current_cell).angle()


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
		if not _moving:
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


## The layer that currently takes damage: "shield", then "armor", then "health".
func top_layer() -> String:
	if shield > 0.0:
		return "shield"
	if armor > 0.0:
		return "armor"
	return "health"


## Applies one hit. `damage` maps layer -> damage against that layer; only the top
## non-empty layer is damaged and any excess is lost.
func take_hit(damage: Dictionary) -> void:
	if _resolved:
		return
	var layer: String = top_layer()
	var amount: float = float(damage.get(layer, 0))
	if amount <= 0.0:
		return
	match layer:
		"shield":
			shield = maxf(shield - amount, 0.0)
		"armor":
			armor = maxf(armor - amount, 0.0)
		_:
			health = maxf(health - amount, 0.0)
	_hit_flash = 0.08
	queue_redraw()
	if health <= 0.0:
		_resolve()
		_spawn_death_fx()
		died.emit(self)
		queue_free()


## Convenience hit dealing `amount` to whichever layer is on top.
func take_damage(amount: float) -> void:
	take_hit({"health": amount, "armor": amount, "shield": amount})


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


## Path distance (world px) still to walk to the exit; smaller = further along.
## Towers use it to target the enemy closest to the exit.
func remaining_distance() -> float:
	if not _moving:
		return float(_board.distance_to_exit(current_cell)) * GameConfig.CELL_SIZE
	return float(_board.distance_to_exit(next_cell)) * GameConfig.CELL_SIZE + position.distance_to(Board.cell_to_world(next_cell))


## Removes the enemy without emitting died/reached_exit (used by Restart).
func discard() -> void:
	_resolve()
	queue_free()


func _arrive_at(cell: Vector2i) -> void:
	current_cell = cell
	if cell == _board.exit_cell():
		next_cell = cell
		_moving = false
		_resolve()
		reached_exit.emit(self)
		queue_free()
		return
	next_cell = _board.next_cell(cell)
	_update_facing()


## Leaves a short burst on the board (not among the enemies) where this enemy died.
func _spawn_death_fx() -> void:
	if _board == null or not _board.is_inside_tree():
		return
	var fx: DeathFx = DeathFx.new()
	fx.setup(position + _draw_offset, color, radius, type_id == EnemyTypes.BOSS)
	_board.add_child(fx)


func _resolve() -> void:
	# Movement state is kept intact: split children copy it from a dying parent.
	_resolved = true
	remove_from_group("enemies")


# --- Rendering -------------------------------------------------------------------

## Body art: each type keeps its silhouette (so it stays recognizable) and gets shading,
## eyes that look where it walks, a bob/squash walk cycle and per-type details. Hits flash
## the body white.
func _draw() -> void:
	var t: float = _anim_time
	var bob: float = sin(t * (14.0 if speed > 60.0 else 9.0)) * radius * 0.08
	var o: Vector2 = _draw_offset + Vector2(0, bob)
	var squash: Vector2 = Vector2(1.0 + 0.05 * sin(t * 18.0), 1.0 - 0.05 * sin(t * 18.0))
	var body: Color = color.lerp(Color.WHITE, clampf(_hit_flash / 0.08, 0.0, 1.0) * 0.75)
	var look: Vector2 = Vector2.RIGHT.rotated(_facing)
	# Ground shadow.
	draw_set_transform(_draw_offset + Vector2(0, radius * 0.75), 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, radius * 0.95, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_aura(o, t)
	# Body (silhouette per type), drawn squashed around its center.
	draw_set_transform(o, _body_rotation(t), squash)
	var points: PackedVector2Array = _shape_points(Vector2.ZERO)
	if shape == "circle" or shape == "ring":
		draw_circle(Vector2.ZERO, radius, body.darkened(0.35))
		draw_circle(Vector2(-radius * 0.08, -radius * 0.1), radius * 0.86, body)
	else:
		draw_colored_polygon(points, body.darkened(0.35))
		var inner: PackedVector2Array = PackedVector2Array()
		for p: Vector2 in points:
			inner.append(p * 0.8 + Vector2(-radius * 0.05, -radius * 0.08))
		draw_colored_polygon(inner, body)
	draw_circle(Vector2(-radius * 0.35, -radius * 0.4), radius * 0.2, Color(1, 1, 1, 0.35))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_details(o, t, look, body)
	_draw_defenses(o, t)
	if _slow > 0.0:
		for i in 3:
			var a: float = t * 2.0 + TAU * i / 3.0
			draw_circle(o + Vector2.RIGHT.rotated(a) * (radius + 6.0), 1.8, Color(0.55, 0.85, 1.0, 0.9))
		draw_arc(o, radius + 6.0, 0.0, TAU, 28, Color(0.45, 0.75, 1.0, 0.45), 1.0)
	_draw_layer_bars()


func _body_rotation(t: float) -> float:
	match type_id:
		EnemyTypes.RUNNER:
			return _facing  # the arrowhead points where it runs
		EnemyTypes.BOSS:
			return t * 0.6
		EnemyTypes.SPLITTER:
			return sin(t * 3.0) * 0.25
	return 0.0


func _draw_aura(o: Vector2, t: float) -> void:
	match type_id:
		EnemyTypes.MENDER:
			var pulse: float = fmod(t * 0.9, 1.0)
			draw_arc(o, radius * (1.0 + pulse * 1.4), 0.0, TAU, 28, Color(0.35, 1.0, 0.8, 0.5 * (1.0 - pulse)), 2.0)
		EnemyTypes.BOSS:
			var pulse: float = 0.5 + 0.5 * sin(t * 3.0)
			draw_circle(o, radius * (1.35 + 0.1 * pulse), Color(0.6, 0.0, 0.05, 0.18 + 0.1 * pulse))
		EnemyTypes.RUNNER:
			var back: Vector2 = -Vector2.RIGHT.rotated(_facing)
			for i in 3:
				var side: Vector2 = back.orthogonal() * (i - 1) * radius * 0.5
				var start: Vector2 = o + back * radius * 0.9 + side
				draw_line(start, start + back * radius * (0.6 + 0.4 * sin(t * 20.0 + i)), Color(1.0, 0.95, 0.6, 0.55), 1.5)


func _draw_eyes(o: Vector2, look: Vector2, spacing: float, size: float, iris: Color = Color(0.08, 0.06, 0.08), angry: bool = false) -> void:
	var side: Vector2 = Vector2(spacing, 0)
	for s: float in [-1.0, 1.0]:
		var eye: Vector2 = o + side * s + Vector2(0, -size * 0.3)
		draw_circle(eye, size, Color(1, 1, 1))
		draw_circle(eye + look * size * 0.4, size * 0.55, iris)
		if angry:
			draw_line(eye + Vector2(-size * 1.1 * s, -size * 1.5), eye + Vector2(size * 0.9 * s, -size * 0.9), Color(0.1, 0.05, 0.05), maxf(1.2, size * 0.45))


func _draw_details(o: Vector2, t: float, look: Vector2, body: Color) -> void:
	var r: float = radius
	match type_id:
		EnemyTypes.GRUNT:
			_draw_eyes(o, look, r * 0.32, r * 0.24, Color(0.08, 0.06, 0.08), true)
			draw_line(o + Vector2(-r * 0.25, r * 0.38), o + Vector2(r * 0.25, r * 0.38), Color(0.2, 0.02, 0.02), 1.5)
		EnemyTypes.RUNNER:
			var eye: Vector2 = o + look * r * 0.25
			draw_circle(eye, r * 0.22, Color.WHITE)
			draw_circle(eye + look * r * 0.08, r * 0.12, Color(0.1, 0.08, 0.05))
		EnemyTypes.SWARMLING:
			var flap: float = absf(sin(t * 30.0))
			for s: float in [-1.0, 1.0]:
				draw_set_transform(o + Vector2(s * r * 0.9, -r * 0.5), s * (0.5 + 0.6 * flap), Vector2(1.0, 0.45))
				draw_circle(Vector2.ZERO, r * 0.75, Color(0.85, 1.0, 0.85, 0.55))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_circle(o + Vector2(0, -r * 0.1), r * 0.45, Color.WHITE)
			draw_circle(o + Vector2(0, -r * 0.1) + look * r * 0.18, r * 0.25, Color(0.1, 0.1, 0.1))
		EnemyTypes.TANK:
			# Treads that roll as it moves, and a visor slit.
			for s: float in [-1.0, 1.0]:
				var tread: Rect2 = Rect2(o + Vector2(-r * 1.15, s * r * 0.95 - r * 0.22), Vector2(r * 2.3, r * 0.44))
				draw_rect(tread, Color(0.15, 0.13, 0.17))
				var shift: float = fmod(t * 14.0, r * 0.5)
				var x: float = tread.position.x + shift
				while x < tread.end.x:
					draw_line(Vector2(x, tread.position.y), Vector2(x, tread.end.y), Color(0.35, 0.32, 0.38), 1.0)
					x += r * 0.5
			draw_rect(Rect2(o + Vector2(-r * 0.55, -r * 0.35), Vector2(r * 1.1, r * 0.3)), Color(0.12, 0.05, 0.15))
			draw_rect(Rect2(o + Vector2(-r * 0.45 + (look.x * r * 0.25), -r * 0.3), Vector2(r * 0.4, r * 0.2)), Color(1.0, 0.4, 0.3))
		EnemyTypes.MENDER:
			var beat: float = 1.0 + 0.15 * sin(t * 6.0)
			draw_rect(Rect2(o + Vector2(-r * 0.16, -r * 0.5) * beat, Vector2(r * 0.32, r) * beat), Color(1, 1, 1, 0.95))
			draw_rect(Rect2(o + Vector2(-r * 0.5, -r * 0.16) * beat, Vector2(r, r * 0.32) * beat), Color(1, 1, 1, 0.95))
		EnemyTypes.SPLITTER:
			# The brood inside, wiggling.
			for i in 3:
				var a: float = TAU * i / 3.0 + t * 2.0
				draw_circle(o + Vector2.RIGHT.rotated(a) * r * 0.42, r * 0.24, body.lightened(0.35))
				draw_circle(o + Vector2.RIGHT.rotated(a) * r * 0.42 + look * r * 0.06, r * 0.09, Color(0.1, 0.05, 0.0))
			draw_arc(o, r * 0.82, 0.0, TAU, 24, body.darkened(0.45), 1.5)
		EnemyTypes.AEGIS:
			_draw_eyes(o, look, r * 0.3, r * 0.2, Color(0.15, 0.1, 0.5))
			draw_circle(o + Vector2(0, r * 0.38), r * 0.16, Color(0.9, 0.95, 1.0))
		EnemyTypes.BOSS:
			# Horns, crown spikes and glowing eyes.
			for s: float in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([o + Vector2(s * r * 0.35, -r * 0.45), o + Vector2(s * r * 0.95, -r * 1.25), o + Vector2(s * r * 0.6, -r * 0.3)]), Color(0.9, 0.85, 0.75))
			var glow: float = 0.6 + 0.4 * sin(t * 5.0)
			for s: float in [-1.0, 1.0]:
				var eye: Vector2 = o + Vector2(s * r * 0.28, -r * 0.08) + look * r * 0.06
				draw_circle(eye, r * 0.2, Color(1.0, 0.3, 0.1, 0.35 * glow))
				draw_circle(eye, r * 0.11, Color(1.0, 0.85, 0.3))
			draw_line(o + Vector2(-r * 0.3, r * 0.32), o + Vector2(r * 0.3, r * 0.32), Color(0.1, 0.0, 0.0), 2.5)
			for i in 4:
				var x: float = -r * 0.22 + r * 0.147 * i
				draw_colored_polygon(PackedVector2Array([o + Vector2(x - r * 0.05, r * 0.32), o + Vector2(x + r * 0.05, r * 0.32), o + Vector2(x, r * 0.45)]), Color(0.95, 0.95, 0.9))


## Armor plates (white segments) and the shield bubble (purple shimmer).
func _draw_defenses(o: Vector2, t: float) -> void:
	if armor > 0.0:
		var plates: int = 6 if radius < 18.0 else 10
		var gap: float = 0.18
		for i in plates:
			var a0: float = TAU * i / plates + gap
			draw_arc(o, radius + 3.0, a0, a0 + TAU / plates - gap * 2.0, 6, LAYER_COLORS["armor"], 2.5)
	if shield > 0.0:
		var shield_color: Color = LAYER_COLORS["shield"]
		draw_circle(o, radius + 6.0, Color(shield_color, 0.13))
		draw_arc(o, radius + 6.0, 0.0, TAU, 32, Color(shield_color, 0.7), 1.5)
		var a: float = t * 2.5
		draw_arc(o, radius + 6.0, a, a + 1.1, 10, Color(shield_color.lightened(0.5), 0.95), 2.5)


## Stacked bars, one per layer the enemy has: shield on top, armor, then health.
func _draw_layer_bars() -> void:
	var layers: Array = []
	if max_shield > 0.0:
		layers.append(["shield", shield, max_shield])
	if max_armor > 0.0:
		layers.append(["armor", armor, max_armor])
	layers.append(["health", health, max_health])
	# Big enemies (bosses) get proportionally wider and thicker bars.
	var bar_width: float = maxf(HEALTH_BAR_WIDTH, radius * 3.4)
	var bar_height: float = HEALTH_BAR_HEIGHT * (2.0 if radius > 18.0 else 1.0)
	var stack_height: float = layers.size() * (bar_height + HEALTH_BAR_GAP)
	var top: float = radius + (8.0 if max_shield > 0.0 else 6.0) + (radius * 0.3 if type_id == EnemyTypes.BOSS else 0.0)
	var origin: Vector2 = _draw_offset + Vector2(-bar_width / 2.0, -top - stack_height)
	draw_rect(Rect2(origin - Vector2(1, 1), Vector2(bar_width + 2, stack_height + 1)), Color(0.05, 0.05, 0.07, 0.85))
	for i in layers.size():
		var layer: Array = layers[i]
		var ratio: float = clampf(layer[1] / layer[2], 0.0, 1.0) if layer[2] > 0.0 else 0.0
		var row: Vector2 = origin + Vector2(0, i * (bar_height + HEALTH_BAR_GAP))
		var color: Color = LAYER_COLORS[layer[0]]
		if layer[0] == "health" and regen_rate > 0.0:
			color = Color(0.3, 0.95, 0.75)
		draw_rect(Rect2(row, Vector2(bar_width, bar_height)), Color(color, 0.18))
		draw_rect(Rect2(row, Vector2(bar_width * ratio, bar_height)), color)


func _shape_points(o: Vector2 = Vector2.ZERO) -> PackedVector2Array:
	var r: float = radius
	match shape:
		"triangle":
			return PackedVector2Array([o + Vector2(r, 0), o + Vector2(-r * 0.8, -r * 0.8), o + Vector2(-r * 0.8, r * 0.8)])
		"square":
			return PackedVector2Array([o + Vector2(-r, -r), o + Vector2(r, -r), o + Vector2(r, r), o + Vector2(-r, r)])
		"hexagon":
			return _regular_polygon(o, 6, r, 0.0)
		"pentagon":
			return _regular_polygon(o, 5, r, -PI / 2.0)
		"star":
			var star: PackedVector2Array = PackedVector2Array()
			for i in 10:
				var point_radius: float = r if i % 2 == 0 else r * 0.55
				star.append(o + Vector2.UP.rotated(TAU * i / 10.0) * point_radius)
			return star
		_:
			return PackedVector2Array([o + Vector2(0, -r), o + Vector2(r, 0), o + Vector2(0, r), o + Vector2(-r, 0)])


func _regular_polygon(o: Vector2, sides: int, r: float, rotation_offset: float) -> PackedVector2Array:
	var points: PackedVector2Array = PackedVector2Array()
	for i in sides:
		points.append(o + Vector2.RIGHT.rotated(rotation_offset + TAU * i / sides) * r)
	return points
