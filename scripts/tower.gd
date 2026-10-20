class_name Tower
extends Node2D

enum Upgrade { NONE, DAMAGE, RANGE, SPEED, SPECIAL }
enum Kind { BASIC, TESLA, MORTAR, ICE, CANNON }

var kind := Kind.BASIC:
	set(value):
		kind = value
		_stats_dirty = true
		queue_redraw()
var _stats_dirty := true
var _damage := 0
var _armor_damage := 0
var _shield_damage := 0
var _range := 0.0
var _interval := 0.0
var upgrades_enabled := false
var special_enabled := false
var _sixth_unlocked := false
var _area_unlocked := false
var _freeze_unlocked := false
var _distance_unlocked := false
var _permanent_damage_factor := 1.0
var _armor_factor := 1.0
var _shield_factor := 1.0
var _range_factor := 1.0
var _interval_factor := 1.0
var _levels: Array[int] = [0, 0, 0, 0, 0]
var upgrade_level: int:
	get: return _levels[1] + _levels[2] + _levels[3] + _levels[4]
var cell := Vector2i.ZERO
var _cooldown := 0.0
var _flash_remaining := 0.0
var _aim := -PI / 2.0
var _last_endpoint := Vector2.ZERO
var _pulse_number := 0
var _board: Board
var _rng := RandomNumberGenerator.new()


func _enter_tree() -> void:
	set_notify_local_transform(true)
	_board = get_parent().get_parent() as Board if get_parent() != null else null
	if _board != null: _board.tower_index.update(self)


func _notification(what: int) -> void:
	if what == NOTIFICATION_LOCAL_TRANSFORM_CHANGED and is_inside_tree() and is_instance_valid(_board):
		_board.tower_index.update(self)


func _exit_tree() -> void:
	if is_instance_valid(_board): _board.tower_index.remove(self)


func _nearby_enemies() -> Array:
	if _board == null:
		return get_tree().get_nodes_in_group("enemies")
	return _board.enemy_index.query_global(global_position, attack_range(), _board.get_node("Enemies"))


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# Local RNG never disturbs the run's wave generator. Cell/kind seed is replayable.
	_rng.seed = cell.x * 7349 + cell.y * 193 + kind * 32771 + 17


func data() -> Dictionary:
	return TowerCatalog.DATA[kind]


func levels(track: int) -> int:
	return _levels[track] if track >= Upgrade.DAMAGE and track <= Upgrade.SPECIAL else 0


func max_upgrades() -> int:
	return 6 if _sixth_unlocked else 5


func configure_progression(profile: Progression) -> void:
	_permanent_damage_factor = 1.0 + (0.1 if profile.has_skill("engineering") else 0.0) + (0.15 if profile.has_skill("engineering_ii") else 0.0) + (0.25 if profile.has_skill("engineering_iii") else 0.0)
	_armor_factor = 1.0 + (0.25 if profile.has_skill("armor_breaker") else 0.0) + (0.4 if profile.has_skill("armor_breaker_ii") else 0.0)
	_shield_factor = 1.0 + (0.25 if profile.has_skill("overcharge") else 0.0) + (0.4 if profile.has_skill("overcharge_ii") else 0.0)
	_range_factor = 1.0 + (0.08 if profile.has_skill("optics") else 0.0) + (0.12 if profile.has_skill("optics_ii") else 0.0)
	_interval_factor = (0.92 if profile.has_skill("rapid_fire") else 1.0) * (0.88 if profile.has_skill("rapid_fire_ii") else 1.0)
	upgrades_enabled = profile.has_skill(data().training)
	special_enabled = profile.has_skill(data().special)
	_sixth_unlocked = profile.has_skill(data().mastery)
	_area_unlocked = profile.has_skill("mortar_area")
	_freeze_unlocked = profile.has_skill("ice_freeze")
	_distance_unlocked = profile.has_skill("cannon_distance")
	_stats_dirty = true
	_cooldown = minf(_cooldown, attack_interval())
	queue_redraw()


func build_cost() -> int:
	return int(data().cost)


func refund() -> int:
	return floori(build_cost() * 0.5)


