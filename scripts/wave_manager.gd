class_name WaveManager
extends Node
## Owns all scheduled/unresolved enemy counts. Main owns no parallel counter.

signal spawn_requested(profile: EnemyProfile)
signal wave_completed(wave: int)

var current_wave := 0
var remaining_to_spawn := 0
var active_count := 0
var running := false
var _until_spawn := 0.0
var wave_size := 0
var spawn_interval := GameConfig.SPAWN_INTERVAL
var _generator := WaveGenerator.new()
var _plan: Array[EnemyProfile] = []
var _spawn_index := 0


func set_run_seed(seed_value: int) -> void:
	assert(not running)
	_generator = WaveGenerator.new(seed_value)


func get_run_seed() -> int:
	return _generator.run_seed


func can_start() -> bool:
	return not running and remaining_to_spawn == 0 and active_count == 0


func start_next_wave() -> bool:
	if not can_start():
		return false
	current_wave += 1
	_plan = _generator.generate(current_wave)
	wave_size = _plan.size()
	remaining_to_spawn = wave_size
	_spawn_index = 0
	spawn_interval = _generator.interval_for(current_wave)
	_until_spawn = 0.0 # First enemy next process tick, followed by this wave's interval.
	running = true
	return true


func _process(delta: float) -> void:
	if not running or remaining_to_spawn == 0:
		return
	_until_spawn -= delta
	while running and remaining_to_spawn > 0 and _until_spawn <= 0.0:
		remaining_to_spawn -= 1
		active_count += 1
		_until_spawn += spawn_interval
		var profile := _plan[_spawn_index]
		_spawn_index += 1
		spawn_requested.emit(profile)


func enemy_resolved() -> void:
	assert(active_count > 0, "An enemy must be counted before it resolves")
	active_count -= 1
	if running and remaining_to_spawn == 0 and active_count == 0:
		running = false # Prevent duplicate completion and automatic next waves.
		_plan.clear()
		wave_completed.emit(current_wave)


func stop() -> void:
	running = false
	remaining_to_spawn = 0
	_plan.clear()
