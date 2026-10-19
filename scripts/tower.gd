class_name Tower
extends Node2D

enum Upgrade { NONE, DAMAGE, RANGE, SPEED, SPECIAL }
enum Kind { BASIC, TESLA }

var kind := Kind.BASIC
var upgrades_enabled := false
var special_enabled := false
var _permanent_damage_factor := 1.0
var _armor_factor := 1.0
var _shield_factor := 1.0
var _range_factor := 1.0
var _interval_factor := 1.0

var cell := Vector2i.ZERO
var upgrade_type := Upgrade.NONE
var upgrade_level := 0
var _cooldown := 0.0
var _flash_remaining := 0.0
var _shot_endpoints: Array[Vector2] = []


func configure_progression(profile: Progression) -> void:
	_permanent_damage_factor = 1.0 + (0.1 if profile.has_skill("engineering") else 0.0) + (0.15 if profile.has_skill("engineering_ii") else 0.0) + (0.25 if profile.has_skill("engineering_iii") else 0.0)
	_armor_factor = 1.0 + (0.25 if profile.has_skill("armor_breaker") else 0.0) + (0.4 if profile.has_skill("armor_breaker_ii") else 0.0)
	_shield_factor = 1.0 + (0.25 if profile.has_skill("overcharge") else 0.0) + (0.4 if profile.has_skill("overcharge_ii") else 0.0)
	_range_factor = 1.0 + (0.08 if profile.has_skill("optics") else 0.0) + (0.12 if profile.has_skill("optics_ii") else 0.0)
	_interval_factor = (0.92 if profile.has_skill("rapid_fire") else 1.0) * (0.88 if profile.has_skill("rapid_fire_ii") else 1.0)
	upgrades_enabled = profile.has_skill("tesla_training" if kind == Kind.TESLA else "basic_training")
	special_enabled = profile.has_skill("static_field" if kind == Kind.TESLA else "piercing")


func build_cost() -> int:
	return GameConfig.TESLA_COST if kind == Kind.TESLA else GameConfig.TOWER_COST


func refund() -> int:
	return floori(build_cost() * 0.5)


func damage() -> int:
	var base := GameConfig.TESLA_DAMAGE if kind == Kind.TESLA else GameConfig.TOWER_DAMAGE
	if upgrade_type == Upgrade.DAMAGE:
		base += (9 if kind == Kind.TESLA else GameConfig.DAMAGE_PER_LEVEL) * upgrade_level
	elif upgrade_type == Upgrade.SPECIAL:
		base += (4 if kind == Kind.TESLA else 8) * upgrade_level
	return roundi(base * _permanent_damage_factor)


func armor_damage() -> int:
	var ratio := 0.5 if kind == Kind.TESLA else 1.6
	var bonus := 15 * upgrade_level if kind == Kind.BASIC and upgrade_type == Upgrade.SPECIAL else 0
	return maxi(1, roundi((damage() * ratio + bonus) * _armor_factor))


func shield_damage() -> int:
	var ratio := 2.0 if kind == Kind.TESLA else 0.55
	return maxi(1, roundi(damage() * ratio * _shield_factor))


func attack_range() -> float:
	var base := GameConfig.TESLA_RANGE if kind == Kind.TESLA else GameConfig.TOWER_RANGE
	return (base + ((12.0 if kind == Kind.TESLA else GameConfig.RANGE_PER_LEVEL) * upgrade_level if upgrade_type == Upgrade.RANGE else 0.0)) * _range_factor


func attack_interval() -> float:
	var base := GameConfig.TESLA_COOLDOWN if kind == Kind.TESLA else GameConfig.TOWER_COOLDOWN
	return base * (pow(GameConfig.SPEED_FACTOR_PER_LEVEL, upgrade_level) if upgrade_type == Upgrade.SPEED else 1.0) * _interval_factor


