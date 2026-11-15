class_name DecorLayer
extends Node2D
## Static scenery for the visible map: trees, rocks, flowers, cacti, reeds and so on,
## chosen per biome from stable per-tile hashes (so nothing flickers between redraws).
## Never placed on the path, beside it, on a tower or in a lake; tiles on a lakeshore get
## shore plants, and calm lakes get lily pads. Everything shares one look: soft-shaded
## shapes lit from the top left with soft shadows to the bottom right. Redrawn only when
## the window, biome or towers change.

const SHORE_CHANCE: float = 0.45
const LILY_CHANCE: float = 0.14

var board: Board


func _draw() -> void:
	if board == null:
		return
	var biome: Dictionary = Biomes.get_def(maxi(board.biome_index, 0))
	for item: Array in placements():
		if item[1] == "lily":
			_draw_lily(item[0], biome)
		else:
			draw_decoration(item[1], item[0], biome)


## [cell, kind] for every piece of scenery in the visible window, top row first (so
## lower pieces overlap higher ones).
func placements() -> Array:
	var out: Array = []
	if board == null:
		return out
	var biome: Dictionary = Biomes.get_def(maxi(board.biome_index, 0))
	var rect: Rect2i = board.window_rect_cells()
	var layout: MapLayout = board.layout
	var calm_water: bool = int(biome["water_style"]) in [0, 3]
	var salt: int = maxi(board.biome_index, 0) * 7
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if layout.is_path(cell) or board.is_blocked(cell):
				continue
			if layout.is_feature(cell):
				if calm_water and _interior_lake(layout, cell) and _hash01(cell, salt + 5) < LILY_CHANCE:
					out.append([cell, "lily"])
				continue
			if _next_to(layout, cell, true) or _plaza(layout, cell):
				continue
			if _next_to(layout, cell, false):
				if _hash01(cell, salt + 9) < SHORE_CHANCE:
					out.append([cell, _pick(cell, biome["shore_decorations"])])
			elif _hash01(cell, salt + 3) < float(biome["deco_density"]):
				out.append([cell, _pick(cell, biome["decorations"])])
	return out


