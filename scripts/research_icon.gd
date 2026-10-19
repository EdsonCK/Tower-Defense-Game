class_name ResearchIcon
extends Button
## No permanent text on a node. Hover/focus reveals information in the menu.

var skill_id := ""
var owned := false
var available := false
var accent := Color("aa9ae0")


func _ready() -> void:
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)


func _draw() -> void:
	var center := size * 0.5
	var highlighted := is_hovered() or has_focus()
	draw_circle(center + Vector2(0, 3), 29, Color(0, 0, 0, 0.45))
	draw_circle(center, 28, DrawKit.INK)
	draw_circle(center, 25, Color("283b4c") if owned or available else Color("1c2737"))
	draw_arc(center, 26, 0, TAU, 40, accent if owned or available or highlighted else Color("4c566a"), 2.5 if highlighted else 1.5, true)
	if owned:
		draw_arc(center, 22, 0, TAU, 32, Color(accent, 0.35), 1, true)
	draw_set_transform(center, 0, Vector2.ONE * 0.9)
	var tower_kind := _tower_kind()
	if tower_kind >= 0:
		TowerArt.draw_tower(self, tower_kind)
	else:
		_draw_symbol()
	draw_set_transform(Vector2.ZERO)
	if skill_id.ends_with("_mastery"):
		for i in range(6):
			var point := center + Vector2.from_angle(i * TAU / 6 - PI / 2) * 19
			draw_circle(point, 1.7, DrawKit.BONE)
	elif skill_id.ends_with("_training"):
		draw_polyline(PackedVector2Array([center + Vector2(-6, 18), center + Vector2(0, 21), center + Vector2(6, 18)]), DrawKit.BONE, 1.5, true)
	if owned:
		draw_circle(center + Vector2(19, -19), 7, Color("2b655c"))
		draw_polyline(PackedVector2Array([center + Vector2(15, -19), center + Vector2(18, -16), center + Vector2(23, -22)]), Color("b6f5c5"), 2, true)
	elif not available:
		draw_circle(center + Vector2(19, -19), 6, Color("455367"))
		draw_arc(center + Vector2(19, -20), 2, PI, TAU, 8, Color("b1bac7"), 1, true)
		draw_rect(Rect2(center + Vector2(16, -20), Vector2(6, 5)), Color("b1bac7"))
	if skill_id.ends_with("_ii") or skill_id.ends_with("_iii"):
		for i in range(3 if skill_id.ends_with("_iii") else 2):
			draw_line(center + Vector2(-5 + i * 5, 15), center + Vector2(-5 + i * 5, 21), DrawKit.BONE, 1.5, true)


func _tower_kind() -> int:
	if skill_id == "tesla": return 1
	if skill_id == "mortar": return 2
	if skill_id == "ice": return 3
	if skill_id == "cannon": return 4
	if skill_id.ends_with("_training") or skill_id.ends_with("_mastery"):
		for i in range(TowerCatalog.DATA.size()):
			if skill_id == TowerCatalog.DATA[i].training or skill_id == TowerCatalog.DATA[i].mastery:
				return i
	return -1


func _draw_symbol() -> void:
	if "gold" in skill_id or skill_id == "salvage":
		for i in range(3):
			DrawKit.ellipse(self, Vector2(-5 + i * 5, 6 - i * 4), Vector2(7, 4), Color("d8ac60"), DrawKit.INK, 1.5)
			draw_line(Vector2(-9 + i * 5, 4 - i * 4), Vector2(-4 + i * 5, 4 - i * 4), Color("ffdf9b"), 1, true)
	elif "optics" in skill_id:
		draw_arc(Vector2.ZERO, 10, 0, TAU, 24, accent, 2, true)
		for i in range(4):
			var v := Vector2.from_angle(i * PI / 2)
			draw_line(v * 5, v * 15, DrawKit.BONE, 1.5, true)
	elif "armor" in skill_id or skill_id == "piercing":
		DrawKit.poly(self, PackedVector2Array([Vector2(-9, -10), Vector2(9, -10), Vector2(8, 5), Vector2(0, 13), Vector2(-8, 5)]), Color("899ca8"))
		draw_polyline(PackedVector2Array([Vector2(2, -13), Vector2(-3, -2), Vector2(4, 1), Vector2(-2, 13)]), Color("ffe2a0"), 2.5, true)
	elif "freeze" in skill_id:
		for i in range(6):
			var v := Vector2.from_angle(i * TAU / 6)
			draw_line(Vector2.ZERO, v * 14, Color("c1f4ff"), 2, true)
			draw_line(v * 8, v * 10 + v.orthogonal() * 4, accent, 1.5, true)
	elif "fragile" in skill_id or "sluggish" in skill_id:
		MonsterArt.draw_monster(self, 3 if "sluggish" in skill_id else 2, 0)
		draw_line(Vector2(-12, 11), Vector2(12, -12), Color("eac882"), 2.5, true)
	elif "rapid" in skill_id:
		for x in [-7, 4]:
			DrawKit.poly(self, PackedVector2Array([Vector2(x - 3, -12), Vector2(x + 5, -2), Vector2(x + 1, 12), Vector2(x - 5, 2)]), Color("b4e2dc"))
	elif skill_id == "mortar_area":
		draw_circle(Vector2.ZERO, 5, Color("ffcd81"))
		for i in range(8):
			var v := Vector2.from_angle(i * TAU / 8)
			draw_line(v * 8, v * 16, Color("ef9b68"), 2, true)
	elif skill_id == "cannon_distance":
		draw_line(Vector2(-14, 0), Vector2(13, 0), Color("d4d9af"), 3, true)
		draw_polyline(PackedVector2Array([Vector2(5, -7), Vector2(13, 0), Vector2(5, 7)]), Color("d4d9af"), 2.5, true)
	else:
		# Electrical and engineering research use a faceted energy rune.
		DrawKit.gem(self, Vector2.ZERO, 14, accent)
		draw_polyline(PackedVector2Array([Vector2(2, -11), Vector2(-4, 0), Vector2(3, 0), Vector2(-2, 11)]), DrawKit.BONE, 2, true)