func next_upgrade_cost() -> int:
	if upgrade_level >= GameConfig.MAX_UPGRADE_LEVEL:
		return 0
	var prices := GameConfig.TESLA_UPGRADE_COSTS if kind == Kind.TESLA else GameConfig.UPGRADE_COSTS
	return prices[upgrade_level]


func upgrade_error(track: int) -> String:
	if not upgrades_enabled:
		return "Unlock this tower's training in the skill tree first"
	if track < Upgrade.DAMAGE or track > Upgrade.SPECIAL:
		return "Choose an available upgrade track"
	if track == Upgrade.SPECIAL and not special_enabled:
		return "Unlock this unique upgrade in the skill tree first"
	if upgrade_type != Upgrade.NONE and upgrade_type != track:
		return "This tower is locked to %s upgrades" % Upgrade.keys()[upgrade_type].to_lower()
	if upgrade_level >= GameConfig.MAX_UPGRADE_LEVEL:
		return "Tower is fully upgraded"
	return ""


func apply_upgrade(track: int) -> bool:
	if not upgrade_error(track).is_empty():
		return false
	upgrade_type = track as Upgrade
	upgrade_level += 1
	# Speed upgrades may shorten a wait but cannot reset it to grant a free shot.
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
	# At most one group scan per shot interval, including while idle.
	if kind == Kind.TESLA:
		attack_area()
	else:
		var target := _nearest_target()
		if target != null:
			_shot_endpoints.clear()
			attack(target)
	_cooldown = attack_interval()


func _nearest_target() -> Enemy:
	var nearest: Enemy = null
	var nearest_distance := attack_range() * attack_range()
	for candidate in get_tree().get_nodes_in_group("enemies"):
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
	_shot_endpoints.append(to_local(target.global_position))
	_flash_remaining = GameConfig.SHOT_FLASH_DURATION
	target.take_damage(damage(), armor_damage(), shield_damage())
	if kind == Kind.TESLA and upgrade_type == Upgrade.SPECIAL and target.is_alive():
		target.apply_slow(0.85 - 0.05 * upgrade_level, 0.8)
	queue_redraw()


func attack_area() -> void:
	_shot_endpoints.clear()
	# Snapshot the group once per pulse; every living target in range is hit once.
	for candidate in get_tree().get_nodes_in_group("enemies"):
		var enemy := candidate as Enemy
		if enemy != null and enemy.is_alive() and global_position.distance_to(enemy.global_position) <= attack_range():
			attack(enemy)


func _draw() -> void:
	draw_rect(Rect2(-13, -13, 26, 26), Color("17688e"))
	draw_rect(Rect2(-13, -13, 26, 26), Color("65d8f5"), false, 2.0)
	draw_circle(Vector2.ZERO, 7, Color("8beaff"))
	if kind == Kind.TESLA:
		draw_circle(Vector2.ZERO, 11, Color("7d58b4"))
		draw_arc(Vector2.ZERO, 9, 0, TAU, 16, Color("c5e8ff"), 2)
		draw_line(Vector2(-4, -8), Vector2(3, 1), Color.WHITE, 2)
		draw_line(Vector2(3, 1), Vector2(-3, 8), Color.WHITE, 2)
	if upgrade_level > 0:
		var color := Color("ffb56b")
		if upgrade_type == Upgrade.RANGE:
			color = Color("b5f57c")
		elif upgrade_type == Upgrade.SPEED:
			color = Color("dc9aff")
		for i in range(upgrade_level):
			draw_circle(Vector2(-10 + 5 * i, 10), 2, color)
	if _flash_remaining > 0.0:
		for endpoint in _shot_endpoints:
			if kind == Kind.TESLA:
				var bend := endpoint * 0.5 + endpoint.orthogonal().normalized() * 7.0
				draw_polyline(PackedVector2Array([Vector2.ZERO, bend, endpoint]), Color("b4eaff"), 3.0, true)
			else:
				draw_line(Vector2.ZERO, endpoint, Color("f5f6a6"), 3.0, true)
		draw_circle(Vector2.ZERO, 10, Color(1.0, 1.0, 0.7, 0.65))