## Draws one decoration of `kind` on `cell` in `biome`'s colors.
func draw_decoration(kind: String, cell: Vector2i, biome: Dictionary) -> void:
	var c: Dictionary = biome["deco_colors"]
	var p: Vector2 = Board.cell_to_world(cell) + Vector2(_hash01(cell, 41) - 0.5, _hash01(cell, 43) - 0.5) * 8.0
	var s: float = 0.8 + 0.4 * _hash01(cell, 47)
	match kind:
		"tree":
			_tree(p, s, cell, [c["leaf"], c["leaf_light"]], c["trunk"])
		"autumn_tree":
			_tree(p, s, cell, [c["leaf"], c["leaf_light"], c["leaf_red"]], c["trunk"])
			for i in 3:
				var q: Vector2 = p + Vector2(_hash01(cell, 140 + i) * 22.0 - 11.0, 8.0 + _hash01(cell, 150 + i) * 5.0)
				_leaf(q, 2.2, _hash01(cell, 160 + i) * TAU, c["leaf_light"] if i % 2 == 0 else c["leaf_red"])
		"bush":
			_shadow(p + Vector2(2, 5), 9.0 * s)
			for o: Vector2 in [Vector2(-5, 1), Vector2(5, 1), Vector2(0, -4), Vector2(0, 2)]:
				_ball(p + o * s, 5.5 * s, c["leaf_light"].darkened(0.1 * absf(o.y)))
			if _hash01(cell, 51) < 0.5:
				for i in 3:
					draw_circle(p + Vector2(_hash01(cell, 52 + i) * 12.0 - 6.0, _hash01(cell, 55 + i) * 8.0 - 5.0) * s, 1.4, Color(0.85, 0.15, 0.2))
		"flowers":
			for i in 5:
				var q: Vector2 = p + Vector2(_hash01(cell, 60 + i) - 0.5, _hash01(cell, 70 + i) - 0.5) * 20.0
				draw_line(q + Vector2(0, 2), q + Vector2(0.5, 7), c["leaf"], 1.2)
				var petal: Color = [c["flower_a"], c["flower_b"], c.get("flower_c", c["flower_a"])][i % 3]
				for k in 5:
					draw_circle(q + Vector2.RIGHT.rotated(TAU * k / 5.0 + i) * 2.0, 1.6, petal)
				draw_circle(q, 1.2, Color(1.0, 0.95, 0.5) if i % 3 != 0 else Color(0.55, 0.3, 0.1))
		"grass":
			_tuft(p, s, c["grass"], cell)
		"rock":
			_rock(p, s, c["rock"], cell, Color.TRANSPARENT)
		"snow_rock":
			_rock(p, s, c["rock"], cell, c["snow"])
		"cactus":
			_cactus(p, s, c, cell)
		"dry_bush":
			_shadow(p + Vector2(2, 5), 8.0 * s)
			for i in 9:
				var a: float = _hash01(cell, 80 + i) * TAU
				var r: float = (4.0 + _hash01(cell, 90 + i) * 5.0) * s
				draw_arc(p + Vector2.RIGHT.rotated(a) * r * 0.4, r * 0.6, a, a + 2.4, 6, c["dry"].lightened(0.15 * (i % 3)), 1.2)
		"bones":
			_shadow(p + Vector2(1, 4), 8.0)
			for i in 3:
				draw_arc(p + Vector2(4, 2), 4.0 + i * 2.2, PI * 1.1, PI * 1.9, 8, c["bones"].darkened(0.1 * i), 1.6)
			draw_circle(p + Vector2(-5, 0), 4.2, c["bones"].darkened(0.2))
			draw_circle(p + Vector2(-5.5, -0.5), 3.8, c["bones"])
			draw_circle(p + Vector2(-6.8, -0.5), 1.0, Color(0.2, 0.15, 0.1))
			draw_circle(p + Vector2(-4.2, -0.5), 1.0, Color(0.2, 0.15, 0.1))
		"palm":
			_palm(p, s, c, cell)
		"pine":
			_pine(p, s, c)
		"ice":
			_shadow(p + Vector2(2, 6), 8.0 * s)
			for i in 3:
				var base: Vector2 = p + Vector2(-5.0 + i * 5.0, 6.0)
				var h: float = (10.0 + _hash01(cell, 100 + i) * 8.0) * s
				var lean: float = (i - 1) * 0.25
				_crystal(base, h, 2.6 * s, lean, c["ice"])
		"lava":
			_shadow(p + Vector2(2, 5), 11.0 * s)
			var mound: PackedVector2Array = _blob(p, Vector2(11, 7) * s, cell, 9)
			draw_colored_polygon(mound, Color(0.14, 0.11, 0.11))
			draw_colored_polygon(_shift(_scale_about(mound, p, 0.75), Vector2(-1.5, -1.5)), Color(0.22, 0.18, 0.18))
			var crack: PackedVector2Array = PackedVector2Array([p + Vector2(-8, 1) * s, p + Vector2(-3, -1) * s, p + Vector2(0, 1) * s, p + Vector2(4, -2) * s, p + Vector2(8, 0) * s])
			draw_polyline(crack, Color(c["lava_glow"], 0.35), 5.0)
			draw_polyline(crack, c["lava"], 2.2)
			draw_polyline(crack, c["lava_glow"], 1.0)
			draw_circle(p + Vector2(0, -1) * s, 2.5, Color(c["lava_glow"], 0.6))
		"stump":
			_shadow(p + Vector2(3, 6), 8.0 * s)
			var trunk: Rect2 = Rect2(p + Vector2(-4, -10) * s, Vector2(8, 16) * s)
			draw_rect(trunk, c["stump"])
			draw_rect(Rect2(trunk.position, Vector2(3 * s, trunk.size.y)), c["stump"].lightened(0.12))
			draw_colored_polygon(PackedVector2Array([trunk.position, trunk.position + Vector2(3, -5) * s, trunk.position + Vector2(5, -1) * s, trunk.position + Vector2(8, -6) * s, trunk.position + Vector2(8, 0) * s]), c["stump"])
			draw_line(p + Vector2(4, -4) * s, p + Vector2(10, -9) * s, c["stump"], 2.0)
			for i in 2:
				draw_circle(p + Vector2(-1 + i * 3, -2 + i * 5) * s, 1.1, Color(1.0, 0.45, 0.1, 0.9))
		"obsidian":
			_shadow(p + Vector2(2, 6), 9.0 * s)
			for i in 3:
				var base: Vector2 = p + Vector2(-6.0 + i * 6.0, 6.0)
				_crystal(base, (8.0 + _hash01(cell, 110 + i) * 9.0) * s, 3.0 * s, (i - 1) * 0.3, c["obsidian"], c["obsidian_light"])
		"reeds":
			for i in 5:
				var base: Vector2 = p + Vector2(-8 + i * 4, 8)
				var bend: float = (_hash01(cell, 70 + i) - 0.5) * 7.0
				var tip: Vector2 = base + Vector2(bend, -(12.0 + _hash01(cell, 75 + i) * 6.0) * s)
				var mid: Vector2 = base.lerp(tip, 0.5) + Vector2(bend * 0.2, 0)
				draw_polyline(PackedVector2Array([base, mid, tip]), c["reed"].darkened(0.1 * (i % 2)), 1.4)
				if i % 2 == 0:
					draw_set_transform(tip + Vector2(0, 3), 0.0, Vector2(1.0, 2.2))
					draw_circle(Vector2.ZERO, 1.6, c["reed_top"])
					draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				else:
					draw_line(mid, mid + Vector2(bend * 0.6 + 4.0, -3.0), c["reed"].lightened(0.15), 1.0)
		"mushroom":
			for i in 3:
				var q: Vector2 = p + Vector2(-5.0 + i * 5.0, 3.0 - (i % 2) * 4.0)
				var r: float = (3.0 + _hash01(cell, 120 + i) * 2.5) * s
				_shadow(q + Vector2(1.5, 3.5), r)
				draw_rect(Rect2(q + Vector2(-r * 0.25, -r * 0.2), Vector2(r * 0.5, r * 1.2)), c["stem"])
				draw_colored_polygon(_dome(q, r), c["cap"].darkened(0.2))
				draw_colored_polygon(_dome(q + Vector2(-0.4, -0.4), r * 0.85), c["cap"])
				draw_circle(q + Vector2(-r * 0.35, -r * 0.45), r * 0.18, c["stem"])
				draw_circle(q + Vector2(r * 0.25, -r * 0.6), r * 0.13, c["stem"])
		"log":
			var angle: float = (_hash01(cell, 130) - 0.5) * 0.8
			_shadow(p + Vector2(2, 5), 12.0 * s)
			draw_set_transform(p, angle, Vector2.ONE)
			draw_rect(Rect2(Vector2(-11, -3.5) * s, Vector2(22, 7) * s), c["log"])
			draw_rect(Rect2(Vector2(-11, -3.5) * s, Vector2(22, 2.5) * s), c["log"].lightened(0.15))
			draw_circle(Vector2(11, 0) * s, 3.6 * s, c["log"].lightened(0.25))
			draw_arc(Vector2(11, 0) * s, 2.0 * s, 0.0, TAU, 10, c["log"], 0.8)
			draw_circle(Vector2(-3, -3) * s, 2.6 * s, c["moss"])
			draw_circle(Vector2(2, -3.2) * s, 2.0 * s, c["moss"].lightened(0.1))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"leaves":
			_shadow(p + Vector2(1, 4), 9.0)
			for i in 9:
				var q: Vector2 = p + Vector2(_hash01(cell, 80 + i) - 0.5, (_hash01(cell, 90 + i) - 0.5) * 0.6) * 18.0
				var col: Color = [c["leaves"], c["leaf_light"], c["leaf_red"]][i % 3]
				_leaf(q, 3.0, _hash01(cell, 95 + i) * TAU, col)
		"pumpkin":
			_shadow(p + Vector2(2, 5), 9.0)
			for o: float in [-3.5, 3.5, 0.0]:
				draw_set_transform(p + Vector2(o, 0), 0.0, Vector2(0.75, 1.0))
				draw_circle(Vector2.ZERO, 6.5, c["pumpkin"].darkened(0.1 if o != 0.0 else 0.0))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			draw_circle(p + Vector2(-2, -3), 1.8, c["pumpkin"].lightened(0.3))
			draw_line(p + Vector2(0, -6), p + Vector2(1.5, -9.5), Color(0.3, 0.42, 0.18), 2.2)
			_leaf(p + Vector2(4, -7), 2.8, 0.4, Color(0.35, 0.55, 0.22))


