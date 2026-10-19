extends Node2D
## Authoritative game manager: currency, lives, build tool, game state, tower purchases,
## win/loss and wiring between Board, WaveManager and HUD.

enum GameState { READY, WAVE_ACTIVE, BETWEEN_WAVES, VICTORY, DEFEAT }

const TOWER_SCENE: PackedScene = preload("res://scenes/tower.tscn")

var currency: int = GameConfig.STARTING_CURRENCY
var lives: int = GameConfig.STARTING_LIVES
var state: GameState = GameState.READY
var build_mode: bool = false

@onready var board: Board = $Board
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: Hud = $HUD/UILayout


func _ready() -> void:
	wave_manager.setup(board)
	board.cell_clicked.connect(_on_board_cell_clicked)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.enemy_spawned.connect(_on_enemy_spawned)
	wave_manager.enemy_killed.connect(_on_enemy_killed)
	wave_manager.enemy_escaped.connect(_on_enemy_escaped)
	hud.build_pressed.connect(_on_build_pressed)
	hud.cancel_pressed.connect(_on_cancel_pressed)
	hud.start_wave_pressed.connect(_on_start_wave_pressed)
	hud.restart_pressed.connect(restart_game)
	restart_game()


func _unhandled_input(event: InputEvent) -> void:
	if not build_mode:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	var right_click: bool = mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT
	if right_click or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()


func is_game_over() -> bool:
	return state == GameState.VICTORY or state == GameState.DEFEAT


## Resets currency, lives, waves, towers, enemies and board occupancy to a fresh game.
func restart_game() -> void:
	wave_manager.reset()
	for enemy: Node in board.enemies.get_children():
		(enemy as Enemy).discard()
	for tower: Node in board.towers.get_children():
		tower.queue_free()
	board.clear_blocked_cells()
	board.enemies.process_mode = Node.PROCESS_MODE_INHERIT
	board.towers.process_mode = Node.PROCESS_MODE_INHERIT
	currency = GameConfig.STARTING_CURRENCY
	lives = GameConfig.STARTING_LIVES
	state = GameState.READY
	_set_build_mode(false)
	hud.show_message("Build towers to shape a maze, then press Start Wave.")
	_refresh_hud()


## Attempts to buy a tower on `cell`. Currency is deducted only after the board accepts
## the block and the tower node exists; any failure leaves the game unchanged.
func try_buy_tower(cell: Vector2i) -> bool:
	if is_game_over():
		return false
	if currency < GameConfig.TOWER_COST:
		hud.show_error("Insufficient currency")
		return false
	var reason: String = board.try_block_cell_live(cell)
	if reason != "":
		hud.show_error(reason)
		return false
	var tower: Tower = TOWER_SCENE.instantiate() as Tower
	if tower == null:
		board.unblock_cell(cell)
		hud.show_error("Tower could not be created")
		return false
	tower.position = Board.cell_to_world(cell)
	board.towers.add_child(tower)
	currency -= GameConfig.TOWER_COST
	if currency < GameConfig.TOWER_COST:
		_set_build_mode(false)
		hud.show_message("Tower built. Not enough currency for another; build mode ended.")
	else:
		hud.show_message("Tower built (-%d)." % GameConfig.TOWER_COST)
	_refresh_hud()
	return true


func _set_build_mode(active: bool) -> void:
	build_mode = active
	hud.set_build_mode(active)
	_refresh_hud()


func _refresh_hud() -> void:
	var state_text: String = GameState.keys()[state].replace("_", " ")
	hud.update_status(currency, lives, wave_manager.current_wave, wave_manager.total_waves(), state_text)
	hud.update_enemy_counts(wave_manager.get_remaining_to_spawn(), wave_manager.get_unresolved_count())
	var can_start: bool = (state == GameState.READY or state == GameState.BETWEEN_WAVES) and wave_manager.has_next_wave()
	hud.set_buttons(not is_game_over(), can_start, build_mode)
	board.set_build_state(build_mode, currency >= GameConfig.TOWER_COST)


func _end_game(final_state: GameState, message: String) -> void:
	state = final_state
	wave_manager.stop()
	# Freeze remaining enemies and towers; only Restart stays available.
	board.enemies.process_mode = Node.PROCESS_MODE_DISABLED
	board.towers.process_mode = Node.PROCESS_MODE_DISABLED
	_set_build_mode(false)
	hud.show_message(message)
	_refresh_hud()


# --- Signal handlers -----------------------------------------------------------

func _on_build_pressed() -> void:
	if is_game_over():
		return
	if currency < GameConfig.TOWER_COST:
		hud.show_error("Insufficient currency")
		return
	_set_build_mode(true)
	hud.show_message("Build mode on.")


func _on_cancel_pressed() -> void:
	if not build_mode:
		return
	_set_build_mode(false)
	hud.show_message("Build mode canceled.")


func _on_board_cell_clicked(cell: Vector2i) -> void:
	if build_mode and not is_game_over():
		try_buy_tower(cell)


func _on_start_wave_pressed() -> void:
	if state != GameState.READY and state != GameState.BETWEEN_WAVES:
		return
	wave_manager.start_next_wave()


func _on_wave_started(wave_number: int) -> void:
	state = GameState.WAVE_ACTIVE
	hud.show_message("Wave %d started!" % wave_number)
	_refresh_hud()


func _on_enemy_spawned(_enemy: Enemy) -> void:
	_refresh_hud()


func _on_enemy_killed(_enemy: Enemy) -> void:
	currency += GameConfig.ENEMY_BOUNTY
	_refresh_hud()


func _on_enemy_escaped(_enemy: Enemy) -> void:
	lives = maxi(lives - GameConfig.BASE_DAMAGE_PER_ENEMY, 0)
	if lives == 0 and not is_game_over():
		_end_game(GameState.DEFEAT, "DEFEAT - the base has fallen. Press Restart to try again.")
		return
	_refresh_hud()


func _on_wave_completed(wave_number: int) -> void:
	if is_game_over():
		return
	if wave_number >= wave_manager.total_waves():
		_end_game(GameState.VICTORY, "VICTORY - all %d waves cleared! Press Restart to play again." % wave_number)
		return
	currency += GameConfig.WAVE_CLEAR_BONUS
	state = GameState.BETWEEN_WAVES
	hud.show_message("Wave %d cleared! +%d bonus. Press Start Wave when ready." % [wave_number, GameConfig.WAVE_CLEAR_BONUS])
	_refresh_hud()
