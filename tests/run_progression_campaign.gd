extends SceneTree
## Natural, deterministic campaigns with an isolated profile reloaded each run.
## --variant=builder --runs=10 --seed=721 --cap=60 --report=/tmp/campaign.json

const Bot = preload("res://tests/advanced_bot.gd")
const DELTA := 1.0 / 30.0
const HASHED_FILES: Array[String] = ["scripts/main.gd", "scripts/board.gd", "scripts/enemy.gd", "scripts/enemy_profile.gd", "scripts/tower.gd", "scripts/tower_catalog.gd", "scripts/combat_projectile.gd", "scripts/progression.gd", "scripts/skill_catalog.gd", "scripts/wave_generator.gd", "scripts/wave_manager.gd", "scripts/game_config.gd", "tests/advanced_bot.gd", "tests/run_progression_campaign.gd", "project.godot", "scenes/main.tscn", "scenes/enemy.tscn", "scenes/tower.tscn"]
var variant: String = Bot.DEFAULT_VARIANT
var run_count := 10
var seed_value := 721
var cap := 80
var report_path := "user://campaign_report.json"
var profile_path := ""
var label := "campaign"
var verify_targets := false
var failed := false
var hashes: Dictionary = {}


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--variant="): variant = argument.trim_prefix("--variant=")
		elif argument.begins_with("--runs="): run_count = clampi(argument.trim_prefix("--runs=").to_int(), 1, 10)
		elif argument.begins_with("--seed="): seed_value = argument.trim_prefix("--seed=").to_int()
		elif argument.begins_with("--cap="): cap = clampi(argument.trim_prefix("--cap=").to_int(), 1, 200)
		elif argument.begins_with("--report="): report_path = argument.trim_prefix("--report=")
		elif argument.begins_with("--label="): label = argument.trim_prefix("--label=")
		elif argument == "--assert-targets": verify_targets = true
	for path in HASHED_FILES:
		hashes[path] = FileAccess.get_sha256("res://" + path)
	profile_path = "user://tests/campaign_%d_%d.json" % [OS.get_process_id(), Time.get_ticks_usec()]
	call_deferred("_run")


func _summary(game: TDGame, full: bool = false) -> Dictionary:
	var kinds: Array[int] = [0, 0, 0, 0, 0]
	var upgrades: Array[int] = [0, 0, 0, 0]
	var layout: Array[Dictionary] = []
	for node in game.board.get_node("Towers").get_children():
		var tower := node as Tower
		kinds[tower.kind] += 1
		var levels: Array[int] = []
		for track in range(1, 5):
			upgrades[track - 1] += tower.levels(track)
			levels.append(tower.levels(track))
		if full: layout.append({"kind": tower.kind, "x": tower.cell.x, "y": tower.cell.y, "levels": levels})
	var result := {"by_kind": kinds, "upgrades": upgrades}
	if full: result.layout = layout
	return result


