class_name Tower
extends Node2D
## Single-tile blocking tower. Its type (TowerTypes) decides stats and attack style:
## "single" hits the nearest enemy in range, "area" shocks every enemy in range. Damage
## is split by enemy layer (health / armor / shield), so towers specialize. Each shot is
## an immediate hit with a short visual. A tower can commit to one upgrade path and
## level it up. Owns no currency, pathfinding or skill state; Main charges for upgrades,
## checks skill unlocks and pushes skill modifiers in.

enum UpgradePath { NONE, DAMAGE, RANGE, SPEED, PIERCE, STATIC, SHRAPNEL }

const BODY_SIZE: float = 24.0
const IDLE_SCAN_INTERVAL: float = 0.1
const PIERCE_ARMOR_FACTOR_PER_LEVEL: float = 1.0   # Basic unique: +100% armor damage per level
const STATIC_SLOW_PER_LEVEL: float = 0.15
const STATIC_SLOW_DURATION: float = 1.5
const SHRAPNEL_RADIUS_BASE: float = 24.0           # Cannon unique: splash radius 24 + 16/level px
const SHRAPNEL_RADIUS_PER_LEVEL: float = 16.0
const SHRAPNEL_DAMAGE_FACTOR: float = 0.5
const COLOR_SELECTED: Color = Color(1.0, 0.9, 0.35)
const PATH_COLORS: Dictionary = {
	UpgradePath.NONE: Color(0.6, 0.95, 1.0),
	UpgradePath.DAMAGE: Color(1.0, 0.35, 0.3),
	UpgradePath.RANGE: Color(0.4, 1.0, 0.45),
	UpgradePath.SPEED: Color(1.0, 0.9, 0.3),
	UpgradePath.PIERCE: Color(0.95, 0.95, 1.0),
	UpgradePath.STATIC: Color(0.45, 0.75, 1.0),
	UpgradePath.SHRAPNEL: Color(1.0, 0.6, 0.25),
}
const PATH_NAMES: Dictionary = {
	UpgradePath.NONE: "None",
	UpgradePath.DAMAGE: "Damage",
	UpgradePath.RANGE: "Range",
	UpgradePath.SPEED: "Hit speed",
	UpgradePath.PIERCE: "Armor piercing",
	UpgradePath.STATIC: "Static field",
	UpgradePath.SHRAPNEL: "Shrapnel",
}
## Compact names for the selection card's upgrade buttons.
const PATH_SHORT_NAMES: Dictionary = {
	UpgradePath.NONE: "-",
	UpgradePath.DAMAGE: "Damage",
	UpgradePath.RANGE: "Range",
	UpgradePath.SPEED: "Speed",
	UpgradePath.PIERCE: "Piercing",
	UpgradePath.STATIC: "Static",
	UpgradePath.SHRAPNEL: "Shrapnel",
}
const GENERIC_PATHS: Array[UpgradePath] = [UpgradePath.DAMAGE, UpgradePath.RANGE, UpgradePath.SPEED]

var tower_type: String = TowerTypes.BASIC
var cell: Vector2i = Vector2i.ZERO
var attack_range: float = GameConfig.TOWER_RANGE
## Damage per hit against each enemy layer: {"health": .., "armor": .., "shield": ..}.
var damage: Dictionary = {"health": GameConfig.TOWER_DAMAGE, "armor": 8, "shield": 6}
var cooldown: float = GameConfig.TOWER_COOLDOWN
var slow_amount: float = 0.0
var splash_radius: float = 0.0
var upgrade_path: UpgradePath = UpgradePath.NONE
var upgrade_level: int = 0
var max_level: int = GameConfig.UPGRADE_MAX_LEVEL
## Total currency spent on this tower (build + upgrades); the basis for its sell value.
var invested: int = GameConfig.TOWER_COST
## Skill modifiers pushed in by Main: damage multiplier per layer, cooldown multiplier.
var layer_multipliers: Dictionary = {"health": 1.0, "armor": 1.0, "shield": 1.0}
var cooldown_multiplier: float = 1.0
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _cooldown_left: float = 0.0
var _scan_left: float = 0.0
var _flash_left: float = 0.0
var _flash_targets: PackedVector2Array = PackedVector2Array()  # local positions hit by the last attack
var _flash_splash: float = 0.0


