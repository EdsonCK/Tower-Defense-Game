class_name GameHUD
extends Control
## Displays Main's state and emits intents; never changes gameplay state.

signal build_requested
signal cancel_requested
signal start_wave_requested
signal auto_start_changed(enabled: bool)
signal restart_prompt_changed(open: bool)
signal restart_requested
signal upgrade_requested(track: int)
signal tesla_requested
signal skills_requested
signal remove_requested

var _building := false
var _finished := false
var _currency := 0
var restart_dialog: ConfirmationDialog
var _restart_shade: ColorRect

@onready var diamond_label: Label = $RightPanel/Margin/Items/Diamonds
@onready var tesla_button: Button = $RightPanel/Margin/Items/BuildTesla
@onready var skills_button: Button = $RightPanel/Margin/Items/Skills
@onready var special_button: Button = $RightPanel/Margin/Items/UpgradeSpecial
@onready var selected_label: Label = $RightPanel/Margin/Items/SelectedTower
@onready var damage_button: Button = $RightPanel/Margin/Items/UpgradeDamage
@onready var range_button: Button = $RightPanel/Margin/Items/UpgradeRange
@onready var speed_button: Button = $RightPanel/Margin/Items/UpgradeSpeed
@onready var remove_button: Button = $RightPanel/Margin/Items/RemoveTower
@onready var currency_label: Label = $RightPanel/Margin/Items/Currency
@onready var lives_label: Label = $RightPanel/Margin/Items/Lives
@onready var wave_label: Label = $RightPanel/Margin/Items/Wave
@onready var status_label: Label = $RightPanel/Margin/Items/Status
@onready var build_button: Button = $RightPanel/Margin/Items/BuildTower
@onready var cancel_button: Button = $RightPanel/Margin/Items/Cancel
@onready var start_button: Button = $RightPanel/Margin/Items/StartWave
@onready var auto_start_button: CheckButton = $RightPanel/Margin/Items/AutoStart
@onready var selection_label: Label = $BottomPanel/Margin/Items/Selection
@onready var message_label: Label = $BottomPanel/Margin/Items/Message


func _ready() -> void:
	theme = UIStyle.make_theme()
	UIStyle.accent(start_button, UIStyle.CYAN)
	UIStyle.accent(skills_button, UIStyle.PURPLE)
	UIStyle.accent(remove_button, Color("ec9b9b"))
	_restart_shade = ColorRect.new()
	_restart_shade.color = Color(0.015, 0.025, 0.05, 0.78)
	_restart_shade.size = Vector2(1600, 900)
	_restart_shade.hide()
	add_child(_restart_shade)
	restart_dialog = ConfirmationDialog.new()
	restart_dialog.name = "RestartConfirmation"
	restart_dialog.title = "Are you sure?"
	restart_dialog.dialog_text = "Restart this run? Towers, gold and wave progress will reset.\nYour diamonds and permanent research will be kept."
	restart_dialog.ok_button_text = "Restart run"
	restart_dialog.cancel_button_text = "Keep playing"
	restart_dialog.exclusive = true
	restart_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	add_child(restart_dialog)
	restart_dialog.confirmed.connect(func() -> void:
		_restart_shade.hide()
		restart_requested.emit()
		restart_prompt_changed.emit(false)
	)
	restart_dialog.canceled.connect(func() -> void:
		_restart_shade.hide()
		restart_prompt_changed.emit(false)
	)
	auto_start_button.toggled.connect(func(enabled: bool) -> void: auto_start_changed.emit(enabled))
	tesla_button.pressed.connect(func() -> void: tesla_requested.emit())
	skills_button.pressed.connect(func() -> void: skills_requested.emit())
	special_button.pressed.connect(func() -> void: upgrade_requested.emit(Tower.Upgrade.SPECIAL))
	build_button.text = "Build Tower • %d" % GameConfig.TOWER_COST
	remove_button.text = "Sell tower • +%d gold" % GameConfig.TOWER_REFUND
	damage_button.pressed.connect(func() -> void: upgrade_requested.emit(Tower.Upgrade.DAMAGE))
	range_button.pressed.connect(func() -> void: upgrade_requested.emit(Tower.Upgrade.RANGE))
	speed_button.pressed.connect(func() -> void: upgrade_requested.emit(Tower.Upgrade.SPEED))
	remove_button.pressed.connect(func() -> void: remove_requested.emit())
	build_button.pressed.connect(func() -> void: build_requested.emit())
	cancel_button.pressed.connect(func() -> void: cancel_requested.emit())
	start_button.pressed.connect(func() -> void: start_wave_requested.emit())
	$RightPanel/Margin/Items/Restart.pressed.connect(func() -> void:
		_restart_shade.show()
		restart_prompt_changed.emit(true)
		restart_dialog.popup_centered(Vector2i(600, 200))
		restart_dialog.get_cancel_button().grab_focus()
	)


