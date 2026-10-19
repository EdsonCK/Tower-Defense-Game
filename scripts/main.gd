class_name TDGame
extends Node2D
## Authoritative economy, game phase, purchase transaction, and system wiring.

enum Phase { READY, WAVE_ACTIVE, BETWEEN_WAVES, DEFEAT }

@export var tower_scene: PackedScene = preload("res://scenes/tower.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var currency := GameConfig.STARTING_CURRENCY
var lives := GameConfig.STARTING_LIVES
var phase := Phase.READY
var building := false
var selected_tower: Tower

@onready var board: Board = $Board
@onready var hud: GameHUD = $HUD/UILayout
@onready var waves: WaveManager = $WaveManager


func _ready() -> void:
	hud.build_requested.connect(select_tower)
	hud.cancel_requested.connect(cancel_build)
	hud.restart_requested.connect(restart)
	hud.start_wave_requested.connect(start_wave)
	hud.upgrade_requested.connect(upgrade_selected_tower)
	hud.remove_requested.connect(remove_selected_tower)
	waves.spawn_requested.connect(_spawn_enemy)
	waves.wave_completed.connect(_on_wave_completed)
	_refresh_hud()
	hud.show_message("Create a maze of towers. Keep a route open from the entrance to the exit.")


func is_finished() -> bool:
	return phase == Phase.DEFEAT


func select_tower() -> void:
	if is_finished():
		return
	if currency < GameConfig.TOWER_COST:
		hud.show_message("Insufficient currency")
		return
	selected_tower = null
	building = true
	_refresh_hud()
	hud.show_message("Left-click a green tile to build. Right-click or Escape cancels.")


func cancel_build() -> void:
	selected_tower = null
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
	if is_finished():
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pixel: Vector2 = board.get_global_transform_with_canvas().affine_inverse() * event.position
		if board.contains_pixel(pixel):
			var cell := board.pixel_to_cell(pixel)
			var tower := tower_at_cell(cell)
			if tower != null:
				select_placed_tower(tower)
			elif building:
				purchase_tower(cell)
			else:
				cancel_build()
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
	tower.cell = cell
	tower.position = board.cell_to_pixel(cell)
	board.get_node("Towers").add_child(tower)
	currency -= GameConfig.TOWER_COST
	board.confirm_placement()
	if currency < GameConfig.TOWER_COST:
		building = false
	_refresh_hud()
	hud.show_message("Tower built • -%d currency" % GameConfig.TOWER_COST)
	return true


func tower_at_cell(cell: Vector2i) -> Tower:
	for child in board.get_node("Towers").get_children():
		var tower := child as Tower
		if tower != null and not tower.is_queued_for_deletion() and tower.cell == cell:
			return tower
	return null


func select_placed_tower(tower: Tower) -> void:
	if is_finished() or not _owns_tower(tower):
		return
	building = false
	selected_tower = tower
	_refresh_hud()
	hud.show_message("Choose one upgrade track, or remove for %d. Upgrades are not refunded." % GameConfig.TOWER_REFUND)


func _owns_tower(tower: Tower) -> bool:
	return is_instance_valid(tower) and not tower.is_queued_for_deletion() and tower.get_parent() == board.get_node("Towers")


func upgrade_selected_tower(track: int) -> bool:
	if is_finished() or not _owns_tower(selected_tower):
		return false
	var error := selected_tower.upgrade_error(track)
	if not error.is_empty():
		hud.show_message(error)
		return false
	var cost := selected_tower.next_upgrade_cost()
	if currency < cost:
		hud.show_message("Insufficient currency")
		return false
	if not selected_tower.apply_upgrade(track):
		return false
	currency -= cost
	_refresh_hud()
	hud.show_message("Tower upgraded • -%d currency • Track locked to %s" % [cost, Tower.Upgrade.keys()[track].to_lower()])
	return true


func remove_selected_tower() -> bool:
	if is_finished() or not _owns_tower(selected_tower):
		return false
	var tower := selected_tower
	if not board.remove_block(tower.cell):
		return false
	selected_tower = null
	tower.set_process(false)
	board.get_node("Towers").remove_child(tower)
	tower.queue_free()
	currency += GameConfig.TOWER_REFUND
	_refresh_hud()
	hud.show_message("Tower removed • +%d currency" % GameConfig.TOWER_REFUND)
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


func _spawn_enemy(profile: EnemyProfile) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.died.connect(_on_enemy_died)
	enemy.reached_exit.connect(_on_enemy_reached_exit)
	enemy.navigation_failed.connect(_on_navigation_failed)
	board.get_node("Enemies").add_child(enemy)
	enemy.setup_profile(board, profile)
	_refresh_hud()


func _on_enemy_died(enemy: Enemy) -> void:
	if is_finished():
		return
	currency += enemy.bounty
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
	currency += GameConfig.WAVE_CLEAR_BONUS
	phase = Phase.BETWEEN_WAVES
	hud.show_message("Wave %d cleared • +%d currency • Press Start Wave when ready" % [wave, GameConfig.WAVE_CLEAR_BONUS])
	_refresh_hud()


func _finish(result: Phase) -> void:
	phase = result
	selected_tower = null
	building = false
	waves.stop()
	board.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	board.get_node("Towers").process_mode = Node.PROCESS_MODE_DISABLED
	hud.show_message("DEFEAT • The base has fallen. Restart for a fresh wave sequence.")
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
	var selected := selected_tower if _owns_tower(selected_tower) else null
	hud.display_tower(selected, currency, is_finished())
	board.show_tower_selection(selected.cell if selected != null else Vector2i(-1, -1), selected.attack_range() if selected != null else 0.0)
