class_name SkillTreeMenu
extends Control
## Modal skill tree overlay. Built from SkillTree.SKILLS / SkillTree.COLUMNS, so adding a
## skill only needs a new entry there (with a free "pos"). It shows state and emits
## intents; Main owns diamonds and decides whether an unlock succeeds.
## While open it covers the whole screen and swallows input; Main pauses the game.

signal unlock_requested(skill_id: String)
signal closed
signal reset_requested

const PANEL_SIZE: Vector2 = Vector2(1520, 800)
const NODE_SIZE: Vector2 = Vector2(184, 58)
const COLUMN_WIDTH: float = 204.0
const ROW_HEIGHT: float = 84.0
const HEADER_Y: float = 66.0       # column chips sit between the root and row 1
const FIRST_ROW_Y: float = 100.0
const BRANCH_COLORS: Array[Color] = [
	Color(0.33, 0.62, 1.0),   # Basic
	Color(0.68, 0.45, 1.0),   # Tesla
	Color(1.0, 0.6, 0.3),     # Cannon
	Color(1.0, 0.8, 0.3),     # Gold
	Color(1.0, 0.42, 0.5),    # Damage types
	Color(0.4, 0.85, 0.55),   # Enemy nerfs
	Color(0.4, 0.85, 0.95),   # Permanent
]
const ROOT_COLOR: Color = Color(0.68, 0.45, 1.0)

var _buttons: Dictionary = {}  # skill id -> Button
var _tree_area: Control
var _title_label: Label
var _diamonds_label: Label
var _info_name: Label
var _info_status: Label
var _info_desc: Label
var _skills: SkillTree
var _diamonds: int = 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_build()


func _build() -> void:
	var backdrop: ColorRect = ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.05, 0.82)
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
	panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.BG, UiTheme.CARD_BORDER, 2, 16, 24, 16))
	add_child(panel)

	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var header: HBoxContainer = HBoxContainer.new()
	column.add_child(header)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.add_theme_constant_override("separation", 0)
	header.add_child(titles)
	var heading: Label = Label.new()
	heading.text = "SKILL TREE"
	heading.theme_type_variation = &"Title"
	heading.add_theme_font_size_override("font_size", 26)
	titles.add_child(heading)
	_title_label = Label.new()
	_title_label.theme_type_variation = &"Caption"
	_title_label.add_theme_font_size_override("font_size", 14)
	titles.add_child(_title_label)
	var pill: PanelContainer = PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.DIAMOND.darkened(0.7), UiTheme.DIAMOND, 2, 18, 18, 6))
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(pill)
	_diamonds_label = Label.new()
	_diamonds_label.theme_type_variation = &"Value"
	_diamonds_label.add_theme_color_override("font_color", UiTheme.DIAMOND)
	pill.add_child(_diamonds_label)

	_tree_area = Control.new()
	_tree_area.name = "TreeArea"
	_tree_area.custom_minimum_size = Vector2(COLUMN_WIDTH * SkillTree.COLUMNS.size(), FIRST_ROW_Y + ROW_HEIGHT * 5.0 + 4.0)
	_tree_area.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tree_area.mouse_filter = Control.MOUSE_FILTER_PASS
	_tree_area.draw.connect(_draw_links)
	column.add_child(_tree_area)
	for i in SkillTree.COLUMNS.size():
		var chip: Label = Label.new()
		chip.text = SkillTree.COLUMNS[i].to_upper()
		chip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		chip.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		chip.add_theme_font_size_override("font_size", 11)
		chip.add_theme_color_override("font_color", BRANCH_COLORS[i].lightened(0.25))
		chip.add_theme_stylebox_override("normal", UiTheme.box(BRANCH_COLORS[i].darkened(0.78), BRANCH_COLORS[i].darkened(0.2), 1, 10, 8, 2))
		chip.size = Vector2(124, 22)
		chip.position = Vector2(COLUMN_WIDTH * i + (COLUMN_WIDTH - 124.0) / 2.0, HEADER_Y)
		_tree_area.add_child(chip)
	for id: String in SkillTree.SKILLS:
		var button: Button = Button.new()
		button.custom_minimum_size = NODE_SIZE
		button.size = NODE_SIZE
		button.position = _node_position(id)
		button.focus_mode = Control.FOCUS_NONE
		button.clip_text = true
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_on_skill_pressed.bind(id))
		button.mouse_entered.connect(_show_description.bind(id))
		_tree_area.add_child(button)
		_buttons[id] = button

	var info: PanelContainer = PanelContainer.new()
	info.theme_type_variation = &"Card"
	info.custom_minimum_size = Vector2(0, 92)
	column.add_child(info)
	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 2)
	info.add_child(info_box)
	var info_head: HBoxContainer = HBoxContainer.new()
	info_box.add_child(info_head)
	_info_name = Label.new()
	_info_name.theme_type_variation = &"Value"
	_info_name.add_theme_font_size_override("font_size", 17)
	info_head.add_child(_info_name)
	_info_status = Label.new()
	_info_status.theme_type_variation = &"Caption"
	_info_status.add_theme_font_size_override("font_size", 13)
	_info_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	info_head.add_child(_info_status)
	_info_desc = Label.new()
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.add_theme_color_override("font_color", UiTheme.TEXT.darkened(0.1))
	info_box.add_child(_info_desc)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	column.add_child(footer)
	var reset_button: Button = Button.new()
	reset_button.name = "ResetButton"
	reset_button.text = "Reset progress"
	reset_button.theme_type_variation = &"DangerButton"
	reset_button.custom_minimum_size = Vector2(200, 40)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.pressed.connect(reset_requested.emit)
	footer.add_child(reset_button)
	var hint: Label = Label.new()
	hint.text = "Unlocks are permanent and carry over to every run.   Esc closes."
	hint.theme_type_variation = &"Caption"
	hint.add_theme_font_size_override("font_size", 13)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	footer.add_child(hint)
	var close_button: Button = Button.new()
	close_button.name = "CloseButton"
	close_button.text = "Continue"
	close_button.theme_type_variation = &"AccentButton"
	close_button.custom_minimum_size = Vector2(200, 40)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(close)
	footer.add_child(close_button)


