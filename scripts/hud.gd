class_name Hud
extends Control
## Displays game state, forwards button presses as intent signals and shows messages.
## Holds no currency, lives, skill or pathfinding logic.
##
## Layout contract (keeps UI off the playable board, whatever is added later):
## - The board lives inside BoardArea, a fixed-size slot in the same HBox/VBox
##   container layout as the panels, so panels can never overlap it.
## - Panel content sits in ScrollContainers: too much (or too wide) content scrolls,
##   so panels never grow or push the board.
## - Every HUD element has a fixed size: labels are single-line (ellipsis) or have a fixed
##   line count, nothing is shown/hidden during play, and the selection card is always
##   present. So buttons and text never move between waves (tests/test_layout.gd checks).
## - Only nodes in PASSTHROUGH_GROUP (pure layout containers that draw nothing and
##   ignore the mouse) may span the board. The one exception is MODAL_GROUP: full-screen
##   menus (skill tree, confirmations) that pause the game while open.
## - Scripts reference nodes by unique name (%Name), so layout can be rearranged freely.

signal build_pressed(type_id: String)
signal cancel_pressed
signal start_wave_pressed
signal restart_pressed
signal upgrade_pressed(path: int)
signal sell_pressed
signal skills_pressed
signal skill_unlock_requested(skill_id: String)
signal skill_menu_closed
signal progress_reset_requested
signal auto_start_toggled(enabled: bool)
signal confirm_answered(confirmed: bool)

const PASSTHROUGH_GROUP: StringName = &"hud_passthrough"
const MODAL_GROUP: StringName = &"hud_modal"
const PASSTHROUGH_CLASSES: Array[String] = ["Control", "HBoxContainer", "VBoxContainer"]
const STATE_COLORS: Dictionary = {
	"READY": UiTheme.GOLD,
	"WAVE ACTIVE": UiTheme.SUCCESS,
	"BETWEEN WAVES": UiTheme.ACCENT,
	"DEFEAT": UiTheme.DANGER,
}

@onready var _board_area: Control = %BoardArea
@onready var _right_panel: Control = %RightPanel
@onready var _bottom_panel: Control = %BottomPanel
@onready var _currency_label: Label = %CurrencyLabel
@onready var _diamonds_label: Label = %DiamondsLabel
@onready var _lives_label: Label = %LivesLabel
@onready var _wave_label: Label = %WaveLabel
@onready var _enemies_label: Label = %EnemiesLabel
@onready var _state_label: Label = %StateLabel
@onready var _next_wave_label: Label = %NextWaveLabel
@onready var _build_button: Button = %BuildButton
@onready var _build_tesla_button: Button = %BuildTeslaButton
@onready var _build_cannon_button: Button = %BuildCannonButton
@onready var _cancel_button: Button = %CancelButton
@onready var _start_wave_button: Button = %StartWaveButton
@onready var _skills_button: Button = %SkillsButton
@onready var _restart_button: Button = %RestartButton
@onready var _auto_start_check: CheckButton = %AutoStartCheck
@onready var _selection_box: Control = %SelectionBox
@onready var _selection_label: Label = %SelectionLabel
@onready var _selection_level_label: Label = %SelectionLevelLabel
@onready var _selection_stats_label: Label = %SelectionStatsLabel
@onready var _selection_note_label: Label = %SelectionNoteLabel
@onready var _damage_labels: Dictionary = {
	"health": %DamageHealthLabel, "armor": %DamageArmorLabel, "shield": %DamageShieldLabel,
}
@onready var _upgrade_damage_button: Button = %UpgradeDamageButton
@onready var _upgrade_range_button: Button = %UpgradeRangeButton
@onready var _upgrade_speed_button: Button = %UpgradeSpeedButton
@onready var _upgrade_unique_button: Button = %UpgradeUniqueButton
@onready var _sell_button: Button = %SellButton
@onready var _mode_label: Label = %ModeLabel
@onready var _message_label: Label = %MessageLabel
@onready var _seed_label: Label = %SeedLabel
@onready var _skill_menu: SkillTreeMenu = %SkillTreeMenu
@onready var _confirm_dialog: ConfirmDialog = %ConfirmDialog

## Tower type id -> its build button.
var _build_buttons: Dictionary = {}
## Upgrade path -> the button showing it (the unique button is re-pointed per tower).
var _upgrade_buttons: Dictionary = {}
var _unique_path: int = Tower.UpgradePath.NONE
var _has_selection: bool = false


