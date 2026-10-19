class_name GameHUD
extends Control
## Displays Main's state and emits intents; never changes gameplay state.

signal build_requested
signal cancel_requested
signal start_wave_requested
signal auto_start_changed(enabled: bool)
signal restart_requested
signal upgrade_requested(track: int)
signal tesla_requested
signal skills_requested
signal remove_requested

var _building := false
var _finished := false
var _currency := 0

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
	auto_start_button.toggled.connect(func(enabled: bool) -> void: auto_start_changed.emit(enabled))
	tesla_button.pressed.connect(func() -> void: tesla_requested.emit())
	skills_button.pressed.connect(func() -> void: skills_requested.emit())
	special_button.pressed.connect(func() -> void: upgrade_requested.emit(Tower.Upgrade.SPECIAL))
	build_button.text = "Build Tower • %d" % GameConfig.TOWER_COST
	remove_button.text = "Remove • Refund %d" % GameConfig.TOWER_REFUND
	$RightPanel/Margin/Items/TowerStats.text = "Build %d • Remove +%d\nNo upgrade refunds" % [GameConfig.TOWER_COST, GameConfig.TOWER_REFUND]
	damage_button.pressed.connect(func() -> void: upgrade_requested.emit(Tower.Upgrade.DAMAGE))
	range_button.pressed.connect(func() -> void: upgrade_requested.emit(Tower.Upgrade.RANGE))
	speed_button.pressed.connect(func() -> void: upgrade_requested.emit(Tower.Upgrade.SPEED))
	remove_button.pressed.connect(func() -> void: remove_requested.emit())
	build_button.pressed.connect(func() -> void: build_requested.emit())
	cancel_button.pressed.connect(func() -> void: cancel_requested.emit())
	start_button.pressed.connect(func() -> void: start_wave_requested.emit())
	$RightPanel/Margin/Items/Restart.pressed.connect(func() -> void: restart_requested.emit())


func display(currency: int, lives: int, wave: int, status: String, building: bool, can_start: bool, finished: bool) -> void:
	_finished = finished
	_currency = currency
	currency_label.text = "Gold: %d" % currency
	lives_label.text = "Base lives: %d" % lives
	wave_label.text = "Wave: %d • Endless" % wave
	status_label.text = status
	build_button.disabled = finished or currency < GameConfig.TOWER_COST
	_building = building
	cancel_button.disabled = finished or not building
	start_button.disabled = finished or not can_start
	selection_label.text = "BUILD MODE • Left-click to place • Stays selected until canceled or funds run out" if building else "Click a tower to manage it • Build Tower to add one • Right-click/Esc clears selection"


func show_message(message: String) -> void:
	message_label.text = message


func display_tower(tower: Tower, currency: int, finished: bool) -> void:
	cancel_button.disabled = finished or (not _building and tower == null)
	remove_button.disabled = finished or tower == null
	var buttons: Array[Button] = [damage_button, range_button, speed_button, special_button]
	var tracks: Array[int] = [Tower.Upgrade.DAMAGE, Tower.Upgrade.RANGE, Tower.Upgrade.SPEED, Tower.Upgrade.SPECIAL]
	var titles: Array[String] = ["Damage", "Range", "Firing speed", "Unique upgrade"]
	selected_label.text = "No tower selected"
	if tower != null:
		remove_button.text = "Remove • Refund %d" % tower.refund()
		titles[3] = "Static Field" if tower.kind == Tower.Kind.TESLA else "Piercing Rounds"
		var track_name: String = Tower.Upgrade.keys()[tower.upgrade_type].capitalize()
		selected_label.text = "%s / %s • %d/%d\nDMG %d • RNG %.0f • %.2fs" % ["Tesla" if tower.kind == Tower.Kind.TESLA else "Basic", track_name if tower.upgrade_level > 0 else "Unchosen", tower.upgrade_level, GameConfig.MAX_UPGRADE_LEVEL, tower.damage(), tower.attack_range(), tower.attack_interval()]
		$RightPanel/Margin/Items/TowerStats.text = "Build %d • Remove +%d\nTraining in Skills enables upgrades" % [tower.build_cost(), tower.refund()]
	for i in range(buttons.size()):
		var cost := tower.next_upgrade_cost() if tower != null else GameConfig.UPGRADE_COSTS[0]
		var locked := tower != null and (not tower.upgrades_enabled or (tracks[i] == Tower.Upgrade.SPECIAL and not tower.special_enabled) or (tower.upgrade_type != Tower.Upgrade.NONE and tower.upgrade_type != tracks[i]))
		var maxed := tower != null and tower.upgrade_level >= GameConfig.MAX_UPGRADE_LEVEL
		buttons[i].text = titles[i] + (" • Locked" if locked else (" • Max" if maxed else " • %d" % cost))
		buttons[i].disabled = finished or tower == null or locked or maxed or currency < cost


func display_progression(profile: Progression, can_open: bool, selected_kind: int) -> void:
	diamond_label.text = "Diamonds: %d%s" % [profile.diamonds, " *" if not profile.save_error.is_empty() else ""]
	diamond_label.tooltip_text = profile.save_error
	tesla_button.text = "Build Tesla • %d" % GameConfig.TESLA_COST if profile.has_skill("tesla") else "Tesla • Skill locked"
	tesla_button.disabled = _finished or not profile.has_skill("tesla") or _currency < GameConfig.TESLA_COST
	skills_button.disabled = not can_open
	if _building:
		selection_label.text = ("TESLA" if selected_kind == Tower.Kind.TESLA else "BASIC") + " BUILD MODE • Left-click a valid tile • Right-click/Esc cancels"
