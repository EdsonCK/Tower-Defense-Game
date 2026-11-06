class_name Biomes
extends RefCounted
## Biome definitions. The map's biome changes every GameConfig.BIOME_WAVES waves and
## cycles after the last one. Every biome shares the same art style (flat shapes with
## a dark outline and a soft shadow) and the same path palette; only the ground colors
## and decorations change. Each biome buffs every tower a little and one favored tower
## type more. Fields:
##   name, ground, ground_alt, grid   ground palette
##   decorations      Array of [kind, weight]; see Board._draw_decoration for kinds
##   deco_colors      named colors used by that biome's decorations
##   deco_density     chance that a free ground cell gets a decoration
##   buff             effect -> fraction for every tower ("range", "attack_speed", "damage")
##   favored          tower type id that gets `favored_buff` on top
##   favored_buff     effect -> fraction for the favored type

## Shared path palette (identical in every biome).
const PATH_COLOR: Color = Color(0.66, 0.54, 0.38)
const PATH_EDGE: Color = Color(0.43, 0.33, 0.22)
const PATH_PEBBLE: Color = Color(0.78, 0.68, 0.52)
const OUTLINE: Color = Color(0.06, 0.06, 0.08, 0.85)

const DEFS: Array[Dictionary] = [
	{
		"name": "Meadow",
		"ground": Color(0.32, 0.55, 0.27), "ground_alt": Color(0.35, 0.59, 0.29), "grid": Color(0, 0, 0, 0.07),
		"decorations": [["tree", 3], ["bush", 3], ["flowers", 4], ["rock", 1]],
		"deco_colors": {"leaf": Color(0.2, 0.5, 0.2), "leaf_light": Color(0.36, 0.7, 0.3), "trunk": Color(0.45, 0.3, 0.18),
			"flower_a": Color(1.0, 0.85, 0.3), "flower_b": Color(0.95, 0.45, 0.6), "rock": Color(0.55, 0.57, 0.6)},
		"deco_density": 0.16,
		"buff": {"range": 0.10}, "favored": TowerTypes.BASIC, "favored_buff": {"range": 0.15},
	},
	{
		"name": "Desert",
		"ground": Color(0.85, 0.72, 0.45), "ground_alt": Color(0.88, 0.75, 0.48), "grid": Color(0.3, 0.2, 0, 0.08),
		"decorations": [["cactus", 4], ["rock", 3], ["dune", 3], ["bones", 1]],
		"deco_colors": {"cactus": Color(0.33, 0.58, 0.3), "cactus_light": Color(0.45, 0.7, 0.38), "rock": Color(0.66, 0.5, 0.34),
			"dune": Color(0.78, 0.63, 0.38), "bones": Color(0.95, 0.93, 0.85)},
		"deco_density": 0.12,
		"buff": {"attack_speed": 0.05}, "favored": TowerTypes.CANNON, "favored_buff": {"attack_speed": 0.15},
	},
	{
		"name": "Tundra",
		"ground": Color(0.86, 0.9, 0.95), "ground_alt": Color(0.82, 0.87, 0.93), "grid": Color(0.2, 0.3, 0.45, 0.08),
		"decorations": [["pine", 4], ["ice", 3], ["snow_rock", 3]],
		"deco_colors": {"pine": Color(0.18, 0.4, 0.36), "snow": Color(0.97, 0.98, 1.0), "trunk": Color(0.4, 0.3, 0.22),
			"ice": Color(0.6, 0.85, 1.0), "rock": Color(0.55, 0.6, 0.68)},
		"deco_density": 0.14,
		"buff": {"damage": 0.05}, "favored": TowerTypes.TESLA, "favored_buff": {"damage": 0.20},
	},
	{
		"name": "Volcanic",
		"ground": Color(0.24, 0.21, 0.22), "ground_alt": Color(0.27, 0.23, 0.24), "grid": Color(0, 0, 0, 0.12),
		"decorations": [["lava", 3], ["stump", 3], ["obsidian", 3]],
		"deco_colors": {"lava": Color(1.0, 0.42, 0.12), "lava_glow": Color(1.0, 0.75, 0.3), "stump": Color(0.16, 0.12, 0.1),
			"obsidian": Color(0.1, 0.08, 0.14), "obsidian_light": Color(0.45, 0.35, 0.6)},
		"deco_density": 0.13,
		"buff": {"damage": 0.05}, "favored": TowerTypes.CANNON, "favored_buff": {"damage": 0.20},
	},
	{
		"name": "Swamp",
		"ground": Color(0.28, 0.36, 0.25), "ground_alt": Color(0.3, 0.39, 0.27), "grid": Color(0, 0, 0, 0.09),
		"decorations": [["reeds", 4], ["pond", 2], ["mushroom", 3]],
		"deco_colors": {"reed": Color(0.5, 0.6, 0.28), "reed_top": Color(0.42, 0.3, 0.18), "water": Color(0.22, 0.38, 0.4),
			"lily": Color(0.4, 0.7, 0.35), "cap": Color(0.85, 0.3, 0.25), "stem": Color(0.92, 0.88, 0.78)},
		"deco_density": 0.15,
		"buff": {"range": 0.10}, "favored": TowerTypes.TESLA, "favored_buff": {"range": 0.20},
	},
	{
		"name": "Autumn Forest",
		"ground": Color(0.5, 0.45, 0.26), "ground_alt": Color(0.53, 0.47, 0.28), "grid": Color(0, 0, 0, 0.08),
		"decorations": [["autumn_tree", 4], ["leaves", 4], ["pumpkin", 1], ["rock", 1]],
		"deco_colors": {"leaf": Color(0.88, 0.45, 0.15), "leaf_light": Color(0.98, 0.68, 0.22), "trunk": Color(0.38, 0.25, 0.15),
			"leaves": Color(0.8, 0.32, 0.15), "pumpkin": Color(0.95, 0.5, 0.12), "rock": Color(0.5, 0.48, 0.45)},
		"deco_density": 0.16,
		"buff": {"attack_speed": 0.05}, "favored": TowerTypes.BASIC, "favored_buff": {"attack_speed": 0.15},
	},
]