func _tree(p: Vector2, s: float, cell: Vector2i, leaves: Array, trunk: Color) -> void:
	_shadow(p + Vector2(5, 9), 13.0 * s)
	draw_rect(Rect2(p + Vector2(-2.2, 1) * s, Vector2(4.4, 10) * s), trunk.darkened(0.2))
	draw_rect(Rect2(p + Vector2(-2.2, 1) * s, Vector2(2.0, 10) * s), trunk)
	var base: Color = leaves[0]
	draw_circle(p + Vector2(1, 0) * s, 11.5 * s, base.darkened(0.35))
	var blobs: Array[Vector2] = [Vector2(-5, -1), Vector2(5, 0), Vector2(0, -6), Vector2(-1, 2), Vector2(3, -4)]
	for i in blobs.size():
		var col: Color = leaves[int(_hash01(cell, 170 + i) * leaves.size()) % leaves.size()]
		_ball(p + blobs[i] * s, (5.5 + _hash01(cell, 180 + i) * 2.0) * s, col)


func _pine(p: Vector2, s: float, c: Dictionary) -> void:
	_shadow(p + Vector2(4, 9), 11.0 * s)
	draw_rect(Rect2(p + Vector2(-1.8, 5) * s, Vector2(3.6, 6) * s), c["trunk"])
	for tier in 3:
		var top: float = (-15.0 + tier * 6.0) * s
		var half_w: float = (5.0 + tier * 2.5) * s
		var bottom: float = top + 11.0 * s
		var tri: PackedVector2Array = PackedVector2Array([p + Vector2(0, top), p + Vector2(half_w, bottom), p + Vector2(-half_w, bottom)])
		draw_colored_polygon(tri, c["pine"])
		draw_colored_polygon(PackedVector2Array([p + Vector2(0, top), p + Vector2(0, bottom), p + Vector2(-half_w, bottom)]), c["pine_light"])
		var cap: PackedVector2Array = PackedVector2Array([p + Vector2(0, top), p + Vector2(half_w * 0.55, top + 6.0 * s), p + Vector2(0, top + 4.5 * s), p + Vector2(-half_w * 0.55, top + 6.0 * s)])
		draw_colored_polygon(cap, c["snow"])


