class_name TowerTypes
extends RefCounted
## Data definitions for every tower type. Fields:
##   name, short, desc           display text
##   cost                        build price
##   range, damage, cooldown     base stats (pixels, HP per hit, seconds)
##   attack                      "single" = nearest enemy, "area" = every enemy in range
##   color                       placeholder appearance
##   damage_per_level, range_per_level   generic Damage/Range upgrade steps
##   unique_path                 Tower.UpgradePath value of this type's unique upgrade

const BASIC: String = "basic"
const TESLA: String = "tesla"

const DEFS: Dictionary = {
	BASIC: {
		"name": "Basic Tower", "short": "Basic", "desc": "Fires at the nearest enemy.",
		"cost": GameConfig.TOWER_COST, "range": GameConfig.TOWER_RANGE,
		"damage": GameConfig.TOWER_DAMAGE, "cooldown": GameConfig.TOWER_COOLDOWN,
		"attack": "single", "color": Color(0.2, 0.6, 0.95),
		"damage_per_level": GameConfig.UPGRADE_DAMAGE_PER_LEVEL, "range_per_level": GameConfig.UPGRADE_RANGE_PER_LEVEL,
		"unique_path": 4,  # Tower.UpgradePath.PIERCE
	},
	TESLA: {
		"name": "Tesla Tower", "short": "Tesla", "desc": "Shocks every enemy within a small radius.",
		"cost": 80, "range": 80.0, "damage": 12, "cooldown": 1.0,
		"attack": "area", "color": Color(0.6, 0.35, 0.95),
		"damage_per_level": 5, "range_per_level": 16.0,
		"unique_path": 5,  # Tower.UpgradePath.STATIC
	},
}

## Order in which tower types appear in the build menu.
const ORDER: Array[String] = [BASIC, TESLA]


static func get_def(type_id: String) -> Dictionary:
	return DEFS[type_id]


static func cost(type_id: String) -> int:
	return DEFS[type_id]["cost"]


static func display_name(type_id: String) -> String:
	return DEFS[type_id]["name"]
