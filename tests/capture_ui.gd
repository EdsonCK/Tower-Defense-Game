extends SceneTree
## Optional rendered fixture. Requires a real or virtual X11/Wayland/Windows display.
## Run: godot --path . --script res://tests/capture_ui.gd -- --output=/tmp/td-ui
## Fixture uses free resources and synthetic bars for visual review, not balance.

var output := "user://ui-previews"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	if DisplayServer.get_name() == "headless":
		printerr("UI capture needs a rendered display; run without --headless")
		quit(1)
		return
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output)) != OK:
		printerr("Could not create UI preview directory")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var game := load("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	game.progression.unlocked.assign(SkillCatalog.IDS)
	game.progression.diamonds = 24
	root.add_child(game)
	game.board.process_mode = Node.PROCESS_MODE_DISABLED
	game.waves.set_process(false)
	game.waves.set_run_seed(472)
	game.currency = 10000
	var towers: Array[Tower] = []
	for kind in range(5):
		game.select_tower(kind)
		var cell := Vector2i(5 + kind * 7, 10)
		game.purchase_tower(cell)
		towers.append(game.tower_at_cell(cell))
	game.currency = 1480
	game.select_placed_tower(towers[2])
	for category in [Tower.Upgrade.DAMAGE, Tower.Upgrade.RANGE, Tower.Upgrade.SPEED]:
		game.upgrade_selected_tower(category)
	var units: Array[Enemy] = []
	for index in range(65):
		var unit := Enemy.new()
		unit.visual_seed = index
		game.board.get_node("Enemies").add_child(unit)
		var profile := EnemyProfile.base((index % 5) as EnemyProfile.Kind)
		profile.hit_points = 5000
		unit.setup_profile(game.board, profile)
		unit.position = Vector2(100 + index * 17, 415)
		unit.set_process(false)
		units.append(unit)
	for i in range(towers.size()):
		if i == 1:
			towers[i].attack_area()
		else:
			var target_x := towers[i].position.x + (220 if i == Tower.Kind.MORTAR else 0)
			var target := units[clampi(roundi((target_x - 100) / 17.0), 0, units.size() - 1)]
			towers[i].attack(target)
	for node in game.board.get_node("Projectiles").get_children():
		(node as CombatProjectile)._process(0.45 if (node as CombatProjectile).kind == CombatProjectile.Kind.MORTAR else 0.12)
	game.waves.current_wave = 40
	game.waves.active_count = units.size() # Visual fixture counters only.
	game.phase = TDGame.Phase.WAVE_ACTIVE
	game._refresh_hud()
	game.hud.show_message("Hold the line • Mix damage, range, firing speed and unique upgrades • Every tower now shares five slots, or six with mastery.")
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	_capture("hud.png")
	game.waves.stop()
	game.phase = TDGame.Phase.BETWEEN_WAVES
	game.progression.unlocked.assign(["tesla", "basic_training", "tesla_training", "mortar", "ice", "cannon", "salvage", "engineering", "mortar_training"])
	game.open_skill_tree()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	_capture("research.png")
	game.skill_tree._show_info("mortar_area")
	await process_frame
	await RenderingServer.frame_post_draw
	_capture("research-hover.png")
	game.close_skill_tree()
	game.hud.get_node("RightPanel/Margin/Items/Restart").pressed.emit()
	for frame in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	_capture("restart.png")
	game.free()
	await process_frame
	var gallery := Node2D.new()
	gallery.set_script(load("res://tests/visual_gallery.gd"))
	root.add_child(gallery)
	await process_frame
	await RenderingServer.frame_post_draw
	_capture("gallery.png")
	gallery.free()
	quit()

func _capture(name: String) -> void:
	var path := output.path_join(name)
	if root.get_texture().get_image().save_png(path) != OK:
		printerr("UI capture failed: ", path)
		quit(1)
	else:
		print("UI preview: ", path)
