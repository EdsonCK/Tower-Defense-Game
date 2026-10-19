extends SceneTree
## Actual viewport hover/click behavior on the branching research graph.

var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func move(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)


func click(point: Vector2) -> void:
	move(point)
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event)


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	game.progression.diamonds = 1000
	root.add_child(game)
	game.board.process_mode = Node.PROCESS_MODE_DISABLED
	game.waves.set_process(false)
	await process_frame
	game.open_skill_tree()
	await process_frame
	await process_frame
	var menu := game.skill_tree
	check(menu.buy_buttons.size() == 40 and menu.graph.positions.size() == 40, "all forty skills have icon nodes and positions")
	check(not menu.hover_card.visible, "no upgrade information is shown before hover")
	check((menu.get_node("Panel/Margin/Items/Footer/Close") as Button).has_focus(), "opening research puts keyboard focus inside its modal")
	check(game.hud.skills_button.disabled and (game.hud.get_node("RightPanel/Margin/Items/Restart") as Button).disabled, "background keyboard controls cannot reopen research or restart through the modal")
	var root_icon := menu.buy_buttons["tesla"] as ResearchIcon
	var previous := game.progression.diamonds
	for id in SkillCatalog.IDS:
		var icon := menu.buy_buttons[id] as ResearchIcon
		check(icon.text.is_empty() and icon.get_child_count() == 0, "no persistent information text on node: " + id)
		var requirement: String = SkillCatalog.NODES[id].requires
		check(icon.available == (id == "tesla"), "Tesla is the sole first available research: " + id)
		if not requirement.is_empty():
			check(menu.graph.positions[id].y > menu.graph.positions[requirement].y, "prerequisite edges branch downward: " + id)
		for other_id in SkillCatalog.IDS:
			if other_id > id:
				check(not icon.get_rect().intersects((menu.buy_buttons[other_id] as Control).get_rect()), "icon hit areas do not overlap: %s / %s" % [id, other_id])
	move(root_icon.get_global_rect().get_center())
	await process_frame
	check(menu.hover_card.visible and menu.hover_text.text.contains("Tesla Tower") and menu.hover_text.text.contains("3 diamonds"), "actual mouse hover reveals title, price, prerequisites and effect")
	check(game.progression.diamonds == previous and game.progression.unlocked.is_empty(), "hover never buys or spends")
	click(root_icon.get_global_rect().get_center())
	check(game.progression.has_skill("tesla") and game.progression.diamonds == previous - 3, "one icon click immediately purchases Tesla")
	click(root_icon.get_global_rect().get_center())
	check(game.progression.diamonds == previous - 3, "repeat icon click cannot buy an owned node again")
	move(Vector2(135, 140))
	await process_frame
	check(not menu.hover_card.visible, "information disappears when cursor leaves the icon")
	var mortar := menu.buy_buttons["mortar"] as ResearchIcon
	move(mortar.get_global_rect().get_center())
	await process_frame
	check(menu.hover_text.text.contains("Arcing shells") and menu.hover_card.visible, "new tower's hover describes its attack")
	click(mortar.get_global_rect().get_center())
	check(game.progression.has_skill("mortar"), "new tower icon purchases its unlock")
	var mastery := menu.buy_buttons["mortar_mastery"] as ResearchIcon
	menu.scroll.ensure_control_visible(mastery)
	await process_frame
	var before := game.progression.diamonds
	click(mastery.get_global_rect().get_center())
	check(not game.progression.has_skill("mortar_mastery") and game.progression.diamonds == before, "locked mastery icon cannot bypass training prerequisite")
	check(menu.hover_text.text.contains("Requires") and menu.hover_card.visible, "locked icons still reveal their requirements")
	menu.scroll.ensure_control_visible(menu.buy_buttons["shield_decay"])
	await process_frame
	move((menu.buy_buttons["shield_decay"] as Control).get_global_rect().get_center())
	await process_frame
	check(Rect2(0, 0, 1600, 900).encloses(menu.hover_card.get_global_rect()), "hover information is clamped inside the logical screen at the bottom of the graph")
	game.close_skill_tree()
	check(not menu.hover_card.visible, "closing research clears hover info")
	# Hover/click research cannot place a tower on the board underneath.
	check(game.board.get_node("Towers").get_child_count() == 0 and game.currency == GameConfig.STARTING_CURRENCY, "research graph input never leaks to board construction")
	game.select_tower(Tower.Kind.MORTAR)
	var button := game.hud.build_buttons[Tower.Kind.MORTAR]
	check(not button.disabled and game.building, "purchased mortar is available on the fixed build palette")
	var rectangles: Array[Rect2] = []
	for build_button in game.hud.build_buttons:
		rectangles.append(build_button.get_global_rect())
	game.currency = 0
	game._refresh_hud()
	await process_frame
	for i in range(game.hud.build_buttons.size()):
		check(game.hud.build_buttons[i].get_global_rect() == rectangles[i], "lock/price/affordability cannot move build buttons")
	game.free()
	await process_frame
	print("Research icon input: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
