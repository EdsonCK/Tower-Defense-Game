extends Node2D
## Documentation-only artwork/contact sheet, rendered by capture_ui.gd.

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1600, 900), Color("111c28"))
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(60, 65), "MONSTERS & MACHINATIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color("e8dcc1"))
	draw_string(font, Vector2(60, 104), "Five monster silhouettes. Five crafted defenses. Illustrated entirely in Godot.", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("99afbf"))
	var monsters := ["EMBER IMP", "SKITTERFANG", "IRONBACK OGRE", "MIRE SHAMAN", "VOID WRAITH"]
	var traits := ["Horns · fangs · curled tail", "Six legs · amber shell", "Heavy plating · slit visor", "Hood · branches · staff", "Crown · claws · spectral tails"]
	for i in range(5):
		var x := 180.0 + i * 308
		draw_style_box(UIStyle.box(Color("1c2b39"), Color("34495a"), 14), Rect2(x - 128, 145, 256, 260))
		draw_set_transform(Vector2(x, 244), 0, Vector2.ONE * 3.1)
		MonsterArt.draw_monster(self, i, 0.75)
		draw_set_transform(Vector2.ZERO)
		draw_string(font, Vector2(x - 110, 342), monsters[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 21, Color("e6dcc9"))
		draw_string(font, Vector2(x - 110, 377), traits[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("a5b8c7"))
	var features := ["Brass sentinel · muzzle flash", "Runic coil · circular lightning", "Siege mortar · arcing shells", "Frost spire · icicles & control", "Iron cannon · piercing balls"]
	for i in range(5):
		var x := 180.0 + i * 308
		draw_style_box(UIStyle.box(Color("1b2935"), Color("34495a"), 14), Rect2(x - 128, 433, 256, 260))
		draw_set_transform(Vector2(x, 540), 0, Vector2.ONE * 3.0)
		TowerArt.draw_tower(self, i, -0.6, 0)
		draw_set_transform(Vector2.ZERO)
		draw_string(font, Vector2(x - 110, 632), str(TowerCatalog.DATA[i].title).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 23, TowerCatalog.DATA[i].color)
		draw_string(font, Vector2(x - 110, 668), features[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("a5b8c7"))
	draw_string(font, Vector2(60, 750), "CROWD READABILITY / ACTUAL GAME SCALE", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("d8c69e"))
	for i in range(88):
		draw_set_transform(Vector2(80 + i * 16, 810 + (i % 3 - 1) * 4), 0, Vector2.ONE)
		MonsterArt.draw_monster(self, i % 5, i * 0.7)
	draw_set_transform(Vector2.ZERO)
	draw_string(font, Vector2(60, 869), "Dark contours, contrasting highlights and render-only lanes preserve each monster's identity in a pack.", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("9fb4c4"))
