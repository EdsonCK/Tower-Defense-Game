extends "res://tests/test_base.gd"
## HUD layout guard: no visible UI may ever cover the playable board, in any HUD state.
## Runs real frames so containers lay themselves out exactly as in the game.
##   godot --headless --path <project> --script res://tests/test_layout.gd

const LONG_TEXT: String = "This is a deliberately enormous status message used to stress the HUD layout. It keeps going and going, far longer than any real message, so that wrapping, clipping and scrolling are all exercised at once. "


func get_tests() -> Array[Callable]:
	return [
		test_board_area_matches_board,
		test_hud_never_covers_board_in_stress_states,
		test_overflowing_panels_scroll_instead_of_growing,
		test_layout_holds_after_real_gameplay,
		test_hud_elements_never_move,
	]


func _wait_frames(count: int) -> void:
	for i in count:
		await process_frame


func _board_rect(main: Node2D) -> Rect2:
	return Rect2(main.board.global_position, Vector2(GameConfig.BOARD_WIDTH, GameConfig.BOARD_HEIGHT))


## Visible rect of `control` after clipping by every clip_contents ancestor.
func _clipped_rect(control: Control) -> Rect2:
	var rect: Rect2 = control.get_global_rect()
	var parent: Node = control.get_parent()
	while parent != null:
		if parent is Control and (parent as Control).clip_contents:
			rect = rect.intersection((parent as Control).get_global_rect())
		parent = parent.get_parent()
	return rect


## Every visible HUD control that is not an approved transparent layout node must stay
## off the board and inside the viewport. Returns "" or the first offender.
func _layout_violation(main: Node2D) -> String:
	var board_rect: Rect2 = _board_rect(main)
	var viewport_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(1600, 900))
	var hud_root: Control = main.hud
	var nodes: Array[Node] = [hud_root]
	nodes.append_array(hud_root.find_children("*", "Control", true, false))
	for node: Node in nodes:
		var control: Control = node as Control
		if not control.is_visible_in_tree():
			continue
		if _in_modal(control):
			continue  # full-screen modal menus pause the game; checked in test_skills
		if control.is_in_group(Hud.PASSTHROUGH_GROUP):
			if control.mouse_filter != Control.MOUSE_FILTER_IGNORE or control.get_class() not in Hud.PASSTHROUGH_CLASSES:
				return "%s is marked passthrough but can draw or catch clicks (%s, filter %d)" % [control.name, control.get_class(), control.mouse_filter]
			continue
		var rect: Rect2 = _clipped_rect(control)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		if rect.intersects(board_rect):
			return "%s (%s) covers the board: %s vs board %s" % [control.get_path(), control.get_class(), rect, board_rect]
		if not viewport_rect.encloses(rect.grow(-0.5)):
			return "%s (%s) extends outside the 1600x900 view: %s" % [control.get_path(), control.get_class(), rect]
	return ""


func _in_modal(control: Control) -> bool:
	var node: Node = control
	while node != null:
		if node.is_in_group(Hud.MODAL_GROUP):
			return true
		node = node.get_parent()
	return false


func _stress_states(main: Node2D) -> Array[Callable]:
	var hud: Hud = main.hud
	var huge_counts: Dictionary = {}
	for type_id: String in EnemyTypes.DEFS:
		huge_counts[type_id] = 9999
	var selection: Dictionary = {
		"title": "CANNON CANNON CANNON CANNON", "level": "Lv 999/999 Armor piercing piercing",
		"damage": {"health": 9999999, "armor": 9999999, "shield": 9999999},
		"stats": "Area  |  99999 px  |  0.01 s  |  splash 9999 " + LONG_TEXT,
		"note": "Unlock Cannon Upgrades in the Skill Tree. " + LONG_TEXT,
		"buttons": {
			Tower.UpgradePath.DAMAGE: {"text": "Damage 999999999", "enabled": true, "chosen": true},
			Tower.UpgradePath.RANGE: {"text": "Range locked locked locked", "enabled": false, "chosen": false},
			Tower.UpgradePath.SPEED: {"text": "Speed n/a n/a n/a n/a", "enabled": false, "chosen": false},
			Tower.UpgradePath.SHRAPNEL: {"text": "Shrapnel 999999999", "enabled": true, "chosen": false},
		},
		"unique_path": Tower.UpgradePath.SHRAPNEL,
		"sell_value": 999999999, "can_sell": true,
	}
	return [
		func() -> void: pass,
		func() -> void: hud.show_message(LONG_TEXT),
		func() -> void: hud.show_error(LONG_TEXT + LONG_TEXT + LONG_TEXT),
		func() -> void: hud.set_build_mode(true),
		func() -> void: hud.update_status(2147483647, 999999, 999999, "BETWEEN WAVES BETWEEN WAVES BETWEEN WAVES", 9223372036854775807),
		func() -> void: hud.update_diamonds(2147483647),
		func() -> void: hud.set_buttons(true, true, false, TowerTypes.BASIC, TowerTypes.ORDER),
		func() -> void: hud.update_enemy_counts(999999, 999999),
		func() -> void: hud.update_next_wave(999999, huge_counts),
		func() -> void: hud.show_selection(selection),
		func() -> void:
			hud.update_next_wave(999999, huge_counts)
			hud.show_selection(selection)
			hud.show_error(LONG_TEXT + LONG_TEXT)
			hud.set_build_mode(true),
	]


