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
var damage: Dictionary = {"health": GameConfig.TOWER_DAMAGE, "armor": 8, "shield": 8}
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
var range_multiplier: float = 1.0
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()

var _cooldown_left: float = 0.0
var _scan_left: float = 0.0
var _flash_left: float = 0.0
var _flash_targets: PackedVector2Array = PackedVector2Array()  # local positions hit by the last attack
var _flash_splash: float = 0.0
# Animation state (visual only).
var _aim: float = -PI / 2.0          # turret angle, radians (up)
var _target_ref: Enemy = null        # last enemy shot, tracked by the turret between shots
var _since_shot: float = 99.0        # seconds since the last attack
var _charge_shown: int = -1          # Tesla charge level currently drawn
var _spark_left: float = 0.0
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# Child canvas items so animation rarely needs a redraw: the turret is drawn once and then
# only rotated/moved (aim, recoil); the Tesla glow is only scaled/faded; shot effects
# redraw only while a shot plays out.
var _turret: Node2D
var _glow: Node2D
var _fx: Node2D
var _fx_live: bool = false

const ANIM_TIME: float = 0.4
const TURN_SPEED: float = 9.0        # radians per second
const BASIC_TRACER_TIME: float = 0.08
const CANNON_SHELL_TIME: float = 0.13


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
	_turret = Node2D.new()
	_turret.draw.connect(_draw_turret)
	add_child(_turret)
	if is_area():
		_glow = Node2D.new()
		_glow.position = TESLA_ORB
		_glow.draw.connect(_draw_glow)
		add_child(_glow)
	_fx = Node2D.new()
	_fx.draw.connect(_draw_fx)
	add_child(_fx)
	_update_children()


func is_area() -> bool:
	return TowerTypes.get_def(tower_type)["attack"] == "area"


func _process(delta: float) -> void:
	step(delta)


func step(delta: float) -> void:
	_animate(delta)
	if _flash_left > 0.0:
		_flash_left -= delta
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


## Enemies this tower would hit right now: for single-target towers the enemy in range
## that is closest to the exit ("first"), for area towers every enemy in range.
## Range is center-to-center distance in world units.
func find_targets() -> Array[Enemy]:
	var targets: Array[Enemy] = []
	var first: Enemy = null
	var first_remaining: float = INF
	var range_squared: float = attack_range * attack_range
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = node as Enemy
		if enemy == null or not enemy.is_active():
			continue
		if position.distance_squared_to(enemy.position) > range_squared:
			continue
		if is_area():
			targets.append(enemy)
		else:
			var remaining: float = enemy.remaining_distance()
			if remaining < first_remaining:
				first = enemy
				first_remaining = remaining
	if first != null:
		targets.append(first)
	return targets


## Nearest active enemy within range, or null.
func find_target() -> Enemy:
	var best: Enemy = null
	var best_distance: float = attack_range
	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Enemy = node as Enemy
		if enemy != null and enemy.is_active():
			var distance: float = position.distance_to(enemy.position)
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
	_since_shot = 0.0
	_target_ref = targets[0]
	if not is_area():
		_aim = (targets[0].position - position).angle()
	GameAudio.play("shot_" + tower_type)
	_fx_live = true
	_update_children()
	var splash_center: Vector2 = targets[0].position
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
			if enemy != null and enemy.is_active() and enemy not in targets and enemy.position.distance_to(splash_center) <= splash_radius:
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


## Skill and biome modifiers: per-layer damage multipliers, cooldown multiplier, max
## level and range multiplier.
func set_modifiers(new_layer_multipliers: Dictionary, new_cooldown_multiplier: float, new_max_level: int, new_range_multiplier: float = 1.0) -> void:
	layer_multipliers = new_layer_multipliers
	cooldown_multiplier = new_cooldown_multiplier
	range_multiplier = new_range_multiplier
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
	attack_range *= range_multiplier
	_cooldown_left = minf(_cooldown_left, cooldown)
	queue_redraw()
	if _turret != null:
		_turret.queue_redraw()  # core color follows the upgrade path


# --- Animation and rendering ---------------------------------------------------------

const TESLA_ORB: Vector2 = Vector2(0, -8.5)


