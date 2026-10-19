class_name Tower
extends Node2D
## Single-tile blocking tower. Its type (TowerTypes) decides stats and attack style:
## "single" hits the nearest enemy in range, "area" shocks every enemy in range. Each
## shot is an immediate hit with a short visual. A tower can commit to one upgrade path
## and level it up. Owns no currency, pathfinding or skill state; Main charges for
## upgrades, checks skill unlocks and pushes global skill modifiers in.

enum UpgradePath { NONE, DAMAGE, RANGE, SPEED, PIERCE, STATIC }

const BODY_SIZE: float = 24.0
const IDLE_SCAN_INTERVAL: float = 0.1
const PIERCE_DAMAGE_PER_LEVEL: int = 4
const STATIC_SLOW_PER_LEVEL: float = 0.15
const STATIC_SLOW_DURATION: float = 1.5
const COLOR_SELECTED: Color = Color(1.0, 1.0, 0.4)
const PATH_COLORS: Dictionary = {
	UpgradePath.NONE: Color(0.6, 0.95, 1.0),
	UpgradePath.DAMAGE: Color(1.0, 0.35, 0.3),
	UpgradePath.RANGE: Color(0.4, 1.0, 0.45),
	UpgradePath.SPEED: Color(1.0, 0.9, 0.3),
	UpgradePath.PIERCE: Color(1.0, 0.55, 0.9),
	UpgradePath.STATIC: Color(0.45, 0.75, 1.0),
}
const PATH_NAMES: Dictionary = {
	UpgradePath.NONE: "None",
	UpgradePath.DAMAGE: "Damage",
	UpgradePath.RANGE: "Range",
	UpgradePath.SPEED: "Hit speed",
	UpgradePath.PIERCE: "Armor piercing",
	UpgradePath.STATIC: "Static field",
}
const GENERIC_PATHS: Array[UpgradePath] = [UpgradePath.DAMAGE, UpgradePath.RANGE, UpgradePath.SPEED]

var tower_type: String = TowerTypes.BASIC
var cell: Vector2i = Vector2i.ZERO
var attack_range: float = GameConfig.TOWER_RANGE
var damage: int = GameConfig.TOWER_DAMAGE
var cooldown: float = GameConfig.TOWER_COOLDOWN
var armor_piercing: bool = false
var slow_amount: float = 0.0
var upgrade_path: UpgradePath = UpgradePath.NONE
var upgrade_level: int = 0
## Total currency spent on this tower (build + upgrades); the basis for its sell value.
var invested: int = GameConfig.TOWER_COST
## Global skill modifiers pushed in by Main.
var damage_multiplier: float = 1.0
var cooldown_multiplier: float = 1.0
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _cooldown_left: float = 0.0
var _scan_left: float = 0.0
var _flash_left: float = 0.0
var _flash_targets: PackedVector2Array = PackedVector2Array()  # local positions hit by the last attack


## Sets the tower type and resets stats/investment. Call before adding to the tree.
func configure(type_id: String) -> void:
	tower_type = type_id
	invested = TowerTypes.cost(type_id)
	upgrade_path = UpgradePath.NONE
	upgrade_level = 0
	_recompute_stats()


func is_area() -> bool:
	return TowerTypes.get_def(tower_type)["attack"] == "area"


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
	var targets: Array[Enemy] = find_targets()
	if targets.is_empty():
		return
	attack(targets)
	_cooldown_left = cooldown
	_scan_left = 0.0


## Enemies this tower would hit right now: the nearest one for single-target towers,
## every enemy in range for area towers. Range is center-to-center distance.
func find_targets() -> Array[Enemy]:
	var targets: Array[Enemy] = []
	var nearest: Enemy = null
	var nearest_distance: float = attack_range
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or not enemy.is_active():
			continue
		var distance: float = global_position.distance_to(enemy.global_position)
		if distance > attack_range:
			continue
		if is_area():
			targets.append(enemy)
		elif distance <= nearest_distance:
			nearest = enemy
			nearest_distance = distance
	if nearest != null:
		targets.append(nearest)
	return targets


## Nearest active enemy within range, or null.
func find_target() -> Enemy:
	var best: Enemy = null
	var best_distance: float = attack_range
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = node as Enemy
		if enemy != null and enemy.is_active():
			var distance: float = global_position.distance_to(enemy.global_position)
			if distance <= best_distance:
				best = enemy
				best_distance = distance
	return best


## Immediate-hit attack on every target. Kept separate so projectiles can replace it later.
func attack(targets: Array[Enemy]) -> void:
	_flash_targets.clear()
	for target: Enemy in targets:
		_flash_targets.append(to_local(target.global_position))
	_flash_left = GameConfig.TOWER_FLASH_DURATION * (2.0 if is_area() else 1.0)
	queue_redraw()
	for target: Enemy in targets:
		if slow_amount > 0.0:
			target.apply_slow(slow_amount, STATIC_SLOW_DURATION)
		target.take_damage(damage, armor_piercing)