## Sets the tower type and resets stats/investment. Call before adding to the tree.
func configure(type_id: String) -> void:
	tower_type = type_id
	invested = TowerTypes.cost(type_id)
	upgrade_path = UpgradePath.NONE
	upgrade_level = 0
	_recompute_stats()


func _ready() -> void:
	# Stagger target scans by tile so hundreds of towers don't all scan on the same tick.
	_scan_left = IDLE_SCAN_INTERVAL * float(posmod(cell.x * 7 + cell.y * 13, 10)) / 10.0


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


## Immediate-hit attack on every target (plus shrapnel splash). Kept separate so
## projectiles can replace it later.
func attack(targets: Array[Enemy]) -> void:
	_flash_targets.clear()
	for target: Enemy in targets:
		_flash_targets.append(to_local(target.global_position))
	_flash_left = GameConfig.TOWER_FLASH_DURATION * (2.0 if is_area() or splash_radius > 0.0 else 1.0)
	_flash_splash = splash_radius
	queue_redraw()
	var splash_center: Vector2 = targets[0].global_position
	for target: Enemy in targets:
		if slow_amount > 0.0:
			target.apply_slow(slow_amount, STATIC_SLOW_DURATION)
		target.take_hit(damage)
	if splash_radius > 0.0:
		var splash_damage: Dictionary = {}
		for layer: String in damage:
			splash_damage[layer] = damage[layer] * SHRAPNEL_DAMAGE_FACTOR
		for node: Node in get_tree().get_nodes_in_group("enemies"):
			var enemy: Enemy = node as Enemy
			if enemy != null and enemy.is_active() and enemy not in targets and enemy.global_position.distance_to(splash_center) <= splash_radius:
				enemy.take_hit(splash_damage)


# --- Upgrades ----------------------------------------------------------------------

## Generic paths plus this type's unique path.
func available_paths() -> Array[UpgradePath]:
	var paths: Array[UpgradePath] = GENERIC_PATHS.duplicate()
	paths.append(unique_path())
	return paths


func unique_path() -> UpgradePath:
	return TowerTypes.get_def(tower_type)["unique_path"] as UpgradePath


## Cost of the next upgrade level, or -1 if the tower is at its maximum level.
func next_upgrade_cost() -> int:
	if upgrade_level >= max_level:
		return -1
	return GameConfig.UPGRADE_COSTS[mini(upgrade_level, GameConfig.UPGRADE_COSTS.size() - 1)]


## A tower may only ever take one of its paths, up to its maximum level. Skill unlocks
## are checked by Main.
func can_upgrade(path: UpgradePath) -> bool:
	if path not in available_paths() or upgrade_level >= max_level:
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


## Skill modifiers: per-layer damage multipliers, cooldown multiplier and max level.
func set_modifiers(new_layer_multipliers: Dictionary, new_cooldown_multiplier: float, new_max_level: int) -> void:
	layer_multipliers = new_layer_multipliers
	cooldown_multiplier = new_cooldown_multiplier
	max_level = maxi(new_max_level, upgrade_level)
	_recompute_stats()


func sell_value(refund_ratio: float = GameConfig.SELL_REFUND_RATIO) -> int:
	return floori(invested * refund_ratio)