## Visual-only animation. Aiming and recoil only move the turret node and the Tesla glow
## is only scaled, so the common case costs no redraw; shot effects redraw while they last.
func _animate(delta: float) -> void:
	if _turret == null:
		return
	var moved: bool = false
	if _since_shot < ANIM_TIME:
		_since_shot += delta
		moved = true
	if not is_area() and is_instance_valid(_target_ref) and _target_ref.is_active():
		var wanted: float = (_target_ref.position - position).angle()
		var diff: float = angle_difference(_aim, wanted)
		if absf(diff) > 0.005:
			_aim += clampf(diff, -TURN_SPEED * delta, TURN_SPEED * delta)
			moved = true
	elif _target_ref != null and not is_instance_valid(_target_ref):
		_target_ref = null
	if is_area():
		var level: int = int(_charge() * 12.0)
		if level != _charge_shown:
			_charge_shown = level
			moved = true
		if level >= 12:
			_spark_left -= delta
			if _spark_left <= 0.0:
				_spark_left = 0.2
				_fx.queue_redraw()  # idle sparks crackle a few times a second
	if moved:
		_update_children()


func _update_children() -> void:
	if _turret == null:
		return
	_turret.rotation = 0.0 if is_area() else _aim
	var kick: float = 0.0
	if tower_type == TowerTypes.CANNON:
		kick = _recoil(6.0, 0.25)
	elif not is_area():
		kick = _recoil(4.0, 0.12)
	_turret.position = -Vector2.RIGHT.rotated(_aim) * kick
	if _glow != null:
		var charge: float = _charge()
		var flare: float = maxf(0.0, 1.0 - _since_shot / 0.22)
		_glow.scale = Vector2.ONE * (0.6 + 0.4 * charge + 0.8 * flare)
		_glow.modulate = Color(1, 1, 1, 0.25 + 0.75 * maxf(charge, flare))
	if _fx_live:
		_fx.queue_redraw()
		if _since_shot >= ANIM_TIME:
			_fx_live = false  # this redraw clears the last effect


## 0 right after a shot, 1 when ready to fire again.
func _charge() -> float:
	return 1.0 if cooldown <= 0.0 else clampf(1.0 - _cooldown_left / cooldown, 0.0, 1.0)


func _path_color() -> Color:
	return PATH_COLORS[upgrade_path]


func _orb_color() -> Color:
	return Color(1.0, 0.95, 0.45) if upgrade_path == UpgradePath.NONE else _path_color()


## Static part: stone base, upgrade pips and the selection/range marker.
func _draw() -> void:
	var path_color: Color = _path_color()
	var body_color: Color = TowerTypes.get_def(tower_type)["color"]
	var half: float = BODY_SIZE / 2.0
	draw_rect(Rect2(-half + 2.0, -half + 3.0, BODY_SIZE, BODY_SIZE), Color(0, 0, 0, 0.32))
	var stone: Color = Color(0.36, 0.37, 0.4).lerp(body_color, 0.12)
	draw_rect(Rect2(-half, -half, BODY_SIZE, BODY_SIZE), stone.darkened(0.25))
	draw_rect(Rect2(-half + 2.0, -half + 2.0, BODY_SIZE - 4.0, BODY_SIZE - 4.0), stone)
	draw_rect(Rect2(-half + 2.0, -half + 2.0, BODY_SIZE - 4.0, 2.0), stone.lightened(0.25))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		draw_rect(Rect2(corner * (half - 4.0) - Vector2(1, 1), Vector2(2, 2)), stone.darkened(0.45))
	match tower_type:
		TowerTypes.TESLA:
			var hexagon: PackedVector2Array = PackedVector2Array()
			for i in 6:
				hexagon.append(Vector2.RIGHT.rotated(TAU * i / 6.0 + PI / 6.0) * 10.5)
			draw_colored_polygon(hexagon, body_color.darkened(0.35))
		TowerTypes.CANNON:
			draw_circle(Vector2.ZERO, 10.5, body_color.darkened(0.45))
			draw_circle(Vector2.ZERO, 9.0, body_color.darkened(0.15))
			for i in 6:
				draw_circle(Vector2.RIGHT.rotated(TAU * i / 6.0) * 7.5, 1.0, body_color.darkened(0.55))
	# One pip per upgrade level along the bottom edge.
	for i in upgrade_level:
		draw_rect(Rect2(-half + 3.0 + i * 5.5, half - 4.0, 4.0, 3.0), path_color)
	if selected:
		draw_arc(Vector2.ZERO, attack_range, 0.0, TAU, 64, Color(COLOR_SELECTED, 0.6), 1.5)
		draw_rect(Rect2(-half - 2.0, -half - 2.0, BODY_SIZE + 4.0, BODY_SIZE + 4.0), COLOR_SELECTED, false, 2.0)


