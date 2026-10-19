class_name Hud
extends Control
## Displays game state, forwards button presses as intent signals and shows messages.
## Holds no currency, lives or pathfinding logic.
##
## Layout contract (keeps UI off the playable board, whatever is added later):
## - The board lives inside BoardArea, a fixed-size slot in the same HBox/VBox
##   container layout as the panels, so panels can never overlap it.
## - Panel content sits in ScrollContainers: too much (or too wide) content scrolls,
##   so panels never grow or push the board.
## - Only nodes in PASSTHROUGH_GROUP (pure layout containers that draw nothing and
##   ignore the mouse) may span the board. tests/test_layout.gd enforces all of this,
##   and _verify_layout() reports any overlap at runtime in debug builds.
## - Scripts reference nodes by unique name (%Name), so layout can be rearranged freely.

signal build_pressed
signal cancel_pressed
signal start_wave_pressed
signal restart_pressed
signal upgrade_pressed(path: int)
signal sell_pressed

const PASSTHROUGH_GROUP: StringName = &"hud_passthrough"
const PASSTHROUGH_CLASSES: Array[String] = ["Control", "HBoxContainer", "VBoxContainer"]
const COLOR_INFO: Color = Color(0.9, 0.9, 0.9)
const COLOR_ERROR: Color = Color(1.0, 0.45, 0.4)

@onready var _board_area: Control = %BoardArea
@onready var _right_panel: Control = %RightPanel
@onready var _bottom_panel: Control = %BottomPanel
@onready var _currency_label: Label = %CurrencyLabel
@onready var _lives_label: Label = %LivesLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _enemies_label: Label = %EnemiesLabel
@onready var _state_label: Label = %StateLabel
@onready var _next_wave_label: Label = %NextWaveLabel
@onready var _tower_info_label: Label = %TowerInfoLabel
@onready var _build_button: Button = %BuildButton
@onready var _cancel_button: Button = %CancelButton
@onready var _start_wave_button: Button = %StartWaveButton
@onready var _restart_button: Button = %RestartButton
@onready var _selection_box: VBoxContainer = %SelectionBox
@onready var _selection_label: Label = %SelectionLabel
@onready var _upgrade_damage_button: Button = %UpgradeDamageButton
@onready var _upgrade_range_button: Button = %UpgradeRangeButton
@onready var _upgrade_speed_button: Button = %UpgradeSpeedButton
@onready var _sell_button: Button = %SellButton
@onready var _mode_label: Label = %ModeLabel
@onready var _message_label: Label = %MessageLabel
@onready var _seed_label: Label = %SeedLabel


func _ready() -> void:
	# The transparent full-screen layout must not swallow board clicks; panels stop them.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_area.custom_minimum_size = Vector2(GameConfig.BOARD_WIDTH, GameConfig.BOARD_HEIGHT)
	if OS.is_debug_build():
		for panel: Control in [_right_panel, _bottom_panel, _board_area]:
			panel.item_rect_changed.connect(_verify_layout, CONNECT_DEFERRED)
	_build_button.pressed.connect(build_pressed.emit)
	_cancel_button.pressed.connect(cancel_pressed.emit)
	_start_wave_button.pressed.connect(start_wave_pressed.emit)
	_restart_button.pressed.connect(restart_pressed.emit)
	_upgrade_damage_button.pressed.connect(upgrade_pressed.emit.bind(Tower.UpgradePath.DAMAGE))
	_upgrade_range_button.pressed.connect(upgrade_pressed.emit.bind(Tower.UpgradePath.RANGE))
	_upgrade_speed_button.pressed.connect(upgrade_pressed.emit.bind(Tower.UpgradePath.SPEED))
	_sell_button.pressed.connect(sell_pressed.emit)
	_tower_info_label.text = "Tower: %d currency - range %d px, %d dmg every %.1f s" % [
		GameConfig.TOWER_COST, int(GameConfig.TOWER_RANGE), GameConfig.TOWER_DAMAGE, GameConfig.TOWER_COOLDOWN,
	]
	hide_selection()


