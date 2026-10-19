class_name Board
extends Node2D
## Owns board coordinates, drawing, and (in phase B) navigation.

func cell_to_pixel(cell: Vector2i) -> Vector2:
	return Vector2(cell * GameConfig.CELL_SIZE) + Vector2.ONE * GameConfig.CELL_SIZE * 0.5


func pixel_to_cell(pixel: Vector2) -> Vector2i:
	return Vector2i(floori(pixel.x / GameConfig.CELL_SIZE), floori(pixel.y / GameConfig.CELL_SIZE))


func contains_pixel(pixel: Vector2) -> bool:
	return Rect2(Vector2.ZERO, GameConfig.BOARD_SIZE).has_point(pixel)


func _draw() -> void:
	for y in range(GameConfig.GRID_SIZE.y):
		for x in range(GameConfig.GRID_SIZE.x):
			var color := Color("243c32") if (x + y) % 2 == 0 else Color("284237")
			draw_rect(Rect2(Vector2(x, y) * GameConfig.CELL_SIZE, Vector2.ONE * GameConfig.CELL_SIZE), color)
	for x in range(GameConfig.GRID_SIZE.x + 1):
		draw_line(Vector2(x * GameConfig.CELL_SIZE, 0), Vector2(x * GameConfig.CELL_SIZE, GameConfig.BOARD_SIZE.y), Color("334d40"))
	for y in range(GameConfig.GRID_SIZE.y + 1):
		draw_line(Vector2(0, y * GameConfig.CELL_SIZE), Vector2(GameConfig.BOARD_SIZE.x, y * GameConfig.CELL_SIZE), Color("334d40"))
	draw_rect(Rect2(cell_to_pixel(GameConfig.SPAWN) - Vector2(15, 15), Vector2(30, 30)), Color("58db83"))
	draw_rect(Rect2(cell_to_pixel(GameConfig.EXIT) - Vector2(15, 15), Vector2(30, 30)), Color("f17c52"))
