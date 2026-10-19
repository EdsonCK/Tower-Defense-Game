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
##     enemy_health, enemy_speed: fractional changes (-0.1 = -10%)
##     lives: extra lives granted on unlock

const ROOT: String = "tesla"

const SKILLS: Dictionary = {
	"tesla": {
		"name": "Tesla Tower", "cost": 3, "requires": [], "pos": Vector2i(2, 0),
		"desc": "Unlocks the Tesla Tower: shocks every enemy within a small radius. Strong against packs, weak against armor.",
		"effects": {"unlock_tower": TowerTypes.TESLA},
	},
	"basic_upgrades": {
		"name": "Basic Upgrades", "cost": 3, "requires": ["tesla"], "pos": Vector2i(0, 1),
		"desc": "Basic Towers can be upgraded: Damage, Range or Hit speed (one path per tower).",
		"effects": {"unlock_upgrades": TowerTypes.BASIC},
	},
	"basic_pierce": {
		"name": "Armor Piercing", "cost": 5, "requires": ["basic_upgrades"], "pos": Vector2i(0, 2),
		"desc": "Unique Basic upgrade path: shots ignore armor and deal +4 damage per level.",
		"effects": {"unlock_path": TowerTypes.BASIC},
	},
	"tesla_upgrades": {
		"name": "Tesla Upgrades", "cost": 4, "requires": ["tesla"], "pos": Vector2i(1, 1),
		"desc": "Tesla Towers can be upgraded: Damage, Range or Hit speed (one path per tower).",
		"effects": {"unlock_upgrades": TowerTypes.TESLA},
	},
	"tesla_static": {
		"name": "Static Field", "cost": 5, "requires": ["tesla_upgrades"], "pos": Vector2i(1, 2),
		"desc": "Unique Tesla upgrade path: bolts slow enemies by 15% per level for 1.5 s.",
		"effects": {"unlock_path": TowerTypes.TESLA},
	},
	"bounty_1": {
		"name": "Bounty Hunter", "cost": 3, "requires": ["tesla"], "pos": Vector2i(2, 1),
		"desc": "+20% gold from every kill.",
		"effects": {"kill_reward": 0.2},
	},
	"bounty_2": {
		"name": "Master Hunter", "cost": 5, "requires": ["bounty_1"], "pos": Vector2i(2, 2),
		"desc": "Another +20% gold from every kill.",
		"effects": {"kill_reward": 0.2},
	},
	"war_chest": {
		"name": "War Chest", "cost": 4, "requires": ["bounty_1"], "pos": Vector2i(2, 3),
		"desc": "+50% wave-clear bonus.",
		"effects": {"wave_bonus": 0.5},
	},
	"weaken_1": {
		"name": "Frailty", "cost": 4, "requires": ["tesla"], "pos": Vector2i(3, 1),
		"desc": "Enemies spawn with 10% less health.",
		"effects": {"enemy_health": -0.1},
	},
	"weaken_2": {
		"name": "Decay", "cost": 6, "requires": ["weaken_1"], "pos": Vector2i(3, 2),
		"desc": "Enemies spawn with another 10% less health.",
		"effects": {"enemy_health": -0.1},
	},
	"cripple": {
		"name": "Cripple", "cost": 5, "requires": ["weaken_1"], "pos": Vector2i(3, 3),
		"desc": "Enemies move 10% slower.",
		"effects": {"enemy_speed": -0.1},
	},
	"fortify": {
		"name": "Fortify", "cost": 3, "requires": ["tesla"], "pos": Vector2i(4, 1),
		"desc": "Permanent: +5 lives right away.",
		"effects": {"lives": 5},
	},
	"sharpen": {
		"name": "Sharpened Arsenal", "cost": 5, "requires": ["fortify"], "pos": Vector2i(4, 2),
		"desc": "Permanent: every tower deals 15% more damage.",
		"effects": {"tower_damage": 0.15},
	},
	"overclock": {
		"name": "Overclock", "cost": 6, "requires": ["sharpen"], "pos": Vector2i(4, 3),
		"desc": "Permanent: every tower attacks 15% faster.",
		"effects": {"tower_attack_speed": 0.15},
	},
}

var _unlocked: Dictionary = {}  # id -> true


func reset() -> void:
	_unlocked.clear()


## Restores saved unlocks in any order, keeping only ids whose prerequisites chain back
## to the root (protects against edited or outdated save files).
func restore(ids: Array) -> void:
	_unlocked.clear()
	var progressed: bool = true
	while progressed:
		progressed = false
		for id: Variant in ids:
			if id is String and SKILLS.has(id) and not _unlocked.has(id) and prerequisites_met(id):
				_unlocked[id] = true
				progressed = true


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
