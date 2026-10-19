class_name Tower
extends Node2D
## Single-tile blocking tower. Every cooldown it hits the nearest living enemy in range
## with an immediate shot and shows a short beam. A tower can commit to one upgrade
## path (damage, range or speed) and level it up. Owns no currency or pathfinding;
## Main charges for upgrades and refunds sales.

enum UpgradePath { NONE, DAMAGE, RANGE, SPEED }

const BODY_SIZE: float = 24.0
const IDLE_SCAN_INTERVAL: float = 0.1
const COLOR_BODY: Color = Color(0.2, 0.6, 0.95)
const COLOR_CORE: Color = Color(0.6, 0.95, 1.0)
const COLOR_BEAM: Color = Color(0.7, 1.0, 1.0, 0.9)
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.4)
const PATH_COLORS: Dictionary = {
	UpgradePath.NONE: Color(0.6, 0.95, 1.0),
	UpgradePath.DAMAGE: Color(1.0, 0.35, 0.3),
	UpgradePath.RANGE: Color(0.4, 1.0, 0.45),
	UpgradePath.SPEED: Color(1.0, 0.9, 0.3),
}
const PATH_NAMES: Dictionary = {
	UpgradePath.NONE: "None",
	UpgradePath.DAMAGE: "Damage",
	UpgradePath.RANGE: "Range",
	UpgradePath.SPEED: "Hit speed",
}

var cell: Vector2i = Vector2i.ZERO
var attack_range: float = GameConfig.TOWER_RANGE
var damage: int = GameConfig.TOWER_DAMAGE
var cooldown: float = GameConfig.TOWER_COOLDOWN
var upgrade_path: UpgradePath = UpgradePath.NONE
var upgrade_level: int = 0
## Total currency spent on this tower (build + upgrades); the basis for its sell value.
var invested: int = GameConfig.TOWER_COST
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

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


# --- Upgrades ----------------------------------------------------------------------

## Cost of the next upgrade level, or -1 if the tower is fully upgraded.
func next_upgrade_cost() -> int:
	if upgrade_level >= GameConfig.UPGRADE_MAX_LEVEL:
		return -1
	return GameConfig.UPGRADE_COSTS[upgrade_level]


## A tower may only ever take one upgrade path, up to the maximum level.
func can_upgrade(path: UpgradePath) -> bool:
	if path == UpgradePath.NONE or upgrade_level >= GameConfig.UPGRADE_MAX_LEVEL:
		return false
	return upgrade_path == UpgradePath.NONE or upgrade_path == path


## Applies one level of `path`. Does not charge currency; Main does that first.
func apply_upgrade(path: UpgradePath) -> bool:
	if not can_upgrade(path):
		return false
	invested += next_upgrade_cost()
	upgrade_path = path
	upgrade_level += 1
	_recompute_stats()
	return true


func sell_value() -> int:
	return floori(invested * GameConfig.SELL_REFUND_RATIO)


func _recompute_stats() -> void:
	damage = GameConfig.TOWER_DAMAGE
	attack_range = GameConfig.TOWER_RANGE
	cooldown = GameConfig.TOWER_COOLDOWN
	match upgrade_path:
		UpgradePath.DAMAGE:
			damage += GameConfig.UPGRADE_DAMAGE_PER_LEVEL * upgrade_level
		UpgradePath.RANGE:
			attack_range += GameConfig.UPGRADE_RANGE_PER_LEVEL * upgrade_level
		UpgradePath.SPEED:
			cooldown *= pow(GameConfig.UPGRADE_COOLDOWN_FACTOR, upgrade_level)
	_cooldown_left = minf(_cooldown_left, cooldown)
	queue_redraw()


# --- Rendering -----------------------------------------------------------------------

func _draw() -> void:
	var half: float = BODY_SIZE / 2.0
	var path_color: Color = PATH_COLORS[upgrade_path]
	draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), COLOR_BODY)
	var border: Color = COLOR_SELECTED if selected else Color(0.05, 0.15, 0.3)
	draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), border, false, 3.0 if selected else 2.0)
	draw_circle(Vector2.ZERO, 5.0, path_color)
	# One pip per upgrade level along the bottom edge.
	for i in upgrade_level:
		draw_rect(Rect2(-half + 3.0 + i * 7.0, half - 6.0, 5.0, 4.0), path_color)
	if selected:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(COLOR_SELECTED, 0.6), 1.5)
	if _flash_left > 0.0:
		draw_line(Vector2.ZERO, _flash_target, Color(path_color, 0.9) if upgrade_path != UpgradePath.NONE else COLOR_BEAM, 3.0)
		draw_circle(_flash_target, 6.0, Color(1, 1, 1, 0.7))
