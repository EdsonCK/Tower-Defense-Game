class_name MapMarkers
extends Node2D
## The gate (a small stone keep on its plaza, with a waving banner and a lit doorway)
## and the entrance portals (swirling rifts in a ring of standing stones). Animated at a
## modest frame rate; there are only a handful of them.

const FPS: float = 24.0
const STONE: Color = Color(0.6, 0.6, 0.63)
const STONE_DARK: Color = Color(0.38, 0.38, 0.42)
const ROOF: Color = Color(0.25, 0.42, 0.8)
const BANNER: Color = Color(0.3, 0.55, 1.0)
const RIFT: Color = Color(0.75, 0.15, 0.3)
const RIFT_GLOW: Color = Color(1.0, 0.45, 0.55)

var board: Board
var _time: float = 0.0
var _frame: int = -1


func _process(delta: float) -> void:
	_time += delta
	var frame: int = int(_time * FPS)
	if frame != _frame:
		_frame = frame
		queue_redraw()


func _draw() -> void:
	if board == null:
		return
	for cell: Vector2i in board.entrances():
		_draw_portal(Board.cell_to_world(cell), cell)
	_draw_keep(Board.cell_to_world(board.exit_cell()))


func _draw_portal(p: Vector2, cell: Vector2i) -> void:
	var t: float = _time + float(cell.x * 3 + cell.y)
	var pulse: float = 0.5 + 0.5 * sin(t * 3.0)
	# Glow and ring of standing stones.
	draw_circle(p, 17.0 + pulse * 2.0, Color(RIFT_GLOW, 0.12))
	for i in 7:
		var a: float = TAU * i / 7.0 + 0.3
		var q: Vector2 = p + Vector2(cos(a), sin(a) * 0.8) * 14.0
		draw_circle(q + Vector2(1, 1.5), 2.6, Color(0, 0, 0, 0.3))
		draw_circle(q, 2.6, STONE_DARK)
		draw_circle(q + Vector2(-0.6, -0.7), 1.7, STONE)
		draw_circle(q, 1.0, Color(RIFT_GLOW, 0.4 + 0.5 * pulse))
	# The rift: a dark core with spiral arms turning inward.
	draw_circle(p, 10.0, RIFT.darkened(0.6))
	for arm in 3:
		var pts: PackedVector2Array = PackedVector2Array()
		for k in 12:
			var f: float = float(k) / 11.0
			var a: float = -t * 2.2 + TAU * arm / 3.0 + f * 3.2
			pts.append(p + Vector2.RIGHT.rotated(a) * (10.0 * (1.0 - f) + 1.0))
		draw_polyline(pts, Color(RIFT_GLOW, 0.85), 1.6)
	draw_circle(p, 3.0 + pulse * 1.2, Color(1.0, 0.8, 0.85, 0.9))
	draw_arc(p, 10.5, 0.0, TAU, 28, Color(RIFT, 0.9), 1.5)


func _draw_keep(p: Vector2) -> void:
	draw_set_transform(p, 0.0, Vector2.ONE * 1.3)
	_draw_keep_body(Vector2.ZERO)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_keep_body(p: Vector2) -> void:
	# Shadow and foundation.
	var shadow: PackedVector2Array = PackedVector2Array()
	for i in 24:
		shadow.append(p + Vector2(4, 12) + Vector2(cos(TAU * i / 24.0) * 26.0, sin(TAU * i / 24.0) * 10.0))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.28))
	# Curtain wall with crenellations.
	var wall: Rect2 = Rect2(p + Vector2(-16, -9), Vector2(32, 21))
	draw_rect(wall, STONE_DARK)
	draw_rect(Rect2(wall.position, Vector2(wall.size.x, 4)), STONE)
	for i in 4:
		draw_rect(Rect2(wall.position + Vector2(2 + i * 8, -4), Vector2(5, 5)), STONE)
	for row in 3:
		for k in 4:
			var x: float = wall.position.x + 1 + k * 8 + (4 if row % 2 == 1 else 0)
			draw_line(Vector2(x, wall.position.y + 5 + row * 5), Vector2(x, wall.position.y + 9 + row * 5), Color(0, 0, 0, 0.18), 1.0)
	# Gate: arched doorway with a warm flicker.
	var flicker: float = 0.75 + 0.25 * sin(_time * 9.0) * sin(_time * 5.3)
	var door: PackedVector2Array = PackedVector2Array()
	for i in 9:
		door.append(p + Vector2(-cos(PI * i / 8.0) * 6.0, 2.0 - sin(PI * i / 8.0) * 6.0))
	door.append(p + Vector2(6, 12))
	door.append(p + Vector2(-6, 12))
	draw_colored_polygon(door, Color(0.16, 0.1, 0.07))
	draw_circle(p + Vector2(0, 7), 5.5, Color(1.0, 0.65, 0.25, 0.35 * flicker))
	for i in 3:
		draw_line(p + Vector2(-4 + i * 4, -2), p + Vector2(-4 + i * 4, 12), Color(0.3, 0.3, 0.33), 1.0)
	# Two round towers with conical roofs.
	for side: float in [-1.0, 1.0]:
		var c: Vector2 = p + Vector2(side * 17.0, -2.0)
		draw_rect(Rect2(c + Vector2(-6, -6), Vector2(12, 19)), STONE_DARK)
		draw_rect(Rect2(c + Vector2(-6, -6), Vector2(5, 19)), STONE)
		draw_rect(Rect2(c + Vector2(-1.5, 0), Vector2(3, 4)), Color(0.15, 0.1, 0.08))
		draw_rect(Rect2(c + Vector2(-1.5, 0), Vector2(3, 4)), Color(1.0, 0.75, 0.3, 0.5 * flicker))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -6), c + Vector2(0, -19), c + Vector2(8, -6)]), ROOF.darkened(0.25))
		draw_colored_polygon(PackedVector2Array([c + Vector2(-8, -6), c + Vector2(0, -19), c + Vector2(0, -6)]), ROOF)
	# Banner on the left tower, waving.
	var pole: Vector2 = p + Vector2(-17, -19)
	draw_line(pole, pole + Vector2(0, -11), Color(0.25, 0.2, 0.15), 1.5)
	var flag: PackedVector2Array = PackedVector2Array()
	for i in 6:
		var x: float = i * 2.6
		flag.append(pole + Vector2(x, -11 + sin(_time * 6.0 - i * 0.9) * 1.4 * (i / 5.0)))
	for i in range(5, -1, -1):
		var x: float = i * 2.6
		flag.append(pole + Vector2(x, -5 + sin(_time * 6.0 - i * 0.9) * 1.4 * (i / 5.0)))
	draw_colored_polygon(flag, BANNER)
