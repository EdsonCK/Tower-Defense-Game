extends "res://tests/test_base.gd"
## Balance guard: poorly placed towers must fail quickly, a well-built maze must last.
## Uses the scripted strategies in tests/bots.gd on fixed seeds (deterministic).
##   godot --headless --path <project> --script res://tests/test_balance.gd   (~1-2 min)

const BOTS: GDScript = preload("res://tests/bots.gd")


func get_tests() -> Array[Callable]:
	return [
		test_random_placement_fails_quickly,
		test_unmazed_line_falls_well_short_of_a_maze,
		test_good_maze_survives_long,
	]


func _step(main: Node2D, dt: float) -> void:
	_simulate(main, dt, 1)
	_free_resolved(main)


func _play(kind: String, seed_value: int, max_wave: int) -> Array:
	var main: Node2D = _make_main(seed_value)
	var bot = BOTS.new(kind, seed_value)
	var reached: int = bot.play(main, max_wave, _step)
	var result: Array = [reached, main.is_game_over()]
	_cleanup_root()
	return result


func test_random_placement_fails_quickly() -> void:
	for seed_value: int in [101, 202, 303]:
		var result: Array = _play("random", seed_value, 30)
		_check(result[1] and result[0] <= 5, "random placement (seed %d) is defeated by wave 5 (wave %d)" % [seed_value, result[0]])


func test_unmazed_line_falls_well_short_of_a_maze() -> void:
	for seed_value: int in [101, 202]:
		var result: Array = _play("nomaze", seed_value, 40)
		_check(result[1] and result[0] <= 25, "towers lining the straight route (seed %d) are defeated by wave 25 (wave %d)" % [seed_value, result[0]])


func test_good_maze_survives_long() -> void:
	var result: Array = _play("good", 101, 30)
	_check(not result[1] and result[0] == 30, "a tight serpentine maze with skills and upgrades survives 30 waves (wave %d)" % result[0])
