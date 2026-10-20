class_name TDGame
extends Node2D
## Authoritative economy, game phase, purchase transaction, and system wiring.

enum Phase { READY, WAVE_ACTIVE, BETWEEN_WAVES, DEFEAT }

@export var tower_scene: PackedScene = preload("res://scenes/tower.tscn")
const ENEMY_SCENE := preload("res://scenes/enemy.tscn")

var currency := GameConfig.STARTING_CURRENCY
var lives := GameConfig.STARTING_LIVES
var phase := Phase.READY
var building := false
var selected_tower: Tower
var build_kind := Tower.Kind.BASIC
var progression: Progression
var auto_start_waves := false
var _run_id := ""
var _enemy_serial := 0
var _hud_refresh_queued := false
var _restart_pending := false
var _restart_confirming := false
var _prior_board_mode: ProcessMode
var _prior_wave_mode: ProcessMode
@export var profile_path := "user://progression.json"

@onready var board: Board = $Board
@onready var hud: GameHUD = $HUD/UILayout
@onready var waves: WaveManager = $WaveManager
@onready var skill_tree: SkillTreeMenu = $HUD/UILayout/SkillTree


func _ready() -> void:
	if get_tree().has_meta("td_restart_progression"):
		progression = get_tree().get_meta("td_restart_progression") as Progression
		get_tree().remove_meta("td_restart_progression")
	if progression == null:
		progression = Progression.new(profile_path)
		progression.load_profile()
	_run_id = Crypto.new().generate_random_bytes(16).hex_encode()
	hud.tesla_requested.connect(func() -> void: select_tower(Tower.Kind.TESLA))
	hud.tower_type_requested.connect(select_tower)
	hud.skills_requested.connect(open_skill_tree)
	skill_tree.purchase_requested.connect(purchase_skill)
	skill_tree.close_requested.connect(close_skill_tree)
	skill_tree.retry_requested.connect(_retry_save)
	hud.build_requested.connect(select_tower)
	hud.cancel_requested.connect(cancel_build)
	hud.restart_requested.connect(restart)
	hud.restart_prompt_changed.connect(_on_restart_prompt_changed)
	hud.start_wave_requested.connect(start_wave)
	hud.auto_start_changed.connect(set_auto_start_waves)
	hud.upgrade_requested.connect(upgrade_selected_tower)
	hud.remove_requested.connect(remove_selected_tower)
	waves.spawn_requested.connect(_spawn_enemy)
	waves.wave_completed.connect(_on_wave_completed)
	_refresh_hud()
	hud.show_message(progression.save_error if not progression.save_error.is_empty() else "Create a maze. Earn 1 diamond per cleared wave; open Skills for permanent unlocks.")


func is_finished() -> bool:
	return phase == Phase.DEFEAT


func select_tower(kind: int = Tower.Kind.BASIC) -> void:
	if is_finished() or _restart_confirming or skill_tree.visible:
		return
	if not TowerCatalog.valid(kind):
		return
	if not TowerCatalog.unlocked(progression, kind):
		hud.show_message("Unlock %s in the skill tree first" % TowerCatalog.DATA[kind].title)
		return
	var cost := int(TowerCatalog.DATA[kind].cost)
	if currency < cost:
		hud.show_message("Insufficient gold")
		return
	selected_tower = null
	build_kind = kind as Tower.Kind
	building = true
	_refresh_hud()
	hud.show_message("Left-click a green tile to build. Right-click or Escape cancels.")


func cancel_build() -> void:
	if _restart_confirming:
		return
	selected_tower = null
	building = false
	_refresh_hud()


