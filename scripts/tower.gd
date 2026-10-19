class_name Tower
extends Node2D
## Single-tile blocking tower. Every cooldown it hits the nearest living enemy in range
## with an immediate shot and shows a short beam. Owns no currency or pathfinding.

const BODY_SIZE: float = 24.0
const IDLE_SCAN_INTERVAL: float = 0.1
const COLOR_BODY: Color = Color(0.2, 0.6, 0.95)
const COLOR_CORE: Color = Color(0.6, 0.95, 1.0)
const COLOR_BEAM: Color = Color(0.7, 1.0, 1.0, 0.9)

var attack_range: float = GameConfig.TOWER_RANGE
var damage: int = GameConfig.TOWER_DAMAGE
var cooldown: float = GameConfig.TOWER_COOLDOWN

var _cooldown_left: float = 0.0
var _scan_left: float = 0.0
var _flash_left: float = 0.0
var _flash_target: Vector2 = Vector2.ZERO  # local position of the last shot's target


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0:
			queue_redraw()
	if _cooldown_left > 0.0:
		_cooldown_left -= delta
		if _cooldown_left > 0.0:
			return
	# Ready to fire; throttle group scans while idle so empty space wastes no shot.
	_scan_left -= delta
	if _scan_left > 0.0:
		return
	_scan_left = IDLE_SCAN_INTERVAL
	var target: Enemy = find_target()
	if target == null:
		return
	attack(target)
	_cooldown_left = cooldown
	_scan_left = 0.0


## Nearest active enemy within range (center-to-center), or null.
func find_target() -> Enemy:
	var best: Enemy = null
	var best_distance: float = attack_range
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or not enemy.is_active():
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance <= best_distance:
			best = enemy
			best_distance = distance
	return best


## Immediate-hit attack. Kept separate so a projectile version can replace it later.
func attack(target: Enemy) -> void:
	_flash_target = to_local(target.global_position)
	_flash_left = GameConfig.TOWER_FLASH_DURATION
	queue_redraw()
	target.take_damage(damage)


func _draw() -> void:
	var half: float = BODY_SIZE / 2.0
	draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), COLOR_BODY)
	draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), Color(0.05, 0.15, 0.3), false, 2.0)
	draw_circle(Vector2.ZERO, 5.0, COLOR_CORE)
	if _flash_left > 0.0:
		draw_line(Vector2.ZERO, _flash_target, COLOR_BEAM, 3.0)
		draw_circle(_flash_target, 6.0, Color(1, 1, 1, 0.7))