func _ready() -> void:
	theme = UiTheme.get_theme()
	# The transparent full-screen layout must not swallow board clicks; panels stop them.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board_area.custom_minimum_size = Vector2(GameConfig.BOARD_WIDTH, GameConfig.BOARD_HEIGHT)
	_right_panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, UiTheme.CARD_BORDER, 0, 0))
	_bottom_panel.add_theme_stylebox_override("panel", UiTheme.box(UiTheme.PANEL, UiTheme.CARD_BORDER, 0, 0))
	_build_buttons = {TowerTypes.BASIC: _build_button, TowerTypes.TESLA: _build_tesla_button, TowerTypes.CANNON: _build_cannon_button}
	for type_id: String in _build_buttons:
		(_build_buttons[type_id] as Button).pressed.connect(build_pressed.emit.bind(type_id))
	_cancel_button.pressed.connect(cancel_pressed.emit)
	_start_wave_button.pressed.connect(start_wave_pressed.emit)
	_skills_button.pressed.connect(skills_pressed.emit)
	_restart_button.pressed.connect(restart_pressed.emit)
	_auto_start_check.toggled.connect(auto_start_toggled.emit)
	_upgrade_damage_button.pressed.connect(upgrade_pressed.emit.bind(Tower.UpgradePath.DAMAGE))
	_upgrade_range_button.pressed.connect(upgrade_pressed.emit.bind(Tower.UpgradePath.RANGE))
	_upgrade_speed_button.pressed.connect(upgrade_pressed.emit.bind(Tower.UpgradePath.SPEED))
	_upgrade_unique_button.pressed.connect(func() -> void: upgrade_pressed.emit(_unique_path))
	_sell_button.pressed.connect(sell_pressed.emit)
	for button: Button in [_upgrade_damage_button, _upgrade_range_button, _upgrade_speed_button, _upgrade_unique_button]:
		button.add_theme_font_size_override("font_size", 12)
	_skill_menu.unlock_requested.connect(skill_unlock_requested.emit)
	_skill_menu.closed.connect(skill_menu_closed.emit)
	_skill_menu.reset_requested.connect(progress_reset_requested.emit)
	_confirm_dialog.answered.connect(confirm_answered.emit)
	hide_selection()
	if OS.is_debug_build():
		for panel: Control in [_right_panel, _bottom_panel, _board_area]:
			panel.item_rect_changed.connect(_verify_layout, CONNECT_DEFERRED)


func update_status(currency: int, lives: int, wave: int, state_text: String, run_seed: int) -> void:
	_currency_label.text = _compact(currency)
	_lives_label.text = str(lives)
	_wave_label.text = str(wave)
	_state_label.text = state_text
	_state_label.add_theme_color_override("font_color", STATE_COLORS.get(state_text, UiTheme.TEXT))
	_seed_label.text = "Seed %d" % run_seed


func update_diamonds(diamonds: int) -> void:
	_diamonds_label.text = _compact(diamonds)
	_skills_button.text = "Skill Tree   (%s diamonds)" % _compact(diamonds)


func update_enemy_counts(to_spawn: int, active: int) -> void:
	_enemies_label.text = "%d active  |  %d to spawn" % [active, to_spawn]


func update_next_wave(wave: int, counts: Dictionary) -> void:
	var parts: PackedStringArray = PackedStringArray()
	for type_id: String in EnemyTypes.DEFS:
		if counts.has(type_id):
			parts.append("%d %s" % [counts[type_id], EnemyTypes.display_name(type_id)])
	_next_wave_label.text = "Next wave %d: %s" % [wave, ", ".join(parts)]


func set_buttons(can_build: bool, can_start_wave: bool, build_mode: bool, build_type: String, unlocked_types: Array[String]) -> void:
	for type_id: String in _build_buttons:
		var button: Button = _build_buttons[type_id]
		var def: Dictionary = TowerTypes.get_def(type_id)
		var unlocked: bool = type_id in unlocked_types
		var active: bool = build_mode and build_type == type_id
		button.disabled = not can_build or not unlocked
		button.theme_type_variation = &"ChosenButton" if active else &""
		button.text = "%s   %d" % [def["name"], def["cost"]] if unlocked else "%s  (Skill Tree)" % def["name"]
	_cancel_button.disabled = not build_mode
	_start_wave_button.disabled = not can_start_wave
	_skills_button.disabled = not can_build


## Shows the auto-start toggle state and, if a wave is scheduled, its countdown.
func set_auto_start(enabled: bool, countdown: float) -> void:
	_auto_start_check.set_pressed_no_signal(enabled)
	_auto_start_check.text = "Auto-start next wave in %ds" % ceili(countdown) if countdown > 0.0 else "Auto-start waves"


