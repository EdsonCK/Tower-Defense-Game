class_name UIStyle
extends RefCounted
## Shared vector-only palette. No imported art or platform font dependencies.

const INK := Color("101927")
const PANEL := Color("152235")
const LINE := Color("30445f")
const TEXT := Color("e6eef9")
const MUTED := Color("9aafc9")
const CYAN := Color("63d8df")
const PURPLE := Color("bc9aff")
const GOLD := Color("f6cc76")


static func box(fill: Color, edge: Color = LINE, radius: int = 10) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = edge
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


static func make_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 17
	result.set_color("font_color", "Label", TEXT)
	result.set_color("font_color", "Button", TEXT)
	result.set_color("font_hover_color", "Button", Color.WHITE)
	result.set_color("font_disabled_color", "Button", Color("788aa2"))
	result.set_stylebox("normal", "Button", box(Color("20334b")))
	result.set_stylebox("hover", "Button", box(Color("2c4963"), CYAN))
	result.set_stylebox("pressed", "Button", box(Color("174c59"), CYAN))
	result.set_stylebox("disabled", "Button", box(Color("172234"), Color("26354a")))
	var focus := box(Color(0, 0, 0, 0), CYAN)
	focus.set_border_width_all(2)
	result.set_stylebox("focus", "Button", focus)
	result.set_stylebox("panel", "PanelContainer", box(PANEL))
	result.set_stylebox("panel", "AcceptDialog", box(INK, CYAN, 14))
	result.set_stylebox("panel", "PopupMenu", box(INK))
	return result


static func accent(button: Button, color: Color) -> void:
	button.add_theme_stylebox_override("normal", box(Color("20334b"), color))
	button.add_theme_color_override("font_color", color)