func _recompute_stats() -> void:
	var def: Dictionary = TowerTypes.get_def(tower_type)
	var base: Dictionary = def["damage"]
	var factors: Dictionary = {"health": 1.0, "armor": 1.0, "shield": 1.0}
	attack_range = def["range"]
	cooldown = def["cooldown"]
	slow_amount = 0.0
	splash_radius = 0.0
	match upgrade_path:
		UpgradePath.DAMAGE:
			for layer: String in factors:
				factors[layer] += GameConfig.UPGRADE_DAMAGE_FACTOR_PER_LEVEL * upgrade_level
		UpgradePath.RANGE:
			attack_range += def["range_per_level"] * upgrade_level
		UpgradePath.SPEED:
			cooldown *= pow(GameConfig.UPGRADE_COOLDOWN_FACTOR, upgrade_level)
		UpgradePath.PIERCE:
			factors["armor"] += PIERCE_ARMOR_FACTOR_PER_LEVEL * upgrade_level
		UpgradePath.STATIC:
			slow_amount = STATIC_SLOW_PER_LEVEL * upgrade_level
		UpgradePath.SHRAPNEL:
			splash_radius = SHRAPNEL_RADIUS_BASE + SHRAPNEL_RADIUS_PER_LEVEL * upgrade_level
	damage = {}
	for layer: String in factors:
		damage[layer] = maxi(1, roundi(base[layer] * factors[layer] * float(layer_multipliers.get(layer, 1.0))))
	cooldown *= cooldown_multiplier
	_cooldown_left = minf(_cooldown_left, cooldown)
	queue_redraw()


# --- Rendering -----------------------------------------------------------------------

func _draw() -> void:
	var half: float = BODY_SIZE / 2.0
	var path_color: Color = PATH_COLORS[upgrade_path]
	var body_color: Color = TowerTypes.get_def(tower_type)["color"]
	var border: Color = COLOR_SELECTED if selected else body_color.darkened(0.6)
	var border_width: float = 3.0 if selected else 2.0
	# Soft drop shadow so towers read as raised blocks on the grid.
	draw_rect(Rect2(-half + 2.0, -half + 3.0, BODY_SIZE, BODY_SIZE), Color(0, 0, 0, 0.3))
	match tower_type:
		TowerTypes.TESLA:
			var hexagon: PackedVector2Array = PackedVector2Array()
			for i in 6:
				hexagon.append(Vector2.RIGHT.rotated(TAU * i / 6.0) * (half + 1.0))
			draw_colored_polygon(hexagon, body_color)
			hexagon.append(hexagon[0])
			draw_polyline(hexagon, border, border_width)
			draw_circle(Vector2.ZERO, 5.0, Color(1.0, 0.95, 0.4) if upgrade_path == UpgradePath.NONE else path_color)
		TowerTypes.CANNON:
			draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), body_color.darkened(0.25))
			draw_circle(Vector2.ZERO, half - 1.0, body_color)
			draw_arc(Vector2.ZERO, half - 1.0, 0.0, TAU, 24, border, border_width)
			draw_rect(Rect2(-3.0, -half - 3.0, 6.0, half), body_color.darkened(0.45))
			draw_circle(Vector2.ZERO, 4.0, path_color)
		_:
			draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), body_color)
			draw_rect(Rect2(-half + 3.0, -half + 3.0, BODY_SIZE - 6.0, 4.0), body_color.lightened(0.25))
			draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), border, false, border_width)
			draw_circle(Vector2.ZERO, 5.0, path_color)
	# One pip per upgrade level along the bottom edge.
	for i in upgrade_level:
		draw_rect(Rect2(-half + 3.0 + i * 5.5, half - 5.0, 4.0, 3.0), path_color)
	if selected:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(COLOR_SELECTED, 0.6), 1.5)
	if _flash_left > 0.0:
		var beam: Color = Color(path_color, 0.9) if upgrade_path != UpgradePath.NONE else Color(0.7, 1.0, 1.0, 0.9)
		for target: Vector2 in _flash_targets:
			if is_area():
				_draw_bolt(target, Color(1.0, 0.95, 0.45) if upgrade_path == UpgradePath.NONE else beam)
			elif tower_type == TowerTypes.CANNON:
				draw_line(Vector2.ZERO, target, Color(1.0, 0.75, 0.4, 0.8), 4.0)
				draw_circle(target, 7.0, Color(1.0, 0.65, 0.3, 0.8))
			else:
				draw_line(Vector2.ZERO, target, beam, 3.0)
			draw_circle(target, 4.0, Color(1, 1, 1, 0.7))
		if _flash_splash > 0.0 and not _flash_targets.is_empty():
			draw_arc(_flash_targets[0], _flash_splash, 0.0, TAU, 32, Color(1.0, 0.6, 0.25, 0.7), 2.0)


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
