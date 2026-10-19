extends SceneTree
## Natural fresh-profile smoke checks. Full retained-profile campaigns are optional.
## Both bots use production economy/combat; no injected gold, health or damage.

const Bot = preload("res://tests/advanced_bot.gd")
const STRATEGY := Bot.DEFAULT_VARIANT
const DELTA := 1.0 / 30.0
var checks := 0
var failures := 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: ", description)


func session(seed_value: int, good: bool) -> Dictionary:
	var game := preload("res://scenes/main.tscn").instantiate() as TDGame
	game.progression = Progression.new("")
	root.add_child(game)
	game.process_mode = Node.PROCESS_MODE_DISABLED
	game.waves.set_run_seed(seed_value)
	var bot := Bot.new(STRATEGY)
	var cleared := 0
	var longest := 0
	for wave in range(1, 16):
		game.close_skill_tree()
		if good:
			bot.prepare(game)
			check(bot.error.is_empty(), "advanced bot purchases preserve placement/economy invariants")
		else:
			for cell in [Vector2i(4, 1), Vector2i(16, 1), Vector2i(28, 22)]:
				if game.tower_at_cell(cell) == null:
					game.purchase_tower(cell)
		longest = maxi(longest, game.board.find_path().size())
		game.start_wave()
		for frame in range(600 * 30):
			if game.phase != TDGame.Phase.WAVE_ACTIVE:
				break
			game.waves._process(DELTA)
			for node in game.board.active_enemies():
				if game.is_finished(): break
				(node as Enemy)._process(DELTA)
			for node in game.board.get_node("Towers").get_children():
				if game.is_finished(): break
				(node as Tower)._process(DELTA)
			for node in game.board.get_node("Projectiles").get_children():
				if game.is_finished(): break
				(node as CombatProjectile)._process(DELTA)
			if frame % 120 == 0: await process_frame
		check(game.phase != TDGame.Phase.WAVE_ACTIVE, "bot wave resolves without timeout/stuck actors")
		if game.phase == TDGame.Phase.BETWEEN_WAVES:
			cleared += 1
		await process_frame
		if game.is_finished(): break
	var spent := 0
	for id in game.progression.unlocked:
		spent += int(SkillCatalog.NODES[id].cost)
	check(game.progression.diamonds + spent == cleared, "natural diamond earnings exactly equal clears, including researched spending")
	check(game.currency >= 0, "bot never overspends run gold")
	var result := {"cleared": cleared, "wave": game.waves.current_wave, "lives": game.lives, "route": longest}
	print("Balance bot: seed=%d policy=%s cleared=%d wave=%d lives=%d route=%d" % [seed_value, STRATEGY if good else "poor", cleared, game.waves.current_wave, game.lives, longest])
	game.free()
	await process_frame
	return result


func _run() -> void:
	for seed_value in [721, 109, 1337, 9001, 2026]:
		var good: Dictionary = await session(seed_value, true)
		var poor: Dictionary = await session(seed_value, false)
		check(good.wave >= 8 and good.wave <= 12 and good.lives == 0 and good.route > 40, "fresh maze bot naturally loses around wave ten")
		check(poor.wave <= 5 and poor.lives == 0, "off-route fresh profile fails within five waves")
	print("Balance: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
