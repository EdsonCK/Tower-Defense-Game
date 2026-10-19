class_name Tower
extends Node2D

enum Upgrade { NONE, DAMAGE, RANGE, SPEED }

var cell := Vector2i.ZERO
var upgrade_type := Upgrade.NONE
var upgrade_level := 0
var _cooldown := 0.0
var _flash_remaining := 0.0
var _shot_endpoint := Vector2.ZERO


func damage() -> int:
	return GameConfig.TOWER_DAMAGE + (GameConfig.DAMAGE_PER_LEVEL * upgrade_level if upgrade_type == Upgrade.DAMAGE else 0)


func attack_range() -> float:
	return GameConfig.TOWER_RANGE + (GameConfig.RANGE_PER_LEVEL * upgrade_level if upgrade_type == Upgrade.RANGE else 0.0)


func attack_interval() -> float:
	return GameConfig.TOWER_COOLDOWN * (pow(GameConfig.SPEED_FACTOR_PER_LEVEL, upgrade_level) if upgrade_type == Upgrade.SPEED else 1.0)


func next_upgrade_cost() -> int:
	return GameConfig.UPGRADE_COSTS[upgrade_level] if upgrade_level < GameConfig.MAX_UPGRADE_LEVEL else 0


func upgrade_error(track: int) -> String:
	if track < Upgrade.DAMAGE or track > Upgrade.SPEED:
		return "Choose damage, range, or firing speed"
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
	var target := _nearest_target()
	if target != null:
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
	_shot_endpoint = to_local(target.global_position)
	_flash_remaining = GameConfig.SHOT_FLASH_DURATION
	target.take_damage(damage())
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-13, -13, 26, 26), Color("17688e"))
	draw_rect(Rect2(-13, -13, 26, 26), Color("65d8f5"), false, 2.0)
	draw_circle(Vector2.ZERO, 7, Color("8beaff"))
	if upgrade_level > 0:
		var color := Color("ffb56b")
		if upgrade_type == Upgrade.RANGE:
			color = Color("b5f57c")
		elif upgrade_type == Upgrade.SPEED:
			color = Color("dc9aff")
		for i in range(upgrade_level):
			draw_circle(Vector2(-10 + 5 * i, 10), 2, color)
	if _flash_remaining > 0.0:
		draw_line(Vector2.ZERO, _shot_endpoint, Color("f5f6a6"), 3.0, true)
		draw_circle(Vector2.ZERO, 10, Color(1.0, 1.0, 0.7, 0.65))
