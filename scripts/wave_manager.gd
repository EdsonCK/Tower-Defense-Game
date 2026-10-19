class_name WaveManager
extends Node
## Owns all scheduled/unresolved enemy counts. Main owns no parallel counter.

signal spawn_requested(hit_points: int)
signal wave_completed(wave: int)

var current_wave := 0
var remaining_to_spawn := 0
var active_count := 0
var running := false
var _until_spawn := 0.0


func can_start() -> bool:
	return not running and remaining_to_spawn == 0 and active_count == 0 and current_wave < GameConfig.WAVE_COUNTS.size()


func start_next_wave() -> bool:
	if not can_start():
		return false
	current_wave += 1
	remaining_to_spawn = GameConfig.WAVE_COUNTS[current_wave - 1]
	_until_spawn = 0.0 # First enemy on the next process tick, then every 1.2 s.
	running = true
	return true


func _process(delta: float) -> void:
	if not running or remaining_to_spawn == 0:
		return
	_until_spawn -= delta
	while running and remaining_to_spawn > 0 and _until_spawn <= 0.0:
		remaining_to_spawn -= 1
		active_count += 1
		_until_spawn += GameConfig.SPAWN_INTERVAL
		spawn_requested.emit(GameConfig.WAVE_HEALTH[current_wave - 1])


func enemy_resolved() -> void:
	assert(active_count > 0, "An enemy must be counted before it resolves")
	active_count -= 1
	if running and remaining_to_spawn == 0 and active_count == 0:
		running = false # Prevent duplicate completion and automatic next waves.
		wave_completed.emit(current_wave)


func stop() -> void:
	running = false
	remaining_to_spawn = 0