func _palm(p: Vector2, s: float, c: Dictionary, cell: Vector2i) -> void:
	_shadow(p + Vector2(8, 8), 12.0 * s)
	var lean: float = (_hash01(cell, 131) - 0.5) * 8.0
	var top: Vector2 = p + Vector2(lean, -13.0 * s)
	var mid: Vector2 = p.lerp(top, 0.5) + Vector2(lean * 0.3, 0)
	draw_polyline(PackedVector2Array([p + Vector2(0, 8), mid, top]), c["trunk"], 3.4 * s)
	for i in 4:
		var q: Vector2 = (p + Vector2(0, 8)).lerp(top, 0.2 + i * 0.2)
		draw_line(q + Vector2(-1.8, 0), q + Vector2(1.8, 0), c["trunk"].darkened(0.3), 1.0)
	for i in 7:
		var a: float = TAU * i / 7.0 + 0.3
		var tip: Vector2 = top + Vector2(cos(a) * 12.0, sin(a) * 7.0 + 3.0) * s
		var side: Vector2 = (tip - top).orthogonal().normalized() * 2.4 * s
		var frond: PackedVector2Array = PackedVector2Array([top, top.lerp(tip, 0.5) + side, tip, top.lerp(tip, 0.5) - side])
		draw_colored_polygon(frond, c["palm"] if i % 2 == 0 else c["palm_light"])
	draw_circle(top + Vector2(-1.5, 1.5), 1.6, Color(0.45, 0.3, 0.15))
	draw_circle(top + Vector2(1.5, 2), 1.6, Color(0.4, 0.27, 0.13))