func _node_position(id: String) -> Vector2:
	var pos: Vector2i = SkillTree.SKILLS[id]["pos"]
	var y: float = 0.0 if pos.y == 0 else FIRST_ROW_Y + ROW_HEIGHT * (pos.y - 1)
	return Vector2(COLUMN_WIDTH * pos.x + (COLUMN_WIDTH - NODE_SIZE.x) / 2.0, y)


func _branch_color(id: String) -> Color:
	var pos: Vector2i = SkillTree.SKILLS[id]["pos"]
	return ROOT_COLOR if pos.y == 0 else BRANCH_COLORS[pos.x]


func open(subtitle: String, diamonds: int, skills: SkillTree) -> void:
	_title_label.text = subtitle
	refresh(diamonds, skills)
	_info_name.text = "Spend diamonds on permanent upgrades"
	_info_status.text = "1 diamond per cleared wave"
	_info_desc.text = "Hover a skill to see what it does. Gold border = affordable now. Deeper tiers cost more."
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
	_diamonds_label.text = "%d  diamonds" % diamonds
	for id: String in _buttons:
		var button: Button = _buttons[id]
		var skill: Dictionary = SkillTree.SKILLS[id]
		var branch: Color = _branch_color(id)
		var bg: Color = UiTheme.CARD
		var border: Color
		var text_color: Color
		var border_width: int = 1
		if skills.is_unlocked(id):
			button.text = "%s\nOWNED" % skill["name"]
			button.disabled = true
			bg = branch.darkened(0.62)
			border = branch
			text_color = branch.lightened(0.45)
			border_width = 2
		elif skills.can_unlock(id, diamonds):
			button.text = "%s\n%d diamonds" % [skill["name"], skill["cost"]]
			button.disabled = false
			border = UiTheme.GOLD
			text_color = UiTheme.TEXT
			border_width = 2
		elif skills.prerequisites_met(id):
			button.text = "%s\nneeds %d diamonds" % [skill["name"], skill["cost"]]
			button.disabled = true
			border = branch.darkened(0.35)
			text_color = UiTheme.MUTED.lightened(0.15)
		else:
			button.text = "%s\n%d diamonds" % [skill["name"], skill["cost"]]
			button.disabled = true
			bg = Color(0.1, 0.11, 0.14)
			border = Color(0.2, 0.22, 0.27)
			text_color = Color(0.4, 0.43, 0.5)
		for state: String in ["font_color", "font_disabled_color", "font_hover_color", "font_pressed_color"]:
			button.add_theme_color_override(state, text_color)
		button.add_theme_stylebox_override("normal", UiTheme.box(bg, border, border_width, 9, 8, 4))
		button.add_theme_stylebox_override("disabled", UiTheme.box(bg, border, border_width, 9, 8, 4))
		button.add_theme_stylebox_override("hover", UiTheme.box(bg.lightened(0.1), border.lightened(0.2), border_width + 1, 9, 8, 4))
		button.add_theme_stylebox_override("pressed", UiTheme.box(bg.darkened(0.1), border, border_width + 1, 9, 8, 4))
	_tree_area.queue_redraw()


func get_skill_button(id: String) -> Button:
	return _buttons[id]


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _on_skill_pressed(id: String) -> void:
	_show_description(id)
	unlock_requested.emit(id)


func _show_description(id: String) -> void:
	var skill: Dictionary = SkillTree.SKILLS[id]
	var status: String = "%d diamonds" % skill["cost"]
	if _skills != null:
		if _skills.is_unlocked(id):
			status = "Owned"
		elif not _skills.prerequisites_met(id):
			var needed: PackedStringArray = PackedStringArray()
			for required: String in skill["requires"]:
				needed.append(SkillTree.SKILLS[required]["name"])
			status = "%d diamonds  -  requires %s" % [skill["cost"], ", ".join(needed)]
		elif _diamonds < skill["cost"]:
			status = "%d diamonds  -  need %d more" % [skill["cost"], skill["cost"] - _diamonds]
		else:
			status = "%d diamonds  -  click to unlock" % skill["cost"]
	_info_name.text = skill["name"]
	_info_name.add_theme_color_override("font_color", _branch_color(id).lightened(0.3))
	_info_status.text = status
	_info_desc.text = skill["desc"]


## Elbow connectors (down, across, down) drawn behind the nodes and column chips.
func _draw_links() -> void:
	for id: String in SkillTree.SKILLS:
		for required: String in SkillTree.SKILLS[id]["requires"]:
			var from: Vector2 = _node_position(required) + Vector2(NODE_SIZE.x / 2.0, NODE_SIZE.y)
			var to: Vector2 = _node_position(id) + Vector2(NODE_SIZE.x / 2.0, 0.0)
			var lit: bool = _skills != null and _skills.is_unlocked(id)
			var color: Color = _branch_color(id) if lit else Color(0.27, 0.3, 0.37)
			var width: float = 3.0 if lit else 2.0
			# Branches leave the root along a bus just above the column chips.
			var mid_y: float = (from.y + HEADER_Y) / 2.0 if from.x != to.x else to.y
			_tree_area.draw_polyline(PackedVector2Array([from, Vector2(from.x, mid_y), Vector2(to.x, mid_y), to]), color, width, true)
