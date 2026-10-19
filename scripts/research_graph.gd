class_name ResearchGraph
extends Control
## Prerequisite edges are part of the same scrolling canvas as the icon nodes.

var positions: Dictionary = {}
var owned: Array[String] = []


func _draw() -> void:
	for id in SkillCatalog.IDS:
		var parent: String = SkillCatalog.NODES[id].requires
		if parent.is_empty() or not positions.has(id):
			continue
		var start: Vector2 = positions[parent] + Vector2(0, 27)
		var end: Vector2 = positions[id] - Vector2(0, 27)
		var points := PackedVector2Array()
		for step in range(21):
			var t := step / 20.0
			points.append(start.bezier_interpolate(start + Vector2(0, 54), end - Vector2(0, 54), end, t))
		draw_polyline(points, Color("101824"), 6, true)
		draw_polyline(points, Color("8a9fa6") if owned.has(id) else Color("394858"), 2 if owned.has(id) else 1.5, true)
		if owned.has(parent):
			draw_circle(start + Vector2(0, 3), 2, Color("dabd7f"))