func _cactus(p: Vector2, s: float, c: Dictionary, cell: Vector2i) -> void:
	_shadow(p + Vector2(4, 8), 8.0 * s)
	var body: Color = c["cactus"]
	_pill(p + Vector2(0, -3) * s, Vector2(6.5, 20) * s, body)
	var left_h: float = (4.0 + _hash01(cell, 133) * 4.0) * s
	draw_rect(Rect2(p + Vector2(-8, -1) * s, Vector2(5, 3.5) * s), body.darkened(0.08))
	_pill(p + Vector2(-8, -1) * s - Vector2(0, left_h * 0.5), Vector2(4, left_h + 3.5 * s), body.darkened(0.08))
	if _hash01(cell, 134) < 0.7:
		draw_rect(Rect2(p + Vector2(3, -6) * s, Vector2(5, 3.5) * s), body)
		_pill(p + Vector2(8, -9) * s, Vector2(4, 8 * s), body)
	draw_line(p + Vector2(-0.8, -11) * s, p + Vector2(-0.8, 6) * s, c["cactus_light"], 1.2)
	for i in 4:
		draw_circle(p + Vector2(2.2, -10 + i * 4.5) * s, 0.6, Color(1, 1, 0.85, 0.8))
	if _hash01(cell, 135) < 0.35:
		draw_circle(p + Vector2(0, -13) * s, 2.0, c["flower_a"])


func _rock(p: Vector2, s: float, color: Color, cell: Vector2i, snow: Color) -> void:
	_shadow(p + Vector2(3, 5), 10.0 * s)
	var outline: PackedVector2Array = _blob(p, Vector2(10, 7) * s, cell, 7)
	draw_colored_polygon(outline, color.darkened(0.35))
	draw_colored_polygon(_shift(_scale_about(outline, p, 0.8), Vector2(-1.5, -2.0) * s), color)
	draw_colored_polygon(_shift(_scale_about(outline, p, 0.42), Vector2(-3.0, -3.5) * s), color.lightened(0.18))
	if snow.a > 0.0:
		draw_colored_polygon(_shift(_scale_about(outline, p, 0.55), Vector2(-1.0, -4.0) * s), snow)


func _crystal(base: Vector2, height: float, half_w: float, lean: float, color: Color, light: Color = Color.WHITE) -> void:
	var up: Vector2 = Vector2(0, -1).rotated(lean)
	var side: Vector2 = up.orthogonal() * half_w
	var tip: Vector2 = base + up * height
	var shoulder: Vector2 = base + up * height * 0.75
	draw_colored_polygon(PackedVector2Array([base - side, shoulder - side, tip, shoulder + side, base + side]), color.darkened(0.25))
	draw_colored_polygon(PackedVector2Array([base - side, shoulder - side, tip, base]), color)
	draw_line(base.lerp(tip, 0.15) - side * 0.4, shoulder - side * 0.4, Color(light, 0.7), 1.0)


func _draw_lily(cell: Vector2i, biome: Dictionary) -> void:
	var p: Vector2 = Board.cell_to_world(cell) + Vector2(_hash01(cell, 141) - 0.5, _hash01(cell, 142) - 0.5) * 12.0
	var pad: Color = Color(0.32, 0.6, 0.28) if int(biome["water_style"]) == 0 else Color(0.36, 0.5, 0.22)
	var a: float = _hash01(cell, 143) * TAU
	draw_circle(p + Vector2(1, 1.5), 5.0, Color(0, 0, 0, 0.18))
	draw_colored_polygon(_pad(p, 5.0, a), pad)
	draw_colored_polygon(_pad(p + Vector2(-0.6, -0.6), 3.4, a), pad.lightened(0.15))
	if _hash01(cell, 144) < 0.4:
		for k in 5:
			draw_circle(p + Vector2.RIGHT.rotated(TAU * k / 5.0) * 1.6, 1.4, Color(1.0, 0.7, 0.85))
		draw_circle(p, 1.0, Color(1.0, 0.9, 0.4))


