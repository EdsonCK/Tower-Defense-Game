class_name SkillTreeMenu
extends Control
## Modal skill tree overlay. Built from SkillTree.SKILLS data, so adding a skill only
## needs a new entry there (with a free "pos"). It shows state and emits intents;
## Main owns diamonds and decides whether an unlock succeeds.
## While open it covers the whole screen and swallows input; Main pauses the game.

signal unlock_requested(skill_id: String)
signal closed
signal reset_requested

const PANEL_SIZE: Vector2 = Vector2(1160, 760)
const NODE_SIZE: Vector2 = Vector2(196, 64)
const COLUMN_WIDTH: float = 218.0
const ROW_HEIGHT: float = 104.0
const COLUMN_TITLES: Array[String] = ["Basic Tower", "Tesla Tower", "Gold", "Enemy Nerfs", "Permanent"]
const COLOR_UNLOCKED: Color = Color(0.45, 1.0, 0.5)
const COLOR_AVAILABLE: Color = Color(1.0, 0.9, 0.45)
const COLOR_LOCKED: Color = Color(0.55, 0.55, 0.6)

var _buttons: Dictionary = {}  # skill id -> Button
var _tree_area: Control
var _title_label: Label
var _diamonds_label: Label
var _desc_label: Label
var _reset_button: Button
var _skills: SkillTree
var _diamonds: int = 0
var _reset_armed: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var panel: PanelContainer = PanelContainer.new()
	panel.name = "Panel"
	panel.custom_minimum_size = PANEL_SIZE
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -PANEL_SIZE.x / 2.0
	panel.offset_top = -PANEL_SIZE.y / 2.0
	panel.offset_right = PANEL_SIZE.x / 2.0
	panel.offset_bottom = PANEL_SIZE.y / 2.0
	var panel_style: StyleBoxFlat = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.12, 0.15)
	panel_style.border_color = Color(0.35, 0.6, 0.75)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", panel_style)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_title_label)
	_diamonds_label = Label.new()
	_diamonds_label.add_theme_font_size_override("font_size", 20)
	_diamonds_label.add_theme_color_override("font_color", Color(0.55, 0.9, 1.0))
	_diamonds_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(_diamonds_label)

	_tree_area = Control.new()
	_tree_area.name = "TreeArea"
	_tree_area.custom_minimum_size = Vector2(COLUMN_WIDTH * COLUMN_TITLES.size(), ROW_HEIGHT * 4.0 + 40.0)
	_tree_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tree_area.draw.connect(_draw_links)
	column.add_child(_tree_area)
	for i in COLUMN_TITLES.size():
		var header: Label = Label.new()
		header.text = COLUMN_TITLES[i]
		header.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		# Column titles sit under the tree so no connector line crosses them.
		header.position = Vector2(COLUMN_WIDTH * i, ROW_HEIGHT * 3.0 + 26.0 + NODE_SIZE.y + 8.0)
		header.size = Vector2(COLUMN_WIDTH, 24)
		_tree_area.add_child(header)
	for id: String in SkillTree.SKILLS:
		var button: Button = Button.new()
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.position = _node_position(id)
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.pressed.connect(_on_skill_pressed.bind(id))
		button.mouse_entered.connect(_show_description.bind(id))
		_tree_area.add_child(button)
		_buttons[id] = button

	_desc_label = Label.new()
	_desc_label.custom_minimum_size = Vector2(0, 52)
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.add_theme_font_size_override("font_size", 17)
	column.add_child(_desc_label)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.alignment = BoxContainer.ALIGNMENT_CENTER
	footer.add_theme_constant_override("separation", 24)
	column.add_child(footer)
	_reset_button = Button.new()
	_reset_button.custom_minimum_size = Vector2(240, 40)
	_reset_button.focus_mode = Control.FOCUS_NONE
	_reset_button.pressed.connect(_on_reset_pressed)
	footer.add_child(_reset_button)
	var close_button: Button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Continue"
	close_button.custom_minimum_size = Vector2(240, 40)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	footer.add_child(close_button)