static func count() -> int:
	return DEFS.size()


## Biome index for `wave` (1-based): waves 1-10 are biome 0, 11-20 biome 1, ... cycling.
static func index_for_wave(wave: int) -> int:
	return floori(float(maxi(wave, 1) - 1) / GameConfig.BIOME_WAVES) % DEFS.size()


static func get_def(index: int) -> Dictionary:
	return DEFS[index % DEFS.size()]


## Total bonus of `effect` for a tower of `type_id` in biome `index`.
static func bonus(index: int, type_id: String, effect: String) -> float:
	if index < 0:
		return 0.0  # no biome (used by tests that need unbuffed numbers)
	var def: Dictionary = get_def(index)
	var value: float = float(def["buff"].get(effect, 0.0))
	if def["favored"] == type_id:
		value += float(def["favored_buff"].get(effect, 0.0))
	return value


## "Meadow: +10% range for all towers, Basic +25% range".
static func describe(index: int) -> String:
	var def: Dictionary = get_def(index)
	var parts: PackedStringArray = PackedStringArray()
	for effect: String in def["buff"]:
		parts.append("+%d%% %s" % [roundi(def["buff"][effect] * 100.0), _effect_name(effect)])
	var favored: PackedStringArray = PackedStringArray()
	for effect: String in def["favored_buff"]:
		var total: float = float(def["buff"].get(effect, 0.0)) + float(def["favored_buff"][effect])
		favored.append("+%d%% %s" % [roundi(total * 100.0), _effect_name(effect)])
	return "%s all, %s %s" % [", ".join(parts), TowerTypes.get_def(def["favored"])["short"], ", ".join(favored)]


static func _effect_name(effect: String) -> String:
	match effect:
		"attack_speed":
			return "hit speed"
		_:
			return effect
