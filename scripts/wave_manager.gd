class_name WaveManager
extends Node
## Owns wave progress: current wave, enemies left to spawn, the spawn timer and the
## count of spawned-but-unresolved enemies. Starts a wave only when told to.

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_spawned(enemy: Enemy)
signal enemy_killed(enemy: Enemy)
signal enemy_escaped(enemy: Enemy)

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

## 1-based number of the most recently started wave (0 before the first).
var current_wave: int = 0

var _board: Board
var _to_spawn: int = 0
var _alive: int = 0
var _spawn_health: int = 0
var _spawn_timer: float = 0.0
var _active: bool = false
var _stopped: bool = false


func setup(board: Board) -> void:
	_board = board


func total_waves() -> int:
	return GameConfig.WAVES.size()


func is_wave_active() -> bool:
	return _active


func has_next_wave() -> bool:
	return not _stopped and current_wave < total_waves()


func get_remaining_to_spawn() -> int:
	return _to_spawn


func get_unresolved_count() -> int:
	return _alive


## Starts the next wave. Returns false (and does nothing) if a wave is running,
## the manager is stopped, or no waves remain.
func start_next_wave() -> bool:
	if _active or not has_next_wave():
		return false
	current_wave += 1
	var wave: Dictionary = GameConfig.WAVES[current_wave - 1]
	_to_spawn = wave["count"]
	_spawn_health = wave["health"]
	_spawn_timer = 0.0  # first enemy spawns immediately
	_active = true
	wave_started.emit(current_wave)
	return true


## Stops all spawning permanently (defeat/victory) until reset().
func stop() -> void:
	_stopped = true
	_active = false
	_to_spawn = 0


func reset() -> void:
	current_wave = 0
	_to_spawn = 0
	_alive = 0
	_spawn_timer = 0.0
	_active = false
	_stopped = false


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if not _active or _to_spawn <= 0:
		return
	_spawn_timer -= delta
	while _active and _to_spawn > 0 and _spawn_timer <= 0.0:
		_spawn_enemy()
		_spawn_timer += GameConfig.SPAWN_INTERVAL


func _spawn_enemy() -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	enemy.setup(_board, _spawn_health)
	enemy.died.connect(_on_enemy_died)
	enemy.reached_exit.connect(_on_enemy_reached_exit)
	_to_spawn -= 1
	_alive += 1
	_board.enemies.add_child(enemy)
	enemy_spawned.emit(enemy)


func _on_enemy_died(enemy: Enemy) -> void:
	_alive -= 1
	enemy_killed.emit(enemy)
	_check_wave_complete()


func _on_enemy_reached_exit(enemy: Enemy) -> void:
	_alive -= 1
	enemy_escaped.emit(enemy)
	_check_wave_complete()


func _check_wave_complete() -> void:
	# A listener may have stopped the manager (defeat) while handling the signal above.
	if _active and _to_spawn == 0 and _alive == 0:
		_active = false
		wave_completed.emit(current_wave)