func _input(event: InputEvent) -> void:
	# The modal consumes every board/gameplay intent, including Escape.
	if _restart_confirming:
		return
	if skill_tree.visible:
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close_skill_tree()
			get_viewport().set_input_as_handled()
		return
	if is_finished():
		return
	if (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		cancel_build()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if is_finished() or _restart_confirming or skill_tree.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var pixel: Vector2 = board.get_global_transform_with_canvas().affine_inverse() * event.position
		if board.contains_pixel(pixel):
			var cell := board.pixel_to_cell(pixel)
			var tower := tower_at_cell(cell)
			if tower != null:
				select_placed_tower(tower)
			elif building:
				purchase_tower(cell)
			else:
				cancel_build()
			get_viewport().set_input_as_handled()


func purchase_tower(cell: Vector2i) -> bool:
	if is_finished() or _restart_confirming or skill_tree.visible:
		return false
	if not TowerCatalog.unlocked(progression, build_kind):
		return false
	var cost := int(TowerCatalog.DATA[build_kind].cost)
	var error := board.try_block_cell(cell, currency, cost)
	if not error.is_empty():
		hud.show_message(error)
		return false
	# Occupancy and money form a transaction. Instantiation failure rolls it back.
	var instance: Node = tower_scene.instantiate() if tower_scene != null and tower_scene.can_instantiate() else null
	if not instance is Tower:
		if instance != null:
			instance.free()
		board.rollback_placement(cell)
		hud.show_message("Tower could not be created; purchase canceled")
		return false
	var tower := instance as Tower
	tower.kind = build_kind
	tower.configure_progression(progression)
	tower.cell = cell
	tower.position = board.cell_to_pixel(cell)
	board.get_node("Towers").add_child(tower)
	currency -= cost
	board.confirm_placement()
	if currency < cost:
		building = false
	_refresh_hud()
	hud.show_message("Tower built • -%d gold" % cost)
	return true


func tower_at_cell(cell: Vector2i) -> Tower:
	for child in board.get_node("Towers").get_children():
		var tower := child as Tower
		if tower != null and not tower.is_queued_for_deletion() and tower.cell == cell:
			return tower
	return null


func select_placed_tower(tower: Tower) -> void:
	if is_finished() or _restart_confirming or skill_tree.visible or not _owns_tower(tower):
		return
	building = false
	selected_tower = tower
	_refresh_hud()
	hud.show_message("Training in the skill tree unlocks upgrades. Remove refunds %d gold; upgrades are not refunded." % tower.refund())


func _owns_tower(tower: Tower) -> bool:
	return is_instance_valid(tower) and not tower.is_queued_for_deletion() and tower.get_parent() == board.get_node("Towers")


func upgrade_selected_tower(track: int) -> bool:
	if is_finished() or _restart_confirming or skill_tree.visible or not _owns_tower(selected_tower):
		return false
	var error := selected_tower.upgrade_error(track)
	if not error.is_empty():
		hud.show_message(error)
		return false
	var cost := selected_tower.next_upgrade_cost()
	if currency < cost:
		hud.show_message("Insufficient gold")
		return false
	if not selected_tower.apply_upgrade(track):
		return false
	currency -= cost
	_refresh_hud()
	hud.show_message("%s upgraded • -%d gold • %d/%d upgrade slots used" % [TowerCatalog.DATA[selected_tower.kind].title, cost, selected_tower.upgrade_level, selected_tower.max_upgrades()])
	return true


func remove_selected_tower() -> bool:
	if is_finished() or _restart_confirming or skill_tree.visible or not _owns_tower(selected_tower):
		return false
	var tower := selected_tower
	if not board.remove_block(tower.cell):
		return false
	var refund := tower.refund()
	selected_tower = null
	tower.set_process(false)
	board.get_node("Towers").remove_child(tower)
	tower.queue_free()
	currency += refund
	_refresh_hud()
	hud.show_message("Tower removed • +%d gold" % refund)
	return true


func _on_restart_prompt_changed(open: bool) -> void:
	if open == _restart_confirming:
		return
	_restart_confirming = open
	if open:
		_prior_board_mode = board.process_mode
		_prior_wave_mode = waves.process_mode
		board.process_mode = Node.PROCESS_MODE_DISABLED
		waves.process_mode = Node.PROCESS_MODE_DISABLED
	else:
		board.process_mode = _prior_board_mode
		waves.process_mode = _prior_wave_mode
		call_deferred("_try_auto_start_wave")
	_refresh_hud()


func restart() -> void:
	if _restart_pending:
		return
	_restart_pending = true
	progression.save_profile()
	get_tree().set_meta("td_restart_progression", progression)
	call_deferred("_reload_run")


func _reload_run() -> void:
	if get_tree().reload_current_scene() != OK:
		get_tree().remove_meta("td_restart_progression")
		_restart_pending = false
		hud.show_message("Restart failed; current progress is preserved")


func start_wave() -> void:
	if is_finished() or _restart_confirming or skill_tree.visible or phase == Phase.WAVE_ACTIVE:
		return
	if waves.start_next_wave():
		phase = Phase.WAVE_ACTIVE
		hud.show_message("Wave %d started • You may keep building" % waves.current_wave)
		_refresh_hud()


func set_auto_start_waves(enabled: bool) -> void:
	if is_finished() or _restart_pending or _restart_confirming:
		return
	auto_start_waves = enabled
	_refresh_hud()
	call_deferred("_try_auto_start_wave")


func _try_auto_start_wave() -> void:
	# Recheck after signal dispatch: menus, cancellation, defeat or restart may
	# have intervened. start_wave() also prevents duplicate queued requests.
	if auto_start_waves and not _restart_pending and phase == Phase.BETWEEN_WAVES and not skill_tree.visible and not _restart_confirming:
		start_wave()


func _spawn_enemy(profile: EnemyProfile) -> void:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	enemy.died.connect(_on_enemy_died)
	enemy.reached_exit.connect(_on_enemy_reached_exit)
	enemy.navigation_failed.connect(_on_navigation_failed)
	enemy.visual_seed = _enemy_serial
	_enemy_serial += 1
	board.get_node("Enemies").add_child(enemy)
	progression.apply_enemy_nerfs(profile)
	enemy.setup_profile(board, profile)
	_request_hud_refresh()


func _on_enemy_died(enemy: Enemy) -> void:
	if is_finished():
		return
	currency += progression.gold_reward(enemy.bounty)
	waves.enemy_resolved()
	_request_hud_refresh()


func _on_enemy_reached_exit(_enemy: Enemy) -> void:
	if is_finished():
		return
	lives = maxi(0, lives - GameConfig.BASE_DAMAGE)
	if lives == 0:
		_finish(Phase.DEFEAT)
	else:
		hud.show_message("An enemy reached the exit • -1 base life")
	waves.enemy_resolved()
	_refresh_hud()


func _on_wave_completed(wave: int) -> void:
	if phase != Phase.WAVE_ACTIVE or lives <= 0 or wave != waves.current_wave or waves.running or waves.active_count != 0 or waves.remaining_to_spawn != 0:
		return
	_clear_projectiles()
	currency += progression.gold_reward(GameConfig.WAVE_CLEAR_BONUS)
	progression.award_wave(_run_id, wave)
	phase = Phase.BETWEEN_WAVES
	hud.show_message("Wave %d cleared • +%d gold • +1 diamond" % [wave, progression.gold_reward(GameConfig.WAVE_CLEAR_BONUS)])
	if wave % GameConfig.SKILL_MENU_INTERVAL == 0:
		open_skill_tree()
	_refresh_hud()
	if auto_start_waves:
		call_deferred("_try_auto_start_wave")


func open_skill_tree() -> void:
	if is_finished() or _restart_confirming or phase == Phase.WAVE_ACTIVE:
		return
	cancel_build()
	skill_tree.refresh(progression)
	skill_tree.show()
	skill_tree.get_node("Panel/Margin/Items/Footer/Close").grab_focus()
	_refresh_hud()


func close_skill_tree() -> void:
	skill_tree.hide()
	_refresh_hud()
	if auto_start_waves:
		call_deferred("_try_auto_start_wave")


func purchase_skill(id: String) -> bool:
	if _restart_confirming or not skill_tree.visible or phase == Phase.WAVE_ACTIVE or is_finished():
		return false
	var error := progression.purchase_error(id)
	if not error.is_empty():
		skill_tree.refresh(progression)
		return false
	if not progression.purchase(id):
		skill_tree.refresh(progression)
		return false
	for child in board.get_node("Towers").get_children():
		(child as Tower).configure_progression(progression)
	skill_tree.refresh(progression)
	_refresh_hud()
	return true


func _retry_save() -> void:
	progression.save_profile()
	skill_tree.refresh(progression)
	_refresh_hud()


func _finish(result: Phase) -> void:
	phase = result
	skill_tree.hide()
	selected_tower = null
	building = false
	waves.stop()
	_clear_projectiles()
	board.get_node("Enemies").process_mode = Node.PROCESS_MODE_DISABLED
	board.get_node("Towers").process_mode = Node.PROCESS_MODE_DISABLED
	hud.show_message("DEFEAT • The base has fallen. Restart for a fresh wave sequence.")
	_refresh_hud()


func _clear_projectiles() -> void:
	var container := board.get_node_or_null("Projectiles")
	if container != null:
		for child in container.get_children():
			child.set_process(false)
			child.queue_free()


func _on_navigation_failed(message: String) -> void:
	# Unexpected invariant failure remains visible; never remove a stuck enemy.
	hud.show_message("NAVIGATION ERROR: " + message)


func _request_hud_refresh() -> void:
	# Spawn/death bursts change authoritative counters immediately. Build the
	# visual sidebar once before rendering instead of once per actor resolved.
	if not _hud_refresh_queued:
		_hud_refresh_queued = true
		_flush_hud_refresh.call_deferred()


func _flush_hud_refresh() -> void:
	if _hud_refresh_queued:
		_refresh_hud()


func _refresh_hud() -> void:
	_hud_refresh_queued = false
	var status: String = Phase.keys()[phase].replace("_", " ")
	if phase == Phase.WAVE_ACTIVE:
		status += "\n%d active • %d to spawn" % [waves.active_count, waves.remaining_to_spawn]
	hud.display(currency, lives, waves.current_wave, status, building, waves.can_start() and not skill_tree.visible, is_finished() or skill_tree.visible)
	hud.display_progression(progression, phase != Phase.WAVE_ACTIVE and not is_finished() and not skill_tree.visible, build_kind)
	(hud.get_node("RightPanel/Margin/Items/Restart") as Button).disabled = skill_tree.visible or _restart_pending
	hud.auto_start_button.set_pressed_no_signal(auto_start_waves)
	hud.auto_start_button.disabled = is_finished() or skill_tree.visible or _restart_pending or _restart_confirming
	var cost := int(TowerCatalog.DATA[build_kind].cost)
	var radius := float(TowerCatalog.DATA[build_kind].range)
	board.set_build_preview(building and not skill_tree.visible, currency, cost, radius)
	var selected := selected_tower if _owns_tower(selected_tower) else null
	hud.display_tower(selected, currency, is_finished() or skill_tree.visible)
	board.show_tower_selection(selected.cell if selected != null else Vector2i(-1, -1), selected.attack_range() if selected != null else 0.0)
