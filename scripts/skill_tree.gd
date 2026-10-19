class_name SkillTree
extends RefCounted
## Skill tree definitions and the unlocked state for the current run.
## Diamonds are owned and charged by Main; this class only knows what is unlocked
## and what the unlocked skills add up to.
##
## Skill fields:
##   name, desc   display text
##   cost         diamonds
##   requires     skill ids that must be unlocked first
##   pos          Vector2i(column, row) in the skill tree menu
##   effects      key -> value. Keys:
##     unlock_tower: tower type id      unlock_upgrades: tower type id (generic paths)
##     unlock_path: tower type id (its unique path)
##     kill_reward, wave_bonus, tower_damage, tower_attack_speed: fractional bonuses (+0.2 = +20%)
##     damage_<type>: fractional damage bonus for one tower type; max_level_<type>: extra levels
##     dmg_health, dmg_armor, dmg_shield: fractional damage bonus against one enemy layer
##     enemy_health, enemy_speed, enemy_armor, enemy_shield: fractional changes (-0.1 = -10%)
##     lives: extra lives every run (granted immediately on unlock)
##     sell_refund: added to the 50% sell refund; start_gold: extra gold every run
##     diamond_bonus: extra diamonds every 5th wave
## Costs rise with the row (tier), so deeper skills are more expensive.

const ROOT: String = "tesla"
## Column titles of the skill tree menu, by column index.
const COLUMNS: Array[String] = ["Basic", "Tesla", "Cannon", "Gold", "Damage Types", "Enemy Nerfs", "Permanent"]

