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
const NODE_SIZE: Vector2 = Vector2(188, 60)
const COLUMN_WIDTH: float = 204.0
const ROW_HEIGHT: float = 82.0
const HEADER_Y: float = 70.0       # column headers sit between the root and row 1
const FIRST_ROW_Y: float = 112.0
const CHIP_SIZE: Vector2 = Vector2(150, 30)
## Glyph (see Icons) shown on each skill's card.
const SKILL_ICONS: Dictionary = {
	"tesla": "bolt",
	"basic_upgrades": "chevrons", "basic_pierce": "arrow", "basic_veteran": "star", "basic_mastery": "crown",
	"tesla_upgrades": "chevrons", "tesla_static": "bolt", "tesla_capacitor": "battery", "tesla_mastery": "crown",
	"cannon": "cannon", "cannon_upgrades": "chevrons", "cannon_shrapnel": "burst", "cannon_mastery": "crown",
	"bounty_1": "coin", "war_chest": "chest", "bounty_2": "coin", "salvage": "gear", "head_start": "flag",
	"hollow_point": "crosshair", "armor_breaker": "arrow", "shield_breaker": "shield", "focus_fire": "crosshair", "annihilator": "burst",
	"weaken_1": "skull", "cripple": "drop", "weaken_2": "skull", "rust": "drop", "dampen": "wave",
	"fortify": "heart", "sharpen": "arrow", "overclock": "clock", "fortify_2": "shield", "diamond_mine": "diamond",
}
const COLUMN_ICONS: Array[String] = ["arrow", "bolt", "cannon", "coin", "crosshair", "skull", "heart"]
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

var _buttons: Dictionary = {}  # skill id -> SkillNode
var _tree_area: Control
var _progress_label: Label
var _progress_bar: ProgressBar
var _info_icon: Control
var _info_icon_kind: String = "diamond"
var _info_icon_color: Color = UiTheme.DIAMOND
var _time: float = 0.0
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
	var progress_box: VBoxContainer = VBoxContainer.new()
	progress_box.custom_minimum_size = Vector2(320, 0)
	progress_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	progress_box.add_theme_constant_override("separation", 4)
	header.add_child(progress_box)
	_progress_label = Label.new()
	_progress_label.theme_type_variation = &"Caption"
	_progress_label.add_theme_font_size_override("font_size", 13)
	_progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	progress_box.add_child(_progress_label)
	_progress_bar = ProgressBar.new()
	_progress_bar.show_percentage = false
	_progress_bar.custom_minimum_size = Vector2(320, 10)
	_progress_bar.add_theme_stylebox_override("background", UiTheme.box(Color(0.05, 0.06, 0.08), UiTheme.CARD_BORDER, 1, 5, 0, 0))
	_progress_bar.add_theme_stylebox_override("fill", UiTheme.box(UiTheme.DIAMOND.darkened(0.15), UiTheme.DIAMOND, 1, 5, 0, 0))
	progress_box.add_child(_progress_bar)
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(24, 0)
	header.add_child(spacer)
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
	for id: String in SkillTree.SKILLS:
		var node: SkillNode = SkillNode.new()
		node.custom_minimum_size = NODE_SIZE
		node.size = NODE_SIZE
		node.position = _node_position(id)
		node.setup(id, SkillTree.SKILLS[id], _branch_color(id), SKILL_ICONS.get(id, "star"))
		node.pressed.connect(_on_skill_pressed.bind(id))
		node.mouse_entered.connect(_show_description.bind(id))
		_tree_area.add_child(node)
		_buttons[id] = node

	var info: PanelContainer = PanelContainer.new()
	info.theme_type_variation = &"Card"
	info.custom_minimum_size = Vector2(0, 92)
	column.add_child(info)
	var info_row: HBoxContainer = HBoxContainer.new()
	info_row.add_theme_constant_override("separation", 14)
	info.add_child(info_row)
	_info_icon = Control.new()
	_info_icon.custom_minimum_size = Vector2(64, 64)
	_info_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_info_icon.draw.connect(_draw_info_icon)
	info_row.add_child(_info_icon)
	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 2)
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_row.add_child(info_box)
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
	_info_desc.text = "Hover a skill to see what it does. Glowing gold cards are affordable now; deeper tiers cost more."
	_info_icon_kind = "diamond"
	_info_icon_color = UiTheme.DIAMOND
	_info_icon.queue_redraw()
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
	var owned: int = 0
	for id: String in _buttons:
		var node: SkillNode = _buttons[id]
		if skills.is_unlocked(id):
			node.set_state(SkillNode.State.OWNED)
			owned += 1
		elif skills.can_unlock(id, diamonds):
			node.set_state(SkillNode.State.AVAILABLE)
		elif skills.prerequisites_met(id):
			node.set_state(SkillNode.State.WAITING)
		else:
			node.set_state(SkillNode.State.LOCKED)
	_progress_label.text = "%d / %d skills unlocked" % [owned, _buttons.size()]
	_progress_bar.max_value = _buttons.size()
	_progress_bar.value = owned
	_tree_area.queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_tree_area.queue_redraw()  # flowing light along owned links


func get_skill_button(id: String) -> SkillNode:
	return _buttons[id]