func _refresh_stats() -> void:
	if not _stats_dirty:
		return
	_stats_dirty = false
	var stats := data()
	_damage = roundi((int(stats.damage) + int(stats.damage_step) * levels(Upgrade.DAMAGE) + int(stats.special_damage) * levels(Upgrade.SPECIAL)) * _permanent_damage_factor)
	var bonus := 15 * levels(Upgrade.SPECIAL) if kind == Kind.BASIC else 0
	_armor_damage = maxi(1, roundi((_damage * float(stats.armor_ratio) + bonus) * _armor_factor))
	_shield_damage = maxi(1, roundi(_damage * float(stats.shield_ratio) * _shield_factor))
	_range = (float(stats.range) + float(stats.range_step) * levels(Upgrade.RANGE)) * _range_factor
	_interval = float(stats.interval) * pow(GameConfig.SPEED_FACTOR_PER_LEVEL, levels(Upgrade.SPEED)) * _interval_factor


func damage() -> int:
	_refresh_stats()
	return _damage


func armor_damage() -> int:
	_refresh_stats()
	return _armor_damage


func shield_damage() -> int:
	_refresh_stats()
	return _shield_damage


func attack_range() -> float:
	_refresh_stats()
	return _range


func attack_interval() -> float:
	_refresh_stats()
	return _interval


func blast_radius() -> float:
	return 64.0 * (1.25 if _area_unlocked else 1.0) + 8.0 * levels(Upgrade.SPECIAL)


func freeze_chance() -> float:
	return 0.08 + 0.03 * levels(Upgrade.SPECIAL) if _freeze_unlocked else 0.0


func cannon_distance() -> float:
	return 320.0 * (1.5 if _distance_unlocked else 1.0) + 36.0 * levels(Upgrade.SPECIAL)


func upgrade_description(track: int) -> String:
	match track:
		Upgrade.DAMAGE: return "+%d base health damage; armor/shield damage also scales." % int(data().damage_step)
		Upgrade.RANGE: return "+%.0f base targeting range." % float(data().range_step)
		Upgrade.SPEED: return "18% shorter firing interval; stacks multiplicatively."
		Upgrade.SPECIAL:
			return ["+8 base health damage and +15 concentrated armor damage.", "+4 base damage and a stronger 0.8-second slow.", "+10 base damage and +8 pixels of blast radius.", "+2 base damage, +3 percentage points of freeze chance, +0.08 seconds of freeze.", "+6 base damage and +36 pixels of cannonball travel."][kind]
	return ""


func attack_description() -> String:
	match kind:
		Kind.BASIC: return "Aimed shots at the nearest enemy."
		Kind.TESLA: return "Circular lightning hits every enemy in range once per discharge."
		Kind.MORTAR: return "Arcing shells land at a fixed point. Blast radius: %.0f pixels." % blast_radius()
		Kind.ICE: return "Homing icicles slow 35%% for 2 seconds. Freeze chance: %.0f%%." % (freeze_chance() * 100)
		Kind.CANNON: return "Pierces enemies for %.0f pixels of travel. Any friendly tower blocks the ball." % cannon_distance()
	return ""


func next_upgrade_cost() -> int:
	return 0 if upgrade_level >= max_upgrades() else int(data().prices[upgrade_level])


func upgrade_error(track: int) -> String:
	if not upgrades_enabled:
		return "Unlock this tower's training in the skill tree first"
	if track < Upgrade.DAMAGE or track > Upgrade.SPECIAL:
		return "Choose an available upgrade"
	if track == Upgrade.SPECIAL and not special_enabled:
		return "Unlock this unique upgrade in the skill tree first"
	if upgrade_level >= max_upgrades():
		return "Research this tower's sixth upgrade slot" if max_upgrades() == 5 else "All six upgrade slots are filled"
	return ""


func apply_upgrade(track: int) -> bool:
	if not upgrade_error(track).is_empty():
		return false
	_levels[track] += 1
	# Any category can share the budget. No purchase grants an immediate free shot.
	_stats_dirty = true
	_cooldown = minf(_cooldown, attack_interval())
	queue_redraw()
	return true


func _process(delta: float) -> void:
	if _flash_remaining > 0.0:
		_flash_remaining = maxf(0.0, _flash_remaining - delta)
		queue_redraw()
	_cooldown = maxf(0.0, _cooldown - delta)
	if _cooldown > 0.0:
		return
	if kind == Kind.TESLA:
		attack_area()
	else:
		var target := _nearest_target()
		if target != null:
			attack(target)
	_cooldown = attack_interval()


