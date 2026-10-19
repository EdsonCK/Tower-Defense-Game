class_name TowerTypes
extends RefCounted
## Data definitions for every tower type. Fields:
##   name, short, desc           display text
##   cost                        build price
##   damage                      per hit, against each enemy layer:
##                               {"health": .., "armor": .., "shield": ..}
##   range, cooldown             pixels, seconds
##   attack                      "single" = nearest enemy, "area" = every enemy in range
##   color                       placeholder appearance
##   range_per_level             Range upgrade step
##   unique_path                 Tower.UpgradePath value of this type's unique upgrade

const BASIC: String = "basic"
const TESLA: String = "tesla"
const CANNON: String = "cannon"
const LAYERS: Array[String] = ["shield", "armor", "health"]

const DEFS: Dictionary = {
	BASIC: {
		"name": "Basic Tower", "short": "Basic", "desc": "Reliable all-rounder. Fires at the nearest enemy.",
		"cost": GameConfig.TOWER_COST, "range": GameConfig.TOWER_RANGE, "cooldown": GameConfig.TOWER_COOLDOWN,
		"damage": {"health": GameConfig.TOWER_DAMAGE, "armor": 8, "shield": 6},
		"attack": "single", "color": Color(0.2, 0.6, 0.95),
		"range_per_level": GameConfig.UPGRADE_RANGE_PER_LEVEL,
		"unique_path": 4,  # Tower.UpgradePath.PIERCE
	},
	TESLA: {
		"name": "Tesla Tower", "short": "Tesla", "desc": "Shocks every enemy in a small radius. Shreds shields.",
		"cost": 80, "range": 80.0, "cooldown": 1.0,
		"damage": {"health": 10, "armor": 3, "shield": 24},
		"attack": "area", "color": Color(0.6, 0.35, 0.95),
		"range_per_level": 16.0,
		"unique_path": 5,  # Tower.UpgradePath.STATIC
	},
	CANNON: {
		"name": "Cannon", "short": "Cannon", "desc": "Slow, long-range heavy shells. Cracks armor.",
		"cost": 110, "range": 128.0, "cooldown": 1.6,
		"damage": {"health": 20, "armor": 48, "shield": 4},
		"attack": "single", "color": Color(0.85, 0.55, 0.25),
		"range_per_level": 24.0,
		"unique_path": 6,  # Tower.UpgradePath.SHRAPNEL
	},
}

## Order in which tower types appear in the build menu.
const ORDER: Array[String] = [BASIC, TESLA, CANNON]


static func get_def(type_id: String) -> Dictionary:
	return DEFS[type_id]


static func cost(type_id: String) -> int:
	return DEFS[type_id]["cost"]


static func display_name(type_id: String) -> String:
	return DEFS[type_id]["name"]


## Short "H/A/S" damage summary, e.g. "15 / 6 / 6".
static func damage_text(damage: Dictionary) -> String:
	return "%d / %d / %d" % [damage["health"], damage["armor"], damage["shield"]]
