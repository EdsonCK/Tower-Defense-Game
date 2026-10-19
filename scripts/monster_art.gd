class_name MonsterArt
extends RefCounted
## Five hand-built silhouettes: imp, skitter, ogre, shaman and wraith.

static func draw_monster(c: CanvasItem, kind: int, time: float, flash: float = 0.0) -> void:
	var gait := sin(time * (12.0 if kind == 1 else 6.0))
	DrawKit.ellipse(c, Vector2(0, 10), Vector2(13, 5), Color(0.015, 0.025, 0.04, 0.65))
	match kind:
		0: _imp(c, gait)
		1: _skitter(c, gait)
		2: _ogre(c, gait)
		3: _shaman(c, time)
		4: _wraith(c, time)
	if flash > 0:
		c.draw_arc(Vector2.ZERO, 13, -2.5, 0.5, 16, Color(1, 0.94, 0.76, flash), 2, true)


static func _imp(c: CanvasItem, gait: float) -> void:
	# Curled tail, bent claws, short legs and cream horns remain readable in packs.
	c.draw_polyline(PackedVector2Array([Vector2(6, 6), Vector2(15, 8), Vector2(16, 2), Vector2(12, 0)]), DrawKit.INK, 5, true)
	c.draw_polyline(PackedVector2Array([Vector2(6, 6), Vector2(15, 8), Vector2(16, 2), Vector2(12, 0)]), Color("ca684f"), 2, true)
	for side in [-1, 1]:
		DrawKit.poly(c, PackedVector2Array([Vector2(side * 4, 5), Vector2(side * 9, 10 + gait * side), Vector2(side * 2, 11 + gait * side)]), Color("633c43"))
		DrawKit.poly(c, PackedVector2Array([Vector2(side * 7, -2), Vector2(side * 13, 3), Vector2(side * 10, 7), Vector2(side * 8, 2)]), Color("d16b51"))
		c.draw_line(Vector2(side * 12, 4), Vector2(side * 14, 6), DrawKit.BONE, 1.4, true)
	DrawKit.ellipse(c, Vector2(0, 1), Vector2(8, 10), Color("a44542"), DrawKit.INK, 2.5)
	DrawKit.ellipse(c, Vector2(0, -4), Vector2(9, 8), Color("ee8c62"), DrawKit.INK, 2.5)
	for side in [-1, 1]:
		DrawKit.poly(c, PackedVector2Array([Vector2(side * 5, -9), Vector2(side * 10, -16), Vector2(side * 10, -7)]), DrawKit.BONE)
		DrawKit.poly(c, PackedVector2Array([Vector2(side * 7, -7), Vector2(side * 15, -8), Vector2(side * 9, -2)]), Color("a44242"))
		c.draw_line(Vector2(side * 2, -5), Vector2(side * 6, -6), DrawKit.INK, 3, true)
		c.draw_circle(Vector2(side * 4, -4), 1.5, Color("ffe7a1"))
	DrawKit.poly(c, PackedVector2Array([Vector2(-5, 1), Vector2(5, 1), Vector2(3, 5), Vector2(-3, 5)]), Color("3d2735"), DrawKit.INK, 1)
	for x in [-3, 2]:
		DrawKit.poly(c, PackedVector2Array([Vector2(x, 1), Vector2(x + 2, 1), Vector2(x + 1, 4)]), DrawKit.BONE, DrawKit.BONE, 0.5)
	c.draw_line(Vector2(-4, 7), Vector2(4, 7), Color("e3ae67"), 2, true)


static func _skitter(c: CanvasItem, gait: float) -> void:
	for side in [-1, 1]:
		for i in range(3):
			var y := -6.0 + i * 6
			var points := PackedVector2Array([Vector2(side * 5, y), Vector2(side * (12 + gait * (i % 2 * 2 - 1)), y - 3), Vector2(side * 15, y + 4)])
			c.draw_polyline(points, DrawKit.INK, 4.5, true)
			c.draw_polyline(points, Color("daac56"), 1.8, true)
	DrawKit.poly(c, PackedVector2Array([Vector2(0, 12), Vector2(-8, 5), Vector2(-7, -5), Vector2(0, -12), Vector2(7, -5), Vector2(8, 5)]), Color("7e4b35"), DrawKit.INK, 2.5)
	for i in range(3):
		var y := 5.0 - i * 5
		DrawKit.poly(c, PackedVector2Array([Vector2(-6, y), Vector2(0, y - 3), Vector2(6, y), Vector2(0, y + 3)]), Color("e3a34e"), Color("4f3532"), 1.3)
	c.draw_line(Vector2.ZERO, Vector2(0, -9), Color("ffdc81"), 1.5, true)
	for side in [-1, 1]:
		c.draw_line(Vector2(side * 3, -9), Vector2(side * 6, -15), DrawKit.INK, 3, true)
		c.draw_circle(Vector2(side * 5, -10), 2.2, Color("ecf8ae"))
		c.draw_circle(Vector2(side * 5, -10), 0.8, DrawKit.INK)
		DrawKit.poly(c, PackedVector2Array([Vector2(side * 4, -12), Vector2(side * 3, -17), Vector2(side * 8, -13)]), DrawKit.BONE)


