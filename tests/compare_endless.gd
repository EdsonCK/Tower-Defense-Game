extends SceneTree
## Opt-in balance experiment, not an instant-kill test or an unlimited suite.
## Example: --script res://tests/compare_endless.gd -- --report=/tmp/baseline.json

const Policies = preload("res://tests/bot_policies.gd")
const DELTA := 1.0 / 30.0
var seed_value := 721
var cap := 200
var report_path := "user://balance_comparison.json"
var policy := "both"
var label := "comparison"
var failed := false
var assert_near_50 := false


func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument == "--assert-near-50":
			assert_near_50 = true
		elif argument.begins_with("--report="):
			report_path = argument.trim_prefix("--report=")
		elif argument.begins_with("--policy="):
			policy = argument.trim_prefix("--policy=")
		elif argument.begins_with("--label="):
			label = argument.trim_prefix("--label=")
		elif argument.begins_with("--cap="):
			cap = clampi(argument.trim_prefix("--cap=").to_int(), 1, 200)
		elif argument.begins_with("--seed="):
			seed_value = argument.trim_prefix("--seed=").to_int()
	call_deferred("_run")


func _observe_spawn(game: TDGame, profile: EnemyProfile, metrics: Dictionary) -> void:
	metrics.spawned += 1
	metrics.max_hp = maxi(metrics.max_hp, profile.hit_points)
	metrics.max_armor = maxi(metrics.max_armor, profile.armor)
	var enemy := game.board.get_node("Enemies").get_child(-1) as Enemy
	enemy.died.connect(func(_enemy: Enemy) -> void:
		var key: String = EnemyProfile.Kind.keys()[enemy.kind]
		metrics.kills[key] = int(metrics.kills.get(key, 0)) + 1
	)
	enemy.reached_exit.connect(func(_enemy: Enemy) -> void:
		var key: String = EnemyProfile.Kind.keys()[enemy.kind]
		metrics.escapes[key] = int(metrics.escapes.get(key, 0)) + 1
	)


func _session(name: String) -> Dictionary:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.waves.set_run_seed(seed_value)
	var started := Time.get_ticks_msec()
	var state := {"index": 0, "gaps": []}
	var rows: Array[Dictionary] = []
	var cleared := 0
	var error := ""
	for wave in range(1, cap + 1):
		game.close_skill_tree()
		if name == "best":
			if wave > 5:
				Policies.spend_skills(game)
			Policies.build_and_upgrade(game, wave)
		else:
			error = Policies.build_hallways(game, state)
		if not error.is_empty():
			break
		var route := game.board.find_path()
		if not game.board.path_is_valid(route, GameConfig.SPAWN):
			error = "Invalid route after purchases"
			break
		var metrics := {"spawned": 0, "kills": {}, "escapes": {}, "max_hp": 0, "max_armor": 0}
		var listener := func(profile: EnemyProfile) -> void: _observe_spawn(game, profile, metrics)
		game.waves.spawn_requested.connect(listener)
		var start_gold := game.currency
		game.start_wave()
		# Long mazes legitimately take longer than the old 150-second smoke limit.
		# Bound travel by the slowest type + nerf + conservative 50% slow, and add
		# spawn time. No HP, speed, damage, money or actor counters are overridden.
		var travel_budget := route.size() * GameConfig.CELL_SIZE / (40.0 * 0.97 * 0.9 * 0.5)
		var budget := travel_budget + game.waves.wave_size * game.waves.spawn_interval + 30.0
		var frames := 0
		while game.phase == TDGame.Phase.WAVE_ACTIVE and frames * DELTA <= budget:
			game.waves._process(DELTA)
			for node in game.board.active_enemies():
				if game.is_finished():
					break
				(node as Enemy)._process(DELTA)
			for node in game.board.get_node("Towers").get_children():
				if game.is_finished():
					break
				(node as Tower)._process(DELTA)
			frames += 1
			if frames % 300 == 0:
				await process_frame
		game.waves.spawn_requested.disconnect(listener)
		if game.phase == TDGame.Phase.WAVE_ACTIVE:
			error = "Wave exceeded route-based travel budget"
			break
		if game.phase == TDGame.Phase.BETWEEN_WAVES:
			cleared += 1
		rows.append({"wave": wave, "status": "defeat" if game.is_finished() else "clear", "lives": game.lives,
			"start_gold": start_gold, "end_gold": game.currency, "towers": game.board.get_node("Towers").get_child_count(),
			"route_cells": route.size(), "sim_seconds": snappedf(frames * DELTA, 0.001), "combat": metrics})
		print("Comparison %s: wave=%d %s lives=%d towers=%d route=%d max_hp=%d armor=%d sim=%.1fs elapsed=%.1fs" % [name, wave,
			"DEFEAT" if game.is_finished() else "clear", game.lives, game.board.get_node("Towers").get_child_count(), route.size(),
			metrics.max_hp, metrics.max_armor, frames * DELTA, (Time.get_ticks_msec() - started) / 1000.0])
		await process_frame
		if game.is_finished():
			break
	var tower_summary := {"basic": 0, "tesla": 0, "upgrade_levels": 0}
	for node in game.board.get_node("Towers").get_children():
		var tower := node as Tower
		tower_summary["basic" if tower.kind == Tower.Kind.BASIC else "tesla"] += 1
		tower_summary.upgrade_levels += tower.upgrade_level
	var result := {"policy": name, "cleared": cleared, "last_wave": game.waves.current_wave, "lives": game.lives,
		"outcome": "error" if not error.is_empty() else ("defeat" if game.is_finished() else "cap"), "error": error,
		"gold": game.currency, "tower_summary": tower_summary, "skills": game.progression.unlocked.duplicate(),
		"gaps": state.gaps, "waves": rows, "elapsed_seconds": (Time.get_ticks_msec() - started) / 1000.0}
	if not error.is_empty():
		failed = true
		printerr("FAIL: ", name, ": ", error)
	game.free()
	await process_frame
	return result


func _run() -> void:
	if not policy in ["best", "hallway", "both"]:
		printerr("FAIL: unknown comparison policy")
		quit(1)
		return
	var results: Array[Dictionary] = []
	for name in ["best", "hallway"]:
		if policy == "both" or policy == name:
			results.append(await _session(name))
	var report := {"label": label, "engine": Engine.get_version_info().string, "seed": seed_value, "wave_cap": cap,
		"step_seconds": DELTA, "generator_sha256": FileAccess.get_sha256("res://scripts/wave_generator.gd"),
		"config_sha256": FileAccess.get_sha256("res://scripts/game_config.gd"), "results": results}
	if assert_near_50:
		var winning_wave := 0
		for result in results:
			winning_wave = maxi(winning_wave, int(result.last_wave))
			if result.outcome != "defeat":
				failed = true
		if results.size() != 2 or winning_wave < 45 or winning_wave > 55:
			failed = true
			printerr("FAIL: winning bot must reach defeat in waves 45–55")
	var file := FileAccess.open(report_path, FileAccess.WRITE)
	if file == null:
		printerr("FAIL: cannot write comparison report")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("Comparison report: ", report_path)
	for result in results:
		print("Comparison RESULT: %s cleared=%d last_wave=%d outcome=%s" % [result.policy, result.cleared, result.last_wave, result.outcome])
	quit(1 if failed else 0)
