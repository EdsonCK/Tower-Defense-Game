extends "res://tests/test_base.gd"
## Sound, music, animation and effects: game events trigger the right sounds, music
## follows boss waves, audio settings toggle and persist, towers aim and animate,
## enemies flash and leave death bursts, and every procedural icon draws.
##   godot --headless --path <project> --script res://tests/test_presentation.gd


func get_tests() -> Array[Callable]:
	return [
		test_audio_files_exist_and_load,
		test_game_events_play_sounds,
		test_boss_wave_switches_music,
		test_sound_throttle_and_mute,
		test_audio_settings_persist,
		test_towers_aim_and_animate,
		test_enemy_hit_flash_and_death_burst,
		test_every_icon_draws,
	]


func _audio() -> GameAudio:
	return GameAudio.instance


func _count(sound_name: String) -> int:
	return int(_audio().play_counts.get(sound_name, 0))


func _wait(frames: int) -> void:
	for i in frames:
		await process_frame


func test_audio_files_exist_and_load() -> void:
	var missing: Array[String] = []
	for sound_name: String in GameAudio.SFX:
		if not (load("res://audio/%s.wav" % sound_name) is AudioStreamWAV):
			missing.append(sound_name)
	for track: String in GameAudio.MUSIC:
		var music: AudioStreamWAV = load(GameAudio.MUSIC[track]) as AudioStreamWAV
		if music == null or music.get_length() < 10.0:
			missing.append(track)
	_check(missing.is_empty(), "%d sound effects and %d music loops are present and load%s" % [GameAudio.SFX.size(), GameAudio.MUSIC.size(), "" if missing.is_empty() else " - missing " + str(missing)])
	var main: Node2D = _make_main()
	_check(_audio() != null and _audio().get_parent() == main, "Main owns the audio player")


func test_game_events_play_sounds() -> void:
	var main: Node2D = _make_main()
	_unlock_tower_skills(main)
	main.currency = 100000
	await _wait(2)
	var before: Dictionary = _audio().play_counts.duplicate()
	var changed: Callable = func(sound_name: String) -> bool:
		return _count(sound_name) > int(before.get(sound_name, 0))
	var spot: Vector2i = _spot(main, 0)
	main.try_buy_tower(spot, TowerTypes.BASIC)
	_check(changed.call("build"), "building a tower plays the build sound")
	await _wait(2)
	main.try_upgrade_tower(main.get_tower_at(spot), Tower.UpgradePath.DAMAGE)
	_check(changed.call("upgrade"), "upgrading plays the upgrade sound")
	await _wait(2)
	main.try_buy_tower(_spot(main, 0), TowerTypes.BASIC)
	_check(changed.call("error"), "an invalid action plays the error sound")
	main._on_start_wave_pressed()
	_check(changed.call("wave_start"), "starting a wave plays the horn")
	var guard: int = 0
	while main.wave_manager.is_wave_active() and guard < 4000:
		_simulate(main, 0.05, 1)
		_free_resolved(main)
		guard += 1
		if guard % 10 == 0:
			await process_frame  # lets the audio clock advance past throttles
	_check(changed.call("shot_basic"), "towers play their shot sound when they fire")
	_check(changed.call("enemy_die"), "kills play the pop")
	_check(changed.call("wave_clear"), "a cleared wave plays the chime")
	await _wait(2)
	main.try_sell_tower(spot)
	_check(changed.call("sell"), "selling plays the coin sound")
	var lives_before: int = main.lives
	var runner: Enemy = _spawn_enemy(main.board, 1.0, EnemyTypes.GRUNT)
	main._on_enemy_escaped(runner)
	runner.discard()
	_check(changed.call("escape") and main.lives < lives_before, "an escape plays the warning")


func test_boss_wave_switches_music() -> void:
	var main: Node2D = _make_main()
	_check(GameAudio.current_music() == "main", "the calm theme plays during a run")
	main.wave_manager.current_wave = GameConfig.BOSS_WAVE_INTERVAL - 1
	var spawn_before: int = _count("boss_spawn")
	main._on_start_wave_pressed()
	_check(GameAudio.current_music() == "boss" and _count("boss_spawn") > spawn_before, "a boss wave sounds the gong and switches to the boss theme")
	_kill_all_active(main)
	var guard: int = 0
	while main.wave_manager.is_wave_active() and guard < 400:
		_simulate(main, 0.05, 1)
		_kill_all_active(main)
		_free_resolved(main)
		guard += 1
	_check(GameAudio.current_music() == "main", "the calm theme returns once the boss wave is cleared")
	main._end_game("test")
	_check(GameAudio.current_music() == "" and _count("defeat") > 0, "defeat stops the music and plays the defeat motif")
	main.restart_game(5)
	_check(GameAudio.current_music() == "main", "restart brings the music back")


func test_sound_throttle_and_mute() -> void:
	_make_main()
	await _wait(2)
	var played: int = 0
	for i in 50:
		if GameAudio.play("shot_basic"):
			played += 1
	_check(played == 1, "50 shots in one frame play once (%d) - no noise wall from big defenses" % played)
	await _wait(10)
	_check(GameAudio.play("shot_basic"), "and the sound plays again a moment later")
	_audio().set_sfx_enabled(false)
	await _wait(10)
	_check(not GameAudio.play("build"), "muted sound effects don't play")
	_audio().set_sfx_enabled(true)
	_audio().set_music_enabled(false)
	_check(not _audio().music_enabled, "music can be switched off separately")
	_audio().set_music_enabled(true)
	var hud: Hud = (_audio().get_parent() as Node).get("hud")
	var music_toggle: Button = hud.get_node("%MusicToggle")
	music_toggle.button_pressed = false
	_check(not _audio().music_enabled, "the HUD Music button switches music off")
	music_toggle.button_pressed = true
	var sound_toggle: Button = hud.get_node("%SoundToggle")
	sound_toggle.button_pressed = false
	_check(not _audio().sfx_enabled, "the HUD Sound button switches effects off")
	sound_toggle.button_pressed = true