# --- Upgrades ----------------------------------------------------------------------

## Generic paths plus this type's unique path.
func available_paths() -> Array[UpgradePath]:
	var paths: Array[UpgradePath] = GENERIC_PATHS.duplicate()
	paths.append(TowerTypes.get_def(tower_type)["unique_path"] as UpgradePath)
	return paths


func unique_path() -> UpgradePath:
	return TowerTypes.get_def(tower_type)["unique_path"] as UpgradePath


## Cost of the next upgrade level, or -1 if the tower is fully upgraded.
func next_upgrade_cost() -> int:
	if upgrade_level >= GameConfig.UPGRADE_MAX_LEVEL:
		return -1
	return GameConfig.UPGRADE_COSTS[upgrade_level]


## A tower may only ever take one of its paths, up to the maximum level. Skill unlocks
## are checked by Main.
func can_upgrade(path: UpgradePath) -> bool:
	if path not in available_paths() or upgrade_level >= GameConfig.UPGRADE_MAX_LEVEL:
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


func set_global_modifiers(new_damage_multiplier: float, new_cooldown_multiplier: float) -> void:
	damage_multiplier = new_damage_multiplier
	cooldown_multiplier = new_cooldown_multiplier
	_recompute_stats()


func sell_value() -> int:
	return floori(invested * GameConfig.SELL_REFUND_RATIO)


func _recompute_stats() -> void:
	var def: Dictionary = TowerTypes.get_def(tower_type)
	var base_damage: float = def["damage"]
	attack_range = def["range"]
	cooldown = def["cooldown"]
	armor_piercing = false
	slow_amount = 0.0
	match upgrade_path:
		UpgradePath.DAMAGE:
			base_damage += def["damage_per_level"] * upgrade_level
		UpgradePath.RANGE:
			attack_range += def["range_per_level"] * upgrade_level
		UpgradePath.SPEED:
			cooldown *= pow(GameConfig.UPGRADE_COOLDOWN_FACTOR, upgrade_level)
		UpgradePath.PIERCE:
			base_damage += PIERCE_DAMAGE_PER_LEVEL * upgrade_level
			armor_piercing = true
		UpgradePath.STATIC:
			slow_amount = STATIC_SLOW_PER_LEVEL * upgrade_level
	damage = maxi(1, roundi(base_damage * damage_multiplier))
	cooldown *= cooldown_multiplier
	_cooldown_left = minf(_cooldown_left, cooldown)
	queue_redraw()


# --- Rendering -----------------------------------------------------------------------

func _draw() -> void:
	var half: float = BODY_SIZE / 2.0
	var path_color: Color = PATH_COLORS[upgrade_path]
	var body_color: Color = TowerTypes.get_def(tower_type)["color"]
	var border: Color = COLOR_SELECTED if selected else Color(0.05, 0.1, 0.25)
	var border_width: float = 3.0 if selected else 2.0
	if is_area():
		var hexagon: PackedVector2Array = PackedVector2Array()
		for i in 6:
			hexagon.append(Vector2.RIGHT.rotated(TAU * i / 6.0) * (half + 1.0))
		draw_colored_polygon(hexagon, body_color)
		hexagon.append(hexagon[0])
		draw_polyline(hexagon, border, border_width)
		draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.95, 0.4) if upgrade_path == UpgradePath.NONE else path_color)
	else:
		draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), body_color)
		draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), border, false, border_width)
		draw_circle(Vector2.ZERO, 5.0, path_color)
	# One pip per upgrade level along the bottom edge.
	for i in upgrade_level:
		draw_rect(Rect2(-half + 3.0 + i * 7.0, half - 6.0, 5.0, 4.0), path_color)
	if selected:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(COLOR_SELECTED, 0.6), 1.5)
	if _flash_left > 0.0:
		var beam: Color = Color(path_color, 0.9) if upgrade_path != UpgradePath.NONE else Color(0.7, 1.0, 1.0, 0.9)
		for target: Vector2 in _flash_targets:
			if is_area():
				_draw_bolt(target, Color(1.0, 0.95, 0.45) if upgrade_path == UpgradePath.NONE else beam)
			else:
				draw_line(Vector2.ZERO, target, beam, 3.0)
			draw_circle(target, 5.0, Color(1, 1, 1, 0.7))


## Jagged electric bolt from the tower to `target`.
func _draw_bolt(target: Vector2, color: Color) -> void:
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	var normal: Vector2 = target.orthogonal().normalized()
	for i in range(1, 5):
		var t: float = i / 5.0
		var offset: float = (6.0 if i % 2 == 0 else -6.0) * (1.0 - absf(t - 0.5))
		points.append(target * t + normal * offset)
	points.append(target)
	draw_polyline(points, color, 2.0)