## Turret, drawn pointing right; the node is rotated to aim and nudged back for recoil.
func _draw_turret() -> void:
	var t: Node2D = _turret
	var path_color: Color = _path_color()
	var body_color: Color = TowerTypes.get_def(tower_type)["color"]
	match tower_type:
		TowerTypes.TESLA:
			# Copper coil: stacked rings narrowing toward the orb.
			for i in 4:
				var y: float = 5.0 - i * 3.6
				var w: float = 8.0 - i * 1.3
				t.draw_set_transform(Vector2(0, y), 0.0, Vector2(1.0, 0.45))
				t.draw_arc(Vector2.ZERO, w, 0.0, TAU, 18, Color(0.85, 0.55, 0.3).lightened(0.1 * i), 2.2)
			t.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			t.draw_circle(TESLA_ORB, 4.5, _orb_color())
			t.draw_circle(TESLA_ORB + Vector2(-1.2, -1.2), 1.4, Color(1, 1, 1, 0.8))
		TowerTypes.CANNON:
			t.draw_rect(Rect2(-1.0, -4.5, 17.0, 9.0), Color(0.18, 0.18, 0.2))
			t.draw_rect(Rect2(-1.0, -4.5, 17.0, 2.5), Color(0.38, 0.38, 0.42))
			t.draw_rect(Rect2(11.0, -5.5, 4.5, 11.0), Color(0.12, 0.12, 0.14))
			t.draw_rect(Rect2(3.0, -4.5, 2.0, 9.0), path_color)
			t.draw_circle(Vector2(-2.0, 0.0), 5.5, body_color)
			t.draw_circle(Vector2(-3.5, -1.5), 1.8, body_color.lightened(0.4))
		_:
			t.draw_rect(Rect2(2.0, -3.5, 12.0, 2.6), body_color.darkened(0.45))
			t.draw_rect(Rect2(2.0, 0.9, 12.0, 2.6), body_color.darkened(0.45))
			t.draw_circle(Vector2.ZERO, 8.0, body_color.darkened(0.3))
			t.draw_circle(Vector2(-0.5, -0.5), 6.6, body_color)
			t.draw_circle(Vector2(-2.0, -2.5), 2.4, body_color.lightened(0.45))
			t.draw_circle(Vector2.ZERO, 2.6, path_color)


## Tesla orb halo (unit size; the node's scale and alpha follow the charge).
func _draw_glow() -> void:
	_glow.draw_circle(Vector2.ZERO, 9.0, Color(_orb_color(), 0.3))
	_glow.draw_circle(Vector2.ZERO, 6.0, Color(_orb_color(), 0.45))


func _recoil(strength: float, duration: float) -> float:
	return strength * maxf(0.0, 1.0 - _since_shot / duration)


func _muzzle() -> Vector2:
	var length: float = 15.0 if tower_type == TowerTypes.CANNON else 14.0
	return Vector2.RIGHT.rotated(_aim) * length


## Short-lived shot effects in tower space: muzzle flash, tracer, bolts, shell, explosion.
func _draw_fx() -> void:
	match tower_type:
		TowerTypes.TESLA:
			_draw_tesla_fx()
		TowerTypes.CANNON:
			_draw_cannon_fx()
		_:
			_draw_basic_fx()


func _draw_basic_fx() -> void:
	if _since_shot >= ANIM_TIME or _flash_targets.is_empty():
		return
	var dir: Vector2 = Vector2.RIGHT.rotated(_aim)
	if _since_shot < 0.06:
		_draw_flash(_fx, dir * (15.0 - _recoil(4.0, 0.12)), 5.0, Color(1.0, 0.95, 0.6, 1.0 - _since_shot / 0.06))
	var target: Vector2 = _flash_targets[0]
	var tracer: Color = Color(_path_color(), 0.95) if upgrade_path != UpgradePath.NONE else Color(0.75, 1.0, 1.0, 0.95)
	var p: float = _since_shot / BASIC_TRACER_TIME
	if p < 1.0:
		var muzzle: Vector2 = _muzzle()
		_fx.draw_line(muzzle.lerp(target, maxf(0.0, p - 0.45)), muzzle.lerp(target, p), tracer, 2.5)
	elif _since_shot < BASIC_TRACER_TIME + 0.1:
		var t: float = (_since_shot - BASIC_TRACER_TIME) / 0.1
		_draw_flash(_fx, target, 3.0 + 5.0 * t, Color(tracer, 1.0 - t))


