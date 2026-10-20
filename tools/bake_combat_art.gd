extends SceneTree
## Rebuild original procedural art into shared textures. Needs a real renderer.
## godot --path . --rendering-method gl_compatibility --script res://tools/bake_combat_art.gd
const FRAMES := 64
const TILE := 96 # 48 logical pixels at 2x for crisp resizing.
const FREQUENCIES := [6.0, 12.0, 6.0, 4.0, 3.0]

class Paint extends Node2D:
	var monster := true
	var kind := 0
	var phase := 0.0
	func _draw() -> void:
		if monster: MonsterArt.draw_monster(self, kind, phase)
		else: TowerArt.draw_base(self, kind)

func _initialize() -> void:
	call_deferred("run")

func bake(monsters: bool, path: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(TILE * 16, TILE * 20) if monsters else Vector2i(TILE * 5, TILE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	root.add_child(viewport)
	for kind in range(5):
		for frame in range(FRAMES if monsters else 1):
			var art := Paint.new()
			art.monster = monsters
			art.kind = kind
			art.phase = float(frame) / FRAMES * TAU / FREQUENCIES[kind]
			art.position = Vector2((frame % 16 + 0.5) * TILE, (kind * 4 + frame / 16 + 0.5) * TILE) if monsters else Vector2((kind + 0.5) * TILE, TILE * 0.5)
			art.scale = Vector2.ONE * 2
			viewport.add_child(art)
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	var error := image.save_png(path)
	assert(error == OK, "Could not save " + path)
	print("Baked ", path, " ", image.get_size())
	viewport.queue_free()
	await process_frame

func run() -> void:
	if DisplayServer.get_name() == "headless":
		printerr("Baking needs an OpenGL/Vulkan renderer; normal headless checks use the committed PNGs.")
		quit(1)
		return
	await bake(true, "res://assets/generated/monsters.png")
	await bake(false, "res://assets/generated/towers.png")
	var manifest := {"frames": FRAMES, "tile": TILE, "frequencies": FREQUENCIES, "source_hashes": {}}
	for file in ["scripts/monster_art.gd", "scripts/tower_art.gd", "scripts/draw_kit.gd", "scripts/tower_catalog.gd"]:
		manifest.source_hashes[file] = FileAccess.get_sha256("res://" + file)
	FileAccess.open("res://assets/generated/art_manifest.json", FileAccess.WRITE).store_string(JSON.stringify(manifest, "\t") + "\n")
	quit()
