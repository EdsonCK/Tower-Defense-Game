extends "res://tests/test_base.gd"
## Balance report (a tuning tool, not a pass/fail test): every bot strategy plays real
## generated waves on several seeds and the wave it reached is printed. Re-run after
## changing enemy, tower, economy or skill numbers.
##   godot --headless --path <project> --script res://tests/balance_report.gd

const BOTS: GDScript = preload("res://tests/bots.gd")
const MAX_WAVE: int = 70


func get_tests() -> Array[Callable]:
	return [report]


func _step(main: Node2D, dt: float) -> void:
	_simulate(main, dt, 1)
	_free_resolved(main)


func report() -> void:
	for kind: String in ["random", "nomaze", "good"]:
		for seed_value: int in [101, 202, 303]:
			var main: Node2D = _make_main(seed_value)
			var bot = BOTS.new(kind, seed_value)
			var leaked: Dictionary = {}
			main.wave_manager.enemy_escaped.connect(func(e: Enemy) -> void: leaked[e.type_id] = leaked.get(e.type_id, 0) + 1)
			var started: int = Time.get_ticks_msec()
			var reached: int = bot.play(main, MAX_WAVE, _step)
			print("BALANCE %-7s seed %d -> %s on wave %d | towers %d, route %d cells, skills %d | last leaks %s | %d ms" % [
				kind, seed_value, "DEFEAT" if main.is_game_over() else "ALIVE", reached, main.get_tower_count(),
				main.board.find_path(SPAWN, EXIT).size(), main.skills.unlocked_ids().size(), leaked, Time.get_ticks_msec() - started])
			_cleanup_root()