func display(currency: int, lives: int, wave: int, status: String, building: bool, can_start: bool, finished: bool) -> void:
	_finished = finished
	_currency = currency
	currency_label.text = "Gold: " + _counter(currency)
	currency_label.tooltip_text = "%d gold" % currency
	lives_label.text = "Lives: %d" % lives
	wave_label.text = "Wave: " + _counter(wave)
	wave_label.tooltip_text = "Wave %d" % wave
	status_label.text = status
	build_button.disabled = finished or currency < GameConfig.TOWER_COST
	_building = building
	cancel_button.disabled = finished or not building
	start_button.disabled = finished or not can_start
	selection_label.text = "BUILD MODE • Left-click to place • Stays selected until canceled or funds run out" if building else "Click a tower to manage it • Build Tower to add one • Right-click/Esc clears selection"


func show_message(message: String) -> void:
	message_label.text = message
	message_label.tooltip_text = message


func display_tower(tower: Tower, currency: int, finished: bool) -> void:
	cancel_button.disabled = finished or (not _building and tower == null)
	remove_button.disabled = finished or tower == null
	var buttons: Array[Button] = [damage_button, range_button, speed_button, special_button]
	var tracks: Array[int] = [Tower.Upgrade.DAMAGE, Tower.Upgrade.RANGE, Tower.Upgrade.SPEED, Tower.Upgrade.SPECIAL]
	var titles: Array[String] = ["Damage", "Range", "Firing speed", "Unique upgrade"]
	selected_label.text = "Select a tower on the grid\nDamage: HP / Armor / Shield"
	selected_label.tooltip_text = ""
	if tower != null:
		remove_button.text = "Sell tower • +%d gold" % tower.refund()
		titles[3] = "Static Field" if tower.kind == Tower.Kind.TESLA else "Piercing Rounds"
		var track_name: String = Tower.Upgrade.keys()[tower.upgrade_type].capitalize()
		selected_label.text = "%s • %s %d/%d\nHP %d   ARM %d   SHD %d\nRange %.0f px   /   Fire %.2f s" % ["Tesla" if tower.kind == Tower.Kind.TESLA else "Basic", track_name if tower.upgrade_level > 0 else "No track", tower.upgrade_level, GameConfig.MAX_UPGRADE_LEVEL, tower.damage(), tower.armor_damage(), tower.shield_damage(), tower.attack_range(), tower.attack_interval()]
		selected_label.tooltip_text = "Damage per hit: health / armor / shield. Each hit affects only the top layer.\n" + selected_label.text
	for i in range(buttons.size()):
		var cost := tower.next_upgrade_cost() if tower != null else GameConfig.UPGRADE_COSTS[0]
		var locked := tower != null and (not tower.upgrades_enabled or (tracks[i] == Tower.Upgrade.SPECIAL and not tower.special_enabled) or (tower.upgrade_type != Tower.Upgrade.NONE and tower.upgrade_type != tracks[i]))
		var maxed := tower != null and tower.upgrade_level >= GameConfig.MAX_UPGRADE_LEVEL
		buttons[i].text = titles[i] + (" • Locked" if locked else (" • Max" if maxed else " • %d" % cost))
		buttons[i].disabled = finished or tower == null or locked or maxed or currency < cost
		buttons[i].tooltip_text = "Select a tower on the grid" if tower == null else tower.upgrade_error(tracks[i])
		if buttons[i].tooltip_text.is_empty():
			buttons[i].tooltip_text = "Upgrade this tower for %d gold. Choosing a track locks the others." % cost


func display_progression(profile: Progression, can_open: bool, selected_kind: int) -> void:
	diamond_label.text = "Diamonds: %s%s" % [_counter(profile.diamonds), " *" if not profile.save_error.is_empty() else ""]
	diamond_label.tooltip_text = "%d diamonds" % profile.diamonds + ("\n" + profile.save_error if not profile.save_error.is_empty() else "")
	tesla_button.text = "Build Tesla • %d" % GameConfig.TESLA_COST if profile.has_skill("tesla") else "Tesla • Skill locked"
	tesla_button.disabled = _finished or not profile.has_skill("tesla") or _currency < GameConfig.TESLA_COST
	skills_button.disabled = not can_open
	if _building:
		selection_label.text = ("TESLA" if selected_kind == Tower.Kind.TESLA else "BASIC") + " BUILD MODE • Left-click a valid tile • Right-click/Esc cancels"


func _counter(value: int) -> String:
	if value >= 1000000:
		return "%.1fM" % (value / 1000000.0)
	if value >= 10000:
		return "%.1fk" % (value / 1000.0)
	return str(value)
