extends Node2D
## Authoritative game manager: currency, diamonds, lives, skill unlocks, build tool,
## tower selection, game state, tower purchases/upgrades/sales, defeat and wiring
## between Board, WaveManager and HUD.
## Waves are endless; the run ends only when lives reach zero. Diamonds and skill
## unlocks are permanent: they are saved and carry over to every future run.

enum GameState { READY, WAVE_ACTIVE, BETWEEN_WAVES, DEFEAT }

const TOWER_SCENE: PackedScene = preload("res://scenes/tower.tscn")

var currency: int = GameConfig.STARTING_CURRENCY
var lives: int = GameConfig.STARTING_LIVES
var diamonds: int = 0
var skills: SkillTree = SkillTree.new()
var state: GameState = GameState.READY
var build_mode: bool = false
var build_type: String = TowerTypes.BASIC
var selected_tower: Tower = null
## When on, the next wave starts AUTO_START_DELAY seconds after the previous one is cleared.
var auto_start: bool = false

var _auto_start_left: float = -1.0

var _towers_by_cell: Dictionary = {}  # Vector2i -> Tower

@onready var board: Board = %Board
@onready var wave_manager: WaveManager = $WaveManager
@onready var hud: Hud = %UILayout


func _ready() -> void:
	var progress: Dictionary = ProgressStore.load_progress()
	diamonds = progress["diamonds"]
	skills.restore(progress["unlocked"])
	auto_start = progress["auto_start"]
	wave_manager.setup(board)
	board.cell_clicked.connect(_on_board_cell_clicked)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.enemy_spawned.connect(_on_enemy_spawned)
	wave_manager.enemy_killed.connect(_on_enemy_killed)
	wave_manager.enemy_escaped.connect(_on_enemy_escaped)
	hud.build_pressed.connect(_on_build_pressed)
	hud.cancel_pressed.connect(_on_cancel_pressed)
	hud.start_wave_pressed.connect(_on_start_wave_pressed)
	hud.restart_pressed.connect(restart_game)
	hud.upgrade_pressed.connect(_on_upgrade_pressed)
	hud.sell_pressed.connect(_on_sell_pressed)
	hud.skills_pressed.connect(open_skill_menu.bind("Skill Tree"))
	hud.skill_unlock_requested.connect(try_unlock_skill)
	hud.skill_menu_closed.connect(_on_skill_menu_closed)
	hud.progress_reset_requested.connect(reset_progress)
	hud.auto_start_toggled.connect(set_auto_start)
	restart_game()


func _process(delta: float) -> void:
	step_auto_start(delta)


## Counts down to the next wave while auto-start is on. Pauses with the game (skill tree).
func step_auto_start(delta: float) -> void:
	if _auto_start_left < 0.0:
		return
	if not auto_start or is_game_over() or (state != GameState.READY and state != GameState.BETWEEN_WAVES):
		_auto_start_left = -1.0
		return
	if is_skill_menu_open():
		return
	var shown_before: int = ceili(_auto_start_left)
	_auto_start_left -= delta
	if _auto_start_left <= 0.0:
		_auto_start_left = -1.0
		_on_start_wave_pressed()
	elif ceili(_auto_start_left) != shown_before:
		_refresh_hud()


func set_auto_start(enabled: bool) -> void:
	auto_start = enabled
	_save_progress()
	_schedule_auto_start()
	_refresh_hud()


func _schedule_auto_start() -> void:
	# Only between waves: wave 1 is always started by the player.
	if auto_start and not is_game_over() and state == GameState.BETWEEN_WAVES:
		_auto_start_left = GameConfig.AUTO_START_DELAY
	else:
		_auto_start_left = -1.0


## Seconds until the next wave auto-starts, or -1 if none is scheduled.
func get_auto_start_countdown() -> float:
	return _auto_start_left


func _unhandled_input(event: InputEvent) -> void:
	if not build_mode and selected_tower == null:
		return
	var mouse_event: InputEventMouseButton = event as InputEventMouseButton
	var right_click: bool = mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_RIGHT
	if right_click or event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_pressed()


func is_game_over() -> bool:
	return state == GameState.DEFEAT


func get_max_lives() -> int:
	return GameConfig.STARTING_LIVES + roundi(skills.total("lives"))


