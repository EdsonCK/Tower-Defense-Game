class_name TDGame
extends Node2D
## Authoritative economy, game phase, purchase transaction, and system wiring.

enum Phase { READY, WAVE_ACTIVE, BETWEEN_WAVES, VICTORY, DEFEAT }

@export var tower_scene: PackedScene = preload("res://scenes/tower.tscn")

var currency := GameConfig.STARTING_CURRENCY
var lives := GameConfig.STARTING_LIVES
var phase := Phase.READY
var building := false

@onready var board: Board = $Board
@onready var hud: GameHUD = $HUD/UILayout


func _ready() -> void:
	hud.build_requested.connect(select_tower)
	hud.cancel_requested.connect(cancel_build)
	hud.restart_requested.connect(restart)
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
	get_tree().reload_current_scene()


func _refresh_hud() -> void:
	hud.display(currency, lives, 0, Phase.keys()[phase], building, phase == Phase.READY or phase == Phase.BETWEEN_WAVES, is_finished())
	board.set_build_preview(building, currency)
