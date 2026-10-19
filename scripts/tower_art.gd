class_name TowerArt
extends RefCounted
## Stone plinths, brass fittings, crystal facets and directional iron weapons.

static func draw_tower(c: CanvasItem, kind: int, aim: float = -PI / 2.0, recoil: float = 0.0) -> void:
	var accent: Color = TowerCatalog.DATA[kind].color
	DrawKit.ellipse(c, Vector2(1, 10), Vector2(16, 7), Color(0.01, 0.02, 0.04, 0.65))
	DrawKit.poly(c, PackedVector2Array([Vector2(-13, -9), Vector2(-8, -14), Vector2(9, -14), Vector2(14, -8), Vector2(14, 9), Vector2(8, 14), Vector2(-9, 14), Vector2(-14, 8)]), Color("3a454e"), DrawKit.INK, 2.3)
	DrawKit.poly(c, PackedVector2Array([Vector2(-11, -8), Vector2(-7, -12), Vector2(8, -12), Vector2(12, -7), Vector2(12, 7), Vector2(7, 11), Vector2(-8, 11), Vector2(-12, 6)]), Color("657078"), Color("b0b6af"), 1)
	c.draw_line(Vector2(-10, 8), Vector2(8, 8), Color("36414c"), 2, true)
	c.draw_line(Vector2(-10, -5), Vector2(-5, -10), Color("c6c2a6"), 1.3, true)
	for x in [-9, 9]:
		c.draw_circle(Vector2(x, 7), 1.5, Color("d4ae72"))
	DrawKit.ellipse(c, Vector2(0, -1), Vector2(10, 10), Color("24313e"), DrawKit.INK, 2)
	match kind:
		0:
			c.draw_arc(Vector2(0, -1), 8, 0, TAU, 24, Color("c3a46d"), 2, true)
			_weapon(c, aim, recoil, false)
		1:
			for y in [3, -1, -5]:
				DrawKit.ellipse(c, Vector2(0, y), Vector2(8, 3), Color("8c719b"), DrawKit.INK, 1.5)
				c.draw_line(Vector2(-6, y - 1), Vector2(5, y - 1), Color("dcc696"), 1.2, true)
			for side in [-1, 1]:
				c.draw_polyline(PackedVector2Array([Vector2(side * 9, 3), Vector2(side * 10, -9), Vector2(side * 5, -12)]), DrawKit.INK, 4, true)
				c.draw_polyline(PackedVector2Array([Vector2(side * 9, 3), Vector2(side * 10, -9), Vector2(side * 5, -12)]), Color("ceb98c"), 1.8, true)
			DrawKit.gem(c, Vector2(0, -10), 6, accent)
			c.draw_circle(Vector2(0, -11), 2, Color("f1edff"))
		2:
			DrawKit.ellipse(c, Vector2(0, 2), Vector2(10, 6), Color("976847"), DrawKit.INK, 2)
			DrawKit.poly(c, PackedVector2Array([Vector2(-7, 3), Vector2(-9, -8), Vector2(-5, -14), Vector2(6, -14), Vector2(10, -8), Vector2(6, 3)]), Color("4c5560"), DrawKit.INK, 2)
			DrawKit.ellipse(c, Vector2(0, -10), Vector2(8, 5), Color("b78655"), DrawKit.INK, 2)
			DrawKit.ellipse(c, Vector2(0, -10), Vector2(5, 3), Color("191e2b"))
			c.draw_line(Vector2(-5, -1), Vector2(5, -1), Color("efae6b"), 2.5, true)
		3:
			for side in [-1, 1]:
				DrawKit.gem(c, Vector2(side * 7, -2), 6, Color("4b94b9"))
			DrawKit.poly(c, PackedVector2Array([Vector2(0, -18), Vector2(6, -6), Vector2(4, 4), Vector2(-4, 4), Vector2(-6, -6)]), accent, DrawKit.INK, 2)
			DrawKit.poly(c, PackedVector2Array([Vector2(0, -17), Vector2(-3, -5), Vector2(0, 2), Vector2(1, -6)]), Color("d3fcff"), Color("b4f7ff"), 0.7)
			c.draw_arc(Vector2.ZERO, 9, 0.2, 2.9, 18, Color("bdeaf1"), 1.5, true)
		4:
			DrawKit.ellipse(c, Vector2(0, 2), Vector2(11, 6), Color("605747"), DrawKit.INK, 2)
			for x in [-8, 8]:
				DrawKit.ellipse(c, Vector2(x, 4), Vector2(3, 6), Color("5d6258"), DrawKit.INK, 1.5)
				c.draw_line(Vector2(x, 0), Vector2(x, 8), Color("aea67e"), 1.5, true)
			_weapon(c, aim, recoil, true)


static func _weapon(c: CanvasItem, aim: float, recoil: float, cannon: bool) -> void:
	var forward := Vector2.from_angle(aim)
	var side := forward.orthogonal()
	var base := Vector2(0, -2) - forward * recoil * 3
	var length := 15.0 if cannon else 13.0
	var half := 4.0 if cannon else 2.8
	DrawKit.poly(c, PackedVector2Array([base - forward * 4 - side * half, base + forward * length - side * half, base + forward * length + side * half, base - forward * 4 + side * half]), Color("485361") if cannon else Color("896d4e"), DrawKit.INK, 2)
	c.draw_line(base - side * half, base + forward * (length - 2) - side * half, Color("c6c8b0"), 1.4, true)
	c.draw_line(base + forward * (length - 2) - side * (half + 1), base + forward * (length - 2) + side * (half + 1), Color("b99764"), 2.8, true)
	c.draw_circle(base, 4.5, Color("8b784f"))
	c.draw_circle(base + Vector2(-1, -1), 1.8, Color("e8d2a0"))