func test_board_area_matches_board() -> void:
	var main: Node2D = _make_main()
	await _wait_frames(3)
	var area: Rect2 = main.hud.get_board_rect()
	_check(area.size == Vector2(GameConfig.BOARD_WIDTH, GameConfig.BOARD_HEIGHT), "reserved board area is exactly 1280x768 (%s)" % area.size)
	_check(area.position == main.board.global_position, "Board node sits exactly on the reserved area (%s vs %s)" % [area.position, main.board.global_position])


func test_hud_never_covers_board_in_stress_states() -> void:
	var main: Node2D = _make_main()
	var states: Array[Callable] = _stress_states(main)
	var violation: String = ""
	for i in states.size():
		states[i].call()
		await _wait_frames(3)
		violation = _layout_violation(main)
		if violation != "":
			violation = "state %d: %s" % [i, violation]
			break
	_check(violation == "", "no HUD element covers the board in %d stress states%s" % [states.size(), "" if violation == "" else " - " + violation])
	_check(_board_rect(main).position == main.hud.get_board_rect().position, "board did not move under stress")


func test_overflowing_panels_scroll_instead_of_growing() -> void:
	var main: Node2D = _make_main()
	var hud: Hud = main.hud
	await _wait_frames(3)
	var right_before: Rect2 = hud.get_node("Root/RightPanel").get_global_rect()
	var bottom_before: Rect2 = hud.get_node("Root/LeftColumn/BottomPanel").get_global_rect()
	for state: Callable in _stress_states(main):
		state.call()
	# Simulate future updates piling more UI into both panels.
	for container: Node in [hud.get_node("%NextWaveLabel").get_parent(), hud.get_node("%MessageLabel").get_parent()]:
		for i in 40:
			var label: Label = Label.new()
			label.text = "Future HUD line %d with a fairly long description that has to wrap" % i
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			container.add_child(label)
			var button: Button = Button.new()
			button.text = "Future button %d" % i
			button.clip_text = true
			container.add_child(button)
	# A label that refuses to wrap must not widen the panel either.
	var wide: Label = Label.new()
	wide.text = "W".repeat(300)
	hud.get_node("%NextWaveLabel").get_parent().add_child(wide)
	await _wait_frames(3)
	_check(right_before == Rect2(1280, 0, 320, 900), "right panel occupies the 320 px column right of the board (%s)" % right_before)
	_check(bottom_before == Rect2(0, 768, 1280, 132), "bottom panel occupies the 132 px strip below the board (%s)" % bottom_before)
	_check(hud.get_node("Root/RightPanel").get_global_rect() == right_before, "right panel keeps its rect when content overflows (%s)" % hud.get_node("Root/RightPanel").get_global_rect())
	_check(hud.get_node("Root/LeftColumn/BottomPanel").get_global_rect() == bottom_before, "bottom panel keeps its rect when content overflows (%s)" % hud.get_node("Root/LeftColumn/BottomPanel").get_global_rect())
	for path: String in ["Root/RightPanel/Scroll", "Root/LeftColumn/BottomPanel/Scroll"]:
		var scroll: ScrollContainer = hud.get_node(path)
		_check(scroll.get_v_scroll_bar().max_value > scroll.size.y, "%s scrolls its overflow (content %d px in %d px)" % [path.get_slice("/", path.get_slice_count("/") - 2), scroll.get_v_scroll_bar().max_value, scroll.size.y])
	_check(_layout_violation(main) == "", "nothing covers the board after the panels overflow: %s" % _layout_violation(main))