func test_audio_settings_persist() -> void:
	var path: String = "user://test_progress_audio_%d.json" % Time.get_ticks_usec()
	ProgressStore.save_path = path
	var main: Node2D = _make_main()
	_audio().set_music_enabled(false)
	_audio().set_sfx_enabled(true)
	root.remove_child(main)
	main.free()
	var again: Node2D = _make_main()
	var ok: bool = not _audio().music_enabled and _audio().sfx_enabled
	var hud_ok: bool = not (again.hud.get_node("%MusicToggle") as Button).button_pressed
	_audio().set_music_enabled(true)
	ProgressStore.save_path = ""
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path.get_basename() + "_settings.json"))
	_check(ok and hud_ok, "audio settings are saved and restored on the next launch")


func test_towers_aim_and_animate() -> void:
	var main: Node2D = _make_main()
	_unlock_tower_skills(main)
	main.skills.unlock("cannon")
	main.currency = 100000
	var board: Board = main.board
	var spot: Vector2i = _spot(main, 0)
	main.try_buy_tower(spot, TowerTypes.CANNON)
	var cannon: Tower = main.get_tower_at(spot)
	var path_cell: Vector2i = Board.NO_CELL
	for cell: Vector2i in board.layout.parent:
		if board.in_window(cell) and Board.cell_to_world(cell).distance_to(cannon.position) <= cannon.attack_range * 0.8 and cell != board.exit_cell():
			path_cell = cell
			break
	var enemy: Enemy = _spawn_enemy(board, 100000.0, EnemyTypes.GRUNT, path_cell)
	var aim_before: float = cannon._aim
	cannon.step(0.5)
	var wanted: float = (enemy.position - cannon.position).angle()
	_check(absf(angle_difference(cannon._aim, wanted)) < 0.05, "a cannon turns to face the enemy it shoots (%.2f -> %.2f, target %.2f)" % [aim_before, cannon._aim, wanted])
	_check(cannon._since_shot < 0.1, "firing starts the recoil/shell animation")
	for i in 10:
		cannon.step(0.05)
	_check(cannon._since_shot >= 0.4, "the shot animation plays out and stops")
	main.try_buy_tower(_spot(main, 1), TowerTypes.TESLA)
	var tesla: Tower = main.get_tower_at(_spot(main, 1))
	tesla._cooldown_left = tesla.cooldown
	var drained: float = tesla._charge()
	tesla._cooldown_left = 0.0
	_check(drained == 0.0 and tesla._charge() == 1.0, "the Tesla coil's glow tracks its recharge")
	enemy.discard()


func test_enemy_hit_flash_and_death_burst() -> void:
	var main: Node2D = _make_main()
	var board: Board = main.board
	var enemy: Enemy = _spawn_enemy(board, 30.0)
	enemy.take_damage(5.0)
	_check(enemy._hit_flash > 0.0, "a hit makes the enemy flash")
	var fx_before: int = 0
	for child: Node in board.get_children():
		if child is DeathFx:
			fx_before += 1
	var enemies_before: int = board.enemies.get_child_count()
	enemy.take_damage(100.0)
	var fx_after: int = 0
	for child: Node in board.get_children():
		if child is DeathFx:
			fx_after += 1
	_check(fx_after == fx_before + 1, "a kill leaves a death burst on the board")
	_check(board.enemies.get_child_count() == enemies_before, "the burst is not counted among the enemies")
	await create_timer(0.7).timeout
	var left: int = 0
	for child: Node in board.get_children():
		if child is DeathFx:
			left += 1
	_check(left == 0, "the burst frees itself after a moment")
	var facing: Array[float] = []
	var walker: Enemy = _spawn_enemy(board, 1000.0)
	for i in 40:
		walker.step(0.1)
		facing.append(walker._facing)
	var turned: bool = false
	for f: float in facing:
		if absf(angle_difference(f, facing[0])) > 1.0:
			turned = true
	_check(turned, "walking enemies turn to face along the winding path")
	walker.discard()


func test_every_icon_draws() -> void:
	var canvas: Control = Control.new()
	root.add_child(canvas)
	var drawn: Array[String] = []
	canvas.draw.connect(func() -> void:
		for kind: String in Icons.KINDS:
			Icons.draw(canvas, kind, Vector2(20, 20), 12.0, Color.WHITE)
			drawn.append(kind))
	canvas.queue_redraw()
	await _wait(2)
	_check(drawn.size() == Icons.KINDS.size(), "all %d procedural icons draw without errors" % Icons.KINDS.size())
	var missing: Array[String] = []
	for icon: String in SkillTreeMenu.SKILL_ICONS.values():
		if icon not in Icons.KINDS:
			missing.append(icon)
	for id: String in SkillTree.SKILLS:
		if not SkillTreeMenu.SKILL_ICONS.has(id):
			missing.append(id)
	_check(missing.is_empty(), "every skill has a known icon%s" % ("" if missing.is_empty() else " - " + str(missing)))
	canvas.queue_free()
