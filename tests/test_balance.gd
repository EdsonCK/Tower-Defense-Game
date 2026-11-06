extends "res://tests/test_base.gd"
## Balance guard on the fixed-path maps, using the scripted strategies in tests/bots.gd
## on fixed seeds (deterministic, fresh save each run).
##   godot --headless --path <project> --script res://tests/test_balance.gd   (~1-2 min)

const BOTS: GDScript = preload("res://tests/bots.gd")
const SEEDS: Array[int] = [101, 202]


func get_tests() -> Array[Callable]:
	return [
		test_random_placement_fails_quickly,
		test_strategic_bot_loses_between_25_and_50,
	]


func _step(main: Node2D, dt: float) -> void:
	_simulate(main, dt, 1)
	_free_resolved(main)


func _play(kind: String, seed_value: int, max_wave: int) -> Dictionary:
	var main: Node2D = _make_main(seed_value, true)
	var bot = BOTS.new(kind, seed_value)
	var reached: int = bot.play(main, max_wave, _step)
	var levels: int = 0
	var types: Dictionary = {}
	for tower: Tower in main._towers_by_cell.values():
		levels += tower.upgrade_level
		types[tower.tower_type] = types.get(tower.tower_type, 0) + 1
	var result: Dictionary = {"wave": reached, "defeated": main.is_game_over(), "towers": main.get_tower_count(), "levels": levels, "types": types}
	_cleanup_root()
	return result


func test_random_placement_fails_quickly() -> void:
	for seed_value: int in [101, 202, 303]:
		var result: Dictionary = _play("random", seed_value, 40)
		_check(result["defeated"] and result["wave"] <= 10, "random Basic towers (seed %d) are defeated by wave 10 (wave %d)" % [seed_value, result["wave"]])


func test_strategic_bot_loses_between_25_and_50() -> void:
	for seed_value: int in SEEDS:
		var result: Dictionary = _play("good", seed_value, 60)
		print("  ..   [%s] seed %d: %s" % [_current_test, seed_value, result])
		_check(result["defeated"] and result["wave"] >= 25 and result["wave"] <= 50, "the strategic bot (seed %d) loses between waves 25 and 50 (wave %d)" % [seed_value, result["wave"]])
		_check(result["levels"] >= result["towers"] / 4, "it upgrades as well as builds (%d towers, %d upgrade levels)" % [result["towers"], result["levels"]])
		_check(result["types"].size() == TowerTypes.ORDER.size(), "and uses every tower type (%s)" % result["types"])