## "owned", "available", "waiting" (prerequisites met, not enough diamonds) or "locked".
func get_skill_state(id: String) -> String:
	return (_buttons[id] as SkillNode).state_name()


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
	_info_icon_kind = SKILL_ICONS.get(id, "star")
	_info_icon_color = _branch_color(id)
	_info_icon.queue_redraw()


func _draw_info_icon() -> void:
	var c: Vector2 = _info_icon.size / 2.0
	_info_icon.draw_circle(c, 30.0, _info_icon_color.darkened(0.65))
	_info_icon.draw_arc(c, 30.0, 0.0, TAU, 40, _info_icon_color, 2.0, true)
	Icons.draw(_info_icon, _info_icon_kind, c, 17.0, _info_icon_color.lightened(0.3))


## Column lanes, branch headers with progress, and elbow connectors (down, across, down)
## drawn behind the skill cards. Owned links glow and carry flowing light.
func _draw_links() -> void:
	var font: Font = get_theme_font("font", "Label")
	var height: float = _tree_area.size.y
	for i in SkillTree.COLUMNS.size():
		var color: Color = BRANCH_COLORS[i]
		var lane: Rect2 = Rect2(COLUMN_WIDTH * i + 4.0, HEADER_Y - 6.0, COLUMN_WIDTH - 8.0, height - HEADER_Y + 6.0)
		_tree_area.draw_style_box(UiTheme.box(Color(color, 0.045), Color(color, 0.12), 1, 14), lane)
	for id: String in SkillTree.SKILLS:
		for required: String in SkillTree.SKILLS[id]["requires"]:
			var from: Vector2 = _node_position(required) + Vector2(NODE_SIZE.x / 2.0, NODE_SIZE.y)
			var to: Vector2 = _node_position(id) + Vector2(NODE_SIZE.x / 2.0, 0.0)
			# Branches leave the root along a bus just above the column headers.
			var mid_y: float = (from.y + HEADER_Y) / 2.0 if from.x != to.x else to.y
			var points: PackedVector2Array = PackedVector2Array([from, Vector2(from.x, mid_y), Vector2(to.x, mid_y), to])
			var owned: bool = _skills != null and _skills.is_unlocked(id)
			var reachable: bool = _skills != null and _skills.is_unlocked(required)
			var branch: Color = _branch_color(id)
			if owned:
				_tree_area.draw_polyline(points, Color(branch, 0.22), 9.0, true)
				_tree_area.draw_polyline(points, branch, 3.0, true)
				_draw_flow(points, branch.lightened(0.6))
			elif reachable:
				_tree_area.draw_polyline(points, Color(branch, 0.55), 2.0, true)
			else:
				_tree_area.draw_polyline(points, Color(0.24, 0.27, 0.33), 2.0, true)
	for i in SkillTree.COLUMNS.size():
		_draw_column_header(i, font)


func _draw_column_header(i: int, font: Font) -> void:
	var color: Color = BRANCH_COLORS[i]
	var rect: Rect2 = Rect2(Vector2(COLUMN_WIDTH * i + (COLUMN_WIDTH - CHIP_SIZE.x) / 2.0, HEADER_Y), CHIP_SIZE)
	_tree_area.draw_style_box(UiTheme.box(color.darkened(0.78), color.darkened(0.15), 1, 15), rect)
	Icons.draw(_tree_area, COLUMN_ICONS[i], rect.position + Vector2(17, 15), 8.0, color.lightened(0.2))
	_tree_area.draw_string(font, rect.position + Vector2(30, 20), SkillTree.COLUMNS[i].to_upper(), HORIZONTAL_ALIGNMENT_LEFT, 82, 11, color.lightened(0.3))
	var owned: int = 0
	var total: int = 0
	for id: String in SkillTree.SKILLS:
		var pos: Vector2i = SkillTree.SKILLS[id]["pos"]
		if pos.y > 0 and pos.x == i:
			total += 1
			if _skills != null and _skills.is_unlocked(id):
				owned += 1
	_tree_area.draw_string(font, rect.position + Vector2(CHIP_SIZE.x - 34, 20), "%d/%d" % [owned, total], HORIZONTAL_ALIGNMENT_RIGHT, 26, 11, color.lightened(0.1) if owned < total else UiTheme.GOLD)
	# Thin progress line under the chip.
	var bar: Rect2 = Rect2(rect.position + Vector2(14, CHIP_SIZE.y - 4), Vector2(CHIP_SIZE.x - 28, 2))
	_tree_area.draw_rect(bar, Color(color, 0.2))
	if total > 0 and owned > 0:
		_tree_area.draw_rect(Rect2(bar.position, Vector2(bar.size.x * owned / total, bar.size.y)), color)


## Bright dots travelling along an owned link.
func _draw_flow(points: PackedVector2Array, color: Color) -> void:
	var length: float = 0.0
	for k in range(1, points.size()):
		length += points[k - 1].distance_to(points[k])
	if length <= 0.0:
		return
	var spacing: float = 34.0
	var offset: float = fmod(_time * 40.0, spacing)
	var d: float = offset
	while d < length:
		_tree_area.draw_circle(_point_along(points, d), 2.2, color)
		d += spacing


func _point_along(points: PackedVector2Array, distance: float) -> Vector2:
	var left: float = distance
	for k in range(1, points.size()):
		var seg: float = points[k - 1].distance_to(points[k])
		if left <= seg:
			return points[k - 1].lerp(points[k], left / maxf(seg, 0.001))
		left -= seg
	return points[points.size() - 1]
