class_name WaveManager
extends Node
## Owns wave progress for the endless game: current wave, the spawn queue built by
## WaveGenerator, the spawn timer and the count of spawned-but-unresolved enemies
## (including split children). Starts a wave only when told to.

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal enemy_spawned(enemy: Enemy)
signal enemy_killed(enemy: Enemy)
signal enemy_escaped(enemy: Enemy)

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemy.tscn")

## 1-based number of the most recently started wave (0 before the first).
var current_wave: int = 0
var run_seed: int = 0

var _board: Board
var _generator: WaveGenerator
var _queue: Array[Dictionary] = []
var _queue_index: int = 0
var _alive: int = 0
var _spawn_timer: float = 0.0
var _active: bool = false
var _stopped: bool = false
var _preview_wave: int = -1
var _preview: Dictionary = {}


func setup(board: Board) -> void:
	_board = board


func is_wave_active() -> bool:
	return _active


## Waves are endless; only a stop (defeat) prevents another.
func has_next_wave() -> bool:
	return not _stopped


func get_remaining_to_spawn() -> int:
	return _queue.size() - _queue_index


func get_unresolved_count() -> int:
	return _alive


## Type id -> count for the wave after the current one (cached per wave).
func preview_next_wave() -> Dictionary:
	if _preview_wave != current_wave + 1:
		_preview_wave = current_wave + 1
		_preview = _generator.summarize(_preview_wave)
	return _preview


## Starts the next wave. Returns false (and does nothing) if a wave is running or the
## manager is stopped.
func start_next_wave() -> bool:
	if _active or not has_next_wave():
		return false
	current_wave += 1
	_queue = _generator.generate(current_wave)
	_queue_index = 0
	_spawn_timer = 0.0  # first enemy spawns immediately
	_active = true
	wave_started.emit(current_wave)
	return true


## Stops all spawning permanently (defeat) until reset().
func stop() -> void:
	_stopped = true
	_active = false
	_queue.clear()
	_queue_index = 0


## Starts a new run. A negative seed picks a random one so each run differs.
func reset(seed_value: int = -1) -> void:
	run_seed = seed_value if seed_value >= 0 else randi()
	_generator = WaveGenerator.new(run_seed)
	_preview_wave = -1
	current_wave = 0
	_queue.clear()
	_queue_index = 0
	_alive = 0
	_spawn_timer = 0.0
	_active = false
	_stopped = false


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if not _active or get_remaining_to_spawn() <= 0:
		return
	_spawn_timer -= delta
	while _active and get_remaining_to_spawn() > 0 and _spawn_timer <= 0.0:
		var entry: Dictionary = _queue[_queue_index]
		_queue_index += 1
		_spawn_timer += entry["interval"]
		var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
		enemy.setup(_board, entry, current_wave)
		_add_enemy(enemy)


func _add_enemy(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)
	enemy.reached_exit.connect(_on_enemy_reached_exit)
	_alive += 1
	_board.enemies.add_child(enemy)
	enemy_spawned.emit(enemy)


func _spawn_split_children(parent: Enemy) -> void:
	var def: Dictionary = EnemyTypes.get_def(parent.type_id)
	var child_type: String = def["split_into"]
	if child_type == "":
		return
	for i in int(def["split_count"]):
		var child: Enemy = ENEMY_SCENE.instantiate() as Enemy
		child.setup_split_from(parent, WaveGenerator.make_entry(child_type, parent.wave), i)
		_add_enemy(child)


func _on_enemy_died(enemy: Enemy) -> void:
	_alive -= 1
	# Children are counted before the completion check so the wave cannot end early.
	_spawn_split_children(enemy)
	enemy_killed.emit(enemy)
	_check_wave_complete()


func _on_enemy_reached_exit(enemy: Enemy) -> void:
	_alive -= 1
	enemy_escaped.emit(enemy)
	_check_wave_complete()


func _check_wave_complete() -> void:
	# A listener may have stopped the manager (defeat) while handling the signal above.
	if _active and get_remaining_to_spawn() == 0 and _alive == 0:
		_active = false
		wave_completed.emit(current_wave)