func _tuft(p: Vector2, s: float, color: Color, cell: Vector2i) -> void:
	for i in 6:
		var x: float = (-5.0 + i * 2.0) * s
		var h: float = (5.0 + _hash01(cell, 200 + i) * 5.0) * s
		var tip: Vector2 = p + Vector2(x + (i - 2.5) * 0.9, -h)
		draw_colored_polygon(PackedVector2Array([p + Vector2(x - 1.0, 3), tip, p + Vector2(x + 1.0, 3)]), color.lightened(0.12 * (i % 3) - 0.08))


func _leaf(p: Vector2, r: float, angle: float, color: Color) -> void:
	draw_set_transform(p, angle, Vector2(1.0, 0.55))
	draw_circle(Vector2.ZERO, r, color)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A soft-shaded ball: dark rim, lit body, small highlight (light from the top left).
func _ball(p: Vector2, r: float, color: Color) -> void:
	draw_circle(p, r, color.darkened(0.3))
	draw_circle(p + Vector2(-r * 0.12, -r * 0.15), r * 0.82, color)
	draw_circle(p + Vector2(-r * 0.35, -r * 0.4), r * 0.3, color.lightened(0.22))


func _pill(center: Vector2, size: Vector2, color: Color) -> void:
	var r: float = size.x / 2.0
	draw_rect(Rect2(center - Vector2(r, size.y / 2.0 - r), Vector2(size.x, size.y - 2.0 * r)), color)
	draw_circle(center - Vector2(0, size.y / 2.0 - r), r, color)
	draw_circle(center + Vector2(0, size.y / 2.0 - r), r, color)
	draw_rect(Rect2(center - Vector2(r, size.y / 2.0 - r), Vector2(r * 0.6, size.y - 2.0 * r)), color.lightened(0.1))


func _shadow(p: Vector2, r: float) -> void:
	draw_set_transform(p, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _dome(p: Vector2, r: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 9:
		pts.append(p + Vector2(-cos(PI * i / 8.0) * r, -sin(PI * i / 8.0) * r * 0.85))
	return pts


func _pad(p: Vector2, r: float, notch: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array([p])
	for i in 11:
		pts.append(p + Vector2.RIGHT.rotated(notch + 0.5 + (TAU - 1.0) * i / 10.0) * r)
	return pts


## Irregular closed outline around `p` (stable per cell).
func _blob(p: Vector2, radii: Vector2, cell: Vector2i, points: int) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in points:
		var a: float = TAU * i / points
		var k: float = 0.75 + 0.35 * _hash01(cell, 300 + i)
		pts.append(p + Vector2(cos(a) * radii.x, sin(a) * radii.y * (0.8 if sin(a) > 0.0 else 1.0)) * k)
	return pts


static func _shift(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in points:
		out.append(q + by)
	return out


static func _scale_about(points: PackedVector2Array, center: Vector2, k: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for q: Vector2 in points:
		out.append(center + (q - center) * k)
	return out


func _pick(cell: Vector2i, options: Array) -> String:
	var total: float = 0.0
	for option: Array in options:
		total += float(option[1])
	var roll: float = _hash01(cell, 97) * total
	for option: Array in options:
		roll -= float(option[1])
		if roll <= 0.0:
			return option[0]
	return options[options.size() - 1][0]


## Whether a 4-neighbour of `cell` is path (`path` true) or lake (`path` false).
static func _next_to(layout: MapLayout, cell: Vector2i, path: bool) -> bool:
	for d: Vector2i in MapLayout.DIRECTIONS:
		if (layout.is_path(cell + d) if path else layout.is_feature(cell + d)):
			return true
	return false


static func _interior_lake(layout: MapLayout, cell: Vector2i) -> bool:
	for d: Vector2i in MapLayout.DIRECTIONS:
		if not layout.is_feature(cell + d):
			return false
	return true


static func _plaza(layout: MapLayout, cell: Vector2i) -> bool:
	return Vector2(cell - layout.exit).length() <= 2.3  # the stone plaza around the gate


## Stable pseudo-random value in [0, 1) for a cell (so decorations never flicker).
static func _hash01(cell: Vector2i, salt: int) -> float:
	return float(absi(hash([cell.x, cell.y, salt])) % 10007) / 10007.0