func _draw_tesla_fx() -> void:
	var orb_color: Color = _orb_color()
	if _charge() >= 1.0:
		_rng.seed = hash([cell, Time.get_ticks_msec() / 200])
		for i in 2:
			var a: float = _rng.randf() * TAU
			var tip: Vector2 = TESLA_ORB + Vector2.RIGHT.rotated(a) * _rng.randf_range(7.0, 11.0)
			_fx.draw_polyline(PackedVector2Array([TESLA_ORB, TESLA_ORB.lerp(tip, 0.5) + Vector2(_rng.randf_range(-2, 2), _rng.randf_range(-2, 2)), tip]), Color(orb_color, 0.8), 1.2)
	# Discharge: flickering bolts to every target.
	var life: float = 0.22
	if _since_shot < life and not _flash_targets.is_empty():
		var fade: float = 1.0 - _since_shot / life
		_rng.seed = hash([cell, int(_since_shot * 60.0)])
		for target: Vector2 in _flash_targets:
			_draw_bolt(_fx, TESLA_ORB, target, Color(orb_color, fade), 2.6 * fade + 0.6)
			_draw_bolt(_fx, TESLA_ORB, target, Color(1, 1, 1, fade * 0.8), 1.0)
			_fx.draw_circle(target, 6.0 * fade + 2.0, Color(orb_color, 0.45 * fade))


func _draw_cannon_fx() -> void:
	if _flash_targets.is_empty() or _since_shot >= ANIM_TIME:
		return
	var dir: Vector2 = Vector2.RIGHT.rotated(_aim)
	if _since_shot < 0.07:
		_draw_flash(_fx, dir * (18.0 - _recoil(6.0, 0.25)), 8.0, Color(1.0, 0.8, 0.35, 1.0 - _since_shot / 0.07))
	# Smoke puffs drifting from the muzzle.
	var muzzle: Vector2 = _muzzle()
	var smoke_t: float = _since_shot / ANIM_TIME
	for i in 3:
		var drift: Vector2 = Vector2.RIGHT.rotated(_aim + (i - 1) * 0.5) * (4.0 + 10.0 * smoke_t)
		_fx.draw_circle(muzzle + drift + Vector2(0, -6.0 * smoke_t), 3.0 + 4.0 * smoke_t, Color(0.75, 0.75, 0.72, 0.45 * (1.0 - smoke_t)))
	# Shell arcing to the target, then an explosion (and the shrapnel ring if upgraded).
	var target: Vector2 = _flash_targets[0]
	var p: float = _since_shot / CANNON_SHELL_TIME
	if p < 1.0:
		var pos: Vector2 = muzzle.lerp(target, p) + Vector2(0, -10.0 * sin(PI * p))
		_fx.draw_circle(pos, 3.2, Color(0.12, 0.12, 0.13))
		_fx.draw_circle(pos + Vector2(-0.8, -0.8), 1.1, Color(0.6, 0.6, 0.6))
	else:
		var t: float = clampf((_since_shot - CANNON_SHELL_TIME) / (ANIM_TIME - CANNON_SHELL_TIME), 0.0, 1.0)
		_fx.draw_circle(target, 4.0 + 10.0 * t, Color(1.0, 0.55, 0.2, 0.55 * (1.0 - t)))
		_fx.draw_circle(target, 3.0 + 5.0 * t, Color(1.0, 0.9, 0.5, 0.8 * (1.0 - t)))
		_fx.draw_arc(target, 6.0 + 14.0 * t, 0.0, TAU, 24, Color(0.3, 0.25, 0.2, 0.6 * (1.0 - t)), 2.0)
		if _flash_splash > 0.0:
			_fx.draw_arc(target, _flash_splash * minf(1.0, 0.4 + t), 0.0, TAU, 32, Color(1.0, 0.6, 0.25, 0.7 * (1.0 - t)), 2.0)


## Star-shaped flash (muzzle flash / impact spark).
static func _draw_flash(ci: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 10:
		pts.append(center + Vector2.RIGHT.rotated(TAU * i / 10.0) * (r if i % 2 == 0 else r * 0.45))
	ci.draw_colored_polygon(pts, color)


## Jagged electric bolt from `from` to `target`, re-randomized every frame for flicker.
func _draw_bolt(ci: CanvasItem, from: Vector2, target: Vector2, color: Color, width: float) -> void:
	var points: PackedVector2Array = PackedVector2Array([from])
	var span: Vector2 = target - from
	var normal: Vector2 = span.orthogonal().normalized()
	var segments: int = clampi(int(span.length() / 10.0), 3, 9)
	for i in range(1, segments):
		var t: float = float(i) / segments
		points.append(from + span * t + normal * _rng.randf_range(-7.0, 7.0) * (1.0 - absf(t - 0.5)))
	points.append(target)
	ci.draw_polyline(points, color, width)