## Starts a new run: resets currency, lives, towers, enemies, board occupancy and waves.
## Diamonds and skill unlocks are permanent and are kept.
## A negative `seed_value` picks a random seed so each run's waves differ.
func restart_game(seed_value: int = -1) -> void:
	hud.hide_skill_menu()
	get_tree().paused = false
	_select_tower(null)
	wave_manager.reset(seed_value)
	for enemy: Node in board.enemies.get_children():
		(enemy as Enemy).discard()
	for tower: Node in board.towers.get_children():
		tower.queue_free()
	_towers_by_cell.clear()
	board.clear_blocked_cells()
	board.enemies.process_mode = Node.PROCESS_MODE_INHERIT
	board.towers.process_mode = Node.PROCESS_MODE_INHERIT
	currency = GameConfig.STARTING_CURRENCY
	lives = get_max_lives()
	state = GameState.READY
	_auto_start_left = -1.0
	build_type = TowerTypes.BASIC
	_apply_skill_modifiers()
	_set_build_mode(false)
	hud.show_message("Build towers to shape a maze, then press Start Wave. Waves are endless - survive as long as you can.")
	_refresh_hud()


func get_tower_at(cell: Vector2i) -> Tower:
	return _towers_by_cell.get(cell)


func get_tower_count() -> int:
	return _towers_by_cell.size()


## Attempts to buy a tower of `type_id` (default: the selected build type) on `cell`.
## Currency is deducted only after the board accepts the block and the tower node
## exists; any failure leaves the game unchanged.
func try_buy_tower(cell: Vector2i, type_id: String = "") -> bool:
	if type_id == "":
		type_id = build_type
	if is_game_over() or is_skill_menu_open():
		return false
	if not skills.is_tower_unlocked(type_id):
		hud.show_error("%s is locked - unlock it in the Skill Tree" % TowerTypes.display_name(type_id))
		return false
	var cost: int = TowerTypes.cost(type_id)
	if currency < cost:
		hud.show_error("Insufficient currency")
		return false
	var reason: String = board.try_block_cell_live(cell)
	if reason != "":
		hud.show_error(reason)
		return false
	var tower: Tower = TOWER_SCENE.instantiate() as Tower
	if tower == null:
		board.unblock_cell(cell)
		hud.show_error("Tower could not be created")
		return false
	tower.configure(type_id)
	tower.cell = cell
	tower.position = Board.cell_to_world(cell)
	_apply_tower_modifiers(tower)
	board.towers.add_child(tower)
	_towers_by_cell[cell] = tower
	currency -= cost
	if build_mode and currency < TowerTypes.cost(build_type):
		_set_build_mode(false)
		hud.show_message("%s built. Not enough currency for another; build mode ended." % TowerTypes.display_name(type_id))
	else:
		hud.show_message("%s built (-%d)." % [TowerTypes.display_name(type_id), cost])
	_refresh_hud()
	return true


## True when the skill tree allows `path` on towers of `type_id`.
func is_path_unlocked(type_id: String, path: Tower.UpgradePath) -> bool:
	if not skills.upgrades_unlocked(type_id):
		return false
	if path == TowerTypes.get_def(type_id)["unique_path"]:
		return skills.unique_path_unlocked(type_id)
	return true


## Upgrades `tower` along `path` if the skill tree allows it and it is affordable.
## Charges only on success.
func try_upgrade_tower(tower: Tower, path: Tower.UpgradePath) -> bool:
	if is_game_over() or tower == null or not _towers_by_cell.has(tower.cell):
		return false
	if path == Tower.UpgradePath.NONE:
		return false
	if not is_path_unlocked(tower.tower_type, path):
		hud.show_error("%s upgrade is locked - unlock it in the Skill Tree" % Tower.PATH_NAMES[path])
		return false
	if not tower.can_upgrade(path):
		if tower.upgrade_level >= GameConfig.UPGRADE_MAX_LEVEL:
			hud.show_error("Tower is fully upgraded")
		else:
			hud.show_error("This tower is already upgrading %s" % Tower.PATH_NAMES[tower.upgrade_path])
		return false
	var cost: int = tower.next_upgrade_cost()
	if currency < cost:
		hud.show_error("Insufficient currency (upgrade costs %d)" % cost)
		return false
	currency -= cost
	tower.apply_upgrade(path)
	hud.show_message("%s upgraded to level %d (-%d)." % [Tower.PATH_NAMES[path], tower.upgrade_level, cost])
	_refresh_hud()
	return true


## Sells the tower on `cell`, refunding SELL_REFUND_RATIO of everything spent on it.
## Unblocking a cell only ever adds routes, so it is always safe, even mid-wave.
func try_sell_tower(cell: Vector2i) -> bool:
	if is_game_over():
		return false
	var tower: Tower = get_tower_at(cell)
	if tower == null:
		return false
	var refund: int = tower.sell_value()
	if tower == selected_tower:
		_select_tower(null)
	_towers_by_cell.erase(cell)
	board.unblock_cell(cell)
	board.towers.remove_child(tower)
	tower.queue_free()
	currency += refund
	hud.show_message("Tower sold (+%d)." % refund)
	_refresh_hud()
	return true


# --- Skill tree --------------------------------------------------------------------

func is_skill_menu_open() -> bool:
	return hud.is_skill_menu_open()