func set_build_mode(active: bool, type_name: String = "") -> void:
	if active:
		_mode_label.text = "BUILD MODE - %s: left-click a tile to place. Stays on until canceled or out of gold. Right-click / Esc cancels." % type_name
	else:
		_mode_label.text = "Build towers to make a maze. Click a tower to inspect, upgrade or sell it."


## `info` is built by Main from the selected tower; see Main._refresh_selection().
func show_selection(info: Dictionary) -> void:
	_has_selection = true
	_selection_label.text = info["title"]
	_selection_level_label.text = info["level"]
	var damage: Dictionary = info["damage"]
	_damage_labels["health"].text = "Health %d" % damage["health"]
	_damage_labels["armor"].text = "Armor %d" % damage["armor"]
	_damage_labels["shield"].text = "Shield %d" % damage["shield"]
	_selection_stats_label.text = info["stats"]
	_selection_note_label.text = info["note"]
	_unique_path = info["unique_path"]
	_upgrade_buttons = {
		Tower.UpgradePath.DAMAGE: _upgrade_damage_button,
		Tower.UpgradePath.RANGE: _upgrade_range_button,
		Tower.UpgradePath.SPEED: _upgrade_speed_button,
		_unique_path: _upgrade_unique_button,
	}
	for path: int in _upgrade_buttons:
		var button: Button = _upgrade_buttons[path]
		var state: Dictionary = info["buttons"].get(path, {"text": "-", "enabled": false, "chosen": false})
		button.text = state["text"]
		button.disabled = not state["enabled"]
		button.theme_type_variation = &"ChosenButton" if state["chosen"] else &""
	_sell_button.text = "Sell  +%d" % info["sell_value"]
	_sell_button.disabled = not info["can_sell"]


## Shows the empty selection card (same size as a filled one).
func hide_selection() -> void:
	_has_selection = false
	_selection_label.text = "No tower selected"
	_selection_level_label.text = ""
	for layer: String in _damage_labels:
		_damage_labels[layer].text = "%s -" % layer.capitalize()
	_selection_stats_label.text = "Click a tower to inspect, upgrade or sell it."
	_selection_note_label.text = ""
	for button: Button in [_upgrade_damage_button, _upgrade_range_button, _upgrade_speed_button, _upgrade_unique_button]:
		button.disabled = true
		button.theme_type_variation = &""
	_upgrade_damage_button.text = "Damage"
	_upgrade_range_button.text = "Range"
	_upgrade_speed_button.text = "Hit speed"
	_upgrade_unique_button.text = "Special"
	_sell_button.text = "Sell"
	_sell_button.disabled = true


## True while a tower is selected (the card itself is always on screen).
func is_selection_visible() -> bool:
	return _has_selection


## Button currently showing `path` in the selection panel (for tests and tooling).
func get_upgrade_button(path: int) -> Button:
	return _upgrade_buttons.get(path)


func get_selection_note() -> String:
	return _selection_note_label.text


func show_skill_menu(subtitle: String, diamonds: int, skills: SkillTree) -> void:
	_skill_menu.open(subtitle, diamonds, skills)


func refresh_skill_menu(diamonds: int, skills: SkillTree) -> void:
	if _skill_menu.is_open():
		_skill_menu.refresh(diamonds, skills)


func hide_skill_menu() -> void:
	_skill_menu.visible = false


func is_skill_menu_open() -> bool:
	return _skill_menu.is_open()


func get_skill_menu() -> SkillTreeMenu:
	return _skill_menu


func show_confirm(title: String, body: String, confirm_text: String) -> void:
	_confirm_dialog.ask(title, body, confirm_text)


func hide_confirm() -> void:
	_confirm_dialog.visible = false


func is_confirm_open() -> bool:
	return _confirm_dialog.is_open()


func get_confirm_dialog() -> ConfirmDialog:
	return _confirm_dialog


func show_message(text: String) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", UiTheme.TEXT)


func show_error(text: String) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", UiTheme.DANGER.lightened(0.15))


func get_message() -> String:
	return _message_label.text


## Screen rect reserved for the board (the Board node is a child of this area).
func get_board_rect() -> Rect2:
	return _board_area.get_global_rect()


## 1234 -> "1,234"; 1234567 -> "1.23M" so big numbers never overflow their tile.
static func _compact(value: int) -> String:
	if absi(value) >= 1000000:
		return "%.2fM" % (value / 1000000.0)
	var digits: String = str(absi(value))
	var grouped: String = ""
	while digits.length() > 3:
		grouped = "," + digits.substr(digits.length() - 3) + grouped
		digits = digits.substr(0, digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped


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