func _nearest_target() -> Enemy:
	var nearest: Enemy = null
	var nearest_distance := attack_range() * attack_range()
	for candidate in _nearby_enemies():
		var enemy := candidate as Enemy
		if enemy == null or not enemy.is_alive():
			continue
		var distance := global_position.distance_squared_to(enemy.global_position)
		if distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func attack(target: Enemy) -> void:
	if not is_instance_valid(target) or not target.is_alive() or global_position.distance_to(target.global_position) > attack_range():
		return
	_last_endpoint = to_local(target.global_position)
	_aim = _last_endpoint.angle()
	_flash_remaining = 0.28 if kind == Kind.TESLA else 0.18
	if kind == Kind.MORTAR or kind == Kind.ICE or kind == Kind.CANNON:
		_launch(target)
	else:
		target.take_damage(damage(), armor_damage(), shield_damage())
		if kind == Kind.TESLA and levels(Upgrade.SPECIAL) > 0 and target.is_alive():
			target.apply_slow(maxf(0.5, 0.85 - 0.05 * levels(Upgrade.SPECIAL)), 0.8)
	queue_redraw()


func attack_area() -> void:
	var hit := false
	for candidate in _nearby_enemies():
		var enemy := candidate as Enemy
		if enemy != null and enemy.is_alive() and global_position.distance_to(enemy.global_position) <= attack_range():
			attack(enemy)
			hit = true
	if hit:
		_pulse_number += 1


func _launch(target_enemy: Enemy) -> void:
	var board := get_parent().get_parent() as Board
	if board == null:
		return
	var projectile := CombatProjectile.new()
	projectile.kind = [CombatProjectile.Kind.MORTAR, CombatProjectile.Kind.ICE, CombatProjectile.Kind.CANNON][kind - Kind.MORTAR]
	projectile.board = board
	projectile.source_id = get_instance_id()
	projectile.origin = position
	projectile.destination = target_enemy.position
	projectile.position = position
	projectile.direction = (target_enemy.position - position).normalized()
	projectile.health_damage = damage()
	projectile.armor_damage = armor_damage()
	projectile.shield_damage = shield_damage()
	projectile.target = weakref(target_enemy)
	projectile.splash_radius = blast_radius()
	projectile.flight_duration = clampf(position.distance_to(target_enemy.position) / 220.0, 0.45, 1.5)
	projectile.speed = 340.0 if kind == Kind.ICE else 300.0
	projectile.travel_limit = cannon_distance()
	projectile.freeze_on_hit = _rng.randf() < freeze_chance() if kind == Kind.ICE else false
	projectile.freeze_duration = 0.5 + 0.08 * levels(Upgrade.SPECIAL)
	board.get_node("Projectiles").add_child(projectile)


func _draw() -> void:
	CombatArt.tower(self, kind, _aim, clampf(_flash_remaining / 0.18, 0, 1))
	if upgrade_level > 0:
		var colors := [Color.TRANSPARENT, Color("efb876"), Color("aada91"), Color("c3a0ef"), Color("8bddeb")]
		var slot := 0
		for track in range(1, 5):
			for level in range(levels(track)):
				draw_circle(Vector2(-10 + slot * 4, 12), 2.4, DrawKit.INK)
				draw_circle(Vector2(-10 + slot * 4, 12), 1.4, colors[track])
				slot += 1
	if _flash_remaining <= 0:
		return
	if kind == Kind.TESLA:
		var progress := 1.0 - _flash_remaining / 0.28
		DrawKit.bolt_ring(self, attack_range() * (0.8 + 0.2 * progress), _pulse_number * 3.7, 1.0 - progress)
	elif kind == Kind.BASIC:
		var muzzle := Vector2.from_angle(_aim) * 15.0 + Vector2(0, -2)
		var f := Vector2.from_angle(_aim)
		var side := f.orthogonal()
		var alpha := _flash_remaining / 0.18
		draw_line(muzzle, _last_endpoint, Color(1, 0.8, 0.45, alpha * 0.6), 1.2, true)
		DrawKit.poly(self, PackedVector2Array([muzzle - side * 3, muzzle + f * 6 - side * 6, muzzle + f * 13, muzzle + f * 6 + side * 6, muzzle + side * 3]), Color(1, 0.86, 0.55, alpha), Color(1, 0.75, 0.35, alpha), 1)
	elif kind == Kind.MORTAR or kind == Kind.CANNON:
		draw_circle(Vector2.from_angle(_aim) * 12, 4 * _flash_remaining / 0.18, Color("ffd099"))
