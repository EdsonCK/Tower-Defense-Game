class_name Tower
extends Node2D

var _cooldown := 0.0
var _flash_remaining := 0.0
var _shot_endpoint := Vector2.ZERO


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
	_cooldown = GameConfig.TOWER_COOLDOWN


func _nearest_target() -> Enemy:
	var nearest: Enemy = null
	var nearest_distance := GameConfig.TOWER_RANGE * GameConfig.TOWER_RANGE
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
	if not is_instance_valid(target) or not target.is_alive():
		return
	_shot_endpoint = to_local(target.global_position)
	_flash_remaining = GameConfig.SHOT_FLASH_DURATION
	target.take_damage(GameConfig.TOWER_DAMAGE)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-13, -13, 26, 26), Color("17688e"))
	draw_rect(Rect2(-13, -13, 26, 26), Color("65d8f5"), false, 2.0)
	draw_circle(Vector2.ZERO, 7, Color("8beaff"))
	if _flash_remaining > 0.0:
		draw_line(Vector2.ZERO, _shot_endpoint, Color("f5f6a6"), 3.0, true)
		draw_circle(Vector2.ZERO, 10, Color(1.0, 1.0, 0.7, 0.65))