const SKILLS: Dictionary = {
	"tesla": {
		"name": "Tesla Tower", "cost": 3, "requires": [], "pos": Vector2i(3, 0),
		"desc": "Unlocks the Tesla Tower: shocks every enemy in a small radius and shreds purple shields.",
		"effects": {"unlock_tower": TowerTypes.TESLA},
	},
	"basic_upgrades": {
		"name": "Basic Upgrades", "cost": 3, "requires": ["tesla"], "pos": Vector2i(0, 1),
		"desc": "Basic Towers can be upgraded: Damage, Range or Hit speed (one path per tower).",
		"effects": {"unlock_upgrades": TowerTypes.BASIC},
	},
	"basic_pierce": {
		"name": "Armor Piercing", "cost": 6, "requires": ["basic_upgrades"], "pos": Vector2i(0, 2),
		"desc": "Unique Basic path: +100% damage against armor per level.",
		"effects": {"unlock_path": TowerTypes.BASIC},
	},
	"basic_veteran": {
		"name": "Veteran Crews", "cost": 10, "requires": ["basic_pierce"], "pos": Vector2i(0, 3),
		"desc": "Basic Towers deal 25% more damage of every type.",
		"effects": {"damage_basic": 0.25},
	},
	"basic_mastery": {
		"name": "Basic Mastery", "cost": 16, "requires": ["basic_veteran"], "pos": Vector2i(0, 4),
		"desc": "Basic Towers can be upgraded to level 4.",
		"effects": {"max_level_basic": 1},
	},
	"tesla_upgrades": {
		"name": "Tesla Upgrades", "cost": 4, "requires": ["tesla"], "pos": Vector2i(1, 1),
		"desc": "Tesla Towers can be upgraded: Damage, Range or Hit speed (one path per tower).",
		"effects": {"unlock_upgrades": TowerTypes.TESLA},
	},
	"tesla_static": {
		"name": "Static Field", "cost": 6, "requires": ["tesla_upgrades"], "pos": Vector2i(1, 2),
		"desc": "Unique Tesla path: bolts slow enemies by 15% per level for 1.5 s.",
		"effects": {"unlock_path": TowerTypes.TESLA},
	},
	"tesla_capacitor": {
		"name": "Capacitors", "cost": 10, "requires": ["tesla_static"], "pos": Vector2i(1, 3),
		"desc": "Tesla Towers deal 25% more damage of every type.",
		"effects": {"damage_tesla": 0.25},
	},
	"tesla_mastery": {
		"name": "Tesla Mastery", "cost": 16, "requires": ["tesla_capacitor"], "pos": Vector2i(1, 4),
		"desc": "Tesla Towers can be upgraded to level 4.",
		"effects": {"max_level_tesla": 1},
	},
	"cannon": {
		"name": "Cannon", "cost": 5, "requires": ["tesla"], "pos": Vector2i(2, 1),
		"desc": "Unlocks the Cannon: slow, long-range shells that crack white armor.",
		"effects": {"unlock_tower": TowerTypes.CANNON},
	},
	"cannon_upgrades": {
		"name": "Cannon Upgrades", "cost": 6, "requires": ["cannon"], "pos": Vector2i(2, 2),
		"desc": "Cannons can be upgraded: Damage, Range or Hit speed (one path per tower).",
		"effects": {"unlock_upgrades": TowerTypes.CANNON},
	},
	"cannon_shrapnel": {
		"name": "Shrapnel", "cost": 10, "requires": ["cannon_upgrades"], "pos": Vector2i(2, 3),
		"desc": "Unique Cannon path: shells splash nearby enemies for 50% damage (radius grows per level).",
		"effects": {"unlock_path": TowerTypes.CANNON},
	},
	"cannon_mastery": {
		"name": "Cannon Mastery", "cost": 16, "requires": ["cannon_shrapnel"], "pos": Vector2i(2, 4),
		"desc": "Cannons can be upgraded to level 4.",
		"effects": {"max_level_cannon": 1},
	},
	"bounty_1": {
		"name": "Bounty Hunter", "cost": 3, "requires": ["tesla"], "pos": Vector2i(3, 1),
		"desc": "+20% gold from every kill.",
		"effects": {"kill_reward": 0.2},
	},
	"war_chest": {
		"name": "War Chest", "cost": 6, "requires": ["bounty_1"], "pos": Vector2i(3, 2),
		"desc": "+50% wave-clear bonus.",
		"effects": {"wave_bonus": 0.5},
	},
	"bounty_2": {
		"name": "Master Hunter", "cost": 10, "requires": ["war_chest"], "pos": Vector2i(3, 3),
		"desc": "Another +20% gold from every kill.",
		"effects": {"kill_reward": 0.2},
	},
	"salvage": {
		"name": "Salvage", "cost": 15, "requires": ["bounty_2"], "pos": Vector2i(3, 4),
		"desc": "Selling refunds 75% instead of 50%.",
		"effects": {"sell_refund": 0.25},
	},
	"head_start": {
		"name": "Head Start", "cost": 22, "requires": ["salvage"], "pos": Vector2i(3, 5),
		"desc": "Start every run with +150 gold.",
		"effects": {"start_gold": 150},
	},
	"hollow_point": {
		"name": "Hollow Points", "cost": 4, "requires": ["tesla"], "pos": Vector2i(4, 1),
		"desc": "Every tower deals 20% more damage to green health.",
		"effects": {"dmg_health": 0.2},
	},
	"armor_breaker": {
		"name": "Armor Breaker", "cost": 7, "requires": ["hollow_point"], "pos": Vector2i(4, 2),
		"desc": "Every tower deals 30% more damage to white armor.",
		"effects": {"dmg_armor": 0.3},
	},
	"shield_breaker": {
		"name": "Shield Breaker", "cost": 10, "requires": ["armor_breaker"], "pos": Vector2i(4, 3),
		"desc": "Every tower deals 30% more damage to purple shields.",
		"effects": {"dmg_shield": 0.3},
	},
	"focus_fire": {
		"name": "Focus Fire", "cost": 16, "requires": ["shield_breaker"], "pos": Vector2i(4, 4),
		"desc": "Every tower deals 15% more damage of every type.",
		"effects": {"tower_damage": 0.15},
	},
	"annihilator": {
		"name": "Annihilator", "cost": 24, "requires": ["focus_fire"], "pos": Vector2i(4, 5),
		"desc": "Every tower deals another 25% more damage of every type.",
		"effects": {"tower_damage": 0.25},
	},
	"weaken_1": {
		"name": "Frailty", "cost": 4, "requires": ["tesla"], "pos": Vector2i(5, 1),
		"desc": "Enemies spawn with 10% less health.",
		"effects": {"enemy_health": -0.1},
	},
	"cripple": {
		"name": "Cripple", "cost": 6, "requires": ["weaken_1"], "pos": Vector2i(5, 2),
		"desc": "Enemies move 10% slower.",
		"effects": {"enemy_speed": -0.1},
	},
	"weaken_2": {
		"name": "Decay", "cost": 10, "requires": ["cripple"], "pos": Vector2i(5, 3),
		"desc": "Enemies spawn with another 10% less health.",
		"effects": {"enemy_health": -0.1},
	},
	"rust": {
		"name": "Rust", "cost": 15, "requires": ["weaken_2"], "pos": Vector2i(5, 4),
		"desc": "Enemies spawn with 25% less armor.",
		"effects": {"enemy_armor": -0.25},
	},
	"dampen": {
		"name": "Dampening Field", "cost": 22, "requires": ["rust"], "pos": Vector2i(5, 5),
		"desc": "Enemies spawn with 25% less shield.",
		"effects": {"enemy_shield": -0.25},
	},
	"fortify": {
		"name": "Fortify", "cost": 3, "requires": ["tesla"], "pos": Vector2i(6, 1),
		"desc": "Permanent: +5 lives on every run.",
		"effects": {"lives": 5},
	},
	"sharpen": {
		"name": "Sharpened Arsenal", "cost": 6, "requires": ["fortify"], "pos": Vector2i(6, 2),
		"desc": "Permanent: every tower deals 15% more damage.",
		"effects": {"tower_damage": 0.15},
	},
	"overclock": {
		"name": "Overclock", "cost": 10, "requires": ["sharpen"], "pos": Vector2i(6, 3),
		"desc": "Permanent: every tower attacks 15% faster.",
		"effects": {"tower_attack_speed": 0.15},
	},
	"fortify_2": {
		"name": "Bastion", "cost": 15, "requires": ["overclock"], "pos": Vector2i(6, 4),
		"desc": "Permanent: another +5 lives on every run.",
		"effects": {"lives": 5},
	},
	"diamond_mine": {
		"name": "Diamond Mine", "cost": 22, "requires": ["fortify_2"], "pos": Vector2i(6, 5),
		"desc": "+1 bonus diamond every 5th wave.",
		"effects": {"diamond_bonus": 1},
	},
}