static func _ogre(c: CanvasItem, gait: float) -> void:
	for side in [-1, 1]:
		DrawKit.ellipse(c, Vector2(side * 7, 10 + gait * side), Vector2(5, 3), Color("32384b"), DrawKit.INK, 2)
		DrawKit.poly(c, PackedVector2Array([Vector2(side * 7, -5), Vector2(side * 15, -6), Vector2(side * 16, 5), Vector2(side * 11, 8)]), Color("667486"), DrawKit.INK, 2.5)
		DrawKit.poly(c, PackedVector2Array([Vector2(side * 11, -5), Vector2(side * 14, -12), Vector2(side * 16, -3)]), DrawKit.BONE)
	DrawKit.poly(c, PackedVector2Array([Vector2(-9, -10), Vector2(9, -10), Vector2(11, 6), Vector2(6, 11), Vector2(-6, 11), Vector2(-11, 6)]), Color("62747e"), DrawKit.INK, 3)
	for side in [-1, 1]:
		DrawKit.poly(c, PackedVector2Array([Vector2(side, -1), Vector2(side * 8, -2), Vector2(side * 8, 6), Vector2(side, 8)]), Color("849a9c"), Color("364454"), 1.2)
		c.draw_circle(Vector2(side * 6, 3), 1, Color("edc786"))
	DrawKit.poly(c, PackedVector2Array([Vector2(-8, -11), Vector2(0, -16), Vector2(8, -11), Vector2(7, -2), Vector2(-7, -2)]), Color("adbcb6"), DrawKit.INK, 2.5)
	c.draw_line(Vector2(-6, -8), Vector2(6, -8), DrawKit.INK, 4, true)
	c.draw_line(Vector2(-4, -8), Vector2(4, -8), Color("ffb965"), 1.4, true)
	c.draw_line(Vector2.ZERO, Vector2(0, -14), Color("d9d8bd"), 2, true)
	c.draw_line(Vector2(-4, 9), Vector2(4, 9), Color("d2aa6e"), 2.5, true)


static func _shaman(c: CanvasItem, time: float) -> void:
	for side in [-1, 1]:
		var curl := sin(time * 4 + side) * 2
		c.draw_polyline(PackedVector2Array([Vector2(side * 4, 4), Vector2(side * 9, 11), Vector2(side * 13, 8 + curl)]), DrawKit.INK, 5, true)
		c.draw_polyline(PackedVector2Array([Vector2(side * 4, 4), Vector2(side * 9, 11), Vector2(side * 13, 8 + curl)]), Color("6ba78b"), 2, true)
	DrawKit.poly(c, PackedVector2Array([Vector2(0, -9), Vector2(8, -4), Vector2(9, 11), Vector2(0, 8), Vector2(-9, 11), Vector2(-8, -4)]), Color("345b57"), DrawKit.INK, 2.5)
	DrawKit.poly(c, PackedVector2Array([Vector2(-8, -5), Vector2(-4, -14), Vector2(4, -16), Vector2(9, -5), Vector2(5, 2), Vector2(-5, 2)]), Color("628d69"), DrawKit.INK, 2.5)
	DrawKit.ellipse(c, Vector2(0, -5), Vector2(5, 6), Color("192e3c"))
	for x in [-2, 2]:
		c.draw_circle(Vector2(x, -5), 1.4, Color("a9ffbd"))
	c.draw_line(Vector2(-1, 2), Vector2(0, 9), Color("a5d895"), 1.6, true)
	c.draw_line(Vector2(11, 9), Vector2(13, -13), DrawKit.INK, 4, true)
	c.draw_line(Vector2(11, 9), Vector2(13, -13), Color("c09269"), 1.7, true)
	DrawKit.gem(c, Vector2(13, -13), 4, Color("9ff1ae"))
	c.draw_line(Vector2(-6, -14), Vector2(-10, -17), Color("a8c98b"), 2, true)


static func _wraith(c: CanvasItem, time: float) -> void:
	var sway := sin(time * 3) * 2
	DrawKit.poly(c, PackedVector2Array([Vector2(0, -15), Vector2(9, -6), Vector2(8, 7), Vector2(12, 13), Vector2(4, 9), Vector2(sway, 16), Vector2(-4, 8), Vector2(-11, 12), Vector2(-8, -6)]), Color("6c558f"), DrawKit.INK, 2.5)
	DrawKit.poly(c, PackedVector2Array([Vector2(0, -14), Vector2(6, -6), Vector2(5, 1), Vector2(0, 5), Vector2(-5, 1), Vector2(-6, -6)]), Color("b19bd1"), DrawKit.INK, 1.5)
	DrawKit.ellipse(c, Vector2(0, -4), Vector2(4, 5), Color("28283f"))
	for side in [-1, 1]:
		c.draw_line(Vector2(side, -5), Vector2(side * 3, -5), Color("fae9ff"), 1.5, true)
		c.draw_polyline(PackedVector2Array([Vector2(side * 7, -3), Vector2(side * 13, 0), Vector2(side * 15, -4)]), DrawKit.INK, 4.5, true)
		c.draw_polyline(PackedVector2Array([Vector2(side * 7, -3), Vector2(side * 13, 0), Vector2(side * 15, -4)]), Color("bba3db"), 1.5, true)
	DrawKit.gem(c, Vector2(0, 6), 3, Color("ead1ff"))
	c.draw_arc(Vector2(0, -13), 5, -PI, 0, 12, Color("efce90"), 1.5, true)