func _node_position(id: String) -> Vector2:
	var pos: Vector2i = SkillTree.SKILLS[id]["pos"]
	# Row 0 (the root) sits above the column titles; other rows sit below them.
	var y: float = 0.0 if pos.y == 0 else ROW_HEIGHT * pos.y
	return Vector2(COLUMN_WIDTH * pos.x + (COLUMN_WIDTH - NODE_SIZE.x) / 2.0, y)


func open(subtitle: String, diamonds: int, skills: SkillTree) -> void:
	_title_label.text = subtitle
	_reset_armed = false
	refresh(diamonds, skills)
	_desc_label.text = "Hover a skill to see what it does. Unlocks are permanent and carry over to every future run."
	visible = true


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func refresh(diamonds: int, skills: SkillTree) -> void:
	_diamonds = diamonds
	_skills = skills
	_diamonds_label.text = "Diamonds: %d" % diamonds
	for id: String in _buttons:
		var button: Button = _buttons[id]
		var skill: Dictionary = SkillTree.SKILLS[id]
		var color: Color
		if skills.is_unlocked(id):
			button.text = "%s\nUNLOCKED" % skill["name"]
			button.disabled = true
			color = COLOR_UNLOCKED
		elif skills.prerequisites_met(id):
			button.text = "%s\n%d diamonds" % [skill["name"], skill["cost"]]
			button.disabled = not skills.can_unlock(id, diamonds)
			color = COLOR_AVAILABLE
		else:
			button.text = "%s\nlocked (%d)" % [skill["name"], skill["cost"]]
			button.disabled = true
			color = COLOR_LOCKED
		for state: String in ["font_color", "font_disabled_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(state, color)
		for style_name: String in ["normal", "disabled", "hover", "pressed"]:
			button.add_theme_stylebox_override(style_name, _node_style(color, style_name == "hover" and not button.disabled))
	_reset_button.text = "Click again to reset everything" if _reset_armed else "Reset progress"
	_tree_area.queue_redraw()


func _node_style(color: Color, highlighted: bool) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.17, 0.2) if not highlighted else Color(0.24, 0.25, 0.3)
	style.border_color = color
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	return style


func get_skill_button(id: String) -> Button:
	return _buttons[id]


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_skill_pressed(id: String) -> void:
	_show_description(id)
	unlock_requested.emit(id)


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		_reset_button.text = "Click again to reset everything"
		return
	_reset_armed = false
	reset_requested.emit()


func _show_description(id: String) -> void:
	var skill: Dictionary = SkillTree.SKILLS[id]
	var status: String = ""
	if _skills != null:
		if _skills.is_unlocked(id):
			status = "  (unlocked)"
		elif not _skills.prerequisites_met(id):
			var needed: PackedStringArray = PackedStringArray()
			for required: String in skill["requires"]:
				needed.append(SkillTree.SKILLS[required]["name"])
			status = "  (requires %s)" % ", ".join(needed)
		elif _diamonds < skill["cost"]:
			status = "  (need %d more diamonds)" % (skill["cost"] - _diamonds)
	_desc_label.text = "%s - %d diamonds%s\n%s" % [skill["name"], skill["cost"], status, skill["desc"]]


func _draw_links() -> void:
	for id: String in SkillTree.SKILLS:
		for required: String in SkillTree.SKILLS[id]["requires"]:
			var from: Vector2 = _node_position(required) + Vector2(NODE_SIZE.x / 2.0, NODE_SIZE.y)
			var to: Vector2 = _node_position(id) + Vector2(NODE_SIZE.x / 2.0, 0.0)
			var lit: bool = _skills != null and _skills.is_unlocked(id)
			_tree_area.draw_line(from, to, COLOR_UNLOCKED if lit else Color(0.4, 0.4, 0.45), 3.0 if lit else 2.0)
