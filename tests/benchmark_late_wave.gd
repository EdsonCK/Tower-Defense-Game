extends SceneTree
## Funded stress fixture, NOT a survival/balance run. Fixed gameplay delta.
## Run with -- --wave=60 --frames=240 --out=/tmp/result.json [--capture=/tmp/frame.png].
const STEP := 1.0 / 60.0
var wave := 60
var frames := 240
var output := "/tmp/late-wave.json"
var capture := ""
var preview := true

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--wave="): wave = int(arg.trim_prefix("--wave="))
		if arg.begins_with("--frames="): frames = int(arg.trim_prefix("--frames="))
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
		if arg == "--no-preview": preview = false
		if arg.begins_with("--capture="): capture = arg.trim_prefix("--capture=" )
	call_deferred("run")

func percentile(values: Array, fraction: float) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	return float(sorted[mini(sorted.size() - 1, floori(sorted.size() * fraction))]) / 1000.0

func run() -> void:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	for id in SkillCatalog.NODES: game.progression.unlocked.append(id)
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.currency = 1000000
	var bot := preload("res://tests/advanced_bot.gd").new("architect")
	# Fixture builds the same legal hallway layout, with explicit free funding.
	for cell in bot.candidates:
		game.select_tower((game.board.get_node("Towers").get_child_count() * 7) % 5)
		game.purchase_tower(cell)
	game.building = false
	for node in game.board.get_node("Towers").get_children():
		var tower := node as Tower
		tower.apply_upgrade(Tower.Upgrade.DAMAGE)
		tower.apply_upgrade(Tower.Upgrade.DAMAGE)
		tower.apply_upgrade(Tower.Upgrade.SPEED)
	game.phase = TDGame.Phase.WAVE_ACTIVE
	game.waves.current_wave = wave
	var profiles := WaveGenerator.new(721).generate(wave)
	game.waves.active_count = profiles.size() + 1 # Sentinel keeps fixture from clearing.
	var route := game.board.find_path()
	var setup_start := Time.get_ticks_usec()
	for i in range(profiles.size()):
		game._spawn_enemy(profiles[i])
		var enemy := game.board.get_node("Enemies").get_child(i) as Enemy
		var at := mini(route.size() - 2, floori(float(i) / profiles.size() * (route.size() - 20)))
		enemy._current_cell = route[at]
		enemy._committed_cell = route[at]
		enemy.position = game.board.cell_to_pixel(route[at])
		enemy._plan_at_center()
	var setup_us := Time.get_ticks_usec() - setup_start
	game._refresh_hud()
	await process_frame
	await process_frame
	var timing := {"enemies": [], "towers": [], "projectiles": [], "preview": [], "frame": []}
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	var peak_projectiles := 0
	for frame in range(frames):
		var start := Time.get_ticks_usec()
		for node in game.board.active_enemies(): (node as Enemy)._process(STEP)
		var after_enemies := Time.get_ticks_usec()
		for node in game.board.get_node("Towers").get_children(): (node as Tower)._process(STEP)
		var after_towers := Time.get_ticks_usec()
		for node in game.board.get_node("Projectiles").get_children(): (node as CombatProjectile)._process(STEP)
		var after_projectiles := Time.get_ticks_usec()
		# A valid off-route hover while hundreds of enemies are moving.
		if preview: game.board.placement_error(Vector2i(0, 0), game.currency)
		var after_preview := Time.get_ticks_usec()
		await process_frame
		var end := Time.get_ticks_usec()
		timing.enemies.append(after_enemies - start)
		timing.towers.append(after_towers - after_enemies)
		timing.projectiles.append(after_projectiles - after_towers)
		timing.preview.append(after_preview - after_projectiles)
		timing.frame.append(end - start)
		var state: Array = [game.currency, game.lives]
		for node in game.board.get_node("Enemies").get_children():
			var e := node as Enemy
			state.append([e.visual_seed, e.position, e.health, e.armor, e.shield, e._slow_factor, e._slow_remaining, e._freeze_remaining, e._regen_fraction, e._current_cell, e._committed_cell, e.is_alive()])
		for node in game.board.get_node("Towers").get_children():
			state.append((node as Tower)._cooldown)
		for node in game.board.get_node("Projectiles").get_children():
			var p := node as CombatProjectile
			state.append([p.kind, p.position, p._age, p._impact, p._traveled, p._hit_ids.size()])
		peak_projectiles = maxi(peak_projectiles, game.board.get_node("Projectiles").get_child_count())
		digest.update(var_to_bytes(state))
	var result := {"engine": Engine.get_version_info().string, "renderer": RenderingServer.get_current_rendering_method(), "display": DisplayServer.get_name(), "preview": preview, "wave": wave, "frames": frames, "delta": STEP, "towers": game.board.get_node("Towers").get_child_count(), "initial_enemies": profiles.size(), "final_enemies": game.board.active_enemies().size(), "peak_projectiles": peak_projectiles, "route_cells": route.size(), "enemy_setup_ms": setup_us / 1000.0, "combat_sha256": digest.finish().hex_encode(), "timing_ms": {}}
	result.source_hashes = {}
	for file in DirAccess.get_files_at("res://scripts"):
		if file.ends_with(".gd"): result.source_hashes[file] = FileAccess.get_sha256("res://scripts/" + file)
	for stage in timing:
		var sum := 0.0
		for value in timing[stage]: sum += value
		result.timing_ms[stage] = {"mean": sum / frames / 1000.0, "p50": percentile(timing[stage], 0.5), "p95": percentile(timing[stage], 0.95)}
	if not capture.is_empty() and DisplayServer.get_name() != "headless":
		await process_frame
		root.get_texture().get_image().save_png(capture)
	FileAccess.open(output, FileAccess.WRITE).store_string(JSON.stringify(result, "\t"))
	print(JSON.stringify(result))
	game.free()
	await process_frame
	quit()