func test_layout_holds_after_real_gameplay() -> void:
	var main: Node2D = _make_main()
	main.currency = 100000
	main.try_buy_tower(Vector2i(10, 12))
	main._on_board_cell_clicked(Vector2i(10, 12))
	main._on_start_wave_pressed()
	await _wait_frames(30)
	_check(_layout_violation(main) == "", "layout clean mid-wave with a tower selected: %s" % _layout_violation(main))
	main.lives = 1
	main._on_enemy_escaped(_active_enemies(main)[0])
	await _wait_frames(3)
	_check(main.is_game_over() and _layout_violation(main) == "", "layout clean on the defeat screen: %s" % _layout_violation(main))


## Every visible, non-modal HUD control keyed by path -> its global rect.
func _hud_rects(main: Node2D) -> Dictionary:
	var rects: Dictionary = {}
	for node: Node in main.hud.find_children("*", "Control", true, false):
		var control: Control = node as Control
		if control.is_visible_in_tree() and not _in_modal(control):
			rects[str(main.hud.get_path_to(control))] = control.get_global_rect()
	return rects


## Buttons and text must not move or resize between waves, selections, build modes,
## messages or defeat: the HUD is built from fixed-size slots.
func test_hud_elements_never_move() -> void:
	var main: Node2D = _make_main()
	main.diamonds = 200
	for id: String in ["tesla", "cannon", "basic_upgrades", "tesla_upgrades", "cannon_upgrades", "basic_pierce"]:
		main.try_unlock_skill(id)
	main.currency = 100000
	main.try_buy_tower(Vector2i(10, 12), TowerTypes.BASIC)
	main.try_buy_tower(Vector2i(12, 3), TowerTypes.TESLA)
	main.try_buy_tower(Vector2i(14, 3), TowerTypes.CANNON)
	await _wait_frames(3)
	var baseline: Dictionary = _hud_rects(main)
	var states: Array = [
		["select Basic", func() -> void: main._on_board_cell_clicked(Vector2i(10, 12))],
		["upgrade it", func() -> void: main.try_upgrade_tower(main.selected_tower, Tower.UpgradePath.PIERCE)],
		["select Tesla", func() -> void: main._on_board_cell_clicked(Vector2i(12, 3))],
		["select Cannon", func() -> void: main._on_board_cell_clicked(Vector2i(14, 3))],
		["deselect", func() -> void: main._on_board_cell_clicked(Vector2i(30, 20))],
		["build mode", func() -> void: main._on_build_pressed(TowerTypes.CANNON)],
		["cancel build", func() -> void: main._on_cancel_pressed()],
		["wave active", func() -> void: main._on_start_wave_pressed()],
		["mid wave", func() -> void: _simulate(main, 0.05, 60)],
		["long message", func() -> void: main.hud.show_error(LONG_TEXT + LONG_TEXT)],
		["auto-start countdown", func() -> void:
			main.set_auto_start(true)
			_kill_all_active(main)
			while main.wave_manager.is_wave_active():
				_simulate(main, 0.05, 1)
				_kill_all_active(main)],
		["huge numbers", func() -> void:
			main.currency = 1234567890
			main.diamonds = 99999
			main._refresh_hud()],
		["defeat", func() -> void:
			main._on_start_wave_pressed()
			_simulate(main, 0.05, 5)
			main.lives = 1
			main._on_enemy_escaped(_active_enemies(main)[0])],
		["restart", func() -> void: main.restart_game()],
	]
	var moved: String = ""
	for state: Array in states:
		state[1].call()
		await _wait_frames(2)
		var now: Dictionary = _hud_rects(main)
		for key: String in baseline:
			if not now.has(key):
				moved = "%s: %s disappeared" % [state[0], key]
				break
			if now[key] != baseline[key]:
				moved = "%s: %s moved %s -> %s" % [state[0], key, baseline[key], now[key]]
				break
		if moved == "":
			for key: String in now:
				if not baseline.has(key):
					moved = "%s: %s appeared" % [state[0], key]
					break
		if moved != "":
			break
	_check(moved == "", "no HUD button or label moves or resizes across %d states (%d controls)%s" % [states.size(), baseline.size(), "" if moved == "" else " - " + moved])