## Opens the skill tree and pauses the game until it is closed.
func open_skill_menu(subtitle: String) -> void:
	if is_game_over():
		return
	_set_build_mode(false)
	hud.show_skill_menu(subtitle, diamonds, skills)
	get_tree().paused = true


func close_skill_menu() -> void:
	hud.hide_skill_menu()
	_on_skill_menu_closed()


## Spends diamonds on `skill_id` if its prerequisites are met and it is affordable.
## Unlocks are saved immediately and apply to this and every future run.
func try_unlock_skill(skill_id: String) -> bool:
	if not skills.can_unlock(skill_id, diamonds):
		return false
	diamonds -= skills.cost(skill_id)
	skills.unlock(skill_id)
	var bonus_lives: int = roundi(float(SkillTree.SKILLS[skill_id]["effects"].get("lives", 0)))
	if bonus_lives > 0 and not is_game_over():
		lives += bonus_lives
	_apply_skill_modifiers()
	_save_progress()
	hud.show_message("Unlocked %s." % SkillTree.SKILLS[skill_id]["name"])
	hud.refresh_skill_menu(diamonds, skills)
	_refresh_hud()
	return true


## Wipes all permanent progress (diamonds and unlocks) and starts a fresh run.
func reset_progress() -> void:
	diamonds = 0
	skills.reset()
	_save_progress()
	restart_game()
	hud.show_message("All progress reset.")


func _save_progress() -> void:
	ProgressStore.save_progress(diamonds, skills.unlocked_ids(), auto_start)


func _apply_skill_modifiers() -> void:
	wave_manager.enemy_health_multiplier = maxf(0.1, 1.0 + skills.total("enemy_health"))
	wave_manager.enemy_speed_multiplier = maxf(0.1, 1.0 + skills.total("enemy_speed"))
	for tower: Tower in _towers_by_cell.values():
		_apply_tower_modifiers(tower)


func _apply_tower_modifiers(tower: Tower) -> void:
	tower.set_global_modifiers(1.0 + skills.total("tower_damage"), 1.0 / (1.0 + skills.total("tower_attack_speed")))


func _on_skill_menu_closed() -> void:
	get_tree().paused = false
	_refresh_hud()


# --- HUD sync -------------------------------------------------------------------------

func _select_tower(tower: Tower) -> void:
	if selected_tower != null and is_instance_valid(selected_tower):
		selected_tower.selected = false
	selected_tower = tower
	if tower != null:
		tower.selected = true
	_refresh_selection()


func _set_build_mode(active: bool) -> void:
	build_mode = active
	if active:
		_select_tower(null)
	hud.set_build_mode(active, TowerTypes.display_name(build_type))
	_refresh_hud()


func _refresh_hud() -> void:
	var state_text: String = GameState.keys()[state].replace("_", " ")
	hud.update_status(currency, lives, wave_manager.current_wave, state_text, wave_manager.run_seed)
	hud.update_diamonds(diamonds)
	hud.update_enemy_counts(wave_manager.get_remaining_to_spawn(), wave_manager.get_unresolved_count())
	if not is_game_over():
		hud.update_next_wave(wave_manager.current_wave + 1, wave_manager.preview_next_wave())
	var can_start: bool = (state == GameState.READY or state == GameState.BETWEEN_WAVES) and wave_manager.has_next_wave() and not is_skill_menu_open()
	var unlocked_types: Array[String] = []
	for type_id: String in TowerTypes.ORDER:
		if skills.is_tower_unlocked(type_id):
			unlocked_types.append(type_id)
	hud.set_buttons(not is_game_over(), can_start, build_mode, build_type, unlocked_types)
	hud.set_auto_start(auto_start, _auto_start_left if not is_skill_menu_open() else -1.0)
	board.set_build_state(build_mode, currency >= TowerTypes.cost(build_type), TowerTypes.get_def(build_type)["range"])
	_refresh_selection()