var _unlocked: Dictionary = {}  # id -> true


func reset() -> void:
	_unlocked.clear()


## Restores saved unlocks in any order, keeping only ids whose prerequisites chain back
## to the root (protects against edited or outdated save files). Returns the known
## skill ids that could not be restored (e.g. after the tree was reorganized) so the
## caller can refund them.
func restore(ids: Array) -> Array[String]:
	_unlocked.clear()
	var progressed: bool = true
	while progressed:
		progressed = false
		for id: Variant in ids:
			if id is String and SKILLS.has(id) and not _unlocked.has(id) and prerequisites_met(id):
				_unlocked[id] = true
				progressed = true
	var dropped: Array[String] = []
	for id: Variant in ids:
		if id is String and SKILLS.has(id) and not _unlocked.has(id) and not dropped.has(id):
			dropped.append(id)
	return dropped


func is_unlocked(id: String) -> bool:
	return _unlocked.has(id)


func unlocked_ids() -> Array:
	return _unlocked.keys()


func prerequisites_met(id: String) -> bool:
	for required: String in SKILLS[id]["requires"]:
		if not _unlocked.has(required):
			return false
	return true


func cost(id: String) -> int:
	return SKILLS[id]["cost"]


func can_unlock(id: String, diamonds: int) -> bool:
	return SKILLS.has(id) and not _unlocked.has(id) and prerequisites_met(id) and diamonds >= cost(id)


## Marks `id` unlocked if its prerequisites are met. Main charges diamonds first.
func unlock(id: String) -> bool:
	if not SKILLS.has(id) or _unlocked.has(id) or not prerequisites_met(id):
		return false
	_unlocked[id] = true
	return true


## Sum of a numeric effect across unlocked skills.
func total(effect: String) -> float:
	var sum: float = 0.0
	for id: String in _unlocked:
		sum += float(SKILLS[id]["effects"].get(effect, 0.0))
	return sum


func _has_effect(effect: String, value: String) -> bool:
	for id: String in _unlocked:
		if SKILLS[id]["effects"].get(effect, "") == value:
			return true
	return false


func is_tower_unlocked(type_id: String) -> bool:
	return type_id == TowerTypes.BASIC or _has_effect("unlock_tower", type_id)


## Generic Damage/Range/Speed upgrades for `type_id`.
func upgrades_unlocked(type_id: String) -> bool:
	return _has_effect("unlock_upgrades", type_id)


## The unique upgrade path of `type_id`.
func unique_path_unlocked(type_id: String) -> bool:
	return _has_effect("unlock_path", type_id)
