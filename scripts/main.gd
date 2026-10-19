class_name TDGame
extends Node2D
## Authoritative economy, game phase, purchase transaction, and system wiring.

enum Phase { READY, WAVE_ACTIVE, BETWEEN_WAVES, VICTORY, DEFEAT }

@export var tower_scene: PackedScene = preload("res://scenes/tower.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var currency := GameConfig.STARTING_CURRENCY
var lives := GameConfig.STARTING_LIVES
var phase := Phase.READY
var building := false

@onready var board: Board = $Board
@onready var hud: GameHUD = $HUD/UILayout
@onready var waves: WaveManager = $WaveManager


func _ready() -> void:
	hud.build_requested.connect(select_tower)
	hud.cancel_requested.connect(cancel_build)
	hud.restart_requested.connect(restart)
	hud.start_wave_requested.connect(start_wave)
	waves.spawn_requested.connect(_spawn_enemy)
	waves.wave_completed.connect(_on_wave_completed)
	_refresh_hud()
	hud.show_message("Create a maze of towers. Keep a route open from the entrance to the exit.")


func is_finished() -> bool:
	return phase == Phase.VICTORY or phase == Phase.DEFEAT


func select_tower() -> void:
	if is_finished():
		return
	if currency < GameConfig.TOWER_COST:
		hud.show_message("Insufficient currency")
		return
	building = true
	_refresh_hud()
	hud.show_message("Left-click a green tile to build. Right-click or Escape cancels.")


func cancel_build() -> void:
	building = false
	_refresh_hud()


func _input(event: InputEvent) -> void:
	# Cancellation also works over a UI panel.
	if is_finished():
		return
	if (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		cancel_build()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if not building or is_finished():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pixel := board.get_local_mouse_position()
		if board.contains_pixel(pixel):
			purchase_tower(board.pixel_to_cell(pixel))
			get_viewport().set_input_as_handled()


func purchase_tower(cell: Vector2i) -> bool:
	if is_finished():
		return false
	var error := board.try_block_cell(cell, currency)
	if not error.is_empty():
		hud.show_message(error)
		return false
	# Occupancy and money form a transaction. Instantiation failure rolls it back.
	var instance: Node = tower_scene.instantiate() if tower_scene != null and tower_scene.can_instantiate() else null
	if not instance is Tower:
		if instance != null:
			instance.free()
		board.rollback_placement(cell)
		hud.show_message("Tower could not be created; purchase canceled")
		return false
	var tower := instance as Tower
	tower.position = board.cell_to_pixel(cell)
	board.get_node("Towers").add_child(tower)
	currency -= GameConfig.TOWER_COST
	board.confirm_placement()
	if currency < GameConfig.TOWER_COST:
		building = false
	_refresh_hud()
	hud.show_message("Tower built • -%d currency" % GameConfig.TOWER_COST)
	return true


func restart() -> void:
	# Deferred so the button's signal dispatch finishes before its scene is freed.
	get_tree().call_deferred("reload_current_scene")


func start_wave() -> void:
	if is_finished() or phase == Phase.WAVE_ACTIVE:
		return
	if waves.start_next_wave():
		phase = Phase.WAVE_ACTIVE
		hud.show_message("Wave %d started • You may keep building" % waves.current_wave)
		_refresh_hud()


func _spawn_enemy(hit_points: int) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.died.connect(_on_enemy_died)
	enemy.reached_exit.connect(_on_enemy_reached_exit)
	enemy.navigation_failed.connect(_on_navigation_failed)
	board.get_node("Enemies").add_child(enemy)
	enemy.setup(board, hit_points)
	_refresh_hud()


func _on_enemy_died(_enemy: Enemy) -> void:
	if is_finished():
		return
	currency += GameConfig.KILL_BOUNTY
	waves.enemy_resolved()
	_refresh_hud()


func _on_enemy_reached_exit(_enemy: Enemy) -> void:
	if is_finished():
		return
	lives = maxi(0, lives - GameConfig.BASE_DAMAGE)
	if lives == 0:
		_finish(Phase.DEFEAT)
	else:
		hud.show_message("An enemy reached the exit • -1 base life")
	waves.enemy_resolved()
	_refresh_hud()


func _on_wave_completed(wave: int) -> void:
	if is_finished() or lives <= 0:
		return
	if wave == GameConfig.WAVE_COUNTS.size():
		_finish(Phase.VICTORY)
	else:
		currency += GameConfig.WAVE_CLEAR_BONUS
		phase = Phase.BETWEEN_WAVES
		hud.show_message("Wave %d cleared • +%d currency • Press Start Wave when ready" % [wave, GameConfig.WAVE_CLEAR_BONUS])
	_refresh_hud()


func _finish(result: Phase) -> void:
	phase = result
	building = false
	waves.stop()
	board.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	board.get_node("Towers").process_mode = Node.PROCESS_MODE_DISABLED
	hud.show_message("VICTORY • All three waves cleared! Restart to play again." if result == Phase.VICTORY else "DEFEAT • The base has fallen. Restart to try a new maze.")
	_refresh_hud()


func _on_navigation_failed(message: String) -> void:
	# Unexpected invariant failure remains visible; never remove a stuck enemy.
	hud.show_message("NAVIGATION ERROR: " + message)


func _refresh_hud() -> void:
	var status: String = Phase.keys()[phase].replace("_", " ")
	if phase == Phase.WAVE_ACTIVE:
		status += "\n%d active • %d to spawn" % [waves.active_count, waves.remaining_to_spawn]
	hud.display(currency, lives, waves.current_wave, status, building, waves.can_start(), is_finished())
	board.set_build_preview(building, currency)