func update_status(currency: int, lives: int, wave: int, state_text: String, run_seed: int) -> void:
	_currency_label.text = "Currency: %d" % currency
	_lives_label.text = "Lives: %d" % lives
	_wave_label.text = "Wave: %d" % wave
	_state_label.text = state_text
	_seed_label.text = "Run seed: %d" % run_seed


func update_enemy_counts(to_spawn: int, active: int) -> void:
	_enemies_label.text = "Enemies: %d active, %d to spawn" % [active, to_spawn]


func update_next_wave(wave: int, counts: Dictionary) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for type_id: String in EnemyTypes.DEFS:
		if counts.has(type_id):
			parts.append("%d %s" % [counts[type_id], EnemyTypes.display_name(type_id)])
	_next_wave_label.text = "Next (wave %d): %s" % [wave, ", ".join(parts)]


func set_buttons(can_build: bool, can_start_wave: bool, build_mode: bool) -> void:
	_build_button.disabled = not can_build or build_mode
	_cancel_button.disabled = not build_mode
	_start_wave_button.disabled = not can_start_wave


func set_build_mode(active: bool) -> void:
	if active:
		_mode_label.text = "BUILD MODE: left-click a tile to place a tower (stays on until canceled or out of currency). Right-click / Esc cancels."
	else:
		_mode_label.text = "Build Tower to place towers. Click a tower to select it, then upgrade or sell it."


## `info` is built by Main from the selected tower; see Main._refresh_selection().
func show_selection(info: Dictionary) -> void:
	_selection_box.visible = true
	var level_text: String = "Level %d/%d (%s)" % [info["level"], info["max_level"], info["path"]] if info["level"] > 0 else "No upgrades yet"
	_selection_label.text = "SELECTED TOWER - %s\nDamage %d, range %d px, every %.2f s" % [
		level_text, info["damage"], int(info["range"]), info["cooldown"],
	]
	var buttons: Dictionary = {
		Tower.UpgradePath.DAMAGE: _upgrade_damage_button,
		Tower.UpgradePath.RANGE: _upgrade_range_button,
		Tower.UpgradePath.SPEED: _upgrade_speed_button,
	}
	for path: int in buttons:
		var button: Button = buttons[path]
		var locked_out: bool = info["locked_path"] != Tower.UpgradePath.NONE and info["locked_path"] != path
		button.visible = not locked_out
		button.disabled = not info["options"][path]
		var cost_text: String = "MAX" if info["next_cost"] < 0 else str(info["next_cost"])
		button.text = "Upgrade %s (%s)" % [Tower.PATH_NAMES[path], cost_text]
	_sell_button.text = "Sell (+%d)" % info["sell_value"]
	_sell_button.disabled = not info["can_sell"]


func hide_selection() -> void:
	_selection_box.visible = false


func is_selection_visible() -> bool:
	return _selection_box.visible


func show_message(text: String) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", COLOR_INFO)


func show_error(text: String) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", COLOR_ERROR)


func get_message() -> String:
	return _message_label.text


## Screen rect reserved for the board (the Board node is a child of this area).
func get_board_rect() -> Rect2:
	return _board_area.get_global_rect()


## Reports an error if a panel ever overlaps the reserved board area.
func _verify_layout() -> void:
	var board_rect: Rect2 = get_board_rect()
	if board_rect.size != Vector2(GameConfig.BOARD_WIDTH, GameConfig.BOARD_HEIGHT):
		push_error("HUD layout: board area is %s, expected %dx%d" % [board_rect.size, GameConfig.BOARD_WIDTH, GameConfig.BOARD_HEIGHT])
	if not get_viewport_rect().encloses(board_rect):
		push_error("HUD layout: board area %s is pushed outside the view" % board_rect)
	for panel: Control in [_right_panel, _bottom_panel]:
		if panel.get_global_rect().intersects(board_rect):
			push_error("HUD layout: %s overlaps the board area" % panel.name)
