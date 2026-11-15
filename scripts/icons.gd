class_name Icons
extends RefCounted
## Small procedural glyphs (no image assets) drawn with CanvasItem primitives, used by
## the skill tree and HUD. `draw(ci, kind, center, r, color)` fits the glyph in a circle of
## radius `r`.

const KINDS: Array[String] = [
	"bolt", "chevrons", "arrow", "star", "crown", "battery", "cannon", "burst", "coin",
	"chest", "gear", "flag", "crosshair", "shield", "skull", "drop", "wave", "heart",
	"clock", "diamond", "lock", "check",
]


static func draw(ci: CanvasItem, kind: String, c: Vector2, r: float, color: Color) -> void:
	var w: float = maxf(1.5, r * 0.16)
	var dark: Color = Color(0, 0, 0, 0.55)
	match kind:
		"bolt":
			_poly(ci, c, r, [Vector2(0.15, -1), Vector2(-0.55, 0.1), Vector2(-0.05, 0.1), Vector2(-0.2, 1), Vector2(0.55, -0.15), Vector2(0.05, -0.15)], color)
		"chevrons":
			for i in 2:
				var y: float = 0.15 + 0.55 * i - 0.45
				ci.draw_polyline(_pts(c, r, [Vector2(-0.65, y + 0.35), Vector2(0, y - 0.25), Vector2(0.65, y + 0.35)]), color, w * 1.3, true)
		"arrow":
			ci.draw_line(c + Vector2(-0.75, 0.75) * r, c + Vector2(0.45, -0.45) * r, color, w * 1.2, true)
			_poly(ci, c, r, [Vector2(0.8, -0.8), Vector2(0.15, -0.6), Vector2(0.6, -0.15)], color)
			ci.draw_line(c + Vector2(-0.75, 0.75) * r, c + Vector2(-0.75, 0.35) * r, color, w, true)
			ci.draw_line(c + Vector2(-0.75, 0.75) * r, c + Vector2(-0.35, 0.75) * r, color, w, true)
		"star":
			var pts: Array[Vector2] = []
			for i in 10:
				var rad: float = 1.0 if i % 2 == 0 else 0.42
				pts.append(Vector2.UP.rotated(TAU * i / 10.0) * rad)
			_poly(ci, c, r, pts, color)
		"crown":
			_poly(ci, c, r, [Vector2(-0.85, 0.55), Vector2(-0.85, -0.45), Vector2(-0.4, 0.05), Vector2(0, -0.75), Vector2(0.4, 0.05), Vector2(0.85, -0.45), Vector2(0.85, 0.55)], color)
			ci.draw_rect(Rect2(c + Vector2(-0.85, 0.62) * r, Vector2(1.7, 0.22) * r), color)
		"battery":
			ci.draw_rect(Rect2(c + Vector2(-0.45, -0.7) * r, Vector2(0.9, 1.5) * r), color, false, w)
			ci.draw_rect(Rect2(c + Vector2(-0.18, -0.88) * r, Vector2(0.36, 0.18) * r), color)
			for i in 3:
				ci.draw_rect(Rect2(c + Vector2(-0.28, 0.4 - 0.42 * i) * r, Vector2(0.56, 0.26) * r), color)
		"cannon":
			ci.draw_circle(c + Vector2(0.1, 0.1) * r, r * 0.62, color)
			ci.draw_circle(c + Vector2(-0.12, -0.12) * r, r * 0.18, Color(1, 1, 1, 0.55))
			ci.draw_line(c + Vector2(0.45, -0.45) * r, c + Vector2(0.8, -0.85) * r, color, w * 1.4, true)
		"burst":
			for i in 8:
				var d: Vector2 = Vector2.RIGHT.rotated(TAU * i / 8.0 + 0.2)
				ci.draw_line(c + d * r * 0.35, c + d * r * (0.95 if i % 2 == 0 else 0.7), color, w * 1.2, true)
			ci.draw_circle(c, r * 0.26, color)
		"coin":
			ci.draw_circle(c, r * 0.82, color)
			ci.draw_arc(c, r * 0.6, 0.0, TAU, 24, dark, w * 0.8, true)
			ci.draw_rect(Rect2(c + Vector2(-0.1, -0.38) * r, Vector2(0.2, 0.76) * r), dark)
		"chest":
			ci.draw_rect(Rect2(c + Vector2(-0.8, -0.2) * r, Vector2(1.6, 0.9) * r), color)
			_poly(ci, c, r, [Vector2(-0.8, -0.25), Vector2(-0.6, -0.7), Vector2(0.6, -0.7), Vector2(0.8, -0.25)], color.darkened(0.15))
			ci.draw_rect(Rect2(c + Vector2(-0.12, -0.35) * r, Vector2(0.24, 0.4) * r), dark)
		"gear":
			for i in 8:
				var d: Vector2 = Vector2.RIGHT.rotated(TAU * i / 8.0)
				ci.draw_line(c + d * r * 0.5, c + d * r * 0.92, color, w * 2.0)
			ci.draw_circle(c, r * 0.62, color)
			ci.draw_circle(c, r * 0.25, dark)
		"flag":
			ci.draw_line(c + Vector2(-0.6, 0.9) * r, c + Vector2(-0.6, -0.85) * r, color, w * 1.1, true)
			_poly(ci, c, r, [Vector2(-0.55, -0.85), Vector2(0.8, -0.5), Vector2(-0.55, -0.1)], color)
		"crosshair":
			ci.draw_arc(c, r * 0.62, 0.0, TAU, 28, color, w, true)
			for d: Vector2 in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				ci.draw_line(c + d * r * 0.3, c + d * r * 0.98, color, w, true)
			ci.draw_circle(c, r * 0.12, color)
		"shield":
			_poly(ci, c, r, [Vector2(0, -0.9), Vector2(0.75, -0.6), Vector2(0.65, 0.2), Vector2(0, 0.92), Vector2(-0.65, 0.2), Vector2(-0.75, -0.6)], color)
			ci.draw_line(c + Vector2(0, -0.6) * r, c + Vector2(0, 0.6) * r, dark, w * 0.8)
		"skull":
			ci.draw_circle(c + Vector2(0, -0.15) * r, r * 0.68, color)
			ci.draw_rect(Rect2(c + Vector2(-0.38, 0.3) * r, Vector2(0.76, 0.5) * r), color)
			ci.draw_circle(c + Vector2(-0.27, -0.15) * r, r * 0.19, dark)
			ci.draw_circle(c + Vector2(0.27, -0.15) * r, r * 0.19, dark)
			for i in 3:
				ci.draw_line(c + Vector2(-0.2 + 0.2 * i, 0.5) * r, c + Vector2(-0.2 + 0.2 * i, 0.8) * r, dark, w * 0.6)
		"drop":
			ci.draw_circle(c + Vector2(0, 0.25) * r, r * 0.58, color)
			_poly(ci, c, r, [Vector2(0, -0.95), Vector2(0.52, 0.05), Vector2(-0.52, 0.05)], color)
			ci.draw_circle(c + Vector2(-0.2, 0.25) * r, r * 0.14, Color(1, 1, 1, 0.5))
		"wave":
			for row in 3:
				var pts: Array[Vector2] = []
				for i in 9:
					var x: float = -0.85 + 1.7 * i / 8.0
					pts.append(Vector2(x, -0.5 + 0.5 * row + 0.16 * sin(x * 7.0)))
				ci.draw_polyline(_pts(c, r, pts), color, w, true)
		"heart":
			ci.draw_circle(c + Vector2(-0.36, -0.25) * r, r * 0.42, color)
			ci.draw_circle(c + Vector2(0.36, -0.25) * r, r * 0.42, color)
			_poly(ci, c, r, [Vector2(-0.76, -0.1), Vector2(0.76, -0.1), Vector2(0, 0.85)], color)
		"clock":
			ci.draw_arc(c, r * 0.8, 0.0, TAU, 28, color, w * 1.1, true)
			ci.draw_line(c, c + Vector2(0, -0.55) * r, color, w, true)
			ci.draw_line(c, c + Vector2(0.4, 0.15) * r, color, w, true)
		"diamond":
			_poly(ci, c, r, [Vector2(-0.8, -0.3), Vector2(-0.45, -0.75), Vector2(0.45, -0.75), Vector2(0.8, -0.3), Vector2(0, 0.85)], color)
			ci.draw_polyline(_pts(c, r, [Vector2(-0.8, -0.3), Vector2(0.8, -0.3)]), dark, w * 0.6)
			ci.draw_polyline(_pts(c, r, [Vector2(-0.25, -0.3), Vector2(0, 0.85), Vector2(0.25, -0.3)]), dark, w * 0.6)
		"lock":
			ci.draw_arc(c + Vector2(0, -0.2) * r, r * 0.38, PI, TAU, 14, color, w * 1.2)
			ci.draw_rect(Rect2(c + Vector2(-0.6, -0.2) * r, Vector2(1.2, 0.95) * r), color)
			ci.draw_circle(c + Vector2(0, 0.22) * r, r * 0.13, dark)
		"check":
			ci.draw_polyline(_pts(c, r, [Vector2(-0.6, 0.0), Vector2(-0.15, 0.48), Vector2(0.65, -0.45)]), color, w * 1.6, true)
		_:
			ci.draw_circle(c, r * 0.6, color)


static func _pts(c: Vector2, r: float, unit: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p: Vector2 in unit:
		out.append(c + p * r)
	return out


static func _poly(ci: CanvasItem, c: Vector2, r: float, unit: Array, color: Color) -> void:
	var pts: PackedVector2Array = _pts(c, r, unit)
	if Geometry2D.triangulate_polygon(pts).is_empty():
		return  # degenerate polygon: skip rather than error
	ci.draw_colored_polygon(pts, color)
