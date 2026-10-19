extends RefCounted
## Shared, unchanged prior best-bot policy plus the requested hallway policy.

static func spend_skills(game: TDGame) -> void:
	game.open_skill_tree()
	for id in ["tesla", "basic_training", "salvage", "tesla_training", "gold_mastery", "sluggish", "fragile", "static_field", "piercing"]:
		if not game.progression.has_skill(id):
			if not game.purchase_skill(id):
				break
	game.close_skill_tree()


static func build_and_upgrade(game: TDGame, wave: int) -> void:
	# Distributed coverage, then increase damage; short-range Tesla covers packs.
	var positions: Array[Vector2i] = []
	for y in [11, 13]:
		for x in range(3, 38, 3):
			positions.append(Vector2i(x, y))
	var target_count := mini(24, 3 + wave * 2)
	for index in range(target_count):
		var cell := positions[index]
		if game.tower_at_cell(cell) != null:
			continue
		var kind := Tower.Kind.TESLA if index >= 12 and index % 2 == 0 and game.progression.has_skill("tesla") else Tower.Kind.BASIC
		game.select_tower(kind)
		if not game.purchase_tower(cell):
			break
	# Several towers upgrade together, avoiding one expensive tower monopolizing gold.
	for level in range(1, 6):
		for node in game.board.get_node("Towers").get_children():
			var tower := node as Tower
			if tower.upgrade_level >= level or not tower.upgrades_enabled:
				continue
			game.select_placed_tower(tower)
			game.upgrade_selected_tower(Tower.Upgrade.DAMAGE)


static func hallway_candidates() -> Array[Vector2i]:
	# Includes the sealing candidate at each wall end, so production validation
	# must reject it. Consecutive walls leave exactly one free corridor column.
	var result: Array[Vector2i] = [Vector2i(0, 11)]
	for y in range(12, 24):
		result.append(Vector2i(1, y))
	for x in range(3, 39, 2):
		var bottom_up := floori((x - 3) / 2.0)
		for step in range(24):
			var y := 23 - step if bottom_up % 2 == 0 else step
			result.append(Vector2i(x, y))
	return result


static func build_hallways(game: TDGame, state: Dictionary) -> String:
	var candidates := hallway_candidates()
	game.select_tower(Tower.Kind.BASIC)
	while game.currency >= GameConfig.TOWER_COST and int(state.index) < candidates.size():
		var cell := candidates[int(state.index)]
		var error := game.board.placement_error(cell, game.currency)
		if error == "Cannot block the last route":
			state.gaps.append([cell.x, cell.y])
			state.index += 1
			continue
		if not error.is_empty():
			return "Unexpected hallway placement rejection at %s: %s" % [cell, error]
		if not game.purchase_tower(cell):
			return "Hallway purchase failed at %s" % cell
		state.index += 1
	return ""
