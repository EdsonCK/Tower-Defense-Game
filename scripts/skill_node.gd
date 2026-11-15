class_name SkillNode
extends Button
## One skill in the skill tree, drawn procedurally: a card with the branch icon, the name,
## and the cost or OWNED badge. Affordable skills pulse with a gold glow, hovering lifts
## the card, and unlocking plays a burst.

enum State { OWNED, AVAILABLE, WAITING, LOCKED }

const STATE_NAMES: Dictionary = {
	State.OWNED: "owned", State.AVAILABLE: "available", State.WAITING: "waiting", State.LOCKED: "locked",
}

var skill_id: String = ""
var skill_name: String = ""
var glyph: String = "star"
var cost: int = 0
var branch_color: Color = Color.WHITE
var state: State = State.LOCKED

var _time: float = 0.0
var _hover: float = 0.0
var _burst: float = 0.0  # seconds left of the unlock burst


func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	flat = true
	for style: String in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func setup(id: String, skill: Dictionary, color: Color, icon_kind: String) -> void:
	skill_id = id
	skill_name = skill["name"]
	cost = skill["cost"]
	branch_color = color
	glyph = icon_kind
	tooltip_text = ""


func set_state(new_state: State) -> void:
	if new_state == State.OWNED and state != State.OWNED and is_inside_tree() and visible:
		_burst = 0.8
	state = new_state
	disabled = new_state != State.AVAILABLE
	text = ""  # everything is drawn in _draw
	queue_redraw()


func state_name() -> String:
	return STATE_NAMES[state]


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var target: float = 1.0 if is_hovered() else 0.0
	var old_hover: float = _hover
	_hover = move_toward(_hover, target, delta * 8.0)
	_burst = maxf(0.0, _burst - delta)
	if state == State.AVAILABLE or _burst > 0.0 or _hover != old_hover:
		queue_redraw()


func _draw() -> void:
	var lift: float = -2.0 * _hover
	var rect: Rect2 = Rect2(Vector2(0, lift), size)
	var font: Font = get_theme_font("font", "Label")
	var bg: Color
	var border: Color
	var name_color: Color
	var border_width: int = 2
	match state:
		State.OWNED:
			bg = branch_color.darkened(0.58)
			border = branch_color
			name_color = branch_color.lightened(0.55)
		State.AVAILABLE:
			bg = UiTheme.CARD.lightened(0.04)
			border = UiTheme.GOLD
			name_color = UiTheme.TEXT
		State.WAITING:
			bg = UiTheme.CARD
			border = branch_color.darkened(0.3)
			name_color = UiTheme.TEXT.darkened(0.15)
			border_width = 1
		_:
			bg = Color(0.09, 0.1, 0.13)
			border = Color(0.2, 0.22, 0.27)
			name_color = Color(0.42, 0.45, 0.52)
			border_width = 1
	var box: StyleBoxFlat = UiTheme.box(bg, border, border_width, 10)
	if state == State.AVAILABLE:
		var pulse: float = 0.5 + 0.5 * sin(_time * 4.0)
		box.shadow_color = Color(UiTheme.GOLD, 0.25 + 0.3 * pulse)
		box.shadow_size = int(4 + 6 * pulse)
	elif state == State.OWNED:
		box.shadow_color = Color(branch_color, 0.25)
		box.shadow_size = 4
	if _hover > 0.0 and state != State.LOCKED:
		box.border_color = box.border_color.lightened(0.25 * _hover)
		box.bg_color = box.bg_color.lightened(0.06 * _hover)
	draw_style_box(box, rect)
	# Owned cards get a soft top highlight.
	if state == State.OWNED:
		draw_rect(Rect2(rect.position + Vector2(8, 3), Vector2(rect.size.x - 16, 2)), Color(1, 1, 1, 0.12))

	# Icon medallion.
	var icon_center: Vector2 = rect.position + Vector2(28, rect.size.y / 2.0)
	var medal_bg: Color = branch_color.darkened(0.35) if state == State.OWNED else branch_color.darkened(0.72)
	if state == State.LOCKED:
		medal_bg = Color(0.13, 0.14, 0.18)
	draw_circle(icon_center, 19.0, medal_bg)
	draw_arc(icon_center, 19.0, 0.0, TAU, 32, border if state != State.AVAILABLE else branch_color, 1.5, true)
	var glyph_color: Color = Color(1, 1, 1, 0.95) if state == State.OWNED else branch_color.lightened(0.25)
	if state == State.LOCKED:
		glyph_color = Color(0.36, 0.39, 0.46)
	Icons.draw(self, glyph, icon_center, 11.0, glyph_color)

	# Name and cost line.
	var text_x: float = rect.position.x + 54.0
	var text_w: float = rect.size.x - 60.0
	draw_string(font, Vector2(text_x, rect.position.y + 25), skill_name, HORIZONTAL_ALIGNMENT_LEFT, text_w, 14, name_color)
	var line_y: float = rect.position.y + 45
	match state:
		State.OWNED:
			Icons.draw(self, "check", Vector2(text_x + 7, line_y - 4), 7.0, branch_color.lightened(0.4))
			draw_string(font, Vector2(text_x + 18, line_y), "OWNED", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, branch_color.lightened(0.4))
		State.LOCKED:
			Icons.draw(self, "lock", Vector2(text_x + 6, line_y - 4), 6.5, name_color)
			draw_string(font, Vector2(text_x + 18, line_y), "%d" % cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, name_color)
		_:
			var cost_color: Color = UiTheme.DIAMOND if state == State.AVAILABLE else UiTheme.MUTED
			Icons.draw(self, "diamond", Vector2(text_x + 6, line_y - 4), 6.5, cost_color)
			var label: String = "%d" % cost if state == State.AVAILABLE else "%d  (need more)" % cost
			draw_string(font, Vector2(text_x + 18, line_y), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, cost_color)

	# Unlock burst: an expanding ring and sparks.
	if _burst > 0.0:
		var t: float = 1.0 - _burst / 0.8
		var center: Vector2 = rect.get_center()
		var alpha: float = 1.0 - t
		draw_arc(center, 20.0 + 90.0 * t, 0.0, TAU, 48, Color(branch_color.lightened(0.4), alpha), 3.0 * alpha + 1.0, true)
		for i in 10:
			var dir: Vector2 = Vector2.RIGHT.rotated(TAU * i / 10.0)
			draw_circle(center + dir * (30.0 + 70.0 * t), 3.0 * alpha + 0.5, Color(UiTheme.GOLD, alpha))
