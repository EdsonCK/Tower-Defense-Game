class_name EnemyTypes
extends RefCounted
## Data definitions for every enemy type. Base health and reward are scaled per wave
## by WaveGenerator. Fields:
##   name, trait     display text
##   shape, color, radius   placeholder appearance
##   speed           pixels per second between cell centers
##   health, reward  base values before wave scaling
##   armor           flat damage removed from every hit (a hit always deals at least 1)
##   regen           fraction of max health regenerated per second
##   lives           base lives lost when it reaches the exit
##   split_into, split_count   enemies spawned where it dies
##   min_wave, weight          when it can appear and how often (weight 0 = never random)
##   pack            [min, max] spawned together per pick
##   interval        seconds until the next spawn after this one

const GRUNT: String = "grunt"
const RUNNER: String = "runner"
const SWARMLING: String = "swarmling"
const TANK: String = "tank"
const MENDER: String = "mender"
const SPLITTER: String = "splitter"
const BOSS: String = "boss"

const DEFS: Dictionary = {
	GRUNT: {
		"name": "Grunt", "trait": "Baseline walker",
		"shape": "diamond", "color": Color(0.9, 0.2, 0.2), "radius": 10.0,
		"speed": 60.0, "health": 45.0, "reward": 12, "armor": 0, "regen": 0.0, "lives": 1,
		"split_into": "", "split_count": 0,
		"min_wave": 1, "weight": 10.0, "pack": [1, 1], "interval": 1.2,
	},
	RUNNER: {
		"name": "Runner", "trait": "Fast but fragile",
		"shape": "triangle", "color": Color(1.0, 0.85, 0.2), "radius": 9.0,
		"speed": 100.0, "health": 28.0, "reward": 10, "armor": 0, "regen": 0.0, "lives": 1,
		"split_into": "", "split_count": 0,
		"min_wave": 3, "weight": 6.0, "pack": [1, 2], "interval": 0.9,
	},
	SWARMLING: {
		"name": "Swarmling", "trait": "Tiny; arrives in packs",
		"shape": "circle", "color": Color(0.55, 0.95, 0.35), "radius": 6.0,
		"speed": 78.0, "health": 14.0, "reward": 4, "armor": 0, "regen": 0.0, "lives": 1,
		"split_into": "", "split_count": 0,
		"min_wave": 4, "weight": 4.0, "pack": [3, 5], "interval": 0.35,
	},
	TANK: {
		"name": "Tank", "trait": "Armored: -4 damage per hit",
		"shape": "square", "color": Color(0.6, 0.35, 0.85), "radius": 12.0,
		"speed": 36.0, "health": 150.0, "reward": 28, "armor": 4, "regen": 0.0, "lives": 2,
		"split_into": "", "split_count": 0,
		"min_wave": 5, "weight": 3.0, "pack": [1, 1], "interval": 1.6,
	},
	MENDER: {
		"name": "Mender", "trait": "Regenerates 5% health per second",
		"shape": "hexagon", "color": Color(0.2, 0.85, 0.8), "radius": 10.0,
		"speed": 55.0, "health": 70.0, "reward": 18, "armor": 0, "regen": 0.05, "lives": 1,
		"split_into": "", "split_count": 0,
		"min_wave": 7, "weight": 3.0, "pack": [1, 1], "interval": 1.2,
	},
	SPLITTER: {
		"name": "Splitter", "trait": "Splits into 3 Swarmlings on death",
		"shape": "ring", "color": Color(1.0, 0.55, 0.15), "radius": 11.0,
		"speed": 50.0, "health": 80.0, "reward": 15, "armor": 0, "regen": 0.0, "lives": 1,
		"split_into": SWARMLING, "split_count": 3,
		"min_wave": 8, "weight": 3.0, "pack": [1, 1], "interval": 1.4,
	},
	BOSS: {
		"name": "Warlord", "trait": "Boss every 10 waves: armored, slowly regenerates, costs 5 lives",
		"shape": "star", "color": Color(0.55, 0.05, 0.1), "radius": 15.0,
		"speed": 34.0, "health": 250.0, "reward": 150, "armor": 3, "regen": 0.005, "lives": 5,
		"split_into": "", "split_count": 0,
		"min_wave": 10, "weight": 0.0, "pack": [1, 1], "interval": 2.5,
	},
}


static func get_def(type_id: String) -> Dictionary:
	return DEFS[type_id]


static func has_type(type_id: String) -> bool:
	return DEFS.has(type_id)


static func display_name(type_id: String) -> String:
	return DEFS[type_id]["name"]


## Type ids that may be randomly picked on `wave` (bosses are scheduled separately).
static func random_pool(wave: int) -> Array[String]:
	var pool: Array[String] = []
	for type_id: String in DEFS:
		var def: Dictionary = DEFS[type_id]
		if def["weight"] > 0.0 and wave >= def["min_wave"]:
			pool.append(type_id)
	return pool
