class_name ConfirmDialog
extends Control
## Full-screen "Are you sure?" modal. Swallows all input while open; Esc or Cancel
## answers no. Main pauses the game while it is open and decides what a "yes" does.

signal answered(confirmed: bool)

const CARD_SIZE: Vector2 = Vector2(540, 200)

var _title_label: Label
var _body_label: Label
var _confirm_button: Button
var _cancel_button: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var card: PanelContainer = PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = CARD_SIZE
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.offset_left = -CARD_SIZE.x / 2.0
	card.offset_top = -CARD_SIZE.y / 2.0
	card.offset_right = CARD_SIZE.x / 2.0
	card.offset_bottom = CARD_SIZE.y / 2.0
	card.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.CARD, UiTheme.DANGER.darkened(0.2), 2, 14, 24, 20))
	add_child(card)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	card.add_child(column)
	_title_label = Label.new()
	_title_label.theme_type_variation = "Title"
	column.add_child(_title_label)
	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.custom_minimum_size = Vector2(0, 64)
	_body_label.add_theme_color_override("font_color", UiTheme.MUTED.lightened(0.25))
	column.add_child(_body_label)

	var buttons: HBoxContainer = HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	column.add_child(buttons)
	_cancel_button = Button.new()
	_cancel_button.name = "CancelButton"
	_cancel_button.text = "Cancel"
	_cancel_button.custom_minimum_size = Vector2(150, 40)
	_cancel_button.focus_mode = Control.FOCUS_NONE
	_cancel_button.pressed.connect(answer.bind(false))
	buttons.add_child(_cancel_button)
	_confirm_button = Button.new()
	_confirm_button.name = "ConfirmButton"
	_confirm_button.theme_type_variation = "DangerButton"
	_confirm_button.custom_minimum_size = Vector2(190, 40)
	_confirm_button.focus_mode = Control.FOCUS_NONE
	_confirm_button.pressed.connect(answer.bind(true))
	buttons.add_child(_confirm_button)


func ask(title: String, body: String, confirm_text: String) -> void:
	_title_label.text = title
	_body_label.text = body
	_confirm_button.text = confirm_text
	visible = true


func is_open() -> bool:
	return visible


## Closes the dialog and reports the answer (no-op if already closed).
func answer(confirmed: bool) -> void:
	if not visible:
		return
	visible = false
	answered.emit(confirmed)


func get_confirm_button() -> Button:
	return _confirm_button


func get_cancel_button() -> Button:
	return _cancel_button


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		answer(false)
