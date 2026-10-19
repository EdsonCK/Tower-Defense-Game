class_name Hud
extends Control
## Displays game state, forwards button presses as intent signals and shows messages.
## Holds no currency, lives or pathfinding logic.

signal build_pressed
signal cancel_pressed
signal start_wave_pressed
signal restart_pressed

const COLOR_INFO: Color = Color(0.9, 0.9, 0.9)
const COLOR_ERROR: Color = Color(1.0, 0.45, 0.4)

@onready var _currency_label: Label = $RightPanel/Margin/VBox/CurrencyLabel
@onready var _lives_label: Label = $RightPanel/Margin/VBox/LivesLabel
@onready var _wave_label: Label = $RightPanel/Margin/VBox/WaveLabel
@onready var _enemies_label: Label = $RightPanel/Margin/VBox/EnemiesLabel
@onready var _state_label: Label = $RightPanel/Margin/VBox/StateLabel
@onready var _tower_info_label: Label = $RightPanel/Margin/VBox/TowerInfoLabel
@onready var _build_button: Button = $RightPanel/Margin/VBox/BuildButton
@onready var _cancel_button: Button = $RightPanel/Margin/VBox/CancelButton
@onready var _start_wave_button: Button = $RightPanel/Margin/VBox/StartWaveButton
@onready var _restart_button: Button = $RightPanel/Margin/VBox/RestartButton
@onready var _mode_label: Label = $BottomPanel/Margin/VBox/ModeLabel
@onready var _message_label: Label = $BottomPanel/Margin/VBox/MessageLabel


func _ready() -> void:
	# The transparent full-screen layout must not swallow board clicks; panels stop them.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_button.pressed.connect(build_pressed.emit)
	_cancel_button.pressed.connect(cancel_pressed.emit)
	_start_wave_button.pressed.connect(start_wave_pressed.emit)
	_restart_button.pressed.connect(restart_pressed.emit)
	_tower_info_label.text = "Tower: %d currency\nRange %d px, %d dmg every %.1f s" % [
		GameConfig.TOWER_COST, int(GameConfig.TOWER_RANGE), GameConfig.TOWER_DAMAGE, GameConfig.TOWER_COOLDOWN,
	]


func update_status(currency: int, lives: int, wave: int, total_waves: int, state_text: String) -> void:
	_currency_label.text = "Currency: %d" % currency
	_lives_label.text = "Lives: %d" % lives
	_wave_label.text = "Wave: %d / %d" % [wave, total_waves]
	_state_label.text = state_text


func update_enemy_counts(to_spawn: int, active: int) -> void:
	_enemies_label.text = "Enemies: %d active, %d to spawn" % [active, to_spawn]


func set_buttons(can_build: bool, can_start_wave: bool, build_mode: bool) -> void:
	_build_button.disabled = not can_build or build_mode
	_cancel_button.disabled = not build_mode
	_start_wave_button.disabled = not can_start_wave


func set_build_mode(active: bool) -> void:
	if active:
		_mode_label.text = "BUILD MODE: left-click a tile to place a tower (stays on until canceled or out of currency). Right-click / Esc cancels."
	else:
		_mode_label.text = "Click Build Tower to place towers. Towers block tiles; enemies path around them."


func show_message(text: String) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", COLOR_INFO)


func show_error(text: String) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", COLOR_ERROR)


func get_message() -> String:
	return _message_label.text
