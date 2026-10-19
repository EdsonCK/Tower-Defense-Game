class_name WaveGenerator
extends RefCounted
## Builds endless waves. Each wave is derived only from (run seed, wave number), so a
## wave can be previewed before it starts and is reproducible for a given seed, while
## different runs (different seeds) get slightly different waves.
##
## A wave is an Array of spawn entries:
##   {"type": String, "health": float, "reward": int, "lives": int, "interval": float}
## where "interval" is the delay before the next spawn.

var run_seed: int


func _init(seed_value: int) -> void:
	run_seed = seed_value


## Multiplier applied to base enemy health on `wave` (1.0 on wave 1).
static func health_scale(wave: int) -> float:
	var w: float = float(maxi(wave, 1) - 1)
	return (1.0 + GameConfig.HEALTH_SCALE_LINEAR * w) * pow(GameConfig.HEALTH_SCALE_GROWTH, w)


## Multiplier applied to base kill rewards on `wave`.
static func reward_scale(wave: int) -> float:
	return 1.0 + 0.03 * float(maxi(wave, 1) - 1)


static func wave_clear_bonus(wave: int) -> int:
	return GameConfig.WAVE_CLEAR_BONUS_BASE + GameConfig.WAVE_CLEAR_BONUS_PER_WAVE * (maxi(wave, 1) - 1)


## Expected enemy count before random variation and boss-wave escort reduction.
static func base_enemy_count(wave: int) -> float:
	var count: float = GameConfig.WAVE_BASE_ENEMY_COUNT + GameConfig.WAVE_ENEMY_COUNT_PER_WAVE * wave
	if wave > GameConfig.LATE_WAVE_START:
		var late: float = float(wave - GameConfig.LATE_WAVE_START)
		count += GameConfig.LATE_WAVE_EXTRA * late * late
	return count


## Multiplier on spawn intervals: spawns get steadily faster as waves progress.
static func interval_scale(wave: int) -> float:
	return maxf(GameConfig.MIN_INTERVAL_SCALE, 1.0 / (1.0 + GameConfig.SPAWN_RATE_GROWTH * float(maxi(wave, 1) - 1)))


static func is_boss_wave(wave: int) -> bool:
	return wave > 0 and wave % GameConfig.BOSS_WAVE_INTERVAL == 0


static func boss_count(wave: int) -> int:
	if not is_boss_wave(wave):
		return 0
	return mini(floori(float(wave) / GameConfig.BOSS_WAVE_INTERVAL), GameConfig.MAX_BOSSES_PER_WAVE)


## Builds a spawn entry for `type_id` scaled to `wave`. `health_jitter` multiplies every
## pool (health, armor, shield); `interval_mult` scales the delay before the next spawn.
static func make_entry(type_id: String, wave: int, health_jitter: float = 1.0, interval_mult: float = 1.0) -> Dictionary:
	var def: Dictionary = EnemyTypes.get_def(type_id)
	return {
		"type": type_id,
		"health": maxf(1.0, def["health"] * health_scale(wave) * health_jitter),
		"armor": maxf(0.0, def["armor"] * health_scale(wave) * health_jitter),
		"shield": maxf(0.0, def["shield"] * health_scale(wave) * health_jitter),
		"reward": maxi(1, roundi(def["reward"] * reward_scale(wave))),
		"lives": int(def["lives"]),
		"interval": maxf(0.08, def["interval"] * interval_mult),
	}


func generate(wave: int) -> Array[Dictionary]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([run_seed, wave])
	var bosses: int = boss_count(wave)
	var target: float = base_enemy_count(wave) * rng.randf_range(0.9, 1.1)
	if bosses > 0:
		target *= GameConfig.BOSS_WAVE_ESCORT_FACTOR  # bosses soak fire, so bring a smaller escort
	var count: int = clampi(roundi(target), 1, GameConfig.MAX_ENEMIES_PER_WAVE - bosses)
	var density: float = interval_scale(wave)
	var pool: Array[String] = EnemyTypes.random_pool(wave)

	var entries: Array[Dictionary] = []
	while entries.size() < count:
		var type_id: String = _pick_type(rng, pool)
		var pack: Array = EnemyTypes.get_def(type_id)["pack"]
		var pack_size: int = mini(rng.randi_range(pack[0], pack[1]), count - entries.size())
		for i in pack_size:
			entries.append(make_entry(type_id, wave, rng.randf_range(0.92, 1.08), density * rng.randf_range(0.85, 1.15)))
	for i in bosses:
		entries.append(make_entry(EnemyTypes.BOSS, wave, rng.randf_range(0.95, 1.05), 1.0))
	return entries


## Counts per type id, for the HUD's next-wave preview.
func summarize(wave: int) -> Dictionary:
	var counts: Dictionary = {}
	for entry: Dictionary in generate(wave):
		counts[entry["type"]] = counts.get(entry["type"], 0) + 1
	return counts


func _pick_type(rng: RandomNumberGenerator, pool: Array[String]) -> String:
	var total: float = 0.0
	for type_id: String in pool:
		total += EnemyTypes.get_def(type_id)["weight"]
	var roll: float = rng.randf() * total
	for type_id: String in pool:
		roll -= EnemyTypes.get_def(type_id)["weight"]
		if roll <= 0.0:
			return type_id
	return pool[pool.size() - 1]
