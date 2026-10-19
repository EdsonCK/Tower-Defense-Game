class_name Tower
extends Node2D


func _draw() -> void:
	draw_rect(Rect2(-13, -13, 26, 26), Color("17688e"))
	draw_rect(Rect2(-13, -13, 26, 26), Color("65d8f5"), false, 2.0)
	draw_circle(Vector2.ZERO, 7, Color("8beaff"))