func _session(profile: Progression, attempt: int) -> Dictionary:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = profile
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	var run_seed := seed_value + (attempt - 1) * 1009
	game.waves.set_run_seed(run_seed)
	var bot := Bot.new(variant)
	var before_diamonds := profile.diamonds
	var before_skills := profile.unlocked.duplicate()
	var rows: Array[Dictionary] = []
	var cleared := 0
	var error := ""
	var started := Time.get_ticks_msec()
	var total_sim := 0.0
	var peak_projectiles := 0
	for wave in range(1, cap + 1):
		game.close_skill_tree()
		bot.prepare(game)
		if not bot.error.is_empty():
			error = bot.error
			break
		var route := game.board.find_path()
		var start_gold := game.currency
		game.start_wave()
		var budget := route.size() * GameConfig.CELL_SIZE / (40.0 * 0.97 * 0.81 * 0.25) + game.waves.wave_size * game.waves.spawn_interval + 60
		var frames := 0
		while game.phase == TDGame.Phase.WAVE_ACTIVE and frames * DELTA <= budget:
			game.waves._process(DELTA)
			for node in game.board.active_enemies():
				if game.is_finished(): break
				(node as Enemy)._process(DELTA)
			for node in game.board.get_node("Towers").get_children():
				if game.is_finished(): break
				(node as Tower)._process(DELTA)
			var projectiles := game.board.get_node("Projectiles").get_children()
			peak_projectiles = maxi(peak_projectiles, projectiles.size())
			for node in projectiles:
				if game.is_finished(): break
				(node as CombatProjectile)._process(DELTA)
			frames += 1
			if frames % 120 == 0: await process_frame
		if game.phase == TDGame.Phase.WAVE_ACTIVE:
			error = "Wave exceeded conservative route/slow travel budget"
			break
		if game.phase == TDGame.Phase.BETWEEN_WAVES: cleared += 1
		total_sim += frames * DELTA
		rows.append({"wave": wave, "lives": game.lives, "route_cells": route.size(), "start_gold": start_gold, "end_gold": game.currency, "sim_seconds": snappedf(frames * DELTA, 0.001), "towers": _summary(game), "diamonds": profile.diamonds, "skill_count": profile.unlocked.size()})
		if wave % 5 == 0 or game.is_finished():
			print("Campaign %s seed=%d run=%d wave=%d %s lives=%d route=%d towers=%s sim=%.1fm wall=%.1fs" % [variant, seed_value, attempt, wave, "DEFEAT" if game.is_finished() else "clear", game.lives, route.size(), str(_summary(game).by_kind), total_sim / 60, (Time.get_ticks_msec() - started) / 1000.0])
		await process_frame
		if game.is_finished(): break
	var research_spending := 0
	for id in profile.unlocked:
		if not before_skills.has(id): research_spending += int(SkillCatalog.NODES[id].cost)
	if profile.diamonds != before_diamonds + cleared - research_spending:
		error = "Diamonds do not equal retained balance plus natural clears minus research spending"
	var result := {"attempt": attempt, "seed": run_seed, "outcome": "error" if not error.is_empty() else ("defeat" if game.is_finished() else "cap"), "cleared": cleared, "last_wave": game.waves.current_wave, "lives": game.lives, "error": error, "research_spending": research_spending, "diamonds_before": before_diamonds, "diamonds_after": profile.diamonds, "skills_before": before_skills, "skills_after": profile.unlocked.duplicate(), "sim_seconds": total_sim, "elapsed_seconds": (Time.get_ticks_msec() - started) / 1000.0, "peak_projectiles": peak_projectiles, "final_towers": _summary(game, true), "gaps": bot.gaps.map(func(cell: Vector2i) -> Array: return [cell.x, cell.y]), "waves": rows}
	print("Campaign RESULT: %s run=%d cleared=%d last_wave=%d outcome=%s diamonds=%d skills=%d" % [variant, attempt, cleared, result.last_wave, result.outcome, profile.diamonds, profile.unlocked.size()])
	if not error.is_empty():
		failed = true
		printerr("FAIL: ", error)
	game.free()
	await process_frame
	return result


func _run() -> void:
	if not Bot.VARIANTS.has(variant):
		printerr("FAIL: unknown bot variant")
		quit(1)
		return
	var results: Array[Dictionary] = []
	var previous_diamonds := 0
	var previous_skills: Array[String] = []
	for attempt in range(1, run_count + 1):
		var profile := Progression.new(profile_path)
		if not profile.load_profile() or profile.diamonds != previous_diamonds or profile.unlocked != previous_skills:
			failed = true
			printerr("FAIL: campaign profile did not round-trip between attempts")
			break
		results.append(await _session(profile, attempt))
		previous_diamonds = profile.diamonds
		previous_skills.assign(profile.unlocked)
		if failed: break
	for path in HASHED_FILES:
		if hashes[path] != FileAccess.get_sha256("res://" + path):
			failed = true
			printerr("FAIL: experiment source changed during run: ", path)
	var first_fifty := 0
	for result in results:
		if first_fifty == 0 and int(result.last_wave) >= 50:
			first_fifty = int(result.attempt)
	if verify_targets and (results.size() != 10 or int(results[0].last_wave) < 8 or int(results[0].last_wave) > 12 or results[0].outcome != "defeat" or first_fifty == 0):
		failed = true
		printerr("FAIL: campaign target is first defeat 8–12 and wave 50 by attempt 10 (earlier is allowed)")
	var report := {"label": label, "variant": variant, "traits": Bot.VARIANTS[variant], "engine": Engine.get_version_info().string, "seed": seed_value, "step_seconds": DELTA, "wave_cap": cap, "source_hashes": hashes, "results": results, "failed": failed, "first_wave_50_attempt": first_fifty}
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		printerr("FAIL: could not write campaign report")
		quit(1)
		return
	file.store_string(JSON.stringify(report))
	file.close()
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(profile_path + suffix))
	print("Campaign report: ", report_path)
	quit(1 if failed else 0)
