class_name DrawKit
extends RefCounted
## Small vector illustration primitives shared by actors and research icons.

const INK := Color("0c101b")
const BONE := Color("ffebbc")


static func poly(canvas: CanvasItem, vertices: PackedVector2Array, fill: Color, edge: Color = INK, width: float = 2.0) -> void:
	canvas.draw_colored_polygon(vertices, fill)
	var loop := vertices.duplicate()
	loop.append(vertices[0])
	canvas.draw_polyline(loop, edge, width, true)


static func ellipse(canvas: CanvasItem, center: Vector2, radii: Vector2, color: Color, edge: Color = Color.TRANSPARENT, width: float = 1.5) -> void:
	var points := PackedVector2Array()
	for i in range(24):
		var angle := TAU * i / 24.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radii)
	canvas.draw_colored_polygon(points, color)
	if edge.a > 0.0:
		points.append(points[0])
		canvas.draw_polyline(points, edge, width, true)


static func gem(canvas: CanvasItem, center: Vector2, radius: float, color: Color) -> void:
	poly(canvas, PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius * 0.7, 0), center + Vector2(0, radius), center + Vector2(-radius * 0.7, 0)]), color)
	canvas.draw_line(center + Vector2(0, -radius + 1), center + Vector2(-radius * 0.35, 0), color.lightened(0.65), 1.5, true)


static func bolt_ring(canvas: CanvasItem, radius: float, phase: float, alpha: float = 1.0) -> void:
	var ring := PackedVector2Array()
	for i in range(65):
		var angle := TAU * i / 64.0
		var jitter := sin(i * 7.31 + phase) * 4.0 + (2.5 if i % 2 == 0 else -2.5)
		ring.append(Vector2.from_angle(angle) * (radius + jitter))
	canvas.draw_polyline(ring, Color(0.45, 0.27, 1.0, alpha * 0.22), 10.0, true)
	canvas.draw_polyline(ring, Color(0.48, 0.72, 1.0, alpha * 0.8), 3.5, true)
	canvas.draw_polyline(ring, Color(0.91, 0.96, 1.0, alpha), 1.2, true)