func _refresh_selection() -> void:
	if selected_tower == null or not is_instance_valid(selected_tower):
		hud.hide_selection()
		return
	var t: Tower = selected_tower
	var buttons: Dictionary = {}
	var any_unlocked: bool = false
	for path: Tower.UpgradePath in t.available_paths():
		var unlocked: bool = is_path_unlocked(t.tower_type, path)
		any_unlocked = any_unlocked or unlocked
		var locked_out: bool = t.upgrade_path != Tower.UpgradePath.NONE and t.upgrade_path != path
		var cost_text: String = "MAX" if t.next_upgrade_cost() < 0 else str(t.next_upgrade_cost())
		buttons[path] = {
			"visible": unlocked and not locked_out,
			"enabled": unlocked and t.can_upgrade(path) and not is_game_over() and currency >= t.next_upgrade_cost(),
			"text": "Upgrade %s (%s)" % [Tower.PATH_NAMES[path], cost_text],
		}
	var note: String = ""
	if not skills.upgrades_unlocked(t.tower_type):
		note = "Upgrades locked - unlock %s Upgrades in the Skill Tree." % TowerTypes.get_def(t.tower_type)["short"]
	var level_text: String = "Level %d/%d (%s)" % [t.upgrade_level, GameConfig.UPGRADE_MAX_LEVEL, Tower.PATH_NAMES[t.upgrade_path]] if t.upgrade_level > 0 else "No upgrades yet"
	hud.show_selection({
		"title": "%s - %s" % [TowerTypes.display_name(t.tower_type).to_upper(), level_text],
		"stats": "Damage %d%s, range %d px, every %.2f s" % [t.damage, " to all in range" if t.is_area() else "", int(t.attack_range), t.cooldown],
		"note": note,
		"buttons": buttons,
		"sell_value": t.sell_value(),
		"can_sell": not is_game_over(),
	})


func _end_game(message: String) -> void:
	state = GameState.DEFEAT
	wave_manager.stop()
	# Freeze remaining enemies and towers; only Restart stays available.
	board.enemies.process_mode = Node.PROCESS_MODE_DISABLED
	board.towers.process_mode = Node.PROCESS_MODE_DISABLED
	_select_tower(null)
	_set_build_mode(false)
	hud.show_message(message)
	_refresh_hud()


# --- Signal handlers -----------------------------------------------------------

func _on_build_pressed(type_id: String) -> void:
	if is_game_over() or is_skill_menu_open():
		return
	if not skills.is_tower_unlocked(type_id):
		hud.show_error("%s is locked - unlock it in the Skill Tree" % TowerTypes.display_name(type_id))
		return
	if currency < TowerTypes.cost(type_id):
		hud.show_error("Insufficient currency")
		return
	build_type = type_id
	_set_build_mode(true)
	hud.show_message("Build mode: %s." % TowerTypes.display_name(type_id))


func _on_cancel_pressed() -> void:
	if build_mode:
		_set_build_mode(false)
		hud.show_message("Build mode canceled.")
	elif selected_tower != null:
		_select_tower(null)


func _on_board_cell_clicked(cell: Vector2i) -> void:
	if is_game_over() or is_skill_menu_open():
		return
	if build_mode:
		try_buy_tower(cell)
	else:
		# Outside build mode, clicking a tower selects it; clicking anything else deselects.
		_select_tower(get_tower_at(cell))


func _on_upgrade_pressed(path: int) -> void:
	try_upgrade_tower(selected_tower, path as Tower.UpgradePath)


func _on_sell_pressed() -> void:
	if selected_tower != null:
		try_sell_tower(selected_tower.cell)


func _on_start_wave_pressed() -> void:
	if state != GameState.READY and state != GameState.BETWEEN_WAVES:
		return
	if is_skill_menu_open():
		return
	wave_manager.start_next_wave()


func _on_wave_started(wave_number: int) -> void:
	state = GameState.WAVE_ACTIVE
	_auto_start_left = -1.0
	var boss_note: String = "  A Warlord approaches!" if WaveGenerator.is_boss_wave(wave_number) else ""
	hud.show_message("Wave %d started!%s" % [wave_number, boss_note])
	_refresh_hud()


func _on_enemy_spawned(_enemy: Enemy) -> void:
	_refresh_hud()


func _on_enemy_killed(enemy: Enemy) -> void:
	currency += roundi(enemy.reward * (1.0 + skills.total("kill_reward")))
	_refresh_hud()


func _on_enemy_escaped(enemy: Enemy) -> void:
	lives = maxi(lives - enemy.lives_cost, 0)
	if lives == 0 and not is_game_over():
		_end_game("DEFEAT on wave %d - the base has fallen. Your diamonds and skills are kept. Press Restart to try again." % wave_manager.current_wave)
		return
	_refresh_hud()


func _on_wave_completed(wave_number: int) -> void:
	if is_game_over():
		return
	var bonus: int = roundi(WaveGenerator.wave_clear_bonus(wave_number) * (1.0 + skills.total("wave_bonus")))
	currency += bonus
	diamonds += GameConfig.DIAMONDS_PER_WAVE
	_save_progress()
	state = GameState.BETWEEN_WAVES
	hud.show_message("Wave %d cleared! +%d gold, +%d diamond. Press Start Wave when ready." % [wave_number, bonus, GameConfig.DIAMONDS_PER_WAVE])
	_schedule_auto_start()
	_refresh_hud()
	if wave_number % GameConfig.SKILL_MENU_WAVE_INTERVAL == 0:
		open_skill_menu("Wave %d complete - spend your diamonds" % wave_number)
