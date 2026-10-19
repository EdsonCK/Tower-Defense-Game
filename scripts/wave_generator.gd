class_name WaveGenerator
extends RefCounted
## Seeded, bounded generation. No ever-growing history or global random state.

var run_seed: int
var _rng := RandomNumberGenerator.new()


func _init(seed_value: int = 0) -> void:
	if seed_value == 0:
		_rng.randomize()
	else:
		_rng.seed = seed_value
	run_seed = _rng.seed


func generate(wave: int) -> Array[EnemyProfile]:
	assert(wave > 0)
	# Clamp before multiplication so even extremely late wave indices stay safe.
	var difficulty := mini(wave - 1, 100000)
	var count := clampi(8 + mini(difficulty, 28) * 2 + _rng.randi_range(-1, 1), 8, 64)
	if wave > 30:
		count = late_wave_count(wave)
	var unlocked := 2
	if wave >= 2:
		unlocked = 3
	if wave >= 3:
		unlocked = 4
	if wave >= 5:
		unlocked = 5
	var result: Array[EnemyProfile] = []
	for i in range(count):
		var kind := EnemyProfile.Kind.GRUNT
		if i == 1:
			kind = _rng.randi_range(1, unlocked - 1) as EnemyProfile.Kind
		elif i > 1 and _rng.randf() < 0.55:
			kind = _rng.randi_range(0, unlocked - 1) as EnemyProfile.Kind
		var profile := EnemyProfile.base(kind)
		# Early waves teach placement; later HP follows investment in tower levels.
		var late := maxf(0.0, difficulty - 4.0)
		var veteran := maxf(0.0, difficulty + 1.0 - GameConfig.VETERAN_START_WAVE)
		var pressure := 1.0 + GameConfig.VETERAN_HEALTH_PER_WAVE * veteran
		var apprenticeship := minf(GameConfig.APPRENTICE_PRESSURE_LIMIT, 1.0 + GameConfig.APPRENTICE_PRESSURE_PER_WAVE * maxf(0, difficulty + 1 - GameConfig.APPRENTICE_START_WAVE))
		var scale := (1.0 + 0.08 * difficulty + 0.012 * late * late) * pressure * apprenticeship * _rng.randf_range(0.95, 1.05)
		if kind == EnemyProfile.Kind.ARMORED:
			var plating := 1.0 + 0.10 * mini(12, floori(difficulty / 6.0) + floori(veteran / GameConfig.VETERAN_ARMOR_INTERVAL))
			profile.armor = clampi(roundi(profile.armor * plating * scale), 1, GameConfig.MAX_ENEMY_HEALTH)
		profile.hit_points = clampi(roundi(profile.hit_points * scale), 1, GameConfig.MAX_ENEMY_HEALTH)
		profile.speed *= _rng.randf_range(0.97, 1.03)
		profile.shield = mini(roundi(profile.shield * scale), GameConfig.MAX_ENEMY_HEALTH)
		result.append(profile)
	# Shuffle with this run's RNG, keeping replay independent of unrelated code.
	for i in range(result.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var swap := result[i]
		result[i] = result[j]
		result[j] = swap
	return result


static func late_wave_count(wave: int) -> int:
	var late := mini(maxi(wave - 30, 0), 100000)
	return mini(GameConfig.MAX_WAVE_ENEMIES, 64 + 4 * late + floori(0.02 * late * late))


func interval_for(wave: int) -> float:
	if wave > 30:
		# Count grows faster than cadence: spawn windows lengthen as density rises.
		# Both plateau together at the node budget, rather than shortening forever.
		return maxf(GameConfig.MIN_SPAWN_INTERVAL, 0.678 * pow(late_wave_count(wave) / 64.0, -0.45))
	var base := GameConfig.SPAWN_INTERVAL - 0.018 * mini(wave - 1, 50)
	return maxf(0.45, base * _rng.randf_range(0.96, 1.04))
