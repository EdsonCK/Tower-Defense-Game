class_name UiTheme
extends RefCounted
## Shared visual theme for every HUD element and menu, built in code so colors and
## styles live in one place. Type variations used by scenes and scripts:
##   PanelContainer: "Card"
##   Button: "AccentButton", "SuccessButton", "DangerButton", "ChosenButton"
##   Label: "Caption" (small muted caps), "Value" (large bold), "Title" (bold heading)

const BG: Color = Color(0.07, 0.08, 0.105)
const PANEL: Color = Color(0.095, 0.11, 0.145)
const CARD: Color = Color(0.135, 0.155, 0.2)
const CARD_BORDER: Color = Color(0.22, 0.26, 0.34)
const TEXT: Color = Color(0.9, 0.92, 0.96)
const MUTED: Color = Color(0.56, 0.6, 0.69)
const ACCENT: Color = Color(0.33, 0.6, 1.0)
const SUCCESS: Color = Color(0.3, 0.78, 0.48)
const DANGER: Color = Color(0.9, 0.34, 0.36)
const GOLD: Color = Color(1.0, 0.8, 0.3)
const DIAMOND: Color = Color(0.45, 0.85, 1.0)
const LIVES: Color = Color(1.0, 0.45, 0.5)
const LAYER_HEALTH: Color = Color(0.35, 0.92, 0.4)
const LAYER_ARMOR: Color = Color(0.93, 0.95, 1.0)
const LAYER_SHIELD: Color = Color(0.75, 0.45, 1.0)

static var _cached: Theme


static func get_theme() -> Theme:
	if _cached == null:
		_cached = build()
	return _cached


static func build() -> Theme:
	var theme: Theme = Theme.new()
	theme.default_font_size = 15
	var bold: FontVariation = FontVariation.new()
	bold.base_font = ThemeDB.fallback_font
	bold.variation_embolden = 0.7

	theme.set_stylebox("panel", "PanelContainer", box(PANEL, Color(0, 0, 0, 0), 0, 0))
	theme.set_stylebox("panel", "Panel", box(PANEL, Color(0, 0, 0, 0), 0, 0))
	theme.set_type_variation("Card", "PanelContainer")
	theme.set_stylebox("panel", "Card", box(CARD, CARD_BORDER, 1, 10, 12, 9))

	# Labels
	theme.set_color("font_color", "Label", TEXT)
	theme.set_type_variation("Caption", "Label")
	theme.set_color("font_color", "Caption", MUTED)
	theme.set_font_size("font_size", "Caption", 11)
	theme.set_type_variation("Value", "Label")
	theme.set_font("font", "Value", bold)
	theme.set_font_size("font_size", "Value", 20)
	theme.set_type_variation("Title", "Label")
	theme.set_font("font", "Title", bold)
	theme.set_font_size("font_size", "Title", 22)

	# Buttons
	_button_styles(theme, "Button", Color(0.19, 0.22, 0.29), Color(0.29, 0.33, 0.43))
	theme.set_font_size("font_size", "Button", 14)
	for variation: Array in [["AccentButton", ACCENT], ["SuccessButton", SUCCESS], ["DangerButton", DANGER], ["ChosenButton", GOLD]]:
		theme.set_type_variation(variation[0], "Button")
		var base: Color = variation[1]
		_button_styles(theme, variation[0], base.darkened(0.45), base)
	theme.set_font("font", "AccentButton", bold)
	theme.set_font("font", "SuccessButton", bold)

	# Check button
	theme.set_color("font_color", "CheckButton", TEXT)
	theme.set_color("font_hover_color", "CheckButton", Color.WHITE)
	theme.set_color("font_pressed_color", "CheckButton", SUCCESS.lightened(0.3))
	theme.set_stylebox("normal", "CheckButton", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 6, 4))
	theme.set_stylebox("hover", "CheckButton", box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 0, 6, 6, 4))
	theme.set_stylebox("pressed", "CheckButton", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 6, 6, 4))
	theme.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())

	# Separators and scroll bars
	var line: StyleBoxLine = StyleBoxLine.new()
	line.color = CARD_BORDER
	line.thickness = 1
	theme.set_stylebox("separator", "HSeparator", line)
	for bar: String in ["VScrollBar", "HScrollBar"]:
		theme.set_stylebox("scroll", bar, box(Color(0, 0, 0, 0.2), Color(0, 0, 0, 0), 0, 4))
		theme.set_stylebox("grabber", bar, box(Color(0.35, 0.4, 0.5, 0.8), Color(0, 0, 0, 0), 0, 4))
		theme.set_stylebox("grabber_highlight", bar, box(Color(0.45, 0.5, 0.62), Color(0, 0, 0, 0), 0, 4))
		theme.set_stylebox("grabber_pressed", bar, box(ACCENT, Color(0, 0, 0, 0), 0, 4))
	return theme


## Rounded flat box with an optional border.
static func box(bg: Color, border: Color, border_width: int, radius: int, margin_h: float = 10.0, margin_v: float = 6.0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = margin_h
	style.content_margin_right = margin_h
	style.content_margin_top = margin_v
	style.content_margin_bottom = margin_v
	style.anti_aliasing = true
	return style


static func _button_styles(theme: Theme, type_name: String, bg: Color, border: Color) -> void:
	theme.set_stylebox("normal", type_name, box(bg, border.darkened(0.15), 1, 7))
	theme.set_stylebox("hover", type_name, box(bg.lightened(0.12), border.lightened(0.2), 1, 7))
	theme.set_stylebox("pressed", type_name, box(bg.darkened(0.15), border.lightened(0.35), 2, 7))
	theme.set_stylebox("disabled", type_name, box(Color(0.12, 0.13, 0.17), Color(0.19, 0.21, 0.26), 1, 7))
	theme.set_stylebox("focus", type_name, StyleBoxEmpty.new())
	theme.set_color("font_color", type_name, TEXT)
	theme.set_color("font_hover_color", type_name, Color.WHITE)
	theme.set_color("font_pressed_color", type_name, Color.WHITE)
	theme.set_color("font_disabled_color", type_name, Color(0.42, 0.45, 0.52))
