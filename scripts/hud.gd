class_name GameHUD
extends Control
## Displays Main's state and emits intents; never changes gameplay state.

signal build_requested
signal cancel_requested
signal start_wave_requested
signal restart_requested

@onready var currency_label: Label = $RightPanel/Margin/Items/Currency
@onready var lives_label: Label = $RightPanel/Margin/Items/Lives
@onready var wave_label: Label = $RightPanel/Margin/Items/Wave
@onready var status_label: Label = $RightPanel/Margin/Items/Status
@onready var build_button: Button = $RightPanel/Margin/Items/BuildTower
@onready var cancel_button: Button = $RightPanel/Margin/Items/Cancel
@onready var start_button: Button = $RightPanel/Margin/Items/StartWave
@onready var selection_label: Label = $BottomPanel/Margin/Items/Selection
@onready var message_label: Label = $BottomPanel/Margin/Items/Message


func _ready() -> void:
	build_button.pressed.connect(func() -> void: build_requested.emit())
	cancel_button.pressed.connect(func() -> void: cancel_requested.emit())
	start_button.pressed.connect(func() -> void: start_wave_requested.emit())
	$RightPanel/Margin/Items/Restart.pressed.connect(func() -> void: restart_requested.emit())


func display(currency: int, lives: int, wave: int, status: String, building: bool, can_start: bool, finished: bool) -> void:
	currency_label.text = "Currency: %d" % currency
	lives_label.text = "Base lives: %d" % lives
	wave_label.text = "Wave: %d / %d" % [wave, GameConfig.WAVE_COUNTS.size()]
	status_label.text = status
	build_button.disabled = finished or currency < GameConfig.TOWER_COST
	cancel_button.disabled = finished or not building
	start_button.disabled = finished or not can_start
	selection_label.text = "BUILD MODE • Left-click to place • Stays selected until canceled or funds run out" if building else "No tower selected • Choose Build Tower to begin"


func show_message(message: String) -> void:
	message_label.text = message
